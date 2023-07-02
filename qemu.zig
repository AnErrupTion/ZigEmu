const std = @import("std");
const builtin = @import("builtin");
const structs = @import("structs.zig");
const main = @import("main.zig");
const utils = @import("utils.zig");
const permanent_buffers = @import("permanent_buffers.zig");

pub fn get_arguments(vm: structs.VirtualMachine, drives: []*structs.Drive) !std.ArrayList([]const u8) {
    var list = std.ArrayList([]const u8).init(main.gpa);

    const architecture_str = switch (vm.basic.architecture) {
        .amd64 => "x86_64",
    };
    const chipset_str = switch (vm.basic.chipset) {
        .i440fx => "pc",
        .q35 => "q35",
    };
    const cpu_str = switch (vm.processor.cpu) {
        .host => "host",
        .max => "max",
    };
    const display_str = switch (vm.graphics.display) {
        .none => "none",
        .sdl => "sdl",
        .gtk => "gtk",
        .spice => "spice-app",
        .cocoa => "cocoa",
        .dbus => "dbus",
    };

    var qemu_name = try std.fmt.allocPrint(main.gpa, "qemu-system-{s}", .{architecture_str});
    var name = try std.fmt.allocPrint(main.gpa, "{s},process={s}", .{ vm.basic.name, vm.basic.name });
    var cpu = if (vm.processor.features.len > 0) try std.fmt.allocPrint(main.gpa, "{s},{s}", .{ cpu_str, vm.processor.features }) else cpu_str;
    var ram = try std.fmt.allocPrint(main.gpa, "{d}M", .{vm.memory.ram});
    var smp = try std.fmt.allocPrint(main.gpa, "cores={d},threads={d}", .{ vm.processor.cores, vm.processor.threads });
    var display = try std.fmt.allocPrint(main.gpa, "{s},gl={s}", .{ display_str, if (vm.graphics.has_graphics_acceleration) "on" else "off" });
    var pci_bus_type = if (vm.basic.chipset == .q35) "pcie" else "pci";
    var ahci_bus: u64 = 0;

    try permanent_buffers.arrays.append(qemu_name);
    try permanent_buffers.arrays.append(name);
    if (vm.processor.features.len > 0) {
        try permanent_buffers.arrays.append(cpu);
    }
    try permanent_buffers.arrays.append(ram);
    try permanent_buffers.arrays.append(smp);
    try permanent_buffers.arrays.append(display);

    try list.append(qemu_name);
    try list.append("-nodefaults");

    try list.append("-accel");
    if (vm.basic.has_acceleration) {
        try list.append(switch (builtin.os.tag) {
            .windows => "whpx",
            .macos => "hvf",
            else => "kvm",
        });
    } else {
        try list.append("tcg");
    }

    try list.append("-machine");
    try list.append(chipset_str);

    try list.append("-name");
    try list.append(name);

    try list.append("-cpu");
    try list.append(cpu);

    try list.append("-m");
    try list.append(ram);

    try list.append("-smp");
    try list.append(smp);

    try list.append("-display");
    try list.append(display);

    if (vm.basic.usb_type != .none) {
        const usb_type_str = switch (vm.basic.usb_type) {
            .ohci => "pci-ohci",
            .uhci => "piix3-usb-uhci",
            .ehci => "usb-ehci",
            .xhci => "qemu-xhci",
            else => unreachable,
        };
        var usb = try std.fmt.allocPrint(main.gpa, "{s},bus={s}.0,id=usb", .{ usb_type_str, pci_bus_type });

        try permanent_buffers.arrays.append(usb);

        try list.append("-device");
        try list.append(usb);
    }

    if (vm.basic.has_ahci) {
        var ahci = try std.fmt.allocPrint(main.gpa, "ahci,bus={s}.0,id=ahci", .{pci_bus_type});

        try permanent_buffers.arrays.append(ahci);

        try list.append("-device");
        try list.append(ahci);
    }

    if (vm.network.type != .none) {
        try list.append("-netdev");

        switch (vm.network.type) {
            .nat => {
                try list.append("user,id=nettype");
            },
            else => unreachable,
        }

        try list.append("-device");

        switch (vm.network.interface) {
            .rtl8139 => {
                var network = try std.fmt.allocPrint(main.gpa, "rtl8139,bus={s}.0,netdev=nettype", .{pci_bus_type});

                try permanent_buffers.arrays.append(network);
                try list.append(network);
            },
            .e1000 => {
                var network = try std.fmt.allocPrint(main.gpa, "e1000,bus={s}.0,netdev=nettype", .{pci_bus_type});

                try permanent_buffers.arrays.append(network);
                try list.append(network);
            },
            .e1000e => {
                var network = try std.fmt.allocPrint(main.gpa, "e1000e,bus={s}.0,netdev=nettype", .{pci_bus_type});

                try permanent_buffers.arrays.append(network);
                try list.append(network);
            },
            .vmware => {
                var network = try std.fmt.allocPrint(main.gpa, "vmxnet3,bus={s}.0,netdev=nettype", .{pci_bus_type});

                try permanent_buffers.arrays.append(network);
                try list.append(network);
            },
            .usb => {
                try list.append("usb-net,bus=usb.0,netdev=nettype");
            },
            .virtio => {
                var network = try std.fmt.allocPrint(main.gpa, "virtio-net-pci,bus={s}.0,netdev=nettype", .{pci_bus_type});

                try permanent_buffers.arrays.append(network);
                try list.append(network);
            },
        }
    }

    if (vm.graphics.gpu != .none) {
        try list.append("-device");

        switch (vm.graphics.gpu) {
            .qxl => {
                if (vm.graphics.has_graphics_acceleration) unreachable;

                var qxl = try std.fmt.allocPrint(main.gpa, "{s},bus={s}.0", .{ if (vm.graphics.has_vga_emulation) "qxl-vga" else "qxl", pci_bus_type });

                try permanent_buffers.arrays.append(qxl);

                try list.append(qxl);
            },
            .vga => {
                if (vm.graphics.has_graphics_acceleration) unreachable;
                if (!vm.graphics.has_vga_emulation) unreachable;

                var vga = try std.fmt.allocPrint(main.gpa, "VGA,bus={s}.0", .{pci_bus_type});

                try permanent_buffers.arrays.append(vga);

                try list.append(vga);
            },
            .vmware => {
                if (vm.graphics.has_graphics_acceleration) unreachable;
                if (!vm.graphics.has_vga_emulation) unreachable;

                var vmware = try std.fmt.allocPrint(main.gpa, "vmware-svga,bus={s}.0", .{pci_bus_type});

                try permanent_buffers.arrays.append(vmware);

                try list.append(vmware);
            },
            .virtio => {
                var virtio_gpu_type = if (vm.graphics.has_vga_emulation and vm.graphics.has_graphics_acceleration) "vga-gl" else if (vm.graphics.has_vga_emulation and !vm.graphics.has_graphics_acceleration) "vga" else if (!vm.graphics.has_vga_emulation and vm.graphics.has_graphics_acceleration) "gpu-gl" else "gpu";
                var virtio = try std.fmt.allocPrint(main.gpa, "virtio-{s},bus={s}.0", .{ virtio_gpu_type, pci_bus_type });

                try permanent_buffers.arrays.append(virtio);

                try list.append(virtio);
            },
            else => unreachable,
        }
    }

    switch (vm.audio.host_device) {
        .none => {
            try list.append("-audiodev");
            try list.append("none,id=hostdev");
        },
        .sdl => {
            try list.append("-audiodev");
            try list.append("sdl,id=hostdev");
        },
        .alsa => {
            try list.append("-audiodev");
            try list.append("alsa,id=hostdev");
        },
        .oss => {
            try list.append("-audiodev");
            try list.append("oss,id=hostdev");
        },
        .pulseaudio => {
            try list.append("-audiodev");
            try list.append("pa,id=hostdev");
        },
        .sndio => {
            try list.append("-audiodev");
            try list.append("sndio,id=hostdev");
        },
        .coreaudio => {
            try list.append("-audiodev");
            try list.append("coreaudio,id=hostdev");
        },
        .directsound => {
            try list.append("-audiodev");
            try list.append("dsound,id=hostdev");
        },
        .wav => {
            try list.append("-audiodev");
            try list.append("wav,id=hostdev");
        },
    }

    switch (vm.audio.sound) {
        .sb16 => {
            if (vm.audio.has_input) unreachable;
            if (!vm.audio.has_output) unreachable;

            try list.append("-device");
            try list.append("sb16,audiodev=hostdev");
        },
        .ac97 => {
            if (vm.audio.has_input) unreachable;
            if (!vm.audio.has_output) unreachable;

            try list.append("-device");
            try list.append("AC97,audiodev=hostdev");
        },
        .ich6 => {
            var sound = try std.fmt.allocPrint(main.gpa, "intel-hda,bus={s}.0,id=hda", .{pci_bus_type});

            try permanent_buffers.arrays.append(sound);

            try list.append("-device");
            try list.append(sound);

            if (vm.audio.has_input and vm.audio.has_output) {
                try list.append("-device");
                try list.append("hda-duplex,audiodev=hostdev,bus=hda.0");
            } else if (!vm.audio.has_input and vm.audio.has_output) {
                try list.append("-device");
                try list.append("hda-output,audiodev=hostdev,bus=hda.0");
            } else if (vm.audio.has_input and !vm.audio.has_output) {
                try list.append("-device");
                try list.append("hda-input,audiodev=hostdev,bus=hda.0");
            }
        },
        .ich9 => {
            var sound = try std.fmt.allocPrint(main.gpa, "ich9-intel-hda,bus={s}.0,id=hda", .{pci_bus_type});

            try permanent_buffers.arrays.append(sound);

            try list.append("-device");
            try list.append(sound);

            if (vm.audio.has_input and vm.audio.has_output) {
                try list.append("-device");
                try list.append("hda-duplex,audiodev=hostdev,bus=hda.0");
            } else if (!vm.audio.has_input and vm.audio.has_output) {
                try list.append("-device");
                try list.append("hda-output,audiodev=hostdev,bus=hda.0");
            } else if (vm.audio.has_input and !vm.audio.has_output) {
                try list.append("-device");
                try list.append("hda-input,audiodev=hostdev,bus=hda.0");
            }
        },
        .usb => {
            if (vm.audio.has_input) unreachable;
            if (!vm.audio.has_output) unreachable;
            if (vm.basic.usb_type == .none) unreachable;

            try list.append("-device");
            try list.append("usb-audio,audiodev=hostdev,bus=usb.0");
        },
    }

    if (vm.peripherals.keyboard != .none) {
        switch (vm.peripherals.keyboard) {
            .usb => {
                if (vm.basic.usb_type == .none) unreachable;

                try list.append("-device");
                try list.append("usb-kbd,bus=usb.0");
            },
            .virtio => {
                var keyboard = try std.fmt.allocPrint(main.gpa, "virtio-keyboard-pci,bus={s}.0", .{pci_bus_type});

                try permanent_buffers.arrays.append(keyboard);

                try list.append("-device");
                try list.append(keyboard);
            },
            else => unreachable,
        }
    }

    if (vm.peripherals.mouse != .none) {
        var mouse: []u8 = undefined;

        switch (vm.peripherals.mouse) {
            .usb => {
                if (vm.basic.usb_type == .none) unreachable;

                mouse = try std.fmt.allocPrint(main.gpa, "{s},bus=usb.0", .{if (vm.peripherals.has_mouse_absolute_pointing) "usb-tablet" else "usb-mouse"});
            },
            .virtio => {
                mouse = try std.fmt.allocPrint(main.gpa, "{s},bus={s}.0", .{ if (vm.peripherals.has_mouse_absolute_pointing) "virtio-tablet-pci" else "virtio-mouse-pci", pci_bus_type });
            },
            else => unreachable,
        }

        try permanent_buffers.arrays.append(mouse);

        try list.append("-device");
        try list.append(mouse);
    }

    for (drives, 0..) |drive, i| {
        if (drive.path.len == 0) {
            continue;
        }

        const drive_format_str = switch (drive.format) {
            .raw => "raw",
            .qcow2 => "qcow2",
            .vmdk => "vmdk",
            .vdi => "vdi",
            .vhd => "vhd",
        };
        const drive_cache_str = switch (drive.cache) {
            .none => "none",
            .writeback => "writeback",
            .writethrough => "writethrough",
            .directsync => "directsync",
            .unsafe => "unsafe",
        };
        var disk = try std.fmt.allocPrint(main.gpa, "if=none,file={s},format={s},cache={s},discard={s},id=drive{d}", .{ drive.path, drive_format_str, drive_cache_str, if (drive.is_ssd) "unmap" else "ignore", i });

        try permanent_buffers.arrays.append(disk);

        try list.append("-drive");
        try list.append(disk);

        switch (drive.bus) {
            .ide => {
                var bus = if (drive.is_cdrom) try std.fmt.allocPrint(main.gpa, "ide-cd,drive=drive{d}", .{i}) else try std.fmt.allocPrint(main.gpa, "ide-hd,drive=drive{d}", .{i});

                try permanent_buffers.arrays.append(bus);

                try list.append("-device");
                try list.append(bus);
            },
            .sata => {
                var bus = if (drive.is_cdrom) try std.fmt.allocPrint(main.gpa, "ide-cd,drive=drive{d},bus=ahci.{d}", .{ i, ahci_bus }) else try std.fmt.allocPrint(main.gpa, "ide-hd,drive=drive{d},bus=ahci.{d}", .{ i, ahci_bus });

                ahci_bus += 1;

                try permanent_buffers.arrays.append(bus);

                try list.append("-device");
                try list.append(bus);
            },
            .usb => {
                if (vm.basic.usb_type == .none) unreachable;
                if (drive.is_cdrom) unreachable;

                var bus = try std.fmt.allocPrint(main.gpa, "usb-storage,drive=drive{d},bus=usb.0", .{i});

                try permanent_buffers.arrays.append(bus);

                try list.append("-device");
                try list.append(bus);
            },
            .virtio => {
                if (drive.is_cdrom) unreachable;

                var bus = try std.fmt.allocPrint(main.gpa, "virtio-blk-pci,drive=drive{d},bus={s}.0", .{ i, pci_bus_type });

                try permanent_buffers.arrays.append(bus);

                try list.append("-device");
                try list.append(bus);
            },
        }
    }

    return list;
}
