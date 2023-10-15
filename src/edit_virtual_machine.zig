const std = @import("std");
const builtin = @import("builtin");
const gui = @import("gui");
const fonts = gui.bitstream_vera;
const ini = @import("ini");
const structs = @import("structs.zig");
const main = @import("main.zig");
const utils = @import("utils.zig");
const qemu = @import("qemu.zig");
const Allocator = std.mem.Allocator;

pub var vm: structs.VirtualMachine = undefined;
pub var vm_index: u64 = undefined;
pub var show = false;

var allocator: Allocator = undefined;

var format_buffer = std.mem.zeroes([1024]u8);

var drives: []*structs.Drive = undefined;

var vm_directory: std.fs.Dir = undefined;
var initialized: bool = undefined;

var setting: u64 = undefined;
var option_index: u64 = undefined;

var override_qemu_path: bool = undefined;
var qemu_path = std.mem.zeroes([512]u8);

var name = std.mem.zeroes([128]u8);
var architecture: u64 = undefined;
var has_acceleration: bool = undefined;
var chipset: u64 = undefined;
var usb_type: u64 = undefined;
var has_ahci: bool = undefined;

var firmware_type: u64 = undefined;
var firmware_path = std.mem.zeroes([512]u8);

var ram = std.mem.zeroes([32]u8);

var cpu: u64 = undefined;
var features = std.mem.zeroes([1024]u8);
var cores = std.mem.zeroes([16]u8);
var threads = std.mem.zeroes([16]u8);

var network_type: u64 = undefined;
var interface: u64 = undefined;

var display: u64 = undefined;
var sdl_grab_modifier_keys = std.mem.zeroes([32]u8);
var sdl_show_cursor: bool = undefined;
var sdl_quit_on_window_close: bool = undefined;
var gtk_full_screen: bool = undefined;
var gtk_grab_on_hover: bool = undefined;
var gtk_show_tabs: bool = undefined;
var gtk_show_cursor: bool = undefined;
var gtk_quit_on_window_close: bool = undefined;
var gtk_zoom_to_fit: bool = undefined;
var cocoa_show_cursor: bool = undefined;
var cocoa_left_command_key: bool = undefined;
var dbus_address = std.mem.zeroes([128]u8);
var dbus_peer_to_peer: bool = undefined;

var gpu: u64 = undefined;
var has_vga_emulation: bool = undefined;
var has_graphics_acceleration: bool = undefined;

var host_device: u64 = undefined;
var sound: u64 = undefined;
var has_input = false;
var has_output = false;

var keyboard: u64 = undefined;
var mouse: u64 = undefined;
var has_mouse_absolute_pointing: bool = undefined;

var drives_options = std.mem.zeroes([5]struct {
    is_cdrom: bool,
    is_removable: bool,
    bus: u64,
    format: u64,
    cache: u64,
    is_ssd: bool,
    path: [512]u8,
});

var deleting_vm = false;
var deletion_confirmation = false;
var deletion_confirmation_text = std.mem.zeroes([128]u8);

pub fn init(frame_allocator: Allocator) !void {
    allocator = frame_allocator;

    drives = try allocator.alloc(*structs.Drive, 5);
    drives[0] = &vm.drive0;
    drives[1] = &vm.drive1;
    drives[2] = &vm.drive2;
    drives[3] = &vm.drive3;
    drives[4] = &vm.drive4;

    vm_directory = try std.fs.cwd().openDir(vm.basic.name, .{});

    try vm_directory.setAsCwd();

    try init_qemu();
    try init_basic();
    try init_firmware();
    try init_memory();
    try init_processor();
    try init_network();
    try init_graphics();
    try init_audio();
    try init_peripherals();
    try init_drives();

    setting = 0;
    initialized = true;
}

pub fn deinit() !void {
    try main.virtual_machines_directory.setAsCwd();

    vm_directory.close();

    allocator.free(drives);
}

