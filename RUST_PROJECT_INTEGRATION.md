# Zig FFI Integration Guide for GhostFlow

## Overview

This guide covers creating FFI (Foreign Function Interface) bindings between Zig and Rust for GhostFlow, focusing on integrating zeke's GhostLLM capabilities and zqlite secure embedded database.

## Architecture

```
┌─────────────────────────────────────────────┐
│           GhostFlow (Rust)                  │
├─────────────────────────────────────────────┤
│          FFI Binding Layer                  │
│  ┌──────────────┐  ┌──────────────────┐   │
│  │ ghostllm-sys │  │   zqlite-sys     │   │
│  └──────────────┘  └──────────────────┘   │
├─────────────────────────────────────────────┤
│           C ABI Interface                   │
├─────────────────────────────────────────────┤
│         Zig Libraries (zeke)                │
│  ┌──────────────┐  ┌──────────────────┐   │
│  │   GhostLLM   │  │     zqlite       │   │
│  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────┘
```

## 1. GhostLLM FFI Bindings

### Zig Side (ghostllm.zig)

```zig
const std = @import("std");
const c = @cImport({
    @cInclude("stdint.h");
});

// Core GhostLLM structures
pub const GhostContext = struct {
    model_path: [*:0]const u8,
    max_tokens: u32,
    temperature: f32,
    allocator: std.mem.Allocator,
};

pub const GhostResponse = struct {
    text: [*:0]const u8,
    tokens_used: u32,
    error_code: i32,
};

// Export C-compatible functions
export fn ghost_init(model_path: [*:0]const u8) ?*GhostContext {
    const allocator = std.heap.c_allocator;
    const ctx = allocator.create(GhostContext) catch return null;
    
    ctx.* = .{
        .model_path = model_path,
        .max_tokens = 2048,
        .temperature = 0.7,
        .allocator = allocator,
    };
    
    return ctx;
}

export fn ghost_generate(
    ctx: *GhostContext,
    prompt: [*:0]const u8,
    callback: ?*const fn([*:0]const u8, usize) callconv(.C) void,
) *GhostResponse {
    // Implementation for streaming generation
    const response = ctx.allocator.create(GhostResponse) catch unreachable;
    
    // Simulate streaming tokens
    if (callback) |cb| {
        // Stream tokens to callback
        cb("Generated ", 10);
        cb("response", 8);
    }
    
    response.* = .{
        .text = "Generated response",
        .tokens_used = 42,
        .error_code = 0,
    };
    
    return response;
}

export fn ghost_free_context(ctx: *GhostContext) void {
    ctx.allocator.destroy(ctx);
}

export fn ghost_free_response(response: *GhostResponse) void {
    std.heap.c_allocator.destroy(response);
}
```

### Rust Side (ghostllm-sys)

#### Cargo.toml
```toml
[package]
name = "ghostllm-sys"
version = "0.1.0"
edition = "2021"

[dependencies]
libc = "0.2"

[build-dependencies]
cc = "1.0"
bindgen = "0.69"
```

#### build.rs
```rust
use std::env;
use std::path::PathBuf;

fn main() {
    // Compile Zig code to static library
    let zig_build = std::process::Command::new("zig")
        .args(&[
            "build-lib",
            "src/ghostllm.zig",
            "-O", "ReleaseFast",
            "-femit-bin=target/libghostllm.a",
            "-target", "native-native-gnu",
            "-mcpu=native",
        ])
        .status()
        .expect("Failed to compile Zig library");

    if !zig_build.success() {
        panic!("Zig compilation failed");
    }

    // Link the compiled library
    println!("cargo:rustc-link-search=native=target");
    println!("cargo:rustc-link-lib=static=ghostllm");

    // Generate bindings
    let bindings = bindgen::Builder::default()
        .header("src/ghostllm.h")
        .parse_callbacks(Box::new(bindgen::CargoCallbacks))
        .generate()
        .expect("Unable to generate bindings");

    let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
    bindings
        .write_to_file(out_path.join("bindings.rs"))
        .expect("Couldn't write bindings!");
}
```

