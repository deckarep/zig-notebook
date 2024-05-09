const std = @import("std");
const c = @import("c_defs.zig").c;
const zeco = @import("zeco.zig");

const MAX_BUNNIES = 100_000;
const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 450;

// This is the maximum amount of elements (quads) per batch
// NOTE: This value is defined in [rlgl] module and can be changed there
const MAX_BATCH_ELEMENTS = 8192;

const Bunny = struct {
    pos: c.Vector2,
    speed: c.Vector2,
    color: c.Color,
};

pub fn main() !void {
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    //zeco.init();
    vanilla_bunnymark();

    // this works fine
    //neco_main(0, null);
    std.debug.print("application terminated.", .{});
}

fn vanilla_bunnymark() void {
    c.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib vanilla bunnymark");
    defer c.CloseWindow();
    c.SetTargetFPS(60);

    const texBunny = c.LoadTexture("resources/textures/wabbit_alpha.png");
    defer c.UnloadTexture(texBunny);

    // Stack alloc'd bunnies array.
    var bunnies: [MAX_BUNNIES]Bunny = undefined;
    var bunniesCount: usize = 0;

    while (!c.WindowShouldClose()) {
        //----------------------------------------------------------------------------------
        // Update
        //----------------------------------------------------------------------------------
        if (c.IsMouseButtonDown(c.MOUSE_BUTTON_LEFT)) {
            // Create more bunnies
            for (0..100) |_| {
                if (bunniesCount < MAX_BUNNIES) {
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
        const sw: f32 = @floatFromInt(c.GetScreenWidth());
        const sh: f32 = @floatFromInt(c.GetScreenHeight());
        const texW = @as(f32, @floatFromInt(texBunny.width >> 2));
        const texH = @as(f32, @floatFromInt(texBunny.height >> 2));
        for (0..bunniesCount) |i| {
            bunnies[i].pos.x += bunnies[i].speed.x;
            bunnies[i].pos.y += bunnies[i].speed.y;

            if (((bunnies[i].pos.x + texW) > sw) or
                ((bunnies[i].pos.x + texW) < 0))
            {
                bunnies[i].speed.x *= -1;
            }
            if (((bunnies[i].pos.y + texH) > sh) or
                ((bunnies[i].pos.y + texH - 40) < 0))
            {
                bunnies[i].speed.y *= -1;
            }
        }
        
        //----------------------------------------------------------------------------------
        // Draw
        //----------------------------------------------------------------------------------
        c.BeginDrawing();
        defer c.EndDrawing();

        c.ClearBackground(c.RAYWHITE);

        for (0..bunniesCount) |i| {
            const x:c_int = @intFromFloat(bunnies[i].pos.x);
            const y:c_int = @intFromFloat(bunnies[i].pos.y);
            c.DrawTexture(texBunny, x, y, bunnies[i].color);
        }

        c.DrawRectangle(0, 0, SCREEN_WIDTH, 40, c.BLACK);
        c.DrawText(c.TextFormat("bunnies: %i", bunniesCount), 120, 10, 20, c.GREEN);
        c.DrawText(c.TextFormat("batched draw calls: %i", 1 + bunniesCount / MAX_BATCH_ELEMENTS), 320, 10, 20, c.MAROON);

        c.DrawFPS(10, 10);
    }
}
