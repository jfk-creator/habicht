const std = @import("std");
const sqlite = @cImport({
    @cInclude("sqlite3.h");
});

const FILE_NAME = "local.db";

pub const Db  = struct {
    sqlite3: ?*sqlite.sqlite3 = null, 
    err_msg: [*c]u8 = null, 
    open_fd: c_int,


    pub fn init() !Db {
        var sqlite3: ?*sqlite.sqlite3 = null;
        const open_fd = sqlite.sqlite3_open(FILE_NAME, &sqlite3);
        if(open_fd != sqlite.SQLITE_OK) {
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
                \\  usermail TEXT UNIQUE NOT NULL, 
                \\  secret TEXT NOT NULL, 
                \\  address_id INTEGER, 
                \\  userinfo TEXT, 
                \\  FOREIGN KEY (address_id) REFERENCES addresses (address_id) );
                \\CREATE TABLE IF NOT EXISTS tokens (  
                \\  token_id INTEGER PRIMARY KEY, 
                \\  user_id INTEGER NOT NULL, 
                \\  user_token TEXT UNIQUE NOT NULL, 
                \\  expires DATETIME, 
                \\  FOREIGN KEY (user_id) REFERENCES user (user_id) ON DELETE CASCADE );
        ;
        const exec_rc = sqlite.sqlite3_exec(self.sqlite3, sql, null, null, &self.err_msg);
        if (exec_rc != sqlite.SQLITE_OK) {
            std.log.err("SQL error: {s}", .{self.err_msg});
            sqlite.sqlite3_free(self.err_msg);
            return error.SQLiteTablesNotCreated; 
        } else {
            std.log.info("Table created", .{});
        }
    }

    pub fn createAddress(
        self: *Db, 
        address_name: [:0]const u8, 
        city_code: [:0]const u8, 
        city_name: [:0]const u8, 
        street_name: [:0]const u8, 
        street_number: [:0]const u8
    ) !i64 {
        const sql = "INSERT INTO addresses (address_name, city_code, city_name, street_name, street_number) VALUES (?, ?, ?, ?, ?)";
        var stmt: ?*sqlite.sqlite3_stmt = null; 

        if (sqlite.sqlite3_prepare_v2(self.sqlite3, sql, -1, &stmt, null) != sqlite.SQLITE_OK) {
            std.debug.print("Failed to prepare statement: {s}\n", .{sqlite.sqlite3_errmsg(self.sqlite3)});
            return error.SQLitePrepareFailed;
        }
        defer _ = sqlite.sqlite3_finalize(stmt);

        _= sqlite.sqlite3_bind_text(stmt, 1, address_name, -1, sqlite.SQLITE_STATIC);
        _= sqlite.sqlite3_bind_text(stmt, 2, city_code, -1, sqlite.SQLITE_STATIC);
        _= sqlite.sqlite3_bind_text(stmt, 3, city_name, -1, sqlite.SQLITE_STATIC);
        _= sqlite.sqlite3_bind_text(stmt, 4, street_name, -1, sqlite.SQLITE_STATIC);
        _= sqlite.sqlite3_bind_text(stmt, 5, street_number, -1, sqlite.SQLITE_STATIC);

        const rc = sqlite.sqlite3_step(stmt);
        if (rc != sqlite.SQLITE_DONE) {
            std.log.err("Failed to insert user: {s}", .{sqlite.sqlite3_errmsg(self.sqlite3)});
            return error.SQliteExecutionFailed;
        }

        return sqlite.sqlite3_last_insert_rowid(self.sqlite3);
    }

    pub fn createUser(
        self: *Db,
        usermail: [:0]const u8, 
        secret: [:0]const u8,
        address_id: ?i64,      
        userinfo: ?[:0]const u8 
    ) !i64 {
        const sql = "INSERT INTO users (usermail, secret, address_id, userinfo) VALUES (?, ?, ?, ?)";
        var stmt: ?*sqlite.sqlite3_stmt = null;

        if (sqlite.sqlite3_prepare_v2(self.sqlite3, sql, -1, &stmt, null) != sqlite.SQLITE_OK) {
            std.debug.print("Failed to prepare statement: {s}\n", .{sqlite.sqlite3_errmsg(self.sqlite3)});
            return error.SQLitePrepareFailed;
        }
        defer _ = sqlite.sqlite3_finalize(stmt);

        _ = sqlite.sqlite3_bind_text(stmt, 1, usermail.ptr, -1, sqlite.SQLITE_STATIC);
        _ = sqlite.sqlite3_bind_text(stmt, 2, secret.ptr, -1, sqlite.SQLITE_STATIC);

        if (address_id) |id| {
            _ = sqlite.sqlite3_bind_int64(stmt, 3, id);
        } else {
            _ = sqlite.sqlite3_bind_null(stmt, 3);
        }

        if (userinfo) |info| {
            _ = sqlite.sqlite3_bind_text(stmt, 4, info.ptr, -1, sqlite.SQLITE_STATIC);
        } else {
            _ = sqlite.sqlite3_bind_null(stmt, 4);
        }

        const rc = sqlite.sqlite3_step(stmt);
        if (rc != sqlite.SQLITE_DONE) {
            std.log.err("Failed to insert user: {s}", .{sqlite.sqlite3_errmsg(self.sqlite3)});
            return error.SQliteExecutionFailed;
        }

        return sqlite.sqlite3_last_insert_rowid(self.sqlite3);
    }

    /// Fetches a user by email, prints their data, and returns their user_id (or null if not found).
    pub fn getUserByEmail(self: *Db, email: [:0]const u8) !?i64 {
        const sql = "SELECT user_id, secret, address_id, userinfo FROM users WHERE usermail = ?";
        var stmt: ?*sqlite.sqlite3_stmt = null;

        if (sqlite.sqlite3_prepare_v2(self.sqlite3, sql, -1, &stmt, null) != sqlite.SQLITE_OK) {
            std.debug.print("Failed to prepare statement: {s}\n",
                .{sqlite.sqlite3_errmsg(self.sqlite3)});
            return error.SQLitePrepareFailed;
        }
        defer _ = sqlite.sqlite3_finalize(stmt);

        _ = sqlite.sqlite3_bind_text(stmt, 1, email.ptr, -1, sqlite.SQLITE_STATIC);

        const rc = sqlite.sqlite3_step(stmt);

        if (rc == sqlite.SQLITE_ROW) {
            const user_id = sqlite.sqlite3_column_int64(stmt, 0);
            const secret_ptr = sqlite.sqlite3_column_text(stmt, 1);

            std.debug.print("\n--- User Found ---\n", .{});
            std.debug.print("Email:     {s}\n", .{email});
            std.debug.print("User ID:   {d}\n", .{user_id});
            std.debug.print("Secret:    {s}\n", .{secret_ptr});

            //Adress can be optional
            if (sqlite.sqlite3_column_type(stmt, 2) != sqlite.SQLITE_NULL) {
                const address_id = sqlite.sqlite3_column_int64(stmt, 2);
                std.debug.print("Address ID:{d}\n", .{address_id});
            } else {
                std.debug.print("Address ID:NULL\n", .{});
            }

            if (sqlite.sqlite3_column_type(stmt, 3) != sqlite.SQLITE_NULL) {
                const info_ptr = sqlite.sqlite3_column_text(stmt, 3);
                std.debug.print("User Info: {s}\n", .{info_ptr});
            } else {
                std.debug.print("User Info: NULL\n", .{});
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

    pub fn getUser(self: *Db) void {
        //query data
        const query = "SELECT Id, Name FROM Users WHERE Id = 1;";
        var stmt: ?*sqlite.sqlite3_stmt = null;

        if(sqlite.sqlite3_prepare_v2(self.sqlite3, query, -1, &stmt, null) 
            == sqlite.SQLITE_OK) {

            defer _ = sqlite.sqlite3_finalize(stmt);

            while (sqlite.sqlite3_step(stmt) == sqlite.SQLITE_ROW) {
                const id = sqlite.sqlite3_column_int(stmt, 0);
                const name_ptr = sqlite.sqlite3_column_text(stmt, 1);

                const name = std.mem.span(name_ptr);

                std.log.info("User found: ID={d}, Name={s}", .{id, name});
            }

        }
    }

};
