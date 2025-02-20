const std = @import("std");
const stdout = std.io.getStdOut().writer();
const debugAlloc = std.heap.DebugAllocator;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var alloc = debugAlloc(.{}).init;
    const testAllocator: Allocator = alloc.allocator();
    defer std.debug.assert(alloc.deinit() == .ok);

    var map = std.StringHashMap([]const u8).init(testAllocator);
    defer map.deinit();

    try map.put("key", "value");
    const result: []const u8 = map.get("key") orelse "empty";
    std.debug.print("The mapped value is {s}\n", .{result});
}
