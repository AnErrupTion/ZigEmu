const std = @import("std");
const gui = @import("gui");

pub var show = false;

var name_buffer = std.mem.zeroes([128]u8);
var ram_buffer = std.mem.zeroes([32]u8);
var cores_buffer = std.mem.zeroes([16]u8);
var threads_buffer = std.mem.zeroes([16]u8);
var disk_buffer = std.mem.zeroes([8]u8);

pub fn gui_frame() !void {
    if (!show) {
        return;
    }

    var window = try gui.floatingWindow(@src(), .{ .open_flag = &show }, .{ .min_size_content = .{ .w = 400, .h = 400 } });
    defer window.deinit();

    try gui.windowHeader("Create a new virtual machine", "", &show);

    var scroll = try gui.scrollArea(@src(), .{}, .{ .expand = .both, .color_style = .window });
    defer scroll.deinit();

    var label = try gui.label(@src(), "{s}:", .{"Name"}, .{});
    _ = label;
    var name = try gui.textEntry(@src(), .{ .text = &name_buffer }, .{ .expand = .both });
    _ = name;

    var label2 = try gui.label(@src(), "{s}:", .{"RAM (in MiB)"}, .{});
    _ = label2;
    var ram = try gui.textEntry(@src(), .{ .text = &ram_buffer }, .{ .expand = .both });
    _ = ram;

    var label3 = try gui.label(@src(), "{s}:", .{"CPU cores"}, .{});
    _ = label3;
    var cores = try gui.textEntry(@src(), .{ .text = &cores_buffer }, .{ .expand = .both });
    _ = cores;

    var label4 = try gui.label(@src(), "{s}:", .{"CPU threads"}, .{});
    _ = label4;
    var threads = try gui.textEntry(@src(), .{ .text = &threads_buffer }, .{ .expand = .both });
    _ = threads;

    var label5 = try gui.label(@src(), "{s}:", .{"Disk size (in GiB)"}, .{});
    _ = label5;
    var disk = try gui.textEntry(@src(), .{ .text = &disk_buffer }, .{ .expand = .both });
    _ = disk;

    if (try gui.button(@src(), "Create", .{ .expand = .both })) {}
}
