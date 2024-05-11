const std = @import("std");

// "This will only yease the pain..."
// (time: f32, beginning: f32, changeInValue: f32, duration: f32)

// More inspo fam.
// https://github.com/Jack-Ji/jok/blob/main/src/utils/easing.zig

pub fn linear(t: f32, b: f32, c: f32, d: f32) f32 {
    return c * t / d + b;
}

pub fn inQuad(t: f32, b: f32, c: f32, d: f32) f32 {
    var tm = t;
    tm /= d;
    return c * t * t + b;
}

pub fn outQuad(t: f32, b: f32, c: f32, d: f32) f32 {
    var tm = t;
    tm /= d;
    return -c * t * (t - 2) + b;
}

pub fn inOutQuad(t: f32, b: f32, c: f32, d: f32) f32 {
    var tm = t;
    tm /= d / 2;
    if (tm < 1) return (c / 2) * tm * tm + b;
    tm -= 1;
    return (-c / 2) * (tm * (tm - 2) - 1) + b;
}

pub fn inSine(t: f32, b: f32, c: f32, d: f32) f32 {
    return -c * std.math.cos(t / d * (std.math.pi / 2.0)) + c + b;
}

pub fn outSine(t: f32, b: f32, c: f32, d: f32) f32 {
    return c * std.math.sin(t / d * (std.math.pi / 2.0)) + b;
}

pub fn inOutSine(t: f32, b: f32, c: f32, d: f32) f32 {
    return (-c / 2) * (std.math.cos(std.math.pi * t / d) - 1) + b;
}

pub fn inExpo(t: f32, b: f32, c: f32, d: f32) f32 {
    if (t == 0) return b;
    return c * std.math.pow(2, 10 * (t / d - 1)) + b;
}

pub fn outExpo(t: f32, b: f32, c: f32, d: f32) f32 {
    if (t == d) return b + c;
    return c * (-std.math.pow(2, -10 * t / d) + 1) + b;
}

pub fn inOutExpo(t: f32, b: f32, c: f32, d: f32) f32 {
    if (t == 0) return b;
    if (t == d) return b + c;
    t /= d / 2;
    if (t < 1) return (c / 2) * std.math.pow(2, 10 * (t - 1)) + b;
    t -= 1;
    return (c / 2) * (-std.math.pow(2, -10 * t) + 2) + b;
}

pub fn inCirc(t: f32, b: f32, c: f32, d: f32) f32 {
    t /= d;
    return -c * (std.math.sqrt(1 - t * t) - 1) + b;
}

pub fn outCirc(t: f32, b: f32, c: f32, d: f32) f32 {
    t = t / d - 1;
    return c * std.math.sqrt(1 - t * t) + b;
}

pub fn inOutCirc(t: f32, b: f32, c: f32, d: f32) f32 {
    t /= d / 2;
    if (t < 1) return (-c / 2) * (std.math.sqrt(1 - t * t) - 1) + b;
    t -= 2;
    return (c / 2) * (std.math.sqrt(1 - t * t) + 1) + b;
}
