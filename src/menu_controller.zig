const render_menu = @import("menu.zig").render_menu;
const MenuState = @import("menu_state.zig").MenuState;

const std = @import("std");

const Allocator = std.mem.Allocator;

const Io = std.Io;
const Dir = std.Io.Dir;
const File = std.Io.File;

pub fn event_loop(io: Io, allocator: Allocator) void {
    var buffer: [1024]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().readerStreaming(io, &buffer);
    var reader = &stdin_reader.interface;
    var state: MenuState = MenuState.MAIN;
    while (true) {
        render_menu(state);

        const eol = try reader.takeDelimiter('\n') orelse break;
        const line = std.mem.trim(u8, eol, "\r");

        if (line.len == 0) {
            std.debug.print("exit\n", .{});
            break;
        }
        switch (line[0]) {
            '1' => state = MenuState.INSTALL,
            '2' => std.debug.print("git pull\n", .{}),
            '3' => std.debug.print("exit\n", .{}),
            else => std.debug.print("invalid option\n", .{}),
        }

        std.debug.print("line: {s}\n", .{line});
    }
}
