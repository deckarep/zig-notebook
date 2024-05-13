pub const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("rlgl.h");
    @cInclude("raymath.h");
    // neco coroutine lib
    @cInclude("neco.h");
    @cInclude("boot_neco.h");
});
