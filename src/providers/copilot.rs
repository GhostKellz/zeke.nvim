use anyhow::Result;
use async_trait::async_trait;
use futures_util::Stream;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::pin::Pin;

#[derive(Debug, Serialize)]
struct CompletionRequest {
    prompt: String,
    suffix: String,
    max_tokens: usize,
    temperature: f32,
    top_p: f32,
    n: usize,
    stream: bool,
    stop: Vec<String>,
}

#[derive(Debug, Deserialize)]
struct CompletionResponse {
    choices: Vec<Choice>,
}

#[derive(Debug, Deserialize)]
struct Choice {
    text: String,
}

pub struct CopilotProvider {
    client: Client,
    github_token: String,
    model: String,
    temperature: f32,
    max_tokens: usize,
}

impl CopilotProvider {
    pub fn new() -> Self {
        let github_token = std::env::var("GITHUB_TOKEN").unwrap_or_default();

        Self {
            client: Client::new(),
            github_token,
            model: "copilot".to_string(),
            temperature: 0.7,
            max_tokens: 2048,
        }
    }

    async fn get_copilot_token(&self) -> Result<String> {
        let response = self.client
            .get("https://api.github.com/copilot_internal/v2/token")
            .header("Authorization", format!("token {}", self.github_token))
            .header("Accept", "application/json")
            .send()
            .await?;

        if !response.status().is_success() {
            return Err(anyhow::anyhow!("Failed to get Copilot token"));
        }

        #[derive(Deserialize)]
        struct TokenResponse {
            token: String,
        }

        let token_response: TokenResponse = response.json().await?;
        Ok(token_response.token)
    }

    async fn make_completion_request(&self, prompt: String) -> Result<String> {
        let copilot_token = self.get_copilot_token().await?;

        let request = CompletionRequest {
            prompt,
            suffix: String::new(),
            max_tokens: self.max_tokens,
            temperature: self.temperature,
            top_p: 1.0,
            n: 1,
            stream: false,
            stop: vec![],
        };

        let response = self.client
            .post("https://copilot-proxy.githubusercontent.com/v1/engines/copilot-codex/completions")
            .header("Authorization", format!("Bearer {}", copilot_token))
            .header("Content-Type", "application/json")
            .json(&request)
            .send()
            .await?;

        if !response.status().is_success() {
            let error_text = response.text().await?;
            return Err(anyhow::anyhow!("Copilot API error: {}", error_text));
        }

        let completion_response: CompletionResponse = response.json().await?;

        Ok(completion_response.choices
            .first()
            .map(|c| c.text.clone())
            .unwrap_or_default())
    }
}

#[async_trait]
impl super::Provider for CopilotProvider {
    async fn chat(&self, message: &str) -> Result<String> {
        let prompt = format!("User: {}\nAssistant:", message);
        self.make_completion_request(prompt).await
    }

    async fn edit_code(&self, code: &str, instruction: &str) -> Result<String> {
        let prompt = format!(
            "// Edit instruction: {}\n// Original code:\n{}\n// Edited code:\n",
            instruction, code
        );
        self.make_completion_request(prompt).await
    }

    async fn explain_code(&self, code: &str) -> Result<String> {
        let prompt = format!(
            "// Explain the following code:\n{}\n// Explanation:\n",
            code
        );
        self.make_completion_request(prompt).await
    }

    async fn analyze_code(&self, code: &str, analysis_type: &str) -> Result<String> {
        let prompt = format!(
            "// Analyze the following code for {}:\n{}\n// Analysis:\n",
            analysis_type, code
        );
        self.make_completion_request(prompt).await
    }

    async fn create_file(&self, description: &str) -> Result<String> {
        let prompt = format!(
            "// Create a file with the following description: {}\n// File content:\n",
            description
        );
        self.make_completion_request(prompt).await
    }

    async fn list_models(&self) -> Vec<String> {
        vec!["copilot".to_string()]
    }

    async fn set_model(&mut self, model: &str) -> Result<()> {
        self.model = model.to_string();
        Ok(())
    }

    async fn get_current_model(&self) -> String {
        self.model.clone()
    }

    async fn chat_stream(&self, _message: &str) -> Result<Pin<Box<dyn Stream<Item = Result<String>> + Send>>> {
        Err(anyhow::anyhow!("Streaming not supported for Copilot provider"))
    }
}