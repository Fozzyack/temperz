const std = @import("std");

const Io = std.Io;
const Dir = Io.Dir;
const mem = std.mem;
const Allocator = std.mem.Allocator;

const log = @import("logger.zig").log_styled;

pub const HOME_DIR = "configs/home";
pub const CONFIG_DIR = "configs/configs";
pub const VM_HOME_DIR = "vm/home";
pub const VM_CONFIG_DIR = "vm/configs";

/// Returned when the `configs/` scan cannot start because a required
/// directory is missing (as opposed to empty).
pub const ScanError = error{
    HomeDirMissing,
    ConfigDirMissing,
};

pub var home_var: ?[]u8 = null;

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
    absolute_path: []const u8,
    location: InstallLocation = .CONFIG,
    is_directory: bool = false,
    for_vm: bool = false,

    fn init(name: []const u8, location: InstallLocation, absolute_path: []const u8, is_directory: bool, allocator: Allocator) !Config {
        return .{ .name = try allocator.dupe(u8, name), .location = location, .absolute_path = try allocator.dupe(u8, absolute_path), .is_directory = is_directory };
    }

    fn set_for_vm(self: *Config) void {
        self.for_vm = true;
    }

    pub fn deinit(self: *Config, allocator: Allocator) void {
        allocator.free(self.name);
        allocator.free(self.absolute_path);
    }
};

pub fn init_home_var(home: []const u8, allocator: Allocator) !void {
    home_var = try allocator.dupe(u8, home);
}

/// Display prefix for the symlink's location, e.g. `~/` or `~/.config/`.
fn link_prefix(location: InstallLocation) []const u8 {
    return if (location == .HOME) "~/" else "~/.config/";
}

pub fn install_config(config: Config, io: Io, allocator: Allocator) !void {
    const home_str: []const u8 = home_var orelse return error.HomeNotSet;
    const location = if (config.location == .HOME) "" else ".config";

    const config_path = try std.mem.join(allocator, "/", &.{ home_str, location });
    defer allocator.free(config_path);

    if (config.location == .CONFIG) try Dir.cwd().createDirPath(io, config_path);

    const config_dir = try Dir.openDirAbsolute(io, config_path, .{ .iterate = true });
    defer config_dir.close(io);

    config_dir.symLink(io, config.absolute_path, config.name, .{ .is_directory = config.is_directory }) catch |err| {
        if (err == error.PathAlreadyExists) {
            try log(.muted, "  [--] skipped    {s}{s}  (already installed)\n", .{ link_prefix(config.location), config.name });
            return;
        }
        return err;
    };

    try log(.success, "  [OK] installed  {s}{s}  ->  {s}\n", .{ link_prefix(config.location), config.name, config.absolute_path });
}

pub fn install_configs(configs: []Config, io: Io, allocator: Allocator) !void {
    try log(.teal, "\n  [..] Installing configs...\n", .{});
    for (configs) |config| try install_config(config, io, allocator);
}

pub const ConfigAction = enum { install, remove };
const PreviewAction = enum { link, skip_existing, remove_file, remove_link, remove_directory, skip_missing };

fn preview_action(config: Config, action: ConfigAction, io: Io, allocator: Allocator) !PreviewAction {
    const home = home_var orelse return error.HomeNotSet;
    const path = try mem.join(allocator, "/", &.{ home, if (config.location == .HOME) "" else ".config" });
    defer allocator.free(path);
    const dir = Dir.openDirAbsolute(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound => return if (action == .install) .link else .skip_missing,
        else => return err,
    };
    defer dir.close(io);

    // Do not follow links: even a broken symlink occupies the destination.
    const stat = dir.statFile(io, config.name, .{ .follow_symlinks = false }) catch |err| switch (err) {
        error.FileNotFound => return if (action == .install) .link else .skip_missing,
        else => return err,
    };
    if (action == .install) return .skip_existing;
    return switch (stat.kind) {
        .directory => .remove_directory,
        .sym_link => .remove_link,
        else => .remove_file,
    };
}

