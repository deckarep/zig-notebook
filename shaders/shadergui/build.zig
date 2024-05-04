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
        // NOTE: not sure if this interrupts building c++ dear imgui, disabling for now.
        // NOTE: When llvm is disabled, leak detection doesn't show a useful traceback.
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
    exe.linkLibCpp(); // Needed for imgui, since it's a c++ lib after all.

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

    const cppFlags = &.{
        "-fno-sanitize=undefined",
        "-std=c++11",
        "-Wno-deprecated-declarations",
        "-DNO_FONT_AWESOME",
    };

    // Resolve the 'library' dependency.
    const common_dep = b.dependency("common", .{});
    // Import the smaller 'add' and 'multiply' modules exported by the library.
    exe.root_module.addImport("common", common_dep.module("common"));

    exe.addCSourceFile(.{
        .file = .{ .path = "../../lib/raygui/lib/raygui_impl.c" },
        .flags = cflags,
    });

    // NOTE: this block is for Raylib(5.0)/Raygui
    exe.addIncludePath(.{ .path = "../../lib/raylib-5.0-macos/include" });
    exe.addIncludePath(.{ .path = "../../lib/raygui/include" });

    // Yes, all of these are required for this to work.
    // imgui (the actual c++ popular Dear ImgGUI lib)
    // cimgui (c-bindings wrapper)
    // raylib-cimgui (raylib backend)

    // NOTE: this block of includes is all for getting Dear ImgGUI to work.
    // cimgui c-bindings (comes with dear imgui as a submodule)
    exe.addIncludePath(.{ .path = "../../lib/cimgui" });
    exe.addCSourceFiles(.{
        .files = &.{
            "../../lib/cimgui/cimgui.cpp",
        },
        .flags = cppFlags,
    });

    // Adds the submodule imgui itself.
    exe.addIncludePath(.{ .path = "../../lib/cimgui/imgui" });
    exe.addCSourceFiles(.{
        .files = &.{
            "../../lib/cimgui/imgui/imgui.cpp",
            "../../lib/cimgui/imgui/imgui_demo.cpp",
            "../../lib/cimgui/imgui/imgui_draw.cpp",
            "../../lib/cimgui/imgui/imgui_tables.cpp",
            "../../lib/cimgui/imgui/imgui_widgets.cpp",
        },
        .flags = cppFlags,
    });

    // ImgGUI Raylib backend integration.
    exe.addIncludePath(.{ .path = "../../lib/raylib-cimgui" });
    exe.addCSourceFile(.{
        .file = .{ .path = "../../lib/raylib-cimgui/rlcimgui.c" },
        .flags = cflags,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
