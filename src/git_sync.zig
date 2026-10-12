const std = @import("std");

const Io = std.Io;

const log = @import("logger.zig").log;

pub fn git_pull(io: Io) !void {
    try log("Pulling Lateset Changes\n", .{});

    var child = try std.process.spawn(io, .{
        .argv = &.{ "git", "pull" },
        .stdin = .inherit,
        .stderr = .inherit,
        .stdout = .inherit,
    });

    const term = try child.wait(io);
    switch (term) {
        .exited => |code| {
            if (code != 0) {
                try log("  • git pull failed\n", .{});
                return;
            }
        },
        .signal, .stopped, .unknown => {
            try log("  • git pull terminated unexpectedly\n", .{});
            return error.GitPullFailed;
        },
    }

    try log("  ✓ pull complete\n", .{});
}
