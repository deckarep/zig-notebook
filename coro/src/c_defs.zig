pub const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("rlgl.h");
    // neco coroutine lib
    @cInclude("neco.h");
    @cInclude("boot_neco.h");
});
