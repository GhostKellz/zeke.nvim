use anyhow::Result;
use async_trait::async_trait;
use futures_util::{Stream, StreamExt};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::pin::Pin;

#[derive(Debug, Serialize)]
struct OllamaRequest {
    model: String,
    prompt: String,
    stream: bool,
    options: Option<OllamaOptions>,
}

#[derive(Debug, Serialize)]
struct OllamaChatRequest {
    model: String,
    messages: Vec<OllamaMessage>,
    stream: bool,
    options: Option<OllamaOptions>,
}

#[derive(Debug, Serialize)]
struct OllamaOptions {
    temperature: f32,
    top_p: f32,
    num_predict: usize,
}

#[derive(Debug, Serialize, Deserialize)]
struct OllamaMessage {
    role: String,
    content: String,
}

#[derive(Debug, Deserialize)]
struct OllamaResponse {
    response: Option<String>,
    done: bool,
}

#[derive(Debug, Deserialize)]
struct OllamaChatResponse {
    message: Option<OllamaMessage>,
    done: bool,
}

#[derive(Debug, Deserialize)]
struct OllamaModel {
    name: String,
    size: u64,
    digest: String,
    modified_at: String,
}

#[derive(Debug, Deserialize)]
struct OllamaModelsResponse {
    models: Vec<OllamaModel>,
}

pub struct OllamaProvider {
    client: Client,
    base_url: String,
    model: String,
    temperature: f32,
    max_tokens: usize,
}

impl OllamaProvider {
    pub fn new() -> Self {
        let base_url = std::env::var("OLLAMA_HOST")
            .unwrap_or_else(|_| "http://localhost:11434".to_string());

        Self {
            client: Client::new(),
            base_url,
            model: "llama2".to_string(),
            temperature: 0.7,
            max_tokens: 2048,
        }
    }

    pub fn with_model(mut self, model: &str) -> Self {
        self.model = model.to_string();
        self
    }

    pub fn with_base_url(mut self, url: &str) -> Self {
        self.base_url = url.to_string();
        self
    }

    async fn generate(&self, prompt: &str, stream: bool) -> Result<reqwest::Response> {
        let request = OllamaRequest {
            model: self.model.clone(),
            prompt: prompt.to_string(),
            stream,
            options: Some(OllamaOptions {
                temperature: self.temperature,
                top_p: 0.9,
                num_predict: self.max_tokens,
            }),
        };

        let response = self.client
            .post(&format!("{}/api/generate", self.base_url))
            .header("Content-Type", "application/json")
            .json(&request)
            .send()
            .await?;

        if !response.status().is_success() {
            let error_text = response.text().await?;
            return Err(anyhow::anyhow!("Ollama API error: {}", error_text));
        }

        Ok(response)
    }

    async fn chat(&self, messages: Vec<OllamaMessage>, stream: bool) -> Result<reqwest::Response> {
        let request = OllamaChatRequest {
            model: self.model.clone(),
            messages,
            stream,
            options: Some(OllamaOptions {
                temperature: self.temperature,
                top_p: 0.9,
                num_predict: self.max_tokens,
            }),
        };

        let response = self.client
            .post(&format!("{}/api/chat", self.base_url))
            .header("Content-Type", "application/json")
            .json(&request)
            .send()
            .await?;

        if !response.status().is_success() {
            let error_text = response.text().await?;
            return Err(anyhow::anyhow!("Ollama API error: {}", error_text));
        }

        Ok(response)
    }

    async fn list_local_models(&self) -> Result<Vec<String>> {
        let response = self.client
            .get(&format!("{}/api/tags", self.base_url))
            .send()
            .await?;

        if !response.status().is_success() {
            return Err(anyhow::anyhow!("Failed to fetch Ollama models"));
        }

        let models_response: OllamaModelsResponse = response.json().await?;
        Ok(models_response.models.into_iter().map(|m| m.name).collect())
    }
}

#[async_trait]
impl super::Provider for OllamaProvider {
    async fn chat(&self, message: &str) -> Result<String> {
        let messages = vec![
            OllamaMessage {
                role: "user".to_string(),
                content: message.to_string(),
            }
        ];

        let response = self.chat(messages, false).await?;
        let text = response.text().await?;

        // Parse JSONL response
        let mut result = String::new();
        for line in text.lines() {
            if let Ok(chat_response) = serde_json::from_str::<OllamaChatResponse>(line) {
                if let Some(message) = chat_response.message {
                    result.push_str(&message.content);
                }
                if chat_response.done {
                    break;
                }
            }
        }

        Ok(result)
    }

