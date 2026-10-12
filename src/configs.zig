const std = @import("std");

const Io = std.Io;
const File = Io.File;
const Dir = Io.Dir;
const mem = std.mem;

const Allocator = std.mem.Allocator;

pub fn get_configs(io: Io, allocator: Allocator) ![]Config {}
