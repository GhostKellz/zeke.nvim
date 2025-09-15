use mlua::prelude::*;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub api_keys: HashMap<String, String>,
    pub default_provider: String,
    pub default_model: String,
    pub temperature: f32,
    pub max_tokens: usize,
    pub stream: bool,
    pub auto_reload: bool,
    pub keymaps: Keymaps,
    pub server: ServerConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Keymaps {
    pub chat: Option<String>,
    pub edit: Option<String>,
    pub explain: Option<String>,
    pub create: Option<String>,
    pub analyze: Option<String>,
    pub models: Option<String>,
    pub tasks: Option<String>,
    pub chat_stream: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerConfig {
    pub host: String,
    pub port: u16,
    pub auto_start: bool,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            api_keys: HashMap::new(),
            default_provider: "openai".to_string(),
            default_model: "gpt-4".to_string(),
            temperature: 0.7,
            max_tokens: 2048,
            stream: false,
            auto_reload: true,
            keymaps: Keymaps::default(),
            server: ServerConfig::default(),
        }
    }
}

impl Default for Keymaps {
    fn default() -> Self {
        Self {
            chat: Some("<leader>zc".to_string()),
            edit: Some("<leader>ze".to_string()),
            explain: Some("<leader>zx".to_string()),
            create: Some("<leader>zn".to_string()),
            analyze: Some("<leader>za".to_string()),
            models: Some("<leader>zm".to_string()),
            tasks: Some("<leader>zt".to_string()),
            chat_stream: Some("<leader>zs".to_string()),
        }
    }
}

impl Default for ServerConfig {
    fn default() -> Self {
        Self {
            host: "127.0.0.1".to_string(),
            port: 7777,
            auto_start: true,
        }
    }
}

impl Config {
    pub fn from_lua_table(table: LuaTable) -> LuaResult<Self> {
        let mut config = Config::default();

        if let Ok(api_keys) = table.get::<LuaTable>("api_keys") {
            for pair in api_keys.pairs::<String, String>() {
                let (k, v) = pair?;
                config.api_keys.insert(k, v);
            }
        }

        if let Ok(provider) = table.get::<String>("default_provider") {
            config.default_provider = provider;
        }

        if let Ok(model) = table.get::<String>("default_model") {
            config.default_model = model;
        }

        if let Ok(temp) = table.get::<f32>("temperature") {
            config.temperature = temp;
        }

        if let Ok(tokens) = table.get::<usize>("max_tokens") {
            config.max_tokens = tokens;
        }

        if let Ok(stream) = table.get::<bool>("stream") {
            config.stream = stream;
        }

        if let Ok(auto_reload) = table.get::<bool>("auto_reload") {
            config.auto_reload = auto_reload;
        }

        if let Ok(keymaps_table) = table.get::<LuaTable>("keymaps") {
            let mut keymaps = Keymaps::default();

            if let Ok(chat) = keymaps_table.get::<String>("chat") {
                keymaps.chat = Some(chat);
            }
            if let Ok(edit) = keymaps_table.get::<String>("edit") {
                keymaps.edit = Some(edit);
            }
            if let Ok(explain) = keymaps_table.get::<String>("explain") {
                keymaps.explain = Some(explain);
            }
            if let Ok(create) = keymaps_table.get::<String>("create") {
                keymaps.create = Some(create);
            }
            if let Ok(analyze) = keymaps_table.get::<String>("analyze") {
                keymaps.analyze = Some(analyze);
            }
            if let Ok(models) = keymaps_table.get::<String>("models") {
                keymaps.models = Some(models);
            }
            if let Ok(tasks) = keymaps_table.get::<String>("tasks") {
                keymaps.tasks = Some(tasks);
            }
            if let Ok(chat_stream) = keymaps_table.get::<String>("chat_stream") {
                keymaps.chat_stream = Some(chat_stream);
            }

            config.keymaps = keymaps;
        }

        if let Ok(server_table) = table.get::<LuaTable>("server") {
            let mut server = ServerConfig::default();

            if let Ok(host) = server_table.get::<String>("host") {
                server.host = host;
            }
            if let Ok(port) = server_table.get::<u16>("port") {
                server.port = port;
            }
            if let Ok(auto_start) = server_table.get::<bool>("auto_start") {
                server.auto_start = auto_start;
            }

            config.server = server;
        }

        Ok(config)
    }

    pub fn load_from_env(&mut self) {
        if let Ok(key) = std::env::var("OPENAI_API_KEY") {
            self.api_keys.insert("openai".to_string(), key);
        }
        if let Ok(key) = std::env::var("ANTHROPIC_API_KEY") {
            self.api_keys.insert("claude".to_string(), key);
        }
        if let Ok(key) = std::env::var("GITHUB_TOKEN") {
            self.api_keys.insert("copilot".to_string(), key);
        }
    }
}