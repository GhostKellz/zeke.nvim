use anyhow::Result;
use async_trait::async_trait;
use futures_util::Stream;
use std::pin::Pin;

pub mod openai;
pub mod claude;
pub mod copilot;
pub mod ollama;

#[async_trait]
pub trait AIProvider: Send + Sync {
    async fn chat(&self, message: &str) -> Result<String>;
    async fn edit_code(&self, code: &str, instruction: &str) -> Result<String>;
    async fn explain_code(&self, code: &str) -> Result<String>;
    async fn analyze_code(&self, code: &str, analysis_type: &str) -> Result<String>;
    async fn create_file(&self, description: &str) -> Result<String>;
    async fn list_models(&self) -> Vec<String>;
    async fn set_model(&mut self, model: &str) -> Result<()>;
    async fn get_current_model(&self) -> String;
    async fn chat_stream(&self, message: &str) -> Result<Pin<Box<dyn Stream<Item = Result<String>> + Send>>>;
}

pub struct ProviderManager {
    current_provider: String,
    providers: std::collections::HashMap<String, Box<dyn AIProvider>>,
}

impl ProviderManager {
    pub fn new() -> Self {
        let mut providers = std::collections::HashMap::new();

        providers.insert("openai".to_string(), Box::new(openai::OpenAIProvider::new()) as Box<dyn AIProvider>);
        providers.insert("claude".to_string(), Box::new(claude::ClaudeProvider::new()) as Box<dyn AIProvider>);
        providers.insert("copilot".to_string(), Box::new(copilot::CopilotProvider::new()) as Box<dyn AIProvider>);
        providers.insert("ollama".to_string(), Box::new(ollama::OllamaProvider::new()) as Box<dyn AIProvider>);

        Self {
            current_provider: "openai".to_string(),
            providers,
        }
    }

    pub fn set_provider(&mut self, provider: &str) -> Result<()> {
        if self.providers.contains_key(provider) {
            self.current_provider = provider.to_string();
            Ok(())
        } else {
            Err(anyhow::anyhow!("Provider '{}' not found", provider))
        }
    }

    pub fn get_current_provider(&self) -> &str {
        &self.current_provider
    }

    fn current(&self) -> Result<&dyn AIProvider> {
        self.providers
            .get(&self.current_provider)
            .map(|p| p.as_ref())
            .ok_or_else(|| anyhow::anyhow!("Current provider not found"))
    }

    fn current_mut(&mut self) -> Result<&mut Box<dyn AIProvider>> {
        self.providers
            .get_mut(&self.current_provider)
            .ok_or_else(|| anyhow::anyhow!("Current provider not found"))
    }

    pub async fn chat(&self, message: &str) -> Result<String> {
        self.current()?.chat(message).await
    }

    pub async fn edit_code(&self, code: &str, instruction: &str) -> Result<String> {
        self.current()?.edit_code(code, instruction).await
    }

    pub async fn explain_code(&self, code: &str) -> Result<String> {
        self.current()?.explain_code(code).await
    }

    pub async fn analyze_code(&self, code: &str, analysis_type: &str) -> Result<String> {
        self.current()?.analyze_code(code, analysis_type).await
    }

    pub async fn create_file(&self, description: &str) -> Result<String> {
        self.current()?.create_file(description).await
    }

    pub async fn list_models(&self) -> Vec<String> {
        self.current().map(|p| {
            futures::executor::block_on(p.list_models())
        }).unwrap_or_default()
    }

    pub async fn set_model(&mut self, model: &str) -> Result<()> {
        self.current_mut()?.set_model(model).await
    }

    pub async fn get_current_model(&self) -> String {
        self.current().map(|p| {
            futures::executor::block_on(p.get_current_model())
        }).unwrap_or_else(|_| "unknown".to_string())
    }

    pub async fn chat_stream(&self, message: &str) -> Result<Pin<Box<dyn Stream<Item = Result<String>> + Send>>> {
        self.current()?.chat_stream(message).await
    }
}