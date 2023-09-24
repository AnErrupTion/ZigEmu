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

    const dvui = b.dependency("dvui", .{ .target = target, .optimize = optimize });
    exe.addModule("gui", dvui.module("dvui"));
    exe.addModule("SDLBackend", dvui.module("SDLBackend"));

    link_deps(exe, dvui.builder);

    const compile_step = b.step("ZigEmu", "Compile ZigEmu");
    compile_step.dependOn(&b.addInstallArtifact(exe, .{}).step);
    b.getInstallStep().dependOn(compile_step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(compile_step);

    const run_step = b.step("run", "Run ZigEmu");
    run_step.dependOn(&run_cmd.step);
}

fn link_deps(exe: *std.Build.Step.Compile, b: *std.Build) void {
    const freetype_dep = b.dependency("freetype", .{
        .target = exe.target,
        .optimize = exe.optimize,
    });
    exe.linkLibrary(freetype_dep.artifact("freetype"));
    exe.linkLibC();

    if (exe.target.isWindows()) {
        const sdl_dep = b.dependency("sdl", .{
            .target = exe.target,
            .optimize = exe.optimize,
        });
        exe.linkLibrary(sdl_dep.artifact("SDL2"));

        exe.linkSystemLibrary("setupapi");
        exe.linkSystemLibrary("winmm");
        exe.linkSystemLibrary("gdi32");
        exe.linkSystemLibrary("imm32");
        exe.linkSystemLibrary("version");
        exe.linkSystemLibrary("oleaut32");
        exe.linkSystemLibrary("ole32");
    } else {
        exe.linkSystemLibrary("SDL2");
    }
}
