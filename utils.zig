const std = @import("std");
const gui = @import("gui");
const main = @import("main.zig");
const structs = @import("structs.zig");

pub const SanitizationError = error{ CannotSanitizeInput, OutOfMemory };
pub const ConversionError = error{CannotConvertInput};

pub const VERSION = "1.0.0";

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

pub fn add_text_option(option_name: []const u8, buffer: []u8, option_index: *u64) !void {
    try gui.label(@src(), "{s}:", .{option_name}, .{ .id_extra = option_index.* });
    option_index.* += 1;

    try gui.textEntry(@src(), .{ .text = buffer }, .{ .expand = .horizontal, .id_extra = option_index.* });
    option_index.* += 1;
}

pub fn add_combo_option(option_name: []const u8, options: []const []const u8, index: *u64, option_index: *u64) !void {
    try gui.label(@src(), "{s}:", .{option_name}, .{ .id_extra = option_index.* });
    option_index.* += 1;

    _ = try gui.dropdown(@src(), options, index, .{ .expand = .horizontal, .id_extra = option_index.* });
    option_index.* += 1;
}

pub fn add_bool_option(option_name: []const u8, value: *bool, option_index: *u64) !void {
    try gui.checkbox(@src(), value, option_name, .{ .id_extra = option_index.* });
    option_index.* += 1;
}
