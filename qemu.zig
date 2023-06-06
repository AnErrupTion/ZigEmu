const main = @import("main.zig");

pub fn get_arguments(vm: main.VirtualMachine) []const []const u8 {
    _ = vm;
    return &[_][]const u8{"qemu-system-x86_64"};
}
