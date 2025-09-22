const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;

pub const StreamingError = error{
    ParseError,
    ConnectionClosed,
    InvalidFormat,
} || Allocator.Error;

pub const StreamChunk = struct {
    content: ?[]const u8 = null,
    is_done: bool = false,
    error_message: ?[]const u8 = null,
    
    const Self = @This();
    
    pub fn deinit(self: *Self, allocator: Allocator) void {
        if (self.content) |content| allocator.free(content);
        if (self.error_message) |error_msg| allocator.free(error_msg);
    }
};

pub const StreamProcessor = struct {
    allocator: Allocator,
    buffer: std.ArrayList(u8),
    
    const Self = @This();
    
    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .buffer = std.ArrayList(u8){},
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.buffer.deinit(self.allocator);
    }
    
    pub fn processChunk(self: *Self, data: []const u8) !?StreamChunk {
        try self.buffer.appendSlice(self.allocator, data);
        
        // Look for complete SSE events
        while (std.mem.indexOf(u8, self.buffer.items, "\n\n")) |end_pos| {
            const event_data = self.buffer.items[0..end_pos];
            
            // Remove processed data from buffer
            const remaining = self.buffer.items[end_pos + 2..];
            self.buffer.clearRetainingCapacity();
            try self.buffer.appendSlice(self.allocator, remaining);
            
            // Parse the SSE event
            return try self.parseSSEEvent(event_data);
        }
        
        return null; // No complete event yet
    }
    
    fn parseSSEEvent(self: *Self, event_data: []const u8) !StreamChunk {
        var lines = std.mem.split(u8, event_data, "\n");
        var data_content: ?[]const u8 = null;
        var event_type: ?[]const u8 = null;
        
        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "data: ")) {
                data_content = line[6..];
            } else if (std.mem.startsWith(u8, line, "event: ")) {
                event_type = line[7..];
            }
        }
        
        if (data_content) |data| {
            if (std.mem.eql(u8, data, "[DONE]")) {
                return StreamChunk{ .is_done = true };
            }
            
            // Parse JSON data
            const parsed = json.parseFromSlice(json.Value, self.allocator, data, .{}) catch {
                return StreamChunk{
                    .error_message = try self.allocator.dupe(u8, "Failed to parse streaming data"),
                };
            };
            defer parsed.deinit();
            
            return try self.parseStreamingResponse(parsed.value);
        }
        
        return StreamChunk{}; // Empty chunk
    }
    
    fn parseStreamingResponse(self: *Self, parsed: json.Value) !StreamChunk {
        // Handle OpenAI format
        if (parsed.object.get("choices")) |choices| {
            if (choices.array.items.len > 0) {
                const choice = choices.array.items[0];
                if (choice.object.get("delta")) |delta| {
                    if (delta.object.get("content")) |content| {
                        return StreamChunk{
                            .content = try self.allocator.dupe(u8, content.string),
                        };
                    }
                }
                
                if (choice.object.get("finish_reason")) |finish_reason| {
                    if (!std.mem.eql(u8, finish_reason.string, "null")) {
                        return StreamChunk{ .is_done = true };
                    }
                }
            }
        }
        
        // Handle Anthropic format
        if (parsed.object.get("delta")) |delta| {
            if (delta.object.get("text")) |text| {
                return StreamChunk{
                    .content = try self.allocator.dupe(u8, text.string),
                };
            }
        }
        
        if (parsed.object.get("stop_reason")) |stop_reason| {
            if (!std.mem.eql(u8, stop_reason.string, "null")) {
                return StreamChunk{ .is_done = true };
            }
        }
        
        // Handle Ollama format
        if (parsed.object.get("response")) |response| {
            return StreamChunk{
                .content = try self.allocator.dupe(u8, response.string),
            };
        }
        
        if (parsed.object.get("done")) |done| {
            if (done.bool) {
                return StreamChunk{ .is_done = true };
            }
        }
        
        return StreamChunk{}; // Empty chunk for unrecognized format
    }
};

pub const StreamingCallback = *const fn (chunk: StreamChunk, user_data: ?*anyopaque) void;

pub fn streamResponse(
    allocator: Allocator,
    response_body: []const u8,
    callback: StreamingCallback,
    user_data: ?*anyopaque,
) !void {
    var processor = StreamProcessor.init(allocator);
    defer processor.deinit();
    
    // Process the response body in chunks to simulate streaming
    var offset: usize = 0;
    const chunk_size = 64; // Process 64 bytes at a time
    
    while (offset < response_body.len) {
        const end = @min(offset + chunk_size, response_body.len);
        const data = response_body[offset..end];
        
        if (try processor.processChunk(data)) |chunk| {
            callback(chunk, user_data);
            
            if (chunk.is_done) break;
        }
        
        offset = end;
        
        // Small delay to simulate streaming (50ms)
        std.time.sleep(50 * std.time.ns_per_ms);
    }
}