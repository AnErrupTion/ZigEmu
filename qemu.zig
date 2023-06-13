const std = @import("std");
const structs = @import("structs.zig");
const main = @import("main.zig");
const utils = @import("utils.zig");
const permanent_buffers = @import("permanent_buffers.zig");

pub fn get_arguments(vm: structs.VirtualMachine) !std.ArrayList([]const u8) {
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
        try list.append("kvm");
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

    if (!std.mem.eql(u8, vm.drive0.path, "")) {
        var drive = try std.fmt.allocPrint(main.gpa, "if=none,file={s},format={s},id=drive0", .{ vm.drive0.path, utils.drive_format_to_string(vm.drive0.format) });

        try permanent_buffers.arrays.append(drive);

        try list.append("-drive");
        try list.append(drive);

        if (vm.drive0.bus == structs.DriveBus.ide) {
            try list.append("-device");
            if (vm.drive0.is_cdrom) {
                try list.append("ide-cd,drive=drive0");
            } else {
                try list.append("ide-hd,drive=drive0");
            }
        } else if (vm.drive0.bus == structs.DriveBus.sata) {
            try list.append("-device");
            if (vm.drive0.is_cdrom) {
                try list.append("ide-cd,drive=drive0,bus=ahci.0");
            } else {
                try list.append("ide-hd,drive=drive0,bus=ahci.0");
            }
        } else if (vm.drive0.bus == structs.DriveBus.usb) {
            if (vm.basic.usb_type == structs.UsbType.none) unreachable;
            if (vm.drive0.is_cdrom) unreachable;

            try list.append("-device");
            try list.append("usb-storage,drive=drive0,bus=usb.0");
        } else if (vm.drive0.bus == structs.DriveBus.virtio) {
            if (vm.drive0.is_cdrom) unreachable;

            try list.append("-device");
            try list.append("virtio-blk-pci,drive=drive0");
        }
    }

    if (!std.mem.eql(u8, vm.drive1.path, "")) {
        var drive = try std.fmt.allocPrint(main.gpa, "if=none,file={s},format={s},id=drive1", .{ vm.drive1.path, utils.drive_format_to_string(vm.drive1.format) });

        try permanent_buffers.arrays.append(drive);

        try list.append("-drive");
        try list.append(drive);

        if (vm.drive1.bus == structs.DriveBus.ide) {
            try list.append("-device");
            if (vm.drive1.is_cdrom) {
                try list.append("ide-cd,drive=drive1");
            } else {
                try list.append("ide-hd,drive=drive1");
            }
        } else if (vm.drive1.bus == structs.DriveBus.sata) {
            try list.append("-device");
            if (vm.drive1.is_cdrom) {
                try list.append("ide-cd,drive=drive1,bus=ahci.0");
            } else {
                try list.append("ide-hd,drive=drive1,bus=ahci.0");
            }
        } else if (vm.drive1.bus == structs.DriveBus.usb) {
            if (vm.basic.usb_type == structs.UsbType.none) unreachable;
            if (vm.drive1.is_cdrom) unreachable;

            try list.append("-device");
            try list.append("usb-storage,drive=drive1,bus=usb.0");
        } else if (vm.drive1.bus == structs.DriveBus.virtio) {
            if (vm.drive1.is_cdrom) unreachable;

            try list.append("-device");
            try list.append("virtio-blk-pci,drive=drive1");
        }
    }

    // TODO: Other disks (we should just find another way...)

    return list;
}
