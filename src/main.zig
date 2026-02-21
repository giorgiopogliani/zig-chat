const std = @import("std");
const utils = @import("utils.zig");
const log = std.log.scoped(.main);

const Payload = struct {
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

const AgentResponse = struct {
    req: std.http.Client.Request,
    reader: *std.io.Reader,

    pub fn deinit(self: *AgentResponse) void {
        self.req.deinit();
    }
};

const Agent = struct {
    allocator: std.mem.Allocator,
    client: std.http.Client,

    fn init(allocator: std.mem.Allocator) Agent {
        return Agent{
            .allocator = allocator,
            .client = std.http.Client{ .allocator = allocator },
        };
    }

    fn prompt(self: *Agent, message: []u8) !AgentResponse {
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
            .req = req,
            .reader = req.reader.bodyReader(allocating.writer.buffer, .none, null),
        };
    }

    fn deinit(self: *Agent) void {
        defer self.client.deinit();
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var allocating: std.io.Writer.Allocating = .init(allocator);
    defer allocating.deinit();

    while (true) {
        const prompt = try utils.ask();
        var agent = Agent.init(allocator);
        var response = try agent.prompt(prompt);
        defer response.deinit();

        while (true) {
            const size = try response.reader.takeDelimiter('\n') orelse return;
            // defer allocator.free(size);
            // std.debug.print("size: {s}\n", .{size});

            if (std.mem.eql(u8, size, "0")) {
                std.debug.print("empty line\n", .{});
                break;
            }

            const payload = try response.reader.takeDelimiter('\n') orelse return;
            // defer allocator.free(payload);
            // std.debug.print("payload: {s}\n", .{payload});
            const jsonParsed = std.json.parseFromSlice(Payload, allocator, payload, .{}) catch {
                // std.debug.print("Error parsing JSON: {any}\n payload: {s}\n", .{err, payload});
                break;
            };
            defer jsonParsed.deinit();
            const value = jsonParsed.value;
            // defer allocator.free(jsonParsed);
            if (value.thinking) |t| {
                std.debug.print("\x1b[90m{s}\x1b[0m", .{t});
            }

            std.debug.print("{s}", .{value.response});

            _ = try response.reader.takeDelimiter('\n') orelse return;
            // defer allocator.free(empty);
            // std.debug.print("empty: {s}\n", .{empty});
        }

        std.debug.print("\n", .{});
    }
}
