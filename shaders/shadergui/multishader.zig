const std = @import("std");
pub const c = @import("c_defs.zig").c;

// Two concepts:
// 1. Simple MultiShader - just two or more shaders applied to a given RenderTexture.
// a. The shaders are independent from each other and applied in the given order, one after the other.
// b. Think of this as just applying two or more successive shaders to a single Texture.

// It would be a nice to plugin in uniforms
// It would be nice to also *cache* or at least provide a way for the user to have a snapshot as an optimization.
// ie, no need to do multi-pass shaders per frame if it only needs to be done once.

var rtPool: [10]RT = undefined;
var poolInitialized = false;
const RT = struct {
    used: bool,
    rt: c.RenderTexture,
};

pub const MultiShaderCtx = struct {
    final: c.RenderTexture,
};

pub fn getFreeRenderTexture(srcTexture: c.Texture) c.RenderTexture {
    // Problem: we're creating fixed w/h render textures...so this code is not yet generic across any size.
    // Yet, we want to keep a pool.

    // In order to support that we should probably use the heap, and create a pool per dimension set.
    // We expect textures to largely be consistent in size when doing multiple shaders.
    if (!poolInitialized) {
        for (&rtPool) |*item| {
            item.used = false;
            item.rt = c.LoadRenderTexture(srcTexture.width, srcTexture.height);
        }
    }

    poolInitialized = true;

    for (&rtPool) |*item| {
        if (!item.used) {
            c.BeginTextureMode(item.rt);
            defer c.EndTextureMode();
            c.ClearBackground(c.Color{ .r = 0, .g = 0, .b = 0, .a = 0 });
            item.used = true;
            return item.rt;
        }
    }

    unreachable;
}

pub fn GetMultiShadedRT(shaders: []const c.Shader, srcTexture: c.Texture) c.RenderTexture {
    var currentTexture = srcTexture;
    var lastRT: c.RenderTexture = undefined;

    var lastIdx: usize = undefined;
    for (shaders, 0..) |*shader, idx| {
        const rt = getFreeRenderTexture(srcTexture);
        lastRT = rt;
        c.BeginTextureMode(rt);
        defer c.EndTextureMode();

        c.BeginShaderMode(shader.*);
        defer c.EndShaderMode();

        c.DrawTexture(currentTexture, 0, 0, c.WHITE);

        // Capture the rendered texture so it's fed into the next shader.
        currentTexture = rt.texture;
        lastIdx = idx;
    }

    // If the last one is odd, do one extra draw with no shader to turn right side up.
    // This is a bit hacky, but it standardizes the output to always be rightside up.
    if (lastIdx % 2 != 0) {
        const tmpRT = getFreeRenderTexture(srcTexture);
        c.BeginTextureMode(tmpRT);
        defer c.EndTextureMode();
        c.DrawTexture(currentTexture, 0, 0, c.WHITE);
        lastRT = tmpRT;
    }

    return lastRT;
}

pub fn UnloadMultiShadedRT() void {
    for (&rtPool) |*item| {
        item.used = false;
    }
}

// 2. Shader Pipeline - (applies a shader to a texture, feeds texture into the next shader as a texture buffer)
// a. Shader drawing logic depends on previous texture buffer AFTER post-processing of previous shader.
// b. Use this for advanced effects where a design of one shader depends on the data from the previous.
