use anyhow::Result;
use async_trait::async_trait;
use futures_util::Stream;
use std::pin::Pin;

pub mod openai;
pub mod claude;
pub mod ollama;
pub mod copilot;
pub mod ghostllm;

use ghostllm::{GhostLLMProvider, Provider};
use openai::OpenAIProvider;
use claude::ClaudeProvider;
use ollama::OllamaProvider;
use copilot::CopilotProvider;

#[derive(Debug, Clone)]
pub enum ProviderType {
    OpenAI,
    Claude,
    Ollama,
    Copilot,
    GhostLLM,
}

impl std::str::FromStr for ProviderType {
    type Err = anyhow::Error;

    fn from_str(s: &str) -> Result<Self> {
        match s.to_lowercase().as_str() {
            "openai" | "gpt" => Ok(ProviderType::OpenAI),
            "claude" | "anthropic" => Ok(ProviderType::Claude),
            "ollama" => Ok(ProviderType::Ollama),
            "copilot" | "github" => Ok(ProviderType::Copilot),
            "ghostllm" | "ghost" => Ok(ProviderType::GhostLLM),
            _ => Err(anyhow::anyhow!("Unknown provider: {}", s)),
        }
    }
}

pub struct ProviderManager {
    current_provider: Box<dyn Provider>,
    provider_type: ProviderType,
    ghostllm_enabled: bool,
    ghostllm_base_url: String,
}

impl ProviderManager {
    pub fn new() -> Self {
        // Default to GhostLLM if available, fallback to OpenAI
        let ghostllm_base_url = "http://localhost:8080".to_string();
        let ghostllm_provider = GhostLLMProvider::new(ghostllm_base_url.clone(), None);

        Self {
            current_provider: Box::new(ghostllm_provider),
            provider_type: ProviderType::GhostLLM,
            ghostllm_enabled: true,
            ghostllm_base_url,
        }
    }

    pub fn new_with_config(
        provider_type: ProviderType,
        api_keys: std::collections::HashMap<String, String>,
        ghostllm_config: Option<(String, Option<String>)>, // (base_url, session_token)
    ) -> Result<Self> {
        let (current_provider, actual_type) = match provider_type {
            ProviderType::GhostLLM => {
                if let Some((base_url, session_token)) = ghostllm_config {
                    let provider = GhostLLMProvider::new(base_url.clone(), session_token);
                    (Box::new(provider) as Box<dyn Provider>, ProviderType::GhostLLM)
                } else {
                    // Fallback to default GhostLLM
                    let base_url = "http://localhost:8080".to_string();
                    let provider = GhostLLMProvider::new(base_url, None);
                    (Box::new(provider) as Box<dyn Provider>, ProviderType::GhostLLM)
                }
            }
            ProviderType::OpenAI => {
                let api_key = api_keys.get("openai")
                    .ok_or_else(|| anyhow::anyhow!("OpenAI API key not found"))?;
                let provider = OpenAIProvider::new(api_key.clone())?;
                (Box::new(provider) as Box<dyn Provider>, ProviderType::OpenAI)
            }
            ProviderType::Claude => {
                let api_key = api_keys.get("claude")
                    .ok_or_else(|| anyhow::anyhow!("Claude API key not found"))?;
                let provider = ClaudeProvider::new(api_key.clone())?;
                (Box::new(provider) as Box<dyn Provider>, ProviderType::Claude)
            }
            ProviderType::Ollama => {
                let base_url = api_keys.get("ollama_base_url")
                    .unwrap_or(&"http://localhost:11434".to_string());
                let provider = OllamaProvider::new(base_url.clone())?;
                (Box::new(provider) as Box<dyn Provider>, ProviderType::Ollama)
            }
            ProviderType::Copilot => {
                let token = api_keys.get("copilot")
                    .ok_or_else(|| anyhow::anyhow!("GitHub token not found"))?;
                let provider = CopilotProvider::new(token.clone())?;
                (Box::new(provider) as Box<dyn Provider>, ProviderType::Copilot)
            }
        };

        Ok(Self {
            current_provider,
            provider_type: actual_type,
            ghostllm_enabled: matches!(provider_type, ProviderType::GhostLLM),
            ghostllm_base_url: ghostllm_config
                .map(|(url, _)| url)
                .unwrap_or_else(|| "http://localhost:8080".to_string()),
        })
    }

    pub async fn health_check(&self) -> bool {
        match &self.provider_type {
            ProviderType::GhostLLM => {
                if let Ok(provider) = self.get_ghostllm_provider() {
                    provider.health_check().await.unwrap_or(false)
                } else {
                    false
                }
            }
            _ => true, // Assume other providers are healthy for now
        }
    }

    pub async fn switch_provider(&mut self, provider_type: ProviderType, api_keys: std::collections::HashMap<String, String>) -> Result<()> {
        let new_manager = Self::new_with_config(
            provider_type,
            api_keys,
            Some((self.ghostllm_base_url.clone(), None))
        )?;

        self.current_provider = new_manager.current_provider;
        self.provider_type = new_manager.provider_type;
        Ok(())
    }

    fn get_ghostllm_provider(&self) -> Result<&GhostLLMProvider> {
        if matches!(self.provider_type, ProviderType::GhostLLM) {
            // Safe downcast since we know the type
            Ok(unsafe { &*(self.current_provider.as_ref() as *const dyn Provider as *const GhostLLMProvider) })
        } else {
            Err(anyhow::anyhow!("Current provider is not GhostLLM"))
        }
    }

    pub async fn chat(&self, message: &str) -> Result<String> {
        self.current_provider.chat(message).await
    }

    pub async fn edit_code(&self, code: &str, instruction: &str) -> Result<String> {
        self.current_provider.edit_code(code, instruction).await
    }

    pub async fn explain_code(&self, code: &str) -> Result<String> {
        self.current_provider.explain_code(code).await
    }

    pub async fn analyze_code(&self, code: &str, analysis_type: &str) -> Result<String> {
        self.current_provider.analyze_code(code, analysis_type).await
    }

    pub async fn create_file(&self, description: &str) -> Result<String> {
        self.current_provider.create_file(description).await
    }

    pub async fn list_models(&self) -> Vec<String> {
        self.current_provider.list_models().await
    }

    pub async fn set_model(&mut self, _model: &str) -> Result<()> {
        // For GhostLLM, model switching is handled automatically
        // For other providers, this would need implementation
        Ok(())
    }

    pub async fn get_current_model(&self) -> String {
        match &self.provider_type {
            ProviderType::GhostLLM => "auto (GhostLLM)".to_string(),
            ProviderType::OpenAI => "gpt-4".to_string(),
            ProviderType::Claude => "claude-3-sonnet".to_string(),
            ProviderType::Ollama => "llama3:8b".to_string(),
            ProviderType::Copilot => "copilot".to_string(),
        }
    }

    pub async fn chat_stream(&self, message: &str) -> Result<Pin<Box<dyn Stream<Item = Result<String>> + Send>>> {
        self.current_provider.chat_stream(message).await
    }

    pub fn get_provider_type(&self) -> &ProviderType {
        &self.provider_type
    }

    pub fn is_ghostllm_enabled(&self) -> bool {
        self.ghostllm_enabled
    }
}

impl Default for ProviderManager {
    fn default() -> Self {
        Self::new()
    }
}