pub fn guiFrame() !void {
    if (!show) {
        if (initialized) {
            try deinit();

            initialized = false;
        }

        return;
    }

    var window = try gui.floatingWindow(@src(), .{ .open_flag = &show }, .{ .min_size_content = .{ .w = 800, .h = 600 } });
    defer window.deinit();

    try gui.windowHeader("Edit virtual machine", vm.basic.name, &show);

    var hbox = try gui.box(@src(), .horizontal, .{ .expand = .horizontal, .min_size_content = .{ .h = 600 } });
    defer hbox.deinit();

    {
        var vbox = try gui.box(@src(), .vertical, .{});
        defer vbox.deinit();

        if (try gui.button(@src(), "QEMU", .{ .expand = .horizontal })) setting = 0;
        if (try gui.button(@src(), "Basic", .{ .expand = .horizontal })) setting = 1;
        if (try gui.button(@src(), "Firmware", .{ .expand = .horizontal })) setting = 2;
        if (try gui.button(@src(), "Memory", .{ .expand = .horizontal })) setting = 3;
        if (try gui.button(@src(), "Processor", .{ .expand = .horizontal })) setting = 4;
        if (try gui.button(@src(), "Network", .{ .expand = .horizontal })) setting = 5;
        if (try gui.button(@src(), "Graphics", .{ .expand = .horizontal })) setting = 6;
        if (try gui.button(@src(), "Audio", .{ .expand = .horizontal })) setting = 7;
        if (try gui.button(@src(), "Peripherals", .{ .expand = .horizontal })) setting = 8;
        if (try gui.button(@src(), "Drives", .{ .expand = .horizontal })) setting = 9;
        if (try gui.button(@src(), "Command line", .{ .expand = .horizontal })) setting = 10;
        if (try gui.button(@src(), "Run", .{ .expand = .horizontal, .color_style = .accent })) {
            var qemu_arguments = try qemu.getArguments(allocator, vm, drives);
            defer qemu_arguments.deinit();

            var qemu_process = std.ChildProcess.init(qemu_arguments.items, allocator);

            qemu_process.spawn() catch {
                try gui.dialog(@src(), .{ .title = "Error", .message = "Unable to create a child process for QEMU." });
                return;
            };
        }

        if (try gui.button(@src(), "Delete", .{ .expand = .horizontal, .color_style = .err })) {
            if (deleting_vm) return;

            deleting_vm = true;
        }

        if (deleting_vm) try delete_confirmation_modal();
    }

    var vbox = try gui.box(@src(), .vertical, .{ .expand = .both, .padding = .{ .x = 20, .y = 20, .w = 20, .h = 20 } });
    defer vbox.deinit();

    switch (setting) {
        0 => try qemu_gui_frame(),
        1 => try basic_gui_frame(),
        2 => try firmware_gui_frame(),
        3 => try memory_gui_frame(),
        4 => try processor_gui_frame(),
        5 => try network_gui_frame(),
        6 => try graphics_gui_frame(),
        7 => try audio_gui_frame(),
        8 => try peripherals_gui_frame(),
        9 => try drives_gui_frame(),
        10 => try command_line_gui_frame(),
        else => {},
    }
}

fn init_qemu() !void {
    @memset(&qemu_path, 0);

    override_qemu_path = vm.qemu.override_qemu_path;
    set_buffer(&qemu_path, vm.qemu.qemu_path);
}

fn init_basic() !void {
    @memset(&name, 0);

    set_buffer(&name, vm.basic.name);
    architecture = @intFromEnum(vm.basic.architecture);
    has_acceleration = vm.basic.has_acceleration;
    chipset = @intFromEnum(vm.basic.chipset);
    usb_type = @intFromEnum(vm.basic.usb_type);
    has_ahci = vm.basic.has_ahci;
}

fn init_firmware() !void {
    @memset(&firmware_path, 0);

    firmware_type = @intFromEnum(vm.firmware.type);
    set_buffer(&firmware_path, vm.firmware.firmware_path);
}

fn init_memory() !void {
    var ram_format = try std.fmt.allocPrint(allocator, "{d}", .{vm.memory.ram});
    defer allocator.free(ram_format);

    @memset(&ram, 0);

    set_buffer(&ram, ram_format);
}

fn init_processor() !void {
    var cores_format = try std.fmt.allocPrint(allocator, "{d}", .{vm.processor.cores});
    defer allocator.free(cores_format);

    var threads_format = try std.fmt.allocPrint(allocator, "{d}", .{vm.processor.threads});
    defer allocator.free(threads_format);

    @memset(&features, 0);
    @memset(&cores, 0);
    @memset(&threads, 0);

    cpu = @intFromEnum(vm.processor.cpu);
    set_buffer(&features, vm.processor.features);
    set_buffer(&cores, cores_format);
    set_buffer(&threads, threads_format);
}

fn init_network() !void {
    network_type = @intFromEnum(vm.network.type);
    interface = @intFromEnum(vm.network.interface);
}

