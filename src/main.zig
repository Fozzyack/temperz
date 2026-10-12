const std = @import("std");
const init_log = @import("log.zig").init_log;
const log = @import("log.zig").log;
const render_menu = @import("menu.zig").render_menu;
const Config = @import("configs.zig").Config;
const get_configs = @import("configs.zig").get_configs;
const get_commands = @import("install_deps.zig").get_commands;

pub fn main(init: std.process.Init) !void {
    init_log(init.io);

    var allocator = init.arena.allocator();

    const configs = try get_configs(init.io, allocator);
    defer init.arena.allocator().free(configs);

    for (configs) |config| {
        std.debug.print("config: {s} dir: {s}\n", .{ config.name, config.location.toString() });
    }

    const commands = try get_commands(init.io, allocator);
    defer allocator.free(commands);

    for (commands) |command| {
        std.debug.print("command: {s}", .{command});
    }

    // render_menu();
}
