// library/build.zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    //  Note:
    // 'b.createModule()' creates a private module.
    // 'b.addModule()' creates a public module that can be imported by other build scripts.

    // Smaller modules that can be imported individually:
    const circBufMod = b.addModule("circBuf", .{
        .root_source_file = .{ .path = "circle_buffer.zig" },
    });

    // One big module that imports and re-exports the smaller modules:
    const common_mod = b.addModule("common", .{
        .root_source_file = .{ .path = "common.zig" },
        .imports = &.{
            .{ .name = "circBuf", .module = circBufMod },
        },
    });

    _ = common_mod;
}
