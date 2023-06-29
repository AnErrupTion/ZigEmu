const std = @import("std");
const main = @import("main.zig");
const structs = @import("structs.zig");

pub const SanitizationError = error{ CannotSanitizeInput, OutOfMemory };
pub const ConversionError = error{CannotConvertInput};

pub fn sanitize_output_text(buffer: []u8, is_name: bool) SanitizationError!std.ArrayList(u8) {
    if (is_name and buffer[0] == 0) {
        return SanitizationError.CannotSanitizeInput;
    }

    var sanitized_buffer = std.ArrayList(u8).init(main.gpa);

    for (buffer) |byte| {
        if (byte == 0) {
            break;
        }

        try sanitized_buffer.append(byte);
    }

    return sanitized_buffer;
}

pub fn sanitize_output_number(buffer: []u8) SanitizationError!u64 {
    if (buffer[0] == 0) {
        return SanitizationError.CannotSanitizeInput;
    }

    var sanitized_buffer = std.ArrayList(u8).init(main.gpa);
    defer sanitized_buffer.deinit();

    for (buffer) |byte| {
        if (byte == 0) {
            break;
        }

        try sanitized_buffer.append(byte);
    }

    return std.fmt.parseInt(u64, sanitized_buffer.items, 10) catch return SanitizationError.CannotSanitizeInput;
}

pub fn cpu_to_string(cpu: structs.Cpu) []const u8 {
    return switch (cpu) {
        structs.Cpu.host => "host",
        structs.Cpu.max => "max",
    };
}

pub fn string_to_cpu(str: []const u8) ConversionError!structs.Cpu {
    if (std.mem.eql(u8, str, "host")) {
        return structs.Cpu.host;
    } else if (std.mem.eql(u8, str, "max")) {
        return structs.Cpu.max;
    } else {
        return ConversionError.CannotConvertInput;
    }
}

pub fn architecture_to_string(architecture: structs.Architecture) []const u8 {
    return switch (architecture) {
        structs.Architecture.amd64 => "x86_64",
    };
}

pub fn string_to_architecture(str: []const u8) ConversionError!structs.Architecture {
    if (std.mem.eql(u8, str, "x86_64")) {
        return structs.Architecture.amd64;
    } else {
        return ConversionError.CannotConvertInput;
    }
}

pub fn chipset_to_string(chipset: structs.Chipset) []const u8 {
    return switch (chipset) {
        structs.Chipset.i440fx => "pc",
        structs.Chipset.q35 => "q35",
    };
}

pub fn string_to_chipset(str: []const u8) ConversionError!structs.Chipset {
    if (std.mem.eql(u8, str, "pc")) {
        return structs.Chipset.i440fx;
    } else if (std.mem.eql(u8, str, "q35")) {
        return structs.Chipset.q35;
    } else {
        return ConversionError.CannotConvertInput;
    }
}

pub fn usb_type_to_string(usb_type: structs.UsbType) []const u8 {
    return switch (usb_type) {
        structs.UsbType.none => "none",
        structs.UsbType.ohci => "ohci",
        structs.UsbType.uhci => "uhci",
        structs.UsbType.ehci => "ehci",
        structs.UsbType.xhci => "xhci",
    };
}

pub fn string_to_usb_type(str: []const u8) ConversionError!structs.UsbType {
    if (std.mem.eql(u8, str, "none")) {
        return structs.UsbType.none;
    } else if (std.mem.eql(u8, str, "ohci")) {
        return structs.UsbType.ohci;
    } else if (std.mem.eql(u8, str, "uhci")) {
        return structs.UsbType.uhci;
    } else if (std.mem.eql(u8, str, "ehci")) {
        return structs.UsbType.ehci;
    } else if (std.mem.eql(u8, str, "xhci")) {
        return structs.UsbType.xhci;
    } else {
        return ConversionError.CannotConvertInput;
    }
}

pub fn network_type_to_string(network_type: structs.NetworkType) []const u8 {
    return switch (network_type) {
        structs.NetworkType.none => "none",
        structs.NetworkType.nat => "nat",
    };
}

