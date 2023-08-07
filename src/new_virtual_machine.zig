const std = @import("std");
const gui = @import("gui");
const ini = @import("ini");
const structs = @import("structs.zig");
const main = @import("main.zig");
const permanent_buffers = @import("permanent_buffers.zig");
const utils = @import("utils.zig");

pub var show = false;

var option_index: u64 = undefined;

var name = std.mem.zeroes([128]u8);
var profile: u64 = undefined;
var ram = std.mem.zeroes([32]u8);
var cores = std.mem.zeroes([16]u8);
var threads = std.mem.zeroes([16]u8);
var disk = std.mem.zeroes([8]u8);
var has_boot_image: bool = undefined;
var boot_image = std.mem.zeroes([1024]u8);

pub fn init() void {
    @memset(&name, 0);
    @memset(&ram, 0);
    @memset(&cores, 0);
    @memset(&threads, 0);
    @memset(&disk, 0);
    @memset(&boot_image, 0);

    profile = 0;
    has_boot_image = false;
}

pub fn guiFrame() !void {
    if (!show) return;

    var window = try gui.floatingWindow(@src(), .{ .open_flag = &show }, .{ .min_size_content = .{ .w = 400, .h = 400 } });
    defer window.deinit();

    try gui.windowHeader("Create a new virtual machine", "", &show);

    var scroll = try gui.scrollArea(@src(), .{}, .{ .expand = .both, .color_style = .window });
    defer scroll.deinit();

    option_index = 0;

    try utils.addTextOption("Name", &name, &option_index);
    try utils.addComboOption("Profile", &.{ "Default", "Windows 10 and above", "Windows 8.1", "Windows 7", "Windows XP", "Linux" }, &profile, &option_index);
    try utils.addTextOption("RAM (in MiB)", &ram, &option_index);
    try utils.addTextOption("Cores", &cores, &option_index);
    try utils.addTextOption("Threads", &threads, &option_index);
    try utils.addTextOption("Disk size (in GiB)", &disk, &option_index);
    try utils.addBoolOption("Add a boot image", &has_boot_image, &option_index);
    if (has_boot_image) try utils.addTextOption("Boot image", &boot_image, &option_index);

    if (try gui.button(@src(), "Create", .{ .expand = .horizontal, .color_style = .accent })) {
        var actual_name = utils.sanitizeOutputText(&name, true) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid name!" });
            return;
        };
        var actual_ram = utils.sanitizeOutputNumber(&ram) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid amount of RAM!" });
            return;
        };
        var actual_cores = utils.sanitizeOutputNumber(&cores) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid amount of cores!" });
            return;
        };
        var actual_threads = utils.sanitizeOutputNumber(&threads) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid amount of threads!" });
            return;
        };
        var actual_disk = utils.sanitizeOutputNumber(&disk) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid disk size!" });
            return;
        };
        var actual_boot_image = utils.sanitizeOutputText(&boot_image, false) catch {
            try gui.dialog(@src(), .{ .title = "Error", .message = "Please enter a valid boot image path!" });
            return;
        };

        try permanent_buffers.lists.append(actual_name);
        try permanent_buffers.lists.append(actual_boot_image);

        const name_str = actual_name.items;
        const boot_image_str = actual_boot_image.items;
        const vm = switch (profile) {
            0 => construct_default_vm(name_str, actual_ram, actual_cores, actual_threads, boot_image_str),
            1 => construct_win10_vm(name_str, actual_ram, actual_cores, actual_threads, boot_image_str),
            2 => construct_win81_vm(name_str, actual_ram, actual_cores, actual_threads, boot_image_str),
            3 => construct_win7_vm(name_str, actual_ram, actual_cores, actual_threads, boot_image_str),
            4 => construct_winxp_vm(name_str, actual_ram, actual_cores, actual_threads, boot_image_str),
            5 => construct_linux_vm(name_str, actual_ram, actual_cores, actual_threads, boot_image_str),
            else => unreachable,
        };

        // Create VM directory, open it, and set it as current working directory
        {
            try std.fs.cwd().makeDir(name_str);

            var vm_directory = try std.fs.cwd().openDir(name_str, .{});
            defer vm_directory.close();

            try vm_directory.setAsCwd();
        }

        try main.virtual_machines.append(vm);

        // Save config to disk
        {
            var file = try std.fs.cwd().createFile("config.ini", .{});
            defer file.close();

            try ini.writeStruct(vm, file.writer());
        }

        // Create VM disk
        {
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
        }

        try main.virtual_machines_directory.setAsCwd();

        show = false;
    }
}

