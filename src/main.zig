const std = @import("std");

const init_log = @import("log.zig").init_log;
const event_loop = @import("menu_controller.zig").event_loop;

const configs = @import("configs.zig");
const init_home_var = @import("configs.zig").init_home_var;

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
