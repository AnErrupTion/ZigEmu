const std = @import("std");
const builtin = @import("builtin");
const structs = @import("structs.zig");
const main = @import("main.zig");
const utils = @import("utils.zig");
const permanent_buffers = @import("permanent_buffers.zig");
const path = @import("path.zig");

pub fn getArguments(vm: structs.VirtualMachine, drives: []*structs.Drive) !std.ArrayList([]const u8) {
    var list = std.ArrayList([]const u8).init(main.gpa);

    const architecture_str = switch (vm.basic.architecture) {
        .amd64 => "x86_64",
    };
    const chipset_str = switch (vm.basic.chipset) {
        .i440fx => "pc",
        .q35 => "q35",
    };
    const cpu_str = switch (vm.processor.cpu) {
        .i486_v1 => "486-v1",
        .i486 => "486",
        .athlon_v1 => "athlon-v1",
        .athlon => "athlon",
        .base => "base",
        .Broadwell_IBRS => "Broadwell-IBRS",
        .Broadwell_noTSX_IBRS => "Broadwell-noTSX-IBRS",
        .Broadwell_noTSX => "Broadwell-noTSX",
        .Broadwell_v1 => "Broadwell-v1",
        .Broadwell_v2 => "Broadwell-v2",
        .Broadwell_v3 => "Broadwell-v3",
        .Broadwell_v4 => "Broadwell-v4",
        .Broadwell => "Broadwell",
        .Cascadelake_Server_noTSX => "Cascadelake-Server-noTSX",
        .Cascadelake_Server_v1 => "Cascadelake-Server-v1",
        .Cascadelake_Server_v2 => "Cascadelake-Server-v2",
        .Cascadelake_Server_v3 => "Cascadelake-Server-v3",
        .Cascadelake_Server_v4 => "Cascadelake-Server-v4",
        .Cascadelake_Server_v5 => "Cascadelake-Server-v5",
        .Cascadelake_Server => "Cascadelake-Server",
        .Conroe_v1 => "Conroe-v1",
        .Conroe => "Conroe",
        .Cooperlake_v1 => "Cooperlake-v1",
        .Cooperlake_v2 => "Cooperlake-v2",
        .Cooperlake => "Cooperlake",
        .core2duo_v1 => "core2duo-v1",
        .core2duo => "core2duo",
        .coreduo_v1 => "coreduo-v1",
        .coreduo => "coreduo",
        .Denverton_v1 => "Denverton-v1",
        .Denverton_v2 => "Denverton-v2",
        .Denverton_v3 => "Denverton-v3",
        .Denverton => "Denverton",
        .Dhyana_v1 => "Dhyana-v1",
        .Dhyana_v2 => "Dhyana-v2",
        .Dhyana => "Dhyana",
        .EPYC_IBPB => "EPYC-IBPB",
        .EPYC_Milan_v1 => "EPYC-Milan-v1",
        .EPYC_Milan => "EPYC-Milan",
        .EPYC_Rome_v1 => "EPYC-Rome-v1",
        .EPYC_Rome_v2 => "EPYC-Rome-v2",
        .EPYC_Rome => "EPYC-Rome",
        .EPYC_v1 => "EPYC-v1",
        .EPYC_v2 => "EPYC-v2",
        .EPYC_v3 => "EPYC-v3",
        .EPYC => "EPYC",
        .Haswell_IBRS => "Haswell-IBRS",
        .Haswell_noTSX_IBRS => "Haswell-noTSX-IBRS",
        .Haswell_noTSX => "Haswell-noTSX",
        .Haswell_v1 => "Haswell-v1",
        .Haswell_v2 => "Haswell-v2",
        .Haswell_v3 => "Haswell-v3",
        .Haswell_v4 => "Haswell-v4",
        .Haswell => "Haswell",
        .host => "host",
        .Icelake_Server_noTSX => "Icelake-Server-noTSX",
        .Icelake_Server_v1 => "Icelake-Server-v1",
        .Icelake_Server_v2 => "Icelake-Server-v2",
        .Icelake_Server_v3 => "Icelake-Server-v3",
        .Icelake_Server_v4 => "Icelake-Server-v4",
        .Icelake_Server_v5 => "Icelake-Server-v5",
        .Icelake_Server_v6 => "Icelake-Server-v6",
        .Icelake_Server => "Icelake-Server",
        .IvyBridge_IBRS => "IvyBridge-IBRS",
        .IvyBridge_v1 => "IvyBridge-v1",
        .IvyBridge_v2 => "IvyBridge-v2",
        .IvyBridge => "IvyBridge",
        .KnightsMill_v1 => "KnightsMill-v1",
        .KnightsMill => "KnightsMill",
        .kvm32_v1 => "kvm32-v1",
        .kvm32 => "kvm32",
        .kvm64_v1 => "kvm64-v1",
        .kvm64 => "kvm64",
        .max => "max",
        .n270_v1 => "n270-v1",
        .n270 => "n270",
        .Nehalem_IBRS => "Nehalem-IBRS",
        .Nehalem_v1 => "Nehalem-v1",
        .Nehalem_v2 => "Nehalem-v2",
        .Nehalem => "Nehalem",
        .Opteron_G1_v1 => "Opteron_G1-v1",
        .Opteron_G1 => "Opteron_G1",
        .Opteron_G2_v1 => "Opteron_G2-v1",
        .Opteron_G2 => "Opteron_G2",
        .Opteron_G3_v1 => "Opteron_G3-v1",
        .Opteron_G3 => "Opteron_G3",
        .Opteron_G4_v1 => "Opteron_G4-v1",
        .Opteron_G4 => "Opteron_G4",
        .Opteron_G5_v1 => "Opteron_G5-v1",
        .Opteron_G5 => "Opteron_G5",
        .Penryn_v1 => "Penryn-v1",
        .Penryn => "Penryn",
        .pentium_v1 => "pentium-v1",
        .pentium => "pentium",
        .pentium2_v1 => "pentium2-v1",
        .pentium2 => "pentium2",
        .pentium3_v1 => "pentium3-v1",
        .pentium3 => "pentium3",
        .phenom_v1 => "phenom-v1",
        .phenom => "phenom",
        .qemu32_v1 => "qemu32-v1",
        .qemu32 => "qemu32",
        .qemu64_v1 => "qemu64-v1",
        .qemu64 => "qemu64",
        .SandyBridge_IBRS => "SandyBridge-IBRS",
        .SandyBridge_v1 => "SandyBridge-v1",
        .SandyBridge_v2 => "SandyBridge-v2",
        .SandyBridge => "SandyBridge",
        .Skylake_Client_IBRS => "Skylake-Client-IBRS",
        .Skylake_Client_noTSX_IBRS => "Skylake-Client-noTSX-IBRS",
        .Skylake_Client_v1 => "Skylake-Client-v1",
        .Skylake_Client_v2 => "Skylake-Client-v2",
        .Skylake_Client_v3 => "Skylake-Client-v3",
        .Skylake_Client_v4 => "Skylake-Client-v4",
        .Skylake_Client => "Skylake-Client",
        .Skylake_Server_IBRS => "Skylake-Server-IBRS",
        .Skylake_Server_noTSX_IBRS => "Skylake-Server-noTSX-IBRS",
        .Skylake_Server_v1 => "Skylake-Server-v1",
        .Skylake_Server_v2 => "Skylake-Server-v2",
        .Skylake_Server_v3 => "Skylake-Server-v3",
        .Skylake_Server_v4 => "Skylake-Server-v4",
        .Skylake_Server_v5 => "Skylake-Server-v5",
        .Skylake_Server => "Skylake-Server",
        .Snowridge_v1 => "Snowridge-v1",
        .Snowridge_v2 => "Snowridge-v2",
        .Snowridge_v3 => "Snowridge-v3",
        .Snowridge_v4 => "Snowridge-v4",
        .Snowridge => "Snowridge",
        .Westmere_IBRS => "Westmere-IBRS",
        .Westmere_v1 => "Westmere-v1",
        .Westmere_v2 => "Westmere-v2",
        .Westmere => "Westmere",
    };
    const display_str = switch (vm.graphics.display) {
        .none => "none",
        .auto => switch (builtin.os.tag) {
            .macos => "cocoa",
            else => "sdl",
        },
        .sdl => "sdl",
        .gtk => "gtk",
        .spice => "spice-app",
        .cocoa => "cocoa",
        .dbus => "dbus",
    };

    const qemu_path_separator = if (vm.qemu.override_qemu_path and !std.mem.endsWith(u8, vm.qemu.qemu_path, std.fs.path.sep_str)) std.fs.path.sep_str else "";
    const pci_bus_type = if (vm.basic.chipset == .q35) "pcie" else "pci";

    var qemu_path = try std.fmt.allocPrint(main.gpa, "{s}{s}qemu-system-{s}", .{ vm.qemu.qemu_path, qemu_path_separator, architecture_str });
    var name = try std.fmt.allocPrint(main.gpa, "{s},process={s}", .{ vm.basic.name, vm.basic.name });
    var cpu = if (vm.processor.features.len > 0) try std.fmt.allocPrint(main.gpa, "{s},{s}", .{ cpu_str, vm.processor.features }) else cpu_str;
    var ram = try std.fmt.allocPrint(main.gpa, "{d}M", .{vm.memory.ram});
    var smp = try std.fmt.allocPrint(main.gpa, "cores={d},threads={d}", .{ vm.processor.cores, vm.processor.threads });
    var display = try std.fmt.allocPrint(main.gpa, "{s},gl={s}", .{ display_str, if (vm.graphics.has_graphics_acceleration) "on" else "off" });
    var ahci_bus: u64 = 0;

    try permanent_buffers.arrays.append(qemu_path);
    try permanent_buffers.arrays.append(name);
    if (vm.processor.features.len > 0) {
        try permanent_buffers.arrays.append(cpu);
    }
    try permanent_buffers.arrays.append(ram);
    try permanent_buffers.arrays.append(smp);
    try permanent_buffers.arrays.append(display);

    try list.append(qemu_path);
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

    switch (vm.firmware.type) {
        .bios => {
            if (vm.basic.architecture != .amd64) unreachable;

            const paths = if (vm.qemu.override_qemu_path) &[_][]const u8{vm.qemu.qemu_path} else switch (builtin.os.tag) {
                .linux => &[_][]const u8{"/usr/share/qemu"},
                else => unreachable, // TODO: Firmware path auto-detection for Windows and macOS
            };

            const names = &[_][]const u8{"bios.bin"};

            var firmware = try path.lookup(main.gpa, paths, names);

            try permanent_buffers.arrays.append(firmware);

            try list.append("-bios");
            try list.append(firmware);
        },
        .uefi => {
            const paths = if (vm.qemu.override_qemu_path) &[_][]const u8{vm.qemu.qemu_path} else switch (builtin.os.tag) {
                .linux => switch (vm.basic.architecture) {
                    .amd64 => &[_][]const u8{ "/usr/share/qemu", "/usr/share/OVMF/x64" },
                },
                else => unreachable, // TODO: Firmware path auto-detection for Windows and macOS
            };

            const codes = switch (vm.basic.architecture) {
                .amd64 => &[_][]const u8{ "edk2-x86_64-code.fd", "OVMF_CODE.fd" },
            };

            const variables = switch (vm.basic.architecture) {
                .amd64 => &[_][]const u8{ "edk2-i386-vars.fd", "OVMF_VARS.fd" },
            };

            const code = try path.lookup(main.gpa, paths, codes);
            const vars = try path.lookup(main.gpa, paths, variables);

            try permanent_buffers.arrays.append(code);
            try permanent_buffers.arrays.append(vars);

            var code_drive = try std.fmt.allocPrint(main.gpa, "if=pflash,readonly=on,file={s}", .{code});
            var vars_drive = try std.fmt.allocPrint(main.gpa, "if=pflash,readonly=on,file={s}", .{vars});

            try permanent_buffers.arrays.append(code_drive);
            try permanent_buffers.arrays.append(vars_drive);

            try list.append("-drive");
            try list.append(code_drive);

            try list.append("-drive");
            try list.append(vars_drive);
        },
        .custom_pc => {
            try list.append("-bios");
            try list.append(vm.firmware.firmware_path);
        },
        .custom_pflash => {
            var firmware = try std.fmt.allocPrint(main.gpa, "if=pflash,readonly=on,file={s}", .{vm.firmware.firmware_path});

            try permanent_buffers.arrays.append(firmware);

            try list.append("-drive");
            try list.append(firmware);
        },
    }

    if (vm.network.type != .none) {
        try list.append("-netdev");

        switch (vm.network.type) {
            .nat => try list.append("user,id=nettype"),
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
            .usb => try list.append("usb-net,bus=usb.0,netdev=nettype"),
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

    try list.append("-audiodev");

    switch (vm.audio.host_device) {
        .none => try list.append("none,id=hostdev"),
        .auto => switch (builtin.os.tag) {
            .windows => try list.append("dsound,id=hostdev"),
            .macos => try list.append("coreaudio,id=hostdev"),
            .linux => try list.append("alsa,id=hostdev"),
            .kfreebsd, .freebsd, .openbsd, .netbsd, .dragonfly => try list.append("sndio,id=hostdev"),
            else => try list.append("sdl,id=hostdev"),
        },
        .sdl => try list.append("sdl,id=hostdev"),
        .alsa => try list.append("alsa,id=hostdev"),
        .oss => try list.append("oss,id=hostdev"),
        .pulseaudio => try list.append("pa,id=hostdev"),
        .sndio => try list.append("sndio,id=hostdev"),
        .coreaudio => try list.append("coreaudio,id=hostdev"),
        .directsound => try list.append("dsound,id=hostdev"),
        .wav => try list.append("wav,id=hostdev"),
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
                if (drive.is_removable) unreachable;

                var bus = if (drive.is_cdrom) try std.fmt.allocPrint(main.gpa, "ide-cd,drive=drive{d}", .{i}) else try std.fmt.allocPrint(main.gpa, "ide-hd,drive=drive{d}", .{i});

                try permanent_buffers.arrays.append(bus);

                try list.append("-device");
                try list.append(bus);
            },
            .sata => {
                if (drive.is_removable) unreachable;

                var bus = if (drive.is_cdrom) try std.fmt.allocPrint(main.gpa, "ide-cd,drive=drive{d},bus=ahci.{d}", .{ i, ahci_bus }) else try std.fmt.allocPrint(main.gpa, "ide-hd,drive=drive{d},bus=ahci.{d}", .{ i, ahci_bus });

                ahci_bus += 1;

                try permanent_buffers.arrays.append(bus);

                try list.append("-device");
                try list.append(bus);
            },
            .usb => {
                if (vm.basic.usb_type == .none) unreachable;
                if (drive.is_cdrom) unreachable;

                var bus = try std.fmt.allocPrint(main.gpa, "usb-storage,drive=drive{d},bus=usb.0,removable={d}", .{ i, if (drive.is_removable) "true" else "false" });

                try permanent_buffers.arrays.append(bus);

                try list.append("-device");
                try list.append(bus);
            },
            .virtio => {
                if (drive.is_cdrom) unreachable;
                if (drive.is_removable) unreachable;

                var bus = try std.fmt.allocPrint(main.gpa, "virtio-blk-pci,drive=drive{d},bus={s}.0", .{ i, pci_bus_type });

                try permanent_buffers.arrays.append(bus);

                try list.append("-device");
                try list.append(bus);
            },
        }
    }

    return list;
}
