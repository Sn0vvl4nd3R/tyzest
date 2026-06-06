const std = @import("std");
const posix = std.posix;

const Ansi = struct {
    pub const green = "\x1b[32m";
    pub const red = "\x1b[31m";
    pub const reset = "\x1b[0m";
    pub const left = "\x1b[1D";
};

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
    var errors_count: usize = 0;
    var opt_time: ?std.Io.Timestamp = null;
    while (true) {
        const symbol = stdin.takeByte() catch |err| switch(err) {
            error.EndOfStream => break,
            error.ReadFailed => break,
        };

        if (opt_time == null) {
            opt_time = std.Io.Clock.awake.now(io);
        }

        if (symbol == 127) {
            if (cursor_idx > 0) {
                cursor_idx -= 1;
                try stdout.print("{s}{s}{c}{s}", .{
                    Ansi.left,
                    Ansi.reset,
                    target_text[cursor_idx],
                    Ansi.left,
                });
                try stdout.flush();
            }
        } else if (symbol == target_text[cursor_idx]) {
            try stdout.print("{s}{c}", .{ Ansi.green, symbol });
            try stdout.flush();
            cursor_idx += 1;
        } else {
            try stdout.print("{s}{c}", .{ Ansi.red, symbol });
            try stdout.flush();
            cursor_idx += 1;
            errors_count += 1;
        }

        if (cursor_idx == target_text.len) {
            try stdout.print("\n", .{});
            try stdout.flush();
            break;
        }
    }

    const elapsed_s = if (opt_time) |start|
        @as(f64, @floatFromInt(start.untilNow(io, .awake).toNanoseconds())) / 1_000_000_000.0
    else
        0.0;

    const len_f64: f64 = @floatFromInt(target_text.len);
    const err_f64: f64 = @floatFromInt(errors_count);
    const accuracy = @max(0.0, (1.0 - (err_f64 / len_f64)) * 100.0);

    const wmp = if (elapsed_s > 0) (len_f64 / 5.0) / (elapsed_s / 60.0) else 0.0;

    try stdout.print("{s}Symbols: {}\nErrors: {}\nAccuracy: {d:.2}%\nTime: {d:.2}s\nWPM: {d:.2}\n", .{
        Ansi.reset,
        target_text.len,
        errors_count,
        accuracy,
        elapsed_s,
        wmp,
    });
    try stdout.flush();
}
