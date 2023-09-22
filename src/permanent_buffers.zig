const std = @import("std");
const Allocator = std.mem.Allocator;

var allocator: Allocator = undefined;

pub var lists: std.ArrayList(std.ArrayList(u8)) = undefined;
pub var arrays: std.ArrayList([]const u8) = undefined;

pub fn init(buffer_allocator: Allocator) void {
    allocator = buffer_allocator;
    lists = std.ArrayList(std.ArrayList(u8)).init(allocator);
    arrays = std.ArrayList([]const u8).init(allocator);
}

pub fn deinit() void {
    for (lists.items) |list| list.deinit();
    for (arrays.items) |array| allocator.free(array);

    lists.deinit();
    arrays.deinit();
}