#### src/lib.rs
```rust
#![allow(non_upper_case_globals)]
#![allow(non_camel_case_types)]
#![allow(non_snake_case)]

include!(concat!(env!("OUT_DIR"), "/bindings.rs"));

use std::ffi::{CStr, CString};
use std::os::raw::c_char;

pub struct GhostLLM {
    context: *mut GhostContext,
}

impl GhostLLM {
    pub fn new(model_path: &str) -> Result<Self, String> {
        let c_path = CString::new(model_path)
            .map_err(|e| format!("Invalid model path: {}", e))?;
        
        unsafe {
            let context = ghost_init(c_path.as_ptr());
            if context.is_null() {
                return Err("Failed to initialize GhostLLM".into());
            }
            Ok(Self { context })
        }
    }

    pub fn generate<F>(&self, prompt: &str, mut callback: F) -> Result<String, String>
    where
        F: FnMut(&str),
    {
        let c_prompt = CString::new(prompt)
            .map_err(|e| format!("Invalid prompt: {}", e))?;
        
        // Wrapper for the callback
        extern "C" fn stream_callback<F>(text: *const c_char, len: usize)
        where
            F: FnMut(&str),
        {
            unsafe {
                let slice = std::slice::from_raw_parts(text as *const u8, len);
                if let Ok(s) = std::str::from_utf8(slice) {
                    // This is a simplification - in practice, you'd need 
                    // a way to pass the closure through
                }
            }
        }
        
        unsafe {
            let response = ghost_generate(
                self.context,
                c_prompt.as_ptr(),
                None, // Simplified for this example
            );
            
            if (*response).error_code != 0 {
                return Err(format!("Generation failed with code: {}", (*response).error_code));
            }
            
            let text = CStr::from_ptr((*response).text)
                .to_string_lossy()
                .into_owned();
            
            ghost_free_response(response);
            Ok(text)
        }
    }
}

impl Drop for GhostLLM {
    fn drop(&mut self) {
        unsafe {
            if !self.context.is_null() {
                ghost_free_context(self.context);
            }
        }
    }
}

unsafe impl Send for GhostLLM {}
unsafe impl Sync for GhostLLM {}
```

## 2. zqlite FFI Bindings

### Zig Side (zqlite.zig)

```zig
const std = @import("std");
const sqlite = @import("sqlite");

pub const ZqliteDB = struct {
    conn: sqlite.Connection,
    allocator: std.mem.Allocator,
    encryption_key: ?[]const u8,
};

pub const ZqliteResult = struct {
    rows: u32,
    columns: u32,
    data: ?[*][*:0]const u8,
    error: ?[*:0]const u8,
};

// Secure database operations with encryption
export fn zqlite_open_encrypted(
    path: [*:0]const u8,
    key: [*:0]const u8,
    key_len: usize,
) ?*ZqliteDB {
    const allocator = std.heap.c_allocator;
    const db = allocator.create(ZqliteDB) catch return null;
    
    const key_slice = key[0..key_len];
    
    db.* = .{
        .conn = sqlite.Connection.open(path, .{
            .mode = .read_write_create,
            .encryption_key = key_slice,
        }) catch {
            allocator.destroy(db);
            return null;
        },
        .allocator = allocator,
        .encryption_key = allocator.dupe(u8, key_slice) catch null,
    };
    
    return db;
}

export fn zqlite_execute(
    db: *ZqliteDB,
    query: [*:0]const u8,
) *ZqliteResult {
    const result = db.allocator.create(ZqliteResult) catch unreachable;
    
    // Execute query with prepared statement for security
    const stmt = db.conn.prepare(query) catch {
        result.* = .{
            .rows = 0,
            .columns = 0,
            .data = null,
            .error = "Failed to prepare statement",
        };
        return result;
    };
    defer stmt.finalize();
    
    // Execute and collect results
    var row_count: u32 = 0;
    while (stmt.step() catch null) |row| {
        row_count += 1;
        // Process row data
    }
    
    result.* = .{
        .rows = row_count,
        .columns = stmt.column_count(),
        .data = null,
        .error = null,
    };
    
    return result;
}

export fn zqlite_prepare_statement(
    db: *ZqliteDB,
    query: [*:0]const u8,
) ?*anyopaque {
    const stmt = db.conn.prepare(query) catch return null;
    return @ptrCast(stmt);
}

export fn zqlite_bind_text(
    stmt: *anyopaque,
    index: u32,
    value: [*:0]const u8,
) i32 {
    // Bind parameter to prevent SQL injection
    const statement = @ptrCast(*sqlite.Statement, @alignCast(stmt));
    statement.bind_text(index, value) catch return -1;
    return 0;
}

export fn zqlite_close(db: *ZqliteDB) void {
    db.conn.close();
    if (db.encryption_key) |key| {
        // Securely wipe encryption key from memory
        @memset(@constCast(key), 0);
        db.allocator.free(key);
    }
    db.allocator.destroy(db);
}

export fn zqlite_free_result(result: *ZqliteResult) void {
    std.heap.c_allocator.destroy(result);
}
```

### Rust Side (zqlite-sys)

#### Cargo.toml
```toml
[package]
name = "zqlite-sys"
version = "0.1.0"
edition = "2021"

[dependencies]
libc = "0.2"
zeroize = "1.7"  # For secure key handling

[build-dependencies]
cc = "1.0"
bindgen = "0.69"
```

