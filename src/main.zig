const std = @import("std");
const posix = std.posix;

const green = "\x1b[32m";
const red = "\x1b[31m";
const reset = "\x1b[0m";
const left = "\x1b[1D";

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var stdout_writer = std.Io.File.stdout().writer(io, &.{});
    const stdout = &stdout_writer.interface;

    const stdin_fd = posix.STDIN_FILENO;
    const orig_termios = try posix.tcgetattr(stdin_fd);
    var raw_termios = orig_termios;

    raw_termios.lflag.ICANON = false;
    raw_termios.lflag.ECHO = false;
    try posix.tcsetattr(stdin_fd, .FLUSH, raw_termios);
    defer posix.tcsetattr(stdin_fd, .FLUSH, orig_termios) catch {};

    var buf: [1]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().reader(io, &buf);
    const stdin = &stdin_reader.interface;

    const target_text = "Zig is cool!";
    try stdout.print("{s}\r", .{ target_text });
    try stdout.flush();

    var cursor_idx: usize = 0;
    while (true) {
        const symbol = stdin.takeByte() catch |err| switch(err) {
            error.EndOfStream => break,
            error.ReadFailed => break,
        };

        if (symbol == 127) {
            if (cursor_idx > 0) {
                cursor_idx -= 1;
                try stdout.print("{s}{s}{c}{s}", .{
                    left,
                    reset,
                    target_text[cursor_idx],
                    left
                });
                try stdout.flush();
            }
        } else if (symbol == target_text[cursor_idx]) {
            try stdout.print("{s}{c}", .{ green, symbol });
            try stdout.flush();
            cursor_idx += 1;
        } else {
            try stdout.print("{s}{c}", .{ red, symbol });
            try stdout.flush();
            cursor_idx += 1;
        }

        if (cursor_idx == target_text.len) {
            try stdout.print("\n", .{});
            try stdout.flush();
            break;
        }
    }
}
