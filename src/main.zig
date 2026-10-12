const std = @import("std");
const init_log = @import("log.zig").init_log;
const log = @import("log.zig").log;
const render_menu = @import("menu.zig").render_menu;
const Config = @import("configs.zig").Config;
const get_configs = @import("configs.zig").get_configs;

pub fn main(init: std.process.Init) !void {
    init_log(init.io);

    // render_menu();
}
