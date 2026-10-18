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
    render_action(5, "Setup VM", "Link your VM dotfiles");
    render_action(6, "Install VM deps", "Set up your VM tools");
    render_option(7, "Exit");
}

fn render_config_menu(configs: []Config, state: MenuState) void {
    render_heading(switch (state) {
        .CONFIGS_DELETE => "Remove configs",
        .SETUP_VM => "Setup VM",
        else => "Install configs",
    }, if (state == .CONFIGS_DELETE) "Remove dotfile links from your home directory." else if (state == .SETUP_VM) "Link VM dotfiles into your home directory." else "Link dotfiles into your home directory.");
    if (configs.len == 0) std.debug.print("  No configs found.\n", .{});
    for (configs, 1..) |config, idx| {
        render_option(idx, config.name);
    }
    render_option(0, "Go back");
}

fn render_command_menu(commands: [][]u8, for_vm: bool) void {
    render_heading(if (for_vm) "Install VM deps" else "Install dependencies", if (for_vm) "Run the setup commands in configs/install-vm.config (optional)." else "Run the setup commands in configs/install.config.");
    if (commands.len == 0) std.debug.print("  No setup commands found.\n", .{});
    for (commands, 1..) |command, idx| {
        render_option(idx, command);
    }
    render_option(0, "Go back");
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
        .CONFIGS_INSTALL, .CONFIGS_DELETE, .SETUP_VM => render_config_menu(configs, state),
        .INSTALL_DEPS, .INSTALL_VM_DEPS => render_command_menu(commands, state == .INSTALL_VM_DEPS),
        .GIT_PULL => render_heading("Pull updates", "Press Enter to pull the latest repository changes."),
        .EXIT => {},
    }
    std.debug.print("\n", .{});
    render_divider();
    const hint = switch (state) {
        .MAIN => "Type a number + Enter  /  Enter to exit",
        .CONFIGS_INSTALL, .SETUP_VM, .INSTALL_DEPS, .INSTALL_VM_DEPS => "0 to go back  /  Enter to install all",
        .CONFIGS_DELETE => "0 to go back  /  Enter to remove all",
        .GIT_PULL => "Enter to continue",
        .EXIT => "Goodbye",
    };
    std.debug.print("  {s}{s}{s}\n", .{ style(.muted), hint, style(.reset) });
}
