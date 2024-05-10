const c = @import("c_defs.zig").c;

pub fn randColor() c.Color {
    return .{
        .r = @intCast(c.GetRandomValue(50, 240)),
        .g = @intCast(c.GetRandomValue(80, 240)),
        .b = @intCast(c.GetRandomValue(100, 240)),
        .a = 255,
    };
}

pub fn clampColorFloat(val: f32) u8 {
    var newVal: f32 = val;
    if (newVal > 255.0) newVal = 255.0;
    if (newVal < 0.0) newVal = 0.0;
    return @intFromFloat(newVal);
}

// pack_rgba packs a ColorRGBA object into a single number value of: 0xAARRGGBB
pub fn pack_rgba(color: c.Color) u32 {
    const a = (color.a * 255) << 24;
    const r = (color.r * 255) << 16;
    const g = (color.g * 255) << 8;
    const b = color.b * 255;
    return a | r | g | b;
}

// unpacks a single rgb color value into a 4 component {r, g, b, a} table.
pub fn unpack_rgba(color: u32) c.Color {
    // convert from packed RGB: 0xAARRGGBB 0-255 values to a lua table normalize to 1.0

    const blue = (color & 0xff) / 255.0;
    const green = ((color >> 8) & 0xff) / 255.0;
    const red = ((color >> 16) & 0xff) / 255.0;
    const alpha = ((color >> 24) & 0xff) / 255.0;

    return .{ .r = red, .g = green, .b = blue, .a = alpha };
}

// // pack_rgb packs a ColorRGB object into a single number value of: 0xRRGGBB
// fn pack_rgb(color: ColorRGB): number {
//     const r = (color.red * 255) << 16;
//     const g = (color.green * 255) << 8;
//     const b = color.blue * 255;
//     return r | g | b;
// }

// fn unpack_rgb(color: number): ColorRGB {
//     // convert from packed RGB: 0xAARRGGBB 0-255 values to a lua table normalize to 1.0

//     const blue = (color & 0xff) / 255.0;
//     const green = ((color >>> 8) & 0xff) / 255.0;
//     const red = ((color >>> 16) & 0xff) / 255.0;

//     return { red: red, green: green, blue: blue };
// }