fn init_graphics() !void {
    @memset(&sdl_grab_modifier_keys, 0);
    @memset(&dbus_address, 0);

    display = @intFromEnum(vm.graphics.display);
    set_buffer(&sdl_grab_modifier_keys, vm.graphics.sdl_grab_modifier_keys);
    sdl_show_cursor = vm.graphics.sdl_show_cursor;
    sdl_quit_on_window_close = vm.graphics.sdl_quit_on_window_close;
    gtk_full_screen = vm.graphics.gtk_full_screen;
    gtk_grab_on_hover = vm.graphics.gtk_grab_on_hover;
    gtk_show_tabs = vm.graphics.gtk_show_tabs;
    gtk_show_cursor = vm.graphics.gtk_show_cursor;
    gtk_quit_on_window_close = vm.graphics.gtk_quit_on_window_close;
    gtk_zoom_to_fit = vm.graphics.gtk_zoom_to_fit;
    cocoa_show_cursor = vm.graphics.cocoa_show_cursor;
    cocoa_left_command_key = vm.graphics.cocoa_left_command_key;
    set_buffer(&dbus_address, vm.graphics.dbus_address);
    dbus_peer_to_peer = vm.graphics.dbus_peer_to_peer;
    gpu = @intFromEnum(vm.graphics.gpu);
    has_vga_emulation = vm.graphics.has_vga_emulation;
    has_graphics_acceleration = vm.graphics.has_graphics_acceleration;
}

fn init_audio() !void {
    host_device = @intFromEnum(vm.audio.host_device);
    sound = @intFromEnum(vm.audio.sound);
    has_input = vm.audio.has_input;
    has_output = vm.audio.has_output;
}

fn init_peripherals() !void {
    keyboard = @intFromEnum(vm.peripherals.keyboard);
    mouse = @intFromEnum(vm.peripherals.mouse);
    has_mouse_absolute_pointing = vm.peripherals.has_mouse_absolute_pointing;
}

fn init_drives() !void {
    for (drives, 0..) |drive, i| {
        var drive_options = &drives_options[i];

        @memset(&drive_options.path, 0);

        drive_options.*.is_cdrom = drive.is_cdrom;
        drive_options.*.is_removable = drive.is_removable;
        drive_options.*.bus = @intFromEnum(drive.bus);
        drive_options.*.format = @intFromEnum(drive.format);
        drive_options.*.cache = @intFromEnum(drive.cache);
        drive_options.*.is_ssd = drive.is_ssd;
        set_buffer(&drive_options.path, drive.path);
    }
}

fn qemu_gui_frame() !void {
    option_index = 0;

    try utils.addBoolOption("Override QEMU path", &override_qemu_path, &option_index);
    if (override_qemu_path) try utils.addTextOption("QEMU path", &qemu_path, &option_index);

    if (try gui.button(@src(), "Save", .{ .expand = .horizontal, .color_style = .accent })) {
        // Write updated data to struct
        vm.qemu.override_qemu_path = override_qemu_path;
        vm.qemu.qemu_path = (utils.sanitizeOutputText(allocator, &qemu_path, false) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid path for QEMU!" });
            return;
        }).items;

        // Write to file
        try save_changes();
    }
}

fn basic_gui_frame() !void {
    option_index = 0;

    try utils.addTextOption("Name", &name, &option_index);
    try utils.addComboOption("Architecture", &.{"AMD64"}, &architecture, &option_index);
    try utils.addBoolOption("Hardware acceleration", &has_acceleration, &option_index); // TODO: Detect host architecture
    try utils.addComboOption("Chipset", &.{ "i440FX", "Q35" }, &chipset, &option_index);
    try utils.addComboOption("USB type", &.{ "None", "OHCI (Open 1.0)", "UHCI (Proprietary 1.0)", "EHCI (2.0)", "XHCI (3.0)" }, &usb_type, &option_index);
    try utils.addBoolOption("Use AHCI", &has_ahci, &option_index);

    if (try gui.button(@src(), "Save", .{ .expand = .horizontal, .color_style = .accent })) {
        const old_name = vm.basic.name;

        // Write updated data to struct
        vm.basic.name = (utils.sanitizeOutputText(allocator, &name, true) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid name!" });
            return;
        }).items;
        vm.basic.architecture = @enumFromInt(architecture);
        vm.basic.has_acceleration = has_acceleration;
        vm.basic.chipset = @enumFromInt(chipset);
        vm.basic.usb_type = @enumFromInt(usb_type);
        vm.basic.has_ahci = has_ahci;

        // Rename VM folder if name has changed
        if (!std.mem.eql(u8, old_name, vm.basic.name)) {
            try main.virtual_machines_directory.rename(old_name, vm.basic.name);
        }

        // Sanity checks
        if (vm.processor.cpu == .host and !vm.basic.has_acceleration) {
            try gui.dialog(@src(), .{ .title = "Error", .message = "CPU model \"host\" requires hardware acceleration." });
            return;
        } else if (vm.basic.usb_type == .none and vm.network.interface == .usb) {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Network interface \"usb\" requires a USB controller." });
            return;
        } else if (vm.basic.usb_type == .none and vm.audio.sound == .usb) {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Sound device \"usb\" requires a USB controller." });
            return;
        } else if (vm.basic.usb_type == .none and vm.peripherals.keyboard == .usb) {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Keyboard model \"usb\" requires a USB controller." });
            return;
        } else if (vm.basic.usb_type == .none and vm.peripherals.mouse == .usb) {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Mouse model \"usb\" requires a USB controller." });
            return;
        } else if (vm.basic.architecture != .amd64 and vm.firmware.type == .bios) {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Firmware \"bios\" only works with the AMD64 architecture." });
            return;
        }

        for (drives, 0..) |drive, i| {
            if (vm.basic.usb_type == .none and drive.bus == .usb) {
                try gui.dialog(@src(), .{ .title = "Error", .message = try std.fmt.bufPrint(&format_buffer, "Bus \"usb\" of drive {d} requires a USB controller.", .{i}) });
                return;
            } else if (!vm.basic.has_ahci and drive.bus == .sata) {
                try gui.dialog(@src(), .{ .title = "Error", .message = try std.fmt.bufPrint(&format_buffer, "Bus \"sata\" of drive {d} requires a USB controller.", .{i}) });
                return;
            }
        }

        // Write to file
        try save_changes();
    }
}

