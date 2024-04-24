const std = @import("std");
pub const c = @import("c_defs.zig").c;
const utils = @import("utils.zig");
const fft = @import("fft.zig");

const WinWidth = 1280;
const WinHeight = 768;

var tickOfTheClock: c.Music = undefined;
var frames: usize = undefined;
const shaderBufSize = 8024;
var shaderCodeBuffer: [shaderBufSize]u8 = .{0} ** shaderBufSize;
var textBoxMultiEditMode: bool = true;

var dotShader: c.Shader = undefined;
var lightningShader: c.Shader = undefined;

var background: c.Texture = undefined;
var zigLogoWhite: c.Texture = undefined;
var blankTexture: c.Texture = undefined;
var blankImg: c.Image = undefined;
var iTimeLoc0: c_int = -1;

var sfxLightning: c.Sound = undefined;
var sfxStaticElectricity: c.Sound = undefined;

const maxFlash: f32 = 100.0;
var flashLifetime: f32 = 0.0;
var flashTexture: c.Texture = undefined;
var flashImg: c.Image = undefined;

var initialState = .Start;
var bleedOut: f32 = 120.0;

pub fn main() !void {
    std.log.info("All your codebase are belong to us.", .{});
    visualizer();
}

fn visualizer() void {
    c.SetConfigFlags(c.FLAG_VSYNC_HINT);
    c.InitWindow(WinWidth, WinHeight, "All your codebase are belong to us.");
    utils.rlCenterWin(WinWidth, WinHeight);
    c.SetTraceLogCallback(CustomLog);
    c.InitAudioDevice();
    c.SetTargetFPS(60);

    defer c.CloseWindow();

    sfxLightning = c.LoadSound("../../resources/audio/lightning_strike.mp3");
    defer c.UnloadSound(sfxLightning);

    sfxStaticElectricity = c.LoadSound("../../resources/audio/static_electricity.mp3");
    defer c.UnloadSound(sfxStaticElectricity);

    // Lightning.
    blankImg = c.GenImageColor(WinWidth, 534, c.WHITE);
    defer c.UnloadImage(blankImg);
    blankTexture = c.LoadTextureFromImage(blankImg);
    defer c.UnloadTexture(blankTexture);

    // Flash texture.
    flashImg = c.GenImageColor(WinWidth, 768, c.WHITE);
    defer c.UnloadImage(flashImg);
    flashTexture = c.LoadTextureFromImage(flashImg);
    defer c.UnloadTexture(blankTexture);

    background = c.LoadTexture("../../resources/textures/synthwave.png");
    defer c.UnloadTexture(background);
    zigLogoWhite = c.LoadTexture("../../resources/textures/zig-mark-neg-white.png");
    defer c.UnloadTexture(zigLogoWhite);
    fft.FFT_Analyzer.reset();

    // Load Shaders
    dotShader = c.LoadShader(0, "../../resources/shaders/dots.fs");
    defer c.UnloadShader(dotShader);

    lightningShader = c.LoadShader(0, "../../resources/shaders/lightning.fs");
    defer c.UnloadShader(lightningShader);

    iTimeLoc0 = c.GetShaderLocation(lightningShader, "iTime");

    // Load Music
    tickOfTheClock = c.LoadMusicStream("../../resources/audio/Tick of the Clock.mp3");
    defer c.UnloadMusicStream(tickOfTheClock);

    c.AttachAudioStreamProcessor(tickOfTheClock.stream, fft.FFT_Analyzer.fft_process_callback);
    c.PlayMusicStream(tickOfTheClock);
    while (!c.WindowShouldClose()) {
        update();
        draw();
    }
}

var shaderLoadInterval: usize = 0;

// Note: I found this on Github, I can't seem to use variadic args in Zig with Raylib's TraceCallback for some reason.
// However, I still want to sniff the errors coming out of here and selectively handle some of them.
var shaderLoadHasErrors: bool = false;

fn CustomLog(msgType: c_int, text: [*c]const u8, args: [*c]c.struct___va_list_tag_1) callconv(.C) void {
    var timeStr: [64]u8 = undefined;
    var now = c.time(null);
    const tm_info = c.localtime(&now);

    _ = c.strftime(&timeStr, @sizeOf(@TypeOf(timeStr)), "%Y-%m-%d %H:%M:%S", tm_info);
    _ = c.printf("[%s] ", &timeStr);

    switch (msgType) {
        c.LOG_INFO => _ = c.printf("[INFO] : "),
        c.LOG_ERROR => _ = c.printf("[ERROR]: "),
        c.LOG_WARNING => {
            // This nonsense is to detect shader load errors, Raylib doesn't really expose error checking otherwise.
            const slice: []const u8 = text[0..7];
            if (std.mem.indexOf(u8, slice, "SHADER")) |idx| {
                std.log.debug("PROBLEM COMPILING SHADER!!!!", .{});
                std.log.debug("text => {s} @ idx: {d}", .{ text, idx });
            }
            shaderLoadHasErrors = true;
            _ = c.printf("[WARN] : ");
        },
        c.LOG_DEBUG => _ = c.printf("[DEBUG]: "),
        else => {},
    }

    _ = c.vprintf(text, args);
    _ = c.printf("\n");
}

