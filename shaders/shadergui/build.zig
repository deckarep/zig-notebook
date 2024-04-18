const std = @import("std");
const Build = std.build;

pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "testing",
        .root_source_file = .{ .path = "main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.addObjectFile(Build.LazyPath.relative("../../lib/raylib-5.0-macos/lib/libraylib.a"));

    exe.linkFramework("CoreVideo");
    exe.linkFramework("IOKit");
    exe.linkFramework("Cocoa");
    exe.linkFramework("GLUT");
    exe.linkFramework("OpenGL");

    exe.linkSystemLibrary("c");

    const cflags = &[_][]const u8{
        "-std=c99",
        "-pedantic",
        //"-Werror",
        "-Wall",
        "-Wextra",
        "-O0", // No optimizations at all (used for debugging bruh)...later remove this.

        // RC: Some build errors are simply because compiler is too strict, need to loosen the error requirements.
        "-Wunused-parameter",
        //"-Wzero-length-array",
    };

    exe.addCSourceFile(.{
        .file = Build.LazyPath.relative("../../lib/raygui/lib/raygui_impl.c"),
        .flags = cflags,
    });

    // Raylib 5.0.
    exe.addIncludePath(Build.LazyPath.relative("../../lib/raylib-5.0-macos/include"));
    exe.addIncludePath(Build.LazyPath.relative("../../lib/raygui/include"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