fn firmware_gui_frame() !void {
    option_index = 0;

    try utils.addComboOption("Type", &.{ "BIOS", "UEFI", "Custom PC", "Custom PFlash" }, &firmware_type, &option_index);
    if (firmware_type >= 2) try utils.addTextOption("Path", &firmware_path, &option_index);

    if (try gui.button(@src(), "Save", .{ .expand = .horizontal, .color_style = .accent })) {
        // Write updated data to struct
        vm.firmware.type = @enumFromInt(firmware_type);
        vm.firmware.firmware_path = (utils.sanitizeOutputText(allocator, &firmware_path, false) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid firmware path!" });
            return;
        }).items;

        // Sanity checks
        if (vm.firmware.type == .bios and vm.basic.architecture != .amd64) {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Firmware \"bios\" only works with the AMD64 architecture." });
            return;
        }

        // Write to file
        try save_changes();
    }
}

fn memory_gui_frame() !void {
    option_index = 0;

    try utils.addTextOption("RAM (in MiB)", &ram, &option_index);

    if (try gui.button(@src(), "Save", .{ .expand = .horizontal, .color_style = .accent })) {
        // Write updated data to struct
        vm.memory.ram = utils.sanitizeOutputNumber(allocator, &ram) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid amount of RAM!" });
            return;
        };

        // Write to file
        try save_changes();
    }
}