/// Read-only preview. Returns the number of paths that would change.
pub fn preview_configs(configs: []const Config, action: ConfigAction, io: Io, allocator: Allocator) !usize {
    try log(.teal, "\n  [..] Dry run: {s} configs (no changes made)\n", .{if (action == .install) "install" else "remove"});
    var changes: usize = 0;
    for (configs) |config| {
        const planned = try preview_action(config, action, io, allocator);
        switch (planned) {
            .link => try log(.text, "  [..] would link    {s}{s}  ->  {s}\n", .{ link_prefix(config.location), config.name, config.absolute_path }),
            .skip_existing => try log(.muted, "  [--] would skip    {s}{s}  (already exists)\n", .{ link_prefix(config.location), config.name }),
            .skip_missing => try log(.muted, "  [--] would skip    {s}{s}  (not installed)\n", .{ link_prefix(config.location), config.name }),
            .remove_file => try log(.text, "  [..] would delete  {s}{s}  (file)\n", .{ link_prefix(config.location), config.name }),
            .remove_link => try log(.text, "  [..] would unlink  {s}{s}  (symlink; source untouched)\n", .{ link_prefix(config.location), config.name }),
            .remove_directory => try log(.failure, "  [!!] would delete  {s}{s}  (directory and ALL contents recursively)\n", .{ link_prefix(config.location), config.name }),
        }
        if (planned != .skip_existing and planned != .skip_missing) changes += 1;
    }
    if (changes == 0) try log(.muted, "  [--] Nothing to change\n", .{});
    return changes;
}

pub fn delete_config(config: Config, io: Io, allocator: Allocator) !void {
    const home_str: []const u8 = home_var orelse return error.HomeNotSet;
    const location = if (config.location == .HOME) "" else ".config";

    const config_path = try std.mem.join(allocator, "/", &.{ home_str, location });
    defer allocator.free(config_path);

    const config_dir = try Dir.openDirAbsolute(io, config_path, .{ .iterate = true });
    defer config_dir.close(io);

    config_dir.deleteFile(io, config.name) catch |err| switch (err) {
        error.IsDir => try config_dir.deleteTree(io, config.name),
        error.FileNotFound => {
            try log(.muted, "  [--] skipped    {s}{s}  (not installed)\n", .{ link_prefix(config.location), config.name });
            return;
        },
        else => return err,
    };

    try log(.success, "  [OK] removed    {s}{s}\n", .{ link_prefix(config.location), config.name });
}

pub fn delete_configs(configs: []Config, io: Io, allocator: Allocator) !void {
    try log(.teal, "\n  [..] Removing configs...\n", .{});
    for (configs) |config| try delete_config(config, io, allocator);
}

fn get_vm_configs(list: *std.ArrayList(Config), io: Io, root: Dir, allocator: Allocator) !void {
    try get_vm_configs_at(list, io, root, VM_HOME_DIR, .HOME, allocator);
    try get_vm_configs_at(list, io, root, VM_CONFIG_DIR, .CONFIG, allocator);
}

