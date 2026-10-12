const std = @import("std");
const init_log = @import("log.zig").init_log;

pub fn main(init: std.process.Init) !void {
    init_log(init.io);
}
