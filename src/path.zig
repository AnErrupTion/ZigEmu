const std = @import("std");

pub const LookupError = std.fmt.AllocPrintError || error{NotFound};

pub fn lookup(allocator: std.mem.Allocator, paths: []const []const u8, names: []const []const u8) LookupError![]const u8 {
    for (paths) |path| {
        var directory = std.fs.openIterableDirAbsolute(path, .{}) catch unreachable;
        defer directory.close();

        var iterator = directory.iterate();

        while (iterator.next() catch continue) |item| {
            const path_separator = if (!std.mem.endsWith(u8, path, std.fs.path.sep_str)) std.fs.path.sep_str else "";

            for (names) |name| if (std.mem.eql(u8, item.name, name)) return std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ path, path_separator, name });
        }
    }

    return LookupError.NotFound;
}