    async fn edit_code(&self, code: &str, instruction: &str) -> Result<String> {
        let prompt = format!(
            "Edit the following code according to this instruction: {}\n\nCode:\n```\n{}\n```\n\nProvide only the edited code in a code block.",
            instruction, code
        );

        let messages = vec![
            OllamaMessage {
                role: "system".to_string(),
                content: "You are a code editor. Edit code according to instructions and return only the modified code in a code block.".to_string(),
            },
            OllamaMessage {
                role: "user".to_string(),
                content: prompt,
            }
        ];

        let response = self.chat(messages, false).await?;
        let text = response.text().await?;

        let mut result = String::new();
        for line in text.lines() {
            if let Ok(chat_response) = serde_json::from_str::<OllamaChatResponse>(line) {
                if let Some(message) = chat_response.message {
                    result.push_str(&message.content);
                }
                if chat_response.done {
                    break;
                }
            }
        }

        Ok(result)
    }

    async fn explain_code(&self, code: &str) -> Result<String> {
        let prompt = format!("Explain the following code clearly and concisely:\n\n```\n{}\n```", code);

        let messages = vec![
            OllamaMessage {
                role: "user".to_string(),
                content: prompt,
            }
        ];

        let response = self.chat(messages, false).await?;
        let text = response.text().await?;

        let mut result = String::new();
        for line in text.lines() {
            if let Ok(chat_response) = serde_json::from_str::<OllamaChatResponse>(line) {
                if let Some(message) = chat_response.message {
                    result.push_str(&message.content);
                }
                if chat_response.done {
                    break;
                }
            }
        }

        Ok(result)
    }

    async fn analyze_code(&self, code: &str, analysis_type: &str) -> Result<String> {
        let prompt = format!(
            "Analyze the following code for {} and provide actionable feedback:\n\n```\n{}\n```",
            analysis_type, code
        );

        let messages = vec![
            OllamaMessage {
                role: "user".to_string(),
                content: prompt,
            }
        ];

        let response = self.chat(messages, false).await?;
        let text = response.text().await?;

        let mut result = String::new();
        for line in text.lines() {
            if let Ok(chat_response) = serde_json::from_str::<OllamaChatResponse>(line) {
                if let Some(message) = chat_response.message {
                    result.push_str(&message.content);
                }
                if chat_response.done {
                    break;
                }
            }
        }

        Ok(result)
    }

    async fn create_file(&self, description: &str) -> Result<String> {
        let prompt = format!(
            "Create a complete, working file based on this description: {}\n\nProvide the complete file content in a code block.",
            description
        );

        let messages = vec![
            OllamaMessage {
                role: "system".to_string(),
                content: "You are a code generator. Generate complete, working code files based on descriptions.".to_string(),
            },
            OllamaMessage {
                role: "user".to_string(),
                content: prompt,
            }
        ];

        let response = self.chat(messages, false).await?;
        let text = response.text().await?;

        let mut result = String::new();
        for line in text.lines() {
            if let Ok(chat_response) = serde_json::from_str::<OllamaChatResponse>(line) {
                if let Some(message) = chat_response.message {
                    result.push_str(&message.content);
                }
                if chat_response.done {
                    break;
                }
            }
        }

        Ok(result)
    }

    async fn list_models(&self) -> Vec<String> {
        self.list_local_models().await.unwrap_or_else(|_| {
            vec![
                "llama2".to_string(),
                "llama2:13b".to_string(),
                "llama2:70b".to_string(),
                "codellama".to_string(),
                "codellama:13b".to_string(),
                "codellama:34b".to_string(),
                "mistral".to_string(),
                "mixtral".to_string(),
                "qwen".to_string(),
                "dolphin-mixtral".to_string(),
            ]
        })
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
            OllamaMessage {
                role: "user".to_string(),
                content: message.to_string(),
            }
        ];

        let response = self.chat(messages, true).await?;

        let stream = response
            .bytes_stream()
            .map(|chunk| {
                chunk.map_err(|e| anyhow::anyhow!("Stream error: {}", e))
                    .and_then(|bytes| {
                        let text = String::from_utf8_lossy(&bytes);

                        for line in text.lines() {
                            if let Ok(chat_response) = serde_json::from_str::<OllamaChatResponse>(line) {
                                if let Some(message) = chat_response.message {
                                    return Ok(message.content);
                                }
                            }
                        }

                        Ok(String::new())
                    })
            });

        Ok(Box::pin(stream))
    }
}