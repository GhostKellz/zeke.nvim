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
        const OpenAIRequest = struct {
            model: []const u8,
            messages: []const struct {
                role: []const u8,
                content: []const u8,
            },
            max_tokens: ?u32 = null,
            temperature: ?f32 = null,
            stream: bool = false,
        };
        
        var messages_list = std.ArrayList(struct {
            role: []const u8,
            content: []const u8,
        }){};
        defer messages_list.deinit(self.allocator);
        
        for (request.messages) |msg| {
            try messages_list.append(self.allocator, .{
                .role = msg.role,
                .content = msg.content,
            });
        }
        
        const openai_request = OpenAIRequest{
            .model = request.model.toString(),
            .messages = messages_list.items,
            .max_tokens = request.max_tokens,
            .temperature = request.temperature,
            .stream = request.stream,
        };
        
        var request_body_list = std.ArrayList(u8){};
        defer request_body_list.deinit(self.allocator);
        
        try std.json.Stringify.value(openai_request, .{}, request_body_list.writer(self.allocator));
        
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
        
        var response = try self.http_client.post(url, headers, request_body_list.items);
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
        const OpenAIResponse = struct {
            choices: []struct {
                message: struct {
                    content: []const u8,
                },
            },
        };
        
        const parsed = json.parseFromSlice(OpenAIResponse, self.allocator, response.body, .{}) catch return AIError.ResponseParsingFailed;
        defer parsed.deinit();
        
        if (parsed.value.choices.len == 0) return AIError.ResponseParsingFailed;
        const content = parsed.value.choices[0].message.content;
        
        return ChatResponse{
            .content = try self.allocator.dupe(u8, content),
            .model = try self.allocator.dupe(u8, request.model.toString()),
        };
    }
    
    fn chatAnthropic(self: *Self, request: ChatRequest) !ChatResponse {
        const api_key = self.auth_config.getApiKey(.anthropic) orelse return AIError.AuthenticationFailed;
        
        // Build request body for Claude
        const ClaudeRequest = struct {
            model: []const u8,
            messages: []const struct {
                role: []const u8,
                content: []const u8,
            },
            max_tokens: u32,
            temperature: ?f32 = null,
        };
        
        var messages_list = std.ArrayList(struct {
            role: []const u8,
            content: []const u8,
        }){};
        defer messages_list.deinit(self.allocator);
        
        for (request.messages) |msg| {
            // Skip system messages for now, Claude handles them differently
            if (std.mem.eql(u8, msg.role, "system")) continue;
            
            try messages_list.append(self.allocator, .{
                .role = msg.role,
                .content = msg.content,
            });
        }
        
        const claude_request = ClaudeRequest{
            .model = request.model.toString(),
            .messages = messages_list.items,
            .max_tokens = request.max_tokens orelse 1024,
            .temperature = request.temperature,
        };
        
        var request_body_list = std.ArrayList(u8){};
        defer request_body_list.deinit(self.allocator);
        
        try std.json.Stringify.value(claude_request, .{}, request_body_list.writer(self.allocator));
        
        // Setup headers
        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();
        
        try headers.put("x-api-key", api_key);
        try headers.put("Content-Type", "application/json");
        try headers.put("anthropic-version", "2023-06-01");
        
        // Make request
        const url = try std.fmt.allocPrint(self.allocator, "{s}/messages", .{AIProvider.anthropic.getBaseUrl()});
        defer self.allocator.free(url);
        
        var response = try self.http_client.post(url, headers, request_body_list.items);
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
        const ClaudeResponse = struct {
            content: []struct {
                text: []const u8,
            },
        };
        
        const parsed = json.parseFromSlice(ClaudeResponse, self.allocator, response.body, .{}) catch return AIError.ResponseParsingFailed;
        defer parsed.deinit();
        
        if (parsed.value.content.len == 0) return AIError.ResponseParsingFailed;
        const text_content = parsed.value.content[0].text;
        
        return ChatResponse{
            .content = try self.allocator.dupe(u8, text_content),
            .model = try self.allocator.dupe(u8, request.model.toString()),
        };
    }
    
    fn chatOllama(self: *Self, request: ChatRequest) !ChatResponse {
        // Build request body for Ollama
        const OllamaRequest = struct {
            model: []const u8,
            prompt: []const u8,
            stream: bool = false,
        };
        
        // Combine all messages into a single prompt for Ollama
        var prompt = std.ArrayList(u8){};
        defer prompt.deinit(self.allocator);
        
        for (request.messages) |msg| {
            try prompt.writer(self.allocator).print("[{s}]: {s}\n", .{ msg.role, msg.content });
        }
        
        const ollama_request = OllamaRequest{
            .model = request.model.toString(),
            .prompt = prompt.items,
            .stream = false,
        };
        
        var request_body_list = std.ArrayList(u8){};
        defer request_body_list.deinit(self.allocator);
        
        try std.json.Stringify.value(ollama_request, .{}, request_body_list.writer(self.allocator));
        
        // Setup headers
        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();
        try headers.put("Content-Type", "application/json");
        
        // Make request
        const base_url = self.auth_config.ollama_base_url orelse AIProvider.ollama.getBaseUrl();
        const url = try std.fmt.allocPrint(self.allocator, "{s}/generate", .{base_url});
        defer self.allocator.free(url);
        
        var response = try self.http_client.post(url, headers, request_body_list.items);
        defer response.deinit(self.allocator);
        
        if (response.status != 200) {
            return AIError.ServiceUnavailable;
        }
        
        // Parse response
        const OllamaResponse = struct {
            response: []const u8,
        };
        
        const parsed = json.parseFromSlice(OllamaResponse, self.allocator, response.body, .{}) catch return AIError.ResponseParsingFailed;
        defer parsed.deinit();
        
        return ChatResponse{
            .content = try self.allocator.dupe(u8, parsed.value.response),
            .model = try self.allocator.dupe(u8, request.model.toString()),
        };
    }
    
    fn chatGoogle(self: *Self, request: ChatRequest) !ChatResponse {
        const api_key = self.auth_config.getApiKey(.google) orelse return AIError.AuthenticationFailed;
        
        // Build request body for Gemini
        const GeminiRequest = struct {
            contents: []const struct {
                role: []const u8,
                parts: []const struct {
                    text: []const u8,
                },
            },
        };
        
        var contents_list = std.ArrayList(struct {
            role: []const u8,
            parts: []const struct {
                text: []const u8,
            },
        }){};
        defer contents_list.deinit(self.allocator);
        
        for (request.messages) |msg| {
            // Map roles
            const role = if (std.mem.eql(u8, msg.role, "assistant")) "model" else "user";
            
            var parts = std.ArrayList(struct { text: []const u8 }){};
            defer parts.deinit(self.allocator);
            try parts.append(self.allocator, .{ .text = msg.content });
            
            try contents_list.append(self.allocator, .{
                .role = role,
                .parts = parts.items,
            });
        }
        
        const gemini_request = GeminiRequest{
            .contents = contents_list.items,
        };
        
        var request_body_list = std.ArrayList(u8){};
        defer request_body_list.deinit(self.allocator);
        
        try std.json.Stringify.value(gemini_request, .{}, request_body_list.writer(self.allocator));
        
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
        
        var response = try self.http_client.post(url, headers, request_body_list.items);
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
        const GeminiResponse = struct {
            candidates: []struct {
                content: struct {
                    parts: []struct {
                        text: []const u8,
                    },
                },
            },
        };
        
        const parsed = json.parseFromSlice(GeminiResponse, self.allocator, response.body, .{}) catch return AIError.ResponseParsingFailed;
        defer parsed.deinit();
        
        if (parsed.value.candidates.len == 0) return AIError.ResponseParsingFailed;
        const content = parsed.value.candidates[0].content;
        if (content.parts.len == 0) return AIError.ResponseParsingFailed;
        const text = content.parts[0].text;
        
        return ChatResponse{
            .content = try self.allocator.dupe(u8, text),
            .model = try self.allocator.dupe(u8, request.model.toString()),
        };
    }
};