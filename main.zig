const std = @import("std");
const gui = @import("gui");
const Backend = @import("SDLBackend");
const new_virtual_machine = @import("new_virtual_machine.zig");

var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};

pub const gpa = gpa_instance.allocator();

pub var virtual_machines_directory: std.fs.Dir = undefined;

pub fn main() !void {
    virtual_machines_directory = try std.fs.cwd().openDir("VMs", .{});
    defer virtual_machines_directory.close();

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

    try new_virtual_machine.gui_frame();
}
