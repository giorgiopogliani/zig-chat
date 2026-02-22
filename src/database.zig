const std = @import("std");
const sqlite = @import("sqlite");
const zigday = @import("zigday");

pub const MessageRepository = struct {
    allocator: std.mem.Allocator,
    db: *sqlite.Db,

    pub fn init(allocator: std.mem.Allocator, db: *sqlite.Db) !MessageRepository {
        try db.exec("CREATE TABLE IF NOT EXISTS messages (id INTEGER PRIMARY KEY AUTOINCREMENT, role TEXT, content TEXT)", .{}, .{});
        return MessageRepository{ .allocator = allocator, .db = db };
    }

    pub fn addMessage(self: *const MessageRepository, message: zigday.AgentMessage) !void {
        try self.db.exec("INSERT INTO messages (role, content) VALUES (?, ?)", .{}, .{
            .role = message.role, //
            .content = message.content,
        });
    }

    pub fn getMessages(self: *const MessageRepository) ![]zigday.AgentMessage {
        const query = "SELECT id, role, content, null as thinking FROM messages";
        var diags = sqlite.Diagnostics{};
        var stmt = self.db.prepareWithDiags(query, .{ .diags = &diags }) catch |err| {
            std.log.err("unable to prepare statement, got error {}. diagnostics: {s}", .{ err, diags.message });
            return err;
        };
        defer stmt.deinit();

        return stmt.all(zigday.AgentMessage, self.allocator, .{}, .{});
    }
};
