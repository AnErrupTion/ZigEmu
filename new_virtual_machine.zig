const std = @import("std");
const gui = @import("gui");
const ini = @import("ini");
const structs = @import("structs.zig");
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

    if (try gui.button(@src(), "Create", .{ .expand = .horizontal, .color_style = .accent })) {
        var actual_name = utils.sanitize_output_text(&name, true) catch {
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
        var actual_boot_image = utils.sanitize_output_text(&boot_image, false) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid boot image path!" });
            return;
        };

        try permanent_buffers.lists.append(actual_name);
        try permanent_buffers.lists.append(actual_boot_image);

        // Dummy drive by default (empty path)
        var boot_drive: structs.Drive = .{
            .is_cdrom = false,
            .bus = .ide,
            .format = .raw,
            .path = "",
        };

        if (has_boot_image) {
            boot_drive = .{
                .is_cdrom = true,
                .bus = .sata,
                .format = .raw,
                .path = actual_boot_image.items,
            };
        }

        try std.fs.cwd().makeDir(actual_name.items);

        var vm_directory = try std.fs.cwd().openDir(actual_name.items, .{});
        defer vm_directory.close();

        try vm_directory.setAsCwd();

        const vm = structs.VirtualMachine{
            .basic = .{
                .name = actual_name.items,
                .architecture = .amd64,
                .chipset = .q35,
                .has_acceleration = true,
                .usb_type = .ehci,
                .has_ahci = true,
            },
            .memory = .{
                .ram = actual_ram,
            },
            .processor = .{
                .cpu = .host,
                .features = "",
                .cores = actual_cores,
                .threads = actual_threads,
            },
            .network = .{},
            .graphics = .{
                .display = .sdl,
                .gpu = .vga,
                .has_vga_emulation = true,
                .has_graphics_acceleration = false,
            },
            .audio = .{
                .host_device = .none,
                .sound = .ac97,
                .has_input = false,
                .has_output = true,
            },
            .peripherals = .{
                .keyboard = .usb,
                .mouse = .usb,
                .has_mouse_absolute_pointing = true,
            },
            .drive0 = .{
                .is_cdrom = false,
                .bus = .sata,
                .format = .raw,
                .path = "disk.img",
            },
            .drive1 = boot_drive,
            .drive2 = .{
                .is_cdrom = false,
                .bus = .ide,
                .format = .raw,
                .path = "",
            },
            .drive3 = .{
                .is_cdrom = false,
                .bus = .ide,
                .format = .raw,
                .path = "",
            },
            .drive4 = .{
                .is_cdrom = false,
                .bus = .ide,
                .format = .raw,
                .path = "",
            },
        };

        try main.virtual_machines.append(vm);

        var file = try std.fs.cwd().createFile("config.ini", .{});
        defer file.close();

        try ini.writeStruct(vm, file.writer());

        var disk_size = try std.fmt.allocPrint(main.gpa, "{d}G", .{actual_disk});
        defer main.gpa.free(disk_size);

        const qemu_img_arguments = [_][]const u8{
            "qemu-img",
            "create",
            "-q",
            "-f",
            "raw",
            "disk.img",
            disk_size,
        };

        _ = std.ChildProcess.exec(.{ .argv = &qemu_img_arguments, .allocator = main.gpa }) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Unable to create a child process for the QEMU image creation." });
            return;
        };

        try main.virtual_machines_directory.setAsCwd();

        show = false;
    }
}

fn add_text_option(text: []const u8, buffer: []u8) !void {
    try gui.label(@src(), "{s}:", .{text}, .{ .id_extra = option_index });
    option_index += 1;

    try gui.textEntry(@src(), .{ .text = buffer }, .{ .expand = .horizontal, .id_extra = option_index });
    option_index += 1;
}

fn add_bool_option(text: []const u8, value: *bool) !void {
    try gui.checkbox(@src(), value, text, .{ .id_extra = option_index });
    option_index += 1;
}
