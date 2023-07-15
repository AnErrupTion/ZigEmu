const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "ZigEmu",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const ini = b.dependency("ini", .{});
    exe.addModule("ini", ini.module("ini"));

    const gui = b.dependency("gui", .{ .target = target, .optimize = optimize });
    exe.addModule("gui", gui.module("gui"));
    exe.addModule("SDLBackend", gui.module("SDLBackend"));

    const freetype = gui.builder.dependency("freetype", .{ .target = target, .optimize = optimize });
    exe.linkLibrary(freetype.artifact("freetype"));

    exe.linkSystemLibrary("SDL2");
    exe.linkLibC();

    const compile_step = b.step("ZigEmu", "Compile ZigEmu");
    compile_step.dependOn(&b.addInstallArtifact(exe).step);
    b.getInstallStep().dependOn(compile_step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(compile_step);

    const run_step = b.step("run", "Run ZigEmu");
    run_step.dependOn(&run_cmd.step);
}
