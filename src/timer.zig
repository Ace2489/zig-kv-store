const std = @import("std");
const Allocator = std.mem.Allocator;
const StringHashmap = std.StringHashMap;

/// A timer handler which handles multiple timers by decrementing each timer in every tick.
/// The tick interval is user-specified takes O(n) time to process all pending timers.
pub const TimerHandler = struct {
    const TimerDetails = struct { requestId: []const u8, duration: u64, expiryAction: *const fn ([]const u8, args: *anyopaque) void, expiryActionArgs: *anyopaque };
    timerQueue: std.ArrayList(TimerDetails), //todo: move this to an actual queue instead of an ArrayList
    runningTimers: StringHashmap(TimerDetails), //hashmap of timers currently running to allow O(1) insertion/removal

    pub fn init(allocator: Allocator) TimerHandler {
        return .{ .runningTimers = StringHashmap(TimerDetails).init(allocator), .timerQueue = std.ArrayList(TimerDetails).init(allocator) };
    }

    pub fn deinit(self: *TimerHandler) void {
        self.runningTimers.deinit();
        self.timerQueue.deinit();
    }

    //Adds a timer to the timerQueue - timers are popped from the queue and started on each tick
    pub fn addToTimerQueue(self: *TimerHandler, timer: TimerDetails) !void {
        try self.timerQueue.append(timer);
    }

    //Starts a timer which expires after the specified duration
    fn startTimer(self: *TimerHandler, requestId: []const u8, duration: u64, expiryAction: *const fn ([]const u8, expiryActionArgs: *anyopaque) void, expiryActionArgs: *anyopaque) !void {
        try self.runningTimers.put(requestId, .{ .requestId = requestId, .duration = duration, .expiryAction = expiryAction, .expiryActionArgs = expiryActionArgs });
        errdefer std.debug.print("Failed to insert timer with id {s}", .{requestId});
    }

    pub fn stopTimer(self: *TimerHandler, requestId: []const u8) void {
        std.debug.print("Stop timer called with timerId {s}", .{requestId});
        const removed = self.runningTimers.remove(requestId);
        std.debug.assert(removed == true); //We should never call a stopTimer for a non-existent timer - that should have been handled by the caller function
    }

    fn perTickBookkeeping(self: *TimerHandler, now: u128) void {
        std.debug.print("Bookkeeping at timestamp {}ns\n", .{now});
        var iterator = self.runningTimers.iterator();

        while (iterator.next()) |timer| {
            std.debug.print("Modifying timer with key {s} \n", .{timer.key_ptr.*});
            timer.value_ptr.*.duration -= 1;
            if (timer.value_ptr.*.duration == 0) {
                self.expiryProcessing(timer.key_ptr.*);
            }
        }
    }

    fn expiryProcessing(self: *TimerHandler, requestId: []const u8) void {
        const callback = self.runningTimers.get(requestId).?.expiryAction;
        const removed = self.runningTimers.fetchRemove(requestId) orelse std.debug.panic("Tried to expire a non-existent timerId: {s}", .{requestId});

        callback(requestId, removed.value.expiryActionArgs);
    }
};

pub fn runTimerHandler(timerHandler: *TimerHandler) !void {
    const interval = std.time.ns_per_s;
    const now_from_epoch: i128 = std.time.nanoTimestamp();

    std.debug.assert(now_from_epoch > 0); //Because why the heck would we be in the past lol
    std.debug.print("Timer started at {}ns from the epoch\n", .{now_from_epoch});

    var timer = std.time.Timer.start() catch @panic("Failed to start TimerHandler's timer\n");
    while (true) {
        std.Thread.sleep(interval);
        const now: u128 = timer.read() + @as(u128, @intCast(now_from_epoch));
        std.debug.print("\nTimer running at {}ns\n", .{now});

        for (timerHandler.timerQueue.items) |i| {
            _ = i;
            const request = timerHandler.timerQueue.orderedRemove(0); //An expensive workaround to not using a queue yet
            std.debug.print("Adding a new timer to the queue. Timer Details: Id:{s} Callback:{} Duration/TickCount:{}\n", .{ request.requestId, request.expiryAction, request.duration });
            try timerHandler.startTimer(request.requestId, request.duration, request.expiryAction, request.expiryActionArgs);
        }

        timerHandler.perTickBookkeeping(now);
        if (now - (@as(u128, @intCast(now_from_epoch))) >= std.time.ns_per_s * 10) { //Break if it's run for ten seconds - here for debugging purposes
            // break;
        }
    }
}
