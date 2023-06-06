const std = @import("std");
const gui = @import("gui");
const Backend = @import("SDLBackend");
const structs = @import("structs.zig");
const ini = @import("ini.zig");
const new_virtual_machine = @import("new_virtual_machine.zig");
const processor = @import("processor.zig");
const permanent_buffers = @import("permanent_buffers.zig");
const qemu = @import("qemu.zig");

var vm_options: structs.VirtualMachine = undefined;
var show_vm_options = false;
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
    var scroll = try gui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer scroll.deinit();

    if (try gui.button(@src(), "Toggle Theme", .{ .expand = .both, .color_style = .success })) {
        if (gui.themeGet() == &gui.Adwaita.dark) {
            gui.themeSet(&gui.Adwaita.light);
        } else {
            gui.themeSet(&gui.Adwaita.dark);
        }
    }

    if (try gui.button(@src(), "New Virtual Machine", .{ .expand = .both, .color_style = .success })) {
        new_virtual_machine.show = true;
        new_virtual_machine.init();
    }

    var index: u64 = 0;

    for (virtual_machines.items) |vm| {
        if (try gui.button(@src(), vm.basic.name, .{ .expand = .both, .color_style = .accent, .id_extra = index })) {
            vm_options = vm;
            show_vm_options = !show_vm_options;
        }

        if (show_vm_options and std.meta.eql(vm_options, vm)) {
            if (try gui.button(@src(), "Basic", .{ .expand = .both })) {}
            if (try gui.button(@src(), "Processor", .{ .expand = .both })) {
                processor.vm = vm;
                processor.show = true;

                try processor.init();
            }
            if (try gui.button(@src(), "Memory", .{ .expand = .both })) {}
            if (try gui.button(@src(), "Network", .{ .expand = .both })) {}
            if (try gui.button(@src(), "Drives", .{ .expand = .both })) {}
            if (try gui.button(@src(), "Graphics", .{ .expand = .both })) {}
            if (try gui.button(@src(), "Audio", .{ .expand = .both })) {}
            if (try gui.button(@src(), "Peripherals", .{ .expand = .both })) {}
            if (try gui.button(@src(), "Command line", .{ .expand = .both })) {}
            if (try gui.button(@src(), "Run", .{ .expand = .both })) {
                var qemu_arguments = try qemu.get_arguments(vm);
                defer qemu_arguments.deinit();

                std.debug.print("{s}\n", .{qemu_arguments.items});

                _ = std.ChildProcess.exec(.{ .argv = qemu_arguments.items, .allocator = gpa }) catch {
                    try gui.dialog(@src(), .{ .title = "Error", .message = "Unable to create a child process for QEMU." });
                    return;
                };
            }
        }

        index += 1;
    }

    try new_virtual_machine.gui_frame();
    try processor.gui_frame();
}
