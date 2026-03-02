const std = @import("std");

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
    connections: std.ArrayList(net.Server.Connection),

    pub fn init(alloc: std.mem.Allocator, host: [4]u8, port: u16) !*HttpServer {
        const self: *HttpServer = try alloc.create(HttpServer);
        self.alloc = alloc;
        self.addr = net.Address.initIp4(host, port);
        self.server = try self.addr.listen(.{ .reuse_address = true});
        self.connections = std.ArrayList(net.Server.Connection).empty;
        std.log.info("HttpServer is running on port: {d}\n", .{port});

        return self;
    }

    pub fn acceptRoutine(self: *HttpServer) !void {
        const config = std.Thread.SpawnConfig{
            .stack_size = 64 * 1024, 
        };
        while (true) {
            const connection = try self.server.accept();
            // try self.connections.append(self.alloc, connection);
            std.log.info("connection accepted\n", .{});
            const thread = try std.Thread.spawn(config, handleConnection, .{self.*, connection});
            thread.detach();
        }
    }

    pub fn handleConnection(self: HttpServer, connection: std.net.Server.Connection) void {
        defer connection.stream.close();

        var rbuf: [1024]u8 = [_]u8{0} ** 1024;
        var wbuf: [1024]u8 = [_]u8{0} ** 1024;

        var conReader = connection.stream.reader(&rbuf);
        var conWriter = connection.stream.writer(&wbuf);

        var httpServer = http.Server.init(conReader.interface(), &conWriter.interface);


    //     const request = self.alloc.create(http.Server.Request) catch |err| {
    //     std.debug.panic("out of memory: {}", .{err});
    // };
        var request= httpServer.receiveHead() catch |err| switch (err) {
            error.HttpConnectionClosing => return,
            else => return 
        };
        // request.* = req;

        std.log.info("Received {s} request for: {s} from {f}\n", 
            .{ @tagName(request.head.method), request.head.target, connection.address });

        if(request.head.method == .OPTIONS) {
            request.respond("", .{ 
                .status = .no_content, 
                .extra_headers = &cors_headers, // only for localhost, nginx is doing this for us
                .keep_alive = false}) catch |err| {
                std.log.err("responding to {f} errored: {}, [.OPTIONS]", .{connection.address, err});
            };
            return;
        }

        if (request.head.method == .POST) {
            self.handlePost(&request) catch |err| {
                std.log.err("responding to {f} errored: {}, [.POST]", .{connection.address, err});
            };
        }
    }

    //get's it's own file?
    const Login = struct {
        user: []const u8, 
        secret: []const u8
    };

    pub fn handlePost(self: HttpServer, request: *http.Server.Request) !void {

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

        const parsed = std.json.parseFromSlice(Login, self.alloc, body, .{}) catch |err| {
            std.log.err("Json parsing, with: {}", .{err});
            return;
    };
        defer parsed.deinit();
        const loginData = parsed.value;

        std.debug.print("username: {s}, secret: {s}\n", .{loginData.user, loginData.secret});

        try request.respond("{\"key\": \"SuperSecretKey\"}", .{
            .status = .ok,
            .extra_headers = &cors_headers, // only for localhost, nginx is doing this for us
            .keep_alive = false,
        });
        return;
    }

    pub fn deinit(self: *HttpServer) void {
        self.server.deinit();
        self.alloc.destroy(self);
    }
};
