const render_menu = @import("menu.zig").render_menu;
const MenuState = @import("menu_state.zig").MenuState;

const get_configs = @import("configs.zig").get_configs;
const install_config = @import("configs.zig").install_config;
const install_configs = @import("configs.zig").install_configs;
const get_commands = @import("install_deps.zig").get_commands;

const Config = @import("configs.zig").Config;
const log = @import("log.zig").log;

const std = @import("std");

const Allocator = std.mem.Allocator;

const Io = std.Io;
const Dir = std.Io.Dir;
const File = std.Io.File;

fn main_menu_handler(char: u8, state: *MenuState) void {
    switch (char) {
        '1' => state.* = .CONFIGS_INSTALL,
        '2' => state.* = .INSTALL,
        '3' => state.* = .GIT,
        '4' => state.* = .EXIT,
        else => std.debug.print("invalid option\n", .{}),
    }
}

fn config_menu_handler(char: u8, configs: []Config, io: Io, allocator: Allocator) !void {
    const choice = char - '0';
    if (choice > configs.len) {
        std.debug.print("invalid option\n", .{});
        return;
    }

    install_config(configs[choice - 1], io, allocator) catch |err| {
        if (err == error.PathAlreadyExists) try log("Config Already Installed\n", .{});
    };
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
            .CONFIGS_INSTALL => {
                if (line.len == 0) {
                    try install_configs(configs, io, allocator);
                } else {
                    config_menu_handler(line[0], configs, io, allocator) catch |err| {
                        if (err == error.PathAlreadyExists) try log("Config Already Installed\n", .{});
                    };
                }
                state = .MAIN;
                _ = try reader.takeDelimiter('\n') orelse break;
            },
            else => {},
        }
    }
}
