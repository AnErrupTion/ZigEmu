const std = @import("std");
const main = @import("main.zig");

pub const Error = error{ CannotSanitizeOutput, OutOfMemory };

pub fn sanitize_output_name(buffer: []u8) Error!std.ArrayList(u8) {
    if (buffer[0] == 0) {
        return Error.CannotSanitizeOutput;
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

pub fn sanitize_output_text(buffer: []u8) Error!std.ArrayList(u8) {
    var sanitized_buffer = std.ArrayList(u8).init(main.gpa);

    for (buffer) |byte| {
        if (byte == 0) {
            break;
        }

        try sanitized_buffer.append(byte);
    }

    return sanitized_buffer;
}

pub fn sanitize_output_number(buffer: []u8) Error!u64 {
    if (buffer[0] == 0) {
        return Error.CannotSanitizeOutput;
    }

    var sanitized_buffer = std.ArrayList(u8).init(main.gpa);
    defer sanitized_buffer.deinit();

    for (buffer) |byte| {
        if (byte == 0) {
            break;
        }

        try sanitized_buffer.append(byte);
    }

    return std.fmt.parseInt(u64, sanitized_buffer.items, 10) catch return Error.CannotSanitizeOutput;
}