fn processor_gui_frame() !void {
    option_index = 0;

    try utils.addComboOption("CPU", &.{
        "486-v1",
        "486",
        "athlon-v1",
        "athlon",
        "base",
        "Broadwell-IBRS",
        "Broadwell-noTSX-IBRS",
        "Broadwell-noTSX",
        "Broadwell-v1",
        "Broadwell-v2",
        "Broadwell-v3",
        "Broadwell-v4",
        "Broadwell",
        "Cascadelake-Server-noTSX",
        "Cascadelake-Server-v1",
        "Cascadelake-Server-v2",
        "Cascadelake-Server-v3",
        "Cascadelake-Server-v4",
        "Cascadelake-Server-v5",
        "Cascadelake-Server",
        "Conroe-v1",
        "Conroe",
        "Cooperlake-v1",
        "Cooperlake-v2",
        "Cooperlake",
        "core2duo-v1",
        "core2duo",
        "coreduo-v1",
        "coreduo",
        "Denverton-v1",
        "Denverton-v2",
        "Denverton-v3",
        "Denverton",
        "Dhyana-v1",
        "Dhyana-v2",
        "Dhyana",
        "EPYC-IBPB",
        "EPYC-Milan-v1",
        "EPYC-Milan",
        "EPYC-Rome-v1",
        "EPYC-Rome-v2",
        "EPYC-Rome",
        "EPYC-v1",
        "EPYC-v2",
        "EPYC-v3",
        "EPYC",
        "Haswell-IBRS",
        "Haswell-noTSX-IBRS",
        "Haswell-noTSX",
        "Haswell-v1",
        "Haswell-v2",
        "Haswell-v3",
        "Haswell-v4",
        "Haswell",
        "host",
        "Icelake-Server-noTSX",
        "Icelake-Server-v1",
        "Icelake-Server-v2",
        "Icelake-Server-v3",
        "Icelake-Server-v4",
        "Icelake-Server-v5",
        "Icelake-Server-v6",
        "Icelake-Server",
        "IvyBridge-IBRS",
        "IvyBridge-v1",
        "IvyBridge-v2",
        "IvyBridge",
        "KnightsMill-v1",
        "KnightsMill",
        "kvm32-v1",
        "kvm32",
        "kvm64-v1",
        "kvm64",
        "max",
        "n270-v1",
        "n270",
        "Nehalem-IBRS",
        "Nehalem-v1",
        "Nehalem-v2",
        "Nehalem",
        "Opteron_G1-v1",
        "Opteron_G1",
        "Opteron_G2-v1",
        "Opteron_G2",
        "Opteron_G3-v1",
        "Opteron_G3",
        "Opteron_G4-v1",
        "Opteron_G4",
        "Opteron_G5-v1",
        "Opteron_G5",
        "Penryn-v1",
        "Penryn",
        "pentium-v1",
        "pentium",
        "pentium2-v1",
        "pentium2",
        "pentium3-v1",
        "pentium3",
        "phenom-v1",
        "phenom",
        "qemu32-v1",
        "qemu32",
        "qemu64-v1",
        "qemu64",
        "SandyBridge-IBRS",
        "SandyBridge-v1",
        "SandyBridge-v2",
        "SandyBridge",
        "Skylake-Client-IBRS",
        "Skylake-Client-noTSX-IBRS",
        "Skylake-Client-v1",
        "Skylake-Client-v2",
        "Skylake-Client-v3",
        "Skylake-Client-v4",
        "Skylake-Client",
        "Skylake-Server-IBRS",
        "Skylake-Server-noTSX-IBRS",
        "Skylake-Server-v1",
        "Skylake-Server-v2",
        "Skylake-Server-v3",
        "Skylake-Server-v4",
        "Skylake-Server-v5",
        "Skylake-Server",
        "Snowridge-v1",
        "Snowridge-v2",
        "Snowridge-v3",
        "Snowridge-v4",
        "Snowridge",
        "Westmere-IBRS",
        "Westmere-v1",
        "Westmere-v2",
        "Westmere",
    }, &cpu, &option_index);
    try utils.addTextOption("Features", &features, &option_index);
    try utils.addTextOption("Cores", &cores, &option_index);
    try utils.addTextOption("Threads", &threads, &option_index);

    if (try gui.button(@src(), "Save", .{ .expand = .horizontal, .color_style = .accent })) {
        // Write updated data to struct
        vm.processor.cpu = @enumFromInt(cpu);
        vm.processor.features = (utils.sanitizeOutputText(allocator, &features, false) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid feature subset!" });
            return;
        }).items;
        vm.processor.cores = utils.sanitizeOutputNumber(allocator, &cores) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid amount of cores!" });
            return;
        };
        vm.processor.threads = utils.sanitizeOutputNumber(allocator, &threads) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid amount of threads!" });
            return;
        };

        // Sanity checks
        if (vm.processor.cpu == .host and !vm.basic.has_acceleration) {
            try gui.dialog(@src(), .{ .title = "Error", .message = "CPU model \"host\" requires hardware acceleration." });
            return;
        }

        // Write to file
        try save_changes();
    }
}

fn network_gui_frame() !void {
    option_index = 0;

    try utils.addComboOption("Type", &.{ "None", "NAT" }, &network_type, &option_index);
    try utils.addComboOption("Interface", &.{ "RTL8139", "E1000", "E1000e", "VMware", "USB", "VirtIO" }, &interface, &option_index);

    if (try gui.button(@src(), "Save", .{ .expand = .horizontal, .color_style = .accent })) {
        // Write updated data to struct
        vm.network.type = @enumFromInt(network_type);
        vm.network.interface = @enumFromInt(interface);

        // Write to file
        try save_changes();
    }
}

