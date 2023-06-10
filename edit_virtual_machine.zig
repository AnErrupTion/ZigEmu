const std = @import("std");
const gui = @import("gui");
const structs = @import("structs.zig");
const ini = @import("ini.zig");
const main = @import("main.zig");
const utils = @import("utils.zig");
const qemu = @import("qemu.zig");

pub var vm: structs.VirtualMachine = undefined;
pub var show = false;

var setting: u64 = 0;
var option_index: u64 = 0;
var cpu = std.mem.zeroes([128]u8);
var features = std.mem.zeroes([1024]u8);
var cores = std.mem.zeroes([16]u8);
var threads = std.mem.zeroes([16]u8);

pub fn init() !void {
    try init_cpu();
}

pub fn gui_frame() !void {
    if (!show) {
        return;
    }

    var window = try gui.floatingWindow(@src(), .{ .open_flag = &show }, .{ .min_size_content = .{ .w = 800, .h = 600 } });
    defer window.deinit();

    try gui.windowHeader("Edit virtual machine", vm.basic.name, &show);

    {
        var hbox = try gui.boxEqual(@src(), .horizontal, .{ .expand = .horizontal, .min_size_content = .{ .h = 600 } });
        defer hbox.deinit();

        {
            var vbox = try gui.box(@src(), .vertical, .{ .expand = .both });
            defer vbox.deinit();

            if (try gui.button(@src(), "Basic", .{ .expand = .horizontal })) {
                setting = 0;
            }
            if (try gui.button(@src(), "Processor", .{ .expand = .horizontal })) {
                setting = 1;
            }
            if (try gui.button(@src(), "Memory", .{ .expand = .horizontal })) {
                setting = 2;
            }
            if (try gui.button(@src(), "Network", .{ .expand = .horizontal })) {
                setting = 3;
            }
            if (try gui.button(@src(), "Drives", .{ .expand = .horizontal })) {
                setting = 4;
            }
            if (try gui.button(@src(), "Graphics", .{ .expand = .horizontal })) {
                setting = 5;
            }
            if (try gui.button(@src(), "Audio", .{ .expand = .horizontal })) {
                setting = 6;
            }
            if (try gui.button(@src(), "Peripherals", .{ .expand = .horizontal })) {
                setting = 7;
            }
            if (try gui.button(@src(), "Command line", .{ .expand = .horizontal })) {
                setting = 8;
            }
            if (try gui.button(@src(), "Run", .{ .expand = .horizontal })) {
                var qemu_arguments = try qemu.get_arguments(vm);
                defer qemu_arguments.deinit();

                std.debug.print("{s}\n", .{qemu_arguments.items});

                _ = std.ChildProcess.exec(.{ .argv = qemu_arguments.items, .allocator = main.gpa }) catch {
                    try gui.dialog(@src(), .{ .title = "Error", .message = "Unable to create a child process for QEMU." });
                    return;
                };
            }
        }

        {
            var vbox = try gui.box(@src(), .vertical, .{ .expand = .both });
            defer vbox.deinit();

            try cpu_gui_frame();
        }
    }
}

fn init_cpu() !void {
    var cores_format = try std.fmt.allocPrint(main.gpa, "{d}", .{vm.processor.cores});
    defer main.gpa.free(cores_format);

    var threads_format = try std.fmt.allocPrint(main.gpa, "{d}", .{vm.processor.threads});
    defer main.gpa.free(threads_format);

    @memset(&cpu, 0);
    @memset(&features, 0);
    @memset(&cores, 0);
    @memset(&threads, 0);

    set_buffer(&cpu, utils.cpu_to_string(vm.processor.cpu));
    set_buffer(&features, vm.processor.features);
    set_buffer(&cores, cores_format);
    set_buffer(&threads, threads_format);
}

fn cpu_gui_frame() !void {
    if (setting != 1) {
        return;
    }

    option_index = 0;

    try add_option("CPU", &cpu);
    try add_option("Features", &features);
    try add_option("Cores", &cores);
    try add_option("Threads", &threads);

    if (try gui.button(@src(), "Save", .{ .expand = .horizontal, .color_style = .accent })) {
        var sanitized_cpu = (utils.sanitize_output_text(&cpu) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid CPU name!" });
            return;
        }).items;

        vm.processor.cpu = utils.string_to_cpu(sanitized_cpu) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid CPU name!" });
            return;
        };

        vm.processor.features = (utils.sanitize_output_text(&features) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid feature subset!" });
            return;
        }).items;

        vm.processor.cores = utils.sanitize_output_number(&cores) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid amount of cores!" });
            return;
        };

        vm.processor.threads = utils.sanitize_output_number(&threads) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid amount of threads!" });
            return;
        };

        var file_name = try std.fmt.allocPrint(main.gpa, "{s}.ini", .{vm.basic.name});
        defer main.gpa.free(file_name);

        var file = try main.virtual_machines_directory.createFile(file_name, .{});
        defer file.close();

        try ini.writeStruct(vm, file.writer());
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
