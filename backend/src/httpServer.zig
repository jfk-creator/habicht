const std = @import("std");
const Db = @import("db.zig").Db;

const net = std.net;
const http = std.http;


const cors_headers = [_]std.http.Header{
    .{ .name = "Access-Control-Allow-Origin", .value = "*" }, 
    .{ .name = "Access-Control-Allow-Methods", .value = "GET, POST, OPTIONS" },
    .{ .name = "Access-Control-Allow-Headers", .value = "Content-Type, Authorization" },
};

pub const HttpServer = struct {
    alloc: std.mem.Allocator,
    addr: net.Address,
    server: net.Server, 
    db: *Db,
    connections: std.ArrayList(net.Server.Connection),

    pub fn init(alloc: std.mem.Allocator, host: [4]u8, port: u16) !*HttpServer {
        const self: *HttpServer = try alloc.create(HttpServer);
        self.alloc = alloc;
        self.addr = net.Address.initIp4(host, port);
        self.server = try self.addr.listen(.{ .reuse_address = true});
        self.connections = std.ArrayList(net.Server.Connection).empty;
        self.db = try alloc.create(Db);
        self.db.* = try Db.init();
        try self.db.createTable();
        std.log.info("HttpServer is running on port: {d}\n", .{port});

        return self;
    }

    pub fn deinit(self: *HttpServer) void {
        self.server.deinit();
        self.db.deinit();
        self.alloc.destroy(self);
    }

    pub fn router(self: *HttpServer, connection: std.net.Server.Connection) void {
        defer connection.stream.close();

        var rbuf: [1024]u8 = [_]u8{0} ** 1024;
        var wbuf: [1024]u8 = [_]u8{0} ** 1024;

        var conReader = connection.stream.reader(&rbuf);
        var conWriter = connection.stream.writer(&wbuf);

        var httpServer = http.Server.init(conReader.interface(), &conWriter.interface);

        var request = httpServer.receiveHead() catch |err| switch (err) {
            error.HttpConnectionClosing => return,
            else => return 
        };

        std.log.info("Received {s} request for: {s} from {f}\n", 
            .{ @tagName(request.head.method), request.head.target, connection.address });

        switch (request.head.method) {
            .OPTIONS => sendCORS(&request, connection),
            .POST => self.handlePost(&request),
            else => { std.debug.print("Not Impl \n", .{});}, 
        }

    }

    pub fn handleNotImplementedMethods(request: *std.http.Server.Request) void {
        request.respond("Method not implemented.", .{
            .status = .bad_request,
            .extra_headers = &cors_headers, // only for localhost, nginx is doing this for us
            .keep_alive = false,
        }) catch |err| { std.log.err("{}", .{err}); };
    }

    pub fn handlePost(self: *HttpServer, request: *std.http.Server.Request) void {
        const path = request.head.target;
        if (std.mem.eql(u8, path, "/register")) {
            _ = self.handleRegister(request) catch |err| { std.log.err("{}", .{err});};
        }

    }

    pub fn acceptRoutine(self: *HttpServer) !void {
        // const config = std.Thread.SpawnConfig{
        //     .stack_size = 64 * 1024, 
        // };
        //------------------- INIT DB ---------------------//
        while (true) {
            const connection = try self.server.accept();
            std.log.info("connection accepted\n", .{});
            const thread = try std.Thread.spawn(.{}, router,
                .{self, connection});
            thread.detach();
        }
    }

    pub fn sendCORS(request: *std.http.Server.Request, connection: std.net.Server.Connection) void {
            request.respond("", .{ 
                .status = .no_content, 
                .extra_headers = &cors_headers, // only for localhost, nginx is doing this for us
                .keep_alive = false}) catch |err| {
                std.log.err("responding to {f} errored: {}, [.OPTIONS]", 
                    .{connection.address, err});
            };
    }
       //get's it's own file?
    const RegisterData = struct {
        email: []const u8, 
        secret: []const u8
    };

    pub fn registerUserInDb(self: *HttpServer, loginData: RegisterData, request: *std.http.Server.Request) !void { 
            const email = loginData.email;
            const secret = loginData.secret;

            const email_z: [:0]const u8 = try self.alloc.dupeZ(u8, email);
            const secret_z: [:0]const u8 = try self.alloc.dupeZ(u8, secret);

            const address_id = try self.db.*.createAddress(
                "Business", "CA 90265", "Malibu", "Malibu Point", "10880");

            if(self.db.createUser(email_z, secret_z, address_id, "{some: json}")) |user_id| {
                try request.respond("{\"key\": \"SuperSecretKey\"}", .{
                    .status = .ok,
                    .extra_headers = &cors_headers, // only for localhost, nginx is doing this for us
                    .keep_alive = false,
                });
                std.log.info("createdUser: {}", .{user_id});
                const rc_id = try self.db.getUserByEmail(email_z);
                if(rc_id == user_id) std.log.info("success", .{});
            } else |err| {
                std.log.err("{}", .{err});
                try request.respond("{\"err\": \"Email already in use.\"}", .{
                    .status = .bad_request,
                    .extra_headers = &cors_headers, // only for localhost, nginx is doing this for us
                    .keep_alive = false,
                });
                return;
            }
    }

    pub fn handleRegister(self: *HttpServer, request: *http.Server.Request) !void {

        var transfer_buffer: [8192]u8 = undefined;
        var body_reader = request.server.reader.bodyReader(
            &transfer_buffer, 
            .none, 
            request.head.content_length
        );

        var body_buffer: [8192]u8 = undefined;
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

        const body = body_buffer[0..bytes_read];

        std.debug.print("Received POST body: {s}\n", .{body});

        const parsed = std.json.parseFromSlice(RegisterData, self.alloc, body, .{}) catch |err| {
            std.log.err("Json parsing, with: {}", .{err});
            return err;
    };
        defer parsed.deinit();
        const loginData = parsed.value;

        try self.registerUserInDb(loginData, request);

    }

};