pub fn string_to_network_type(str: []const u8) ConversionError!structs.NetworkType {
    if (std.mem.eql(u8, str, "none")) {
        return structs.NetworkType.none;
    } else if (std.mem.eql(u8, str, "nat")) {
        return structs.NetworkType.nat;
    } else {
        return ConversionError.CannotConvertInput;
    }
}

pub fn interface_to_string(interface: structs.Interface) []const u8 {
    return switch (interface) {
        structs.Interface.rtl8139 => "rtl8139",
        structs.Interface.e1000 => "e1000",
        structs.Interface.e1000e => "e1000e",
        structs.Interface.vmware => "vmware",
        structs.Interface.usb => "usb",
        structs.Interface.virtio => "virtio",
    };
}

pub fn string_to_interface(str: []const u8) ConversionError!structs.Interface {
    if (std.mem.eql(u8, str, "rtl8139")) {
        return structs.Interface.rtl8139;
    } else if (std.mem.eql(u8, str, "e1000")) {
        return structs.Interface.e1000;
    } else if (std.mem.eql(u8, str, "e1000e")) {
        return structs.Interface.e1000e;
    } else if (std.mem.eql(u8, str, "vmware")) {
        return structs.Interface.vmware;
    } else if (std.mem.eql(u8, str, "usb")) {
        return structs.Interface.usb;
    } else if (std.mem.eql(u8, str, "virtio")) {
        return structs.Interface.virtio;
    } else {
        return ConversionError.CannotConvertInput;
    }
}

pub fn display_to_string(display: structs.Display) []const u8 {
    return switch (display) {
        structs.Display.none => "none",
        structs.Display.sdl => "sdl",
        structs.Display.gtk => "gtk",
        structs.Display.spice => "spice-app",
    };
}

pub fn string_to_display(str: []const u8) ConversionError!structs.Display {
    if (std.mem.eql(u8, str, "none")) {
        return structs.Display.none;
    } else if (std.mem.eql(u8, str, "sdl")) {
        return structs.Display.sdl;
    } else if (std.mem.eql(u8, str, "gtk")) {
        return structs.Display.gtk;
    } else if (std.mem.eql(u8, str, "spice-app")) {
        return structs.Display.spice;
    } else {
        return ConversionError.CannotConvertInput;
    }
}

pub fn gpu_to_string(gpu: structs.Gpu) []const u8 {
    return switch (gpu) {
        structs.Gpu.none => "none",
        structs.Gpu.vga => "vga",
        structs.Gpu.qxl => "qxl",
        structs.Gpu.vmware => "vmware",
        structs.Gpu.virtio => "virtio",
    };
}

pub fn string_to_gpu(str: []const u8) ConversionError!structs.Gpu {
    if (std.mem.eql(u8, str, "none")) {
        return structs.Gpu.none;
    } else if (std.mem.eql(u8, str, "vga")) {
        return structs.Gpu.vga;
    } else if (std.mem.eql(u8, str, "qxl")) {
        return structs.Gpu.qxl;
    } else if (std.mem.eql(u8, str, "vmware")) {
        return structs.Gpu.vmware;
    } else if (std.mem.eql(u8, str, "virtio")) {
        return structs.Gpu.virtio;
    } else {
        return ConversionError.CannotConvertInput;
    }
}

pub fn host_device_to_string(host_device: structs.HostDevice) []const u8 {
    return switch (host_device) {
        structs.HostDevice.none => "none",
        structs.HostDevice.alsa => "alsa",
        structs.HostDevice.pulseaudio => "pulseaudio",
    };
}

pub fn string_to_host_device(str: []const u8) ConversionError!structs.HostDevice {
    if (std.mem.eql(u8, str, "none")) {
        return structs.HostDevice.none;
    } else if (std.mem.eql(u8, str, "alsa")) {
        return structs.HostDevice.alsa;
    } else if (std.mem.eql(u8, str, "pulseaudio")) {
        return structs.HostDevice.pulseaudio;
    } else {
        return ConversionError.CannotConvertInput;
    }
}

pub fn sound_to_string(sound: structs.Sound) []const u8 {
    return switch (sound) {
        structs.Sound.sb16 => "sb16",
        structs.Sound.ac97 => "ac97",
        structs.Sound.ich6 => "ich6",
        structs.Sound.ich9 => "ich9",
        structs.Sound.usb => "usb",
    };
}

