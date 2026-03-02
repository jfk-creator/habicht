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

    pub fn createTable(self: *Db) void {
        //create table and insert user
        const sql = \\CREATE TABLE IF NOT EXISTS Users(Id INT PRIMARY KEY, Name TEXT); 
                \\INSERT OR IGNORE INTO Users VALUES(1, 'Alice');
        ;
        const exec_rc = sqlite.sqlite3_exec(self.sqlite3, sql, null, null, &self.err_msg);
        if (exec_rc != sqlite.SQLITE_OK) {
            std.log.err("SQL error: {s}n", .{self.err_msg});
            sqlite.sqlite3_free(self.err_msg);
        } else {
            std.log.info("Table created and data insertedn", .{});
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
