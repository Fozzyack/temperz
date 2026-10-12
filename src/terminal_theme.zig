const std = @import("std");

// Shared ANSI slots in configs/home/wezterm.lua and ghostty/themes/retro-dark.
// Keep the terminal's charcoal background, transparency, and font untouched.
pub const Tone = enum { reset, text, heading, accent, teal, muted, success, failure };

var stderr_color = false;
var stdout_color = false;
pub var interactive = false;

pub fn init(io: std.Io, no_color: bool, dumb_terminal: bool) void {
    interactive = !dumb_terminal and (std.Io.File.stderr().isTty(io) catch false);
    stderr_color = interactive and !no_color;
    stdout_color = !dumb_terminal and !no_color and (std.Io.File.stdout().isTty(io) catch false);
}

pub fn sequence(tone: Tone, enabled: bool) []const u8 {
    if (!enabled) return "";
    return switch (tone) {
        .reset => "\x1b[0m",
        .text => "\x1b[37m", // warm cream
        .heading => "\x1b[1;37m",
        .accent => "\x1b[33m", // burnt orange, not the default terminal yellow
        .teal => "\x1b[36m",
        .muted => "\x1b[90m",
        .success => "\x1b[32m",
        .failure => "\x1b[31m",
    };
}

pub fn style(tone: Tone) []const u8 {
    return sequence(tone, stderr_color);
}

pub fn stdout_style(tone: Tone) []const u8 {
    return sequence(tone, stdout_color);
}

pub fn status(tone: Tone, comptime message: []const u8, args: anytype) void {
    std.debug.print("{s}", .{style(tone)});
    std.debug.print(message, args);
    std.debug.print("{s}", .{style(.reset)});
}

test "plain output contains no styling sequences" {
    for (std.enums.values(Tone)) |tone| {
        try std.testing.expectEqualStrings("", sequence(tone, false));
    }
}

test "retro accents use the terminal palette" {
    try std.testing.expectEqualStrings("\x1b[33m", sequence(.accent, true));
    try std.testing.expectEqualStrings("\x1b[36m", sequence(.teal, true));
    try std.testing.expectEqualStrings("\x1b[37m", sequence(.text, true));
    try std.testing.expectEqualStrings("\x1b[0m", sequence(.reset, true));
}
