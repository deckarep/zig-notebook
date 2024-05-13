const std = @import("std");
const c = @import("c_defs.zig").c;
const col_ops = @import("color_ops.zig");
const yeasings = @import("yeasings.zig");

var gAlloc: std.mem.Allocator = undefined;

// Not that I'm trying to be just like Defold, but they have these options.
pub const Playback = enum(u16) {
    None, // What does None do, maybe it means just not set.
    OnceForward,
    OnceBackward,
    OncePingpong,
    LoopForward,
    LoopBackward,
    LoopPingpong,
};

pub const Bunny = struct {
    pos: c.Vector2,
    speed: c.Vector2,
    color: c.Color,
    rot: f32 = 0.0,
    scale: c.Vector2 = .{ 1.0, 1.0 },
};

pub const AsyncCmd = enum(u16) {
    RotateFromTo = 0,
    ScaleFromTo = 1,
    MoveFromTo = 2,
    ColorTo = 3,
    AlphaFromTo = 4,
};

pub const EaseType = enum(u16) {
    Linear,
    InQuad,
    OutQuad,
    InOutQuad,
    InSine,
    OutSine,
    InOutSine,
};

pub fn EaseFunc(t: EaseType) *const fn (f32, f32, f32, f32) f32 {
    switch (t) {
        .Linear => return yeasings.linear,
        .InQuad => return yeasings.inQuad,
        .OutQuad => return yeasings.outQuad,
        .InOutQuad => return yeasings.inOutQuad,
        .InSine => return yeasings.inSine,
        .OutSine => return yeasings.outSine,
        .InOutSine => return yeasings.inOutSine,
    }
}

// This is the maximum amount of elements (quads) per batch
// NOTE: This value is defined in [rlgl] module and can be changed there
const MAX_BATCH_ELEMENTS = 8192;
var gameOver = false;
var coroutineCount: usize = 0;

pub fn coromation(texBunny: c.Texture) void {
    // Kick off the main coroutine which will run the Raylib event loop.
    _ = c.neco_start(main_coro, 1, &texBunny);
}

fn async_dispatch(argc: c_int, argv: [*c]?*anyopaque) callconv(.C) void {
    const remArgc = argc - 1;
    const cmd: AsyncCmd = @enumFromInt(@as(*u16, @alignCast(@ptrCast(argv[0]))).*);

    switch (cmd) {
        .RotateFromTo => {
            std.debug.assert(remArgc == 2);
            // Since pointers are sent, we immediately deref and copy them for local use.
            const pBunny: *Bunny = @alignCast(@ptrCast(argv[1]));
            const pArgs = @as(*rotateFromToArgs, @alignCast(@ptrCast(argv[2])));
            _rotateFromTo(pBunny, pArgs);
        },
        .ScaleFromTo => {
            std.debug.assert(remArgc == 2);
            // Since pointers are sent, we immediately deref and copy them for local use.
            const pBunny: *Bunny = @alignCast(@ptrCast(argv[1]));
            const pArgs = @as(*scaleFromToArgs, @alignCast(@ptrCast(argv[2])));

            _scaleFromTo(pBunny, pArgs);
        },
        .MoveFromTo => {
            std.debug.assert(remArgc == 2);
            // Since pointers are sent, we immediately deref and copy them for local use.
            const pBunny: *Bunny = @alignCast(@ptrCast(argv[1]));
            const pArgs = @as(*moveFromToArgs, @alignCast(@ptrCast(argv[2])));

            _moveFromTo(pBunny, pArgs);
        },
        .ColorTo => {
            std.debug.assert(remArgc == 2);
            // Since pointers are sent, we immediately deref and copy them for local use.
            const pBunny: *Bunny = @alignCast(@ptrCast(argv[1]));
            const pArgs = @as(*colorToArgs, @alignCast(@ptrCast(argv[2])));

            _colorTo(pBunny, pArgs);
        },
        .AlphaFromTo => {
            std.debug.assert(remArgc == 2);
            // Since pointers are sent, we immediately deref and copy them for local use.
            const pBunny: *Bunny = @alignCast(@ptrCast(argv[1]));
            const args: alphaFromToArgs = @as(*alphaFromToArgs, @alignCast(@ptrCast(argv[2]))).*;
            alphaFromTo(pBunny, args);
        },
    }
}

