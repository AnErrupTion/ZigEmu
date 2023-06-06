const std = @import("std");
const gui = @import("gui");
const main = @import("main.zig");

pub var vm: main.VirtualMachine = undefined;
pub var show = false;

var option_index: u64 = 0;
var cpu = std.mem.zeroes([128]u8);
var cores = std.mem.zeroes([16]u8);
var threads = std.mem.zeroes([16]u8);

pub fn init() !void {
    var cores_format = try std.fmt.allocPrint(main.gpa, "{d}", .{vm.machine.cores});
    defer main.gpa.free(cores_format);

    var threads_format = try std.fmt.allocPrint(main.gpa, "{d}", .{vm.machine.threads});
    defer main.gpa.free(threads_format);

    @memset(&cpu, 0);
    @memset(&cores, 0);
    @memset(&threads, 0);

    set_buffer(&cpu, vm.machine.cpu);
    set_buffer(&cores, cores_format);
    set_buffer(&threads, threads_format);
}

pub fn gui_frame() !void {
    if (!show) {
        return;
    }

    var window = try gui.floatingWindow(@src(), .{ .open_flag = &show }, .{ .min_size_content = .{ .w = 400, .h = 400 } });
    defer window.deinit();

    var title = try std.fmt.allocPrint(main.gpa, "{s} - Processor", .{vm.machine.name});
    defer main.gpa.free(title);

    try gui.windowHeader(title, "", &show);

    var scroll = try gui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer scroll.deinit();

    option_index = 0;

    try add_option("CPU", &cpu);
    try add_option("Cores", &cores);
    try add_option("Threads", &threads);

    if (try gui.button(@src(), "OK", .{ .expand = .both, .color_style = .accent })) {
        show = false;
    }
}

fn set_buffer(buffer: []u8, value: []const u8) void {
    var index: u64 = 0;

    for (value) |c| {
        buffer[index] = c;
        index += 1;
    }
}

fn add_option(name: []const u8, buffer: []u8) !void {
    try gui.label(@src(), "{s}:", .{name}, .{ .id_extra = option_index });
    option_index += 1;

    try gui.textEntry(@src(), .{ .text = buffer }, .{ .expand = .horizontal, .id_extra = option_index });
    option_index += 1;
}
