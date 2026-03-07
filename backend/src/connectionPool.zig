const std =  @import("std");
const Db = @import("db.zig").Db;

pub const ConnectionPool = struct {
    alloc: std.mem.Allocator,
    connections: std.ArrayList(*Db),
    mutex: std.Thread.Mutex,
    condition: std.Thread.Condition,

    pub fn init(alloc: std.mem.Allocator, max_connections: usize) 
        !*ConnectionPool {
            const pool = try alloc.create(ConnectionPool);

            pool.* = .{
                .alloc = alloc, 
                .connections = std.ArrayList(*Db){},
                .mutex = std.Thread.Mutex{},
                .condition = std.Thread.Condition{},
            };

            for (0..max_connections) |_| {
                const db = try alloc.create(Db);
                db.* = try Db.init();
                try pool.connections.append(alloc, db);
            }
            return pool;
    }

    pub fn deinit(self: *ConnectionPool) void {
        for (self.connections.items) |db| {
            db.deinit();
            self.alloc.destroy(db);
        }
        self.connections.deinit(self.alloc);
        self.alloc.destroy(self);
    }

    pub fn acquire(self: *ConnectionPool) !*Db {
        self.mutex.lock();
        defer self.mutex.unlock();

        while(self.connections.items.len == 0) {
            self.condition.wait(&self.mutex);
        }
        const db_pop = self.connections.pop();

        if(db_pop) |db| {
            return db;
        } else {
            std.log.warn("Forgot to release Db after aquiring it?", .{});
            return error.NoDbConnectionOpen;
        }
    }

    pub fn release(self: *ConnectionPool, db: *Db) !void {
        self.mutex.lock(); 
        defer self.mutex.unlock(); 

        try self.connections.append(self.alloc, db);

        self.condition.signal();
    }
};
