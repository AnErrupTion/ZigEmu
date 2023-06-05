const std = @import("std");
const gui = @import("gui");
const ini = @import("ini.zig");
const main = @import("main.zig");

pub var show = false;

const Error = error{ CannotSanitizeOutput, OutOfMemory };
const VirtualMachine = struct {
    name: []const u8,
    ram: u64,
    cores: u64,
    threads: u64,
    disk: u64,
    has_boot_image: bool,
    boot_image: []const u8,
};

var name = std.mem.zeroes([128]u8);
var ram = std.mem.zeroes([32]u8);
var cores = std.mem.zeroes([16]u8);
var threads = std.mem.zeroes([16]u8);
var disk = std.mem.zeroes([8]u8);
var has_boot_image = false;
var boot_image = std.mem.zeroes([1024]u8);

pub fn gui_frame() !void {
    if (!show) {
        return;
    }

    var window = try gui.floatingWindow(@src(), .{ .open_flag = &show }, .{ .min_size_content = .{ .w = 400, .h = 400 } });
    defer window.deinit();

    try gui.windowHeader("Create a new virtual machine", "", &show);

    var scroll = try gui.scrollArea(@src(), .{}, .{ .expand = .both, .color_style = .window });
    defer scroll.deinit();

    try gui.label(@src(), "{s}:", .{"Name"}, .{});
    try gui.textEntry(@src(), .{ .text = &name }, .{ .expand = .both });

    try gui.label(@src(), "{s}:", .{"RAM (in MiB)"}, .{});
    try gui.textEntry(@src(), .{ .text = &ram }, .{ .expand = .both });

    try gui.label(@src(), "{s}:", .{"CPU cores"}, .{});
    try gui.textEntry(@src(), .{ .text = &cores }, .{ .expand = .both });

    try gui.label(@src(), "{s}:", .{"CPU threads"}, .{});
    try gui.textEntry(@src(), .{ .text = &threads }, .{ .expand = .both });

    try gui.label(@src(), "{s}:", .{"Disk size (in GiB)"}, .{});
    try gui.textEntry(@src(), .{ .text = &disk }, .{ .expand = .both });

    try gui.checkbox(@src(), &has_boot_image, "Add a boot image", .{});

    if (has_boot_image) {
        try gui.label(@src(), "{s}:", .{"Boot image"}, .{});
        try gui.textEntry(@src(), .{ .text = &boot_image }, .{ .expand = .both });
    }

    if (try gui.button(@src(), "Create", .{ .expand = .both })) {
        var actual_name = sanitize_output_text(&name) catch return;
        defer actual_name.deinit();

        // var vm = VirtualMachine{
        //     .name = actual_name.items,
        //     .ram = ram,
        //     .cores = cores,
        //     .threads = threads,
        //     .disk = disk,
        //     .has_boot_image = has_boot_image,
        //     .boot_image = boot_image,
        // };

        try actual_name.append('.');
        try actual_name.append('i');
        try actual_name.append('n');
        try actual_name.append('i');

        var file = try main.virtual_machines_directory.createFile(actual_name.items, .{});
        defer file.close();

        // try ini.writeStruct(vm, file.writer());

        show = false;
    }
}

fn sanitize_output_text(buffer: []u8) Error!std.ArrayList(u8) {
    if (buffer[0] == 0) {
        return Error.CannotSanitizeOutput;
    }

    var sanitized_buffer = std.ArrayList(u8).init(main.gpa);

    for (buffer) |byte| {
        if (byte == 0) {
            break;
        }

        try sanitized_buffer.append(byte);
    }

    return sanitized_buffer;
}
