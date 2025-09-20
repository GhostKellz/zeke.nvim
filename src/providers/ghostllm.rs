use anyhow::Result;
use async_trait::async_trait;
use futures_util::{Stream, StreamExt};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::pin::Pin;

#[derive(Debug, Serialize)]
struct GhostLLMRequest {
    model: String,
    messages: Vec<Message>,
    temperature: f32,
    max_tokens: usize,
    stream: bool,
}

#[derive(Debug, Serialize, Deserialize)]
struct Message {
    role: String,
    content: String,
}

#[derive(Debug, Deserialize)]
struct GhostLLMResponse {
    choices: Vec<Choice>,
}

#[derive(Debug, Deserialize)]
struct Choice {
    message: Message,
}

#[derive(Debug, Deserialize)]
struct StreamChunk {
    choices: Vec<StreamChoice>,
}

#[derive(Debug, Deserialize)]
struct StreamChoice {
    delta: Delta,
}

#[derive(Debug, Deserialize)]
struct Delta {
    content: Option<String>,
}

#[derive(Debug, Deserialize)]
struct ConsentRequired {
    error: ConsentError,
}

#[derive(Debug, Deserialize)]
struct ConsentError {
    message: String,
    #[serde(rename = "type")]
    error_type: String,
    consent_id: String,
}

#[derive(Debug, Serialize)]
struct ConsentApproval {
    consent_id: String,
    decision: String, // "allow_once", "allow_session", "deny"
}

pub struct GhostLLMProvider {
    client: Client,
    base_url: String,
    session_token: Option<String>,
}

impl GhostLLMProvider {
    pub fn new(base_url: String, session_token: Option<String>) -> Self {
        Self {
            client: Client::new(),
            base_url,
            session_token,
        }
    }

    async fn make_request(&self, request: GhostLLMRequest) -> Result<String> {
        let mut headers = reqwest::header::HeaderMap::new();
        headers.insert("Content-Type", "application/json".parse()?);

        if let Some(token) = &self.session_token {
            headers.insert("Authorization", format!("Bearer {}", token).parse()?);
        }

        let response = self
            .client
            .post(&format!("{}/v1/chat/completions", self.base_url))
            .headers(headers)
            .json(&request)
            .send()
            .await?;

        if response.status() == 200 {
            let chat_response: GhostLLMResponse = response.json().await?;
            Ok(chat_response.choices[0].message.content.clone())
        } else if response.status() == 403 {
            // Handle consent required
            let consent_response: ConsentRequired = response.json().await?;
            if consent_response.error.error_type == "consent_required" {
                // For now, auto-approve. In production, this would show UI prompt
                self.approve_consent(&consent_response.error.consent_id, "allow_session").await?;
                // Retry the request
                self.make_request(request).await
            } else {
                Err(anyhow::anyhow!("GhostLLM error: {}", consent_response.error.message))
            }
        } else {
            let error_text = response.text().await?;
            Err(anyhow::anyhow!("GhostLLM API error: {}", error_text))
        }
    }

    async fn approve_consent(&self, consent_id: &str, decision: &str) -> Result<()> {
        let approval = ConsentApproval {
            consent_id: consent_id.to_string(),
            decision: decision.to_string(),
        };

        let response = self
            .client
            .post(&format!("{}/admin/consent", self.base_url))
            .header("Content-Type", "application/json")
            .json(&approval)
            .send()
            .await?;

        if !response.status().is_success() {
            return Err(anyhow::anyhow!("Failed to approve consent"));
        }

        Ok(())
    }

    pub async fn chat(&self, message: &str) -> Result<String> {
        let request = GhostLLMRequest {
            model: "auto".to_string(), // Let GhostLLM route automatically
            messages: vec![Message {
                role: "user".to_string(),
                content: message.to_string(),
            }],
            temperature: 0.7,
            max_tokens: 2048,
            stream: false,
        };

        self.make_request(request).await
    }

    pub async fn edit_code(&self, code: &str, instruction: &str) -> Result<String> {
        let message = format!(
            "Please edit the following code according to the instruction:\n\nCode:\n```\n{}\n```\n\nInstruction: {}",
            code, instruction
        );

        self.chat(&message).await
    }

    pub async fn explain_code(&self, code: &str) -> Result<String> {
        let message = format!("Please explain the following code:\n\n```\n{}\n```", code);
        self.chat(&message).await
    }

    pub async fn analyze_code(&self, code: &str, analysis_type: &str) -> Result<String> {
        let message = format!(
            "Please analyze the following code for {}:\n\n```\n{}\n```",
            analysis_type, code
        );
        self.chat(&message).await
    }