fn graphics_gui_frame() !void {
    option_index = 0;

    try utils.addComboOption("Display", &.{ "None", "Auto", "SDL", "GTK", "SPICE", "Cocoa", "D-Bus" }, &display, &option_index);
    switch (display) {
        2 => {
            try utils.addTextOption("Modifier keys for mouse grabbing", &sdl_grab_modifier_keys, &option_index);
            try utils.addBoolOption("Force showing cursor", &sdl_show_cursor, &option_index);
            try utils.addBoolOption("Quit on window close", &sdl_quit_on_window_close, &option_index);
        },
        3 => {
            try utils.addBoolOption("Start in full screen", &gtk_full_screen, &option_index);
            try utils.addBoolOption("Grab cursor on mouse hover", &gtk_grab_on_hover, &option_index);
            try utils.addBoolOption("Show graphical interface tabs", &gtk_show_tabs, &option_index);
            try utils.addBoolOption("Force showing cursor", &gtk_show_cursor, &option_index);
            try utils.addBoolOption("Quit on window close", &gtk_quit_on_window_close, &option_index);
            try utils.addBoolOption("Zoom video output to fit window size", &gtk_zoom_to_fit, &option_index);
        },
        5 => {
            try utils.addBoolOption("Force showing cursor", &cocoa_show_cursor, &option_index);
            try utils.addBoolOption("Disable forwarding left command key to host", &cocoa_left_command_key, &option_index);
        },
        6 => {
            try utils.addTextOption("Address", &dbus_address, &option_index);
            try utils.addBoolOption("Use peer-to-peer connection", &dbus_peer_to_peer, &option_index);
        },
        else => {},
    }
    try utils.addComboOption("GPU", &.{ "None", "VGA", "Cirrus", "QXL", "VMware", "VirtIO" }, &gpu, &option_index);
    try utils.addBoolOption("VGA emulation", &has_vga_emulation, &option_index);
    try utils.addBoolOption("Graphics acceleration", &has_graphics_acceleration, &option_index);

    // First sanity checks
    if (gpu == 1 or gpu == 2 or gpu == 4) has_vga_emulation = true;
    if (gpu >= 1 and gpu <= 4) has_graphics_acceleration = false;

    if (try gui.button(@src(), "Save", .{ .expand = .horizontal, .color_style = .accent })) {
        // Write updated data to struct
        vm.graphics.display = @enumFromInt(display);
        vm.graphics.sdl_grab_modifier_keys = (utils.sanitizeOutputText(allocator, &sdl_grab_modifier_keys, false) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter valid modifier keys!" });
            return;
        }).items;
        vm.graphics.sdl_show_cursor = sdl_show_cursor;
        vm.graphics.sdl_quit_on_window_close = sdl_quit_on_window_close;
        vm.graphics.gtk_full_screen = gtk_full_screen;
        vm.graphics.gtk_grab_on_hover = gtk_grab_on_hover;
        vm.graphics.gtk_show_tabs = gtk_show_tabs;
        vm.graphics.gtk_show_cursor = gtk_show_cursor;
        vm.graphics.gtk_quit_on_window_close = gtk_quit_on_window_close;
        vm.graphics.gtk_zoom_to_fit = gtk_zoom_to_fit;
        vm.graphics.cocoa_show_cursor = cocoa_show_cursor;
        vm.graphics.cocoa_left_command_key = cocoa_left_command_key;
        vm.graphics.dbus_address = (utils.sanitizeOutputText(allocator, &dbus_address, false) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid D-Bus address!" });
            return;
        }).items;
        vm.graphics.dbus_peer_to_peer = dbus_peer_to_peer;
        vm.graphics.gpu = @enumFromInt(gpu);
        vm.graphics.has_vga_emulation = has_vga_emulation;
        vm.graphics.has_graphics_acceleration = has_graphics_acceleration;

        // Second sanity checks
        if (vm.graphics.display == .cocoa and builtin.os.tag != .macos) {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Display \"cocoa\" is only supported on macOS." });
            return;
        } else if (vm.graphics.display == .dbus and !switch (builtin.os.tag) {
            .linux, .kfreebsd, .freebsd, .openbsd, .netbsd, .dragonfly => true,
            else => false,
        }) {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Display \"dbus\" is only supported on Linux/BSD." });
            return;
        }

        // Write to file
        try save_changes();
    }
}

