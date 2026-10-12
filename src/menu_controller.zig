const std = @import("std");

const Io = std.Io;
const Allocator = std.mem.Allocator;

const config_manager = @import("config_manager.zig");
const Config = config_manager.Config;
const get_configs = config_manager.get_configs;
const install_config = config_manager.install_config;
const install_configs = config_manager.install_configs;
const delete_config = config_manager.delete_config;
const delete_configs = config_manager.delete_configs;

const dependencies = @import("dependency_installer.zig");
const get_commands = dependencies.get_commands;
const free_commands = dependencies.free_commands;
const install_command = dependencies.install_command;
const install_commands = dependencies.install_commands;

const git_pull = @import("git_sync.zig").git_pull;
const render_menu = @import("menu_renderer.zig").render_menu;
const MenuState = @import("menu_state.zig").MenuState;

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

        @import("menu_renderer.zig").render_prompt();
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