const scaleFromToArgs = struct {
    seconds: f32,
    from: c.Vector2,
    to: c.Vector2,
    ease: EaseType = .Linear,

    const Self = @This();

    fn toHeap(self: Self) *Self {
        const pArgs = gAlloc.create(scaleFromToArgs) catch unreachable;
        pArgs.* = self; // deref ptr and value-wise copy self.

        return pArgs;
    }
};

fn scaleFromTo_async(bunny: *Bunny, args: scaleFromToArgs) void {
    const pArgs = args.toHeap();

    // NOTE: pointers must always be sent, for variadics.
    const ASYNC_CMD: u16 = @intFromEnum(AsyncCmd.ScaleFromTo);
    _ = c.neco_start(
        async_dispatch,
        3,
        &ASYNC_CMD,
        bunny,
        pArgs,
    );
}

fn scaleFromTo(bunny: *Bunny, args: scaleFromToArgs) void {
    const pArgs = args.toHeap();

    _scaleFromTo(bunny, pArgs);
}

fn _scaleFromTo(bunny: *Bunny, pArgs: *const scaleFromToArgs) void {
    // defer works with neco coroutines, seems like nothing blowing up so far.
    defer {
        gAlloc.destroy(pArgs);
    }

    const change_scale = c.Vector2Subtract(pArgs.to, pArgs.from);
    var elapsed_time = c.GetFrameTime();
    const ease_func = EaseFunc(pArgs.ease);

    while (elapsed_time < pArgs.seconds) {
        const new_scale_x = ease_func(elapsed_time, pArgs.from.x, change_scale.x, pArgs.seconds);
        const new_scale_y = ease_func(elapsed_time, pArgs.from.y, change_scale.y, pArgs.seconds);

        // NOTE: original implementation had scale for x/y separate.
        bunny.scale = .{ .x = new_scale_x, .y = new_scale_y };

        _ = c.neco_yield();
        elapsed_time = elapsed_time + c.GetFrameTime();
    }

    // Set the final resting place.
    bunny.scale = pArgs.to;
}

const rotateFromToArgs = struct {
    seconds: f32,
    start: f32,
    end: f32,
    ease: EaseType = .Linear,

    const Self = @This();

    fn toHeap(self: Self) *Self {
        const pArgs = gAlloc.create(rotateFromToArgs) catch unreachable;
        pArgs.* = self; // deref ptr and value-wise copy self.

        return pArgs;
    }
};

fn rotateFromTo_async(bunny: *Bunny, args: rotateFromToArgs) void {
    const pArgs = args.toHeap();

    // NOTE: pointers must always be sent, for variadics.
    const ASYNC_CMD: u16 = @intFromEnum(AsyncCmd.RotateFromTo);
    _ = c.neco_start(async_dispatch, 3, &ASYNC_CMD, bunny, pArgs);
}

fn rotateFromTo(bunny: *Bunny, args: rotateFromToArgs) void {
    const pArgs = args.toHeap();
    _rotateFromTo(bunny, pArgs);
}

fn _rotateFromTo(bunny: *Bunny, pArgs: *rotateFromToArgs) void {
    // defer works with neco coroutines, seems like nothing blowing up so far.
    defer {
        gAlloc.destroy(pArgs);
    }

    // Note: all of this works in degrees.
    const start_angle = pArgs.start;
    const end_angle = pArgs.end;
    const change_angle = end_angle - start_angle;

    //const dt = love.timer.getDelta;
    var elapsed_time = c.GetFrameTime();

    const ease_func = EaseFunc(pArgs.ease); // hard-coded for now!
    while (elapsed_time <= pArgs.seconds) {
        const new_angle = ease_func(elapsed_time, start_angle, change_angle, pArgs.seconds);
        bunny.rot = new_angle;

        _ = c.neco_yield();
        elapsed_time = elapsed_time + c.GetFrameTime();
    }

    // Set final resting angle.
    bunny.rot = end_angle;
}

