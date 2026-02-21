const std = @import("std");

pub fn ask() ![]u8 {
    var stdin_buffer: [1024]u8 = undefined;
    var stdin = std.fs.File.stdin().reader(&stdin_buffer);
    var line_buffer: [1024]u8 = undefined;
    var w: std.io.Writer = .fixed(&line_buffer);
    const line_length = try stdin.interface.streamDelimiterLimit(&w, '\n', .unlimited);
    const input_line = line_buffer[0..line_length];
    return input_line;
}
