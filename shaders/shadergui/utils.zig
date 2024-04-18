pub const c = @import("c_defs.zig").c;

pub fn rlCenterWin(width: u32, height: u32) void {
    const w = @as(c_int, @intCast(width));
    const h = @as(c_int, @intCast(height));
    const mon = c.GetCurrentMonitor();
    const mon_width = c.GetMonitorWidth(mon);
    const mon_height = c.GetMonitorHeight(mon);
    c.SetWindowPosition(@divTrunc(mon_width, 2) - @divTrunc(w, 2), @divTrunc(mon_height, 2) - @divTrunc(h, 2));
}