const std = @import("std");
const builtin = @import("builtin");
const structs = @import("structs.zig");
const main = @import("main.zig");
const utils = @import("utils.zig");
const permanent_buffers = @import("permanent_buffers.zig");

pub fn get_arguments(vm: structs.VirtualMachine, drives: []structs.Drive) !std.ArrayList([]const u8) {
    var list = std.ArrayList([]const u8).init(main.gpa);

    var qemu_name = try std.fmt.allocPrint(main.gpa, "qemu-system-{s}", .{utils.architecture_to_string(vm.basic.architecture)});
    var name = try std.fmt.allocPrint(main.gpa, "{s},process={s}", .{ vm.basic.name, vm.basic.name });
    var cpu = if (vm.processor.features.len > 0) try std.fmt.allocPrint(main.gpa, "{s},{s}", .{ utils.cpu_to_string(vm.processor.cpu), vm.processor.features }) else utils.cpu_to_string(vm.processor.cpu);
    var ram = try std.fmt.allocPrint(main.gpa, "{d}M", .{vm.memory.ram});
    var smp = try std.fmt.allocPrint(main.gpa, "cores={d},threads={d}", .{ vm.processor.cores, vm.processor.threads });

    try permanent_buffers.arrays.append(qemu_name);
    try permanent_buffers.arrays.append(name);
    if (vm.processor.features.len > 0) {
        try permanent_buffers.arrays.append(cpu);
    }
    try permanent_buffers.arrays.append(ram);
    try permanent_buffers.arrays.append(smp);

    try list.append(qemu_name);
    try list.append("-nodefaults");

    try list.append("-accel");
    if (vm.basic.has_acceleration) {
        if (builtin.os.tag == .windows) {
            try list.append("whpx");
        } else if (builtin.os.tag == .macos) {
            try list.append("hvf");
        } else {
            try list.append("kvm");
        }
    } else {
        try list.append("tcg");
    }

    try list.append("-machine");
    try list.append(utils.chipset_to_string(vm.basic.chipset));

    try list.append("-name");
    try list.append(name);

    try list.append("-cpu");
    try list.append(cpu);

    try list.append("-m");
    try list.append(ram);

    try list.append("-smp");
    try list.append(smp);

    try list.append("-display");
    try list.append(utils.display_to_string(vm.graphics.display));

    if (vm.basic.usb_type != structs.UsbType.none) {
        try list.append("-device");

        if (vm.basic.usb_type == structs.UsbType.ohci) {
            try list.append("pci-ohci,id=usb");
        } else if (vm.basic.usb_type == structs.UsbType.uhci) {
            try list.append("piix3-usb-uhci,id=usb");
        } else if (vm.basic.usb_type == structs.UsbType.ehci) {
            try list.append("usb-ehci,id=usb");
        } else if (vm.basic.usb_type == structs.UsbType.xhci) {
            try list.append("qemu-xhci,id=usb");
        }
    }

    if (vm.basic.has_ahci) {
        try list.append("-device");
        try list.append("ahci,id=ahci");
    }

    if (vm.graphics.gpu != structs.Gpu.none) {
        try list.append("-device");

        if (vm.graphics.gpu == structs.Gpu.qxl) {
            if (vm.graphics.has_graphics_acceleration) unreachable;

            if (vm.graphics.has_vga_emulation) {
                try list.append("qxl-vga");
            } else {
                try list.append("qxl");
            }
        } else if (vm.graphics.gpu == structs.Gpu.vga) {
            if (vm.graphics.has_graphics_acceleration) unreachable;
            if (!vm.graphics.has_vga_emulation) unreachable;

            try list.append("VGA");
        } else if (vm.graphics.gpu == structs.Gpu.virtio) {
            if (vm.graphics.has_vga_emulation) {
                if (vm.graphics.has_graphics_acceleration) {
                    try list.append("virtio-vga-gl");
                } else {
                    try list.append("virtio-vga");
                }
            } else {
                if (vm.graphics.has_graphics_acceleration) {
                    try list.append("virtio-gpu-gl");
                } else {
                    try list.append("virtio-gpu");
                }
            }
        }
    }

    if (vm.peripherals.keyboard != structs.Keyboard.none) {
        try list.append("-device");

        if (vm.peripherals.keyboard == structs.Keyboard.usb) {
            if (vm.basic.usb_type == structs.UsbType.none) unreachable;

            try list.append("usb-kbd,bus=usb.0");
        } else if (vm.peripherals.keyboard == structs.Keyboard.virtio) {
            try list.append("virtio-keyboard-pci");
        }
    }

    if (vm.peripherals.mouse != structs.Mouse.none) {
        try list.append("-device");

        if (vm.peripherals.mouse == structs.Mouse.usb) {
            if (vm.peripherals.has_mouse_absolute_pointing) {
                if (vm.basic.usb_type == structs.UsbType.none) unreachable;

                try list.append("usb-tablet,bus=usb.0");
            } else {
                try list.append("usb-mouse,bus=usb.0");
            }
        } else if (vm.peripherals.mouse == structs.Mouse.virtio) {
            if (vm.peripherals.has_mouse_absolute_pointing) {
                try list.append("virtio-tablet-pci");
            } else {
                try list.append("virtio-mouse-pci");
            }
        }
    }

    for (drives, 0..) |drive, i| {
        if (std.mem.eql(u8, drive.path, "")) {
            continue;
        }

        var disk = try std.fmt.allocPrint(main.gpa, "if=none,file={s},format={s},id=drive{d}", .{ drive.path, utils.drive_format_to_string(drive.format), i });

        try permanent_buffers.arrays.append(disk);

        try list.append("-drive");
        try list.append(disk);

        if (drive.bus == structs.DriveBus.ide) {
            var bus = if (drive.is_cdrom) try std.fmt.allocPrint(main.gpa, "ide-cd,drive=drive{d}", .{i}) else try std.fmt.allocPrint(main.gpa, "ide-hd,drive=drive{d}", .{i});

            try permanent_buffers.arrays.append(bus);

            try list.append("-device");
            try list.append(bus);
        } else if (drive.bus == structs.DriveBus.sata) {
            var bus = if (drive.is_cdrom) try std.fmt.allocPrint(main.gpa, "ide-cd,drive=drive{d},bus=ahci.0", .{i}) else try std.fmt.allocPrint(main.gpa, "ide-hd,drive=drive{d},bus=ahci.0", .{i});

            try permanent_buffers.arrays.append(bus);

            try list.append("-device");
            try list.append(bus);
        } else if (drive.bus == structs.DriveBus.usb) {
            if (vm.basic.usb_type == structs.UsbType.none) unreachable;
            if (drive.is_cdrom) unreachable;

            var bus = try std.fmt.allocPrint(main.gpa, "usb-storage,drive=drive{d},bus=usb.0", .{i});

            try permanent_buffers.arrays.append(bus);

            try list.append("-device");
            try list.append(bus);
        } else if (drive.bus == structs.DriveBus.virtio) {
            if (drive.is_cdrom) unreachable;

            var bus = try std.fmt.allocPrint(main.gpa, "virtio-blk-pci,drive=drive{d}", .{i});

            try permanent_buffers.arrays.append(bus);

            try list.append("-device");
            try list.append(bus);
        }
    }

    return list;
}
