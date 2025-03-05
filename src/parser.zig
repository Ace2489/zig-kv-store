const std = @import("std");
const eql = std.mem.eql;
const expect = std.testing.expect;

pub const getImpl = struct { key: []const u8 };
pub const setImpl = struct { key: []const u8, value: []const u8 };

pub const Operation = union(enum) { get: getImpl, set: setImpl, delete, quit };
pub const ParserError = error{ invalidOperation, noCloseQuotesOnKey, noSpace, noOpeningQuotesOnValue, noCloseQuotesOnValue, insufficientValue };
pub const InvalidSetArgumentError = error{};

// Pseudo-Grammar
// getOperation = "get" identifer
// setOperation = "set" identifer value
// deleteOperation = ""delete" identifer
// identifer = "<string>" //any string enclosed in quotes
// value = "<string>"//any string enclosed in quotes

pub fn extractOperation(inputString: []const u8) ParserError!Operation {
    if (eql(u8, inputString, "quit")) {
        return .quit;
    }

    if (inputString.len < "get \"a\"".len) { //Can't accomodate the length of 'get "a"' or 'set "a"'
        return ParserError.invalidOperation;
    }

    const threeLetterOperation = inputString[0..5]; //Include an extra character for the space after 'get' or 'set'

    if (eql(u8, threeLetterOperation, "get \"")) {
        return parseGetOperation(inputString);
    }

    if (eql(u8, threeLetterOperation, "set \"")) { //Come back to this after handing the DELETE
        return parseSetOperation(inputString);
    }

    // if (eql(u8, inputString[0..8], "delete \"")) {
    //     return parseDeleteOperation(inputString);
    // }

    return ParserError.invalidOperation;
}

fn parseGetOperation(inputString: []const u8) ParserError!Operation {
    std.debug.assert(eql(u8, inputString[0..5], "get \""));

    if (inputString[inputString.len - 1] != '\"') { //Identifier doesn't end with a closing quote
        return ParserError.noCloseQuotesOnKey;
    }

    const key = inputString[5 .. inputString.len - 1]; //Don't take the closing quotes'
    return .{ .get = .{ .key = key } };
}

fn parseSetOperation(inputString: []const u8) ParserError!Operation {
    std.debug.assert(eql(u8, inputString[0..5], "set \""));

    const key_start_index = 5;
    const key_end_index = getClosingQuotes(inputString, key_start_index) orelse return ParserError.noCloseQuotesOnKey;

    //Less than the minimum number of characters: ' \"a\"'
    //The minimum characters for a value after the closing quote of a key are:
    //A space, an opening quote, one character for the value, and a closing quote
    if (inputString[key_end_index..].len < 3) {
        return ParserError.insufficientValue;
    }

    if (inputString[key_end_index + 1] != ' ') { //No space between key and value, e.g set "key""value", "key"value, etc.
        return ParserError.noSpace;
    }

    const value_start_index = key_end_index + 2; //skip 1 for the space inbetween

    if (inputString[value_start_index] != '\"') { //No opening quotes for the value
        return ParserError.noOpeningQuotesOnValue;
    }
    const value_end_index = getClosingQuotes(inputString, value_start_index + 1) orelse return ParserError.noCloseQuotesOnValue;

    return .{ .set = .{ .key = inputString[key_start_index .. key_end_index + 1], .value = inputString[value_start_index .. value_end_index + 1] } };
}

fn getClosingQuotes(input: []const u8, start_index: usize) ?usize {
    var close_string_index: ?usize = null;

    for (input[start_index..], start_index..) |c, i| { //get closing quote for the key
        if (c == '\"') {
            close_string_index = i;
            break;
        }
    }

    return close_string_index;
}

test getClosingQuotes {
    try expect(getClosingQuotes("no closing", 0) == null);
    try expect(getClosingQuotes("closing \"", 0) == 8);
    try expect(getClosingQuotes("closing \"", 5) == 8);
}

test extractOperation {
    try expect(extractOperation("erroring out") == ParserError.invalidOperation);
    try expect(extractOperation("error bla bla bla") == ParserError.invalidOperation);
    try expect(try extractOperation("quit") == Operation.quit);
}

test parseGetOperation {
    try expect(parseGetOperation("get \"args") == ParserError.noCloseQuotesOnKey); //No closing quotes
    try expect(try parseGetOperation("get \"args\"") == Operation.get);
    const argument = try parseGetOperation("get \"args\"");
    try expect(eql(u8, argument.get.key, "args"));
}

test parseSetOperation {
    try expect(try parseSetOperation("set \"key\" \"value\"") == .set);
    try expect(parseSetOperation("set \"key") == ParserError.noCloseQuotesOnKey); //No closing quotes
    try expect(parseSetOperation("set \"key \"") == ParserError.insufficientValue); //Insufficient characters for a proper value
    try expect(parseSetOperation("set \"key\"value") == ParserError.noSpace); //No space after the key
    try expect(parseSetOperation("set \"key\" value") == ParserError.noOpeningQuotesOnValue); //No quotes to start off the value
    try expect(parseSetOperation("set \"key\" \"value") == ParserError.noCloseQuotesOnValue); //No quotes to end the value

}

pub fn main() !void {
    const val = try extractOperation("set \"key\" \"value\"");
    std.debug.print("output :{s}", .{val.set.value});
}
