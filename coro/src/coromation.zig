const std = @import("std");
const c = @import("c_defs.zig").c;
const col_ops = @import("color_ops.zig");

pub const Bunny = struct {
    pos: c.Vector2,
    speed: c.Vector2,
    color: c.Color,
    rot: f32 = 0.0,
    scale: f32 = 1.0,
};

pub const AsyncCmd = enum(u16) {
    RotateFromTo = 0,
    ScaleFromTo = 1,
    MoveFromTo = 2,
    ColorTo = 3,
    AlphaFromTo = 4,
};

// This is the maximum amount of elements (quads) per batch
// NOTE: This value is defined in [rlgl] module and can be changed there
const MAX_BATCH_ELEMENTS = 8192;
var gameOver = false;
var coroutineCount: usize = 0;

pub fn coromation(texBunny: c.Texture) void {
    // Kick off the main coroutine which will run the Raylib event loop.
    _ = c.neco_start(main_coro, 1, &texBunny);
}

// (time: number, beginning: number, changeInValue: number, duration: number)
fn ease_linear(tm: f32, beg: f32, chg: f32, dur: f32) f32 {
    return (chg * tm) / dur + beg;
}

fn ease_inOutQuint(tm: f32, beg: f32, chg: f32, dur: f32) f32 {
    var tm_ = tm;

    tm_ /= dur;
    if ((tm_ / 2) < 1) {
        return (chg / 2) * tm_ * tm_ * tm_ * tm_ * tm_ + beg;
    }
    tm_ -= 2;
    return (chg / 2) * (tm_ * tm_ * tm_ * tm_ * tm_ + 2) + beg;
}

fn async_dispatch(_: c_int, argv: [*c]?*anyopaque) callconv(.C) void {
    const cmd: AsyncCmd = @enumFromInt(@as(*u16, @alignCast(@ptrCast(argv[0]))).*);

    switch (cmd) {
        .RotateFromTo => {
            const pBunny: *Bunny = @alignCast(@ptrCast(argv[1]));
            // Since pointers are sent, we immediately deref and copy them for local use.
            const seconds: f32 = @as(*f32, @alignCast(@ptrCast(argv[2]))).*;
            const start: f32 = @as(*f32, @alignCast(@ptrCast(argv[3]))).*;
            const end: f32 = @as(*f32, @alignCast(@ptrCast(argv[4]))).*;

            rotateFromTo(pBunny, seconds, start, end);
        },
        .ScaleFromTo => {
            const pBunny: *Bunny = @alignCast(@ptrCast(argv[1]));
            // Since pointers are sent, we immediately deref and copy them for local use.
            const seconds: f32 = @as(*f32, @alignCast(@ptrCast(argv[2]))).*;
            const from: f32 = @as(*f32, @alignCast(@ptrCast(argv[3]))).*;
            const to: f32 = @as(*f32, @alignCast(@ptrCast(argv[4]))).*;

            scaleFromTo(pBunny, seconds, from, to);
        },
        .MoveFromTo => {
            const pBunny: *Bunny = @alignCast(@ptrCast(argv[1]));
            // Since pointers are sent, we immediately deref and copy them for local use.
            const seconds: f32 = @as(*f32, @alignCast(@ptrCast(argv[2]))).*;
            const from: c.Vector2 = @as(*c.Vector2, @alignCast(@ptrCast(argv[3]))).*;
            const to: c.Vector2 = @as(*c.Vector2, @alignCast(@ptrCast(argv[4]))).*;

            moveFromTo(pBunny, seconds, from, to);
        },
        .ColorTo => {
            const pBunny: *Bunny = @alignCast(@ptrCast(argv[1]));
            // Since pointers are sent, we immediately deref and copy them for local use.
            const seconds: f32 = @as(*f32, @alignCast(@ptrCast(argv[2]))).*;
            const destColor: c.Color = @as(*c.Color, @alignCast(@ptrCast(argv[3]))).*;

            colorTo(pBunny, seconds, destColor);
        },
        .AlphaFromTo => {
            const pBunny: *Bunny = @alignCast(@ptrCast(argv[1]));
            // Since pointers are sent, we immediately deref and copy them for local use.
            const seconds: f32 = @as(*f32, @alignCast(@ptrCast(argv[2]))).*;
            const from: u8 = @as(*u8, @alignCast(@ptrCast(argv[3]))).*;
            const to: u8 = @as(*u8, @alignCast(@ptrCast(argv[4]))).*;

            alphaFromTo(pBunny, seconds, from, to);
        },
    }
}

