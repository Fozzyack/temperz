const std = @import("std");

const Config = @import("config_manager.zig").Config;
const MenuState = @import("menu_state.zig").MenuState;

const theme = @import("terminal_theme.zig");
const style = theme.style;

pub fn init(io: std.Io, no_color: bool, dumb_terminal: bool) void {
    theme.init(io, no_color, dumb_terminal);
}

fn render_title() void {
    std.debug.print("\n  {s}[ temperz ]{s}  {s}DEV ENVIRONMENT / CONTROL PANEL{s}\n", .{ style(.accent), style(.reset), style(.muted), style(.reset) });
    std.debug.print("  {s}Your tools. Your dotfiles. One place.{s}\n\n", .{ style(.text), style(.reset) });
}

fn render_divider() void {
    std.debug.print("  {s}+--------------------------------------------------+{s}\n", .{ style(.teal), style(.reset) });
}

fn render_heading(title: []const u8, description: []const u8) void {
    std.debug.print("\n  {s}{s}{s}\n  {s}{s}{s}\n\n", .{
        style(.heading), title,       style(.reset),
        style(.muted),   description, style(.reset),
    });
}

fn render_option(index: usize, label: []const u8) void {
    std.debug.print("  {s}[{d}]{s}  {s}{s}{s}\n", .{ style(.accent), index, style(.reset), style(.text), label, style(.reset) });
}

fn render_action(index: usize, label: []const u8, description: []const u8) void {
    std.debug.print("  {s}[{d}]{s}  {s}{s: <21}{s} {s}{s}{s}\n", .{
        style(.accent), index,       style(.reset),
        style(.text),   label,       style(.reset),
        style(.muted),  description, style(.reset),
    });
}

fn render_main_options() void {
    render_heading("What would you like to do?", "Choose an action to get started.");
    render_action(1, "Install configs", "Link your dotfiles");
    render_action(2, "Remove configs", "Unlink your dotfiles");
    render_action(3, "Install dependencies", "Set up your dev tools");
    render_action(4, "Pull updates", "Sync this repository");
    render_option(5, "Exit");
}

fn render_config_menu(configs: []Config, is_delete: bool) void {
    render_heading(if (is_delete) "Remove configs" else "Install configs", if (is_delete) "Remove dotfile links from your home directory." else "Link dotfiles into your home directory.");
    if (configs.len == 0) std.debug.print("  No configs found.\n", .{});
    for (configs, 1..) |config, idx| {
        render_option(idx, config.name);
    }
}

fn render_command_menu(commands: [][]u8) void {
    render_heading("Install dependencies", "Run the setup commands in configs/install.config.");
    if (commands.len == 0) std.debug.print("  No setup commands found.\n", .{});
    for (commands, 1..) |command, idx| {
        render_option(idx, command);
    }
}

pub fn render_prompt() void {
    std.debug.print("\n  {s}READY >{s} ", .{ style(.accent), style(.reset) });
}

pub fn render_menu(state: MenuState, configs: []Config, commands: [][]u8) void {
    if (theme.interactive) std.debug.print("\x1b[2J\x1b[H", .{});
    render_title();
    render_divider();
    switch (state) {
        .MAIN => render_main_options(),
        .CONFIGS_INSTALL => render_config_menu(configs, false),
        .CONFIGS_DELETE => render_config_menu(configs, true),
        .INSTALL_DEPS => render_command_menu(commands),
        .GIT_PULL => render_heading("Pull updates", "Press Enter to pull the latest repository changes."),
        .EXIT => {},
    }
    std.debug.print("\n", .{});
    render_divider();
    const hint = switch (state) {
        .MAIN => "Type a number + Enter  /  Enter to exit",
        .CONFIGS_INSTALL, .INSTALL_DEPS => "Type a number + Enter  /  Enter to install all",
        .CONFIGS_DELETE => "Type a number + Enter  /  Enter to remove all",
        .GIT_PULL => "Enter to continue",
        .EXIT => "Goodbye",
    };
    std.debug.print("  {s}{s}{s}\n", .{ style(.muted), hint, style(.reset) });
}
