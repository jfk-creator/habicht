const std = @import("std");

pub const UserPackage = struct {
    user_id: i64,
    email: []const u8,
    first_name: []const u8,
    last_name: []const u8,
    address_id: i64,

    pub fn deinit(self: UserPackage, alloc: std.mem.Allocator) void {
        alloc.free(self.email);
        alloc.free(self.first_name);
        alloc.free(self.last_name);
    }
};

pub const AddressPackage = struct {
    address_name: []const u8,
    city_code: []const u8,
    city_name: []const u8,
    street_name: []const u8,
    street_number: []const u8,

    pub fn deinit(self: AddressPackage, alloc: std.mem.Allocator) void {
        alloc.free(self.address_name);
        alloc.free(self.city_code);
        alloc.free(self.city_name);
        alloc.free(self.street_name);
        alloc.free(self.street_number);
    }
};

pub const RegistrationPackage = struct {
    email: []const u8,
    secret: []const u8,
    first_name: []const u8,
    last_name: []const u8,
    city_code: []const u8,
    city_name: []const u8,
    street_name: []const u8,
    street_number: []const u8,

    pub fn deinit(self: RegistrationPackage, alloc: std.mem.Allocator) void {
        alloc.free(self.email);
        alloc.free(self.secret);
        alloc.free(self.first_name);
        alloc.free(self.last_name);
        alloc.free(self.city_code);
        alloc.free(self.city_name);
        alloc.free(self.street_name);
        alloc.free(self.street_number);
    }
};

pub const LoginPackage = struct {
    email: []const u8,
    secret: []const u8,

    pub fn deinit(self: LoginPackage, alloc: std.mem.Allocator) void {
        alloc.free(self.email);
        alloc.free(self.secret);
    }
};

pub const TokenPackage = struct {
    token: []const u8,

    pub fn deinit(self: TokenPackage, alloc: std.mem.Allocator) void {
        alloc.free(self.token);
    }
};
