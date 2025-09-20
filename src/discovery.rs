use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use std::process::Command;
use tokio::fs;
use tokio::time::{timeout, Duration};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ZekeSessionInfo {
    pub port: u16,
    pub auth_token: String,
    pub session_id: String,
    pub pid: u32,
    pub start_time: u64,
    pub version: String,
}

#[derive(Debug, Clone)]
pub struct ZekeDiscovery {
    session_dir: PathBuf,
}

impl ZekeDiscovery {
    pub fn new() -> Self {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
        let session_dir = PathBuf::from(home).join(".zeke").join("sessions");

        Self { session_dir }
    }

    pub fn with_session_dir<P: AsRef<Path>>(session_dir: P) -> Self {
        Self {
            session_dir: session_dir.as_ref().to_path_buf(),
        }
    }

    /// Discover running Zeke CLI sessions by scanning lock files
    pub async fn discover_sessions(&self) -> Result<Vec<ZekeSessionInfo>> {
        if !self.session_dir.exists() {
            return Ok(Vec::new());
        }

        let mut sessions = Vec::new();
        let mut dir = fs::read_dir(&self.session_dir).await?;

        while let Some(entry) = dir.next_entry().await? {
            if let Some(file_name) = entry.file_name().to_str() {
                if file_name.ends_with(".lock") {
                    if let Ok(session) = self.parse_lock_file(&entry.path()).await {
                        // Verify the session is still active
                        if self.is_session_active(&session).await {
                            sessions.push(session);
                        } else {
                            // Clean up stale lock file
                            let _ = fs::remove_file(&entry.path()).await;
                        }
                    }
                }
            }
        }

        // Sort by start time (newest first)
        sessions.sort_by(|a, b| b.start_time.cmp(&a.start_time));
        Ok(sessions)
    }

    /// Find the most recent active Zeke CLI session
    pub async fn find_active_session(&self) -> Result<Option<ZekeSessionInfo>> {
        let sessions = self.discover_sessions().await?;
        Ok(sessions.into_iter().next())
    }

    /// Start a new Zeke CLI instance with WebSocket server
    pub async fn start_zeke_cli(&self, port: Option<u16>) -> Result<ZekeSessionInfo> {
        // Ensure session directory exists
        fs::create_dir_all(&self.session_dir).await?;

        let port = port.unwrap_or(8081);

        // Start Zeke CLI with WebSocket server
        let mut cmd = Command::new("zeke");
        cmd.args(&[
            "serve",
            "--websocket",
            "--port", &port.to_string(),
            "--session-dir", self.session_dir.to_str().unwrap(),
        ]);

        let child = cmd.spawn()?;
        let pid = child.id();

        // Wait for the session to be ready
        let session_info = timeout(Duration::from_secs(10), async {
            loop {
                if let Ok(Some(session)) = self.find_session_by_port(port).await {
                    return Ok::<ZekeSessionInfo, anyhow::Error>(session);
                }
                tokio::time::sleep(Duration::from_millis(100)).await;
            }
        }).await??;

        tracing::info!("Started Zeke CLI with PID {} on port {}", pid, port);
        Ok(session_info)
    }

    /// Ensure there's an active Zeke CLI connection
    pub async fn ensure_connection(&self) -> Result<ZekeSessionInfo> {
        // First, try to find an existing active session
        if let Some(session) = self.find_active_session().await? {
            tracing::info!("Found active Zeke CLI session on port {}", session.port);
            return Ok(session);
        }

        // No active session found, start a new one
        tracing::info!("No active Zeke CLI session found, starting new instance");
        self.start_zeke_cli(None).await
    }

    async fn find_session_by_port(&self, port: u16) -> Result<Option<ZekeSessionInfo>> {
        let sessions = self.discover_sessions().await?;
        Ok(sessions.into_iter().find(|s| s.port == port))
    }

    async fn parse_lock_file<P: AsRef<Path>>(&self, path: P) -> Result<ZekeSessionInfo> {
        let content = fs::read_to_string(path).await?;
        let session_info: ZekeSessionInfo = serde_json::from_str(&content)?;
        Ok(session_info)
    }

    async fn is_session_active(&self, session: &ZekeSessionInfo) -> bool {
        // Check if process is still running
        if !self.is_process_running(session.pid) {
            return false;
        }

        // Check if WebSocket server is responding
        self.check_websocket_health(session.port).await
    }

    fn is_process_running(&self, pid: u32) -> bool {
        #[cfg(unix)]
        {
            match Command::new("kill").args(&["-0", &pid.to_string()]).status() {
                Ok(status) => status.success(),
                Err(_) => false,
            }
        }

        #[cfg(windows)]
        {
            match Command::new("tasklist")
                .args(&["/FI", &format!("PID eq {}", pid)])
                .output()
            {
                Ok(output) => {
                    let output_str = String::from_utf8_lossy(&output.stdout);
                    output_str.contains(&pid.to_string())
                }
                Err(_) => false,
            }
        }
    }

