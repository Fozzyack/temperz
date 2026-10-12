const MenuState = @import("menu_state.zig").MenuState;
const Config = @import("configs.zig").Config;

const std = @import("std");
const Io = std.Io;

fn render_title() void {
    const title =
        " ████████╗███████╗███╗   ███╗██████╗ ███████╗██████╗ ███████╗\n" ++
        " ╚══██╔══╝██╔════╝████╗ ████║██╔══██╗██╔════╝██╔══██╗╚══███╔╝\n" ++
        "    ██║   █████╗  ██╔████╔██║██████╔╝█████╗  ██████╔╝  ███╔╝ \n" ++
        "    ██║   ██╔══╝  ██║╚██╔╝██║██╔═══╝ ██╔══╝  ██╔══██╗ ███╔╝  \n" ++
        "    ██║   ███████╗██║ ╚═╝ ██║██║     ███████╗██║  ██║███████╗\n" ++
        "    ╚═╝   ╚══════╝╚═╝     ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝╚══════╝\n";
    std.debug.print("{s}\n", .{title});
}

fn render_divider() void {
    std.debug.print(" ========================================================== \n", .{});
}
fn clear_screan() void {
    std.debug.print("\x1b[2J\x1b[H\n\n", .{});
}

fn render_main_options() void {
    std.debug.print(" Options\n", .{});
    std.debug.print(" [1] Install Configs\n", .{});
    std.debug.print(" [2] Remove Configs\n", .{});
    std.debug.print(" [3] Install Deps\n", .{});
    std.debug.print(" [4] Git Pull\n", .{});
    std.debug.print(" [5] Exit\n", .{});
}

fn render_config_menu(configs: []Config, is_delete: bool) void {
    if (is_delete) std.debug.print(" Delete Configs", .{}) else std.debug.print(" Install Configs", .{});
    std.debug.print(" Options\n", .{});
    for (configs, 1..) |config, idx| {
        std.debug.print(" [{d}]: {s}\n", .{ idx, config.name });
    }
    if (is_delete) std.debug.print(" Leave blank to delete all\n", .{}) else std.debug.print(" Leave blank to install all\n", .{});
}

fn render_command_menu(commands: [][]u8) void {
    std.debug.print(" Options\n", .{});
    for (commands, 1..) |command, idx| {
        std.debug.print(" [{d}]: {s}\n", .{ idx, command });
    }
    std.debug.print(" Leave blank to install all\n", .{});
}

pub fn render_menu(state: MenuState, configs: []Config, commands: [][]u8) void {
    clear_screan();
    render_title();
    render_divider();
    switch (state) {
        .MAIN => render_main_options(),
        .CONFIGS_INSTALL => render_config_menu(configs, false),
        .CONFIGS_DELETE => render_config_menu(configs, true),
        .INSTALL => render_command_menu(commands),
        else => std.debug.print("invalid state\n", .{}),
    }
    render_divider();
}
