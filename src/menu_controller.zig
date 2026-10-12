const render_menu = @import("menu.zig").render_menu;
const MenuState = @import("menu_state.zig").MenuState;

const get_configs = @import("configs.zig").get_configs;
const get_commands = @import("install_deps.zig").get_commands;

const std = @import("std");

const Allocator = std.mem.Allocator;

const Io = std.Io;
const Dir = std.Io.Dir;
const File = std.Io.File;

fn main_menu(char: u8, state: *MenuState) void {
    switch (char) {
        '1' => state.* = MenuState.INSTALL,
        '2' => std.debug.print("git pull\n", .{}),
        '3' => std.debug.print("exit\n", .{}),
        else => std.debug.print("invalid option\n", .{}),
    }
}

pub fn event_loop(io: Io, allocator: Allocator) !void {
    const configs = try get_configs(io, allocator);
    defer allocator.free(configs);

    const install_configs = try get_commands(io, allocator);
    defer allocator.free(install_configs);

    var buffer: [1024]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().readerStreaming(io, &buffer);
    var reader = &stdin_reader.interface;
    var state: MenuState = MenuState.MAIN;
    while (true) {
        render_menu(state, configs);

        std.debug.print("> ", .{});
        const eol = try reader.takeDelimiter('\n') orelse break;
        const line = std.mem.trim(u8, eol, "\r");

        if (line.len == 0) {
            std.debug.print("exit\n", .{});
            break;
        }

        switch (state) {
            .MAIN => main_menu(line[0], &state),
            .INSTALL => main_menu(line[0], &state),
        }

        std.debug.print("line: {s}\n", .{line});
    }
}
