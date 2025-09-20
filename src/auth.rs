use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use tokio::process::Command;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuthToken {
    pub token: String,
    pub expires_at: Option<u64>,
    pub refresh_token: Option<String>,
    pub scopes: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuthConfig {
    pub github: Option<GitHubAuth>,
    pub google: Option<GoogleAuth>,
    pub openai: Option<OpenAIAuth>,
    pub anthropic: Option<AnthropicAuth>,
    pub ghostllm: Option<GhostLLMAuth>,
    pub ollama: Option<OllamaAuth>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GitHubAuth {
    pub token: AuthToken,
    pub user_info: Option<GitHubUser>,
    pub copilot_enabled: bool,
    pub has_pro_subscription: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GoogleAuth {
    pub token: AuthToken,
    pub user_info: Option<GoogleUser>,
    pub services: Vec<String>, // ["vertex-ai", "gemini", "grok", etc.]
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OpenAIAuth {
    pub api_key: String,
    pub organization: Option<String>,
    pub usage_limits: Option<UsageLimits>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnthropicAuth {
    pub api_key: String,
    pub usage_limits: Option<UsageLimits>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GhostLLMAuth {
    pub session_token: String,
    pub base_url: String,
    pub user_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OllamaAuth {
    pub base_url: String,
    pub detected_models: Vec<String>,
    pub auto_detected: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GitHubUser {
    pub login: String,
    pub id: u64,
    pub name: Option<String>,
    pub email: Option<String>,
    pub plan: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GoogleUser {
    pub id: String,
    pub email: String,
    pub name: String,
    pub picture: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UsageLimits {
    pub daily_limit: Option<f64>,
    pub monthly_limit: Option<f64>,
    pub current_usage: f64,
}

pub struct AuthManager {
    config: AuthConfig,
    config_path: std::path::PathBuf,
}

impl AuthManager {
    pub fn new() -> Result<Self> {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
        let config_path = std::path::PathBuf::from(home)
            .join(".config")
            .join("zeke")
            .join("auth.json");

        let config = if config_path.exists() {
            let content = std::fs::read_to_string(&config_path)?;
            serde_json::from_str(&content).unwrap_or_default()
        } else {
            AuthConfig::default()
        };

        Ok(Self { config, config_path })
    }

    // GitHub Authentication (OAuth + Copilot)
    pub async fn authenticate_github(&mut self) -> Result<()> {
        tracing::info!("Starting GitHub OAuth authentication...");

        // Step 1: Launch OAuth flow
        let oauth_result = self.github_oauth_flow().await?;

        // Step 2: Get user info and check subscriptions
        let user_info = self.get_github_user_info(&oauth_result.token).await?;
        let copilot_enabled = self.check_copilot_access(&oauth_result.token).await?;

        self.config.github = Some(GitHubAuth {
            token: oauth_result,
            user_info: Some(user_info.clone()),
            copilot_enabled,
            has_pro_subscription: user_info.plan.as_ref().map_or(false, |plan| {
                plan.to_lowercase().contains("pro") || plan.to_lowercase().contains("team")
            }),
        });

        self.save_config()?;
        tracing::info!("GitHub authentication successful!");

        Ok(())
    }

    async fn github_oauth_flow(&self) -> Result<AuthToken> {
        // GitHub Device Flow for CLI applications
        let client = reqwest::Client::new();

        // Step 1: Request device code
        let device_response = client
            .post("https://github.com/login/device/code")
            .header("Accept", "application/json")
            .form(&[
                ("client_id", "your_github_app_client_id"), // Replace with actual client ID
                ("scope", "user copilot read:user"),
            ])
            .send()
            .await?;

        #[derive(Deserialize)]
        struct DeviceCodeResponse {
            device_code: String,
            user_code: String,
            verification_uri: String,
            expires_in: u64,
            interval: u64,
        }

        let device_data: DeviceCodeResponse = device_response.json().await?;

        // Step 2: Show user the verification URL
        println!("🔐 GitHub Authentication Required");
        println!("📱 Please visit: {}", device_data.verification_uri);
        println!("🔑 Enter code: {}", device_data.user_code);
        println!("⏱️  Waiting for authorization...");

        // Open browser automatically
        let _ = Command::new("open")
            .arg(&device_data.verification_uri)
            .spawn();

        // Step 3: Poll for token
        let mut interval = tokio::time::interval(std::time::Duration::from_secs(device_data.interval));
        let start_time = std::time::Instant::now();
        let timeout = std::time::Duration::from_secs(device_data.expires_in);

        loop {
            interval.tick().await;

            if start_time.elapsed() > timeout {
                return Err(anyhow::anyhow!("GitHub authentication timed out"));
            }

            let token_response = client
                .post("https://github.com/login/oauth/access_token")
                .header("Accept", "application/json")
                .form(&[
                    ("client_id", "your_github_app_client_id"),
                    ("device_code", &device_data.device_code),
                    ("grant_type", "urn:ietf:params:oauth:grant-type:device_code"),
                ])
                .send()
                .await?;

            #[derive(Deserialize)]
            struct TokenResponse {
                access_token: Option<String>,
                error: Option<String>,
                scope: Option<String>,
            }

            let token_data: TokenResponse = token_response.json().await?;

            if let Some(error) = token_data.error {
                if error == "authorization_pending" {
                    continue; // Keep polling
                } else {
                    return Err(anyhow::anyhow!("GitHub auth error: {}", error));
                }
            }

            if let Some(access_token) = token_data.access_token {
                return Ok(AuthToken {
                    token: access_token,
                    expires_at: None, // GitHub tokens don't expire
                    refresh_token: None,
                    scopes: token_data.scope
                        .unwrap_or_default()
                        .split(',')
                        .map(|s| s.trim().to_string())
                        .collect(),
                });
            }
        }
    }

    async fn get_github_user_info(&self, token: &str) -> Result<GitHubUser> {
        let client = reqwest::Client::new();
        let response = client
            .get("https://api.github.com/user")
            .header("Authorization", format!("token {}", token))
            .header("User-Agent", "zeke-nvim")
            .send()
            .await?;

        #[derive(Deserialize)]
        struct GitHubUserResponse {
            login: String,
            id: u64,
            name: Option<String>,
            email: Option<String>,
            plan: Option<GitHubPlan>,
        }

        #[derive(Deserialize)]
        struct GitHubPlan {
            name: String,
        }

        let user_data: GitHubUserResponse = response.json().await?;

        Ok(GitHubUser {
            login: user_data.login,
            id: user_data.id,
            name: user_data.name,
            email: user_data.email,
            plan: user_data.plan.map(|p| p.name),
        })
    }

    async fn check_copilot_access(&self, token: &str) -> Result<bool> {
        let client = reqwest::Client::new();
        let response = client
            .get("https://api.github.com/copilot_internal/user")
            .header("Authorization", format!("token {}", token))
            .header("User-Agent", "zeke-nvim")
            .send()
            .await;

        match response {
            Ok(resp) if resp.status().is_success() => Ok(true),
            _ => Ok(false),
        }
    }

    // Google Authentication (OAuth + Multiple Services)
    pub async fn authenticate_google(&mut self) -> Result<()> {
        tracing::info!("Starting Google OAuth authentication...");

        let oauth_result = self.google_oauth_flow().await?;
        let user_info = self.get_google_user_info(&oauth_result.token).await?;
        let services = self.detect_google_services(&oauth_result.token).await?;

        self.config.google = Some(GoogleAuth {
            token: oauth_result,
            user_info: Some(user_info),
            services,
        });

        self.save_config()?;
        tracing::info!("Google authentication successful!");

        Ok(())
    }

    async fn google_oauth_flow(&self) -> Result<AuthToken> {
        // Google Device Flow
        let client = reqwest::Client::new();

        let device_response = client
            .post("https://oauth2.googleapis.com/device/code")
            .form(&[
                ("client_id", "your_google_client_id.apps.googleusercontent.com"),
                ("scope", "openid email profile https://www.googleapis.com/auth/cloud-platform"),
            ])
            .send()
            .await?;

        #[derive(Deserialize)]
        struct GoogleDeviceResponse {
            device_code: String,
            user_code: String,
            verification_url: String,
            expires_in: u64,
            interval: u64,
        }

        let device_data: GoogleDeviceResponse = device_response.json().await?;

        println!("🔐 Google Authentication Required");
        println!("📱 Please visit: {}", device_data.verification_url);
        println!("🔑 Enter code: {}", device_data.user_code);
        println!("⏱️  Waiting for authorization...");

        // Open browser
        let _ = Command::new("open")
            .arg(&device_data.verification_url)
            .spawn();

        // Poll for token
        let mut interval = tokio::time::interval(std::time::Duration::from_secs(device_data.interval));
        let start_time = std::time::Instant::now();
        let timeout = std::time::Duration::from_secs(device_data.expires_in);

        loop {
            interval.tick().await;

            if start_time.elapsed() > timeout {
                return Err(anyhow::anyhow!("Google authentication timed out"));
            }

            let token_response = client
                .post("https://oauth2.googleapis.com/token")
                .form(&[
                    ("client_id", "your_google_client_id.apps.googleusercontent.com"),
                    ("client_secret", "your_google_client_secret"),
                    ("device_code", &device_data.device_code),
                    ("grant_type", "urn:ietf:params:oauth:grant-type:device_code"),
                ])
                .send()
                .await?;

            #[derive(Deserialize)]
            struct GoogleTokenResponse {
                access_token: Option<String>,
                refresh_token: Option<String>,
                expires_in: Option<u64>,
                error: Option<String>,
                scope: Option<String>,
            }

            let token_data: GoogleTokenResponse = token_response.json().await?;

            if let Some(error) = token_data.error {
                if error == "authorization_pending" || error == "slow_down" {
                    continue;
                } else {
                    return Err(anyhow::anyhow!("Google auth error: {}", error));
                }
            }

            if let Some(access_token) = token_data.access_token {
                let expires_at = token_data.expires_in.map(|exp| {
                    std::time::SystemTime::now()
                        .duration_since(std::time::UNIX_EPOCH)
                        .unwrap()
                        .as_secs() + exp
                });

                return Ok(AuthToken {
                    token: access_token,
                    expires_at,
                    refresh_token: token_data.refresh_token,
                    scopes: token_data.scope
                        .unwrap_or_default()
                        .split(' ')
                        .map(|s| s.to_string())
                        .collect(),
                });
            }
        }
    }

    async fn get_google_user_info(&self, token: &str) -> Result<GoogleUser> {
        let client = reqwest::Client::new();
        let response = client
            .get("https://www.googleapis.com/oauth2/v2/userinfo")
            .header("Authorization", format!("Bearer {}", token))
            .send()
            .await?;

        let user_data: GoogleUser = response.json().await?;
        Ok(user_data)
    }

    async fn detect_google_services(&self, token: &str) -> Result<Vec<String>> {
        let mut services = Vec::new();
        let client = reqwest::Client::new();

        // Check Vertex AI access
        if let Ok(response) = client
            .get("https://aiplatform.googleapis.com/v1/projects")
            .header("Authorization", format!("Bearer {}", token))
            .send()
            .await
        {
            if response.status().is_success() {
                services.push("vertex-ai".to_string());
            }
        }

        // Check other Google AI services
        services.push("gemini".to_string()); // Assume Gemini access with OAuth

        Ok(services)
    }

    // OpenAI API Key Authentication
    pub async fn authenticate_openai(&mut self, api_key: String, organization: Option<String>) -> Result<()> {
        // Validate API key
        let client = reqwest::Client::new();
        let mut headers = reqwest::header::HeaderMap::new();
        headers.insert("Authorization", format!("Bearer {}", api_key).parse()?);
        if let Some(org) = &organization {
            headers.insert("OpenAI-Organization", org.parse()?);
        }

        let response = client
            .get("https://api.openai.com/v1/models")
            .headers(headers)
            .send()
            .await?;

        if !response.status().is_success() {
            return Err(anyhow::anyhow!("Invalid OpenAI API key"));
        }

        // Get usage limits (if available)
        let usage_limits = self.get_openai_usage_limits(&api_key).await.ok();

        self.config.openai = Some(OpenAIAuth {
            api_key,
            organization,
            usage_limits,
        });

        self.save_config()?;
        tracing::info!("OpenAI authentication successful!");

        Ok(())
    }

    async fn get_openai_usage_limits(&self, api_key: &str) -> Result<UsageLimits> {
        let client = reqwest::Client::new();
        let response = client
            .get("https://api.openai.com/v1/usage")
            .header("Authorization", format!("Bearer {}", api_key))
            .send()
            .await?;

        if response.status().is_success() {
            // Parse usage data (implementation depends on OpenAI API structure)
            Ok(UsageLimits {
                daily_limit: Some(100.0),
                monthly_limit: Some(1000.0),
                current_usage: 0.0,
            })
        } else {
            Err(anyhow::anyhow!("Could not fetch usage limits"))
        }
    }

    // Anthropic API Key Authentication
    pub async fn authenticate_anthropic(&mut self, api_key: String) -> Result<()> {
        // Validate API key
        let client = reqwest::Client::new();
        let response = client
            .post("https://api.anthropic.com/v1/messages")
            .header("x-api-key", &api_key)
            .header("anthropic-version", "2023-06-01")
            .header("content-type", "application/json")
            .json(&serde_json::json!({
                "model": "claude-3-haiku-20240307",
                "max_tokens": 1,
                "messages": [{"role": "user", "content": "test"}]
            }))
            .send()
            .await?;

        if !response.status().is_success() {
            return Err(anyhow::anyhow!("Invalid Anthropic API key"));
        }

        let usage_limits = self.get_anthropic_usage_limits(&api_key).await.ok();

        self.config.anthropic = Some(AnthropicAuth {
            api_key,
            usage_limits,
        });

        self.save_config()?;
        tracing::info!("Anthropic authentication successful!");

        Ok(())
    }

    async fn get_anthropic_usage_limits(&self, _api_key: &str) -> Result<UsageLimits> {
        // Anthropic doesn't have a public usage API yet
        Ok(UsageLimits {
            daily_limit: None,
            monthly_limit: None,
            current_usage: 0.0,
        })
    }

    // Ollama Detection
    pub async fn detect_ollama(&mut self) -> Result<()> {
        let common_ports = vec![11434, 11435, 11436];
        let common_hosts = vec!["localhost", "127.0.0.1"];

        for host in &common_hosts {
            for &port in &common_ports {
                let base_url = format!("http://{}:{}", host, port);

                if let Ok(models) = self.check_ollama_instance(&base_url).await {
                    self.config.ollama = Some(OllamaAuth {
                        base_url: base_url.clone(),
                        detected_models: models,
                        auto_detected: true,
                    });

                    self.save_config()?;
                    tracing::info!("Ollama detected at {}", base_url);
                    return Ok(());
                }
            }
        }

        Err(anyhow::anyhow!("Ollama not detected on common ports"))
    }

    async fn check_ollama_instance(&self, base_url: &str) -> Result<Vec<String>> {
        let client = reqwest::Client::new();
        let response = client
            .get(&format!("{}/api/tags", base_url))
            .timeout(std::time::Duration::from_secs(2))
            .send()
            .await?;

        if response.status().is_success() {
            #[derive(Deserialize)]
            struct OllamaTagsResponse {
                models: Vec<OllamaModelInfo>,
            }

            #[derive(Deserialize)]
            struct OllamaModelInfo {
                name: String,
            }

            let tags: OllamaTagsResponse = response.json().await?;
            Ok(tags.models.into_iter().map(|m| m.name).collect())
        } else {
            Err(anyhow::anyhow!("Ollama not accessible"))
        }
    }

    // GhostLLM Authentication
    pub async fn authenticate_ghostllm(&mut self, base_url: String, session_token: Option<String>) -> Result<()> {
        let client = reqwest::Client::new();

        // Test connection
        let health_response = client
            .get(&format!("{}/health", base_url))
            .send()
            .await?;

        if !health_response.status().is_success() {
            return Err(anyhow::anyhow!("GhostLLM not accessible at {}", base_url));
        }

        // If session token provided, validate it
        if let Some(token) = &session_token {
            let auth_response = client
                .get(&format!("{}/v1/models", base_url))
                .header("Authorization", format!("Bearer {}", token))
                .send()
                .await?;

            if !auth_response.status().is_success() {
                return Err(anyhow::anyhow!("Invalid GhostLLM session token"));
            }
        }

        self.config.ghostllm = Some(GhostLLMAuth {
            session_token: session_token.unwrap_or_default(),
            base_url,
            user_id: None,
        });

        self.save_config()?;
        tracing::info!("GhostLLM authentication successful!");

        Ok(())
    }

    // Configuration management
    fn save_config(&self) -> Result<()> {
        if let Some(parent) = self.config_path.parent() {
            std::fs::create_dir_all(parent)?;
        }

        let content = serde_json::to_string_pretty(&self.config)?;
        std::fs::write(&self.config_path, content)?;

        Ok(())
    }

    pub fn get_config(&self) -> &AuthConfig {
        &self.config
    }

    pub fn is_authenticated(&self, provider: &str) -> bool {
        match provider {
            "github" => self.config.github.is_some(),
            "google" => self.config.google.is_some(),
            "openai" => self.config.openai.is_some(),
            "anthropic" => self.config.anthropic.is_some(),
            "ollama" => self.config.ollama.is_some(),
            "ghostllm" => self.config.ghostllm.is_some(),
            _ => false,
        }
    }

    pub fn get_provider_credentials(&self, provider: &str) -> Option<HashMap<String, String>> {
        let mut creds = HashMap::new();

        match provider {
            "github" => {
                if let Some(github) = &self.config.github {
                    creds.insert("token".to_string(), github.token.token.clone());
                    if github.copilot_enabled {
                        creds.insert("copilot_enabled".to_string(), "true".to_string());
                    }
                }
            }
            "google" => {
                if let Some(google) = &self.config.google {
                    creds.insert("token".to_string(), google.token.token.clone());
                    if let Some(refresh) = &google.token.refresh_token {
                        creds.insert("refresh_token".to_string(), refresh.clone());
                    }
                }
            }
            "openai" => {
                if let Some(openai) = &self.config.openai {
                    creds.insert("api_key".to_string(), openai.api_key.clone());
                    if let Some(org) = &openai.organization {
                        creds.insert("organization".to_string(), org.clone());
                    }
                }
            }
            "anthropic" => {
                if let Some(anthropic) = &self.config.anthropic {
                    creds.insert("api_key".to_string(), anthropic.api_key.clone());
                }
            }
            "ollama" => {
                if let Some(ollama) = &self.config.ollama {
                    creds.insert("base_url".to_string(), ollama.base_url.clone());
                }
            }
            "ghostllm" => {
                if let Some(ghostllm) = &self.config.ghostllm {
                    creds.insert("base_url".to_string(), ghostllm.base_url.clone());
                    if !ghostllm.session_token.is_empty() {
                        creds.insert("session_token".to_string(), ghostllm.session_token.clone());
                    }
                }
            }
            _ => return None,
        }

        if creds.is_empty() {
            None
        } else {
            Some(creds)
        }
    }
}

impl Default for AuthConfig {
    fn default() -> Self {
        Self {
            github: None,
            google: None,
            openai: None,
            anthropic: None,
            ghostllm: None,
            ollama: None,
        }
    }
}

impl Default for AuthManager {
    fn default() -> Self {
        Self::new().unwrap_or_else(|_| {
            Self {
                config: AuthConfig::default(),
                config_path: std::path::PathBuf::from("/tmp/zeke_auth.json"),
            }
        })
    }
}