fn construct_default_vm(name_str: []const u8, ram_num: u64, cores_num: u64, threads_num: u64, boot_image_str: []const u8) structs.VirtualMachine {
    return .{
        .basic = .{
            .name = name_str,
            .architecture = .amd64,
            .chipset = .q35,
            .has_acceleration = true,
            .usb_type = .ehci,
            .has_ahci = true,
        },
        .memory = .{
            .ram = ram_num,
        },
        .processor = .{
            .cpu = .host,
            .features = "",
            .cores = cores_num,
            .threads = threads_num,
        },
        .network = .{
            .type = .nat,
            .interface = .e1000,
        },
        .graphics = .{
            .display = .auto,
            .gpu = .vga,
            .has_vga_emulation = true,
            .has_graphics_acceleration = false,
        },
        .audio = .{
            .host_device = .auto,
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
            .is_removable = false,
            .bus = .sata,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "disk.img",
        },
        .drive1 = if (has_boot_image) .{
            .is_cdrom = true,
            .is_removable = false,
            .bus = .sata,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = boot_image_str,
        } else .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "",
        },
        .drive2 = .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "",
        },
        .drive3 = .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "",
        },
        .drive4 = .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "",
        },
        .qemu = .{
            .override_qemu_path = false,
            .qemu_path = "",
        },
        .firmware = .{
            .type = .bios,
            .firmware_path = "",
        },
    };
}

fn construct_win10_vm(name_str: []const u8, ram_num: u64, cores_num: u64, threads_num: u64, boot_image_str: []const u8) structs.VirtualMachine {
    return .{
        .basic = .{
            .name = name_str,
            .architecture = .amd64,
            .chipset = .q35,
            .has_acceleration = true,
            .usb_type = .xhci,
            .has_ahci = true,
        },
        .memory = .{
            .ram = ram_num,
        },
        .processor = .{
            .cpu = .host,
            .features = "",
            .cores = cores_num,
            .threads = threads_num,
        },
        .network = .{
            .type = .nat,
            .interface = .e1000e,
        },
        .graphics = .{
            .display = .auto,
            .gpu = .qxl,
            .has_vga_emulation = true,
            .has_graphics_acceleration = false,
        },
        .audio = .{
            .host_device = .auto,
            .sound = .ich9,
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
            .is_removable = false,
            .bus = .nvme,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "disk.img",
        },
        .drive1 = if (has_boot_image) .{
            .is_cdrom = true,
            .is_removable = false,
            .bus = .sata,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = boot_image_str,
        } else .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "",
        },
        .drive2 = .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "",
        },
        .drive3 = .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "",
        },
        .drive4 = .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "",
        },
        .qemu = .{
            .override_qemu_path = false,
            .qemu_path = "",
        },
        .firmware = .{
            .type = .uefi,
            .firmware_path = "",
        },
    };
}

fn construct_win81_vm(name_str: []const u8, ram_num: u64, cores_num: u64, threads_num: u64, boot_image_str: []const u8) structs.VirtualMachine {
    return .{
        .basic = .{
            .name = name_str,
            .architecture = .amd64,
            .chipset = .q35,
            .has_acceleration = true,
            .usb_type = .xhci,
            .has_ahci = true,
        },
        .memory = .{
            .ram = ram_num,
        },
        .processor = .{
            .cpu = .host,
            .features = "",
            .cores = cores_num,
            .threads = threads_num,
        },
        .network = .{
            .type = .nat,
            .interface = .e1000e,
        },
        .graphics = .{
            .display = .auto,
            .gpu = .qxl,
            .has_vga_emulation = true,
            .has_graphics_acceleration = false,
        },
        .audio = .{
            .host_device = .auto,
            .sound = .ich9,
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
            .is_removable = false,
            .bus = .sata,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "disk.img",
        },
        .drive1 = if (has_boot_image) .{
            .is_cdrom = true,
            .is_removable = false,
            .bus = .sata,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = boot_image_str,
        } else .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "",
        },
        .drive2 = .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "",
        },
        .drive3 = .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "",
        },
        .drive4 = .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "",
        },
        .qemu = .{
            .override_qemu_path = false,
            .qemu_path = "",
        },
        .firmware = .{
            .type = .uefi,
            .firmware_path = "",
        },
    };
}