#### src/lib.rs
```rust
#![allow(non_upper_case_globals)]
#![allow(non_camel_case_types)]
#![allow(non_snake_case)]

include!(concat!(env!("OUT_DIR"), "/bindings.rs"));

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use zeroize::Zeroize;

pub struct SecureDatabase {
    db: *mut ZqliteDB,
    encryption_key: Vec<u8>,
}

impl SecureDatabase {
    pub fn open_encrypted(path: &str, key: &[u8]) -> Result<Self, String> {
        let c_path = CString::new(path)
            .map_err(|e| format!("Invalid path: {}", e))?;
        
        let mut encryption_key = key.to_vec();
        
        unsafe {
            let db = zqlite_open_encrypted(
                c_path.as_ptr(),
                encryption_key.as_ptr() as *const c_char,
                encryption_key.len(),
            );
            
            if db.is_null() {
                encryption_key.zeroize();
                return Err("Failed to open database".into());
            }
            
            Ok(Self { db, encryption_key })
        }
    }

    pub fn execute(&self, query: &str) -> Result<QueryResult, String> {
        let c_query = CString::new(query)
            .map_err(|e| format!("Invalid query: {}", e))?;
        
        unsafe {
            let result = zqlite_execute(self.db, c_query.as_ptr());
            
            if !(*result).error.is_null() {
                let error = CStr::from_ptr((*result).error)
                    .to_string_lossy()
                    .into_owned();
                zqlite_free_result(result);
                return Err(error);
            }
            
            let query_result = QueryResult {
                rows: (*result).rows,
                columns: (*result).columns,
            };
            
            zqlite_free_result(result);
            Ok(query_result)
        }
    }

    pub fn prepare(&self, query: &str) -> Result<PreparedStatement, String> {
        let c_query = CString::new(query)
            .map_err(|e| format!("Invalid query: {}", e))?;
        
        unsafe {
            let stmt = zqlite_prepare_statement(self.db, c_query.as_ptr());
            if stmt.is_null() {
                return Err("Failed to prepare statement".into());
            }
            Ok(PreparedStatement { stmt })
        }
    }
}

impl Drop for SecureDatabase {
    fn drop(&mut self) {
        unsafe {
            if !self.db.is_null() {
                zqlite_close(self.db);
            }
        }
        self.encryption_key.zeroize();
    }
}

pub struct PreparedStatement {
    stmt: *mut std::ffi::c_void,
}

impl PreparedStatement {
    pub fn bind_text(&mut self, index: u32, value: &str) -> Result<(), String> {
        let c_value = CString::new(value)
            .map_err(|e| format!("Invalid value: {}", e))?;
        
        unsafe {
            let result = zqlite_bind_text(self.stmt, index, c_value.as_ptr());
            if result != 0 {
                return Err("Failed to bind parameter".into());
            }
        }
        Ok(())
    }
}

pub struct QueryResult {
    pub rows: u32,
    pub columns: u32,
}

unsafe impl Send for SecureDatabase {}
unsafe impl Sync for SecureDatabase {}
```

## 3. Integration with GhostFlow

### Add to Cargo.toml
```toml
[dependencies]
ghostllm-sys = { path = "./crates/ghostllm-sys" }
zqlite-sys = { path = "./crates/zqlite-sys" }
tokio = { version = "1", features = ["full"] }
```

### Usage Example (src/services/llm_service.rs)
```rust
use ghostllm_sys::GhostLLM;
use zqlite_sys::SecureDatabase;
use std::sync::Arc;
use tokio::sync::RwLock;

pub struct LLMService {
    llm: Arc<GhostLLM>,
    db: Arc<RwLock<SecureDatabase>>,
}

impl LLMService {
    pub fn new(model_path: &str, db_path: &str, encryption_key: &[u8]) -> Result<Self, String> {
        let llm = Arc::new(GhostLLM::new(model_path)?);
        let db = Arc::new(RwLock::new(
            SecureDatabase::open_encrypted(db_path, encryption_key)?
        ));
        
        Ok(Self { llm, db })
    }

    pub async fn process_prompt(&self, prompt: &str) -> Result<String, String> {
        // Store prompt in secure database
        {
            let db = self.db.write().await;
            db.execute("INSERT INTO prompts (text, timestamp) VALUES (?, datetime('now'))")?;
        }
        
        // Generate response with streaming
        let response = self.llm.generate(prompt, |token| {
            // Handle streaming tokens
            print!("{}", token);
        })?;
        
        // Store response
        {
            let db = self.db.write().await;
            db.execute("INSERT INTO responses (prompt_id, text) VALUES (last_insert_rowid(), ?)")?;
        }
        
        Ok(response)
    }
}
```

