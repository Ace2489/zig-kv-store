const std = @import("std");
const eql = std.mem.eql;
const expect = std.testing.expect;

pub const getImpl = struct { key: []const u8 };
pub const setImpl = struct { key: []const u8, value: []const u8 };
pub const deleteImpl = struct { key: []const u8 };

pub const Operation = union(enum) { get: getImpl, set: setImpl, delete: deleteImpl, quit };
pub const ParserError = error{ invalidOperation, noOpeningQuotesOnKey, noCloseQuotesOnKey, noSpace, noOpeningQuotesOnValue, noCloseQuotesOnValue, insufficientValue };
pub const InvalidSetArgumentError = error{};

// Pseudo-Grammar
// getOperation = "get" identifer
// setOperation = "set" identifer value
// deleteOperation = ""delete" identifer
// identifer = "<string>" //any string enclosed in quotes
// value = "<string>"//any string enclosed in quotes

pub fn parseOperation(inputString: []const u8) ParserError!Operation {
    if (eql(u8, inputString, "quit")) {
        return .quit;
    }

    const del = "delete";

    if (eql(u8, inputString[0..del.len], del)) {
        std.debug.print("\nDELETING\n", .{});
        return parseDeleteOperation(inputString);
    }

    if (inputString.len < "get \"a\"".len) { //Can't accomodate 'get "a"' or 'set "a"'
        return ParserError.invalidOperation;
    }

    const threeLetterOperation = inputString[0..5]; //Include an extra character for the space after 'get' or 'set'

    if (eql(u8, threeLetterOperation, "get \"")) {
        return parseGetOperation(inputString);
    }

    if (eql(u8, threeLetterOperation, "set \"")) { //Come back to this after handing the DELETE
        return parseSetOperation(inputString);
    }

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

    return .{ .set = .{ .key = inputString[key_start_index..key_end_index], .value = inputString[value_start_index + 1 .. value_end_index] } };
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

fn parseDeleteOperation(input_string: []const u8) ParserError!Operation {
    std.debug.assert(eql(u8, input_string[0.."delete".len], "delete"));

    if (input_string.len < "delete \"a\"".len) return ParserError.insufficientValue; // Can't accomodate 'delete "a" - the minimum amount of characters

    const del = "delete";

    if (input_string[del.len] != ' ') return ParserError.noSpace; //No space after the operation

    if (input_string[del.len + 1] != '"') return ParserError.noOpeningQuotesOnKey; // No opening quotes after the key

    const close_quote_position = getClosingQuotes(input_string, del.len + 2) orelse return ParserError.noCloseQuotesOnKey;

    const op = input_string[del.len + 2 .. close_quote_position];
    return .{ .delete = .{ .key = op } };
}

test getClosingQuotes {
    try expect(getClosingQuotes("no closing", 0) == null);
    try expect(getClosingQuotes("closing \"", 0) == 8);
    try expect(getClosingQuotes("closing \"", 5) == 8);
}

test parseOperation {
    try expect(parseOperation("erroring out") == ParserError.invalidOperation);
    try expect(parseOperation("error bla bla bla") == ParserError.invalidOperation);
    try expect(try parseOperation("quit") == Operation.quit);
}

test parseGetOperation {
    try expect(parseGetOperation("get \"args") == ParserError.noCloseQuotesOnKey); //No closing quotes
    try expect(try parseOperation("get \"args\"") == Operation.get); //Implicitly test that the caller calls this function
    const argument = try parseOperation("get \"args\"");
    try expect(eql(u8, argument.get.key, "args"));
}

test parseSetOperation {
    try expect(try parseSetOperation("set \"key\" \"value\"") == .set);
    const item = try parseOperation("set \"key\" \"value\"");
    try expect(eql(u8, item.set.key, "key"));
    try expect(eql(u8, item.set.value, "value"));
    try expect(parseSetOperation("set \"key") == ParserError.noCloseQuotesOnKey); //No closing quotes
    try expect(parseSetOperation("set \"key \"") == ParserError.insufficientValue); //Insufficient characters for a proper value
    try expect(parseSetOperation("set \"key\"value") == ParserError.noSpace); //No space after the key
    try expect(parseSetOperation("set \"key\" value") == ParserError.noOpeningQuotesOnValue); //No quotes to start off the value
    try expect(parseSetOperation("set \"key\" \"value") == ParserError.noCloseQuotesOnValue); //No quotes to end the value

}

test parseDeleteOperation {
    try expect(try parseDeleteOperation("delete \"args\"") == .delete);
    const argument = try parseOperation("delete \"key\"");

    try expect(eql(u8, argument.delete.key, "key"));

    try expect(parseDeleteOperation("delete") == ParserError.insufficientValue); //Not enough characters for a proper key
    try expect(parseDeleteOperation("deleteblabala") == ParserError.noSpace); //Not space after the operation
    try expect(parseDeleteOperation("delete bla bla bla") == ParserError.noOpeningQuotesOnKey); //No opening quotes before key
    try expect(parseDeleteOperation("delete \"args") == ParserError.noCloseQuotesOnKey); //No closing quotes
}
