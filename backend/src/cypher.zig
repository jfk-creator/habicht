const std =  @import("std");
const argon2 = std.crypto.pwhash.argon2;


pub fn hashPassword(alloc: std.mem.Allocator, password: []const u8, buffer: *[255]u8) ![]const u8 {
    const params = argon2.Params.owasp_2id;
    const mode =   argon2.Mode.argon2id;
    const hash =  try argon2.strHash(password, .{ .allocator = alloc, .params = params, .mode = mode}, buffer);
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

pub fn createToken(alloc: std.mem.Allocator) ![]const u8 {
    var buf: [32]u8 = undefined;
    std.crypto.random.bytes(&buf);

    const encoder = std.base64.url_safe_no_pad.Encoder; 
    const encodeLen = encoder.calcSize(buf.len);

    const token = try alloc.alloc(u8, encodeLen);
    _ = encoder.encode(token, &buf);

    return token;
}

