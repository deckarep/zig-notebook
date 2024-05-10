const std = @import("std");
const c = @import("c_defs.zig").c;
const Bunny = @import("bunny.zig").Bunny;

// This is the maximum amount of elements (quads) per batch
// NOTE: This value is defined in [rlgl] module and can be changed there
const MAX_BATCH_ELEMENTS = 8192;

// Vanilla is just the normal style Bunnymark of one update loop followed by one render pass.
// No magic really, this is the canonical way a game loop is made and the most cache friendly.
pub fn bunnymark(comptime maxBunnies: comptime_int, comptime barfCount: comptime_int, texBunny: c.Texture) void {
    const SCREEN_WIDTH = c.GetScreenWidth();
    const SCREEN_HEIGHT = c.GetScreenHeight();

    // Stack alloc'd bunnies array.
    var bunnies: [maxBunnies]Bunny = undefined;
    var bunniesCount: usize = 0;

    while (!c.WindowShouldClose()) {
        //----------------------------------------------------------------------------------
        // Update
        //----------------------------------------------------------------------------------
        if (c.IsMouseButtonDown(c.MOUSE_BUTTON_LEFT)) {
            // Barf more bunnies
            for (0..barfCount) |_| {
                if (bunniesCount < maxBunnies) {
                    bunnies[bunniesCount].pos = c.GetMousePosition();
                    bunnies[bunniesCount].speed.x = @as(f32, @floatFromInt(c.GetRandomValue(-250, 250))) / 60.0;
                    bunnies[bunniesCount].speed.y = @as(f32, @floatFromInt(c.GetRandomValue(-250, 250))) / 60.0;
                    bunnies[bunniesCount].color = .{
                        .r = @intCast(c.GetRandomValue(50, 240)),
                        .g = @intCast(c.GetRandomValue(80, 240)),
                        .b = @intCast(c.GetRandomValue(100, 240)),
                        .a = 255,
                    };
                    bunniesCount += 1;
                }
            }
        }

        // Update bunnies
        const sw: f32 = @floatFromInt(SCREEN_WIDTH);
        const sh: f32 = @floatFromInt(SCREEN_HEIGHT);
        const texW = @as(f32, @floatFromInt(texBunny.width >> 2));
        const texH = @as(f32, @floatFromInt(texBunny.height >> 2));
        for (&bunnies) |*bun| {
            bun.pos.x += bun.speed.x;
            bun.pos.y += bun.speed.y;

            if (((bun.pos.x + texW) > sw) or
                ((bun.pos.x + texW) < 0))
            {
                bun.speed.x *= -1;
            }
            if (((bun.pos.y + texH) > sh) or
                ((bun.pos.y + texH - 40) < 0))
            {
                bun.speed.y *= -1;
            }
        }

        //----------------------------------------------------------------------------------
        // Draw
        //----------------------------------------------------------------------------------
        c.BeginDrawing();
        defer c.EndDrawing();

        c.ClearBackground(c.RAYWHITE);

        for (0..bunniesCount) |i| {
            const x: c_int = @intFromFloat(bunnies[i].pos.x);
            const y: c_int = @intFromFloat(bunnies[i].pos.y);
            c.DrawTexture(texBunny, x, y, bunnies[i].color);
        }

        c.DrawRectangle(0, 0, SCREEN_WIDTH, 40, c.BLACK);
        c.DrawText(c.TextFormat("bunnies: %i", bunniesCount), 120, 10, 20, c.GREEN);
        c.DrawText(c.TextFormat("batched draw calls: %i", 1 + bunniesCount / MAX_BATCH_ELEMENTS), 320, 10, 20, c.MAROON);

        c.DrawFPS(10, 10);
    }
}