fn scaleFromTo_async(bunny: *Bunny, seconds: f32, from: f32, to: f32) void {
    // NOTE: pointers must always be sent, for variadics.
    const ASYNC_CMD: u16 = @intFromEnum(AsyncCmd.ScaleFromTo);
    _ = c.neco_start(
        async_dispatch,
        5,
        &ASYNC_CMD,
        bunny,
        &seconds,
        &from,
        &to,
    );
}

fn scaleFromTo(bunny: *Bunny, seconds: f32, from: f32, to: f32) void {
    const change_scale = to - from;

    var elapsed_time = c.GetFrameTime();
    const ease_func = ease_linear;

    while (elapsed_time <= seconds) {
        const new_scale = ease_func(elapsed_time, from, change_scale, seconds);

        // NOTE: original implementation had scale for x/y separate.
        //img.setScale(new_scale, new_scale);
        bunny.scale = new_scale;

        _ = c.neco_yield();
        elapsed_time = elapsed_time + c.GetFrameTime();
    }

    // Set the final resting place.
    bunny.scale = to;
}

fn rotateFromTo_async(bunny: *Bunny, seconds: f32, start: f32, end: f32) void {
    // NOTE: pointers must always be sent, for variadics.
    const ASYNC_CMD: u16 = @intFromEnum(AsyncCmd.RotateFromTo);
    _ = c.neco_start(async_dispatch, 5, &ASYNC_CMD, bunny, &seconds, &start, &end);
}

fn rotateFromTo(bunny: *Bunny, seconds: f32, start: f32, end: f32) void {
    // Note: all of this works in degrees.
    const start_angle = start;
    const end_angle = end;
    const change_angle = end_angle - start_angle;

    //const dt = love.timer.getDelta;
    var elapsed_time = c.GetFrameTime();

    const ease_func = ease_linear; // hard-coded for now!
    while (elapsed_time <= seconds) {
        const new_angle = ease_func(elapsed_time, start_angle, change_angle, seconds);
        bunny.rot = new_angle;
        _ = c.neco_yield();

        elapsed_time = elapsed_time + c.GetFrameTime();
    }

    // Set final resting angle.
    bunny.rot = end_angle;
}

fn colorTo_async(bunny: *Bunny, seconds: f32, destColor: c.Color) void {
    // NOTE: pointers must always be sent, for variadics.
    const ASYNC_CMD: u16 = @intFromEnum(AsyncCmd.ColorTo);
    _ = c.neco_start(async_dispatch, 4, &ASYNC_CMD, bunny, &seconds, &destColor);
}

fn colorTo(bunny: *Bunny, seconds: f32, destColor: c.Color) void {
    //std.debug.print("colorTo!!!\n", .{});
    var elapsed_time = c.GetFrameTime();

    const ease_func = ease_linear;

    const startColor = bunny.color;

    const start_r = startColor.r;
    const start_g = startColor.g;
    const start_b = startColor.b;
    const start_a = startColor.a;

    const end_r = destColor.r;
    const end_g = destColor.g;
    const end_b = destColor.b;
    const end_a = destColor.a;

    const change_r: f32 = @as(f32, @floatFromInt(end_r)) - @as(f32, @floatFromInt(start_r));
    const change_g: f32 = @as(f32, @floatFromInt(end_g)) - @as(f32, @floatFromInt(start_g));
    const change_b: f32 = @as(f32, @floatFromInt(end_b)) - @as(f32, @floatFromInt(start_b));
    const change_a: f32 = @as(f32, @floatFromInt(end_a)) - @as(f32, @floatFromInt(start_a));

    while (elapsed_time <= seconds) {
        const new_r = ease_func(elapsed_time, @floatFromInt(start_r), change_r, seconds);
        const new_g = ease_func(elapsed_time, @floatFromInt(start_g), change_g, seconds);
        const new_b = ease_func(elapsed_time, @floatFromInt(start_b), change_b, seconds);
        const new_a = ease_func(elapsed_time, @floatFromInt(start_a), change_a, seconds);

        //std.debug.print("{d}, {d}, {d}, {d}\n", .{new_r, new_g, new_b, new_a});

        bunny.color = .{
            .r = col_ops.clampColorFloat(new_r),
            .g = col_ops.clampColorFloat(new_g),
            .b = col_ops.clampColorFloat(new_b),
            .a = col_ops.clampColorFloat(new_a),
        };

        _ = c.neco_yield();
        elapsed_time = elapsed_time + c.GetFrameTime();
    }

    // After animation frames set the color to the final and absolute resting place.
    bunny.color = .{ .r = end_r, .g = end_g, .b = end_b, .a = end_a };
}

