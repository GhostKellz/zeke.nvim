const std = @import("std");
const zsync = @import("zsync");
const http = @import("http.zig");
const json = std.json;
const Allocator = std.mem.Allocator;

pub const AIError = error{
    InvalidModel,
    AuthenticationFailed,
    RateLimitExceeded,
    ServiceUnavailable,
    InvalidRequest,
    ResponseParsingFailed,
} || Allocator.Error || http.HttpError;

pub const AIModel = enum {
    openai_gpt4,
    openai_gpt3_5,
    claude_sonnet,
    claude_haiku,
    ollama_llama,
    ollama_codellama,
    gemini_pro,
    
    pub fn toString(self: AIModel) []const u8 {
        return switch (self) {
            .openai_gpt4 => "gpt-4",
            .openai_gpt3_5 => "gpt-3.5-turbo",
            .claude_sonnet => "claude-3-5-sonnet-20241022",
            .claude_haiku => "claude-3-haiku-20240307",
            .ollama_llama => "llama2",
            .ollama_codellama => "codellama",
            .gemini_pro => "gemini-pro",
        };
    }
    
    pub fn fromString(model_str: []const u8) ?AIModel {
        if (std.mem.eql(u8, model_str, "gpt-4")) return .openai_gpt4;
        if (std.mem.eql(u8, model_str, "gpt-3.5-turbo")) return .openai_gpt3_5;
        if (std.mem.eql(u8, model_str, "claude-3-5-sonnet-20241022")) return .claude_sonnet;
        if (std.mem.eql(u8, model_str, "claude-3-haiku-20240307")) return .claude_haiku;
        if (std.mem.eql(u8, model_str, "llama2")) return .ollama_llama;
        if (std.mem.eql(u8, model_str, "codellama")) return .ollama_codellama;
        if (std.mem.eql(u8, model_str, "gemini-pro")) return .gemini_pro;
        return null;
    }
    
    pub fn getProvider(self: AIModel) AIProvider {
        return switch (self) {
            .openai_gpt4, .openai_gpt3_5 => .openai,
            .claude_sonnet, .claude_haiku => .anthropic,
            .ollama_llama, .ollama_codellama => .ollama,
            .gemini_pro => .google,
        };
    }
};

pub const AIProvider = enum {
    openai,
    anthropic,
    ollama,
    google,
    
    pub fn getBaseUrl(self: AIProvider) []const u8 {
        return switch (self) {
            .openai => "https://api.openai.com/v1",
            .anthropic => "https://api.anthropic.com/v1",
            .ollama => "http://localhost:11434/api",
            .google => "https://generativelanguage.googleapis.com/v1",
        };
    }
};

pub const ChatMessage = struct {
    role: []const u8,
    content: []const u8,
};

pub const ChatRequest = struct {
    model: AIModel,
    messages: []const ChatMessage,
    max_tokens: ?u32 = null,
    temperature: ?f32 = null,
    stream: bool = false,
};

pub const ChatResponse = struct {
    content: []const u8,
    model: []const u8,
    usage: ?struct {
        prompt_tokens: u32,
        completion_tokens: u32,
        total_tokens: u32,
    } = null,
    
    const Self = @This();
    
    pub fn deinit(self: *Self, allocator: Allocator) void {
        allocator.free(self.content);
        allocator.free(self.model);
    }
};

pub const AuthConfig = struct {
    openai_api_key: ?[]const u8 = null,
    anthropic_api_key: ?[]const u8 = null,
    google_api_key: ?[]const u8 = null,
    ollama_base_url: ?[]const u8 = null,
    
    pub fn getApiKey(self: AuthConfig, provider: AIProvider) ?[]const u8 {
        return switch (provider) {
            .openai => self.openai_api_key,
            .anthropic => self.anthropic_api_key,
            .google => self.google_api_key,
            .ollama => null, // Ollama typically doesn't require API key
        };
    }
};

