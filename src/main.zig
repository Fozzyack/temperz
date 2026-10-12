const std = @import("std");
const init_log = @import("log.zig").init_log;
const event_loop = @import("menu_controller.zig").event_loop;

pub fn main(init: std.process.Init) !void {
    init_log(init.io);
    try event_loop(init.io, init.arena.allocator());
}
