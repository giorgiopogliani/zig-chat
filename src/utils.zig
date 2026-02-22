const std = @import("std");

pub fn ask(allocator: std.mem.Allocator) ![]u8 {
    var buffer = try allocator.alloc(u8, 1024);
    var stdin = std.fs.File.stdin().reader(buffer);
    var line_buffer: [1024]u8 = undefined;
    var w: std.io.Writer = .fixed(&line_buffer);
    const line_length = try stdin.interface.streamDelimiterLimit(&w, '\n', .unlimited);
    return buffer[0..line_length];
}
