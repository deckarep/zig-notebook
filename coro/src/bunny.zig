const c = @import("c_defs.zig").c;

pub const Bunny = struct {
    pos: c.Vector2,
    speed: c.Vector2,
    color: c.Color,
};
