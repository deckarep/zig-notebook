# Raylib Bunnymark in Zig

## What is this nonsense?

This is a `bunnymark` demo just showing bouncing bunnies in Raylib but in Zig. The intention is always to show how many bunnies can you get bouncing on your screen before your GPU/CPU starts choking. It's a combination of raw CPU power to update the positions of all the bunnies and GPU rendering power.

While it's nothing too scientific it's a fun way to compare how fast a rendering library (such as Raylib in this case) can go.

Two versions exist:
  * `classic_delicious.zig` - Run-of-the-mill Bunnymark in Zig, [ported from here](https://github.com/raysan5/raylib/blob/master/examples/textures/textures_bunnymark.c)
  * `coro_tacular.zig` - A `coroutine` version of Bunnymark in Zig, using the C library [neco](https://github.com/tidwall/neco)

## Question: can Raylib do coroutines?

Out of the box no, unless perhaps you're using a language that supports it directly such as Lua. The Lua interpreter has a powerful coroutine library that allows one to mimic the concept of many threads without actually spawning native OS threads. Go has a similar ability called `goroutines` which are also lightweight threads but they get mapped over multiple OS scheduled threads to maximize CPU core usage.

There's always a trade-off however, with something like `goroutines`; these are preemtible + scheduled over many native threads so you have to be conscious of data-races and how work gets synchronized.

Although Go and Lua are powerful, Go's flavor of concurrency is not what I want and Lua is a scripting language which can be slow. (Not LuaJit - see Love2D).

I want to use Zig. Zig makes me happy. I want to manage memory manually. I want a better defer. I also don't want a scripting language.

## Enter Neco

It turns out there's a wonderful C-based coroutine library called [neco](https://github.com/tidwall/neco) by `@tidwall` that offers a true single-threaded coroutine experience similar to Lua's implementation. This library has ported some of the *magical* assembly which is required per architecture in order to pull off coroutines. I believe some of the assembly comes from a library called `coro` and also from `luajit`.

## What does this allow us to do?

It allows us to write code like the following:

```zig
fn bunny_mover_coro(_: c_int, argv: [*c]?*anyopaque) callconv(.C) void {
    coroutineCount += 1;

    const pBunny: *Bunny = @alignCast(@ptrCast(argv[0]));
    const pTexBunny: *c.Texture = @alignCast(@ptrCast(argv[1]));

    const SCREEN_WIDTH = c.GetScreenWidth();
    const SCREEN_HEIGHT = c.GetScreenHeight();

    const sw: f32 = @floatFromInt(SCREEN_WIDTH);
    const sh: f32 = @floatFromInt(SCREEN_HEIGHT);
    const texW = @as(f32, @floatFromInt(pTexBunny.width >> 2));
    const texH = @as(f32, @floatFromInt(pTexBunny.height >> 2));

    // This loop is now dedicated to updating a single bunny.
    while (true) {
        if (deltaAdded == 0) {
            pBunny.pos.x += pBunny.speed.x;
            pBunny.pos.y += pBunny.speed.y;

            if (((pBunny.pos.x + texW) > sw) or
                ((pBunny.pos.x + texW) < 0))
            {
                pBunny.speed.x *= -1;
            }
            if (((pBunny.pos.y + texH) > sh) or
                ((pBunny.pos.y + texH - 40) < 0))
            {
                pBunny.speed.y *= -1;
            }
        }
        _ = c.neco_yield();
    }
}
```

The code above is a single function that uses the C calling convention since Neco is a c-based library. This could be cleaned up with a pure Zig wrapped solution but to my knowledge has not been done yet.

This function shown above can be thought of a single coroutine process. A mini agent that has a single responsibility. The responsibility is to just simply update the bunnies x and y position vector and to ensure the bunny stays within bounds.

It does this work over and over in a loop and yields back to the `neco` scheduler per loop iteration giving other coroutines a chance to run. It turns out that on my x86-64 MacBook Pro (yes I have not yet upgraded cause I'm cheap) I can get 10's of thousands of coroutines running with a caveat that I haven't yet fully worked through.

```zig
    // Grab a pointer to a single bunny.
    const pBunny = &bunnies[bunniesCount];
    
    // Spawn a coroutine responsible for moving this bunny, passing the bunny
    // and texture by reference as 2 args.
    _ = c.neco_start(bunny_mover_coro, 2, pBunny, pTexBunny);
```

The code above is code where a coroutine is started. The code simply has a reference to the mover function called: `bunny_mover_coro`, with an arg count of: `2` and passes in a pointer to a single `Bunny` struct sitting in an array, and a pointer to the bunny texture for drawing purposes.

The coroutines seem to all be humming along fine, as I'm writing this I have 20k coroutine powered bunnies running which is nothing compared to the `classic_delicious` version of the code. Keep in mind a coroutine only solution is likely not CPU cache-friendly due all the context switching that needs to occur. The context switching is extremely fast compared to native OS threads because true coroutines are expected to be very lightweight.

## The caveats
  * The coroutine version will never be as a fast as the classic_delicious version, that's not the goal here
  * I have not properly setup shutdown logic, the app won't terminate gracefully
  * The neco library if properly wrapped with Zig, will have a nicer API.
  * The big caveat:
    * When you click with the mouse to add more coroutines as the number of couritines grow, the framerate drops
    * This is because invoking: `c.neco_start` itself causes a chain reaction of yielding to all coroutines
    * Since this happens in a loop we end up having to yield: new_coroutines * existing_coroutines
    * To combat this at least for now, the coroutines that are running need to skip some degree of updates and only yield. This is to prevent the bunnies from animating too fast. I just need to think more about it. I welcome feedback.

## Conclusion

Practically, you may likely not need to spawn 10's or hundreds of thousands of coroutines for a game. Although, Go has been known to have millions of goroutines for server-based applications since which can make sense for an IO-bound application.

But, this was just a proof of concept with Zig, Raylib and Neco and it's nice to know what degree of power we may have.

This was a really fun experiment and I have high hopes for `Zig`, the `neco` c-library and `Raylib` is already truly amazing.

Yes, Raylib can use true cooperatively scheduled coroutines!

@deckarep


