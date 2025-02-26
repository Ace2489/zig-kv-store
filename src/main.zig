const std = @import("std");
const stdout = std.io.getStdOut().writer();
const debugAlloc = std.heap.DebugAllocator;
const Allocator = std.mem.Allocator;
const Timer = @import("timer.zig").TimerHandler;

fn Test() void {
    std.debug.print("Expiry action called\n", .{});
}
pub fn main() !void {
    var alloc = std.heap.DebugAllocator(.{}).init;
    const testAllocator: Allocator = alloc.allocator();
    defer std.debug.assert(alloc.deinit() == .ok);

    var timer = Timer.init(testAllocator);
    defer timer.deinit();

    try timer.timerQueue.append(.{ .requestId = "testReq", .duration = 1, .expiryAction = Test });
    try timer.timerQueue.append(.{ .requestId = "testReq2", .duration = 2, .expiryAction = Test });
    try timer.run();

    var store = std.StringHashMap([]const u8).init(testAllocator);
    defer store.deinit();

    try store.put("key", "value");
    const result: ?[]const u8 = store.get("key");
    std.debug.assert(result != null);
    std.debug.print("The mapped value is {s}\n", .{result.?});
}
