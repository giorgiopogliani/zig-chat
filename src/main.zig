const std = @import("std");
const zigday = @import("zigday");
const sqlite = @import("sqlite");

const utils = @import("utils.zig");
const database = @import("database.zig");

const log = std.log.scoped(.main);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var db = try sqlite.Db.init(.{
        .mode = sqlite.Db.Mode{ .File = "storage.db" },
        .open_flags = .{ .write = true, .create = true },
        .threading_mode = .MultiThread,
    });
    const messageRepository = try database.MessageRepository.init(allocator, &db);

    while (true) {
        std.debug.print("user: ", .{});
        const prompt = try utils.ask(allocator);

        const message = zigday.AgentMessage{ .role = @constCast("user"), .content = prompt };
        try messageRepository.addMessage(message);

        var agent = zigday.Agent.init(allocator);
        var response = try agent.prompt(try messageRepository.getMessages());
        defer response.deinit();

        var answer = zigday.AgentMessage{ .role = @constCast("assistant"), .content = "" };

        while (try response.next()) |res| {
            if (!res.done) {
                if (res.message.thinking) |t| {
                    std.debug.print("\x1b[90m{s}\x1b[0m", .{t});
                }
                if (res.message.content.len > 0) {
                    std.debug.print("{s}", .{res.message.content});
                }
                answer.content = try std.fmt.allocPrint(allocator, "{s}{s}", .{ answer.content, res.message.content });
            }

            if (res.done) {
                try messageRepository.addMessage(answer);
            }
        }
        std.debug.print("\n", .{});
    }
}