fn get_vm_configs_at(list: *std.ArrayList(Config), io: Io, root: Dir, path: []const u8, location: InstallLocation, allocator: Allocator) !void {
    var vm_dir = root.openDir(io, path, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer vm_dir.close(io);

    var iterator: Dir.Iterator = vm_dir.iterate();
    while (try iterator.next(io)) |entry| {
        if (entry.kind != .file and entry.kind != .directory) continue;

        const file_name = entry.name;
        const absolute_path = try vm_dir.realPathFileAlloc(io, file_name, allocator);
        defer allocator.free(absolute_path);
        const is_directory = entry.kind == .directory;

        var config: Config = try .init(file_name, location, absolute_path, is_directory, allocator);
        config.set_for_vm();
        errdefer config.deinit(allocator);
        try list.append(allocator, config);
    }
}

fn get_home_configs(list: *std.ArrayList(Config), io: Io, root: Dir, allocator: Allocator) !void {
    var home_dir = root.openDir(io, HOME_DIR, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return error.HomeDirMissing,
        else => return err,
    };
    defer home_dir.close(io);

    var iterator: Dir.Iterator = home_dir.iterate();
    while (try iterator.next(io)) |entry| {
        if (entry.kind != .file and entry.kind != .directory) continue;

        const file_name = entry.name;
        const absolute_path = try home_dir.realPathFileAlloc(io, file_name, allocator);
        defer allocator.free(absolute_path);
        const is_directory = entry.kind == .directory;

        var config: Config = try .init(file_name, .HOME, absolute_path, is_directory, allocator);
        errdefer config.deinit(allocator);
        try list.append(allocator, config);
    }
}

fn get_config_configs(list: *std.ArrayList(Config), io: Io, root: Dir, allocator: Allocator) !void {
    var config_dir = root.openDir(io, CONFIG_DIR, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return error.ConfigDirMissing,
        else => return err,
    };
    defer config_dir.close(io);

    var iterator: Dir.Iterator = config_dir.iterate();
    while (try iterator.next(io)) |entry| {
        if (entry.kind != .file and entry.kind != .directory) continue;

        const file_name = entry.name;
        const absolute_path = try config_dir.realPathFileAlloc(io, file_name, allocator);
        defer allocator.free(absolute_path);
        const is_directory = entry.kind == .directory;

        var config: Config = try .init(file_name, .CONFIG, absolute_path, is_directory, allocator);
        errdefer config.deinit(allocator);
        try list.append(allocator, config);
    }
}

pub fn get_configs(io: Io, allocator: Allocator) ![]Config {
    return get_configs_in(io, Dir.cwd(), allocator);
}

/// Collects regular configs and optional VM home/config directories under `root`.
/// Split out from `get_configs` so tests can point at a temporary directory tree.
fn get_configs_in(io: Io, root: Dir, allocator: Allocator) ![]Config {
    var configs: std.ArrayList(Config) = .empty;
    defer configs.deinit(allocator);

    errdefer {
        for (configs.items) |*config| {
            config.deinit(allocator);
        }
    }

    try get_vm_configs(&configs, io, root, allocator);
    try get_home_configs(&configs, io, root, allocator);
    try get_config_configs(&configs, io, root, allocator);
    return configs.toOwnedSlice(allocator);
}

const testing = std.testing;

/// Returns a borrowed subset; free only the returned slice, not its configs.
pub fn filter_configs(configs: []const Config, for_vm: bool, allocator: Allocator) ![]Config {
    var filtered: std.ArrayList(Config) = .empty;
    errdefer filtered.deinit(allocator);
    for (configs) |config| {
        if (config.for_vm == for_vm) try filtered.append(allocator, config);
    }
    return filtered.toOwnedSlice(allocator);
}

/// Frees a slice returned by `get_configs`/`get_configs_in` and the names it owns.
fn free_configs(allocator: Allocator, configs: []Config) void {
    for (configs) |*config| config.deinit(allocator);
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
    var config = try Config.init(&name, .HOME, "/source/abcd", false, testing.allocator);
    defer config.deinit(testing.allocator);

    name[0] = 'Z';

    try testing.expectEqualStrings("abcd", config.name);
    try testing.expectEqual(InstallLocation.HOME, config.location);
}

test "VM configs are marked and filtered separately from regular configs" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = testing.io;
    const allocator = testing.allocator;
    try tmp.dir.createDirPath(io, HOME_DIR);
    try tmp.dir.createDirPath(io, CONFIG_DIR);
    try tmp.dir.createDirPath(io, VM_HOME_DIR ++ "/vm-directory");
    try tmp.dir.writeFile(io, .{ .sub_path = VM_HOME_DIR ++ "/.bashrc", .data = "vm" });
    try tmp.dir.createDirPath(io, VM_CONFIG_DIR ++ "/i3");
    try tmp.dir.writeFile(io, .{ .sub_path = VM_CONFIG_DIR ++ "/i3/config", .data = "vm i3" });
    try tmp.dir.writeFile(io, .{ .sub_path = HOME_DIR ++ "/.bashrc", .data = "regular" });
    try tmp.dir.createDirPath(io, CONFIG_DIR ++ "/nvim");

    const configs = try get_configs_in(io, tmp.dir, allocator);
    defer free_configs(allocator, configs);
    const vm = try filter_configs(configs, true, allocator);
    defer allocator.free(vm);
    const regular = try filter_configs(configs, false, allocator);
    defer allocator.free(regular);
    try testing.expectEqual(@as(usize, 3), vm.len);
    try testing.expectEqual(@as(usize, 2), regular.len);
    for (vm) |config| {
        try testing.expect(config.for_vm);
        const is_i3 = mem.eql(u8, config.name, "i3");
        try testing.expectEqual(if (is_i3) InstallLocation.CONFIG else InstallLocation.HOME, config.location);
        try testing.expect(mem.indexOf(u8, config.absolute_path, if (is_i3) "/" ++ VM_CONFIG_DIR ++ "/" else "/" ++ VM_HOME_DIR ++ "/") != null);
        try testing.expectEqual(!mem.eql(u8, config.name, ".bashrc"), config.is_directory);
    }
    for (regular) |config| try testing.expect(!config.for_vm);

    const empty = try filter_configs(&.{}, true, allocator);
    defer allocator.free(empty);
    try testing.expectEqual(@as(usize, 0), empty.len);

    @import("logger.zig").init_log(io);
    const home = try tmp.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(home);
    const previous_home = home_var;
    home_var = home;
    defer home_var = previous_home;
    try tmp.dir.createDirPath(io, ".config/existing");
    try testing.expectEqual(@as(usize, 3), try preview_configs(vm, .install, io, allocator));
    try install_configs(vm, io, allocator);
    try testing.expectEqual(.sym_link, (try tmp.dir.statFile(io, ".bashrc", .{ .follow_symlinks = false })).kind);
    try testing.expectEqual(.sym_link, (try tmp.dir.statFile(io, "vm-directory", .{ .follow_symlinks = false })).kind);
    const contents = try tmp.dir.readFileAlloc(io, ".bashrc", allocator, .limited(100));
    defer allocator.free(contents);
    try testing.expectEqualStrings("vm", contents);
    try testing.expectEqual(.directory, (try tmp.dir.statFile(io, ".config", .{ .follow_symlinks = false })).kind);
    try testing.expectEqual(.sym_link, (try tmp.dir.statFile(io, ".config/i3", .{ .follow_symlinks = false })).kind);
    try testing.expectEqual(.directory, (try tmp.dir.statFile(io, ".config/existing", .{})).kind);
    const i3_contents = try tmp.dir.readFileAlloc(io, ".config/i3/config", allocator, .limited(100));
    defer allocator.free(i3_contents);
    try testing.expectEqualStrings("vm i3", i3_contents);
    try testing.expectEqual(@as(usize, 0), try preview_configs(vm, .install, io, allocator));
    try testing.expectError(error.FileNotFound, tmp.dir.statFile(io, ".config/nvim", .{}));
}

