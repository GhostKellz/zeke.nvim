use anyhow::Result;
use futures_util::{Stream, StreamExt};
use std::pin::Pin;
use tokio::sync::mpsc;

pub struct StreamHandler {
    sender: mpsc::UnboundedSender<String>,
    receiver: mpsc::UnboundedReceiver<String>,
}

impl StreamHandler {
    pub fn new() -> Self {
        let (sender, receiver) = mpsc::unbounded_channel();
        Self { sender, receiver }
    }

    pub async fn handle_stream(
        &self,
        mut stream: Pin<Box<dyn Stream<Item = Result<String>> + Send>>,
    ) -> Result<String> {
        let mut full_response = String::new();

        while let Some(chunk) = stream.next().await {
            match chunk {
                Ok(text) => {
                    full_response.push_str(&text);
                    let _ = self.sender.send(text);
                }
                Err(e) => {
                    eprintln!("Stream error: {}", e);
                    break;
                }
            }
        }

        Ok(full_response)
    }

    pub async fn next_chunk(&mut self) -> Option<String> {
        self.receiver.recv().await
    }
}

pub struct StreamBuffer {
    buffer: Vec<String>,
    capacity: usize,
}

impl StreamBuffer {
    pub fn new(capacity: usize) -> Self {
        Self {
            buffer: Vec::with_capacity(capacity),
            capacity,
        }
    }

    pub fn push(&mut self, chunk: String) {
        if self.buffer.len() >= self.capacity {
            self.buffer.remove(0);
        }
        self.buffer.push(chunk);
    }

    pub fn get_content(&self) -> String {
        self.buffer.join("")
    }

    pub fn clear(&mut self) {
        self.buffer.clear();
    }
}

pub async fn process_sse_stream(
    response: reqwest::Response,
) -> Result<Pin<Box<dyn Stream<Item = Result<String>> + Send>>> {
    let stream = response
        .bytes_stream()
        .map(|chunk| {
            chunk.map_err(|e| anyhow::anyhow!("Stream error: {}", e))
                .and_then(|bytes| {
                    let text = String::from_utf8_lossy(&bytes);
                    let mut result = String::new();

                    for line in text.lines() {
                        if line.starts_with("data: ") {
                            let data = &line[6..];
                            if data != "[DONE]" {
                                result.push_str(data);
                            }
                        }
                    }

                    Ok(result)
                })
        });

    Ok(Box::pin(stream))
}