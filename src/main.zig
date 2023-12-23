const std = @import("std");
const gui = @import("gui");
const Backend = @import("SDLBackend");
const ini = @import("ini");
const structs = @import("structs.zig");
const utils = @import("utils.zig");
const new_virtual_machine = @import("new_virtual_machine.zig");
const edit_virtual_machine = @import("edit_virtual_machine.zig");
const permanent_buffers = @import("permanent_buffers.zig");
const Allocator = std.mem.Allocator;

pub var virtual_machines_directory: std.fs.IterableDir = undefined;
pub var virtual_machines: std.ArrayList(structs.VirtualMachine) = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    defer _ = gpa.deinit();

    permanent_buffers.init(allocator);
    defer permanent_buffers.deinit();

    std.fs.cwd().makeDir("VMs") catch |err| {
        if (err == error.PathAlreadyExists) {
            std.debug.print("Warning: VMs directory already exists.\n", .{});
        } else {
            return err;
        }
    };

    virtual_machines_directory = try std.fs.cwd().openIterableDir("VMs", .{});
    defer virtual_machines_directory.close();

    virtual_machines = std.ArrayList(structs.VirtualMachine).init(allocator);
    defer virtual_machines.deinit();

    // Iterate over all directories inside the "VMs" directory
    var iterator = virtual_machines_directory.iterate();

    while (try iterator.next()) |directory| {
        var files = try virtual_machines_directory.dir.openDir(directory.name, .{});
        defer files.close();

        var config = try files.readFileAlloc(allocator, "config.ini", 16 * 1024);
        var vm = try ini.readToStruct(structs.VirtualMachine, config);

        try permanent_buffers.arrays.append(config);
        try virtual_machines.append(vm);
    }

    try virtual_machines_directory.dir.setAsCwd();

    var backend = try Backend.init(.{
        .size = .{ .w = 1024, .h = 768 },
        .min_size = .{ .w = 800, .h = 600 },
        .vsync = true,
        .title = "ZigEmu",
    });
    defer backend.deinit();

    var win = try gui.Window.init(@src(), 0, allocator, backend.backend());
    defer win.deinit();

    win.theme = &gui.Adwaita.dark;

    while (true) {
        var nstime = win.beginWait(backend.hasEvent());

        try win.begin(nstime);

        const quit = try backend.addAllEvents(&win);
        if (quit) break;

        try gui_frame(allocator);

        const end_micros = try win.end(.{});

        backend.setCursor(win.cursorRequested());
        backend.renderPresent();

        const wait_event_micros = win.waitTime(end_micros, null);
        backend.waitEventTimeout(wait_event_micros);
    }
}

fn gui_frame(allocator: Allocator) !void {
    {
        var m = try gui.menu(@src(), .horizontal, .{ .background = true, .expand = .horizontal });
        defer m.deinit();

        if (try gui.menuItemLabel(@src(), "File", .{ .submenu = true }, .{ .expand = .none })) |r| {
            var fw = try gui.popup(@src(), gui.Rect.fromPoint(gui.Point{ .x = r.x, .y = r.y + r.h }), .{});
            defer fw.deinit();

            if (try gui.menuItemLabel(@src(), "New Virtual Machine", .{}, .{}) != null) {
                new_virtual_machine.show = true;
                new_virtual_machine.init(allocator);

                gui.menuGet().?.close();
            }
        }

        if (try gui.menuItemLabel(@src(), "View", .{ .submenu = true }, .{ .expand = .none })) |r| {
            var fw = try gui.popup(@src(), gui.Rect.fromPoint(gui.Point{ .x = r.x, .y = r.y + r.h }), .{});
            defer fw.deinit();

            if (gui.themeGet() == &gui.Adwaita.dark and try gui.menuItemLabel(@src(), "Use Light Theme", .{}, .{}) != null) {
                gui.themeSet(&gui.Adwaita.light);
                gui.menuGet().?.close();
            } else if (gui.themeGet() == &gui.Adwaita.light and try gui.menuItemLabel(@src(), "Use Dark Theme", .{}, .{}) != null) {
                gui.themeSet(&gui.Adwaita.dark);
                gui.menuGet().?.close();
            }
        }

        if (try gui.menuItemLabel(@src(), "Help", .{ .submenu = true }, .{ .expand = .none })) |r| {
            var fw = try gui.popup(@src(), gui.Rect.fromPoint(gui.Point{ .x = r.x, .y = r.y + r.h }), .{});
            defer fw.deinit();

            if (try gui.menuItemLabel(@src(), "About", .{}, .{}) != null) {
                try gui.dialog(@src(), .{ .title = "About", .message = "ZigEmu v" ++ utils.VERSION ++ " - A simple QEMU frontend, made in Zig." });

                gui.menuGet().?.close();
            }
        }
    }

    {
        var scroll = try gui.scrollArea(@src(), .{}, .{ .expand = .both, .color_style = .window });
        defer scroll.deinit();

        for (virtual_machines.items, 0..) |vm, i| {
            if (try gui.button(@src(), vm.system.name, .{}, .{ .expand = .horizontal, .color_style = .accent, .id_extra = i })) {
                edit_virtual_machine.vm = vm;
                edit_virtual_machine.vm_index = i;
                edit_virtual_machine.show = true;

                try edit_virtual_machine.init(allocator);
            }
        }
    }

    try new_virtual_machine.guiFrame();
    try edit_virtual_machine.guiFrame();
}
