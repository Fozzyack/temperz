const std = @import("std");

const Io = std.Io;
const Allocator = std.mem.Allocator;

const config_manager = @import("config_manager.zig");
const Config = config_manager.Config;
const get_configs = config_manager.get_configs;
const install_configs = config_manager.install_configs;
const delete_configs = config_manager.delete_configs;

const dependencies = @import("dependency_installer.zig");
const get_commands = dependencies.get_commands;
const free_commands = dependencies.free_commands;
const install_command = dependencies.install_command;
const install_commands = dependencies.install_commands;

const git_pull = @import("git_sync.zig").git_pull;
const render_menu = @import("menu_renderer.zig").render_menu;
const MenuState = @import("menu_state.zig").MenuState;
const status = @import("terminal_theme.zig").status;

fn main_menu_handler(char: u8, state: *MenuState) void {
    switch (char) {
        '1' => state.* = .CONFIGS_INSTALL,
        '2' => state.* = .CONFIGS_DELETE,
        '3' => state.* = .INSTALL_DEPS,
        '4' => state.* = .GIT_PULL,
        '5' => state.* = .EXIT,
        else => status(.failure, "  [!!] Invalid option\n", .{}),
    }
}

fn config_menu_handler(line: []const u8, configs: []Config, action: config_manager.ConfigAction, reader: *Io.Reader, io: Io, allocator: Allocator) !void {
    const selected = if (line.len == 0) configs else blk: {
        const choice = std.fmt.parseInt(usize, line, 10) catch 0;
        if (choice == 0 or choice > configs.len) {
            status(.failure, "  [!!] Invalid option\n", .{});
            return;
        }
        break :blk configs[choice - 1 .. choice];
    };
    if (try config_manager.preview_configs(selected, action, io, allocator) == 0) return;

    status(.accent, "\n  Press Enter to continue, or type anything to cancel > ", .{});
    const confirmation = try reader.takeDelimiter('\n') orelse {
        status(.muted, "  [--] Cancelled (no changes made)\n", .{});
        return;
    };
    if (std.mem.trim(u8, confirmation, "\r").len != 0) {
        status(.muted, "  [--] Cancelled (no changes made)\n", .{});
        return;
    }
    switch (action) {
        .install => try install_configs(selected, io, allocator),
        .remove => try delete_configs(selected, io, allocator),
    }
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
            .CONFIGS_INSTALL, .CONFIGS_DELETE, .INSTALL_DEPS => {
                if (std.mem.eql(u8, line, "0")) {
                    state = .MAIN;
                    continue;
                }
            },
            else => {},
        }

        switch (state) {
            .MAIN => {
                if (line.len == 0) {
                    status(.muted, "  [--] Session closed\n", .{});
                    break;
                }
                main_menu_handler(line[0], &state);
            },
            .CONFIGS_INSTALL => {
                try config_menu_handler(line, configs, .install, reader, io, allocator);
                state = .MAIN;
                status(.muted, "\n  Press Enter to continue...", .{});
                _ = try reader.takeDelimiter('\n') orelse break;
            },
            .CONFIGS_DELETE => {
                try config_menu_handler(line, configs, .remove, reader, io, allocator);
                state = .MAIN;
                status(.muted, "\n  Press Enter to continue...", .{});
                _ = try reader.takeDelimiter('\n') orelse break;
            },
            .INSTALL_DEPS => {
                if (line.len == 0) {
                    install_commands(commands, io) catch |err| {
                        status(.failure, "  [!!] Installation failed: {t}\n", .{err});
                    };
                } else {
                    const choice = std.fmt.parseInt(usize, line, 10) catch 0;
                    if (choice == 0 or choice > commands.len) {
                        status(.failure, "  [!!] Invalid option\n", .{});
                    } else {
                        install_command(commands[choice - 1], io) catch |err| {
                            status(.failure, "  [!!] Installation failed: {t}\n", .{err});
                        };
                    }
                }
                state = .MAIN;
                status(.muted, "\n  Press Enter to continue...", .{});
                _ = try reader.takeDelimiter('\n') orelse break;
            },
            .GIT_PULL => {
                try git_pull(io);
                state = .MAIN;
                status(.muted, "\n  Press Enter to continue...", .{});
                _ = try reader.takeDelimiter('\n') orelse break;
            },
            else => {},
        }
    }
}
