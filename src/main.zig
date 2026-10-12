const std = @import("std");
const init_log = @import("log.zig").init_log;
const log = @import("log.zig").log;
const render_menu = @import("menu.zig").render_menu;
const Config = @import("configs.zig").Config;
const get_configs = @import("configs.zig").get_configs;

pub fn main(init: std.process.Init) !void {
    init_log(init.io);

    const configs: []Config = try get_configs(init.io, init.arena.allocator());
    defer init.arena.allocator().free(configs);
    for (configs) |*config| {
        std.debug.print("{s}\n", .{config.*.name});
    }

    // render_menu();
}
