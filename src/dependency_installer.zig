const std = @import("std");

const Io = std.Io;
const Dir = Io.Dir;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const status = @import("terminal_theme.zig").status;

const BUFFER_SIZE: usize = 4096;
pub const INSTALL_FILE = "configs/install.config";
pub const VM_INSTALL_FILE = "configs/install-vm.config";

/// Returned when `configs/install.config` does not exist.
pub const ScanError = error{InstallFileMissing};

pub fn get_commands(io: Io, allocator: Allocator) ![][]u8 {
    return get_commands_in(Dir.cwd(), io, allocator);
}

pub fn get_vm_commands(io: Io, allocator: Allocator) ![][]u8 {
    return get_vm_commands_in(Dir.cwd(), io, allocator);
}

fn get_vm_commands_in(root: Dir, io: Io, allocator: Allocator) ![][]u8 {
    return read_commands_in(root, VM_INSTALL_FILE, io, allocator) catch |err| switch (err) {
        error.FileNotFound => try allocator.alloc([]u8, 0),
        else => return err,
    };
}

/// Executes a trusted shell command, keeping package-manager prompts interactive.
/// Never pass untrusted input: `sh -c` permits arbitrary shell commands.
pub fn install_command(command: []const u8, io: Io) !void {
    const trimmed = mem.trim(u8, command, " \t\r\n");
    if (trimmed.len == 0) return error.EmptyCommand;

    status(.accent, "\n  [..] {s}\n", .{trimmed});
    var child = try std.process.spawn(io, .{
        .argv = &.{ "sh", "-c", trimmed },
        .stdin = .inherit,
        .stdout = .inherit,
        .stderr = .inherit,
    });

    try check_term(try child.wait(io));
    status(.success, "  [OK] completed\n", .{});
}

/// Installs in file order, stopping at the first failure.
pub fn install_commands(commands: [][]u8, io: Io) !void {
    status(.teal, "\n  [..] Installing dependencies...\n", .{});
    for (commands) |command| try install_command(command, io);
}

fn check_term(term: std.process.Child.Term) !void {
    switch (term) {
        .exited => |code| if (code != 0) return error.DependencyInstallFailed,
        .signal, .stopped, .unknown => return error.DependencyInstallFailed,
    }
}

/// Frees the command strings and their containing slice.
pub fn free_commands(commands: [][]u8, allocator: Allocator) void {
    for (commands) |command| allocator.free(command);
    allocator.free(commands);
}

fn get_commands_in(root: Dir, io: Io, allocator: Allocator) ![][]u8 {
    return read_commands_in(root, INSTALL_FILE, io, allocator) catch |err| switch (err) {
        error.FileNotFound => return error.InstallFileMissing,
        else => return err,
    };
}

fn read_commands_in(root: Dir, path: []const u8, io: Io, allocator: Allocator) ![][]u8 {
    const file = try root.openFile(io, path, .{});
    defer file.close(io);

    var commands: std.ArrayList([]u8) = .empty;
    defer commands.deinit(allocator);
    errdefer {
        for (commands.items) |command| allocator.free(command);
    }

    var pending: std.ArrayList(u8) = .empty;
    defer pending.deinit(allocator);
    var read_buffer: [BUFFER_SIZE]u8 = undefined;
    var offset: u64 = 0;

    while (true) {
        const bytes_read = try file.readPositionalAll(io, &read_buffer, offset);
        if (bytes_read == 0) break;
        offset += bytes_read;

        var start: usize = 0;
        for (read_buffer[0..bytes_read], 0..) |byte, index| {
            if (byte != '\n') continue;
            try pending.appendSlice(allocator, read_buffer[start..index]);
            try append_command(&commands, pending.items, allocator);
            pending.clearRetainingCapacity();
            start = index + 1;
        }
        try pending.appendSlice(allocator, read_buffer[start..bytes_read]);
    }

    try append_command(&commands, pending.items, allocator);
    return commands.toOwnedSlice(allocator);
}

fn append_command(commands: *std.ArrayList([]u8), line: []const u8, allocator: Allocator) !void {
    const trimmed = mem.trim(u8, line, " \t\r");
    if (trimmed.len == 0) return;
    const command = try allocator.dupe(u8, trimmed);
    errdefer allocator.free(command);
    try commands.append(allocator, command);
}