fn construct_win7_vm(name_str: []const u8, ram_num: u64, cores_num: u64, threads_num: u64, boot_image_str: []const u8) structs.VirtualMachine {
    return .{
        .basic = .{
            .name = name_str,
            .architecture = .amd64,
            .chipset = .q35,
            .has_acceleration = true,
            .usb_type = .ehci,
            .has_ahci = true,
        },
        .memory = .{
            .ram = ram_num,
        },
        .processor = .{
            .cpu = .host,
            .features = "",
            .cores = cores_num,
            .threads = threads_num,
        },
        .network = .{
            .type = .nat,
            .interface = .e1000e,
        },
        .graphics = .{
            .display = .auto,
            .gpu = .qxl,
            .has_vga_emulation = true,
            .has_graphics_acceleration = false,
        },
        .audio = .{
            .host_device = .auto,
            .sound = .ich9,
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
            .is_removable = false,
            .bus = .sata,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "disk.img",
        },
        .drive1 = if (has_boot_image) .{
            .is_cdrom = true,
            .is_removable = false,
            .bus = .sata,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = boot_image_str,
        } else .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "",
        },
        .drive2 = .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "",
        },
        .drive3 = .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "",
        },
        .drive4 = .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "",
        },
        .qemu = .{
            .override_qemu_path = false,
            .qemu_path = "",
        },
        .firmware = .{
            .type = .bios,
            .firmware_path = "",
        },
    };
}

fn construct_winxp_vm(name_str: []const u8, ram_num: u64, cores_num: u64, threads_num: u64, boot_image_str: []const u8) structs.VirtualMachine {
    return .{
        .basic = .{
            .name = name_str,
            .architecture = .amd64,
            .chipset = .i440fx,
            .has_acceleration = true,
            .usb_type = .ohci,
            .has_ahci = false,
        },
        .memory = .{
            .ram = ram_num,
        },
        .processor = .{
            .cpu = .host,
            .features = "",
            .cores = cores_num,
            .threads = threads_num,
        },
        .network = .{
            .type = .nat,
            .interface = .rtl8139,
        },
        .graphics = .{
            .display = .auto,
            .gpu = .cirrus,
            .has_vga_emulation = true,
            .has_graphics_acceleration = false,
        },
        .audio = .{
            .host_device = .auto,
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
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "disk.img",
        },
        .drive1 = if (has_boot_image) .{
            .is_cdrom = true,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = boot_image_str,
        } else .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "",
        },
        .drive2 = .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "",
        },
        .drive3 = .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "",
        },
        .drive4 = .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "",
        },
        .qemu = .{
            .override_qemu_path = false,
            .qemu_path = "",
        },
        .firmware = .{
            .type = .bios,
            .firmware_path = "",
        },
    };
}

fn construct_linux_vm(name_str: []const u8, ram_num: u64, cores_num: u64, threads_num: u64, boot_image_str: []const u8) structs.VirtualMachine {
    return .{
        .basic = .{
            .name = name_str,
            .architecture = .amd64,
            .chipset = .q35,
            .has_acceleration = true,
            .usb_type = .none,
            .has_ahci = true,
        },
        .memory = .{
            .ram = ram_num,
        },
        .processor = .{
            .cpu = .host,
            .features = "",
            .cores = cores_num,
            .threads = threads_num,
        },
        .network = .{
            .type = .nat,
            .interface = .virtio,
        },
        .graphics = .{
            .display = .auto,
            .gpu = .virtio,
            .has_vga_emulation = true,
            .has_graphics_acceleration = true,
        },
        .audio = .{
            .host_device = .auto,
            .sound = .ich9,
            .has_input = false,
            .has_output = true,
        },
        .peripherals = .{
            .keyboard = .virtio,
            .mouse = .virtio,
            .has_mouse_absolute_pointing = true,
        },
        .drive0 = .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .virtio,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "disk.img",
        },
        .drive1 = if (has_boot_image) .{
            .is_cdrom = true,
            .is_removable = false,
            .bus = .sata,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = boot_image_str,
        } else .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "",
        },
        .drive2 = .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "",
        },
        .drive3 = .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "",
        },
        .drive4 = .{
            .is_cdrom = false,
            .is_removable = false,
            .bus = .ide,
            .format = .raw,
            .cache = .none,
            .is_ssd = false,
            .path = "",
        },
        .qemu = .{
            .override_qemu_path = false,
            .qemu_path = "",
        },
        .firmware = .{
            .type = .uefi,
            .firmware_path = "",
        },
    };
}