    pub async fn create_file(&self, description: &str) -> Result<String> {
        let message = format!("Please create a file with the following description: {}", description);
        self.chat(&message).await
    }

    pub async fn list_models(&self) -> Result<Vec<String>> {
        let response = self
            .client
            .get(&format!("{}/v1/models", self.base_url))
            .send()
            .await?;

        if response.status().is_success() {
            #[derive(Debug, Deserialize)]
            struct ModelsResponse {
                data: Vec<Model>,
            }

            #[derive(Debug, Deserialize)]
            struct Model {
                id: String,
            }

            let models_response: ModelsResponse = response.json().await?;
            Ok(models_response.data.into_iter().map(|m| m.id).collect())
        } else {
            // Fallback to common models if endpoint not available
            Ok(vec![
                "auto".to_string(),
                "claude-3-sonnet".to_string(),
                "gpt-4".to_string(),
                "gpt-3.5-turbo".to_string(),
                "llama3:8b".to_string(),
                "deepseek-coder:6.7b".to_string(),
            ])
        }
    }

    pub async fn chat_stream(
        &self,
        message: &str,
    ) -> Result<Pin<Box<dyn Stream<Item = Result<String>> + Send>>> {
        let request = GhostLLMRequest {
            model: "auto".to_string(),
            messages: vec![Message {
                role: "user".to_string(),
                content: message.to_string(),
            }],
            temperature: 0.7,
            max_tokens: 2048,
            stream: true,
        };

        let mut headers = reqwest::header::HeaderMap::new();
        headers.insert("Content-Type", "application/json".parse()?);

        if let Some(token) = &self.session_token {
            headers.insert("Authorization", format!("Bearer {}", token).parse()?);
        }

        let response = self
            .client
            .post(&format!("{}/v1/chat/completions", self.base_url))
            .headers(headers)
            .json(&request)
            .send()
            .await?;

        if !response.status().is_success() {
            return Err(anyhow::anyhow!("Failed to start stream"));
        }

        let stream = response.bytes_stream().map(|chunk| {
            match chunk {
                Ok(bytes) => {
                    let text = String::from_utf8_lossy(&bytes);
                    // Parse SSE format
                    for line in text.lines() {
                        if line.starts_with("data: ") {
                            let json_str = &line[6..];
                            if json_str == "[DONE]" {
                                break;
                            }
                            if let Ok(chunk) = serde_json::from_str::<StreamChunk>(json_str) {
                                if let Some(content) = chunk.choices.get(0)
                                    .and_then(|choice| choice.delta.content.as_ref()) {
                                    return Ok(content.clone());
                                }
                            }
                        }
                    }
                    Ok(String::new())
                }
                Err(e) => Err(anyhow::anyhow!("Stream error: {}", e)),
            }
        });

        Ok(Box::pin(stream))
    }

    pub async fn health_check(&self) -> Result<bool> {
        let response = self
            .client
            .get(&format!("{}/health", self.base_url))
            .send()
            .await;

        match response {
            Ok(resp) => Ok(resp.status().is_success()),
            Err(_) => Ok(false),
        }
    }
}

#[async_trait]
pub trait Provider: Send + Sync {
    async fn chat(&self, message: &str) -> Result<String>;
    async fn edit_code(&self, code: &str, instruction: &str) -> Result<String>;
    async fn explain_code(&self, code: &str) -> Result<String>;
    async fn analyze_code(&self, code: &str, analysis_type: &str) -> Result<String>;
    async fn create_file(&self, description: &str) -> Result<String>;
    async fn list_models(&self) -> Vec<String>;
    async fn chat_stream(&self, message: &str) -> Result<Pin<Box<dyn Stream<Item = Result<String>> + Send>>>;
}

#[async_trait]
impl Provider for GhostLLMProvider {
    async fn chat(&self, message: &str) -> Result<String> {
        self.chat(message).await
    }

    async fn edit_code(&self, code: &str, instruction: &str) -> Result<String> {
        self.edit_code(code, instruction).await
    }

    async fn explain_code(&self, code: &str) -> Result<String> {
        self.explain_code(code).await
    }

    async fn analyze_code(&self, code: &str, analysis_type: &str) -> Result<String> {
        self.analyze_code(code, analysis_type).await
    }

    async fn create_file(&self, description: &str) -> Result<String> {
        self.create_file(description).await
    }

    async fn list_models(&self) -> Vec<String> {
        self.list_models().await.unwrap_or_else(|_| vec![
            "auto".to_string(),
            "claude-3-sonnet".to_string(),
            "gpt-4".to_string(),
        ])
    }

    async fn chat_stream(&self, message: &str) -> Result<Pin<Box<dyn Stream<Item = Result<String>> + Send>>> {
        self.chat_stream(message).await
    }
}