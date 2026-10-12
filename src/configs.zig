const std = @import("std");

const Io = std.Io;
const File = Io.File;
const Dir = Io.Dir;
const mem = std.mem;

const ArrayList = std.ArrayList;

const Allocator = std.mem.Allocator;

pub const Config = struct {
    name: []const u8,
    is_file: bool,

    pub fn init(name: []const u8, is_file: bool, allocator: Allocator) !Config {
        const self: Config = .{ .name = try allocator.dupe(u8, name), .is_file = is_file };
        return self;
    }

    pub fn deinit(self: *Config, allocator: Allocator) void {
        allocator.free(self.name);
    }
};

pub fn get_configs(io: Io, allocator: Allocator) ![]Config {
    var config_dir = try Dir.cwd().openDir(io, "configs", .{ .iterate = true });
    defer config_dir.close(io);

    var configs: std.ArrayList(Config) = .empty;
    defer configs.deinit(allocator);

    var iterator = config_dir.iterate();
    while (try iterator.next(io)) |entry| {
        if (entry.kind != .file and entry.kind != .directory) continue;

        var config: Config = try Config.init(entry.name, entry.kind == .file, allocator);
        errdefer config.deinit(allocator);

        try configs.append(
            allocator,
            config,
        );
    }

    return try configs.toOwnedSlice(allocator);
}
