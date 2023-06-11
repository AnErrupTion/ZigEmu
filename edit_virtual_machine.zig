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

var name = std.mem.zeroes([128]u8);
var architecture = std.mem.zeroes([16]u8);
var has_acceleration = false;
var chipset = std.mem.zeroes([8]u8);
var usb_type = std.mem.zeroes([4]u8);
var has_ahci = false;

var cpu = std.mem.zeroes([128]u8);
var features = std.mem.zeroes([1024]u8);
var cores = std.mem.zeroes([16]u8);
var threads = std.mem.zeroes([16]u8);

var ram = std.mem.zeroes([32]u8);

var display = std.mem.zeroes([8]u8);
var gpu = std.mem.zeroes([16]u8);
var has_vga_emulation = false;
var has_graphics_acceleration = false;

pub fn init() !void {
    try init_basic();
    try init_memory();
    try init_processor();
    try init_network();
    try init_graphics();
    try init_audio();
    try init_peripherals();
    try init_drives();
}

pub fn gui_frame() !void {
    if (!show) {
        return;
    }

    var window = try gui.floatingWindow(@src(), .{ .open_flag = &show }, .{ .min_size_content = .{ .w = 800, .h = 600 } });
    defer window.deinit();

    try gui.windowHeader("Edit virtual machine", vm.basic.name, &show);

    var hbox = try gui.box(@src(), .horizontal, .{ .expand = .horizontal, .min_size_content = .{ .h = 600 } });
    defer hbox.deinit();

    {
        var vbox = try gui.box(@src(), .vertical, .{ .expand = .both });
        defer vbox.deinit();

        if (try gui.button(@src(), "Basic", .{ .expand = .horizontal })) {
            setting = 0;
        }
        if (try gui.button(@src(), "Memory", .{ .expand = .horizontal })) {
            setting = 1;
        }
        if (try gui.button(@src(), "Processor", .{ .expand = .horizontal })) {
            setting = 2;
        }
        if (try gui.button(@src(), "Network", .{ .expand = .horizontal })) {
            setting = 3;
        }
        if (try gui.button(@src(), "Graphics", .{ .expand = .horizontal })) {
            setting = 4;
        }
        if (try gui.button(@src(), "Audio", .{ .expand = .horizontal })) {
            setting = 5;
        }
        if (try gui.button(@src(), "Peripherals", .{ .expand = .horizontal })) {
            setting = 6;
        }
        if (try gui.button(@src(), "Drives", .{ .expand = .horizontal })) {
            setting = 7;
        }
        if (try gui.button(@src(), "Command line", .{ .expand = .horizontal })) {
            setting = 8;
        }
        if (try gui.button(@src(), "Run", .{ .expand = .horizontal, .color_style = .accent })) {
            var qemu_arguments = try qemu.get_arguments(vm);
            defer qemu_arguments.deinit();

            _ = std.ChildProcess.exec(.{ .argv = qemu_arguments.items, .allocator = main.gpa }) catch {
                try gui.dialog(@src(), .{ .title = "Error", .message = "Unable to create a child process for QEMU." });
                return;
            };
        }
    }

    {
        var vbox = try gui.box(@src(), .vertical, .{ .expand = .both });
        defer vbox.deinit();

        switch (setting) {
            0 => {
                try basic_gui_frame();
            },
            1 => {
                try memory_gui_frame();
            },
            2 => {
                try processor_gui_frame();
            },
            3 => {
                try network_gui_frame();
            },
            4 => {
                try graphics_gui_frame();
            },
            5 => {
                try audio_gui_frame();
            },
            6 => {
                try peripherals_gui_frame();
            },
            7 => {
                try drives_gui_frame();
            },
            8 => {
                try command_line_gui_frame();
            },
            else => {},
        }
    }
}

fn init_basic() !void {
    @memset(&name, 0);
    @memset(&architecture, 0);
    @memset(&chipset, 0);
    @memset(&usb_type, 0);

    set_buffer(&name, vm.basic.name);
    set_buffer(&architecture, utils.architecture_to_string(vm.basic.architecture));
    set_buffer(&chipset, utils.chipset_to_string(vm.basic.chipset));
    set_buffer(&usb_type, utils.usb_type_to_string(vm.basic.usb_type));

    has_acceleration = vm.basic.has_acceleration;
    has_ahci = vm.basic.has_ahci;
}