    async fn check_websocket_health(&self, port: u16) -> bool {
        // Try to connect to the WebSocket endpoint
        let url = format!("ws://localhost:{}/health", port);

        match timeout(Duration::from_secs(2), async {
            tokio_tungstenite::connect_async(&url).await
        }).await {
            Ok(Ok(_)) => true,
            _ => false,
        }
    }

    /// Stop a Zeke CLI session
    pub async fn stop_session(&self, session: &ZekeSessionInfo) -> Result<()> {
        // Try graceful shutdown first
        if let Err(_) = self.send_shutdown_signal(session).await {
            // Force kill if graceful shutdown fails
            self.force_kill_session(session)?;
        }

        // Clean up lock file
        let lock_file = self.session_dir.join(format!("{}.lock", session.session_id));
        if lock_file.exists() {
            fs::remove_file(lock_file).await?;
        }

        Ok(())
    }

    async fn send_shutdown_signal(&self, session: &ZekeSessionInfo) -> Result<()> {
        let url = format!("ws://localhost:{}", session.port);
        let (ws_stream, _) = tokio_tungstenite::connect_async(&url).await?;

        let (mut write, _read) = futures_util::StreamExt::split(ws_stream);

        let shutdown_msg = serde_json::json!({
            "jsonrpc": "2.0",
            "method": "shutdown",
            "params": {},
            "id": "shutdown"
        });

        futures_util::SinkExt::send(&mut write,
            tokio_tungstenite::tungstenite::Message::Text(shutdown_msg.to_string())
        ).await?;

        Ok(())
    }

    fn force_kill_session(&self, session: &ZekeSessionInfo) -> Result<()> {
        #[cfg(unix)]
        {
            Command::new("kill")
                .args(&["-TERM", &session.pid.to_string()])
                .status()?;
        }

        #[cfg(windows)]
        {
            Command::new("taskkill")
                .args(&["/PID", &session.pid.to_string(), "/F"])
                .status()?;
        }

        Ok(())
    }

    /// List all sessions (active and inactive)
    pub async fn list_all_sessions(&self) -> Result<Vec<(ZekeSessionInfo, bool)>> {
        if !self.session_dir.exists() {
            return Ok(Vec::new());
        }

        let mut sessions = Vec::new();
        let mut dir = fs::read_dir(&self.session_dir).await?;

        while let Some(entry) = dir.next_entry().await? {
            if let Some(file_name) = entry.file_name().to_str() {
                if file_name.ends_with(".lock") {
                    if let Ok(session) = self.parse_lock_file(&entry.path()).await {
                        let is_active = self.is_session_active(&session).await;
                        sessions.push((session, is_active));
                    }
                }
            }
        }

        // Sort by start time (newest first)
        sessions.sort_by(|a, b| b.0.start_time.cmp(&a.0.start_time));
        Ok(sessions)
    }

    /// Clean up stale lock files
    pub async fn cleanup_stale_sessions(&self) -> Result<usize> {
        let sessions = self.list_all_sessions().await?;
        let mut cleaned = 0;

        for (session, is_active) in sessions {
            if !is_active {
                let lock_file = self.session_dir.join(format!("{}.lock", session.session_id));
                if lock_file.exists() {
                    fs::remove_file(lock_file).await?;
                    cleaned += 1;
                    tracing::info!("Cleaned up stale session: {}", session.session_id);
                }
            }
        }

        Ok(cleaned)
    }
}

impl Default for ZekeDiscovery {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[tokio::test]
    async fn test_discovery_creation() {
        let discovery = ZekeDiscovery::new();
        assert!(discovery.session_dir.to_string_lossy().contains(".zeke/sessions"));
    }

    #[tokio::test]
    async fn test_custom_session_dir() {
        let temp_dir = TempDir::new().unwrap();
        let discovery = ZekeDiscovery::with_session_dir(temp_dir.path());
        assert_eq!(discovery.session_dir, temp_dir.path());
    }

    #[tokio::test]
    async fn test_discover_sessions_empty_dir() {
        let temp_dir = TempDir::new().unwrap();
        let discovery = ZekeDiscovery::with_session_dir(temp_dir.path());

        let sessions = discovery.discover_sessions().await.unwrap();
        assert!(sessions.is_empty());
    }

    #[test]
    fn test_session_info_serialization() {
        let session = ZekeSessionInfo {
            port: 8081,
            auth_token: "test-token".to_string(),
            session_id: "test-session".to_string(),
            pid: 12345,
            start_time: 1234567890,
            version: "0.1.0".to_string(),
        };

        let serialized = serde_json::to_string(&session).unwrap();
        let deserialized: ZekeSessionInfo = serde_json::from_str(&serialized).unwrap();

        assert_eq!(deserialized.port, 8081);
        assert_eq!(deserialized.auth_token, "test-token");
        assert_eq!(deserialized.session_id, "test-session");
        assert_eq!(deserialized.pid, 12345);
    }
}