pub const AIService = struct {
    allocator: Allocator,
    http_client: *http.HttpClient,
    auth_config: AuthConfig,
    current_model: AIModel,
    
    const Self = @This();
    
    pub fn init(allocator: Allocator, http_client: *http.HttpClient, auth_config: AuthConfig) Self {
        return Self{
            .allocator = allocator,
            .http_client = http_client,
            .auth_config = auth_config,
            .current_model = .openai_gpt3_5, // Default model
        };
    }
    
    pub fn setModel(self: *Self, model: AIModel) void {
        self.current_model = model;
    }
    
    pub fn chat(self: *Self, request: ChatRequest) !ChatResponse {
        const provider = request.model.getProvider();
        
        switch (provider) {
            .openai => return self.chatOpenAI(request),
            .anthropic => return self.chatAnthropic(request),
            .ollama => return self.chatOllama(request),
            .google => return self.chatGoogle(request),
        }
    }
    
    fn chatOpenAI(self: *Self, request: ChatRequest) !ChatResponse {
        const api_key = self.auth_config.getApiKey(.openai) orelse return AIError.AuthenticationFailed;
        
        // Build request body
        var request_obj = json.ObjectMap.init(self.allocator);
        defer request_obj.deinit();
        
        try request_obj.put("model", json.Value{ .string = request.model.toString() });
        try request_obj.put("stream", json.Value{ .bool = request.stream });
        
        if (request.max_tokens) |tokens| {
            try request_obj.put("max_tokens", json.Value{ .integer = @intCast(tokens) });
        }
        
        if (request.temperature) |temp| {
            try request_obj.put("temperature", json.Value{ .float = temp });
        }
        
        // Convert messages
        var messages_array = json.Array.init(self.allocator);
        defer messages_array.deinit();
        
        for (request.messages) |msg| {
            var msg_obj = json.ObjectMap.init(self.allocator);
            defer msg_obj.deinit();
            try msg_obj.put("role", json.Value{ .string = msg.role });
            try msg_obj.put("content", json.Value{ .string = msg.content });
            try messages_array.append(json.Value{ .object = msg_obj });
        }
        
        try request_obj.put("messages", json.Value{ .array = messages_array });
        
        const request_body = try json.stringifyAlloc(self.allocator, json.Value{ .object = request_obj }, .{});
        defer self.allocator.free(request_body);
        
        // Setup headers
        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();
        
        const auth_header = try std.fmt.allocPrint(self.allocator, "Bearer {s}", .{api_key});
        defer self.allocator.free(auth_header);
        
        try headers.put("Authorization", auth_header);
        try headers.put("Content-Type", "application/json");
        
        // Make request
        const url = try std.fmt.allocPrint(self.allocator, "{s}/chat/completions", .{AIProvider.openai.getBaseUrl()});
        defer self.allocator.free(url);
        
        var response = try self.http_client.post(url, headers, request_body);
        defer response.deinit(self.allocator);
        
        if (response.status != 200) {
            return switch (response.status) {
                401 => AIError.AuthenticationFailed,
                429 => AIError.RateLimitExceeded,
                503 => AIError.ServiceUnavailable,
                else => AIError.InvalidRequest,
            };
        }
        
        // Parse response
        const parsed = json.parseFromSlice(json.Value, self.allocator, response.body, .{}) catch return AIError.ResponseParsingFailed;
        defer parsed.deinit();
        
        const choices = parsed.value.object.get("choices") orelse return AIError.ResponseParsingFailed;
        if (choices.array.items.len == 0) return AIError.ResponseParsingFailed;
        
        const message = choices.array.items[0].object.get("message") orelse return AIError.ResponseParsingFailed;
        const content = message.object.get("content") orelse return AIError.ResponseParsingFailed;
        
        return ChatResponse{
            .content = try self.allocator.dupe(u8, content.string),
            .model = try self.allocator.dupe(u8, request.model.toString()),
        };
    }
    
    fn chatAnthropic(self: *Self, request: ChatRequest) !ChatResponse {
        const api_key = self.auth_config.getApiKey(.anthropic) orelse return AIError.AuthenticationFailed;
        
        // Build request body for Claude
        var request_obj = json.ObjectMap.init(self.allocator);
        defer request_obj.deinit();
        
        try request_obj.put("model", json.Value{ .string = request.model.toString() });
        try request_obj.put("max_tokens", json.Value{ .integer = request.max_tokens orelse 1024 });
        
        if (request.temperature) |temp| {
            try request_obj.put("temperature", json.Value{ .float = temp });
        }
        
        // Convert messages (Claude format is slightly different)
        var messages_array = json.Array.init(self.allocator);
        defer messages_array.deinit();
        
        for (request.messages) |msg| {
            // Skip system messages for now, Claude handles them differently
            if (std.mem.eql(u8, msg.role, "system")) continue;
            
            var msg_obj = json.ObjectMap.init(self.allocator);
            defer msg_obj.deinit();
            try msg_obj.put("role", json.Value{ .string = msg.role });
            try msg_obj.put("content", json.Value{ .string = msg.content });
            try messages_array.append(json.Value{ .object = msg_obj });
        }
        
        try request_obj.put("messages", json.Value{ .array = messages_array });
        
        const request_body = try json.stringifyAlloc(self.allocator, json.Value{ .object = request_obj }, .{});
        defer self.allocator.free(request_body);
        
        // Setup headers
        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();
        
        try headers.put("x-api-key", api_key);
        try headers.put("Content-Type", "application/json");
        try headers.put("anthropic-version", "2023-06-01");
        
        // Make request
        const url = try std.fmt.allocPrint(self.allocator, "{s}/messages", .{AIProvider.anthropic.getBaseUrl()});
        defer self.allocator.free(url);
        
        var response = try self.http_client.post(url, headers, request_body);
        defer response.deinit(self.allocator);
        
        if (response.status != 200) {
            return switch (response.status) {
                401 => AIError.AuthenticationFailed,
                429 => AIError.RateLimitExceeded,
                503 => AIError.ServiceUnavailable,
                else => AIError.InvalidRequest,
            };
        }
        
        // Parse response
        const parsed = json.parseFromSlice(json.Value, self.allocator, response.body, .{}) catch return AIError.ResponseParsingFailed;
        defer parsed.deinit();
        
        const content_array = parsed.value.object.get("content") orelse return AIError.ResponseParsingFailed;
        if (content_array.array.items.len == 0) return AIError.ResponseParsingFailed;
        
        const text_content = content_array.array.items[0].object.get("text") orelse return AIError.ResponseParsingFailed;
        
        return ChatResponse{
            .content = try self.allocator.dupe(u8, text_content.string),
            .model = try self.allocator.dupe(u8, request.model.toString()),
        };
    }
    
    fn chatOllama(self: *Self, request: ChatRequest) !ChatResponse {
        // Build request body for Ollama
        var request_obj = json.ObjectMap.init(self.allocator);
        defer request_obj.deinit();
        
        try request_obj.put("model", json.Value{ .string = request.model.toString() });
        try request_obj.put("stream", json.Value{ .bool = false });
        
        // Combine all messages into a single prompt for Ollama
        var prompt = std.ArrayList(u8).init(self.allocator);
        defer prompt.deinit();
        
        for (request.messages) |msg| {
            try prompt.writer().print("[{s}]: {s}\n", .{ msg.role, msg.content });
        }
        
        try request_obj.put("prompt", json.Value{ .string = prompt.items });
        
        const request_body = try json.stringifyAlloc(self.allocator, json.Value{ .object = request_obj }, .{});
        defer self.allocator.free(request_body);
        
        // Setup headers
        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();
        try headers.put("Content-Type", "application/json");
        
        // Make request
        const base_url = self.auth_config.ollama_base_url orelse AIProvider.ollama.getBaseUrl();
        const url = try std.fmt.allocPrint(self.allocator, "{s}/generate", .{base_url});
        defer self.allocator.free(url);
        
        var response = try self.http_client.post(url, headers, request_body);
        defer response.deinit(self.allocator);
        
        if (response.status != 200) {
            return AIError.ServiceUnavailable;
        }
        
        // Parse response
        const parsed = json.parseFromSlice(json.Value, self.allocator, response.body, .{}) catch return AIError.ResponseParsingFailed;
        defer parsed.deinit();
        
        const response_text = parsed.value.object.get("response") orelse return AIError.ResponseParsingFailed;
        
        return ChatResponse{
            .content = try self.allocator.dupe(u8, response_text.string),
            .model = try self.allocator.dupe(u8, request.model.toString()),
        };
    }
    
    fn chatGoogle(self: *Self, request: ChatRequest) !ChatResponse {
        const api_key = self.auth_config.getApiKey(.google) orelse return AIError.AuthenticationFailed;
        
        // Build request body for Gemini
        var request_obj = json.ObjectMap.init(self.allocator);
        defer request_obj.deinit();
        
        // Convert messages to Gemini format
        var contents_array = json.Array.init(self.allocator);
        defer contents_array.deinit();
        
        for (request.messages) |msg| {
            var content_obj = json.ObjectMap.init(self.allocator);
            defer content_obj.deinit();
            
            // Map roles
            const role = if (std.mem.eql(u8, msg.role, "assistant")) "model" else "user";
            try content_obj.put("role", json.Value{ .string = role });
            
            var parts_array = json.Array.init(self.allocator);
            defer parts_array.deinit();
            
            var part_obj = json.ObjectMap.init(self.allocator);
            defer part_obj.deinit();
            try part_obj.put("text", json.Value{ .string = msg.content });
            try parts_array.append(json.Value{ .object = part_obj });
            
            try content_obj.put("parts", json.Value{ .array = parts_array });
            try contents_array.append(json.Value{ .object = content_obj });
        }
        
        try request_obj.put("contents", json.Value{ .array = contents_array });
        
        const request_body = try json.stringifyAlloc(self.allocator, json.Value{ .object = request_obj }, .{});
        defer self.allocator.free(request_body);
        
        // Setup headers
        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();
        try headers.put("Content-Type", "application/json");
        
        // Make request
        const url = try std.fmt.allocPrint(self.allocator, "{s}/models/{s}:generateContent?key={s}", .{ 
            AIProvider.google.getBaseUrl(), 
            request.model.toString(), 
            api_key 
        });
        defer self.allocator.free(url);
        
        var response = try self.http_client.post(url, headers, request_body);
        defer response.deinit(self.allocator);
        
        if (response.status != 200) {
            return switch (response.status) {
                401 => AIError.AuthenticationFailed,
                429 => AIError.RateLimitExceeded,
                503 => AIError.ServiceUnavailable,
                else => AIError.InvalidRequest,
            };
        }
        
        // Parse response
        const parsed = json.parseFromSlice(json.Value, self.allocator, response.body, .{}) catch return AIError.ResponseParsingFailed;
        defer parsed.deinit();
        
        const candidates = parsed.value.object.get("candidates") orelse return AIError.ResponseParsingFailed;
        if (candidates.array.items.len == 0) return AIError.ResponseParsingFailed;
        
        const content = candidates.array.items[0].object.get("content") orelse return AIError.ResponseParsingFailed;
        const parts = content.object.get("parts") orelse return AIError.ResponseParsingFailed;
        if (parts.array.items.len == 0) return AIError.ResponseParsingFailed;
        
        const text = parts.array.items[0].object.get("text") orelse return AIError.ResponseParsingFailed;
        
        return ChatResponse{
            .content = try self.allocator.dupe(u8, text.string),
            .model = try self.allocator.dupe(u8, request.model.toString()),
        };
    }
};