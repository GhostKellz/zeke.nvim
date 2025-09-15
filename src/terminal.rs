use anyhow::Result;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;

#[derive(Debug, Clone)]
pub struct Task {
    pub id: usize,
    pub command: String,
    pub status: TaskStatus,
    pub output: String,
    pub error: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub enum TaskStatus {
    Pending,
    Running,
    Completed,
    Failed,
    Cancelled,
}

#[derive(Clone)]
pub struct TaskManager {
    tasks: Arc<RwLock<HashMap<usize, Task>>>,
    next_id: Arc<RwLock<usize>>,
}

impl TaskManager {
    pub fn new() -> Self {
        Self {
            tasks: Arc::new(RwLock::new(HashMap::new())),
            next_id: Arc::new(RwLock::new(1)),
        }
    }

    pub async fn create_task(&self, command: String) -> usize {
        let mut next_id = self.next_id.write().await;
        let id = *next_id;
        *next_id += 1;

        let task = Task {
            id,
            command,
            status: TaskStatus::Pending,
            output: String::new(),
            error: None,
        };

        let mut tasks = self.tasks.write().await;
        tasks.insert(id, task);

        id
    }

    pub async fn update_task_status(&self, id: usize, status: TaskStatus) -> Result<()> {
        let mut tasks = self.tasks.write().await;
        if let Some(task) = tasks.get_mut(&id) {
            task.status = status;
            Ok(())
        } else {
            Err(anyhow::anyhow!("Task {} not found", id))
        }
    }

    pub async fn append_output(&self, id: usize, output: &str) -> Result<()> {
        let mut tasks = self.tasks.write().await;
        if let Some(task) = tasks.get_mut(&id) {
            task.output.push_str(output);
            Ok(())
        } else {
            Err(anyhow::anyhow!("Task {} not found", id))
        }
    }

    pub async fn set_error(&self, id: usize, error: String) -> Result<()> {
        let mut tasks = self.tasks.write().await;
        if let Some(task) = tasks.get_mut(&id) {
            task.error = Some(error);
            task.status = TaskStatus::Failed;
            Ok(())
        } else {
            Err(anyhow::anyhow!("Task {} not found", id))
        }
    }

    pub async fn get_task(&self, id: usize) -> Option<Task> {
        let tasks = self.tasks.read().await;
        tasks.get(&id).cloned()
    }

    pub async fn list_tasks(&self) -> Vec<Task> {
        let tasks = self.tasks.read().await;
        tasks.values().cloned().collect()
    }

    pub async fn cancel_task(&self, id: usize) -> Result<()> {
        self.update_task_status(id, TaskStatus::Cancelled).await
    }

    pub async fn cancel_all_tasks(&self) -> Result<()> {
        let mut tasks = self.tasks.write().await;
        for task in tasks.values_mut() {
            if task.status == TaskStatus::Running || task.status == TaskStatus::Pending {
                task.status = TaskStatus::Cancelled;
            }
        }
        Ok(())
    }

    pub async fn get_active_tasks(&self) -> Vec<Task> {
        let tasks = self.tasks.read().await;
        tasks
            .values()
            .filter(|t| t.status == TaskStatus::Running || t.status == TaskStatus::Pending)
            .cloned()
            .collect()
    }

    pub async fn clean_completed_tasks(&self) {
        let mut tasks = self.tasks.write().await;
        tasks.retain(|_, task| {
            task.status != TaskStatus::Completed && task.status != TaskStatus::Cancelled
        });
    }
}

pub struct Terminal {
    task_manager: TaskManager,
}

impl Terminal {
    pub fn new() -> Self {
        Self {
            task_manager: TaskManager::new(),
        }
    }

    pub async fn execute_command(&self, command: String) -> Result<String> {
        let task_id = self.task_manager.create_task(command.clone()).await;
        self.task_manager.update_task_status(task_id, TaskStatus::Running).await?;

        let output = tokio::process::Command::new("sh")
            .arg("-c")
            .arg(&command)
            .output()
            .await?;

        let stdout = String::from_utf8_lossy(&output.stdout).to_string();
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();

        if output.status.success() {
            self.task_manager.append_output(task_id, &stdout).await?;
            self.task_manager.update_task_status(task_id, TaskStatus::Completed).await?;
            Ok(stdout)
        } else {
            self.task_manager.set_error(task_id, stderr.clone()).await?;
            Err(anyhow::anyhow!("Command failed: {}", stderr))
        }
    }

    pub async fn execute_command_async(&self, command: String) -> usize {
        let task_id = self.task_manager.create_task(command.clone()).await;
        let task_manager = self.task_manager.clone();

        tokio::spawn(async move {
            let _ = task_manager.update_task_status(task_id, TaskStatus::Running).await;

            let output = tokio::process::Command::new("sh")
                .arg("-c")
                .arg(&command)
                .output()
                .await;

            match output {
                Ok(output) => {
                    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
                    let stderr = String::from_utf8_lossy(&output.stderr).to_string();

                    if output.status.success() {
                        let _ = task_manager.append_output(task_id, &stdout).await;
                        let _ = task_manager.update_task_status(task_id, TaskStatus::Completed).await;
                    } else {
                        let _ = task_manager.set_error(task_id, stderr).await;
                    }
                }
                Err(e) => {
                    let _ = task_manager.set_error(task_id, e.to_string()).await;
                }
            }
        });

        task_id
    }

    pub fn get_task_manager(&self) -> &TaskManager {
        &self.task_manager
    }
}