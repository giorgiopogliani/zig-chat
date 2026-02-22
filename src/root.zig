const std = @import("std");

pub const AgentPayload = struct {
    model: []u8,
    created_at: []u8,
    response: []u8,
    thinking: ?[]u8 = null,
    done: bool,
    done_reason: ?[]u8 = null,
    context: ?[]i64 = null,
    total_duration: ?i64 = null,
    load_duration: ?i64 = null,
    prompt_eval_count: ?i64 = null,
    prompt_eval_duration: ?i64 = null,
    eval_count: ?i64 = null,
    eval_duration: ?i64 = null,
};

pub const AgentResponse = struct {
    req: std.http.Client.Request,
    reader: *std.io.Reader,
    allocator: std.mem.Allocator,

    pub fn next(self: *AgentResponse) !?AgentPayload {
        const size = try self.reader.takeDelimiter('\n') orelse return null;

        if (std.mem.eql(u8, size, "0")) {
            std.debug.print("empty line\n", .{});
            return null;
        }

        const payload = try self.reader.takeDelimiter('\n') orelse return null;

        const jsonParsed = std.json.parseFromSlice(AgentPayload, self.allocator, payload, .{}) catch {
            return null;
        };

        _ = try self.reader.takeDelimiter('\n') orelse return null;

        return jsonParsed.value;
    }

    pub fn deinit(self: *AgentResponse) void {
        self.req.deinit();
    }
};

pub const Agent = struct {
    allocator: std.mem.Allocator,
    client: std.http.Client,

    pub fn init(allocator: std.mem.Allocator) Agent {
        return Agent{
            .allocator = allocator,
            .client = std.http.Client{ .allocator = allocator },
        };
    }

    pub fn prompt(self: *Agent, message: []u8) !AgentResponse {
        const url = try std.Uri.parse("http://localhost:11434/api/generate");
        var req = try self.client.request(.POST, url, .{});

        var allocating: std.io.Writer.Allocating = .init(self.allocator);
        defer allocating.deinit();

        try std.json.Stringify.value(.{ .model = "qwen3:latest", .prompt = message }, .{}, &allocating.writer);
        const buffer = try allocating.toOwnedSlice();
        defer self.allocator.free(buffer);

        try req.sendBodyComplete(buffer);

        _ = try req.receiveHead(allocating.writer.buffer);

        return AgentResponse{
            .allocator = self.allocator,
            .req = req,
            .reader = req.reader.bodyReader(allocating.writer.buffer, .none, null),
        };
    }

    pub fn deinit(self: *Agent) void {
        defer self.client.deinit();
    }
};
