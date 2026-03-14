const std = @import("std");
const Http = @import("httpServer.zig").HttpServer;

const VERSION = "V 0.0.1";

pub fn main() !void {
    std.debug.print("Habicht {s}\n", .{VERSION});
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    const alloc = gpa.allocator();
    defer {
        if (gpa.deinit() == .leak) std.log.err("We are leaking some memory", .{});
    }

    var server = Http.init(alloc, .{ 127, 0, 0, 1 }, 8080) catch |err| {
        std.log.err("could not init server: {}", .{err});
        return;
    };
    defer server.deinit();

    try server.startThreads();
}
