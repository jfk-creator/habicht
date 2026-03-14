const std = @import("std");
const UserPackage = @import("definitions.zig").UserPackage;
const AddressPackage = @import("definitions.zig").AddressPackage;
const sqlite = @cImport({
    @cInclude("sqlite3.h");
});

const FILE_NAME = "local.db";

pub const Db = struct {
    sqlite3: ?*sqlite.sqlite3 = null,
    err_msg: [*c]u8 = null,
    open_fd: c_int,

    pub fn init() !Db {
        var sqlite3: ?*sqlite.sqlite3 = null;
        const flags = sqlite.SQLITE_OPEN_NOMUTEX |
            sqlite.SQLITE_OPEN_READWRITE |
            sqlite.SQLITE_OPEN_CREATE;
        const open_fd = sqlite.sqlite3_open_v2(FILE_NAME, &sqlite3, flags, null);
        // const open_fd = sqlite.sqlite3_open(FILE_NAME, &sqlite3);
        if (open_fd != sqlite.SQLITE_OK) {
            std.log.err("Failed to load file: {s}", .{sqlite.sqlite3_errmsg(sqlite3)});
            return error.FailedToLoadFile;
        } else {
            std.log.info("Opened Database.", .{});
        }

        return .{
            .sqlite3 = sqlite3,
            .open_fd = open_fd,
        };
    }

    pub fn deinit(self: Db) void {
        _ = sqlite.sqlite3_close(self.sqlite3);
        std.log.info("Database closed.", .{});
    }

    pub fn createTable(self: *Db) !void {
        //create table and insert user
        _ = sqlite.sqlite3_exec(self.sqlite3, "PRAGMA foreign_keys = ON;", null, null, null);
        const sql =
            \\CREATE TABLE IF NOT EXISTS addresses (
            \\  address_id INTEGER PRIMARY KEY,
            \\  address_name TEXT, 
            \\  city_code TEXT, 
            \\  city_name TEXT, 
            \\  street_name TEXT, 
            \\  street_number TEXT, 
            \\  current INTEGER DEFAULT 1); 
            \\CREATE TABLE IF NOT EXISTS users (
            \\  user_id INTEGER PRIMARY KEY, 
            \\  first_name TEXT NOT NULL, 
            \\  last_name TEXT NOT NULL, 
            \\  email TEXT UNIQUE NOT NULL, 
            \\  secret TEXT NOT NULL, 
            \\  address_id INTEGER, 
            \\  info TEXT, 
            \\  FOREIGN KEY (address_id) REFERENCES addresses (address_id) );
            \\CREATE TABLE IF NOT EXISTS tokens (  
            \\  token_id INTEGER PRIMARY KEY, 
            \\  user_id INTEGER NOT NULL, 
            \\  user_token TEXT UNIQUE NOT NULL, 
            \\  expires DATETIME, 
            \\  FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE );
        ;
        const exec_rc = sqlite.sqlite3_exec(self.sqlite3, sql, null, null, &self.err_msg);
        if (exec_rc != sqlite.SQLITE_OK) {
            if (self.err_msg != null) {
                std.log.err("SQL error: {s}", .{self.err_msg});
                sqlite.sqlite3_free(self.err_msg);
            } else {
                std.log.err("No error message provided by SQLite", .{});
            }
            return error.SQLiteTablesNotCreated;
        } else {
            std.log.info("Table created", .{});
        }
    }

    pub fn insertAddress(
        self: *Db,
        alloc: std.mem.Allocator,
        address_name: []const u8,
        city_code: []const u8,
        city_name: []const u8,
        street_name: []const u8,
        street_number: []const u8,
    ) !i64 {
        const sql = "INSERT INTO addresses (address_name, city_code, city_name, street_name, street_number) VALUES (?, ?, ?, ?, ?)";
        var stmt: ?*sqlite.sqlite3_stmt = null;

        if (sqlite.sqlite3_prepare_v2(self.sqlite3, sql, -1, &stmt, null) != sqlite.SQLITE_OK) {
            std.debug.print("Failed to prepare statement: {s}\n", .{sqlite.sqlite3_errmsg(self.sqlite3)});
            return error.SQLitePrepareFailed;
        }
        defer _ = sqlite.sqlite3_finalize(stmt);
        try bindText(alloc, stmt, 1, address_name);
        try bindText(alloc, stmt, 2, city_code);
        try bindText(alloc, stmt, 3, city_name);
        try bindText(alloc, stmt, 4, street_name);
        try bindText(alloc, stmt, 5, street_number);

        const rc = sqlite.sqlite3_step(stmt);
        if (rc != sqlite.SQLITE_DONE) {
            std.log.err("Failed to insert user: {s}", .{sqlite.sqlite3_errmsg(self.sqlite3)});
            return error.SQliteExecutionFailed;
        }

        return sqlite.sqlite3_last_insert_rowid(self.sqlite3);
    }

    fn bindText(
        alloc: std.mem.Allocator,
        stmt: ?*sqlite.sqlite3_stmt,
        step: c_int,
        field: []const u8,
    ) !void {
        const field_z = try alloc.dupeZ(u8, field);
        defer alloc.free(field_z);
        _ = sqlite.sqlite3_bind_text(stmt, step, field_z, @as(c_int, @intCast(field.len)), sqlite.SQLITE_TRANSIENT);
    }

    fn extractString(alloc: std.mem.Allocator, stmt: ?*sqlite.sqlite3_stmt, col_index: i32) ![]const u8 {
        const ptr = sqlite.sqlite3_column_text(stmt, col_index);

        if (ptr == null) {
            return error.SqlNullValue;
        }

        const len = @as(usize, @intCast(sqlite.sqlite3_column_bytes(stmt, col_index)));
        const slice = ptr[0..len];

        return try alloc.dupe(u8, slice);
    }

    /// Fetches a user by email, prints their data, and returns their user_id (or null if not found).
    pub fn getAddressById(
        self: *Db,
        alloc: std.mem.Allocator,
        address_id: i64,
    ) !?AddressPackage {
        const sql =
            "SELECT address_name, city_code, city_name, street_name, street_number FROM addresses WHERE address_id = ?";
        var stmt: ?*sqlite.sqlite3_stmt = null;

        try prepareStatment(self.sqlite3, sql, &stmt);
        defer _ = sqlite.sqlite3_finalize(stmt);

        _ = sqlite.sqlite3_bind_int64(stmt, 1, address_id);

        const rc = sqlite.sqlite3_step(stmt);

        if (rc == sqlite.SQLITE_ROW) {
            const addressData: AddressPackage = .{
                .address_name = try extractString(alloc, stmt, 0),
                .city_code = try extractString(alloc, stmt, 1),
                .city_name = try extractString(alloc, stmt, 2),
                .street_name = try extractString(alloc, stmt, 3),
                .street_number = try extractString(alloc, stmt, 4),
            };

            return addressData;
        } else if (rc == sqlite.SQLITE_DONE) {
            std.debug.print("No address found for user_id: '{d}'\n", .{address_id});
            return null;
        } else {
            std.debug.print("Failed to execute query: {s}\n", .{sqlite.sqlite3_errmsg(self.sqlite3)});
            return error.SQLtieExecutionFailed;
        }
    }

    pub fn insertUser(
        self: *Db,
        email: []const u8,
        secret: []const u8,
        first_name: []const u8,
        last_name: []const u8,
        address_id: ?i64,
        info: ?[]const u8,
    ) !i64 {
        const sql = "INSERT INTO users (email, secret, first_name, last_name, address_id,  info) VALUES (?, ?, ?, ?, ?, ?)";
        var stmt: ?*sqlite.sqlite3_stmt = null;

        try prepareStatment(self.sqlite3, sql, &stmt);
        defer _ = sqlite.sqlite3_finalize(stmt);

        std.debug.print("first_name: {s}\n", .{first_name});
        _ = sqlite.sqlite3_bind_text(stmt, 1, email.ptr, @intCast(email.len), sqlite.SQLITE_STATIC);
        _ = sqlite.sqlite3_bind_text(stmt, 2, secret.ptr, @intCast(secret.len), sqlite.SQLITE_STATIC);
        _ = sqlite.sqlite3_bind_text(stmt, 3, first_name.ptr, @intCast(first_name.len), sqlite.SQLITE_STATIC);
        _ = sqlite.sqlite3_bind_text(stmt, 4, last_name.ptr, @intCast(last_name.len), sqlite.SQLITE_STATIC);

        if (address_id) |id| {
            _ = sqlite.sqlite3_bind_int64(stmt, 5, id);
        } else {
            _ = sqlite.sqlite3_bind_null(stmt, 5);
        }

        if (info) |i| {
            _ = sqlite.sqlite3_bind_text(stmt, 6, i.ptr, @intCast(i.len), sqlite.SQLITE_STATIC);
        } else {
            _ = sqlite.sqlite3_bind_null(stmt, 6);
        }

        const rc = sqlite.sqlite3_step(stmt);
        if (rc != sqlite.SQLITE_DONE) {
            std.log.err("Failed to insert user: {s}", .{sqlite.sqlite3_errmsg(self.sqlite3)});
            return error.SQliteExecutionFailed;
        }

        return sqlite.sqlite3_last_insert_rowid(self.sqlite3);
    }

    /// Fetches a user by email, prints their data, and returns their user_id (or null if not found).
    pub fn getUserIdByEmail(self: *Db, email: []const u8) !?i64 {
        const sql = "SELECT user_id, secret, address_id, info FROM users WHERE email = ?";
        var stmt: ?*sqlite.sqlite3_stmt = null;

        try prepareStatment(self.sqlite3, sql, &stmt);
        defer _ = sqlite.sqlite3_finalize(stmt);

        _ = sqlite.sqlite3_bind_text(stmt, 1, email.ptr, @intCast(email.len), sqlite.SQLITE_STATIC);

        const rc = sqlite.sqlite3_step(stmt);

        if (rc == sqlite.SQLITE_ROW) {
            const user_id = sqlite.sqlite3_column_int64(stmt, 0);
            const secret_ptr = sqlite.sqlite3_column_text(stmt, 1);

            std.debug.print("\n--- User Found ---\n", .{});
            std.debug.print("Email:      {s}\n", .{email});
            std.debug.print("User ID:    {d}\n", .{user_id});
            std.debug.print("Secret:     {s}\n", .{secret_ptr});

            //Adress can be optional
            if (sqlite.sqlite3_column_type(stmt, 2) != sqlite.SQLITE_NULL) {
                const address_id = sqlite.sqlite3_column_int64(stmt, 2);
                std.debug.print("Address ID: {d}\n", .{address_id});
            } else {
                std.debug.print("Address ID: NULL\n", .{});
            }

            if (sqlite.sqlite3_column_type(stmt, 3) != sqlite.SQLITE_NULL) {
                const info_ptr = sqlite.sqlite3_column_text(stmt, 3);
                std.debug.print("User Info:  {s}\n", .{info_ptr});
            } else {
                std.debug.print("User Info:  NULL\n", .{});
            }
            std.debug.print("------------------\n\n", .{});

            return user_id;
        } else if (rc == sqlite.SQLITE_DONE) {
            std.debug.print("No user found with email: '{s}'\n", .{email});
            return null;
        } else {
            std.debug.print("Failed to execute query: {s}\n", .{sqlite.sqlite3_errmsg(self.sqlite3)});
            return error.SQLtieExecutionFailed;
        }
    }

    pub fn getHashFromMail(self: *Db, alloc: std.mem.Allocator, user_mail: []const u8) ![]const u8 {
        const sql = "SELECT secret FROM users WHERE email = ?";
        var stmt: ?*sqlite.sqlite3_stmt = null;

        try prepareStatment(self.sqlite3, sql, &stmt);
        defer _ = sqlite.sqlite3_finalize(stmt);

        try bindText(alloc, stmt, 1, user_mail);
        const rc = sqlite.sqlite3_step(stmt);

        if (rc == sqlite.SQLITE_ROW) {
            const hash = try extractString(alloc, stmt, 0);
            std.log.info("===============> your hash: {s}", .{hash});
            return hash;
        } else if (rc == sqlite.SQLITE_DONE) {
            std.log.err("User with mail: {s} not found", .{user_mail});
            return error.UserNotFound;
        } else {
            std.log.err("Sqlite faild to get data.", .{});
            return error.SQLiteExecutionFailed;
        }
    }

    /// Fetches a user by email, prints their data, and returns their user_id (or null if not found).
    pub fn getUserByUserId(
        self: *Db,
        alloc: std.mem.Allocator,
        user_id: i64,
    ) !?UserPackage {
        const sql = "SELECT email, first_name, last_name, address_id FROM users WHERE user_id = ?";
        var stmt: ?*sqlite.sqlite3_stmt = null;

        try prepareStatment(self.sqlite3, sql, &stmt);
        defer _ = sqlite.sqlite3_finalize(stmt);

        _ = sqlite.sqlite3_bind_int64(stmt, 1, user_id);

        const rc = sqlite.sqlite3_step(stmt);

        if (rc == sqlite.SQLITE_ROW) {
            var user: UserPackage = undefined;
            user.user_id = user_id;
            user.email = try extractString(alloc, stmt, 0);
            user.first_name = try extractString(alloc, stmt, 1);
            user.last_name = try extractString(alloc, stmt, 2);

            const address_id = sqlite.sqlite3_column_int64(stmt, 3);
            user.address_id = address_id;

            return user;
        } else if (rc == sqlite.SQLITE_DONE) {
            std.debug.print("No user found with email: '{d}'\n", .{user_id});
            return null;
        } else {
            std.debug.print("Failed to execute query: {s}\n", .{sqlite.sqlite3_errmsg(self.sqlite3)});
            return error.SQLiteExecutionFailed;
        }
    }

    pub fn addTokenToUser(
        self: *Db,
        user_id: i64,
        tokenString: []const u8,
    ) !i64 {
        const sql = "INSERT INTO tokens (user_id, user_token, expires) VALUES (?, ?, CURRENT_TIMESTAMP)";
        var stmt: ?*sqlite.sqlite3_stmt = null;

        try prepareStatment(self.sqlite3, sql, &stmt);
        defer _ = sqlite.sqlite3_finalize(stmt);

        _ = sqlite.sqlite3_bind_int64(stmt, 1, user_id);
        _ = sqlite.sqlite3_bind_text(stmt, 2, tokenString.ptr, @intCast(tokenString.len), sqlite.SQLITE_STATIC);

        const rc = sqlite.sqlite3_step(stmt);
        if (rc != sqlite.SQLITE_DONE) {
            std.log.err("Failed to insert user: {s}", .{sqlite.sqlite3_errmsg(self.sqlite3)});
            return error.SQliteExecutionFailed;
        }

        return sqlite.sqlite3_last_insert_rowid(self.sqlite3);
    }

    fn prepareStatment(sqlite3: ?*sqlite.sqlite3, sql: [*c]const u8, stmt: [*c]?*sqlite.sqlite3_stmt) !void {
        if (sqlite.sqlite3_prepare_v2(sqlite3, sql, -1, stmt, null) != sqlite.SQLITE_OK) {
            std.debug.print("Failed to prepare statement: {s}\n", .{sqlite.sqlite3_errmsg(sqlite3)});
            return error.SQLitePrepareFailed;
        }
    }

    /// Fetches a user by session token, prints their data, and returns their user_id (or null if not found).
    pub fn getUserIdByToken(self: *Db, token: []const u8) !?i64 {
        const sql = "SELECT user_id, expires FROM tokens WHERE user_token = ?";
        var stmt: ?*sqlite.sqlite3_stmt = null;

        try prepareStatment(self.sqlite3, sql, &stmt);
        defer _ = sqlite.sqlite3_finalize(stmt);

        _ = sqlite.sqlite3_bind_text(stmt, 1, token.ptr, @intCast(token.len), sqlite.SQLITE_STATIC);

        const rc = sqlite.sqlite3_step(stmt);

        if (rc == sqlite.SQLITE_ROW) {
            const user_id = sqlite.sqlite3_column_int64(stmt, 0);
            return user_id;
        } else if (rc == sqlite.SQLITE_DONE) {
            std.debug.print("No user found with token: '{s}'\n", .{token});
            return null;
        } else {
            std.debug.print("Failed to execute query: {s}\n", .{sqlite.sqlite3_errmsg(self.sqlite3)});
            return error.SQLtieExecutionFailed;
        }
    }
};