pub fn string_to_sound(str: []const u8) ConversionError!structs.Sound {
    if (std.mem.eql(u8, str, "sb16")) {
        return structs.Sound.sb16;
    } else if (std.mem.eql(u8, str, "ac97")) {
        return structs.Sound.ac97;
    } else if (std.mem.eql(u8, str, "ich6")) {
        return structs.Sound.ich6;
    } else if (std.mem.eql(u8, str, "ich9")) {
        return structs.Sound.ich9;
    } else if (std.mem.eql(u8, str, "usb")) {
        return structs.Sound.usb;
    } else {
        return ConversionError.CannotConvertInput;
    }
}

pub fn keyboard_to_string(keyboard: structs.Keyboard) []const u8 {
    return switch (keyboard) {
        structs.Keyboard.none => "none",
        structs.Keyboard.usb => "usb",
        structs.Keyboard.virtio => "virtio",
    };
}

pub fn string_to_keyboard(str: []const u8) ConversionError!structs.Keyboard {
    if (std.mem.eql(u8, str, "none")) {
        return structs.Keyboard.none;
    } else if (std.mem.eql(u8, str, "usb")) {
        return structs.Keyboard.usb;
    } else if (std.mem.eql(u8, str, "virtio")) {
        return structs.Keyboard.virtio;
    } else {
        return ConversionError.CannotConvertInput;
    }
}

pub fn mouse_to_string(mouse: structs.Mouse) []const u8 {
    return switch (mouse) {
        structs.Mouse.none => "none",
        structs.Mouse.usb => "usb",
        structs.Mouse.virtio => "virtio",
    };
}

pub fn string_to_mouse(str: []const u8) ConversionError!structs.Mouse {
    if (std.mem.eql(u8, str, "none")) {
        return structs.Mouse.none;
    } else if (std.mem.eql(u8, str, "usb")) {
        return structs.Mouse.usb;
    } else if (std.mem.eql(u8, str, "virtio")) {
        return structs.Mouse.virtio;
    } else {
        return ConversionError.CannotConvertInput;
    }
}

pub fn drive_bus_to_string(drive_bus: structs.DriveBus) []const u8 {
    return switch (drive_bus) {
        structs.DriveBus.usb => "usb",
        structs.DriveBus.ide => "ide",
        structs.DriveBus.sata => "sata",
        structs.DriveBus.virtio => "virtio",
    };
}

pub fn string_to_drive_bus(str: []const u8) ConversionError!structs.DriveBus {
    if (std.mem.eql(u8, str, "usb")) {
        return structs.DriveBus.usb;
    } else if (std.mem.eql(u8, str, "ide")) {
        return structs.DriveBus.ide;
    } else if (std.mem.eql(u8, str, "sata")) {
        return structs.DriveBus.sata;
    } else if (std.mem.eql(u8, str, "virtio")) {
        return structs.DriveBus.virtio;
    } else {
        return ConversionError.CannotConvertInput;
    }
}

pub fn drive_format_to_string(drive_format: structs.DriveFormat) []const u8 {
    return switch (drive_format) {
        structs.DriveFormat.raw => "raw",
        structs.DriveFormat.qcow2 => "qcow2",
        structs.DriveFormat.vmdk => "vmdk",
        structs.DriveFormat.vdi => "vdi",
        structs.DriveFormat.vhd => "vhd",
    };
}

pub fn string_to_drive_format(str: []const u8) ConversionError!structs.DriveFormat {
    if (std.mem.eql(u8, str, "raw")) {
        return structs.DriveFormat.raw;
    } else if (std.mem.eql(u8, str, "qcow2")) {
        return structs.DriveFormat.qcow2;
    } else if (std.mem.eql(u8, str, "vmdk")) {
        return structs.DriveFormat.vmdk;
    } else if (std.mem.eql(u8, str, "vdi")) {
        return structs.DriveFormat.vdi;
    } else if (std.mem.eql(u8, str, "vhd")) {
        return structs.DriveFormat.vhd;
    } else {
        return ConversionError.CannotConvertInput;
    }
}
