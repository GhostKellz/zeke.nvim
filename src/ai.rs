#[allow(unused_imports)]
use anyhow::Result;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatMessage {
    pub role: String,
    pub content: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatRequest {
    pub messages: Vec<ChatMessage>,
    pub model: Option<String>,
    pub temperature: Option<f32>,
    pub max_tokens: Option<usize>,
    pub stream: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatResponse {
    pub content: String,
    pub model: String,
    pub usage: Option<Usage>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Usage {
    pub prompt_tokens: usize,
    pub completion_tokens: usize,
    pub total_tokens: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeEditRequest {
    pub code: String,
    pub instruction: String,
    pub language: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeEditResponse {
    pub edited_code: String,
    pub explanation: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeAnalysis {
    pub issues: Vec<Issue>,
    pub suggestions: Vec<String>,
    pub metrics: Option<CodeMetrics>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Issue {
    pub severity: String,
    pub line: Option<usize>,
    pub column: Option<usize>,
    pub message: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeMetrics {
    pub complexity: usize,
    pub lines_of_code: usize,
    pub maintainability_index: f32,
}

pub fn extract_code_blocks(content: &str) -> Vec<String> {
    let mut code_blocks = Vec::new();
    let mut in_code_block = false;
    let mut current_block = String::new();

    for line in content.lines() {
        if line.starts_with("```") {
            if in_code_block {
                code_blocks.push(current_block.clone());
                current_block.clear();
                in_code_block = false;
            } else {
                in_code_block = true;
            }
        } else if in_code_block {
            if !current_block.is_empty() {
                current_block.push('\n');
            }
            current_block.push_str(line);
        }
    }

    code_blocks
}

pub fn format_code_block(code: &str, language: Option<&str>) -> String {
    match language {
        Some(lang) => format!("```{}\n{}\n```", lang, code),
        None => format!("```\n{}\n```", code),
    }
}

pub fn create_system_prompt(task: &str) -> String {
    format!(
        "You are an expert programming assistant integrated into Neovim. \
         Your task is to {}. Be concise and provide high-quality code.",
        task
    )
}