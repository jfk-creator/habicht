const std = @import("std");
const Http = @import("httpServer.zig").HttpServer;
const Db = @import("db.zig").Db;
const Cypher = @import("cypher.zig");


const VERSION = "V 0.0.1";

pub fn main() !void {
    std.debug.print("Habicht {s}\n", .{VERSION});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    var server = try Http.init(alloc, .{ 127, 0, 0, 1}, 8080);
    defer server.deinit();

    var db = try Db.init(); 
    defer db.deinit();

    try db.createTable();
    const e_mail = "ladiesman217.com";

    const address_id = try db.createAddress("Business", "CA 90265", "Malibu", "Malibu Point", "10880");
    const user_id = try db.createUser(e_mail, "alslsidjflakjmsdnfkj", address_id, "{some: json}");
    std.log.info("createdUser: {}", .{user_id});
    const rc_id = try db.getUserByEmail(e_mail);

    if(rc_id == user_id) std.log.info("success", .{});
 
}