fn alphaFromTo_async(bunny: *Bunny, seconds: f32, from: u8, to: u8) void {
    // NOTE: pointers must always be sent, for variadics.
    const ASYNC_CMD: u16 = @intFromEnum(AsyncCmd.AlphaFromTo);
    _ = c.neco_start(async_dispatch, 5, &ASYNC_CMD, bunny, &seconds, &from, &to);
}

fn alphaFromTo(bunny: *Bunny, seconds: f32, from: u8, to: u8) void {
    var elapsed_time: f32 = c.GetFrameTime();

    const ease_func = ease_linear; // hard-coded for now!
    const start_alpha = from;

    const end_alpha = to;
    const change_a: f32 = @as(f32, @floatFromInt(end_alpha)) - @as(f32, @floatFromInt(start_alpha));

    while (elapsed_time <= seconds) {
        const new_alpha = ease_func(elapsed_time, @floatFromInt(start_alpha), change_a, seconds);
        bunny.color.a = col_ops.clampColorFloat(new_alpha);

        _ = c.neco_yield();
        elapsed_time = elapsed_time + c.GetFrameTime();
    }

    // Set the final resting alpha.
    bunny.color.a = end_alpha;
}

fn moveFromTo_async(bunny: *Bunny, seconds: f32, start: c.Vector2, end: c.Vector2) void {
    // NOTE: pointers must always be sent, for variadics.
    const ASYNC_CMD: u16 = @intFromEnum(AsyncCmd.MoveFromTo);
    _ = c.neco_start(async_dispatch, 5, &ASYNC_CMD, bunny, &seconds, &start, &end);
}

fn moveFromTo(bunny: *Bunny, seconds: f32, start: c.Vector2, end: c.Vector2) void {
    // Moves a bunny from start to end points
    // Type can be LINEAR, EASE_IN, EASE_OUT, EASE_INOUT, SLOW_EASE_IN, SLOW_EASE_OUT, SIN_INOUT, or COS_INOUT
    const start_x = start.x;
    const start_y = start.y;

    const end_x = end.x;
    const end_y = end.y;

    const change_x = end_x - start_x;
    const change_y = end_y - start_y;

    //const dt = love.timer.getDelta;
    var elapsed_time = c.GetFrameTime();

    //const ease_func = easing.inOutQuint; // hard-coded for now!
    const ease_func = ease_linear;

    while (elapsed_time < seconds) {
        const new_x = ease_func(elapsed_time, start_x, change_x, seconds);
        const new_y = ease_func(elapsed_time, start_y, change_y, seconds);

        //img.setPosition(new_x, new_y);
        bunny.pos = .{ .x = new_x, .y = new_y };

        _ = c.neco_yield();
        elapsed_time = elapsed_time + c.GetFrameTime();
    }

    // Set the final resting place.
    //img.setPosition(end_x, end_y);
    bunny.pos = .{ .x = end_x, .y = end_y };
}

fn mov_bunny_a_coro(_: c_int, argv: [*c]?*anyopaque) callconv(.C) void {
    const pBunny: *Bunny = @alignCast(@ptrCast(argv[0]));
    //const pTexBunny: *c.Texture = @alignCast(@ptrCast(argv[1]));

    const DUR_SECONDS = 3.0;
    const SCREEN_WIDTH: f32 = @floatFromInt(c.GetScreenWidth());
    const SLEEP_FOR = c.NECO_MILLISECOND * 500;
    //const SCREEN_HEIGHT = c.GetScreenHeight();

    pBunny.pos = .{ .x = 10, .y = 60 };
    const origLoc = pBunny.pos;
    const destLoc = .{ .x = SCREEN_WIDTH - 40, .y = 60 };

    while (true) {
        //rotateFromTo_async(pBunny, DUR_SECONDS, 0.0, 90 * 6);
        //scaleFromTo_async(pBunny, DUR_SECONDS, 1.0, 2.0);
        //colorTo_async(pBunny, DUR_SECONDS, col_ops.randColor());
        alphaFromTo_async(pBunny, DUR_SECONDS, 255, 0);
        moveFromTo(pBunny, DUR_SECONDS, pBunny.pos, destLoc);

        _ = c.neco_sleep(SLEEP_FOR);

        //rotateFromTo_async(pBunny, DUR_SECONDS, 90.0 * 6, 0);
        //scaleFromTo_async(pBunny, DUR_SECONDS, 2.0, 1.0);
        //colorTo_async(pBunny, DUR_SECONDS, col_ops.randColor());
        alphaFromTo_async(pBunny, DUR_SECONDS, 0, 255);
        moveFromTo(pBunny, DUR_SECONDS, pBunny.pos, origLoc);
        _ = c.neco_sleep(SLEEP_FOR);
    }
}

