const std = @import("std");
const utils = @import("utils.zig");
const log = std.log.scoped(.main);
const zigday = @import("zigday");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    while (true) {
        const prompt = try utils.ask();

        var agent = zigday.Agent.init(allocator);
        var response = try agent.prompt(prompt);
        defer response.deinit();

        while (try response.next()) |res| {
            if (res.thinking) |t| {
                std.debug.print("\x1b[90m{s}\x1b[0m", .{t});
            }

            std.debug.print("{s}", .{res.response});
        }
        std.debug.print("\n", .{});
    }
}
