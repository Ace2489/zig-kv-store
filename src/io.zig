const std = @import("std");
var bufWriter = std.io.bufferedWriter(std.io.getStdOut().writer());
var bufReader = std.io.bufferedReader(std.io.getStdIn().reader());

pub const Io = struct {
    writer: @TypeOf(bufWriter.writer()),
    reader: @TypeOf(bufReader.reader()),

    pub fn init() Io {
        return .{ .writer = bufWriter.writer(), .reader = bufReader.reader() };
    }
};
