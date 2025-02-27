const std = @import("std");
const stdout = std.io.getStdOut().writer();
const debugAlloc = std.heap.DebugAllocator;
const Allocator = std.mem.Allocator;
const Timer = @import("timer.zig").TimerHandler;
const runTimers = @import("timer.zig").runTimerHandler;

fn Test(timerId: []const u8) void {
    std.debug.print("Expiry action called for {s}\n", .{timerId});
}
pub fn main() !void {
    var alloc = std.heap.DebugAllocator(.{}).init;
    const testAllocator: Allocator = alloc.allocator();
    defer std.debug.assert(alloc.deinit() == .ok);

    var timer = Timer.init(testAllocator);
    defer timer.deinit();
    const thread = try std.Thread.spawn(.{}, runTimers, .{&timer});
    defer thread.join();

    try timer.timerQueue.append(.{ .requestId = "testReq", .duration = 1, .expiryAction = Test });
    try timer.timerQueue.append(.{ .requestId = "testReq2", .duration = 2, .expiryAction = Test });

    var store = std.StringHashMap([]const u8).init(testAllocator);
    defer store.deinit();

    try store.put("key", "value");
    std.debug.print("store has value {?s}", .{store.get("key")});
    std.time.sleep(std.time.ns_per_s * 5);
}

fn run(timer: *Timer) !void {
    try timer.run();
}
