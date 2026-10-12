const std = @import("std");

const configs = @import("config_manager.zig");
const init_home_var = configs.init_home_var;

const init_log = @import("logger.zig").init_log;
const event_loop = @import("menu_controller.zig").event_loop;

pub fn main(init: std.process.Init) !void {
    init_log(init.io);
    const env = init.environ_map.get("HOME") orelse return error.HomeNotSet;

    try init_home_var(env, init.arena.allocator());
    defer {
        init.arena.allocator().free(configs.home_var.?);
        configs.home_var = null;
    }

    try event_loop(init.io, init.arena.allocator());
}
