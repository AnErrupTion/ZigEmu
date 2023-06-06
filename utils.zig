const std = @import("std");
const main = @import("main.zig");
const structs = @import("structs.zig");

pub const SanitizationError = error{ CannotSanitizeInput, OutOfMemory };
pub const ConversionError = error{CannotConvertInput};

pub fn sanitize_output_name(buffer: []u8) SanitizationError!std.ArrayList(u8) {
    if (buffer[0] == 0) {
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

pub fn sanitize_output_text(buffer: []u8) SanitizationError!std.ArrayList(u8) {
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

pub fn chipset_to_string(chipset: structs.Chipset) []const u8 {
    return switch (chipset) {
        structs.Chipset.i440fx => "pc",
        structs.Chipset.q35 => "q35",
    };
}

pub fn display_to_string(display: structs.Display) []const u8 {
    return switch (display) {
        structs.Display.none => "none",
        structs.Display.sdl => "sdl",
        structs.Display.gtk => "gtk",
        structs.Display.spice => "spice-app",
    };
}
