const std = @import("std");
const c = @import("c_defs.zig").c;
const zeco = @import("zeco.zig");
const classic = @import("classic_delicious.zig");
const tacular = @import("coro_tacular.zig");
const mation = @import("coromation.zig");

const Bunny = @import("bunny.zig").Bunny;

const MAX_BUNNIES = 100_000;
const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 450;
const BUNNY_BARF_COUNT = 1;

var texBunny: c.Texture = undefined;

const Style = enum {
    ClassicDelicious,
    CoroTacular,
    Coromation,
};

// Change this variable to one of the enum type above.
const RunStyle = .CoroTacular;

pub fn main() !void {
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    std.debug.print("Ziggified coro implementation by @deckarep\n", .{});
    std.debug.print("Original c implementation by @raysan5\n", .{});

    std.debug.print("@sizeOf(Bunny): {d}, @alignOf(Bunny): {d}\n", .{ @sizeOf(Bunny), @alignOf(Bunny) });

    c.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib vanilla bunnymark");
    defer c.CloseWindow();
    c.SetTargetFPS(60);

    texBunny = c.LoadTexture("resources/textures/wabbit_alpha.png");
    defer c.UnloadTexture(texBunny);

    switch (RunStyle) {
        .ClassicDelicious => classic.bunnymark(MAX_BUNNIES, BUNNY_BARF_COUNT, texBunny),
        .CoroTacular => tacular.bunnymark(texBunny),
        .Coromation => mation.coromation(texBunny),
        else => {},
    }

    std.debug.print("bunnymark terminated.\n", .{});
}
