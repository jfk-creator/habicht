const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sqlite_flags = &[_][]const u8{
        "-DSQLITE_THREADSAFE=2",
    };

    const exe = b.addExecutable(.{
        .name = "Habicht",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.addIncludePath(b.path("cInclude"));

    exe.addCSourceFile(.{
        .file = b.path("cInclude/sqlite3.c"),
        .flags = sqlite_flags,
    });

    exe.linkLibC();   exe.addIncludePath(b.path("cInclude"));
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

}
