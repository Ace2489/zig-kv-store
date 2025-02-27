const std = @import("std");
const Allocator = std.mem.Allocator;
const StringHashmap = std.StringHashMap;

pub const TimerHandler = struct {
    const timerDetails = struct { requestId: []const u8, duration: u64, expiryAction: *const fn ([]const u8) void };
    timerQueue: std.ArrayList(timerDetails), //todo: move this to an actual queue instead of an ArrayList
    runningTimers: StringHashmap(timerDetails), //hashmap of timers currently running to allow O(1) insertion/removal

    pub fn init(allocator: Allocator) TimerHandler {
        return .{ .runningTimers = StringHashmap(timerDetails).init(allocator), .timerQueue = std.ArrayList(timerDetails).init(allocator) };
    }

    pub fn deinit(self: *TimerHandler) void {
        self.runningTimers.deinit();
        self.timerQueue.deinit();
    }

    fn startTimer(self: *TimerHandler, requestId: []const u8, duration: u64, expiryAction: *const fn ([]const u8) void) !void {
        try self.runningTimers.put(requestId, .{ .requestId = requestId, .duration = duration, .expiryAction = expiryAction });
        errdefer std.debug.print("Failed to insert timer with id {s}", .{requestId});
    }

    pub fn stopTimer(self: *TimerHandler, requestId: []const u8) void {
        _ = requestId;
        _ = self;
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
        const callback: *const fn ([]const u8) void = self.runningTimers.get(requestId).?.expiryAction;
        const removed = self.runningTimers.remove(requestId);

        std.debug.assert(removed == true);
        callback(requestId);
    }

    pub fn run(self: *TimerHandler) !void {
        const interval = std.time.ns_per_s;
        const now_from_epoch: i128 = std.time.nanoTimestamp();

        std.debug.assert(now_from_epoch > 0); //Because why the heck would we be in the past lol
        std.debug.print("Timer started at {}ns from the epoch\n", .{now_from_epoch});

        var timer = std.time.Timer.start() catch @panic("Failed to start TimerHandler's timer\n");
        while (true) {
            std.Thread.sleep(interval);
            const now: u128 = timer.read() + @as(u128, @intCast(now_from_epoch));
            std.debug.print("\nTimer running at {}ns\n", .{now});

            for (self.timerQueue.items) |i| {
                _ = i;
                const request = self.timerQueue.orderedRemove(0); //An expensive workaround to not using a queue yet
                std.debug.print("Adding a new timer to the queue. Timer Details: Id:{s} Callback:{} Duration/TickCount:{}\n", .{ request.requestId, request.expiryAction, request.duration });
                try self.startTimer(request.requestId, request.duration, request.expiryAction);
            }

            self.perTickBookkeeping(now);
            // if (now - (@as(u128, @intCast(now_from_epoch))) >= std.time.ns_per_s * 5) { //Break if it's run for five seconds - here for debugging purposes
            //     break;
            // }
        }
    }
};
