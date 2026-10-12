const render_menu = @import("menu.zig").render_menu;
const MenuState = @import("menu_state.zig").MenuState;

const get_configs = @import("configs.zig").get_configs;
const install_config = @import("configs.zig").install_config;
const install_configs = @import("configs.zig").install_configs;
const delete_config = @import("configs.zig").delete_config;
const delete_configs = @import("configs.zig").delete_configs;
const get_commands = @import("install_deps.zig").get_commands;
const free_commands = @import("install_deps.zig").free_commands;
const install_command = @import("install_deps.zig").install_command;
const install_commands = @import("install_deps.zig").install_commands;
const git_pull = @import("git.zig").git_pull;

const Config = @import("configs.zig").Config;

const std = @import("std");

const Allocator = std.mem.Allocator;

const Io = std.Io;
const Dir = std.Io.Dir;
const File = std.Io.File;

fn main_menu_handler(char: u8, state: *MenuState) void {
    switch (char) {
        '1' => state.* = .CONFIGS_INSTALL,
        '2' => state.* = .CONFIGS_DELETE,
        '3' => state.* = .INSTALL_DEPS,
        '4' => state.* = .GIT_PULL,
        '5' => state.* = .EXIT,
        else => std.debug.print("invalid option\n", .{}),
    }
}

fn install_config_menu_handler(char: u8, configs: []Config, io: Io, allocator: Allocator) !void {
    const choice = char -% '0';
    if (choice == 0 or choice > configs.len) {
        std.debug.print("invalid option\n", .{});
        return;
    }

    try install_config(configs[choice - 1], io, allocator);
}

fn delete_config_menu_handler(char: u8, configs: []Config, io: Io, allocator: Allocator) !void {
    const choice = char -% '0';
    if (choice == 0 or choice > configs.len) {
        std.debug.print("invalid option\n", .{});
        return;
    }

    try delete_config(configs[choice - 1], io, allocator);
}

pub fn event_loop(io: Io, allocator: Allocator) !void {
    const configs = try get_configs(io, allocator);
    defer allocator.free(configs);

    const commands = try get_commands(io, allocator);
    defer free_commands(commands, allocator);

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
                    try install_config_menu_handler(line[0], configs, io, allocator);
                }
                state = .MAIN;
                std.debug.print("\nPress Enter to continue...", .{});
                _ = try reader.takeDelimiter('\n') orelse break;
            },
            .CONFIGS_DELETE => {
                if (line.len == 0) {
                    try delete_configs(configs, io, allocator);
                } else {
                    try delete_config_menu_handler(line[0], configs, io, allocator);
                }
                state = .MAIN;
                std.debug.print("\nPress Enter to continue...", .{});
                _ = try reader.takeDelimiter('\n') orelse break;
            },
            .INSTALL_DEPS => {
                if (line.len == 0) {
                    install_commands(commands, io) catch |err| {
                        std.debug.print("  ✗ installation failed: {t}\n", .{err});
                    };
                } else {
                    const choice = std.fmt.parseInt(usize, line, 10) catch 0;
                    if (choice == 0 or choice > commands.len) {
                        std.debug.print("invalid option\n", .{});
                    } else {
                        install_command(commands[choice - 1], io) catch |err| {
                            std.debug.print("  ✗ installation failed: {t}\n", .{err});
                        };
                    }
                }
                state = .MAIN;
                std.debug.print("\nPress Enter to continue...", .{});
                _ = try reader.takeDelimiter('\n') orelse break;
            },
            .GIT_PULL => {
                try git_pull(io);
                state = .MAIN;
                std.debug.print("\nPress Enter to continue...", .{});
                _ = try reader.takeDelimiter('\n') orelse break;
            },
            else => {},
        }
    }
}
