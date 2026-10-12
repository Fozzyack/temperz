const std = @import("std");

const Config = @import("config_manager.zig").Config;
const MenuState = @import("menu_state.zig").MenuState;

var terminal = false;
var color = false;

pub fn init(io: std.Io, no_color: bool, dumb_terminal: bool) void {
    terminal = !dumb_terminal and (std.Io.File.stderr().isTty(io) catch false);
    color = terminal and !no_color;
}

fn style(sequence: []const u8) []const u8 {
    return if (color) sequence else "";
}

fn render_title() void {
    std.debug.print("\n  {s}temperz{s}  /  dev environment\n", .{ style("\x1b[1;36m"), style("\x1b[0m") });
    std.debug.print("  {s}Your tools. Your dotfiles. One place.{s}\n\n", .{ style("\x1b[2m"), style("\x1b[0m") });
}

fn render_divider() void {
    std.debug.print("  {s}----------------------------------------------------{s}\n", .{ style("\x1b[2m"), style("\x1b[0m") });
}

fn render_heading(title: []const u8, description: []const u8) void {
    std.debug.print("\n  {s}{s}{s}\n  {s}{s}{s}\n\n", .{
        style("\x1b[1m"), title,       style("\x1b[0m"),
        style("\x1b[2m"), description, style("\x1b[0m"),
    });
}

fn render_option(index: usize, label: []const u8) void {
    std.debug.print("  {s}[{d}]{s}  {s}\n", .{ style("\x1b[36m"), index, style("\x1b[0m"), label });
}

fn render_main_options() void {
    render_heading("What would you like to do?", "Choose an action to get started.");
    render_option(1, "Install configs       Link your dotfiles");
    render_option(2, "Remove configs        Unlink your dotfiles");
    render_option(3, "Install dependencies  Set up your dev tools");
    render_option(4, "Pull updates          Sync this repository");
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
    std.debug.print("\n  {s}>{s} ", .{ style("\x1b[36m"), style("\x1b[0m") });
}

pub fn render_menu(state: MenuState, configs: []Config, commands: [][]u8) void {
    if (terminal) std.debug.print("\x1b[2J\x1b[H", .{});
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
    std.debug.print("  {s}{s}{s}\n", .{ style("\x1b[2m"), hint, style("\x1b[0m") });
}
