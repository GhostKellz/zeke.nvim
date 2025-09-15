use mlua::prelude::*;
use std::sync::Arc;
use tokio::sync::RwLock;

mod ai;
mod config;
mod providers;
mod streaming;
mod terminal;

use config::Config;
use providers::ProviderManager;

#[derive(Clone)]
pub struct ZekeState {
    config: Arc<RwLock<Config>>,
    provider_manager: Arc<RwLock<ProviderManager>>,
    runtime: Arc<tokio::runtime::Runtime>,
}

impl ZekeState {
    fn new() -> LuaResult<Self> {
        let runtime = tokio::runtime::Runtime::new()
            .map_err(|e| LuaError::RuntimeError(format!("Failed to create runtime: {}", e)))?;

        Ok(Self {
            config: Arc::new(RwLock::new(Config::default())),
            provider_manager: Arc::new(RwLock::new(ProviderManager::new())),
            runtime: Arc::new(runtime),
        })
    }
}

fn setup(lua: &Lua, opts: LuaTable) -> LuaResult<()> {
    let state = lua.app_data_ref::<ZekeState>()
        .ok_or_else(|| LuaError::RuntimeError("Zeke state not initialized".to_string()))?;

    let config = Config::from_lua_table(opts)?;

    state.runtime.block_on(async {
        *state.config.write().await = config;
    });

    Ok(())
}

fn chat(lua: &Lua, message: String) -> LuaResult<String> {
    let state = lua.app_data_ref::<ZekeState>()
        .ok_or_else(|| LuaError::RuntimeError("Zeke state not initialized".to_string()))?;

    state.runtime.block_on(async {
        let provider = state.provider_manager.read().await;
        match provider.chat(&message).await {
            Ok(response) => Ok(response),
            Err(e) => Err(LuaError::RuntimeError(format!("Chat failed: {}", e)))
        }
    })
}

fn edit_code(lua: &Lua, (code, instruction): (String, String)) -> LuaResult<String> {
    let state = lua.app_data_ref::<ZekeState>()
        .ok_or_else(|| LuaError::RuntimeError("Zeke state not initialized".to_string()))?;

    state.runtime.block_on(async {
        let provider = state.provider_manager.read().await;
        match provider.edit_code(&code, &instruction).await {
            Ok(response) => Ok(response),
            Err(e) => Err(LuaError::RuntimeError(format!("Edit failed: {}", e)))
        }
    })
}

fn explain_code(lua: &Lua, code: String) -> LuaResult<String> {
    let state = lua.app_data_ref::<ZekeState>()
        .ok_or_else(|| LuaError::RuntimeError("Zeke state not initialized".to_string()))?;

    state.runtime.block_on(async {
        let provider = state.provider_manager.read().await;
        match provider.explain_code(&code).await {
            Ok(response) => Ok(response),
            Err(e) => Err(LuaError::RuntimeError(format!("Explain failed: {}", e)))
        }
    })
}

fn analyze_code(lua: &Lua, (code, analysis_type): (String, String)) -> LuaResult<String> {
    let state = lua.app_data_ref::<ZekeState>()
        .ok_or_else(|| LuaError::RuntimeError("Zeke state not initialized".to_string()))?;

    state.runtime.block_on(async {
        let provider = state.provider_manager.read().await;
        match provider.analyze_code(&code, &analysis_type).await {
            Ok(response) => Ok(response),
            Err(e) => Err(LuaError::RuntimeError(format!("Analysis failed: {}", e)))
        }
    })
}

fn create_file(lua: &Lua, description: String) -> LuaResult<String> {
    let state = lua.app_data_ref::<ZekeState>()
        .ok_or_else(|| LuaError::RuntimeError("Zeke state not initialized".to_string()))?;

    state.runtime.block_on(async {
        let provider = state.provider_manager.read().await;
        match provider.create_file(&description).await {
            Ok(response) => Ok(response),
            Err(e) => Err(LuaError::RuntimeError(format!("Create file failed: {}", e)))
        }
    })
}

fn list_models(lua: &Lua, _: ()) -> LuaResult<Vec<String>> {
    let state = lua.app_data_ref::<ZekeState>()
        .ok_or_else(|| LuaError::RuntimeError("Zeke state not initialized".to_string()))?;

    state.runtime.block_on(async {
        let provider = state.provider_manager.read().await;
        Ok(provider.list_models().await)
    })
}

fn set_model(lua: &Lua, model: String) -> LuaResult<()> {
    let state = lua.app_data_ref::<ZekeState>()
        .ok_or_else(|| LuaError::RuntimeError("Zeke state not initialized".to_string()))?;

    state.runtime.block_on(async {
        let mut provider = state.provider_manager.write().await;
        match provider.set_model(&model).await {
            Ok(_) => Ok(()),
            Err(e) => Err(LuaError::RuntimeError(format!("Failed to set model: {}", e)))
        }
    })
}

fn get_current_model(lua: &Lua, _: ()) -> LuaResult<String> {
    let state = lua.app_data_ref::<ZekeState>()
        .ok_or_else(|| LuaError::RuntimeError("Zeke state not initialized".to_string()))?;

    state.runtime.block_on(async {
        let provider = state.provider_manager.read().await;
        Ok(provider.get_current_model().await)
    })
}

fn chat_stream(lua: &Lua, (message, callback): (String, LuaFunction)) -> LuaResult<()> {
    let state = lua.app_data_ref::<ZekeState>()
        .ok_or_else(|| LuaError::RuntimeError("Zeke state not initialized".to_string()))?
        .clone();

    let _callback_registry = lua.create_registry_value(callback)?;

    state.runtime.spawn(async move {
        let provider = state.provider_manager.read().await;
        let stream = provider.chat_stream(&message).await;

        match stream {
            Ok(mut stream) => {
                use futures_util::StreamExt;
                while let Some(chunk) = stream.next().await {
                    match chunk {
                        Ok(_text) => {
                        }
                        Err(e) => {
                            eprintln!("Stream error: {}", e);
                            break;
                        }
                    }
                }
            }
            Err(e) => {
                eprintln!("Failed to start stream: {}", e);
            }
        }
    });

    Ok(())
}

#[mlua::lua_module]
fn zeke_nvim(lua: &Lua) -> LuaResult<LuaTable> {
    let state = ZekeState::new()?;
    lua.set_app_data(state);

    let exports = lua.create_table()?;

    exports.set("setup", lua.create_function(setup)?)?;
    exports.set("chat", lua.create_function(chat)?)?;
    exports.set("edit_code", lua.create_function(edit_code)?)?;
    exports.set("explain_code", lua.create_function(explain_code)?)?;
    exports.set("analyze_code", lua.create_function(analyze_code)?)?;
    exports.set("create_file", lua.create_function(create_file)?)?;
    exports.set("list_models", lua.create_function(list_models)?)?;
    exports.set("set_model", lua.create_function(set_model)?)?;
    exports.set("get_current_model", lua.create_function(get_current_model)?)?;
    exports.set("chat_stream", lua.create_function(chat_stream)?)?;

    Ok(exports)
}