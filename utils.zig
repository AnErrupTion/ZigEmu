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

pub fn drive_format_to_string(drive_format: structs.DriveFormat) []const u8 {
    return switch (drive_format) {
        structs.DriveFormat.raw => "raw",
        structs.DriveFormat.qcow2 => "qcow2",
        structs.DriveFormat.vmdk => "vmdk",
        structs.DriveFormat.vdi => "vdi",
        structs.DriveFormat.vhd => "vhd",
    };
}
