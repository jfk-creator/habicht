const std = @import("std");
const Db = @import("db.zig").Db;
const Cypher = @import("cypher.zig");

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
        if (std.mem.eql(u8, path, "/app/register")) {
            _ = self.handleRegister(request) catch |err| { std.log.err("{}", .{err});};
        }
        if (std.mem.eql(u8, path, "/app/data")) {
            _ = self.handleData(request) catch |err| { std.log.err("{}", .{err});};
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

    const TokenData = struct {
        key: []const u8
    };

    pub fn registerUserInDb(self: *HttpServer, loginData: RegisterData, request: *std.http.Server.Request) !void { 
            const email = loginData.email;
            var hashBuffer: [255]u8 = undefined;
            const hash = try Cypher.hashPassword(self.alloc, loginData.secret, &hashBuffer);

            const address_id = try self.db.*.createAddress(
                "Business", "CA 90265", "Malibu", "Malibu Point", "10880");

            if(self.db.createUser(email, hash, address_id, "{some: json}")) |_| {
                const tokenString = try Cypher.createToken(self.alloc);
                defer self.alloc.free(tokenString);

                const user_id = try self.db.getUserIdByEmail(email); 
                if(user_id) |id| {
                    _ = try self.db.addTokenToUser(id, tokenString);
                }

                const tokenData: TokenData = .{.key = tokenString};

                //TODO: Would be nice without allocation
                var jsonData = std.Io.Writer.Allocating.init(self.alloc); 
                defer jsonData.deinit();

                std.debug.print("!!!!!!sending Token: {s}\n", .{tokenString});

                var s: std.json.Stringify = .{ .writer = &jsonData.writer, .options = .{} };
                try s.write(tokenData);

                try request.respond(jsonData.written(), .{
                    .status = .ok,
                    .extra_headers = &cors_headers, // only for localhost, nginx is doing this for us
                    .keep_alive = false,
                });
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

    const TokenPackage = struct {
        token: []const u8,
    };

    pub fn handleData(self: *HttpServer, request: *http.Server.Request) !void {

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

        const parsed = std.json.parseFromSlice(TokenPackage, self.alloc, body, .{}) catch |err| {
            std.log.err("Json parsing, with: {}", .{err});
            return err;
        };
        defer parsed.deinit();
        const token = parsed.value;

        std.debug.print("token: {s}\n", .{token.token});

        const user_id = try self.db.getUserIdByToken(token.token);
        if (user_id) |id| {
            std.debug.print("user_id: {}\n", .{id});
            const user: ?Db.UserPackage = try self.db.getUserByUserId(id);
            if(user) |u| {
                std.log.info("User Found\n#-------------------------#\nuser_id: {d}\nuser_mail: {s}\naddress_name: {s}\nstreet_name: {s}\nstreet_number: {s}\ncity_code: {s} city_name: {s}\n#-------------------------#", 
                    .{
                        u.user_id, 
                        u.user_mail, 
                        u.addressData.?.address_name,
                        u.addressData.?.street_name,
                        u.addressData.?.street_number,
                        u.addressData.?.city_code,
                        u.addressData.?.city_name
                    });

                if(u.addressData) |addressData| {
                    //TODO: Would be nice without allocation
                    var jsonData = std.Io.Writer.Allocating.init(self.alloc); 
                    defer jsonData.deinit();

                    std.debug.print("!!!!!!sending Address\n", .{});

                    var s: std.json.Stringify = .{ .writer = &jsonData.writer, .options = .{} };
                    try s.write(addressData);

                    try request.respond(jsonData.written(), .{
                        .status = .ok,
                        .extra_headers = &cors_headers, // only for localhost, nginx is doing this for us
                        .keep_alive = false,
                    });
                }
                
            }
        } 



    }

};
