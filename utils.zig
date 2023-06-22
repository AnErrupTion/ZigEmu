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
    } else if (std.mem.eql(u8, str, "virtio")) {
        return structs.Gpu.virtio;
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

pub fn drive_format_to_string(drive_format: structs.DriveFormat) []const u8 {
    return switch (drive_format) {
        structs.DriveFormat.raw => "raw",
        structs.DriveFormat.qcow2 => "qcow2",
        structs.DriveFormat.vmdk => "vmdk",
        structs.DriveFormat.vdi => "vdi",
        structs.DriveFormat.vhd => "vhd",
    };
}
