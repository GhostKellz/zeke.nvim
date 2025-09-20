# Zeke API Documentation

## Overview

Zeke provides a comprehensive Rust API for AI-powered development workflows. This document covers all public APIs, types, and integration patterns.

## Core API

### ZekeApi

The main entry point for integrating Zeke into other applications.

```rust
use zeke::{ZekeApi, ZekeResult};

let api = ZekeApi::new().await?;
```

#### Methods

##### `new() -> ZekeResult<Self>`

Creates a new ZekeApi instance and initializes default providers.

```rust
#[tokio::main]
async fn main() -> ZekeResult<()> {
    let api = ZekeApi::new().await?;
    Ok(())
}
```

**Returns:** `ZekeResult<ZekeApi>`

**Errors:**
- Provider initialization failures
- Configuration loading errors

##### `ask(provider: &str, question: &str, model: Option<&str>) -> ZekeResult<Response>`

Ask a question to a specific AI provider.

```rust
let response = api.ask("claude", "Explain this Rust code", None).await?;
println!("Response: {}", response.content);

// With specific model
let response = api.ask("openai", "Generate a function", Some("gpt-4")).await?;
```

**Parameters:**
- `provider`: Provider name (`"claude"`, `"openai"`, `"copilot"`, `"ghostllm"`, `"ollama"`, `"deepseek"`)
- `question`: The question or prompt to send
- `model`: Optional specific model name

**Returns:** `ZekeResult<Response>`

**Errors:**
- Provider not available
- API key missing or invalid
- Network connection issues
- Rate limiting

##### `list_providers() -> ZekeResult<Vec<ProviderInfo>>`

Get information about all available providers.

```rust
let providers = api.list_providers().await?;
for provider in providers {
    println!("Provider: {} - Status: {}", provider.name, provider.status);
}
```

**Returns:** `ZekeResult<Vec<ProviderInfo>>`

##### `get_provider_status() -> Vec<(Provider, ProviderHealth)>`

Get detailed health status for all providers.

```rust
let status = api.get_provider_status().await;
for (provider, health) in status {
    println!("{:?}: healthy={}, response_time={:?}",
        provider, health.is_healthy, health.response_time);
}
```

**Returns:** `Vec<(Provider, ProviderHealth)>`

##### `set_current_provider(provider: &str) -> ZekeResult<()>`

Set the default provider for subsequent operations.

```rust
api.set_current_provider("claude").await?;
```

**Parameters:**
- `provider`: Provider name to set as default

**Returns:** `ZekeResult<()>`

#### Git Operations (Feature: `git`)

##### `git() -> ZekeResult<GitManager>`

Get a git manager for the current directory.

```rust
#[cfg(feature = "git")]
{
    let git = api.git()?;
    let status = git.status().await?;
    println!("Current branch: {}", status.branch);
}
```

**Returns:** `ZekeResult<GitManager>`

##### `git_with_path(path: PathBuf) -> GitManager`

Get a git manager for a specific repository path.

```rust
#[cfg(feature = "git")]
{
    let path = std::path::PathBuf::from("/path/to/repo");
    let git = api.git_with_path(path);
}
```

**Parameters:**
- `path`: Path to git repository

**Returns:** `GitManager`

---

## Types

### Response

AI provider response containing the generated content and metadata.

```rust
pub struct Response {
    pub content: String,
    pub provider: String,
    pub model: String,
    pub usage: Option<Usage>,
}
```

**Fields:**
- `content`: The AI-generated response text
- `provider`: Name of the provider that generated the response
- `model`: Specific model used for generation
- `usage`: Optional token usage information

### Usage

Token usage information for AI requests.

```rust
pub struct Usage {
    pub total_tokens: u32,
    pub prompt_tokens: u32,
    pub completion_tokens: u32,
}
```

**Fields:**
- `total_tokens`: Total tokens used (prompt + completion)
- `prompt_tokens`: Tokens used for the input prompt
- `completion_tokens`: Tokens used for the generated response

### ProviderInfo

Information about an AI provider's availability and status.

```rust
pub struct ProviderInfo {
    pub name: String,
    pub status: String,
    pub models: Vec<String>,
}
```

**Fields:**
- `name`: Provider name
- `status`: Current status (`"healthy"`, `"unhealthy"`, `"unknown"`)
- `models`: List of available models (implementation pending)

### Provider

Enum representing supported AI providers.

```rust
pub enum Provider {
    OpenAI,
    Claude,
    Copilot,
    GhostLLM,
    Ollama,
    DeepSeek,
}
```

### ProviderHealth

Detailed health information for a provider.

```rust
pub struct ProviderHealth {
    pub provider: Provider,
    pub is_healthy: bool,
    pub last_check: Instant,
    pub response_time: Duration,
    pub error_rate: f32,
}
```

