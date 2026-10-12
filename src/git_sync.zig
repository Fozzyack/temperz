const std = @import("std");

const Io = std.Io;

const log = @import("logger.zig").log_styled;

pub fn git_pull(io: Io) !void {
    try log(.teal, "\n  [..] Pulling latest changes...\n", .{});

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
                try log(.failure, "  [!!] git pull failed\n", .{});
                return;
            }
        },
        .signal, .stopped, .unknown => {
            try log(.failure, "  [!!] git pull terminated unexpectedly\n", .{});
            return error.GitPullFailed;
        },
    }

    try log(.success, "  [OK] pull complete\n", .{});
}
