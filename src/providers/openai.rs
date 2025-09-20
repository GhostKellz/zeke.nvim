use anyhow::Result;
use async_trait::async_trait;
use futures_util::{Stream, StreamExt};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::pin::Pin;

#[derive(Debug, Serialize)]
struct ChatRequest {
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
struct ChatResponse {
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

pub struct OpenAIProvider {
    client: Client,
    api_key: String,
    model: String,
    temperature: f32,
    max_tokens: usize,
}

impl OpenAIProvider {
    pub fn new() -> Self {
        let api_key = std::env::var("OPENAI_API_KEY").unwrap_or_default();

        Self {
            client: Client::new(),
            api_key,
            model: "gpt-4".to_string(),
            temperature: 0.7,
            max_tokens: 2048,
        }
    }

    async fn make_request(&self, messages: Vec<Message>, stream: bool) -> Result<reqwest::Response> {
        let request = ChatRequest {
            model: self.model.clone(),
            messages,
            temperature: self.temperature,
            max_tokens: self.max_tokens,
            stream,
        };

        let response = self.client
            .post("https://api.openai.com/v1/chat/completions")
            .header("Authorization", format!("Bearer {}", self.api_key))
            .header("Content-Type", "application/json")
            .json(&request)
            .send()
            .await?;

        if !response.status().is_success() {
            let error_text = response.text().await?;
            return Err(anyhow::anyhow!("OpenAI API error: {}", error_text));
        }

        Ok(response)
    }
}

#[async_trait]
impl super::Provider for OpenAIProvider {
    async fn chat(&self, message: &str) -> Result<String> {
        let messages = vec![
            Message {
                role: "user".to_string(),
                content: message.to_string(),
            }
        ];

        let response = self.make_request(messages, false).await?;
        let chat_response: ChatResponse = response.json().await?;

        Ok(chat_response.choices
            .first()
            .map(|c| c.message.content.clone())
            .unwrap_or_default())
    }

    async fn edit_code(&self, code: &str, instruction: &str) -> Result<String> {
        let prompt = format!(
            "Edit the following code according to this instruction: {}\n\nCode:\n```\n{}\n```\n\nProvide the edited code in a code block.",
            instruction, code
        );

        let messages = vec![
            Message {
                role: "system".to_string(),
                content: "You are a code editor. Edit code according to instructions and return only the modified code in a code block.".to_string(),
            },
            Message {
                role: "user".to_string(),
                content: prompt,
            }
        ];

        let response = self.make_request(messages, false).await?;
        let chat_response: ChatResponse = response.json().await?;

        Ok(chat_response.choices
            .first()
            .map(|c| c.message.content.clone())
            .unwrap_or_default())
    }

    async fn explain_code(&self, code: &str) -> Result<String> {
        let prompt = format!("Explain the following code:\n\n```\n{}\n```", code);

        let messages = vec![
            Message {
                role: "system".to_string(),
                content: "You are a code explainer. Provide clear, concise explanations of code.".to_string(),
            },
            Message {
                role: "user".to_string(),
                content: prompt,
            }
        ];

        let response = self.make_request(messages, false).await?;
        let chat_response: ChatResponse = response.json().await?;

        Ok(chat_response.choices
            .first()
            .map(|c| c.message.content.clone())
            .unwrap_or_default())
    }

    async fn analyze_code(&self, code: &str, analysis_type: &str) -> Result<String> {
        let prompt = format!(
            "Analyze the following code for {}:\n\n```\n{}\n```",
            analysis_type, code
        );

        let messages = vec![
            Message {
                role: "system".to_string(),
                content: format!("You are a code analyzer. Analyze code for {} and provide actionable feedback.", analysis_type),
            },
            Message {
                role: "user".to_string(),
                content: prompt,
            }
        ];

        let response = self.make_request(messages, false).await?;
        let chat_response: ChatResponse = response.json().await?;

        Ok(chat_response.choices
            .first()
            .map(|c| c.message.content.clone())
            .unwrap_or_default())
    }

    async fn create_file(&self, description: &str) -> Result<String> {
        let prompt = format!(
            "Create a file based on this description: {}\n\nProvide the complete file content in a code block.",
            description
        );

        let messages = vec![
            Message {
                role: "system".to_string(),
                content: "You are a code generator. Generate complete, working code files based on descriptions.".to_string(),
            },
            Message {
                role: "user".to_string(),
                content: prompt,
            }
        ];

        let response = self.make_request(messages, false).await?;
        let chat_response: ChatResponse = response.json().await?;

        Ok(chat_response.choices
            .first()
            .map(|c| c.message.content.clone())
            .unwrap_or_default())
    }

    async fn list_models(&self) -> Vec<String> {
        vec![
            "gpt-4".to_string(),
            "gpt-4-turbo".to_string(),
            "gpt-3.5-turbo".to_string(),
            "gpt-3.5-turbo-16k".to_string(),
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
                            if json_str.trim() == "[DONE]" {
                                Ok(String::new())
                            } else {
                                serde_json::from_str::<StreamChunk>(json_str)
                                    .map(|chunk| {
                                        chunk.choices.first()
                                            .and_then(|c| c.delta.content.clone())
                                            .unwrap_or_default()
                                    })
                                    .map_err(|e| anyhow::anyhow!("JSON parse error: {}", e))
                            }
                        } else {
                            Ok(String::new())
                        }
                    })
            });

        Ok(Box::pin(stream))
    }
}