fn init_memory() !void {
    var ram_format = try std.fmt.allocPrint(main.gpa, "{d}", .{vm.memory.ram});
    defer main.gpa.free(ram_format);

    @memset(&ram, 0);

    set_buffer(&ram, ram_format);
}

fn init_processor() !void {
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

fn init_network() !void {}

fn init_graphics() !void {
    @memset(&display, 0);
    @memset(&gpu, 0);

    set_buffer(&display, utils.display_to_string(vm.graphics.display));
    set_buffer(&gpu, utils.gpu_to_string(vm.graphics.gpu));

    has_vga_emulation = vm.graphics.has_vga_emulation;
    has_graphics_acceleration = vm.graphics.has_graphics_acceleration;
}

fn init_audio() !void {}

fn init_peripherals() !void {}

fn init_drives() !void {}

fn basic_gui_frame() !void {
    option_index = 0;

    try add_text_option("Name", &name);
    try add_text_option("Architecture", &architecture);
    try add_bool_option("Hardware acceleration", &has_acceleration); // TODO: Detect host architecture
    try add_text_option("Chipset", &chipset);
    try add_text_option("USB type", &usb_type);
    try add_bool_option("Use AHCI", &has_ahci);

    if (try gui.button(@src(), "Save", .{ .expand = .horizontal, .color_style = .accent })) {
        // Write updated data to struct
        vm.basic.name = (utils.sanitize_output_text(&name, true) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid name!" });
            return;
        }).items;

        vm.basic.architecture = utils.string_to_architecture((utils.sanitize_output_text(&architecture, false) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid architecture name!" });
            return;
        }).items) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid architecture name!" });
            return;
        };

        vm.basic.has_acceleration = has_acceleration;

        vm.basic.chipset = utils.string_to_chipset((utils.sanitize_output_text(&chipset, false) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid chipset name!" });
            return;
        }).items) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid chipset name!" });
            return;
        };

        vm.basic.usb_type = utils.string_to_usb_type((utils.sanitize_output_text(&usb_type, false) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid USB type!" });
            return;
        }).items) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid USB type!" });
            return;
        };

        vm.basic.has_ahci = has_ahci;

        // Sanity checks
        if (vm.processor.cpu == structs.Cpu.host and !vm.basic.has_acceleration) {
            try gui.dialog(@src(), .{ .title = "Error", .message = "CPU model \"host\" requires hardware acceleration." });
            return;
        }

        // Write to file
        var file_name = try std.fmt.allocPrint(main.gpa, "{s}.ini", .{vm.basic.name});
        defer main.gpa.free(file_name);

        var file = try std.fs.cwd().openFile(file_name, .{ .mode = .read_write });
        defer file.close();

        try ini.writeStruct(vm, file.writer());
    }
}

fn memory_gui_frame() !void {
    option_index = 0;

    try add_text_option("RAM (in MiB)", &ram);

    if (try gui.button(@src(), "Save", .{ .expand = .horizontal, .color_style = .accent })) {
        // Write updated data to struct
        vm.memory.ram = utils.sanitize_output_number(&ram) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid amount of RAM!" });
            return;
        };

        // Write to file
        var file_name = try std.fmt.allocPrint(main.gpa, "{s}.ini", .{vm.basic.name});
        defer main.gpa.free(file_name);

        var file = try std.fs.cwd().createFile(file_name, .{});
        defer file.close();

        try ini.writeStruct(vm, file.writer());
    }
}

