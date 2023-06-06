const std = @import("std");
const gui = @import("gui");
const ini = @import("ini.zig");
const main = @import("main.zig");
const utils = @import("utils.zig");

pub var vm: main.VirtualMachine = undefined;
pub var show = false;

var option_index: u64 = 0;
var cpu = std.mem.zeroes([128]u8);
var features = std.mem.zeroes([1024]u8);
var cores = std.mem.zeroes([16]u8);
var threads = std.mem.zeroes([16]u8);

pub fn init() !void {
    var cores_format = try std.fmt.allocPrint(main.gpa, "{d}", .{vm.machine.cores});
    defer main.gpa.free(cores_format);

    var threads_format = try std.fmt.allocPrint(main.gpa, "{d}", .{vm.machine.threads});
    defer main.gpa.free(threads_format);

    @memset(&cpu, 0);
    @memset(&features, 0);
    @memset(&cores, 0);
    @memset(&threads, 0);

    set_buffer(&cpu, vm.machine.cpu);
    set_buffer(&features, vm.machine.features);
    set_buffer(&cores, cores_format);
    set_buffer(&threads, threads_format);
}

pub fn gui_frame() !void {
    if (!show) {
        return;
    }

    var window = try gui.floatingWindow(@src(), .{ .open_flag = &show }, .{ .min_size_content = .{ .w = 400, .h = 400 } });
    defer window.deinit();

    try gui.windowHeader("Processor", vm.machine.name, &show);

    var scroll = try gui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer scroll.deinit();

    option_index = 0;

    try add_option("CPU", &cpu);
    try add_option("Features", &features);
    try add_option("Cores", &cores);
    try add_option("Threads", &threads);

    if (try gui.button(@src(), "OK", .{ .expand = .both, .color_style = .accent })) {
        vm.machine.cpu = (utils.sanitize_output_text(&cpu) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid CPU name!" });
            return;
        }).items;
        vm.machine.features = (utils.sanitize_output_text(&features) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid features subset!" });
            return;
        }).items;
        vm.machine.cores = utils.sanitize_output_number(&cores) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid amount of cores!" });
            return;
        };
        vm.machine.threads = utils.sanitize_output_number(&threads) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid amount of threads!" });
            return;
        };

        var file_name = try std.fmt.allocPrint(main.gpa, "{s}.ini", .{vm.machine.name});
        defer main.gpa.free(file_name);

        var file = try main.virtual_machines_directory.createFile(file_name, .{});
        defer file.close();

        try ini.writeStruct(vm, file.writer());

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