const colorToArgs = struct {
    seconds: f32,
    to: c.Color,
    ease: EaseType = .Linear,

    const Self = @This();

    fn toHeap(self: Self) *Self {
        const pArgs = gAlloc.create(colorToArgs) catch unreachable;
        pArgs.* = self; // deref ptr and value-wise copy self.

        return pArgs;
    }
};

fn colorTo_async(bunny: *Bunny, args: colorToArgs) void {
    const pArgs = args.toHeap();
    // NOTE: pointers must always be sent, for variadics.
    const ASYNC_CMD: u16 = @intFromEnum(AsyncCmd.ColorTo);
    _ = c.neco_start(async_dispatch, 3, &ASYNC_CMD, bunny, pArgs);
}

fn colorTo(bunny: *Bunny, args: colorToArgs) void {
    const pArgs = args.toHeap();

    _colorTo(bunny, pArgs);
}

fn _colorTo(bunny: *Bunny, pArgs: *const colorToArgs) void {
    // defer works with neco coroutines, seems like nothing blowing up so far.
    defer {
        gAlloc.destroy(pArgs);
    }

    var elapsed_time = c.GetFrameTime();
    const ease_func = EaseFunc(pArgs.ease);
    const startColor = bunny.color;

    const chngR: f32 = @as(f32, @floatFromInt(pArgs.to.r)) - @as(f32, @floatFromInt(startColor.r));
    const chngG: f32 = @as(f32, @floatFromInt(pArgs.to.g)) - @as(f32, @floatFromInt(startColor.g));
    const chngB: f32 = @as(f32, @floatFromInt(pArgs.to.b)) - @as(f32, @floatFromInt(startColor.b));
    const chngA: f32 = @as(f32, @floatFromInt(pArgs.to.a)) - @as(f32, @floatFromInt(startColor.a));

    while (elapsed_time <= pArgs.seconds) {
        bunny.color = c.Color{
            .r = col_ops.clampColorFloat(ease_func(elapsed_time, @floatFromInt(startColor.r), chngR, pArgs.seconds)),
            .g = col_ops.clampColorFloat(ease_func(elapsed_time, @floatFromInt(startColor.g), chngG, pArgs.seconds)),
            .b = col_ops.clampColorFloat(ease_func(elapsed_time, @floatFromInt(startColor.b), chngB, pArgs.seconds)),
            .a = col_ops.clampColorFloat(ease_func(elapsed_time, @floatFromInt(startColor.a), chngA, pArgs.seconds)),
        };

        _ = c.neco_yield();
        elapsed_time += c.GetFrameTime();
    }

    // After animation frames set the color to the final and absolute resting place.
    bunny.color = pArgs.to;
}

const alphaFromToArgs = struct {
    seconds: f32,
    from: u8,
    to: u8,
    ease: EaseType = .Linear,

    const Self = @This();

    fn toHeap(self: Self) *Self {
        const pArgs = gAlloc.create(alphaFromToArgs) catch unreachable;
        pArgs.* = self; // deref ptr and value-wise copy self.

        return pArgs;
    }
};

fn alphaFromTo_async(bunny: *Bunny, args: alphaFromToArgs) void {
    const pArgs = args.toHeap();

    // NOTE: pointers must always be sent, for variadics.
    const ASYNC_CMD: u16 = @intFromEnum(AsyncCmd.AlphaFromTo);
    _ = c.neco_start(async_dispatch, 3, &ASYNC_CMD, bunny, pArgs);
}

fn alphaFromTo(bunny: *Bunny, args: alphaFromToArgs) void {
    const pArgs = args.toHeap();
    _alphaFromTo(bunny, pArgs);
}