fn processor_gui_frame() !void {
    option_index = 0;

    try add_text_option("CPU", &cpu);
    try add_text_option("Features", &features);
    try add_text_option("Cores", &cores);
    try add_text_option("Threads", &threads);

    if (try gui.button(@src(), "Save", .{ .expand = .horizontal, .color_style = .accent })) {
        // Write updated data to struct
        vm.processor.cpu = utils.string_to_cpu((utils.sanitize_output_text(&cpu, false) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid CPU model name!" });
            return;
        }).items) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid CPU model name!" });
            return;
        };

        vm.processor.features = (utils.sanitize_output_text(&features, false) catch {
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

        // Sanity checks
        if (vm.processor.cpu == structs.Cpu.host and !vm.basic.has_acceleration) {
            try gui.dialog(@src(), .{ .title = "Error", .message = "CPU model \"host\" requires hardware acceleration." });
            return;
        }

        // Write to file
        var file_name = try std.fmt.allocPrint(main.gpa, "{s}.ini", .{vm.basic.name});
        defer main.gpa.free(file_name);

        var file = try std.fs.cwd().createFile(file_name, .{});
        defer file.close();

        try ini.writeStruct(vm, file.writer());
    }
}

fn network_gui_frame() !void {}

fn graphics_gui_frame() !void {
    option_index = 0;

    try add_text_option("Display", &display);
    try add_text_option("GPU", &gpu);
    try add_bool_option("VGA emulation", &has_vga_emulation);
    try add_bool_option("Graphics acceleration", &has_graphics_acceleration);

    if (try gui.button(@src(), "Save", .{ .expand = .horizontal, .color_style = .accent })) {
        // Write updated data to struct
        vm.graphics.display = utils.string_to_display((utils.sanitize_output_text(&display, false) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid display name!" });
            return;
        }).items) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid display name!" });
            return;
        };

        vm.graphics.gpu = utils.string_to_gpu((utils.sanitize_output_text(&gpu, false) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid GPU model name!" });
            return;
        }).items) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid GPU model name!" });
            return;
        };

        vm.graphics.has_vga_emulation = has_vga_emulation;

        vm.graphics.has_graphics_acceleration = has_graphics_acceleration;

        // Sanity checks
        if (vm.graphics.gpu == structs.Gpu.vga and !vm.graphics.has_vga_emulation) {
            try gui.dialog(@src(), .{ .title = "Error", .message = "GPU model \"vga\" requires VGA emulation." });
            return;
        } else if (vm.graphics.gpu == structs.Gpu.vga and vm.graphics.has_graphics_acceleration) {
            try gui.dialog(@src(), .{ .title = "Error", .message = "GPU model \"vga\" doesn't support graphics acceleration." });
            return;
        } else if (vm.graphics.gpu == structs.Gpu.qxl and vm.graphics.has_graphics_acceleration) {
            try gui.dialog(@src(), .{ .title = "Error", .message = "GPU model \"qxl\" doesn't support graphics acceleration." });
            return;
        }

        // Write to file
        var file_name = try std.fmt.allocPrint(main.gpa, "{s}.ini", .{vm.basic.name});
        defer main.gpa.free(file_name);

        var file = try std.fs.cwd().createFile(file_name, .{});
        defer file.close();

        try ini.writeStruct(vm, file.writer());
    }
}

fn audio_gui_frame() !void {}

fn peripherals_gui_frame() !void {}

fn drives_gui_frame() !void {}

fn command_line_gui_frame() !void {
    var qemu_arguments = try qemu.get_arguments(vm);
    defer qemu_arguments.deinit();

    var arguments = std.ArrayList(u8).init(main.gpa);
    defer arguments.deinit();

    for (qemu_arguments.items) |arg| {
        for (arg) |c| {
            try arguments.append(c);
        }
        try arguments.append(' ');
    }

    try gui.textEntry(@src(), .{ .text = arguments.items }, .{ .expand = .both });
}

fn set_buffer(buffer: []u8, value: []const u8) void {
    var index: u64 = 0;

    for (value) |c| {
        buffer[index] = c;
        index += 1;
    }
}

fn add_text_option(option_name: []const u8, buffer: []u8) !void {
    try gui.label(@src(), "{s}:", .{option_name}, .{ .id_extra = option_index });
    option_index += 1;

    try gui.textEntry(@src(), .{ .text = buffer }, .{ .expand = .horizontal, .id_extra = option_index });
    option_index += 1;
}

fn add_bool_option(option_name: []const u8, value: *bool) !void {
    try gui.checkbox(@src(), value, option_name, .{ .id_extra = option_index });
    option_index += 1;
}