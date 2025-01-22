const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const mqtt = b.addModule("mqtt", .{
        .root_source_file = b.path("src/mqtt.zig"),
        .target = target,
        .optimize = optimize,
    });

    _ = mqtt;

    // Restore when server works
    //b.installArtifact(mqtt);
    //const run_cmd = b.addRunArtifact(mqtt);
    //run_cmd.step.dependOn(b.getInstallStep());

    //if (b.args) |args| {
    //    run_cmd.addArgs(args);
    //}

    //const run_step = b.step("run", "Run the app");
    //run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/mqtt.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