test "get_commands trims whitespace, skips blanks, and includes the final line" {
    const testing = std.testing;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "configs");
    try tmp.dir.writeFile(testing.io, .{
        .sub_path = INSTALL_FILE,
        .data = "  paru -S neovim \r\n\n\t \r\n\tparu -S tmux\t",
    });

    const commands = try get_commands_in(tmp.dir, testing.io, testing.allocator);
    defer free_commands(commands, testing.allocator);
    try testing.expectEqual(@as(usize, 2), commands.len);
    try testing.expectEqualStrings("paru -S neovim", commands[0]);
    try testing.expectEqualStrings("paru -S tmux", commands[1]);
}

test "get_commands handles lines spanning multiple read buffers" {
    const testing = std.testing;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "configs");
    var long_line: [BUFFER_SIZE * 2 + 1]u8 = undefined;
    @memset(&long_line, 'x');
    const data = try mem.concat(testing.allocator, u8, &.{ &long_line, "\nnext\n" });
    defer testing.allocator.free(data);
    try tmp.dir.writeFile(testing.io, .{
        .sub_path = INSTALL_FILE,
        .data = data,
    });

    const commands = try get_commands_in(tmp.dir, testing.io, testing.allocator);
    defer free_commands(commands, testing.allocator);
    try testing.expectEqual(@as(usize, 2), commands.len);
    try testing.expectEqualStrings(&long_line, commands[0]);
    try testing.expectEqualStrings("next", commands[1]);
}

test "get_commands returns an empty slice for an empty file" {
    const testing = std.testing;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "configs");
    try tmp.dir.writeFile(testing.io, .{ .sub_path = INSTALL_FILE, .data = "" });
    const commands = try get_commands_in(tmp.dir, testing.io, testing.allocator);
    defer free_commands(commands, testing.allocator);
    try testing.expectEqual(@as(usize, 0), commands.len);
}

test "get_commands reports a missing install file" {
    const testing = std.testing;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "configs");
    try testing.expectError(
        error.InstallFileMissing,
        get_commands_in(tmp.dir, testing.io, testing.allocator),
    );
}

test "check_term accepts only successful exits" {
    try check_term(.{ .exited = 0 });
    try std.testing.expectError(error.DependencyInstallFailed, check_term(.{ .exited = 1 }));
    try std.testing.expectError(error.DependencyInstallFailed, check_term(.{ .signal = .TERM }));
    try std.testing.expectError(error.DependencyInstallFailed, check_term(.{ .stopped = .STOP }));
    try std.testing.expectError(error.DependencyInstallFailed, check_term(.{ .unknown = 1 }));
}

test "VM commands use a separate optional file and the same parsing rules" {
    const testing = std.testing;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const missing = try get_vm_commands_in(tmp.dir, testing.io, testing.allocator);
    defer free_commands(missing, testing.allocator);
    try testing.expectEqual(@as(usize, 0), missing.len);

    try tmp.dir.createDirPath(testing.io, "configs");
    try tmp.dir.writeFile(testing.io, .{ .sub_path = INSTALL_FILE, .data = "regular-command\n" });
    try tmp.dir.writeFile(testing.io, .{
        .sub_path = VM_INSTALL_FILE,
        .data = "  vm-command-one \r\n\n\t \r\n\tvm-command-two\t",
    });
    const commands = try get_vm_commands_in(tmp.dir, testing.io, testing.allocator);
    defer free_commands(commands, testing.allocator);
    try testing.expectEqual(@as(usize, 2), commands.len);
    try testing.expectEqualStrings("vm-command-one", commands[0]);
    try testing.expectEqualStrings("vm-command-two", commands[1]);
    const regular = try get_commands_in(tmp.dir, testing.io, testing.allocator);
    defer free_commands(regular, testing.allocator);
    try testing.expectEqual(@as(usize, 1), regular.len);
    try testing.expectEqualStrings("regular-command", regular[0]);

    try tmp.dir.writeFile(testing.io, .{ .sub_path = VM_INSTALL_FILE, .data = "" });
    const empty = try get_vm_commands_in(tmp.dir, testing.io, testing.allocator);
    defer free_commands(empty, testing.allocator);
    try testing.expectEqual(@as(usize, 0), empty.len);
}

test "install_command rejects blank input without spawning a process" {
    try std.testing.expectError(error.EmptyCommand, install_command(" \t\r\n", std.testing.io));
}