**Fields:**
- `provider`: The provider this health info relates to
- `is_healthy`: Whether the provider is currently healthy
- `last_check`: Timestamp of last health check
- `response_time`: Average response time
- `error_rate`: Error rate (0.0-1.0)

---

## Git API (Feature: `git`)

### GitManager

Manages git operations for a repository.

#### Methods

##### `new() -> ZekeResult<Self>`

Create a GitManager for the current directory.

```rust
let git = GitManager::new()?;
```

##### `with_path(path: PathBuf) -> Self`

Create a GitManager for a specific path.

```rust
let git = GitManager::with_path(PathBuf::from("/path/to/repo"));
```

##### `status() -> ZekeResult<GitStatus>`

Get the current git status.

```rust
let status = git.status().await?;
println!("Branch: {}", status.branch);
println!("Staged files: {:?}", status.staged);
println!("Modified files: {:?}", status.modified);
```

**Returns:** `ZekeResult<GitStatus>`

##### `add(paths: &[String]) -> ZekeResult<()>`

Add files to the git index.

```rust
git.add(&["src/main.rs".to_string(), "Cargo.toml".to_string()]).await?;
```

**Parameters:**
- `paths`: Array of file paths to add

##### `commit(message: &str) -> ZekeResult<String>`

Create a git commit with the specified message.

```rust
let commit_hash = git.commit("Add new feature").await?;
println!("Created commit: {}", commit_hash);
```

**Parameters:**
- `message`: Commit message

**Returns:** `ZekeResult<String>` - The commit hash

##### `create_branch(branch_name: &str, from_branch: Option<&str>) -> ZekeResult<()>`

Create a new git branch.

```rust
// Create from current branch
git.create_branch("feature/new-feature", None).await?;

// Create from specific branch
git.create_branch("feature/from-main", Some("main")).await?;
```

##### `checkout(branch_name: &str) -> ZekeResult<()>`

Check out a git branch.

```rust
git.checkout("main").await?;
```

##### `push(remote_name: Option<&str>, branch_name: Option<&str>) -> ZekeResult<()>`

Push changes to remote repository.

```rust
// Push current branch to origin
git.push(None, None).await?;

// Push specific branch to specific remote
git.push(Some("upstream"), Some("feature-branch")).await?;
```

##### `create_pull_request(title: &str, body: &str, base: &str, head: &str) -> ZekeResult<String>`

Create a pull request using GitHub CLI.

```rust
let pr_url = git.create_pull_request(
    "Add new feature",
    "This PR adds a new feature with tests",
    "main",
    "feature/new-feature"
).await?;
```

**Returns:** `ZekeResult<String>` - The PR URL

##### `get_recent_commits(count: usize) -> ZekeResult<Vec<CommitInfo>>`

Get recent commit information.

```rust
let commits = git.get_recent_commits(10).await?;
for commit in commits {
    println!("{}: {}", commit.hash, commit.message);
}
```

##### `diff(staged: bool) -> ZekeResult<String>`

Get git diff output.

```rust
// Working directory changes
let diff = git.diff(false).await?;

// Staged changes
let staged_diff = git.diff(true).await?;
```

### GitStatus

Current git repository status.

```rust
pub struct GitStatus {
    pub branch: String,
    pub ahead: usize,
    pub behind: usize,
    pub staged: Vec<String>,
    pub modified: Vec<String>,
    pub untracked: Vec<String>,
    pub conflicts: Vec<String>,
}
```

### CommitInfo

Information about a git commit.

```rust
pub struct CommitInfo {
    pub hash: String,
    pub message: String,
    pub author: String,
    pub timestamp: String,
}
```

---

## Provider System

### ProviderManager

Low-level provider management (usually not needed when using ZekeApi).

#### Methods

##### `new() -> Self`

Create a new provider manager.

##### `initialize_default_providers() -> ZekeResult<()>`

Initialize all available providers based on environment configuration.

##### `chat_completion(request: &ChatRequest) -> ZekeResult<ChatResponse>`

Send a chat completion request with automatic provider selection and fallback.

### ChatRequest

Request structure for chat completions.

```rust
pub struct ChatRequest {
    pub messages: Vec<ChatMessage>,
    pub model: Option<String>,
    pub temperature: Option<f32>,
    pub max_tokens: Option<u32>,
    pub stream: Option<bool>,
}
```

### ChatMessage

Individual message in a chat request.

```rust
pub struct ChatMessage {
    pub role: String,    // "user", "assistant", "system"
    pub content: String,
}
```

### ChatResponse

Response from a chat completion request.

