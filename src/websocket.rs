use anyhow::Result;
use futures_util::{SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::{mpsc, RwLock};
use tokio_tungstenite::{connect_async, tungstenite::Message};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonRpcRequest {
    pub jsonrpc: String,
    pub method: String,
    pub params: serde_json::Value,
    pub id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonRpcResponse {
    pub jsonrpc: String,
    pub result: Option<serde_json::Value>,
    pub error: Option<JsonRpcError>,
    pub id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonRpcError {
    pub code: i32,
    pub message: String,
    pub data: Option<serde_json::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum StreamMessage {
    ChatDelta { content: String },
    Error { message: String },
    StreamStart { session_id: String },
    StreamEnd { reason: String },
    Ping,
    Pong,
    ActionRequest { action: ActionRequest },
    ActionResponse { approved: bool, session: bool },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActionRequest {
    pub id: String,
    pub action_type: String,
    pub description: String,
    pub file_path: Option<String>,
    pub changes: Option<Vec<FileChange>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileChange {
    pub file_path: String,
    pub content: String,
    pub change_type: String, // "create", "modify", "delete"
}

#[derive(Debug, Clone)]
pub struct ZekeSession {
    pub port: u16,
    pub auth_token: String,
    pub session_id: String,
}

pub struct WebSocketClient {
    session: Option<ZekeSession>,
    sender: Option<mpsc::UnboundedSender<Message>>,
    message_handlers: Arc<RwLock<Vec<Box<dyn Fn(StreamMessage) + Send + Sync>>>>,
}

impl WebSocketClient {
    pub fn new() -> Self {
        Self {
            session: None,
            sender: None,
            message_handlers: Arc::new(RwLock::new(Vec::new())),
        }
    }

    pub async fn connect(&mut self, session: ZekeSession) -> Result<()> {
        let url = format!("ws://localhost:{}", session.port);
        let (ws_stream, _) = connect_async(&url).await?;

        let (mut write, mut read) = ws_stream.split();
        let (tx, mut rx) = mpsc::unbounded_channel();

        // Send authentication
        let auth_message = serde_json::json!({
            "type": "auth",
            "token": session.auth_token
        });
        write.send(Message::Text(auth_message.to_string())).await?;

        self.session = Some(session);
        self.sender = Some(tx.clone());

        let handlers = Arc::clone(&self.message_handlers);

        // Spawn message sender task
        tokio::spawn(async move {
            while let Some(message) = rx.recv().await {
                if let Err(e) = write.send(message).await {
                    tracing::error!("Failed to send WebSocket message: {}", e);
                    break;
                }
            }
        });

        // Spawn message receiver task
        tokio::spawn(async move {
            while let Some(message) = read.next().await {
                match message {
                    Ok(Message::Text(text)) => {
                        if let Ok(stream_msg) = serde_json::from_str::<StreamMessage>(&text) {
                            let handlers = handlers.read().await;
                            for handler in handlers.iter() {
                                handler(stream_msg.clone());
                            }
                        }
                    }
                    Ok(Message::Ping(payload)) => {
                        // Handle ping/pong automatically
                        let _ = tx.send(Message::Pong(payload));
                    }
                    Ok(Message::Close(_)) => {
                        tracing::info!("WebSocket connection closed");
                        break;
                    }
                    Err(e) => {
                        tracing::error!("WebSocket error: {}", e);
                        break;
                    }
                    _ => {}
                }
            }
        });

        Ok(())
    }

    pub async fn send_chat_request(&self, content: &str, context: Option<serde_json::Value>) -> Result<()> {
        let request = JsonRpcRequest {
            jsonrpc: "2.0".to_string(),
            method: "chat_completion".to_string(),
            params: serde_json::json!({
                "messages": [{"role": "user", "content": content}],
                "context": context,
                "stream": true
            }),
            id: Uuid::new_v4().to_string(),
        };

        self.send_message(Message::Text(serde_json::to_string(&request)?)).await
    }

    pub async fn send_action_approval(&self, action_id: &str, approved: bool, session: bool) -> Result<()> {
        let response = StreamMessage::ActionResponse { approved, session };
        let message = serde_json::json!({
            "id": action_id,
            "response": response
        });

        self.send_message(Message::Text(message.to_string())).await
    }

    pub async fn send_provider_switch(&self, provider: &str) -> Result<()> {
        let request = JsonRpcRequest {
            jsonrpc: "2.0".to_string(),
            method: "switch_provider".to_string(),
            params: serde_json::json!({
                "provider": provider
            }),
            id: Uuid::new_v4().to_string(),
        };

        self.send_message(Message::Text(serde_json::to_string(&request)?)).await
    }

    pub async fn send_context_update(&self, context: serde_json::Value) -> Result<()> {
        let request = JsonRpcRequest {
            jsonrpc: "2.0".to_string(),
            method: "update_context".to_string(),
            params: context,
            id: Uuid::new_v4().to_string(),
        };

        self.send_message(Message::Text(serde_json::to_string(&request)?)).await
    }

    async fn send_message(&self, message: Message) -> Result<()> {
        if let Some(sender) = &self.sender {
            sender.send(message)?;
            Ok(())
        } else {
            Err(anyhow::anyhow!("WebSocket not connected"))
        }
    }

    pub async fn add_message_handler<F>(&self, handler: F)
    where
        F: Fn(StreamMessage) + Send + Sync + 'static,
    {
        let mut handlers = self.message_handlers.write().await;
        handlers.push(Box::new(handler));
    }

    pub fn is_connected(&self) -> bool {
        self.session.is_some() && self.sender.is_some()
    }

    pub fn get_session(&self) -> Option<&ZekeSession> {
        self.session.as_ref()
    }
}

impl Default for WebSocketClient {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_websocket_client_creation() {
        let client = WebSocketClient::new();
        assert!(!client.is_connected());
        assert!(client.get_session().is_none());
    }

    #[test]
    fn test_stream_message_serialization() {
        let msg = StreamMessage::ChatDelta {
            content: "Hello, world!".to_string(),
        };

        let serialized = serde_json::to_string(&msg).unwrap();
        let deserialized: StreamMessage = serde_json::from_str(&serialized).unwrap();

        match deserialized {
            StreamMessage::ChatDelta { content } => {
                assert_eq!(content, "Hello, world!");
            }
            _ => panic!("Wrong message type"),
        }
    }

    #[test]
    fn test_json_rpc_request_serialization() {
        let request = JsonRpcRequest {
            jsonrpc: "2.0".to_string(),
            method: "chat_completion".to_string(),
            params: serde_json::json!({"test": "value"}),
            id: "test-id".to_string(),
        };

        let serialized = serde_json::to_string(&request).unwrap();
        let deserialized: JsonRpcRequest = serde_json::from_str(&serialized).unwrap();

        assert_eq!(deserialized.jsonrpc, "2.0");
        assert_eq!(deserialized.method, "chat_completion");
        assert_eq!(deserialized.id, "test-id");
    }
}