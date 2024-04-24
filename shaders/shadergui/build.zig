const std = @import("std");

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
        // These two bools, disable llvm/lld and use the faster debug builder.
        // To see this enabled must pass Debug flag: zig build run -Doptimize=Debug
        .use_llvm = false,
        .use_lld = false,
    });

    exe.addObjectFile(.{ .path = "../../lib/raylib-5.0-macos/lib/libraylib.a" });

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

    // Resolve the 'library' dependency.
    const common_dep = b.dependency("common", .{});
    // Import the smaller 'add' and 'multiply' modules exported by the library.
    exe.root_module.addImport("common", common_dep.module("common"));

    // const circBufMod = b.addModule("circBuf", .{
    //     .root_source_file = .{ .path = "../../common/circle_buffer.zig" },
    // });

    // // One big module that imports and re-exports the smaller modules:
    // const commonMod = b.addModule("common", .{
    //     .root_source_file = .{ .path = "../../common/common.zig" },
    //     .imports = &.{
    //         .{ .name = "circBuf", .module = circBufMod },
    //     },
    // });
    // const multiply_mod = b.addModule("multiply", .{
    //     .root_source_file = .{ .path = "multiply.zig" },
    // });

    // // One big module that imports and re-exports the smaller modules:
    // const library_mod = b.addModule("library", .{
    //     .root_source_file = .{ .path = "library.zig" },
    //     .imports = &.{
    //         .{ .name = "add", .module = add_mod },
    //         .{ .name = "multiply", .module = multiply_mod },
    //     },
    // });

    exe.addCSourceFile(.{
        .file = .{ .path = "../../lib/raygui/lib/raygui_impl.c" },
        .flags = cflags,
    });

    // Raylib 5.0.
    exe.addIncludePath(.{ .path = "../../lib/raylib-5.0-macos/include" });
    exe.addIncludePath(.{ .path = "../../lib/raygui/include" });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
