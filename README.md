# zig-kv-store

An in-memory key-value store with TTL support built in Zig. This project is mainly a learning exercise to explore Zig's features for systems programming.

## Overview

This is a simple KV store implementation with a command parser, in-memory storage using Zig's HashMaps, and a timer-based expiration system. The code demonstrates basic usage of Zig's memory management, error handling, and concurrency primitives.

## Components

- `parser.zig`: Handles command parsing with error handling (get/set operations)
- `timer.zig`: Implements a timer system to track and expire entries
- `io.zig`: Simple I/O wrapper for terminal interaction
- `main.zig`: Ties everything together

## Implementation Notes

The timer system runs on a separate thread and processes expiration events. The command parser validates input syntax and converts string commands to structured operations. Both components use Zig's error handling approach extensively.

Commands are parsed according to a simple grammar:
```
getOperation = "get" identifer
setOperation = "set" identifer value
identifer = "<string>" //any string enclosed in quotes
value = "<string>" //any string enclosed in quotes
```

## Usage

```
> set "key" "value"
> get "key"
> quit
```

## Limitations

This is a learning project and has several limitations:
- No persistence
- Basic error handling

## Build

Built with Zig version 0.14.0
