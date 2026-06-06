const std = @import("std");
const posix = std.posix;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var stdout_writer = std.Io.File.stdout().writer(io, &.{});
    const stdout = &stdout_writer.interface;

    var buf: [1]u8 = undefined;
    // var stdin_reader = std.Io.File.stdin().reader(io, &buf);
    // const stdin = &stdin_reader.interface;

    const stdin_fd = posix.STDIN_FILENO;
    const orig_termios = try posix.tcgetattr(stdin_fd);
    var raw_termios = orig_termios;

    raw_termios.lflag.ICANON = false;
    raw_termios.lflag.ECHO = false;
    try posix.tcsetattr(stdin_fd, .FLUSH, raw_termios);
    defer posix.tcsetattr(stdin_fd, .FLUSH, orig_termios) catch {};

    var stdin_reader = std.Io.File.stdin().reader(io, &buf);
    const stdin = &stdin_reader.interface;

    while (true) {
        const symbol = stdin.takeByte() catch |err| switch(err) {
            error.EndOfStream => break,
            error.ReadFailed => break,
        };

        try stdout.print("You've pressed: {c} (code: {d})\n\r", .{ symbol, symbol });
        try stdout.flush();

        if (symbol == 'q') {
            break;
        }
    }
}
