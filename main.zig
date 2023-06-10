const std = @import("std");
const gui = @import("gui");
const Backend = @import("SDLBackend");
const structs = @import("structs.zig");
const ini = @import("ini.zig");
const new_virtual_machine = @import("new_virtual_machine.zig");
const edit_virtual_machine = @import("edit_virtual_machine.zig");
const permanent_buffers = @import("permanent_buffers.zig");

var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};

pub const gpa = gpa_instance.allocator();

pub var virtual_machines_directory: std.fs.Dir = undefined;
pub var virtual_machines: std.ArrayList(structs.VirtualMachine) = undefined;

pub fn main() !void {
    defer _ = gpa_instance.deinit();

    permanent_buffers.init();
    defer permanent_buffers.deinit();

    virtual_machines_directory = try std.fs.cwd().openDir("VMs", .{});
    defer virtual_machines_directory.close();

    virtual_machines = std.ArrayList(structs.VirtualMachine).init(gpa);
    defer virtual_machines.deinit();

    var files = try std.fs.cwd().openIterableDir("VMs", .{});
    defer files.close();

    var iterator = files.iterate();

    while (try iterator.next()) |file| {
        if (!std.mem.endsWith(u8, file.name, ".ini")) {
            continue;
        }

        var config = try virtual_machines_directory.readFileAlloc(gpa, file.name, 16 * 1024 * 1024); // Free?
        var vm = try ini.readToStruct(structs.VirtualMachine, config);

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

    win.theme = &gui.Adwaita.dark;

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
    {
        var m = try gui.menu(@src(), .horizontal, .{ .background = true, .expand = .horizontal });
        defer m.deinit();

        if (try gui.menuItemLabel(@src(), "File", true, .{ .expand = .none })) |r| {
            var fw = try gui.popup(@src(), gui.Rect.fromPoint(gui.Point{ .x = r.x, .y = r.y + r.h }), .{});
            defer fw.deinit();

            if (try gui.menuItemLabel(@src(), "New Virtual Machine", false, .{}) != null) {
                new_virtual_machine.show = true;
                new_virtual_machine.init();

                gui.menuGet().?.close();
            }
        }

        if (try gui.menuItemLabel(@src(), "View", true, .{ .expand = .none })) |r| {
            var fw = try gui.popup(@src(), gui.Rect.fromPoint(gui.Point{ .x = r.x, .y = r.y + r.h }), .{});
            defer fw.deinit();

            if (gui.themeGet() == &gui.Adwaita.dark) {
                if (try gui.menuItemLabel(@src(), "Use Light Theme", false, .{}) != null) {
                    gui.themeSet(&gui.Adwaita.light);
                    gui.menuGet().?.close();
                }
            } else {
                if (try gui.menuItemLabel(@src(), "Use Dark Theme", false, .{}) != null) {
                    gui.themeSet(&gui.Adwaita.dark);
                    gui.menuGet().?.close();
                }
            }
        }
    }

    {
        var scroll = try gui.scrollArea(@src(), .{}, .{ .expand = .both, .color_style = .window });
        defer scroll.deinit();

        var index: u64 = 0;

        for (virtual_machines.items) |vm| {
            if (try gui.button(@src(), vm.basic.name, .{ .expand = .both, .color_style = .accent, .id_extra = index })) {
                edit_virtual_machine.vm = vm;
                edit_virtual_machine.show = true;

                try edit_virtual_machine.init();
            }

            index += 1;
        }
    }

    try new_virtual_machine.gui_frame();
    try edit_virtual_machine.gui_frame();
}
