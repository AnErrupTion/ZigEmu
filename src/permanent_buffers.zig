const std = @import("std");
const main = @import("main.zig");

pub var lists: std.ArrayList(std.ArrayList(u8)) = undefined;
pub var arrays: std.ArrayList([]const u8) = undefined;

pub fn init() void {
    lists = std.ArrayList(std.ArrayList(u8)).init(main.gpa);
    arrays = std.ArrayList([]const u8).init(main.gpa);
}

pub fn deinit() void {
    for (lists.items) |list| {
        list.deinit();
    }

    for (arrays.items) |array| {
        main.gpa.free(array);
    }

    lists.deinit();
    arrays.deinit();
}
