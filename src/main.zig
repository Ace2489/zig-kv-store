const std = @import("std");
const stdout = std.io.getStdOut().writer();
const debugAlloc = std.heap.DebugAllocator;
const Allocator = std.mem.Allocator;
const Timer = @import("timer.zig").TimerHandler;
const runTimers = @import("timer.zig").runTimerHandler;
const StoreCallbackArgs: type = struct { key: []const u8, hashmap: *std.StringHashMap([]const u8) };

pub fn main() !void {
    var alloc = std.heap.DebugAllocator(.{}).init;
    const testAllocator: Allocator = alloc.allocator();
    defer std.debug.assert(alloc.deinit() == .ok);

    var timer = Timer.init(testAllocator);
    defer timer.deinit();
    const thread = try std.Thread.spawn(.{ .allocator = testAllocator }, runTimers, .{&timer});

    var store = std.StringHashMap([]const u8).init(testAllocator);
    defer store.deinit();

    try store.put("key", "value");
    std.debug.print("store has value {?s}\n", .{store.get("key")});
    std.time.sleep(std.time.ns_per_s * 5);

    var args: StoreCallbackArgs = .{ .hashmap = &store, .key = "key" };

    try timer.timerQueue.append(.{ .requestId = "testReq2", .duration = 2, .expiryAction = ExpireItem, .expiryActionArgs = @ptrCast(&args) });
    thread.join();
}

fn ExpireItem(timerId: []const u8, params: *anyopaque) void {
    std.debug.print("Expiry action called for {s}\n", .{timerId});
    const args = @as(*StoreCallbackArgs, @alignCast(@ptrCast(params)));
    std.debug.print("Removing entry with key: {s} from the store\n", .{args.key});

    const removed = args.hashmap.*.remove(args.key);
    std.debug.assert(removed == true);
}
