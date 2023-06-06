const std = @import("std");
const gui = @import("gui");
const ini = @import("ini.zig");
const main = @import("main.zig");
const permanent_buffers = @import("permanent_buffers.zig");

pub var show = false;

const Error = error{ CannotSanitizeOutput, OutOfMemory };

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
        var actual_name = sanitize_output_name(&name) catch return;
        var actual_ram = sanitize_output_number(&ram) catch return;
        var actual_cores = sanitize_output_number(&cores) catch return;
        var actual_threads = sanitize_output_number(&threads) catch return;
        var actual_disk = sanitize_output_number(&disk) catch return;
        var actual_boot_image = sanitize_output_text(&boot_image) catch return;

        try permanent_buffers.lists.append(actual_name);
        try permanent_buffers.lists.append(actual_boot_image);

        const vm = main.VirtualMachine{
            .machine = .{
                .name = actual_name.items,
                .ram = actual_ram,
                .cores = actual_cores,
                .threads = actual_threads,
                .disk = actual_disk,
                .has_boot_image = has_boot_image,
                .boot_image = actual_boot_image.items,
            },
        };

        try main.virtual_machines.append(vm);

        try actual_name.append('.');
        try actual_name.append('i');
        try actual_name.append('n');
        try actual_name.append('i');

        var file = try main.virtual_machines_directory.createFile(actual_name.items, .{});
        defer file.close();

        try ini.writeStruct(vm, file.writer());

        show = false;
    }
}

fn sanitize_output_name(buffer: []u8) Error!std.ArrayList(u8) {
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

fn sanitize_output_text(buffer: []u8) Error!std.ArrayList(u8) {
    var sanitized_buffer = std.ArrayList(u8).init(main.gpa);

    for (buffer) |byte| {
        if (byte == 0) {
            break;
        }

        try sanitized_buffer.append(byte);
    }

    return sanitized_buffer;
}

fn sanitize_output_number(buffer: []u8) Error!u64 {
    if (buffer[0] == 0) {
        return Error.CannotSanitizeOutput;
    }

    var sanitized_buffer = std.ArrayList(u8).init(main.gpa);
    defer sanitized_buffer.deinit();

    for (buffer) |byte| {
        if (byte == 0) {
            break;
        }

        try sanitized_buffer.append(byte);
    }

    return std.fmt.parseInt(u64, sanitized_buffer.items, 10) catch return Error.CannotSanitizeOutput;
}
