const std = @import("std");

const Io = std.Io;
const Dir = std.Io.Dir;
const File = std.Io.File;

const mem = std.mem;

const Allocator = std.mem.Allocator;

const BUFFER_SIZE: usize = 4096;
const INSTALL_FILE = "configs/install.config";

pub fn get_commands(io: Io, allocator: Allocator) ![][]u8 {
    const file = try Dir.cwd().openFile(io, INSTALL_FILE, .{});
    defer file.close(io);

    var commands: [][]u8 = &.{};
    errdefer {
        for (commands) |command| {
            allocator.free(command);
        }
        allocator.free(commands);
    }

    var read_buffer: [BUFFER_SIZE]u8 = undefined;
    var offset: usize = 0;
    var used: usize = 0;

    while (true) {
        const bytes_read: usize = try file.readPositionalAll(io, read_buffer[used..], offset);
        if (bytes_read == 0) {
            break;
        }

        offset += bytes_read;
        used += bytes_read;

        while (true) {
            const idx = mem.findScalar(u8, read_buffer[0..used], '\n') orelse break;
            const command = read_buffer[0..idx];

            commands = try allocator.realloc(commands, commands.len + 1);
            commands[commands.len - 1] = try allocator.dupe(u8, command);

            const consumed: usize = idx + 1;
            const remaining: usize = used - consumed;

            @memmove(read_buffer[0..remaining], read_buffer[consumed..used]);
            used = remaining;
        }
    }

    return commands;
}