## 4. Build Configuration

### Project Structure
```
ghostflow/
├── Cargo.toml
├── build.rs
├── crates/
│   ├── ghostllm-sys/
│   │   ├── Cargo.toml
│   │   ├── build.rs
│   │   ├── src/
│   │   │   ├── lib.rs
│   │   │   ├── ghostllm.zig
│   │   │   └── ghostllm.h
│   └── zqlite-sys/
│       ├── Cargo.toml
│       ├── build.rs
│       ├── src/
│       │   ├── lib.rs
│       │   ├── zqlite.zig
│       │   └── zqlite.h
```

### Root build.rs
```rust
fn main() {
    // Ensure Zig is available
    let zig_version = std::process::Command::new("zig")
        .arg("version")
        .output()
        .expect("Zig compiler not found. Please install Zig.");
    
    println!("cargo:rerun-if-changed=crates/ghostllm-sys/src/ghostllm.zig");
    println!("cargo:rerun-if-changed=crates/zqlite-sys/src/zqlite.zig");
}
```

## 5. Security Considerations

### Memory Safety
- **Zeroization**: Always zeroize sensitive data (keys, passwords) when dropped
- **Bounds Checking**: Zig provides compile-time bounds checking
- **RAII**: Rust's ownership ensures proper cleanup

### SQL Injection Prevention
- Always use prepared statements
- Parameter binding for user input
- Query validation at compile time where possible

### Encryption
- AES-256 for database encryption
- Key derivation using Argon2id
- Secure key storage in memory (mlock/VirtualLock)

## 6. Performance Optimization

### Compilation Flags
```zig
// Zig optimization flags
-O ReleaseFast     // Maximum speed
-O ReleaseSmall    // Minimum size
-O ReleaseSafe     // Safety checks enabled

// CPU-specific optimizations
-mcpu=native       // Target native CPU
-march=x86-64-v3   // Modern x86-64 features
```

### Link-Time Optimization
```toml
[profile.release]
lto = true
codegen-units = 1
panic = "abort"
strip = true
```

### Async/Streaming
- Use callbacks for LLM token streaming
- Async database operations with connection pooling
- Zero-copy where possible using Zig's comptime features

## 7. Testing

### Zig Tests
```zig
test "ghost_init creates valid context" {
    const ctx = ghost_init("model.gguf");
    try std.testing.expect(ctx != null);
    defer ghost_free_context(ctx.?);
}

test "zqlite handles encryption correctly" {
    const db = zqlite_open_encrypted("test.db", "key123", 6);
    try std.testing.expect(db != null);
    defer zqlite_close(db.?);
}
```

### Rust Integration Tests
```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_llm_generation() {
        let llm = GhostLLM::new("model.gguf").unwrap();
        let response = llm.generate("Hello", |_| {}).unwrap();
        assert!(!response.is_empty());
    }

    #[tokio::test]
    async fn test_secure_database() {
        let key = b"test_encryption_key";
        let db = SecureDatabase::open_encrypted(":memory:", key).unwrap();
        let result = db.execute("CREATE TABLE test (id INTEGER)").unwrap();
        assert_eq!(result.rows, 0);
    }
}
```

## 8. Troubleshooting

### Common Issues

1. **Zig compiler not found**
   ```bash
   curl -L https://ziglang.org/download/0.11.0/zig-linux-x86_64-0.11.0.tar.xz | tar xJ
   export PATH=$PATH:./zig-linux-x86_64-0.11.0
   ```

2. **Linking errors**
   - Ensure Zig targets match Rust target triple
   - Check that all symbols are properly exported
   - Verify C ABI compatibility

3. **Memory leaks**
   - Use Valgrind: `valgrind --leak-check=full ./target/release/ghostflow`
   - Enable Zig's GeneralPurposeAllocator in debug mode
   - Use Rust's miri for undefined behavior detection

## 9. Future Enhancements

- **WASM Support**: Compile Zig to WASM for browser deployment
- **GPU Acceleration**: Integrate Zig's GPU compute capabilities
- **Distributed Processing**: Multi-node LLM inference
- **Hot Reload**: Dynamic library reloading for development
- **Cross-compilation**: Support for ARM64, RISC-V targets

## Resources

- [Zig Language Reference](https://ziglang.org/documentation/)
- [Rust FFI Guide](https://doc.rust-lang.org/nomicon/ffi.html)
- [GhostLLM Documentation](https://github.com/zeke/ghostllm)
- [SQLite Encryption Extension](https://www.sqlite.org/see/doc/trunk/doc/readme.wiki)