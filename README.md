# zig-kv-store

An in-memory key-value store with TTL support built in Zig.

## Overview

This is a simple KV store implementation with a command parser, in-memory storage, and a timer-based expiration system. The code demonstrates basic usage of Zig's memory management, error handling, and concurrency primitives.

## Components

- `parser.zig`: Handles command parsing with error handling (get/set operations)
- `timer.zig`: Implements a timer system to track and expire entries
- `io.zig`: Simple I/O wrapper for terminal interaction
- `main.zig`: Ties everything together

## Implementation Notes

The timer system runs on a separate thread and processes expiration events. The command parser validates input syntax and converts string commands to structured operations. The default expiry timer for entries is set to five minutes.

Commands are parsed according to a simple grammar:
```
getOperation = "get" key
setOperation = "set" key value
identifer = "<string>" //any string enclosed in quotes
value = "<string>" //any string enclosed in quotes
```

## Getting Started
Clone the repo
```
git clone https://github.com/Ace2489/zig-kv-store
```
Navigate to the root directory of the project
```
cd zig-kv-store
```
Run the program (The logs are currently printed to stderr, redirect them to prevent distractions)
```
zig run src/main.zig 2> error.txt
```


## Usage

```
> set "key" "value"
> get "key"
> delete "key"
> quit
```

## Limitations

This is a learning project and has several limitations:
- No persistence
- Basic error handling

## Build

Built with Zig version 0.14.0