test "normal and VM installs create missing config directory without preview side effects" {
    const io = testing.io;
    const allocator = testing.allocator;
    @import("logger.zig").init_log(io);

    for ([_]bool{ false, true }) |for_vm| {
        var tmp = testing.tmpDir(.{});
        defer tmp.cleanup();
        try tmp.dir.writeFile(io, .{ .sub_path = "source", .data = "config" });
        const source = try tmp.dir.realPathFileAlloc(io, "source", allocator);
        defer allocator.free(source);
        const home = try tmp.dir.realPathFileAlloc(io, ".", allocator);
        defer allocator.free(home);
        const previous_home = home_var;
        home_var = home;
        defer home_var = previous_home;

        var configs = [_]Config{.{ .name = "app", .absolute_path = source, .for_vm = for_vm }};
        try testing.expectEqual(@as(usize, 1), try preview_configs(&configs, .install, io, allocator));
        try testing.expectEqual(@as(usize, 0), try preview_configs(&configs, .remove, io, allocator));
        try testing.expectError(error.FileNotFound, tmp.dir.statFile(io, ".config", .{}));

        try install_configs(&configs, io, allocator);
        try testing.expectEqual(.directory, (try tmp.dir.statFile(io, ".config", .{ .follow_symlinks = false })).kind);
        try testing.expectEqual(.sym_link, (try tmp.dir.statFile(io, ".config/app", .{ .follow_symlinks = false })).kind);
        const contents = try tmp.dir.readFileAlloc(io, ".config/app", allocator, .limited(100));
        defer allocator.free(contents);
        try testing.expectEqualStrings("config", contents);
        try install_configs(&configs, io, allocator);
        try testing.expectEqual(@as(usize, 0), try preview_configs(&configs, .install, io, allocator));
    }
}

test "VM home and config source directories are independently optional" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = testing.io;
    try tmp.dir.createDirPath(io, HOME_DIR);
    try tmp.dir.createDirPath(io, CONFIG_DIR);
    try tmp.dir.createDirPath(io, VM_CONFIG_DIR ++ "/i3");
    const configs = try get_configs_in(io, tmp.dir, testing.allocator);
    defer free_configs(testing.allocator, configs);
    try testing.expectEqual(@as(usize, 1), configs.len);
    try testing.expect(configs[0].for_vm);
    try testing.expectEqual(InstallLocation.CONFIG, configs[0].location);
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
        error.HomeDirMissing,
        get_configs_in(testing.io, tmp.dir, testing.allocator),
    );
}

test "get_configs_in reports each missing config directory separately" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = testing.io;

    try tmp.dir.createDirPath(io, HOME_DIR);
    try testing.expectError(
        error.ConfigDirMissing,
        get_configs_in(io, tmp.dir, testing.allocator),
    );

    try tmp.dir.createDirPath(io, CONFIG_DIR);
    const configs = try get_configs_in(io, tmp.dir, testing.allocator);
    defer free_configs(testing.allocator, configs);
    try testing.expectEqual(@as(usize, 0), configs.len);
}

