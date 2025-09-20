use anyhow::Result;
use async_trait::async_trait;
use futures_util::{Stream, StreamExt};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::pin::Pin;

#[derive(Debug, Serialize)]
struct MessagesRequest {
    model: String,
    messages: Vec<Message>,
    max_tokens: usize,
    temperature: f32,
    stream: bool,
}

#[derive(Debug, Serialize, Deserialize)]
struct Message {
    role: String,
    content: String,
}

#[derive(Debug, Deserialize)]
struct MessagesResponse {
    content: Vec<Content>,
}

#[derive(Debug, Deserialize)]
struct Content {
    text: String,
}

#[derive(Debug, Deserialize)]
struct StreamEvent {
    #[serde(rename = "type")]
    event_type: String,
    delta: Option<Delta>,
}

#[derive(Debug, Deserialize)]
struct Delta {
    text: Option<String>,
}

pub struct ClaudeProvider {
    client: Client,
    api_key: String,
    model: String,
    temperature: f32,
    max_tokens: usize,
}

impl ClaudeProvider {
    pub fn new() -> Self {
        let api_key = std::env::var("ANTHROPIC_API_KEY").unwrap_or_default();

        Self {
            client: Client::new(),
            api_key,
            model: "claude-3-5-sonnet-20241022".to_string(),
            temperature: 0.7,
            max_tokens: 4096,
        }
    }

    async fn make_request(&self, messages: Vec<Message>, stream: bool) -> Result<reqwest::Response> {
        let request = MessagesRequest {
            model: self.model.clone(),
            messages,
            max_tokens: self.max_tokens,
            temperature: self.temperature,
            stream,
        };

        let response = self.client
            .post("https://api.anthropic.com/v1/messages")
            .header("x-api-key", &self.api_key)
            .header("anthropic-version", "2023-06-01")
            .header("Content-Type", "application/json")
            .json(&request)
            .send()
            .await?;

        if !response.status().is_success() {
            let error_text = response.text().await?;
            return Err(anyhow::anyhow!("Claude API error: {}", error_text));
        }

        Ok(response)
    }
}

#[async_trait]
impl super::Provider for ClaudeProvider {
    async fn chat(&self, message: &str) -> Result<String> {
        let messages = vec![
            Message {
                role: "user".to_string(),
                content: message.to_string(),
            }
        ];

        let response = self.make_request(messages, false).await?;
        let messages_response: MessagesResponse = response.json().await?;

        Ok(messages_response.content
            .first()
            .map(|c| c.text.clone())
            .unwrap_or_default())
    }

    async fn edit_code(&self, code: &str, instruction: &str) -> Result<String> {
        let prompt = format!(
            "Edit the following code according to this instruction: {}\n\nCode:\n```\n{}\n```\n\nProvide the edited code in a code block.",
            instruction, code
        );

        let messages = vec![
            Message {
                role: "user".to_string(),
                content: prompt,
            }
        ];

        let response = self.make_request(messages, false).await?;
        let messages_response: MessagesResponse = response.json().await?;

        Ok(messages_response.content
            .first()
            .map(|c| c.text.clone())
            .unwrap_or_default())
    }

    async fn explain_code(&self, code: &str) -> Result<String> {
        let prompt = format!("Explain the following code clearly and concisely:\n\n```\n{}\n```", code);

        let messages = vec![
            Message {
                role: "user".to_string(),
                content: prompt,
            }
        ];

        let response = self.make_request(messages, false).await?;
        let messages_response: MessagesResponse = response.json().await?;

        Ok(messages_response.content
            .first()
            .map(|c| c.text.clone())
            .unwrap_or_default())
    }

    async fn analyze_code(&self, code: &str, analysis_type: &str) -> Result<String> {
        let prompt = format!(
            "Analyze the following code for {} and provide actionable feedback:\n\n```\n{}\n```",
            analysis_type, code
        );

        let messages = vec![
            Message {
                role: "user".to_string(),
                content: prompt,
            }
        ];

        let response = self.make_request(messages, false).await?;
        let messages_response: MessagesResponse = response.json().await?;

        Ok(messages_response.content
            .first()
            .map(|c| c.text.clone())
            .unwrap_or_default())
    }

    async fn create_file(&self, description: &str) -> Result<String> {
        let prompt = format!(
            "Create a complete, working file based on this description: {}\n\nProvide the complete file content in a code block.",
            description
        );

        let messages = vec![
            Message {
                role: "user".to_string(),
                content: prompt,
            }
        ];

        let response = self.make_request(messages, false).await?;
        let messages_response: MessagesResponse = response.json().await?;

        Ok(messages_response.content
            .first()
            .map(|c| c.text.clone())
            .unwrap_or_default())
    }

    async fn list_models(&self) -> Vec<String> {
        vec![
            "claude-3-5-sonnet-20241022".to_string(),
            "claude-3-5-haiku-20241022".to_string(),
            "claude-3-opus-20240229".to_string(),
            "claude-3-sonnet-20240229".to_string(),
            "claude-3-haiku-20240307".to_string(),
        ]
    }

    async fn set_model(&mut self, model: &str) -> Result<()> {
        self.model = model.to_string();
        Ok(())
    }

    async fn get_current_model(&self) -> String {
        self.model.clone()
    }

    async fn chat_stream(&self, message: &str) -> Result<Pin<Box<dyn Stream<Item = Result<String>> + Send>>> {
        let messages = vec![
            Message {
                role: "user".to_string(),
                content: message.to_string(),
            }
        ];

        let response = self.make_request(messages, true).await?;

        let stream = response
            .bytes_stream()
            .map(|chunk| {
                chunk.map_err(|e| anyhow::anyhow!("Stream error: {}", e))
                    .and_then(|bytes| {
                        let text = String::from_utf8_lossy(&bytes);

                        if text.starts_with("data: ") {
                            let json_str = &text[6..];
                            serde_json::from_str::<StreamEvent>(json_str)
                                .map(|event| {
                                    event.delta
                                        .and_then(|d| d.text)
                                        .unwrap_or_default()
                                })
                                .map_err(|e| anyhow::anyhow!("JSON parse error: {}", e))
                        } else {
                            Ok(String::new())
                        }
                    })
            });

        Ok(Box::pin(stream))
    }
}