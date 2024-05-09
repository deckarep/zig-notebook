const std = @import("std");
const c = @import("c_defs.zig").c;

fn p(s: []const u8) void {
    std.debug.print("HERE: {s}\n", .{s});
}

pub fn init() void {
    // this causes crashing here, when started in a coroutine.
    _ = c.neco_start(neco_main, 0);
}

pub fn start() void {}

fn neco_main(_: c_int, _: [*c]?*anyopaque) callconv(.C) void {
    const N = 1000;

    p("1");
    // Use a waitgroup to wait for the child coroutines to initialize.
    var wg: c.neco_waitgroup = std.mem.zeroes(c.neco_waitgroup);
    _ = c.neco_waitgroup_init(&wg);
    _ = c.neco_waitgroup_add(&wg, N);

    p("2");
    // Start coroutines
    const startTime = c.neco_now();
    for (0..N) |_| {
        _ = c.neco_start(coro, 1, &wg);
    }

    p("3");
    // Wait for all coroutines to start
    _ = c.neco_waitgroup_wait(&wg);

    p("4");
    const elapsed: i64 = c.neco_now() - startTime;
    const fElapsed: f64 = @floatFromInt(elapsed);
    const fDiv: f64 = 1_000_000.0;
    // WARNING: adding this line causes this code to crash???
    // Theories:
    // 0. Only crashes on debug builds.
    // 1. The neco code is not quite compatible with Zig (due to the magic)
    // 2. A bug in neco with stack alignment
    // 3. A bug on only on macos
    // 4. Some truly undefined behavior in neco that is somehow showing up.

    // Offending line.
    // std.log.info("start: {d}, elapsed: {d}\n", .{start, elapsed});

    // OK
    _ = c.printf("all started in %f ms\n", fElapsed / fDiv);
}

fn coro(_: c_int, argv: [*c]?*anyopaque) callconv(.C) void {
    //p("coro:start");
    //const num:*usize = @alignCast(@ptrCast(argv[0]));
    const wg: *c.neco_waitgroup = @alignCast(@ptrCast(argv[0]));
    //p("coro:a");
    _ = c.neco_waitgroup_done(wg);
    //p("coro:b");
    _ = c.neco_waitgroup_wait(wg);
    //p("coro:c");

    //std.debug.print("coro started\n", .{});
    //p("coro:end");
    //std.debug.print("coro num: {d}, started\n", .{num.*});
}
