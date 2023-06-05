const std = @import("std");
const Pkg = std.build.Pkg;

const Packages = struct {
    // Declared here because submodule may not be cloned at the time build.zig runs.
    const zmath = std.build.Pkg{
        .name = "zmath",
        .source = .{ .path = "libs/zmath/src/zmath.zig" },
    };
};

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const gui_mod = b.addModule("gui", .{
        .source_file = .{ .path = "gui/gui.zig" },
        .dependencies = &.{},
    });

    const sdl_mod = b.addModule("SDLBackend", .{
        .source_file = .{ .path = "gui/SDLBackend.zig" },
        .dependencies = &.{
            .{ .name = "gui", .module = gui_mod },
        },
    });

    const exe = b.addExecutable(.{
        .name = "ZigEmu",
        .root_source_file = .{ .path = "main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.addModule("gui", gui_mod);
    exe.addModule("SDLBackend", sdl_mod);
    const freetype_dep = b.dependency("freetype", .{
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibrary(freetype_dep.artifact("freetype"));

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
