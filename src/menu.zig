const std = @import("std");
const MenuState = @import("menu_state.zig").MenuState;

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
    std.debug.print(" [1] Install Dotfiles\n", .{});
    std.debug.print(" [2] Git Pull\n", .{});
    std.debug.print(" [3] Exit\n", .{});
}

fn render_install_menu() void {}

pub fn render_menu(state: MenuState) void {
    clear_screan();
    render_title();
    render_divider();
    switch (state) {
        .MAIN => render_main_options(),
        .INSTALL => render_install_menu(),
    }
}
