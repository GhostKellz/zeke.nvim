const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;
const net = std.net;

pub const HttpError = error{
    RequestFailed,
    InvalidResponse,
    AuthenticationFailed,
    NetworkError,
    TimeoutError,
} || Allocator.Error || net.TcpConnectToHostError || std.fs.File.WriteError || std.fs.File.ReadError;

pub const HttpResponse = struct {
    status: u16,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    
    const Self = @This();
    
    pub fn deinit(self: *Self, allocator: Allocator) void {
        self.headers.deinit();
        allocator.free(self.body);
    }
};

pub const HttpClient = struct {
    allocator: Allocator,
    timeout_ms: u32,
    
    const Self = @This();
    
    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .timeout_ms = 30000, // 30 seconds default
        };
    }
    
    pub fn setTimeout(self: *Self, timeout_ms: u32) void {
        self.timeout_ms = timeout_ms;
    }
    
    pub fn get(self: *Self, url: []const u8, headers: ?std.StringHashMap([]const u8)) !HttpResponse {
        return self.request("GET", url, headers, null);
    }
    
    pub fn post(self: *Self, url: []const u8, headers: ?std.StringHashMap([]const u8), body: ?[]const u8) !HttpResponse {
        return self.request("POST", url, headers, body);
    }
    
    pub fn request(self: *Self, method: []const u8, url: []const u8, headers: ?std.StringHashMap([]const u8), body: ?[]const u8) !HttpResponse {
        // Parse URL to extract host, path, port
        const parsed_url = try parseUrl(self.allocator, url);
        defer self.allocator.free(parsed_url.host);
        defer self.allocator.free(parsed_url.path);
        
        // Create HTTP request string
        const request_string = try buildRequestString(self.allocator, method, parsed_url, headers, body);
        defer self.allocator.free(request_string);
        
        // Connect to server using standard library
        var stream = try net.tcpConnectToHost(self.allocator, parsed_url.host, parsed_url.port);
        defer stream.close();
        
        // Send request
        _ = try stream.writeAll(request_string);
        
        // Read response
        var response_buffer = std.ArrayList(u8).init(self.allocator);
        defer response_buffer.deinit();
        
        var read_buffer: [4096]u8 = undefined;
        var content_length: ?usize = null;
        var header_end_found = false;
        
        while (true) {
            const bytes_read = stream.read(&read_buffer) catch {
                break; // Any read error means end of data
            };
            
            if (bytes_read == 0) break;
            try response_buffer.appendSlice(read_buffer[0..bytes_read]);
            
            // Check if we have complete headers
            if (!header_end_found) {
                if (std.mem.indexOf(u8, response_buffer.items, "\r\n\r\n")) |header_end| {
                    header_end_found = true;
                    content_length = parseContentLength(response_buffer.items[0..header_end]);
                }
            }
            
            // Check if we have complete response
            if (header_end_found) {
                if (std.mem.indexOf(u8, response_buffer.items, "\r\n\r\n")) |header_end| {
                    const body_start = header_end + 4;
                    const expected_length = content_length orelse 0;
                    if (response_buffer.items.len >= body_start + expected_length) break;
                }
            }
        }
        
        return try parseHttpResponse(self.allocator, response_buffer.items);
    }
};

const ParsedUrl = struct {
    host: []const u8,
    port: u16,
    path: []const u8,
    is_https: bool,
};

fn parseUrl(allocator: Allocator, url: []const u8) !ParsedUrl {
    const is_https = std.mem.startsWith(u8, url, "https://");
    const is_http = std.mem.startsWith(u8, url, "http://");
    
    if (!is_https and !is_http) {
        return HttpError.InvalidResponse;
    }
    
    const protocol_len: usize = if (is_https) 8 else 7; // "https://" or "http://"
    const remainder = url[protocol_len..];
    
    // Find path separator
    const path_start = std.mem.indexOf(u8, remainder, "/") orelse remainder.len;
    const host_port = remainder[0..path_start];
    const path = if (path_start < remainder.len) remainder[path_start..] else "/";
    
    // Parse host and port
    var host: []const u8 = undefined;
    var port: u16 = if (is_https) 443 else 80;
    
    if (std.mem.indexOf(u8, host_port, ":")) |port_start| {
        host = try allocator.dupe(u8, host_port[0..port_start]);
        const port_str = host_port[port_start + 1..];
        port = try std.fmt.parseInt(u16, port_str, 10);
    } else {
        host = try allocator.dupe(u8, host_port);
    }
    
    return ParsedUrl{
        .host = host,
        .port = port,
        .path = try allocator.dupe(u8, path),
        .is_https = is_https,
    };
}

fn buildRequestString(allocator: Allocator, method: []const u8, parsed_url: ParsedUrl, headers: ?std.StringHashMap([]const u8), body: ?[]const u8) ![]const u8 {
    var request = std.ArrayList(u8).init(allocator);
    defer request.deinit();
    
    // Request line
    try request.writer().print("{s} {s} HTTP/1.1\r\n", .{ method, parsed_url.path });
    
    // Host header
    try request.writer().print("Host: {s}\r\n", .{parsed_url.host});
    
    // Default headers
    try request.appendSlice("User-Agent: zeke-nvim/1.0\r\n");
    try request.appendSlice("Connection: close\r\n");
    
    // Custom headers
    if (headers) |h| {
        var iterator = h.iterator();
        while (iterator.next()) |entry| {
            try request.writer().print("{s}: {s}\r\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
    }
    
    // Content-Length for POST requests
    if (body) |b| {
        try request.writer().print("Content-Length: {d}\r\n", .{b.len});
    }
    
    // End headers
    try request.appendSlice("\r\n");
    
    // Body
    if (body) |b| {
        try request.appendSlice(b);
    }
    
    return request.toOwnedSlice();
}

fn parseContentLength(headers: []const u8) ?usize {
    var lines = std.mem.splitSequence(u8, headers, "\r\n");
    while (lines.next()) |line| {
        if (std.ascii.startsWithIgnoreCase(line, "content-length:")) {
            const value = std.mem.trim(u8, line[15..], " \t");
            return std.fmt.parseInt(usize, value, 10) catch null;
        }
    }
    return null;
}

fn parseHttpResponse(allocator: Allocator, response_data: []const u8) !HttpResponse {
    const header_end = std.mem.indexOf(u8, response_data, "\r\n\r\n") orelse return HttpError.InvalidResponse;
    const headers_section = response_data[0..header_end];
    const body_start = header_end + 4;
    const body = response_data[body_start..];
    
    // Parse status line
    var lines = std.mem.splitSequence(u8, headers_section, "\r\n");
    const status_line = lines.next() orelse return HttpError.InvalidResponse;
    
    var status_parts = std.mem.splitScalar(u8, status_line, ' ');
    _ = status_parts.next(); // HTTP version
    const status_str = status_parts.next() orelse return HttpError.InvalidResponse;
    const status = try std.fmt.parseInt(u16, status_str, 10);
    
    // Parse headers
    var headers_map = std.StringHashMap([]const u8).init(allocator);
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, ":")) |colon_pos| {
            const key = std.mem.trim(u8, line[0..colon_pos], " \t");
            const value = std.mem.trim(u8, line[colon_pos + 1..], " \t");
            try headers_map.put(try allocator.dupe(u8, key), try allocator.dupe(u8, value));
        }
    }
    
    return HttpResponse{
        .status = status,
        .headers = headers_map,
        .body = try allocator.dupe(u8, body),
    };
}