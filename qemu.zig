const std = @import("std");
const main = @import("main.zig");
const permanent_buffers = @import("permanent_buffers.zig");

pub fn get_arguments(vm: main.VirtualMachine) !std.ArrayList([]const u8) {
    var list = std.ArrayList([]const u8).init(main.gpa);

    var name = try std.fmt.allocPrint(main.gpa, "\"{s}\",process=\"{s}\"", .{ vm.machine.name, vm.machine.name });
    var cpu = try std.fmt.allocPrint(main.gpa, "{s},{s}", .{ vm.machine.cpu, vm.machine.features });
    var ram = try std.fmt.allocPrint(main.gpa, "{d}M", .{vm.machine.ram});
    var smp = try std.fmt.allocPrint(main.gpa, "cores={d},threads={d}", .{ vm.machine.cores, vm.machine.threads });

    try permanent_buffers.arrays.append(name);
    try permanent_buffers.arrays.append(cpu);
    try permanent_buffers.arrays.append(ram);
    try permanent_buffers.arrays.append(smp);

    try list.append("qemu-system-x86_64");
    try list.append("-enable-kvm");
    try list.append("-name");
    try list.append(name);
    try list.append("-cpu");
    try list.append(cpu);
    try list.append("-m");
    try list.append(ram);
    try list.append("-smp");
    try list.append(smp);

    return list;
}