test "delete_config removes files and directories without following symlinks" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = testing.io;
    const allocator = testing.allocator;
    @import("logger.zig").init_log(io);

    const home = try tmp.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(home);
    const previous_home = home_var;
    home_var = home;
    defer home_var = previous_home;

    try tmp.dir.createDirPath(io, ".config/directory/nested");
    try tmp.dir.writeFile(io, .{ .sub_path = ".config/directory/nested/config", .data = "config" });
    try tmp.dir.writeFile(io, .{ .sub_path = ".config/file", .data = "config" });
    try tmp.dir.createDirPath(io, "source");
    try tmp.dir.writeFile(io, .{ .sub_path = "source/config", .data = "keep" });
    try tmp.dir.symLink(io, "../source", ".config/link", .{ .is_directory = true });
    try tmp.dir.symLink(io, "../../source", ".config/directory/link", .{ .is_directory = true });
    try tmp.dir.symLink(io, "missing", ".config/broken", .{});
    try tmp.dir.createDirPath(io, "home-directory/nested");

    for ([_][]const u8{ "directory", "file", "link", "broken", "missing" }) |name| {
        try delete_config(.{ .name = name, .absolute_path = "unused" }, io, allocator);
        const path = try std.fmt.allocPrint(allocator, ".config/{s}", .{name});
        defer allocator.free(path);
        try testing.expectError(error.FileNotFound, tmp.dir.statFile(io, path, .{ .follow_symlinks = false }));
    }
    try delete_config(.{ .name = "home-directory", .absolute_path = "unused", .location = .HOME }, io, allocator);
    try testing.expectError(error.FileNotFound, tmp.dir.statFile(io, "home-directory", .{}));
    const contents = try tmp.dir.readFileAlloc(io, "source/config", allocator, .limited(100));
    defer allocator.free(contents);
    try testing.expectEqualStrings("keep", contents);
}

test "dry run classifies existing paths without modifying them" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = testing.io;
    const allocator = testing.allocator;
    @import("logger.zig").init_log(io);
    const home = try tmp.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(home);
    const previous_home = home_var;
    home_var = home;
    defer home_var = previous_home;

    try tmp.dir.createDirPath(io, ".config/directory/nested");
    try tmp.dir.writeFile(io, .{ .sub_path = ".config/directory/nested/config", .data = "keep" });
    try tmp.dir.writeFile(io, .{ .sub_path = ".config/file", .data = "keep" });
    try tmp.dir.symLink(io, "missing", ".config/broken", .{});
    const configs = [_]Config{
        .{ .name = "directory", .absolute_path = "/source/directory" },
        .{ .name = "file", .absolute_path = "/source/file" },
        .{ .name = "broken", .absolute_path = "/source/broken" },
        .{ .name = "missing", .absolute_path = "/source/missing" },
    };
    try testing.expectEqual(PreviewAction.skip_existing, try preview_action(configs[0], .install, io, allocator));
    try testing.expectEqual(PreviewAction.skip_existing, try preview_action(configs[2], .install, io, allocator));
    try testing.expectEqual(PreviewAction.remove_directory, try preview_action(configs[0], .remove, io, allocator));
    try testing.expectEqual(PreviewAction.remove_file, try preview_action(configs[1], .remove, io, allocator));
    try testing.expectEqual(PreviewAction.remove_link, try preview_action(configs[2], .remove, io, allocator));
    try testing.expectEqual(PreviewAction.skip_missing, try preview_action(configs[3], .remove, io, allocator));
    try testing.expectEqual(@as(usize, 1), try preview_configs(&configs, .install, io, allocator));
    try testing.expectEqual(@as(usize, 3), try preview_configs(&configs, .remove, io, allocator));
    try testing.expectEqual(@as(usize, 0), try preview_configs(configs[0..3], .install, io, allocator));
    try testing.expectEqual(@as(usize, 0), try preview_configs(&.{}, .remove, io, allocator));
    const contents = try tmp.dir.readFileAlloc(io, ".config/directory/nested/config", allocator, .limited(100));
    defer allocator.free(contents);
    try testing.expectEqualStrings("keep", contents);
    try testing.expectEqual(.sym_link, (try tmp.dir.statFile(io, ".config/broken", .{ .follow_symlinks = false })).kind);
    try testing.expectError(error.FileNotFound, tmp.dir.statFile(io, ".config/missing", .{ .follow_symlinks = false }));
}