fn _alphaFromTo(bunny: *Bunny, pArgs: *const alphaFromToArgs) void {
    // defer works with neco coroutines, seems like nothing blowing up so far.
    defer {
        gAlloc.destroy(pArgs);
    }

    var elapsed_time: f32 = c.GetFrameTime();

    const ease_func = EaseFunc(pArgs.ease);
    const start_alpha = pArgs.from;

    const end_alpha = pArgs.to;
    const change_a: f32 = @as(f32, @floatFromInt(end_alpha)) - @as(f32, @floatFromInt(start_alpha));

    while (elapsed_time <= pArgs.seconds) {
        const new_alpha = ease_func(elapsed_time, @floatFromInt(start_alpha), change_a, pArgs.seconds);
        bunny.color.a = col_ops.clampColorFloat(new_alpha);

        _ = c.neco_yield();
        elapsed_time = elapsed_time + c.GetFrameTime();
    }

    // Set the final resting alpha.
    bunny.color.a = end_alpha;
}

const moveFromToArgs = struct {
    seconds: f32,
    start: c.Vector2, // use nullable, to indicate start from current x/y?
    end: c.Vector2,
    ease: EaseType = .Linear,

    const Self = @This();

    fn toHeap(self: Self) *Self {
        const pArgs = gAlloc.create(moveFromToArgs) catch unreachable;
        pArgs.* = self; // deref ptr and value-wise copy self.

        return pArgs;
    }
};

fn moveFromTo_async(bunny: *Bunny, args: moveFromToArgs) void {
    const pArgs = args.toHeap();

    // NOTE: pointers must always be sent, for variadics.
    const ASYNC_CMD: u16 = @intFromEnum(AsyncCmd.MoveFromTo);
    _ = c.neco_start(async_dispatch, 3, &ASYNC_CMD, bunny, pArgs);
}

fn moveFromTo(bunny: *Bunny, args: moveFromToArgs) void {
    const pArgs = args.toHeap();

    _moveFromTo(bunny, pArgs);
}

