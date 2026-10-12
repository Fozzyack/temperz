const std = @import("std");

const Io = std.Io;
const theme = @import("terminal_theme.zig");

var log_io: ?Io = null;

const LogError = error{
    LOG_IO_NOTSET,
    PRINTERROR,
};

pub fn init_log(io: Io) void {
    log_io = io;
}

pub fn log(comptime message: []const u8, args: anytype) !void {
    const io = log_io orelse return LogError.LOG_IO_NOTSET;
    var log_buffer: [1024]u8 = undefined;
    const msg = try std.mem.print(&log_buffer, message, args);
    try std.Io.File.stdout().writeStreamingAll(io, msg);
}

pub fn log_styled(tone: theme.Tone, comptime message: []const u8, args: anytype) !void {
    const io = log_io orelse return LogError.LOG_IO_NOTSET;
    var log_buffer: [1024]u8 = undefined;
    const msg = try std.mem.print(&log_buffer, message, args);
    try std.Io.File.stdout().writeStreamingAll(io, theme.stdout_style(tone));
    try std.Io.File.stdout().writeStreamingAll(io, msg);
    try std.Io.File.stdout().writeStreamingAll(io, theme.stdout_style(.reset));
}
