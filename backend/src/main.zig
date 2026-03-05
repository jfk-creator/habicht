const std = @import("std");
const Http = @import("httpServer.zig").HttpServer;

const VERSION = "V 0.0.1";

pub fn main() !void {
    std.debug.print("Habicht {s}\n", .{VERSION});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    var server = try Http.init(alloc, .{ 127, 0, 0, 1}, 8080);
    defer server.deinit();

    try server.acceptRoutine();

 
}

