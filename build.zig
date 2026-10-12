const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const exe = b.addExecutable(.{
        .name = "temperz",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
        }),
    });

    b.installArtifact(exe);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/config_manager.zig"),
            .target = b.graph.host,
        }),
    });
    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
    const theme_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/terminal_theme.zig"),
            .target = b.graph.host,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(theme_tests).step);
}
