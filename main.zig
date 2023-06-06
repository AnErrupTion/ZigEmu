const std = @import("std");
const gui = @import("gui");
const Backend = @import("SDLBackend");
const ini = @import("ini.zig");
const new_virtual_machine = @import("new_virtual_machine.zig");
const permanent_buffers = @import("permanent_buffers.zig");

var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};

pub const gpa = gpa_instance.allocator();
pub const VirtualMachine = struct {
    machine: struct {
        name: []const u8,
        ram: u64,
        cores: u64,
        threads: u64,
        disk: u64,
        has_boot_image: bool,
        boot_image: []const u8,
    },
};

pub var virtual_machines_directory: std.fs.Dir = undefined;
pub var virtual_machines: std.ArrayList(VirtualMachine) = undefined;

pub fn main() !void {
    defer _ = gpa_instance.deinit();

    permanent_buffers.init();
    defer permanent_buffers.deinit();

    virtual_machines_directory = try std.fs.cwd().openDir("VMs", .{});
    defer virtual_machines_directory.close();

    virtual_machines = std.ArrayList(VirtualMachine).init(gpa);
    defer virtual_machines.deinit();

    var files = try std.fs.cwd().openIterableDir("VMs", .{});
    defer files.close();

    var iterator = files.iterate();

    while (try iterator.next()) |file| {
        var config = try virtual_machines_directory.readFileAlloc(gpa, file.name, 16 * 1024 * 1024); // Free?
        var vm = try ini.readToStruct(VirtualMachine, config);

        try permanent_buffers.arrays.append(config);
        try virtual_machines.append(vm);
    }

    var backend = try Backend.init(.{
        .width = 640,
        .height = 480,
        .vsync = true,
        .title = "ZigEmu",
    });
    defer backend.deinit();

    var win = try gui.Window.init(@src(), 0, gpa, backend.guiBackend());
    defer win.deinit();

    main_loop: while (true) {
        var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena_allocator.deinit();

        const arena = arena_allocator.allocator();

        var nstime = win.beginWait(backend.hasEvent());

        try win.begin(arena, nstime);

        const quit = try backend.addAllEvents(&win);
        if (quit) break :main_loop;

        try gui_frame();

        const end_micros = try win.end();

        backend.setCursor(win.cursorRequested());
        backend.renderPresent();

        const wait_event_micros = win.waitTime(end_micros, null);
        backend.waitEventTimeout(wait_event_micros);
    }
}

fn gui_frame() !void {
    gui.themeSet(&gui.Adwaita.dark);

    if (try gui.button(@src(), "New Virtual Machine", .{})) {
        new_virtual_machine.show = true;
    }

    var scroll = try gui.scrollArea(@src(), .{}, .{ .expand = .both, .color_style = .window });
    defer scroll.deinit();

    for (virtual_machines.items) |vm| {
        if (try gui.button(@src(), vm.machine.name, .{ .expand = .both })) {}
    }

    try new_virtual_machine.gui_frame();
}
