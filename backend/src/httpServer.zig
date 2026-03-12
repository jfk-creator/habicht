const std = @import("std");
const Db = @import("db.zig").Db;
const ConnectionPool = @import("connectionPool.zig").ConnectionPool;
const Cypher = @import("cypher.zig");

const RegistrationPackage = @import("definitions.zig").RegistrationPackage;
const TokenPackage = @import("definitions.zig").TokenPackage;
const UserPackage = @import("definitions.zig").UserPackage;
const AddressPackage = @import("definitions.zig").AddressPackage;
const LoginPackage = @import("definitions.zig").LoginPackage;

const net = std.net;
const http = std.http;

const cors_headers = [_]std.http.Header{
    .{ .name = "Access-Control-Allow-Origin", .value = "*" },
    .{ .name = "Access-Control-Allow-Methods", .value = "GET, POST, OPTIONS" },
    .{ .name = "Access-Control-Allow-Headers", .value = "Content-Type, Authorization" },
};

var keep_running = std.atomic.Value(bool).init(true);
pub const HttpServer = struct {
    alloc: std.mem.Allocator,
    addr: net.Address,
    server: net.Server,
    pool: *ConnectionPool,
    connections: std.ArrayList(net.Server.Connection),

    pub fn init(
        alloc: std.mem.Allocator,
        host: [4]u8,
        port: u16,
    ) !*HttpServer {
        const self: *HttpServer = try alloc.create(HttpServer);
        self.alloc = alloc;
        self.addr = net.Address.initIp4(host, port);
        self.server = try self.addr.listen(.{ .reuse_address = true });
        self.pool = try ConnectionPool.init(alloc, 20);
        self.connections = std.ArrayList(net.Server.Connection).empty;
        std.log.info("HttpServer is running on port: {d}", .{port});

        const db = try self.pool.acquire();
        try db.createTable();
        try self.pool.release(db);

        var act = std.posix.Sigaction{
            .handler = .{ .handler = handleSignal },
            .mask = std.posix.sigemptyset(),
            .flags = 0,
        };

        std.posix.sigaction(std.posix.SIG.INT, &act, null);
        std.posix.sigaction(std.posix.SIG.TERM, &act, null);

        return self;
    }

    pub fn deinit(self: *HttpServer) void {
        self.server.deinit();
        self.pool.deinit();
        self.alloc.destroy(self);
    }

    fn handleSignal(sig: c_int) callconv(.c) void {
        _ = sig;
        std.log.info("handleSignal gets called.", .{});
        keep_running.store(false, .seq_cst);
    }

    pub fn startThreads(self: *HttpServer) !void {
        while (keep_running.load(.seq_cst)) {
            var fds = [_]std.posix.pollfd{.{
                .fd = self.server.stream.handle,
                .events = std.posix.POLL.IN,
                .revents = 0,
            }};

            const ready_count = std.posix.poll(&fds, 500) catch |err| {
                std.log.err("Poll err: {}", .{err});
                continue;
            };

            if (ready_count == 0) {
                continue;
            }

            const connection = try self.server.accept();
            const thread = try std.Thread.spawn(.{}, router, .{ self, connection });
            thread.detach();
        }
        std.log.info("Shutting down server.", .{});
    }

    pub fn router(
        self: *HttpServer,
        connection: std.net.Server.Connection,
    ) void {
        defer connection.stream.close();

        std.log.info("connection accepted", .{});
        var rbuf: [1024]u8 = [_]u8{0} ** 1024;
        var wbuf: [1024]u8 = [_]u8{0} ** 1024;

        var conReader = connection.stream.reader(&rbuf);
        var conWriter = connection.stream.writer(&wbuf);

        var httpServer = http.Server.init(conReader.interface(), &conWriter.interface);

        var request = httpServer.receiveHead() catch |err| switch (err) {
            error.HttpConnectionClosing => return,
            else => return,
        };

        std.log.info("Received {s} request for: {s} from {f}", .{ @tagName(request.head.method), request.head.target, connection.address });

        switch (request.head.method) {
            .OPTIONS => sendCORS(&request, connection),
            .POST => self.handlePost(&request),
            else => {
                std.log.info("Not Impl", .{});
            },
        }
    }

    pub fn handleNotImplementedMethods(
        request: *std.http.Server.Request,
    ) void {
        request.respond("Method not implemented.", .{
            .status = .bad_request,
            .extra_headers = &cors_headers, // only for localhost, nginx is doing this for us
            .keep_alive = true,
        }) catch |err| {
            std.log.err("{}", .{err});
        };
    }

    pub fn handlePost(
        self: *HttpServer,
        request: *std.http.Server.Request,
    ) void {
        const path = request.head.target;
        if (std.mem.eql(u8, path, "/api/register")) {
            _ = self.handleRegister(request) catch |err| {
                std.log.err("{}", .{err});
            };
        }
        if (std.mem.eql(u8, path, "/api/login")) {
            _ = self.handleLogin(request) catch |err| {
                std.log.err("{}", .{err});
            };
        }
        if (std.mem.eql(u8, path, "/api/data")) {
            _ = self.handleData(request) catch |err| {
                std.log.err("{}", .{err});
            };
        }
    }

    pub fn sendCORS(
        request: *std.http.Server.Request,
        connection: std.net.Server.Connection,
    ) void {
        request.respond("", .{
            .status = .no_content,
            .extra_headers = &cors_headers, // only for localhost, nginx is doing this for us
            .keep_alive = false,
        }) catch |err| {
            std.log.err("responding to {f} errored: {}, [.OPTIONS]", .{ connection.address, err });
        };
    }

    pub fn registerUserInDb(
        self: *HttpServer,
        registerData: RegistrationPackage,
        request: *std.http.Server.Request,
    ) !void {
        const email = registerData.email;
        var hashBuffer: [255]u8 = undefined;
        const hash = try Cypher.hashPassword(self.alloc, registerData.secret, &hashBuffer);

        var db = try self.pool.acquire();
        defer self.pool.release(db) catch |err| {
            std.log.err("Error releasing Db-Connection: {}", .{err});
        };

        const city_code = registerData.city_code;
        const city_name = registerData.city_name;
        const street_name = registerData.street_name;
        const street_number = registerData.street_number;

        const address_id = try db.*.insertAddress(self.alloc, "Business", city_code, city_name, street_name, street_number);

        if (db.insertUser(email, hash, address_id, "{some: json}")) |_| {
            try newToken(self.alloc, db, registerData.email, request);
        } else |err| {
            std.log.err("{}", .{err});
            try request.respond("{\"err\": \"Email already in use.\"}", .{
                .status = .bad_request,
                .extra_headers = &cors_headers, // only for localhost, nginx is doing this for us
                .keep_alive = true,
            });
            return;
        }
    }

    fn extractBody(request: *http.Server.Request, body_buffer: []u8) ![]const u8 {
        var transfer_buffer: [8192]u8 = undefined;
        var body_reader = request.server.reader.bodyReader(&transfer_buffer, .none, request.head.content_length);

        var bytes_read: usize = 0;
        while (true) {
            const size = try body_reader.readSliceShort(body_buffer[bytes_read..]);
            if (size == 0) break;

            bytes_read += size;
            if (request.head.content_length) |c_len| {
                if (bytes_read >= c_len) break;
            }

            if (bytes_read >= body_buffer.len) break;
        }

        return body_buffer[0..bytes_read];
    }

    pub fn handleRegister(self: *HttpServer, request: *http.Server.Request) !void {
        var body_buffer: [8192]u8 = undefined;
        const body = try extractBody(request, &body_buffer);

        std.log.info("Received POST body: {s}", .{body});

        const parsed = std.json.parseFromSlice(RegistrationPackage, self.alloc, body, .{}) catch |err| {
            std.log.err("Json parsing, with: {}", .{err});
            return err;
        };
        defer parsed.deinit();
        const registerData = parsed.value;

        try self.registerUserInDb(registerData, request);
    }

    pub fn handleLogin(self: *HttpServer, request: *http.Server.Request) !void {
        var body_buffer: [8192]u8 = undefined;
        const body = try extractBody(request, &body_buffer);
        std.log.info("Received POST body: {s}", .{body});

        const parsed = std.json.parseFromSlice(LoginPackage, self.alloc, body, .{}) catch |err| {
            std.log.err("Json parsing, with: {}", .{err});
            return err;
        };
        defer parsed.deinit();
        const loginData: LoginPackage = parsed.value;

        var db = try self.pool.acquire();
        defer self.pool.release(db) catch |err| {
            std.log.err("{}", .{err});
        };

        const hash = try db.getHashFromMail(self.alloc, loginData.email);
        defer self.alloc.free(hash);

        if (Cypher.verifyPassword(self.alloc, loginData.secret, hash)) {
            try newToken(self.alloc, db, loginData.email, request);
        }
    }

    fn newToken(alloc: std.mem.Allocator, db: *Db, user_mail: []const u8, request: *std.http.Server.Request) !void {
        const tokenString = try Cypher.createToken(alloc);
        const user_id = try db.getUserIdByEmail(user_mail);
        if (user_id) |u| {
            _ = try db.addTokenToUser(u, tokenString);

            const tokenData: TokenPackage = .{ .token = tokenString };
            defer tokenData.deinit(alloc);

            //TODO: Would be nice without allocation
            var jsonData = std.Io.Writer.Allocating.init(alloc);
            defer jsonData.deinit();

            var s: std.json.Stringify = .{ .writer = &jsonData.writer, .options = .{} };
            try s.write(tokenData);

            try request.respond(jsonData.written(), .{
                .status = .ok,
                .extra_headers = &cors_headers, // only for localhost, nginx is doing this for us
                .keep_alive = true,
            });
        }
    }

    pub fn handleData(self: *HttpServer, request: *http.Server.Request) !void {
        var body_buffer: [8192]u8 = undefined;
        const body = try extractBody(request, &body_buffer);

        std.log.info("Received POST body: {s}", .{body});

        const parsed = std.json.parseFromSlice(TokenPackage, self.alloc, body, .{}) catch |err| {
            std.log.err("Json parsing, with: {}", .{err});
            return err;
        };
        defer parsed.deinit();
        const token = parsed.value;

        var db = try self.pool.acquire();
        defer self.pool.release(db) catch |err| {
            std.log.err("Error releasing Db-Connection: {}", .{err});
        };

        const user_id = try db.getUserIdByToken(token.token);
        if (user_id) |id| {
            const user: ?UserPackage = try db.getUserByUserId(self.alloc, id);
            defer user.?.deinit(self.alloc);
            if (user) |u| {
                const addr: ?AddressPackage = try db.getAddressById(self.alloc, u.address_id);
                defer addr.?.deinit(self.alloc);
                if (addr) |a| {
                    std.log.info("User Found\n-----------------------------------\nuser_id: \t{d}\nuser_mail: \t{s}\naddress_name: \t{s}\nstreet_name: \t{s}\nstreet_number: \t{s}\ncity_code: \t{s}\ncity_name: \t{s}\n-----------------------------------", .{ u.user_id, u.user_mail, a.address_name, a.street_name, a.street_number, a.city_code, a.city_name });

                    //TODO: Would be nice without allocation
                    var jsonData = std.Io.Writer.Allocating.init(self.alloc);
                    defer jsonData.deinit();

                    var s: std.json.Stringify = .{ .writer = &jsonData.writer, .options = .{} };
                    try s.write(a);

                    try request.respond(jsonData.written(), .{
                        .status = .ok,
                        .extra_headers = &cors_headers, // only for localhost, nginx is doing this for us
                        .keep_alive = true,
                    });
                }
            }
        }
    }
};