```rust
pub struct ChatResponse {
    pub content: String,
    pub model: String,
    pub provider: Provider,
    pub usage: Option<Usage>,
}
```

---

## Error Handling

### ZekeError

Main error type for all Zeke operations.

```rust
pub enum ZekeError {
    Io(String),
    Network(String),
    Auth(String),
    Provider(String),
    Config(String),
    InvalidInput(String),
    CommandFailed(String),
}
```

### ZekeResult<T>

Type alias for `Result<T, ZekeError>`.

```rust
pub type ZekeResult<T> = Result<T, ZekeError>;
```

#### Error Creation

```rust
// Provider errors
ZekeError::provider("Provider not available")

// Network errors
ZekeError::network("Connection timeout")

// Authentication errors
ZekeError::auth("Invalid API key")

// IO errors
ZekeError::io("File not found")

// Invalid input
ZekeError::invalid_input("Invalid provider name")
```

---

## Configuration

### ZekeConfig

Configuration structure for Zeke settings.

```rust
pub struct ZekeConfig {
    pub providers: HashMap<String, ProviderConfig>,
    pub default_provider: String,
    pub api_timeout: Duration,
    pub max_retries: u32,
}
```

#### Default Configuration

Zeke uses sensible defaults and can work without explicit configuration:

- **Default Provider:** `ghostllm` (if available), falls back to others
- **API Timeout:** 30 seconds
- **Max Retries:** 3
- **Provider Priority:** GhostLLM > Claude > OpenAI > DeepSeek > Copilot > Ollama

---

## Integration Examples

### Basic Integration

```rust
use zeke::{ZekeApi, ZekeResult};

#[tokio::main]
async fn main() -> ZekeResult<()> {
    let api = ZekeApi::new().await?;

    // Simple question
    let response = api.ask("claude", "What is Rust?", None).await?;
    println!("Response: {}", response.content);

    Ok(())
}
```

### Advanced Integration

```rust
use zeke::{ZekeApi, ZekeResult, Provider};

async fn analyze_code_with_fallback(code: &str) -> ZekeResult<String> {
    let api = ZekeApi::new().await?;

    // Try Claude first, then OpenAI
    let providers = ["claude", "openai"];

    for provider in providers {
        match api.ask(provider, &format!("Analyze this code: {}", code), None).await {
            Ok(response) => return Ok(response.content),
            Err(e) => {
                eprintln!("Provider {} failed: {}", provider, e);
                continue;
            }
        }
    }

    Err(zeke::ZekeError::provider("All providers failed"))
}
```

### Git Integration

```rust
use zeke::{ZekeApi, ZekeResult};

async fn ai_commit_message() -> ZekeResult<()> {
    let api = ZekeApi::new().await?;

    #[cfg(feature = "git")]
    {
        let git = api.git()?;

        // Get staged changes
        let diff = git.diff(true).await?;

        if !diff.is_empty() {
            // Ask AI to generate commit message
            let prompt = format!("Generate a commit message for these changes:\n{}", diff);
            let response = api.ask("claude", &prompt, None).await?;

            // Create commit
            let commit_hash = git.commit(&response.content).await?;
            println!("Created commit: {}", commit_hash);
        }
    }

    Ok(())
}
```

---

## Feature Flags

Zeke supports optional features:

### `git` (default)

Enables git operations and GitManager.

```toml
[dependencies]
zeke = { git = "https://github.com/ghostkellz/zeke", features = ["git"] }
```

### `agents` (default)

Enables agent system for specialized AI tasks.

```toml
[dependencies]
zeke = { git = "https://github.com/ghostkellz/zeke", features = ["agents"] }
```

### Minimal Build

For library use without optional features:

```toml
[dependencies]
zeke = { git = "https://github.com/ghostkellz/zeke", default-features = false }
```

---

## Thread Safety

All public APIs are thread-safe and can be used across async tasks:

```rust
use std::sync::Arc;
use zeke::ZekeApi;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let api = Arc::new(ZekeApi::new().await?);

    let tasks: Vec<_> = (0..5).map(|i| {
        let api = api.clone();
        tokio::spawn(async move {
            let response = api.ask("claude", &format!("Question {}", i), None).await?;
            println!("Response {}: {}", i, response.content);
            Ok::<_, zeke::ZekeError>(())
        })
    }).collect();

    futures::future::try_join_all(tasks).await?;
    Ok(())
}
```

---

## Performance Considerations

### Connection Pooling

Zeke automatically manages connection pools for each provider to optimize performance.

### Caching

Provider configurations and health status are cached to reduce initialization overhead.

### Async Design

All operations are fully async and non-blocking, allowing high concurrency.

### Memory Usage

Zeke is designed for minimal memory overhead with efficient data structures and lazy initialization.