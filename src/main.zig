const std = @import("std");
const utils = @import("utils.zig");
const log = std.log.scoped(.main);
const zigday = @import("zigday");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    while (true) {
        std.debug.print("\x1b[90muser: ", .{});
        const prompt = try utils.ask();

        var agent = zigday.Agent.init(allocator);
        var response = try agent.prompt(prompt);
        defer response.deinit();

        while (try response.next()) |res| {
            if (res.message.thinking) |t| {
                std.debug.print("\x1b[90m{s}\x1b[0m", .{t});
            }

            if (res.message.content.len > 0 and !res.done) {
                std.debug.print("{s}", .{res.message.content});
            }
        }
        std.debug.print("\n", .{});
    }
}