fn audio_gui_frame() !void {
    option_index = 0;

    try utils.addComboOption("Host device", &.{ "None", "Auto", "SDL", "ALSA", "OSS", "PulseAudio", "PipeWire", "sndio", "CoreAudio", "DirectSound", "WAV" }, &host_device, &option_index);
    try utils.addComboOption("Sound", &.{ "Sound Blaster 16", "AC97", "HDA ICH6", "HDA ICH9", "USB" }, &sound, &option_index);
    try utils.addBoolOption("Input", &has_input, &option_index);
    try utils.addBoolOption("Output", &has_output, &option_index);

    // First sanity checks
    if (sound <= 1 or sound == 4) {
        has_input = false;
        has_output = true;
    }

    if (try gui.button(@src(), "Save", .{ .expand = .horizontal, .color_style = .accent })) {
        // Write updated data to struct
        vm.audio.host_device = @enumFromInt(host_device);
        vm.audio.sound = @enumFromInt(sound);
        vm.audio.has_input = has_input;
        vm.audio.has_output = has_output;

        // Second sanity checks
        if (vm.audio.sound == .usb and vm.basic.usb_type == .none) {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Sound device \"usb\" requires a USB controller." });
            return;
        } else if (builtin.os.tag == .windows and host_device >= 3 and host_device <= 7) {
            try gui.dialog(@src(), .{ .title = "Error", .message = try std.fmt.bufPrint(&format_buffer, "Audio host device \"{}\" is unsupported by Windows.", .{vm.audio.host_device}) });
            return;
        } else if (builtin.os.tag == .macos and ((host_device >= 3 and host_device <= 6) or host_device == 8)) {
            try gui.dialog(@src(), .{ .title = "Error", .message = try std.fmt.bufPrint(&format_buffer, "Audio host device \"{}\" is unsupported by macOS.", .{vm.audio.host_device}) });
            return;
        } else if (host_device == 7 or host_device == 8) {
            try gui.dialog(@src(), .{ .title = "Error", .message = try std.fmt.bufPrint(&format_buffer, "Audio host device \"{}\" is unsupported by Linux/BSD.", .{vm.audio.host_device}) });
            return;
        }

        // Write to file
        try save_changes();
    }
}

fn peripherals_gui_frame() !void {
    option_index = 0;

    try utils.addComboOption("Keyboard", &.{ "None", "USB", "VirtIO" }, &keyboard, &option_index);
    try utils.addComboOption("Mouse", &.{ "None", "USB", "VirtIO" }, &mouse, &option_index);
    try utils.addBoolOption("Absolute mouse pointing", &has_mouse_absolute_pointing, &option_index);

    if (try gui.button(@src(), "Save", .{ .expand = .horizontal, .color_style = .accent })) {
        // Write updated data to struct
        vm.peripherals.keyboard = @enumFromInt(keyboard);
        vm.peripherals.mouse = @enumFromInt(mouse);
        vm.peripherals.has_mouse_absolute_pointing = has_mouse_absolute_pointing;

        // Sanity checks
        if (vm.peripherals.keyboard == .usb and vm.basic.usb_type == .none) {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Keyboard model \"usb\" requires a USB controller." });
            return;
        } else if (vm.peripherals.mouse == .usb and vm.basic.usb_type == .none) {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Mouse model \"usb\" requires a USB controller." });
            return;
        }

        // Write to file
        try save_changes();
    }
}

fn drives_gui_frame() !void {
    option_index = 0;

    var scroll = try gui.scrollArea(@src(), .{}, .{ .expand = .both, .color_style = .window });
    defer scroll.deinit();

    for (drives, 0..) |_, i| {
        var drive_options = &drives_options[i];

        try gui.label(@src(), "Drive {d}:", .{i}, .{ .id_extra = option_index });

        try utils.addBoolOption("CD-ROM", &drive_options.is_cdrom, &option_index);
        try utils.addBoolOption("Removable", &drive_options.is_removable, &option_index);
        try utils.addComboOption("Bus", &.{ "USB", "IDE", "SATA", "NVMe", "VirtIO" }, &drive_options.bus, &option_index);
        try utils.addComboOption("Format", &.{ "Raw", "QCOW2", "VMDK", "VDI", "VHD" }, &drive_options.format, &option_index);
        try utils.addComboOption("Cache", &.{ "None", "Writeback", "Writethrough", "Directsync", "Unsafe" }, &drive_options.cache, &option_index);
        try utils.addBoolOption("SSD", &drive_options.is_ssd, &option_index);
        try utils.addTextOption("Path", &drive_options.path, &option_index);

        try gui.separator(@src(), .{ .expand = .horizontal, .id_extra = option_index });

        // First sanity checks
        if (drive_options.bus == 0 or drive_options.bus >= 3) drive_options.*.is_cdrom = false;
        if (drive_options.bus != 0) drive_options.*.is_removable = false;
    }

    if (try gui.button(@src(), "Save", .{ .expand = .horizontal, .color_style = .accent })) {
        // Write updated data to struct
        for (drives, 0..) |drive, i| {
            var drive_options = drives_options[i];

            drive.*.is_cdrom = drive_options.is_cdrom;
            drive.*.is_removable = drive_options.is_removable;
            drive.*.bus = @enumFromInt(drive_options.bus);
            drive.*.format = @enumFromInt(drive_options.format);
            drive.*.cache = @enumFromInt(drive_options.cache);
            drive.*.is_ssd = drive_options.is_ssd;
            drive.*.path = (utils.sanitizeOutputText(allocator, &drive_options.path, false) catch {
                try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid drive path!" });
                return;
            }).items;

            // Second sanity checks
            if (drive.bus == .usb and vm.basic.usb_type == .none) {
                try gui.dialog(@src(), .{ .title = "Error", .message = try std.fmt.bufPrint(&format_buffer, "Bus \"usb\" of drive {d} requires a USB controller.", .{i}) });
                return;
            } else if (drive.bus == .sata and !vm.basic.has_ahci) {
                try gui.dialog(@src(), .{ .title = "Error", .message = try std.fmt.bufPrint(&format_buffer, "Bus \"sata\" of drive {d} requires a SATA controller.", .{i}) });
                return;
            }
        }

        // Write to file
        try save_changes();
    }
}