fn _moveFromTo(bunny: *Bunny, pArgs: *const moveFromToArgs) void {
    // defer works with neco coroutines, seems like nothing blowing up so far.
    defer {
        gAlloc.destroy(pArgs);
    }

    // Moves a bunny from start to end points
    // Type can be LINEAR, EASE_IN, EASE_OUT, EASE_INOUT, SLOW_EASE_IN, SLOW_EASE_OUT, SIN_INOUT, or COS_INOUT
    const start_x = pArgs.start.x;
    const start_y = pArgs.start.y;

    const end_x = pArgs.end.x;
    const end_y = pArgs.end.y;

    const change_x = end_x - start_x;
    const change_y = end_y - start_y;

    //const dt = love.timer.getDelta;
    var elapsed_time = c.GetFrameTime();

    //const ease_func = easing.inOutQuint; // hard-coded for now!
    const ease_func = EaseFunc(pArgs.ease);

    while (elapsed_time < pArgs.seconds) {
        const new_x = ease_func(elapsed_time, start_x, change_x, pArgs.seconds);
        const new_y = ease_func(elapsed_time, start_y, change_y, pArgs.seconds);

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

    const DUR_SECONDS = 0.6;
    const SCREEN_WIDTH: f32 = @floatFromInt(c.GetScreenWidth());
    //const SLEEP_FOR = c.NECO_MILLISECOND * 500;
    const SCREEN_HEIGHT: f32 = @floatFromInt(c.GetScreenHeight());

    // const yLoc = 100;
    // const xLoc = 80;
    // pBunny.pos = .{ .x = xLoc, .y = yLoc };

    const origLoc = pBunny.pos;
    const origScale = pBunny.scale;
    const destLoc = .{ .x = SCREEN_WIDTH / 2.0, .y = SCREEN_HEIGHT / 2.0 };

    // Sleepin creates an interesting delay effect.
    _ = c.neco_sleep(c.NECO_MILLISECOND * c.GetRandomValue(100, 300));

    while (true) {
        // TODO: work through override, cancellation logic eventually.
        //      - this is important for things like PingPong (asumming I do it)
        // TODO: color and alpha interfere, break them out for finer control.
        // colorTo_async(pBunny, .{
        //     .seconds = DUR_SECONDS,
        //     .to = col_ops.randColor(),
        //     .ease = .InOutSine,
        // });
        alphaFromTo_async(pBunny, .{
            .seconds = DUR_SECONDS,
            .from = 255, // TODO: it's clear to me that this should take (0.0 - 1.0)
            .to = 128, // (0.0 - 1.0)
            .ease = .InOutSine,
        });

        scaleFromTo_async(pBunny, .{
            .seconds = DUR_SECONDS,
            .from = origScale,
            .to = .{ .x = 3.0, .y = 3.0 },
            .ease = .InOutSine,
        });

        moveFromTo_async(pBunny, .{
            .seconds = DUR_SECONDS,
            .start = origLoc,
            .end = destLoc,
            .ease = .InOutSine,
        });

        rotateFromTo_async(pBunny, .{
            .seconds = DUR_SECONDS,
            .start = 0.0,
            .end = 90 * 8,
            .ease = .InOutSine,
        });

        _ = c.neco_sleep(c.NECO_SECOND * 6);
    }

    // while (true) {
    //     //std.debug.print("yielding...\n", .{});
    //     _ = c.neco_yield();
    // }

    std.debug.print("animation routine done.\n", .{});
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
    //pBunny.scale = 1.0;
}

fn main_coro(_: c_int, argv: [*c]?*anyopaque) callconv(.C) void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    gAlloc = allocator; // capture this globally.
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) @panic("TEST FAIL");
    }

    const SCREEN_WIDTH = c.GetScreenWidth();
    const maxBunnies = 10_000;

    const pTexBunny: *c.Texture = @alignCast(@ptrCast(argv[0]));

    // Stack alloc'd bunnies array.
    var bunnies: [maxBunnies]Bunny = undefined;
    var bunniesCount: usize = 0;

    // Init and spawn bunny threads.
    for (0..10) |idx| {
        const pBunny = &bunnies[idx];
        initBunny(pBunny);

        const i: f32 = @floatFromInt(idx);
        pBunny.pos.x = pBunny.pos.x + (i * 100.0);

        // Spawn a coroutine responsible for moving this bunny,
        // passing the bunny and texture by reference.
        _ = c.neco_start(mov_bunny_a_coro, 2, pBunny, pTexBunny);
        bunniesCount += 1;
    }

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

        const tw: f32 = @floatFromInt(pTexBunny.width);
        const th: f32 = @floatFromInt(pTexBunny.height);
        const hw = tw / 2.0;
        const hh = th / 2.0;

        for (0..bunniesCount) |i| {
            const cb = bunnies[i];

            c.DrawTexturePro(
                pTexBunny.*,
                .{
                    .x = 0,
                    .y = 0,
                    .width = tw,
                    .height = th,
                },
                .{
                    .x = cb.pos.x,
                    .y = cb.pos.y,
                    .width = tw * cb.scale.x,
                    .height = th * cb.scale.y,
                },
                .{ .x = hw * cb.scale.x, .y = hh * cb.scale.y },
                cb.rot,
                cb.color,
            );
        }

        var stats: c.neco_stats = undefined;
        _ = c.neco_getstats(&stats);

        const coro_count = stats.coroutines;

        c.DrawRectangle(0, 0, SCREEN_WIDTH, 40, c.BLACK);
        c.DrawText(c.TextFormat("bunnies: %i", bunniesCount), 120, 10, 20, c.GREEN);
        c.DrawText(c.TextFormat("batched draw calls: %i, coroutines: %i", 1 + bunniesCount / MAX_BATCH_ELEMENTS, coro_count), 320, 10, 20, c.MAROON);

        c.DrawFPS(10, 10);
    }
}
