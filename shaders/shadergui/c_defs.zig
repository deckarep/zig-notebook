pub const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdarg.h");
    @cInclude("string.h");
    @cInclude("time.h");
    @cInclude("raylib.h");
    @cInclude("rlgl.h");
    @cInclude("raygui.h");

    // raylib_cimgui bindings
    @cInclude("imgui_impl_raylib.h");
    @cInclude("rlcimgui.h");
});