fn command_line_gui_frame() !void {
    var qemu_arguments = try qemu.getArguments(allocator, vm, drives);
    defer qemu_arguments.deinit();

    var arguments = std.ArrayList(u8).init(allocator);
    defer arguments.deinit();

    for (qemu_arguments.items) |arg| {
        for (arg) |c| {
            try arguments.append(c);
        }
        try arguments.appendSlice(" \\\n    ");
    }

    var entry = try gui.textEntry(@src(), .{ .text = arguments.items }, .{ .expand = .both });
    defer entry.deinit();
}

fn save_changes() !void {
    var file = try std.fs.cwd().createFile("config.ini", .{});
    defer file.close();

    // Save changes to disk
    try ini.writeStruct(vm, file.writer());

    // Update VM in array list
    main.virtual_machines.items[vm_index] = vm;
}

fn set_buffer(buffer: []u8, value: []const u8) void {
    var index: u64 = 0;

    for (value) |c| {
        buffer[index] = c;
        index += 1;
    }
}

fn delete_confirmation_modal() !void {
    // Render a modal when deleting a VM
    var confirmation_window = try gui.floatingWindow(@src(), .{
        .modal = true,
        .open_flag = &deleting_vm,
    }, .{
        .color_style = .window,
        .min_size_content = .{ .w = 300, .h = 100 },
    });
    defer confirmation_window.deinit();

    var confirmation_vbox = try gui.box(@src(), .vertical, .{
        .expand = .both,
        .padding = .{ .x = 20, .y = 20, .w = 20, .h = 20 },
    });
    defer confirmation_vbox.deinit();

    // Render some text to confirm deletion
    try gui.label(@src(), "Are you sure you want to delete this virtual machine?", .{}, .{ .expand = .horizontal });

    // Confirmation text input
    {
        var confiration_input_vbox = try gui.box(@src(), .vertical, .{
            .expand = .both,
            .padding = .{ .x = 0, .y = 5, .w = 0, .h = 5 },
        });
        defer confiration_input_vbox.deinit();

        try gui.label(@src(), "Enter the full name of the VM to confirm deletion:", .{}, .{
            .expand = .horizontal,
            .font = .{
                .size = 8,
                .name = "VeraIt",
                .ttf_bytes = fonts.VeraIt,
            },
        });

        var confirmation_input = try gui.textEntry(@src(), .{
            .text = &deletion_confirmation_text,
            .scroll_vertical = false,
            .scroll_horizontal_bar = .hide,
        }, .{ .expand = .horizontal });
        defer confirmation_input.deinit();
    }

    // A horizontal box to render buttons
    {
        var confirmation_hbox = try gui.box(@src(), .horizontal, .{
            .expand = .horizontal,
            .margin = .{ .y = 5 },
        });
        defer confirmation_hbox.deinit();

        // Cancel button
        if (try gui.button(@src(), "Cancel", .{ .expand = .horizontal, .color_style = .accent })) deleting_vm = false;

        // Confirmation button
        if (try gui.button(@src(), "Confirm", .{ .expand = .horizontal, .color_style = .err })) {
            // Use starts with because the deletion confirmation is the full buffer
            if (!std.mem.eql(u8, deletion_confirmation_text[0..vm.basic.name.len], vm.basic.name)) {
                try gui.dialog(@src(), .{
                    .title = "Error: VM Name Mismatch",
                    .message = "Make sure you enter the full name of the VM to confirm deletion!",
                });
                return;
            }

            // Delete VM directory
            try main.virtual_machines_directory.deleteTree(vm.basic.name);
            // Remove VM from array list
            _ = main.virtual_machines.swapRemove(vm_index);

            // Close window
            show = false;

            // Stop deleting VM
            deleting_vm = false;
        }
    }
}
