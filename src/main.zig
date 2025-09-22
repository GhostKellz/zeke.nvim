const std = @import("std");
const zsync = @import("zsync");
const json = std.json;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const http = @import("http.zig");
const ai_services = @import("ai_services.zig");

const ZekeResponse = struct {
    success: bool,
    content: []const u8,
    @"error": ?[]const u8 = null,
};

var global_ai_service: ?*ai_services.AIService = null;
var global_http_client: ?*http.HttpClient = null;
var current_model: ai_services.AIModel = .openai_gpt3_5;

fn mainTask(io: zsync.Io, allocator: Allocator, args: [][:0]u8) !void {
    _ = io; // We're using standard library networking for now
    
    // Initialize HTTP client
    var http_client = http.HttpClient.init(allocator);
    global_http_client = &http_client;

    // Load authentication config
    const auth_config = loadAuthConfig(allocator) catch ai_services.AuthConfig{};

    // Initialize AI service
    var ai_service = ai_services.AIService.init(allocator, &http_client, auth_config);
    global_ai_service = &ai_service;

    if (args.len < 2) {
        try printUsage();
        return;
    }

    const command = args[1];
    
    if (std.mem.eql(u8, command, "nvim")) {
        try handleNvimCommand(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "model")) {
        try handleModelCommand(allocator, args[2..]);
    } else {
        try printUsage();
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Use zsync's blocking runtime for CLI application
    try zsync.runBlocking(mainTask, .{ allocator, args });
}

fn printUsage() !void {
    std.debug.print("Zeke AI CLI - Zig-based development assistant\n\n", .{});
    std.debug.print("Usage:\n", .{});
    std.debug.print("  zeke nvim chat <message>\n", .{});
    std.debug.print("  zeke nvim edit <code> <instruction>\n", .{});
    std.debug.print("  zeke nvim explain <code>\n", .{});
    std.debug.print("  zeke nvim create <description>\n", .{});
    std.debug.print("  zeke nvim analyze <code> <type>\n", .{});
    std.debug.print("  zeke nvim --rpc\n", .{});
    std.debug.print("  zeke model list\n", .{});
    std.debug.print("  zeke model set <model_name>\n", .{});
    std.debug.print("  zeke model current\n", .{});
}

fn handleNvimCommand(allocator: Allocator, args: [][:0]u8) !void {
    if (args.len == 0) {
        try printUsage();
        return;
    }

    const subcommand = args[0];

    if (std.mem.eql(u8, subcommand, "chat")) {
        if (args.len > 1) {
            try handleNvimChat(allocator, args[1]);
        } else {
            try outputError(allocator, "Usage: zeke nvim chat <message>");
        }
    } else if (std.mem.eql(u8, subcommand, "edit")) {
        if (args.len > 2) {
            try handleNvimEdit(allocator, args[1], args[2]);
        } else {
            try outputError(allocator, "Usage: zeke nvim edit <code> <instruction>");
        }
    } else if (std.mem.eql(u8, subcommand, "explain")) {
        if (args.len > 1) {
            try handleNvimExplain(allocator, args[1]);
        } else {
            try outputError(allocator, "Usage: zeke nvim explain <code>");
        }
    } else if (std.mem.eql(u8, subcommand, "create")) {
        if (args.len > 1) {
            try handleNvimCreate(allocator, args[1]);
        } else {
            try outputError(allocator, "Usage: zeke nvim create <description>");
        }
    } else if (std.mem.eql(u8, subcommand, "analyze")) {
        if (args.len > 2) {
            try handleNvimAnalyze(allocator, args[1], args[2]);
        } else {
            try outputError(allocator, "Usage: zeke nvim analyze <code> <type>");
        }
    } else if (std.mem.eql(u8, subcommand, "--rpc")) {
        try handleNvimRpc(allocator);
    } else {
        try outputError(allocator, "Unknown nvim subcommand");
    }
}

fn handleNvimChat(allocator: Allocator, message: []const u8) !void {
    const ai_service = global_ai_service orelse {
        try outputError(allocator, "AI service not initialized");
        return;
    };

    const messages = [_]ai_services.ChatMessage{
        .{ .role = "user", .content = message },
    };

    const request = ai_services.ChatRequest{
        .model = current_model,
        .messages = &messages,
        .max_tokens = 2048,
        .temperature = 0.7,
    };

    const response = ai_service.chat(request) catch |err| {
        const error_msg = switch (err) {
            ai_services.AIError.AuthenticationFailed => "Authentication failed. Please check your API keys.",
            ai_services.AIError.RateLimitExceeded => "Rate limit exceeded. Please try again later.",
            ai_services.AIError.ServiceUnavailable => "AI service is currently unavailable.",
            else => "An error occurred while processing your request.",
        };
        try outputError(allocator, error_msg);
        return;
    };
    
    try outputSuccess(allocator, response.content);
    // Note: response cleanup will be handled by the calling context
}

fn handleNvimEdit(allocator: Allocator, code: []const u8, instruction: []const u8) !void {
    const ai_service = global_ai_service orelse {
        try outputError(allocator, "AI service not initialized");
        return;
    };

    const prompt = try std.fmt.allocPrint(allocator, "Please edit the following code according to the instruction.\n\nInstruction: {s}\n\nCode:\n{s}\n\nPlease provide the modified code:", .{ instruction, code });
    defer allocator.free(prompt);

    const messages = [_]ai_services.ChatMessage{
        .{ .role = "system", .content = "You are a code editing assistant. Provide clean, well-formatted code modifications." },
        .{ .role = "user", .content = prompt },
    };

    const request = ai_services.ChatRequest{
        .model = current_model,
        .messages = &messages,
        .max_tokens = 4096,
        .temperature = 0.3,
    };

    const response = ai_service.chat(request) catch |err| {
        const error_msg = switch (err) {
            ai_services.AIError.AuthenticationFailed => "Authentication failed. Please check your API keys.",
            ai_services.AIError.RateLimitExceeded => "Rate limit exceeded. Please try again later.",
            ai_services.AIError.ServiceUnavailable => "AI service is currently unavailable.",
            else => "An error occurred while processing your request.",
        };
        try outputError(allocator, error_msg);
        return;
    };
    
    try outputSuccess(allocator, response.content);
}

fn handleNvimExplain(allocator: Allocator, code: []const u8) !void {
    const ai_service = global_ai_service orelse {
        try outputError(allocator, "AI service not initialized");
        return;
    };

    const prompt = try std.fmt.allocPrint(allocator, "Please explain the following code in detail:\n\n{s}\n\nProvide a clear explanation of what this code does, how it works, and any notable patterns or techniques used.", .{code});
    defer allocator.free(prompt);

    const messages = [_]ai_services.ChatMessage{
        .{ .role = "system", .content = "You are a code explanation assistant. Provide clear, detailed explanations of code functionality." },
        .{ .role = "user", .content = prompt },
    };

    const request = ai_services.ChatRequest{
        .model = current_model,
        .messages = &messages,
        .max_tokens = 3072,
        .temperature = 0.5,
    };

    const response = ai_service.chat(request) catch |err| {
        const error_msg = switch (err) {
            ai_services.AIError.AuthenticationFailed => "Authentication failed. Please check your API keys.",
            ai_services.AIError.RateLimitExceeded => "Rate limit exceeded. Please try again later.",
            ai_services.AIError.ServiceUnavailable => "AI service is currently unavailable.",
            else => "An error occurred while processing your request.",
        };
        try outputError(allocator, error_msg);
        return;
    };
    
    try outputSuccess(allocator, response.content);
}

fn handleNvimCreate(allocator: Allocator, description: []const u8) !void {
    const ai_service = global_ai_service orelse {
        try outputError(allocator, "AI service not initialized");
        return;
    };

    const prompt = try std.fmt.allocPrint(allocator, "Please create code based on this description: {s}\n\nProvide complete, working code that implements the described functionality. Include appropriate comments and error handling.", .{description});
    defer allocator.free(prompt);

    const messages = [_]ai_services.ChatMessage{
        .{ .role = "system", .content = "You are a code generation assistant. Create complete, well-structured code based on user descriptions." },
        .{ .role = "user", .content = prompt },
    };

    const request = ai_services.ChatRequest{
        .model = current_model,
        .messages = &messages,
        .max_tokens = 4096,
        .temperature = 0.4,
    };

    const response = ai_service.chat(request) catch |err| {
        const error_msg = switch (err) {
            ai_services.AIError.AuthenticationFailed => "Authentication failed. Please check your API keys.",
            ai_services.AIError.RateLimitExceeded => "Rate limit exceeded. Please try again later.",
            ai_services.AIError.ServiceUnavailable => "AI service is currently unavailable.",
            else => "An error occurred while processing your request.",
        };
        try outputError(allocator, error_msg);
        return;
    };
    
    try outputSuccess(allocator, response.content);
}

fn handleNvimAnalyze(allocator: Allocator, code: []const u8, analysis_type: []const u8) !void {
    const ai_service = global_ai_service orelse {
        try outputError(allocator, "AI service not initialized");
        return;
    };

    const prompt = try std.fmt.allocPrint(allocator, "Please analyze the following code for {s}:\n\n{s}\n\nProvide a detailed analysis including potential issues, improvements, and recommendations.", .{ analysis_type, code });
    defer allocator.free(prompt);

    const messages = [_]ai_services.ChatMessage{
        .{ .role = "system", .content = "You are a code analysis assistant. Provide thorough code reviews and suggestions for improvement." },
        .{ .role = "user", .content = prompt },
    };

    const request = ai_services.ChatRequest{
        .model = current_model,
        .messages = &messages,
        .max_tokens = 3072,
        .temperature = 0.3,
    };

    const response = ai_service.chat(request) catch |err| {
        const error_msg = switch (err) {
            ai_services.AIError.AuthenticationFailed => "Authentication failed. Please check your API keys.",
            ai_services.AIError.RateLimitExceeded => "Rate limit exceeded. Please try again later.",
            ai_services.AIError.ServiceUnavailable => "AI service is currently unavailable.",
            else => "An error occurred while processing your request.",
        };
        try outputError(allocator, error_msg);
        return;
    };
    
    try outputSuccess(allocator, response.content);
}

fn handleNvimRpc(allocator: Allocator) !void {
    try outputSuccess(allocator, "Starting MessagePack-RPC server on port 9001...");
    // TODO: Implement actual RPC server using zsync
}

fn handleModelCommand(allocator: Allocator, args: [][:0]u8) !void {
    if (args.len == 0) {
        try printUsage();
        return;
    }

    const subcommand = args[0];

    if (std.mem.eql(u8, subcommand, "list")) {
        try handleModelList(allocator);
    } else if (std.mem.eql(u8, subcommand, "set")) {
        if (args.len > 1) {
            try handleModelSet(allocator, args[1]);
        } else {
            try outputError(allocator, "Usage: zeke model set <model_name>");
        }
    } else if (std.mem.eql(u8, subcommand, "current")) {
        try handleModelCurrent(allocator);
    } else {
        try outputError(allocator, "Unknown model subcommand");
    }
}

fn handleModelList(allocator: Allocator) !void {
    const models = "Available models:\n" ++
        "- gpt-4 (OpenAI GPT-4)\n" ++
        "- gpt-3.5-turbo (OpenAI GPT-3.5 Turbo)\n" ++
        "- claude-3-5-sonnet-20241022 (Anthropic Claude 3.5 Sonnet)\n" ++
        "- claude-3-haiku-20240307 (Anthropic Claude 3 Haiku)\n" ++
        "- llama2 (Ollama Llama 2)\n" ++
        "- codellama (Ollama Code Llama)\n" ++
        "- gemini-pro (Google Gemini Pro)";
    
    try outputSuccess(allocator, models);
}

fn handleModelSet(allocator: Allocator, model_name: []const u8) !void {
    if (ai_services.AIModel.fromString(model_name)) |model| {
        current_model = model;
        if (global_ai_service) |ai_service| {
            ai_service.setModel(model);
        }
        
        const response = try std.fmt.allocPrint(allocator, "Model set to: {s}", .{model.toString()});
        defer allocator.free(response);
        try outputSuccess(allocator, response);
    } else {
        const response = try std.fmt.allocPrint(allocator, "Invalid model: {s}. Use 'zeke model list' to see available models.", .{model_name});
        defer allocator.free(response);
        try outputError(allocator, response);
    }
}

fn handleModelCurrent(allocator: Allocator) !void {
    const response = try std.fmt.allocPrint(allocator, "Current model: {s}", .{current_model.toString()});
    defer allocator.free(response);
    try outputSuccess(allocator, response);
}

fn loadAuthConfig(allocator: Allocator) !ai_services.AuthConfig {
    return ai_services.AuthConfig{
        .openai_api_key = std.process.getEnvVarOwned(allocator, "OPENAI_API_KEY") catch null,
        .anthropic_api_key = std.process.getEnvVarOwned(allocator, "ANTHROPIC_API_KEY") catch null,
        .google_api_key = std.process.getEnvVarOwned(allocator, "GOOGLE_API_KEY") catch null,
        .ollama_base_url = std.process.getEnvVarOwned(allocator, "OLLAMA_BASE_URL") catch null,
    };
}

fn outputSuccess(allocator: Allocator, content: []const u8) !void {
    const response = ZekeResponse{
        .success = true,
        .content = content,
    };
    
    var string_writer = std.io.Writer.Allocating.init(allocator);
    defer string_writer.deinit();
    
    try std.json.Stringify.value(response, .{}, &string_writer.writer);
    
    std.debug.print("{s}\n", .{string_writer.written()});
}

fn outputError(allocator: Allocator, error_message: []const u8) !void {
    const response = ZekeResponse{
        .success = false,
        .content = "",
        .@"error" = error_message,
    };
    
    var string_writer = std.io.Writer.Allocating.init(allocator);
    defer string_writer.deinit();
    
    try std.json.Stringify.value(response, .{}, &string_writer.writer);
    
    std.debug.print("{s}\n", .{string_writer.written()});
}

test "basic functionality" {
    const testing = std.testing;
    try testing.expect(true);
}
