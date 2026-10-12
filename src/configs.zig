const std = @import("std");

const Io = std.Io;
const File = Io.File;
const Dir = Io.Dir;
const mem = std.mem;

const Allocator = std.mem.Allocator;

const HOME_DIR = "configs/home";
const CONFIG_DIR = "configs/configs";

const InstallLocation = enum(u8) {
    HOME,
    CONFIG,

    pub fn toString(self: InstallLocation) []const u8 {
        return switch (self) {
            .HOME => HOME_DIR,
            .CONFIG => CONFIG_DIR,
        };
    }
};

pub const Config = struct {
    name: []const u8,
    location: InstallLocation = .CONFIG,

    fn init(name: []const u8, location: InstallLocation, allocator: Allocator) !Config {
        return .{ .name = try allocator.dupe(u8, name), .location = location };
    }

    pub fn deinit(self: *Config, allocator: Allocator) void {
        self.deinit(allocator);
    }
};

fn get_home_configs(list: *std.ArrayList(Config), io: Io, allocator: Allocator) !void {
    var home_dir = try Dir.cwd().openDir(io, HOME_DIR, .{ .iterate = true });
    defer home_dir.close(io);

    var iterator: Dir.Iterator = home_dir.iterate();
    while (try iterator.next(io)) |entry| {
        if (entry.kind != .file and entry.kind != .directory) continue;
        const file_name = entry.name;

        var config: Config = try .init(file_name, .HOME, allocator);
        errdefer config.deinit(allocator);
        try list.append(allocator, config);
    }
}

fn get_config_configs(list: *std.ArrayList(Config), io: Io, allocator: Allocator) !void {
    var home_dir = try Dir.cwd().openDir(io, CONFIG_DIR, .{ .iterate = true });
    defer home_dir.close(io);

    var iterator: Dir.Iterator = home_dir.iterate();
    while (try iterator.next(io)) |entry| {
        if (entry.kind != .file and entry.kind != .directory) continue;
        const file_name = entry.name;

        var config: Config = try .init(file_name, .CONFIG, allocator);
        errdefer config.deinit(allocator);
        try list.append(allocator, config);
    }
}

pub fn get_configs(io: Io, allocator: Allocator) ![]Config {
    var configs: std.ArrayList(Config) = .empty;
    defer configs.deinit(allocator);

    errdefer {
        for (configs.items) |*config| {
            config.deinit(allocator);
        }
    }

    try get_home_configs(&configs, io, allocator);
    try get_config_configs(&configs, io, allocator);
    return configs.toOwnedSlice(allocator);
}