var shaderSeconds: f32 = 0;
fn update() void {
    c.UpdateMusicStream(tickOfTheClock);
    frames = fft.FFT_Analyzer.analyze(c.GetFrameTime());

    if (shaderLoadInterval % (60 * 5) == 0) {
        const tmpShader = c.LoadShader(0, "../../resources/shaders/dots.fs");
        if (c.IsShaderReady(tmpShader)) {
            c.UnloadShader(dotShader);
            dotShader = tmpShader;
            std.log.debug("shader v{d} successfully swapped!", .{shaderLoadInterval});
        } else {
            std.log.err("shader v{d} unsuccessful - keeping original", .{shaderLoadInterval});
            std.posix.exit(0);
        }
    }

    //const t = c.GetTime();
    shaderSeconds += 0.029; //c.GetFrameTime() / 2.0;

    var r: f32 = @floatFromInt(c.GetRandomValue(0, 1000));
    r /= 10;
    if (r <= 1.0) {
        if (!c.IsSoundPlaying(sfxStaticElectricity)) {
            //std.log.debug("c.PlaySound(sfxLightning);", .{});
            c.PlaySound(sfxLightning);
            c.PlaySound(sfxStaticElectricity);
            flashLifetime = maxFlash;
        }
    }

    // Update uniforms for both shaders.
    //const iTimeLoc0 = c.GetShaderLocation(lightningShader, "iTime");
    c.SetShaderValue(lightningShader, iTimeLoc0, &shaderSeconds, c.SHADER_UNIFORM_FLOAT);

    const iTimeLoc = c.GetShaderLocation(dotShader, "iTime");
    c.SetShaderValue(dotShader, iTimeLoc, &shaderSeconds, c.SHADER_UNIFORM_FLOAT);
    shaderLoadInterval += 1;

    if (flashLifetime > 0) {
        flashLifetime *= 0.93;
        if (flashLifetime <= 0.001) {
            flashLifetime = 0;
        }
    }

    if (bleedOut > 0) {
        bleedOut -= 0.81;
        if (bleedOut <= 0.001) {
            bleedOut = 0.0;
        }
    }
}

fn draw() void {
    c.BeginDrawing();
    defer c.EndDrawing();
    c.ClearBackground(c.BLACK);

    c.DrawTexture(background, 0, 0, c.WHITE);

    // Now do lightening texture (BEHIND ZIG LOGO)
    c.BeginBlendMode(c.BLEND_ADDITIVE);
    c.BeginShaderMode(lightningShader);
    c.DrawTexture(blankTexture, 0, 0, c.WHITE);
    c.EndShaderMode();
    c.EndBlendMode();

    const logoXOffset = 10;
    const logoYOffset = 80;
    c.BeginBlendMode(c.BLEND_ADDITIVE);
    c.DrawTexture(
        zigLogoWhite,
        WinWidth / 2 - @divTrunc(zigLogoWhite.width, 2) - logoXOffset,
        WinHeight / 2 - @divTrunc(zigLogoWhite.height, 2) - logoYOffset,
        c.Fade(c.YELLOW, 1.0),
    );
    c.EndBlendMode();

    //c.DrawFPS(20, WinHeight - 40);
    {
        c.BeginShaderMode(dotShader);
        defer c.EndShaderMode();

        c.BeginBlendMode(c.BLEND_ADDITIVE);
        defer c.EndBlendMode();
        renderFFT(568, 400);
    }

    {
        c.BeginBlendMode(c.BLEND_ADDITIVE);
        defer c.EndBlendMode();
        const slogan = "All your codebase are belong to us.";
        const fontSize = 24;
        const textSize = c.MeasureText(slogan, fontSize);
        c.DrawText(slogan, WinWidth / 2 - @divTrunc(textSize, 2), WinHeight - 40, fontSize, c.Fade(c.WHITE, 0.5));
    }

    if (flashLifetime > 0) {
        c.BeginBlendMode(c.BLEND_ADDITIVE);
        defer c.EndBlendMode();
        c.DrawTexture(flashTexture, 0, 0, c.Fade(c.WHITE, (1.0 / maxFlash) * flashLifetime));
    }

    c.DrawTexture(flashTexture, 0, 0, c.Fade(c.BLACK, (1.0 / 120.0) * bleedOut));
}

fn renderFFT(bottomY: c_int, height: c_int) void {
    const leftX = 0;
    const width: c_int = @intCast(WinWidth / frames);
    const xSpacing = 40;
    const full_degrees: f32 = 360.0 / @as(f32, @floatFromInt(frames));

    // This translation was just to slightly shifter over the FFT bars.
    c.rlPushMatrix();
    defer c.rlPopMatrix();
    c.rlTranslatef(-20, 0, 0);
    for (0..frames) |idx| {
        const t = if (true) fft.FFT_Analyzer.smoothed()[idx] else fft.FFT_Analyzer.smeared()[idx];
        const inverse_height = (@as(f32, @floatFromInt(height)) * t);
        const h: c_int = @intFromFloat(inverse_height);
        var clr = c.ColorFromHSV(@as(f32, @floatFromInt(idx)) * full_degrees, 1.0, 1.0);
        clr = c.Fade(clr, 0.7);
        const x = @as(c_int, @intCast(leftX + (idx) * xSpacing));
        c.DrawRectangle(x, bottomY - h, width, h, clr);
    }
}
