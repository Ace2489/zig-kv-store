const std = @import("std");
const eql = std.mem.eql;
const startsWith = std.mem.startsWith;
const expect = std.testing.expect;

pub const getImpl = struct { key: []const u8 };
pub const setImpl = struct { key: []const u8, value: []const u8 };
pub const deleteImpl = struct { key: []const u8 };

pub const Operation = union(enum) { get: getImpl, set: setImpl, delete: deleteImpl, quit };

pub const ParserError = error{ invalidOperation, insufficientKey, noOpeningQuotesOnKey, noClosingQuotesOnKey, noOpeningQuotesOnValue, noCloseQuotesOnValue, insufficientValue };

pub const InvalidSetArgumentError = error{};

// Pseudo-Grammar
// getOperation = "get" key
// setOperation = "set" key value
// deleteOperation = ""delete" key
// key = "<string>" //any string enclosed in quotes
// value = "<string>"//any string enclosed in quotes

pub fn parseOperation(input_string: []const u8) ParserError!Operation {
    if (eql(u8, input_string, "quit")) {
        return .quit;
    }

    if (startsWith(u8, input_string, "get")) return parseGetOperation(input_string);

    if (startsWith(u8, input_string, "set")) return parseSetOperation(input_string);

    if (startsWith(u8, input_string, "delete")) return parseDeleteOperation(input_string);

    return ParserError.invalidOperation;
}

fn parseGetOperation(input_string: []const u8) ParserError!Operation {
    const get = "get";
    std.debug.assert(startsWith(u8, input_string, get)); // We should never reach a situation where this is called with a wrong string
    if (input_string.len < "get \"a\"".len) return ParserError.insufficientKey; //The minimum length for a valid getOperation

    const key_start_index = getCharacterIndex(input_string, '\"', get.len) orelse return ParserError.noOpeningQuotesOnKey;

    const key_end_index = getCharacterIndex(input_string, '\"', key_start_index + 1) orelse return ParserError.noClosingQuotesOnKey;

    const key = input_string[key_start_index + 1 .. key_end_index]; //skip the opening quote

    return .{ .get = .{ .key = key } };
}

fn parseSetOperation(input_string: []const u8) ParserError!Operation {
    const set = "set";
    std.debug.assert(startsWith(u8, input_string, set)); // We should never reach a situation where this is called with a wrong string

    if (input_string.len < "set \"a\"".len) return ParserError.insufficientKey; //The minimum length for a valid setOperation

    const key_start_index = getCharacterIndex(input_string, '\"', set.len) orelse return ParserError.noOpeningQuotesOnKey;

    const key_end_index = getCharacterIndex(input_string, '\"', key_start_index + 1) orelse return ParserError.noClosingQuotesOnKey;

    //Less than the minimum number of characters: ' \"a\"'
    //The minimum characters for a value after the closing quote of a key are:
    //A space, an opening quote, one character for the value, and a closing quote
    if (input_string[key_end_index + 1 ..].len < 4) {
        return ParserError.insufficientValue;
    }

    const value_start_index = getCharacterIndex(input_string, '\"', key_end_index + 1) orelse return ParserError.noOpeningQuotesOnValue;
    const value_end_index = getCharacterIndex(input_string, '\"', value_start_index + 1) orelse return ParserError.noCloseQuotesOnValue;

    return .{ .set = .{ .key = input_string[key_start_index + 1 .. key_end_index], .value = input_string[value_start_index + 1 .. value_end_index] } };
}

fn getCharacterIndex(input_string: []const u8, character: u8, start_index: usize) ?usize {
    var index = start_index;
    while (index < input_string.len) {
        if (input_string[index] == character) return index;
        index += 1;
    }
    return null;
}

fn parseDeleteOperation(input_string: []const u8) ParserError!Operation {
    const del = "delete";
    std.debug.assert(startsWith(u8, input_string, del));

    if (input_string.len < "delete \"a\"".len) return ParserError.insufficientKey; //The minimum length for a valid deleteOperation

    const key_start_index = getCharacterIndex(input_string, '\"', del.len) orelse return ParserError.noOpeningQuotesOnKey;

    const key_end_index = getCharacterIndex(input_string, '\"', key_start_index + 1) orelse return ParserError.noClosingQuotesOnKey;

    const op = input_string[key_start_index + 1 .. key_end_index];

    return .{ .delete = .{ .key = op } };
}

test parseOperation {
    try expect(parseOperation("erroring out") == ParserError.invalidOperation);
    try expect(parseOperation("error bla bla bla") == ParserError.invalidOperation);
    try expect(parseOperation("gi") == ParserError.invalidOperation);
    try expect(try parseOperation("quit") == Operation.quit);
}

test parseGetOperation {
    try expect(parseGetOperation("get") == ParserError.insufficientKey);
    try expect(parseGetOperation("get \"args") == ParserError.noClosingQuotesOnKey); //No closing quotes
    try expect(try parseOperation("get                   \"args\"") == Operation.get); //Implicitly test that the caller calls this function, and multiple whitespace
    const argument = try parseOperation("get \"args\"");
    try expect(eql(u8, argument.get.key, "args"));
}

test parseSetOperation {
    try expect(try parseSetOperation("set \"key\" \"value\"") == .set);
    const item = try parseOperation("set \"key\" \"value\"");
    try expect(eql(u8, item.set.key, "key"));
    try expect(eql(u8, item.set.value, "value"));
    try expect(parseSetOperation("set") == ParserError.insufficientKey);
    try expect(parseSetOperation("set \"key") == ParserError.noClosingQuotesOnKey); //No closing quotes
    try expect(parseSetOperation("set \"key \"") == ParserError.insufficientValue); //Insufficient characters for a proper value
    try expect(parseSetOperation("set \"key\" value") == ParserError.noOpeningQuotesOnValue); //No quotes to start off the value
    try expect(parseSetOperation("set \"key\" \"value") == ParserError.noCloseQuotesOnValue); //No quotes to end the value
}

test parseDeleteOperation {
    try expect(try parseDeleteOperation("delete \"args\"") == .delete);
    const argument = try parseOperation("delete \"key\"");

    try expect(eql(u8, argument.delete.key, "key"));

    try expect(parseDeleteOperation("delete") == ParserError.insufficientKey); //Not enough characters for a proper key
    try expect(parseDeleteOperation("delete bla bla bla") == ParserError.noOpeningQuotesOnKey); //No opening quotes before key
    try expect(parseDeleteOperation("delete \"args") == ParserError.noClosingQuotesOnKey); //No closing quotes
}

test getCharacterIndex {
    const index = (getCharacterIndex("str     \"", '\"', "str".len));
    try expect(index == 8);
}
