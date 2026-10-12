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
        allocator.free(self.name);
    }
};

fn get_home_configs(list: *std.ArrayList(Config), io: Io, root: Dir, allocator: Allocator) !void {
    var home_dir = try root.openDir(io, HOME_DIR, .{ .iterate = true });
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

fn get_config_configs(list: *std.ArrayList(Config), io: Io, root: Dir, allocator: Allocator) !void {
    var home_dir = try root.openDir(io, CONFIG_DIR, .{ .iterate = true });
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
    return get_configs_in(io, Dir.cwd(), allocator);
}

/// Collects configs from the `HOME_DIR` and `CONFIG_DIR` subdirectories of `root`.
/// Split out from `get_configs` so tests can point at a temporary directory tree.
fn get_configs_in(io: Io, root: Dir, allocator: Allocator) ![]Config {
    var configs: std.ArrayList(Config) = .empty;
    defer configs.deinit(allocator);

    errdefer {
        for (configs.items) |*config| {
            config.deinit(allocator);
        }
    }

    try get_home_configs(&configs, io, root, allocator);
    try get_config_configs(&configs, io, root, allocator);
    return configs.toOwnedSlice(allocator);
}

const testing = std.testing;

/// Frees a slice returned by `get_configs`/`get_configs_in` and the names it owns.
fn free_configs(allocator: Allocator, configs: []Config) void {
    for (configs) |config| allocator.free(config.name);
    allocator.free(configs);
}

fn expect_config(configs: []const Config, name: []const u8, location: InstallLocation) !void {
    for (configs) |config| {
        if (mem.eql(u8, config.name, name)) {
            try testing.expectEqual(location, config.location);
            return;
        }
    }
    testing.failPrint("expected config '{s}' not found\n", .{name});
    return error.TestExpectedConfig;
}

test "InstallLocation.toString maps to the config directories" {
    try testing.expectEqualStrings(HOME_DIR, InstallLocation.HOME.toString());
    try testing.expectEqualStrings(CONFIG_DIR, InstallLocation.CONFIG.toString());
}

test "Config.init duplicates the name" {
    var name: [4]u8 = "abcd".*;
    const config = try Config.init(&name, .HOME, testing.allocator);
    defer testing.allocator.free(config.name);

    name[0] = 'Z';

    try testing.expectEqualStrings("abcd", config.name);
    try testing.expectEqual(InstallLocation.HOME, config.location);
}

test "get_configs_in collects files and directories from both roots" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = testing.io;
    try tmp.dir.createDirPath(io, HOME_DIR);
    try tmp.dir.createDirPath(io, CONFIG_DIR);

    try tmp.dir.writeFile(io, .{ .sub_path = HOME_DIR ++ "/wezterm.lua", .data = "" });
    try tmp.dir.createDirPath(io, HOME_DIR ++ "/tmux");
    try tmp.dir.createDirPath(io, CONFIG_DIR ++ "/nvim");

    const configs = try get_configs_in(io, tmp.dir, testing.allocator);
    defer free_configs(testing.allocator, configs);

    try testing.expectEqual(@as(usize, 3), configs.len);
    try expect_config(configs, "wezterm.lua", .HOME);
    try expect_config(configs, "tmux", .HOME);
    try expect_config(configs, "nvim", .CONFIG);
}

test "get_configs_in ignores entries that are neither files nor directories" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = testing.io;
    try tmp.dir.createDirPath(io, HOME_DIR);
    try tmp.dir.createDirPath(io, CONFIG_DIR);
    try tmp.dir.writeFile(io, .{ .sub_path = HOME_DIR ++ "/real", .data = "" });

    tmp.dir.symLink(io, "real", HOME_DIR ++ "/link", .{}) catch |err| switch (err) {
        error.PermissionDenied, error.AccessDenied => return error.SkipZigTest,
        else => return err,
    };

    const configs = try get_configs_in(io, tmp.dir, testing.allocator);
    defer free_configs(testing.allocator, configs);

    try testing.expectEqual(@as(usize, 1), configs.len);
    try expect_config(configs, "real", .HOME);
}

test "get_configs_in returns an empty slice when both roots are empty" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = testing.io;
    try tmp.dir.createDirPath(io, HOME_DIR);
    try tmp.dir.createDirPath(io, CONFIG_DIR);

    const configs = try get_configs_in(io, tmp.dir, testing.allocator);
    defer free_configs(testing.allocator, configs);

    try testing.expectEqual(@as(usize, 0), configs.len);
}

test "get_configs_in reports a missing root directory" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    try testing.expectError(
        error.FileNotFound,
        get_configs_in(testing.io, tmp.dir, testing.allocator),
    );
}
