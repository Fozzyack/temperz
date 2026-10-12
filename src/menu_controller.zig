const render_menu = @import("menu.zig").render_menu;
const MenuState = @import("menu_state.zig").MenuState;

const get_configs = @import("configs.zig").get_configs;
const get_commands = @import("install_deps.zig").get_commands;

const Config = @import("configs.zig").Config;

const std = @import("std");

const Allocator = std.mem.Allocator;

const Io = std.Io;
const Dir = std.Io.Dir;
const File = std.Io.File;

fn main_menu_handler(char: u8, state: *MenuState) void {
    switch (char) {
        '1' => state.* = .CONFIGS,
        '2' => state.* = .INSTALL,
        '3' => state.* = .GIT,
        '4' => state.* = .EXIT,
        else => std.debug.print("invalid option\n", .{}),
    }
}

pub fn event_loop(io: Io, allocator: Allocator) !void {
    const configs = try get_configs(io, allocator);
    defer allocator.free(configs);

    const commands = try get_commands(io, allocator);
    defer allocator.free(commands);

    var buffer: [1024]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().readerStreaming(io, &buffer);
    var reader = &stdin_reader.interface;
    var state: MenuState = .MAIN;
    while (true) {
        if (state == .EXIT) break;

        render_menu(state, configs, commands);

        std.debug.print("> ", .{});
        const eol = try reader.takeDelimiter('\n') orelse break;
        const line = std.mem.trim(u8, eol, "\r");

        switch (state) {
            .MAIN => {
                if (line.len == 0) {
                    std.debug.print("exit\n", .{});
                    break;
                }
                main_menu_handler(line[0], &state);
            },
            .CONFIGS => {
                config: {
                    if (line.len == 0) {
                        std.debug.print("Installing all dots\n", .{});
                        break :config;
                    }
                    // config_menu_handler(line[0], &state);
                }
            },
            else => {},
        }

        std.debug.print("line: {s}\n", .{line});
    }
}
