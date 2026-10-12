const std = @import("std");

const Io = std.Io;
const File = Io.File;
const Dir = Io.Dir;

const ArrayList = std.ArrayList;

const Allocator = std.mem.Allocator;

pub fn get_configs(io: Io, allocator: Allocator) ![][]u8 {
    var config_dir = try Dir.cwd().openDir(io, "configs", .{ .iterate = true });
    var walker = try config_dir.walk(allocator);

    var configs: [][]u8 = &.{};
    errdefer {
        for (configs) |config| {
            allocator.free(config);
        }
        allocator.free(configs);
    }

    while (try walker.next(io)) |entry| {
        const file_path = entry.basename;
        configs = try allocator.realloc(configs, configs.len + 1);
        configs[configs.len - 1] = allocator.dupe(u8, file_path);
    }
}
