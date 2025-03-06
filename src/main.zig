const std = @import("std");
const stdout = std.io.getStdOut().writer();
const debugAlloc = std.heap.DebugAllocator;
const Allocator = std.mem.Allocator;
const Timer = @import("timer.zig").TimerHandler;
const timerRunner = @import("timer.zig").runTimerHandler;
const parserModule = @import("parser.zig");
const Io = @import("io.zig").Io;

const parser = parserModule.parseOperation;
const StoreCallbackArgs: type = struct { key: []const u8, hashmap: *std.StringHashMap([]const u8) };

pub fn main() !void {
    var alloc = std.heap.DebugAllocator(.{}).init;
    const testAllocator: Allocator = alloc.allocator();
    defer std.debug.assert(alloc.deinit() == .ok);

    var timer = Timer.init(testAllocator);
    defer timer.deinit();
    const thread = try std.Thread.spawn(.{ .allocator = testAllocator }, timerRunner, .{&timer});

    var store = std.StringHashMap([]const u8).init(testAllocator);
    defer store.deinit();

    var args: StoreCallbackArgs = .{ .hashmap = &store, .key = "key" };

    try store.put("key", "value");

    const io = Io.init();
    while (true) {
        _ = try io.writer.write("here now\n");

        const inputString: []const u8 = try getInput(testAllocator, io);
        defer testAllocator.free(inputString);

        const operation: parserModule.Operation = parser(inputString) catch |err| {
            try io.writer.print("Error: {}\n", .{err});
            break;
        };

        switch (operation) {
            .quit => break,
            .get => |getOp| {
                try io.writer.print("operations {} args {s}\n", .{ getOp, getOp.key });
            },
            .set => |setOp| {
                try io.writer.print("operations {} key {s} value {s}\n", .{ setOp, setOp.key, setOp.value });
            },
            else => {
                unreachable;
            },
        }
    }

    try timer.addToTimerQueue(.{ .requestId = "testReq2", .duration = 2, .expiryAction = expireItem, .expiryActionArgs = @ptrCast(&args) });
    thread.join();
}

// Called to 'expire' an item from the store - essentially, remove the item from the store after a duration of time
fn expireItem(timerId: []const u8, params: *anyopaque) void {
    std.debug.print("Expiry action called for {s}\n", .{timerId});
    const args = @as(*StoreCallbackArgs, @alignCast(@ptrCast(params)));
    std.debug.print("Removing entry with key: {s} from the store\n", .{args.key});

    const removed = args.hashmap.*.remove(args.key);
    std.debug.assert(removed == true);
}

fn getInput(allocator: Allocator, io: Io) ![]const u8 {
    var inputStream: std.ArrayList(u8) = std.ArrayList(u8).init(allocator);

    _ = try io.writer.write("> ");
    try io.reader.streamUntilDelimiter(inputStream.writer(), '\n', null);
    return inputStream.toOwnedSlice();
}
