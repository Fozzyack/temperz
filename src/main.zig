const std = @import("std");

const configs = @import("config_manager.zig");
const init_home_var = configs.init_home_var;

const dependencies = @import("dependency_installer.zig");

const init_log = @import("logger.zig").init_log;
const event_loop = @import("menu_controller.zig").event_loop;
const status = @import("terminal_theme.zig").status;

pub fn main(init: std.process.Init) !void {
    init_log(init.io);
    const term = init.environ_map.get("TERM") orelse "";
    @import("menu_renderer.zig").init(init.io, init.environ_map.get("NO_COLOR") != null, std.mem.eql(u8, term, "dumb"));
    const env = init.environ_map.get("HOME") orelse {
        report_error(error.HomeNotSet);
        std.process.exit(1);
    };

    try init_home_var(env, init.arena.allocator());
    defer {
        init.arena.allocator().free(configs.home_var.?);
        configs.home_var = null;
    }

    event_loop(init.io, init.arena.allocator()) catch |err| {
        report_error(err);
        std.process.exit(1);
    };
}

/// Describes a fatal error in one line instead of letting the Zig runtime
/// print a stack trace. Scan failures name the missing path and how to fix it.
fn report_error(err: anyerror) void {
    switch (err) {
        error.HomeDirMissing, error.ConfigDirMissing => {
            status(.failure, "\n  [!!] Cannot find {s}\n", .{if (err == error.HomeDirMissing) configs.HOME_DIR else configs.CONFIG_DIR});
            status(.muted, "       Create both {s}/ and {s}/, then run temperz from that directory.\n", .{ configs.HOME_DIR, configs.CONFIG_DIR });
            status(.muted, "       See README.md - \"Where to put configs\".\n", .{});
        },
        error.InstallFileMissing => {
            status(.failure, "\n  [!!] Cannot find {s}\n", .{dependencies.INSTALL_FILE});
            status(.muted, "       Add one install command per line, or create an empty file.\n", .{});
        },
        error.HomeNotSet => status(.failure, "\n  [!!] HOME is not set\n", .{}),
        else => status(.failure, "\n  [!!] temperz failed: {s}\n", .{@errorName(err)}),
    }
}
