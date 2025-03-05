const std = @import("std");
var bufReader = std.io.bufferedReader(std.io.getStdIn().reader());

pub const Io = struct {
    writer: @TypeOf(std.io.getStdOut().writer()),
    reader: @TypeOf(bufReader.reader()),

    pub fn init() Io {
        return .{ .writer = std.io.getStdOut().writer(), .reader = bufReader.reader() };
    }
};
