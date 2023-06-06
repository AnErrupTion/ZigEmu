const std = @import("std");
const gui = @import("gui");
const structs = @import("structs.zig");
const ini = @import("ini.zig");
const main = @import("main.zig");
const permanent_buffers = @import("permanent_buffers.zig");
const utils = @import("utils.zig");

pub var show = false;

var option_index: u64 = 0;
var name = std.mem.zeroes([128]u8);
var ram = std.mem.zeroes([32]u8);
var cores = std.mem.zeroes([16]u8);
var threads = std.mem.zeroes([16]u8);
var disk = std.mem.zeroes([8]u8);
var has_boot_image = false;
var boot_image = std.mem.zeroes([1024]u8);

pub fn init() void {
    @memset(&name, 0);
    @memset(&ram, 0);
    @memset(&cores, 0);
    @memset(&threads, 0);
    @memset(&disk, 0);
    @memset(&boot_image, 0);

    has_boot_image = false;
}

pub fn gui_frame() !void {
    if (!show) {
        return;
    }

    var window = try gui.floatingWindow(@src(), .{ .open_flag = &show }, .{ .min_size_content = .{ .w = 400, .h = 400 } });
    defer window.deinit();

    try gui.windowHeader("Create a new virtual machine", "", &show);

    var scroll = try gui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer scroll.deinit();

    option_index = 0;

    try add_text_option("Name", &name);
    try add_text_option("RAM (in MiB)", &ram);
    try add_text_option("Cores", &cores);
    try add_text_option("Threads", &threads);
    try add_text_option("Disk size (in GiB)", &disk);
    try add_bool_option("Add a boot image", &has_boot_image);
    if (has_boot_image) {
        try add_text_option("Boot image", &boot_image);
    }

    if (try gui.button(@src(), "Create", .{ .expand = .both, .color_style = .accent })) {
        var actual_name = utils.sanitize_output_name(&name) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid name!" });
            return;
        };
        var actual_ram = utils.sanitize_output_number(&ram) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid amount of RAM!" });
            return;
        };
        var actual_cores = utils.sanitize_output_number(&cores) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid amount of cores!" });
            return;
        };
        var actual_threads = utils.sanitize_output_number(&threads) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid amount of threads!" });
            return;
        };
        var actual_disk = utils.sanitize_output_number(&disk) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid disk size!" });
            return;
        };
        var actual_boot_image = utils.sanitize_output_text(&boot_image) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid boot image path!" });
            return;
        };

        try permanent_buffers.lists.append(actual_name);
        try permanent_buffers.lists.append(actual_boot_image);

        // Dummy drive by default (0 bytes size + empty path)
        var boot_drive: structs.Drive = .{
            .is_cdrom = false,
            .bus = structs.DriveBus.ide,
            .size = 0,
            .path = "",
        };

        if (has_boot_image) {
            boot_drive = .{
                .is_cdrom = true,
                .bus = structs.DriveBus.sata,
                .size = 0,
                .path = actual_boot_image.items,
            };
        }

        var disk_file = try std.fmt.allocPrint(main.gpa, "{s}.img", .{actual_name.items});

        try permanent_buffers.arrays.append(disk_file);

        const vm = structs.VirtualMachine{
            .basic = .{
                .name = actual_name.items,
                .architecture = structs.Architecture.amd64,
                .chipset = structs.Chipset.q35,
                .has_acceleration = true,
                .usb_type = structs.UsbType.ehci,
            },
            .memory = .{ .ram = actual_ram },
            .processor = .{
                .cpu = structs.Cpu.host,
                .features = "",
                .cores = actual_cores,
                .threads = actual_threads,
            },
            .network = .{},
            .graphics = .{
                .display = structs.Display.sdl,
                .gpu = structs.Gpu.vga,
                .has_vga_emulation = true,
                .has_graphics_acceleration = false,
            },
            .audio = .{},
            .peripherals = .{
                .keyboard = structs.Keyboard.usb,
                .mouse = structs.Mouse.usb,
                .has_mouse_absolute_pointing = true,
            },
            .drive0 = .{
                .is_cdrom = false,
                .bus = structs.DriveBus.sata,
                .size = actual_disk,
                .path = disk_file,
            },
            .drive1 = boot_drive,
            .drive2 = .{
                .is_cdrom = false,
                .bus = structs.DriveBus.ide,
                .size = 0,
                .path = "",
            },
            .drive3 = .{
                .is_cdrom = false,
                .bus = structs.DriveBus.ide,
                .size = 0,
                .path = "",
            },
            .drive4 = .{
                .is_cdrom = false,
                .bus = structs.DriveBus.ide,
                .size = 0,
                .path = "",
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

fn add_text_option(text: []const u8, buffer: []u8) !void {
    try gui.label(@src(), "{s}:", .{text}, .{ .id_extra = option_index });
    option_index += 1;

    try gui.textEntry(@src(), .{ .text = buffer }, .{ .expand = .both, .id_extra = option_index });
    option_index += 1;
}

fn add_bool_option(text: []const u8, value: *bool) !void {
    try gui.checkbox(@src(), value, text, .{ .id_extra = option_index });
    option_index += 1;
}
