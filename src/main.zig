const std = @import("std");
const init_log = @import("log.zig").init_log;
const log = @import("log.zig").log;
const render_menu = @import("menu.zig").render_menu;

pub fn main(init: std.process.Init) !void {
    init_log(init.io);
    render_menu();
}
