const std = @import("std");
const stdout = std.io.getStdOut().writer();
const debugAlloc = std.heap.DebugAllocator;
const Allocator = std.mem.Allocator;
const Timer = @import("timer.zig").TimerHandler;
const timerRunner = @import("timer.zig").runTimerHandler;
const parserModule = @import("parser.zig");
const Io = @import("io.zig").Io;

const parser = parserModule.parseOperation;
const StoreCallbackArgs: type = struct { key: []const u8, hashmap: *std.StringHashMap([]const u8), allocator: *const Allocator };

pub fn main() !void {
    var alloc = std.heap.DebugAllocator(.{ .thread_safe = true }).init;
    const testAllocator: Allocator = alloc.allocator();
    defer _ = alloc.deinit();

    var timer = Timer.init(testAllocator);
    defer timer.deinit();
    const thread = try std.Thread.spawn(.{ .allocator = testAllocator }, timerRunner, .{&timer});

    var store = std.StringHashMap([]const u8).init(testAllocator);
    defer store.deinit();

    const io = Io.init();
    while (true) {
        const inputString: []const u8 = try getInput(testAllocator, io);
        defer testAllocator.free(inputString);

        const operation: parserModule.Operation = parser(inputString) catch |err| {
            try io.writer.print("Error: {}\n", .{err});
            continue;
        };

        switch (operation) {
            .quit => {
                thread.detach();
                break;
            },
            .get => |getOp| {
                try io.writer.print("operations {} args {s}\n", .{ getOp, getOp.key });
                try io.writer.print("{?s}\n", .{store.get(getOp.key)});
            },
            .set => |setOp| {
                try io.writer.print("operations {} key {s} value {s}\n", .{ setOp, setOp.key, setOp.value });

                const key = try testAllocator.dupe(u8, setOp.key);
                const value = try testAllocator.dupe(u8, setOp.value);

                const inserted = try idempotentInsert(&store, key, value);
                if (!inserted) {
                    try io.writer.print("{s} already exists in the store. Delete it and try again\n", .{key});
                    continue;
                }

                const expiryTime = 10; //Each tick is one second.

                const expiryActionArgs = try testAllocator.create(StoreCallbackArgs);
                expiryActionArgs.* = .{ .hashmap = &store, .key = key, .allocator = &testAllocator };

                try timer.addToTimerQueue(.{ .requestId = key, .duration = expiryTime, .expiryAction = expireItem, .expiryActionArgs = @ptrCast(expiryActionArgs) });
            },
            .delete => |deleteOp| {
                try io.writer.print("Delete OP with key: {s}\n", .{deleteOp.key});
                const removed = store.fetchRemove(deleteOp.key) orelse
                    {
                        try io.writer.print("There is no entry with a key of {s} in the store\n", .{deleteOp.key});
                        continue;
                    };

                const timerDetails = timer.stopTimer(deleteOp.key); //Make sure to stop the timer before freeing the keys, as they point to the same memory
                testAllocator.free(removed.key);
                testAllocator.free(removed.value);
                const args = @as(*StoreCallbackArgs, @alignCast(@ptrCast(timerDetails)));

                testAllocator.destroy(args);
            },
        }
    }
}

// Called to 'expire' an item from the store - essentially, remove the item from the store after a duration of time
fn expireItem(timerId: []const u8, params: *anyopaque) void {
    std.debug.print("Expiry action called for {s}\n", .{timerId});
    const args = @as(*StoreCallbackArgs, @alignCast(@ptrCast(params)));

    std.debug.print("Removing entry with key: {s} from the store\n", .{args.key});
    // std.Thread.Mutex()

    const removed = args.hashmap.fetchRemove(args.key) orelse std.debug.panic("No store entry exists for the given key: {s}\n", .{args.key});

    const allocator = args.allocator;
    allocator.*.destroy(args);
    allocator.*.free(removed.key); //Also removes the timerId, since they're both references to the same memory
    allocator.*.free(removed.value);
}

fn getInput(allocator: Allocator, io: Io) ![]const u8 {
    var inputStream: std.ArrayList(u8) = std.ArrayList(u8).init(allocator);

    _ = try io.writer.write("> ");
    try io.reader.streamUntilDelimiter(inputStream.writer(), '\n', null);
    return inputStream.toOwnedSlice();
}

fn idempotentInsert(store: *std.StringHashMap([]const u8), key: []const u8, value: []const u8) !bool {
    const result = try store.*.getOrPut(key);
    if (result.found_existing == false) {
        result.value_ptr.* = value;
        return true;
    }
    return false;
}

const expect = std.testing.expect;
test idempotentInsert {
    const allocator = std.testing.allocator;
    var store = std.StringHashMap([]const u8).init(allocator);
    defer store.deinit();

    try expect(try idempotentInsert(&store, "key", "value") == true); //First insert
    try expect(try idempotentInsert(&store, "key", "value") == false); //Second insert should fail
}
