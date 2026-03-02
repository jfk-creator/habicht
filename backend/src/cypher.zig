const std =  @import("std");
const argon2 = std.crypto.pwhash.argon2;


pub fn hashPassword(allocator: std.mem.Allocator, password: []const u8, buffer: *[255]u8) ![]const u8 {
    const params = argon2.Params.owasp_2id;
    const mode =   argon2.Mode.argon2id;
    const hash =  try argon2.strHash(password, .{ .allocator = allocator, .params = params, .mode = mode}, buffer);
    return hash;
}

pub fn verifyPassword(alloc: std.mem.Allocator, secret: []const u8, hash: []const u8) bool {
    if(argon2.strVerify(hash, secret, .{ .allocator = alloc})) |_| {
        return true; 
    } else |err| {
        std.log.err("Error Loggin in: {}", .{err});
        return false;
    }
}

