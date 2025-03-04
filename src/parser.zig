const std = @import("std");
const eql = std.mem.eql;
const expect = std.testing.expect;

pub const getImpl = struct { key: []const u8 };
pub const setImpl = struct { key: []const u8, value: []const u8 };

pub const Operation = union(enum) { get: getImpl, set: setImpl, delete, quit };
pub const ParserError = error{ invalidOperationError, invalidArgumentError };

//Pseudo-Grammar
// getOperation = "get" identifer
// setOperation = "set" identifer value
// deleteOperation = ""delete" identifer
// identifer = "<string>" //any string enclosed in quotes
// value = "<string>"//any string enclosed in quotes

pub fn extractOperation(inputString: []const u8) ParserError!Operation {
    if (eql(u8, inputString, "quit")) {
        return .quit;
    }

    const threeLetterOperation = inputString[0..5]; //Include an extrac character for the space after 'get' or 'set'

    if (eql(u8, threeLetterOperation, "get \"")) {
        return parse_getOperation(inputString);
    }

    // if (eql(u8, threeLetterOperation, "set ")) {
    //     return parse_setOperation(inputString);
    // }
    return ParserError.invalidOperationError;
}

fn parse_getOperation(inputString: []const u8) ParserError!Operation {
    std.debug.assert(eql(u8, inputString[0..5], "get \""));

    if (inputString[inputString.len - 1] != '\"') { //Identifier oesn't end with a closing quote
        return ParserError.invalidArgumentError;
    }

    const key = inputString[5 .. inputString.len - 1]; //Don't take the closing quotes'
    return .{ .get = .{ .key = key } };
}

test extractOperation {
    try expect(extractOperation("error") == ParserError.invalidOperationError);
    try expect(extractOperation("error bla bla bla") == ParserError.invalidOperationError);
    try expect(try extractOperation("quit") == Operation.quit);
}

test parse_getOperation {
    try expect(parse_getOperation("get \"args") == ParserError.invalidArgumentError); //No closing quotes
    try expect(try parse_getOperation("get \"args\"") == Operation.get);
    const argument = try parse_getOperation("get \"args\"");
    try expect(eql(u8, argument.get.key, "args"));
}

//useful for the set operation
// var close_string_index: usize = 0;

// for (inputString[5..], 0..) |c, i| {
//     std.debug.print("character {c}\n", .{c});
//     if (c == '\"') {
//         std.debug.print("setting index{c}\n", .{c});
//         close_string_index = i;
//         break;
//     }
// }

// if (close_string_index == 0) { //We didn't find a closing string in the arguments
// }

// test "setOperation"{
//     try expect(getOperation("set key value"), .{ .set = "value" });
// }