fn initBunny(pBunny: *Bunny) void {
    pBunny.pos = c.GetMousePosition();
    pBunny.speed.x = @as(f32, @floatFromInt(c.GetRandomValue(-250, 250))) / 60.0;
    pBunny.speed.y = @as(f32, @floatFromInt(c.GetRandomValue(-250, 250))) / 60.0;
    pBunny.color = .{
        .r = @intCast(c.GetRandomValue(50, 240)),
        .g = @intCast(c.GetRandomValue(80, 240)),
        .b = @intCast(c.GetRandomValue(100, 240)),
        .a = 255,
    };
    pBunny.rot = 0.0;
    pBunny.scale = 1.0;
}

fn main_coro(_: c_int, argv: [*c]?*anyopaque) callconv(.C) void {
    const SCREEN_WIDTH = c.GetScreenWidth();
    const maxBunnies = 5;

    const pTexBunny: *c.Texture = @alignCast(@ptrCast(argv[0]));

    // Stack alloc'd bunnies array.
    var bunnies: [maxBunnies]Bunny = undefined;
    var bunniesCount: usize = 0;

    // Create a single bunny
    const pBunny = &bunnies[0];
    initBunny(pBunny);
    bunniesCount += 1;

    // Spawn a coroutine responsible for moving this bunny,
    // passing the bunny and texture by reference.
    _ = c.neco_start(mov_bunny_a_coro, 2, pBunny, pTexBunny);

    while (!c.WindowShouldClose() and !gameOver) {
        //----------------------------------------------------------------------------------
        // Update
        //----------------------------------------------------------------------------------
        if (c.IsKeyReleased(c.KEY_ESCAPE)) {
            gameOver = true;
        }

        // Don't forget to yield the game loop to give all alive coroutines a chance to run.
        // After all, this is a truly concurrent demo - no pesky native OS threads here.
        _ = c.neco_yield();

        //----------------------------------------------------------------------------------
        // Draw
        //----------------------------------------------------------------------------------
        c.BeginDrawing();
        defer c.EndDrawing();

        c.ClearBackground(c.RAYWHITE);

        for (0..bunniesCount) |i| {
            const cb = bunnies[i];
            // const tw:f32 = @floatFromInt(pTexBunny.width);
            // const th:f32 = @floatFromInt(pTexBunny.height);
            //const halfW: f32 = @floatFromInt(pTexBunny.width >> 2);
            //const halfH: f32 = @floatFromInt(pTexBunny.height >> 2);
            //const adjustedPos = .{ .x = cb.pos.x - halfW, .y = cb.pos.y - halfH };

            c.rlPushMatrix();
            defer c.rlPopMatrix();

            c.rlScalef(cb.scale, cb.scale, 1.0);
            c.rlRotatef(cb.rot, 1.0, 1.0, 1.0);
            c.DrawTexture(pTexBunny.*, @intFromFloat(cb.pos.x), @intFromFloat(cb.pos.y), cb.color);
            // c.DrawTextureEx(
            //     pTexBunny.*,
            //     adjustedPos,
            //     cb.rot,
            //     cb.scale,
            //     cb.color,
            // );

            // c.DrawTexturePro(
            //     pTexBunny.*,
            //     .{
            //         .x = 0,
            //         .y = 0,
            //         .width = tw,
            //         .height = th,
            //     },
            //     .{
            //         .x = 0,
            //         .y = 0,
            //         .width = tw,
            //         .height = th,
            //     },
            //     adjustedPos,
            //     cb.rot,
            //     cb.color,
            // );
        }

        c.DrawRectangle(0, 0, SCREEN_WIDTH, 40, c.BLACK);
        c.DrawText(c.TextFormat("bunnies: %i", bunniesCount), 120, 10, 20, c.GREEN);
        c.DrawText(c.TextFormat("batched draw calls: %i, coroutines: %i", 1 + bunniesCount / MAX_BATCH_ELEMENTS, bunniesCount), 320, 10, 20, c.MAROON);

        c.DrawFPS(10, 10);
    }
}
