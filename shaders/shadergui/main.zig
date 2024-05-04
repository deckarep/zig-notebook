const std = @import("std");
pub const c = @import("c_defs.zig").c;
const utils = @import("utils.zig");
const fft = @import("fft.zig");
const ms = @import("multishader.zig");

const WinWidth = 1280;
const WinHeight = 768;

var tickOfTheClock: c.Music = undefined;
var frames: usize = undefined;
const shaderBufSize = 8024;
var shaderCodeBuffer: [shaderBufSize]u8 = .{0} ** shaderBufSize;
var textBoxMultiEditMode: bool = true;

var dotShader: c.Shader = undefined;
var lightningShader: c.Shader = undefined;

var crtBlurShader: c.Shader = undefined;
var crtShader: c.Shader = undefined;
var crtRenderTexture: c.RenderTexture = undefined;
var crtRenderTexturePass2: c.RenderTexture = undefined;
var blurredImg: c.Image = undefined;
var crtShaderTexture1Loc: c_int = undefined;
var fooTexture: c.Texture = undefined;

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

// Multishader test objects
var alfredTexture: c.Texture = undefined;
var redShader: c.Shader = undefined;
var blueShader: c.Shader = undefined;
var swirlShader: c.Shader = undefined;
var crossHatchShader: c.Shader = undefined;
var fishEyeShader: c.Shader = undefined;

const codebase = "All your codebase are belong to us.";

pub fn main() !void {
    std.log.info(codebase, .{});
    try visualizer();
}

fn embedAndLoadSound(comptime path: []const u8) c.Sound {
    const p = @embedFile(path);
    const wav = c.LoadWaveFromMemory(".mp3", p, p.len);
    const snd = c.LoadSoundFromWave(wav);
    return snd;
}

fn embedAndLoadMusicStream(comptime path: []const u8) c.Music {
    const p = @embedFile(path);
    const stream = c.LoadMusicStreamFromMemory(".mp3", p, p.len);
    return stream;
}

fn embedAndLoadTexture(comptime path: []const u8) c.Texture {
    const img = embedAndLoadImage(path);
    const txtr = c.LoadTextureFromImage(img);
    return txtr;
}

fn embedAndLoadImage(comptime path: []const u8) c.Image {
    const p = @embedFile(path);
    const img = c.LoadImageFromMemory(".png", p, p.len);
    return img;
}

fn embedAndLoadShader(comptime path: []const u8) c.Shader {
    const p = @embedFile(path);
    if (std.mem.eql(u8, path, "blue.fs")) {
        std.log.debug("Loading blue.fs shader...", .{});
    }
    const shdr = c.LoadShaderFromMemory(null, p);
    if (std.mem.eql(u8, path, "blue.fs")) {
        std.log.debug("Load blue.fs complete...", .{});
    }
    return shdr;
}

fn visualizer() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = false,
        .safety = true,
    }){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            std.log.err("Leaks were discovered!", .{});
        }
    }

    var argsIter = try std.process.argsWithAllocator(allocator);
    defer argsIter.deinit();
    while (argsIter.next()) |arg| {
        std.log.debug("arg val => {s}", .{arg});
    }

    c.SetConfigFlags(c.FLAG_VSYNC_HINT | c.FLAG_WINDOW_RESIZABLE);
    c.InitWindow(WinWidth, WinHeight, codebase);
    utils.rlCenterWin(WinWidth, WinHeight);
    c.SetTraceLogCallback(CustomLog);
    c.InitAudioDevice();
    c.SetTargetFPS(60);

    // Setup Dear ImGui context
    const ctx = c.igCreateContext(null);
    defer c.igDestroyContext(ctx);

    const ioPtr = c.igGetIO();
    ioPtr.*.ConfigFlags |= c.ImGuiConfigFlags_NavEnableKeyboard; // Enable Keyboard Controls
    ioPtr.*.ConfigFlags |= c.ImGuiConfigFlags_NavEnableGamepad; // Enable Gamepad Controls

    // set docking
    // #ifdef IMGUI_HAS_DOCK
    //     ioptr->ConfigFlags |= ImGuiConfigFlags_DockingEnable;       // Enable Docking
    //     ioptr->ConfigFlags |= ImGuiConfigFlags_ViewportsEnable;     // Enable Multi-Viewport / Platform Windows
    // #endif

    // Setup Dear ImGui style
    c.igStyleColorsDark(null);

    // Setup Platform/Renderer backends
    _ = c.ImGui_ImplRaylib_Init();
    defer c.ImGui_ImplRaylib_Shutdown();

    _ = c.ImFontAtlas_AddFontDefault(ioPtr.*.Fonts, null);
    c.rligSetupFontAwesome();

    // required to be called to cache the font texture with raylib
    c.ImGui_ImplRaylib_BuildFontAtlas();

    defer c.CloseWindow();

    sfxLightning = embedAndLoadSound("resources/audio/lightning_strike.mp3");
    defer c.UnloadSound(sfxLightning);

    sfxStaticElectricity = embedAndLoadSound("resources/audio/static_electricity.mp3");
    defer c.UnloadSound(sfxStaticElectricity);

    fooTexture = c.LoadTexture("foo.png");
    defer c.UnloadTexture(fooTexture);

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

    background = embedAndLoadTexture("resources/textures/synth-car.png");
    defer c.UnloadTexture(background);
    zigLogoWhite = embedAndLoadTexture("resources/textures/zig-mark-neg-white.png");
    defer c.UnloadTexture(zigLogoWhite);
    fft.FFT_Analyzer.reset();

    // Load Multishader test shaders
    alfredTexture = c.LoadTexture("resources/textures/alfred_transparent.png");
    defer c.UnloadTexture(alfredTexture);
    redShader = embedAndLoadShader("resources/shaders/red.fs");
    defer c.UnloadShader(redShader);

    blueShader = embedAndLoadShader("resources/shaders/pixelshader.fs");
    defer c.UnloadShader(blueShader);

    swirlShader = embedAndLoadShader("resources/shaders/swirl.fs");
    defer c.UnloadShader(swirlShader);

    crossHatchShader = embedAndLoadShader("resources/shaders/crosshatch.fs");
    defer c.UnloadShader(crossHatchShader);

    fishEyeShader = embedAndLoadShader("resources/shaders/fisheye.fs");
    defer c.UnloadShader(fishEyeShader);

    // Load Shaders
    dotShader = embedAndLoadShader("resources/shaders/dots.fs");
    defer c.UnloadShader(dotShader);

    lightningShader = embedAndLoadShader("resources/shaders/lightning.fs");
    defer c.UnloadShader(lightningShader);

    // Blur shader
    // I guess i need to port shaders to the right version to work on mac. 120 doesn't compile.
    // I guess mac requires 330, so this blur.fs won't work as-is.
    crtRenderTexture = c.LoadRenderTexture(1280, 768);
    crtRenderTexturePass2 = c.LoadRenderTexture(1280, 768);
    defer c.UnloadRenderTexture(crtRenderTexture);
    defer c.UnloadRenderTexture(crtRenderTexturePass2);
    crtBlurShader = embedAndLoadShader("resources/shaders/crtblur.fs");
    defer c.UnloadShader(crtBlurShader);
    crtShader = embedAndLoadShader("resources/shaders/crt.fs");
    defer c.UnloadShader(crtShader);

    crtShaderTexture1Loc = c.GetShaderLocation(crtShader, "texture1");

    // Apply blur to background, this occurs just once to fill the sampler2d texture blurbuffer.
    c.BeginTextureMode(crtRenderTexturePass2);
    c.BeginShaderMode(crtBlurShader);
    c.DrawTexture(background, 0, 0, c.WHITE);
    c.EndShaderMode();
    c.EndTextureMode();
    blurredImg = c.LoadImageFromTexture(crtRenderTexturePass2.texture);

    iTimeLoc0 = c.GetShaderLocation(lightningShader, "iTime");

    // Load Music
    tickOfTheClock = embedAndLoadMusicStream("resources/audio/Demon Dance.mp3");
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
                shaderLoadHasErrors = true;
            }
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
    // Poll and handle events (inputs, window resize, etc.)
    // You can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if dear imgui wants to use your inputs.
    // - When io.WantCaptureMouse is true, do not dispatch mouse input data to your main application, or clear/overwrite your copy of the mouse data.
    // - When io.WantCaptureKeyboard is true, do not dispatch keyboard input data to your main application, or clear/overwrite your copy of the keyboard data.
    // Generally you may always pass all inputs to dear imgui, and hide them from your application based on those two flags.
    _ = c.ImGui_ImplRaylib_ProcessEvents();

    c.UpdateMusicStream(tickOfTheClock);
    frames = fft.FFT_Analyzer.analyze(c.GetFrameTime());

    if (true and shaderLoadInterval % (30 * 5) == 0) {
        // Dynamically refresh dot.fs shader.
        if (false and c.FileExists("resources/shaders/dots.fs")) {
            const tmpShader = c.LoadShader(0, "resources/shaders/dots.fs");
            if (c.IsShaderReady(tmpShader)) {
                c.UnloadShader(dotShader);
                dotShader = tmpShader;
                std.log.debug("shader v{d} successfully swapped!", .{shaderLoadInterval});
            } else {
                std.log.err("shader v{d} unsuccessful - keeping original", .{shaderLoadInterval});
                std.posix.exit(0);
            }
        } else {
            std.log.warn("dynamic shader: dot.fs is not found...IGNORING!", .{});
        }

        // Dynamically refresh crt.fs shader.
        if (true and c.FileExists("resources/shaders/crt.fs")) {
            const tmpShader = c.LoadShader(0, "resources/shaders/crt.fs");
            if (c.IsShaderReady(tmpShader)) {
                c.UnloadShader(crtShader);
                crtShader = tmpShader;
                std.log.debug("shader v{d} successfully swapped!", .{shaderLoadInterval});
            } else {
                std.log.err("shader v{d} unsuccessful - keeping original", .{shaderLoadInterval});
                std.posix.exit(0);
            }
        } else {
            std.log.warn("dynamic shader: crt.fs is not found...IGNORING!", .{});
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

    const crtTimeLoc = c.GetShaderLocation(crtShader, "iTime");
    c.SetShaderValue(crtShader, crtTimeLoc, &shaderSeconds, c.SHADER_UNIFORM_FLOAT);

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

var showAnotherWindow = false;
fn igPreRender() void {
    c.ImGui_ImplRaylib_NewFrame();
    c.igNewFrame();

    var showDemoWindow = false;

    if (showDemoWindow) {
        c.igShowDemoWindow(&showDemoWindow);
    }

    {
        _ = c.igBegin("Hello, world!", null, 0);
        defer c.igEnd();

        c.igText("Some fuckin' text eh?");
        _ = c.igCheckbox("Another Window", &showAnotherWindow);
    }

    if (showAnotherWindow) {
        _ = c.igBegin("Another Window", &showAnotherWindow, 0); // Pass a pointer to our bool variable (the window will have a closing button that will clear the bool when clicked)
        defer c.igEnd();
        c.igText("Hello from another window!");

        const N_SAMPLES = 100;
        var samples: [N_SAMPLES]f32 = undefined;
        for (0..N_SAMPLES) |n| {
            samples[n] = @sin(@as(f32, @floatFromInt(n)) * 0.2 + @as(f32, @floatCast(c.igGetTime())) * 1.5);
        }

        // The C++ regular code has default args, but the Zig ends up flatten such calls and expanding them out into full arg style function variants.
        c.igPlotLines_FloatPtr("Samples", &samples, N_SAMPLES, 0, null, c.igGET_FLT_MAX(), c.igGET_FLT_MAX(), .{ .x = 0, .y = 100 }, @sizeOf(f32));

        const buttonSize = c.ImVec2{ .x = 0, .y = 0 };
        if (c.igButton("Close me", buttonSize)) {
            showAnotherWindow = false;
        }

        // Display contents in a scrolling region
        c.igTextColored(.{ .x = 1, .y = 1, .z = 0, .w = 0 }, "Important Stuff");
        _ = c.igBeginChild_Str("Important Stuff", .{ .x = 0, .y = 0 }, 0, 0);
        defer c.igEndChild();
        for (0..50_000) |n| {
            c.igText("%04d: Some text", n);
        }
    }

    // Must be last command.
    c.igRender();
}

fn igShowFrame() void {
    c.ImGui_ImplRaylib_RenderDrawData(c.igGetDrawData());
}

var errorDelayCounter: usize = 0;
fn draw() void {
    if (errorDelayCounter == 10) {
        std.process.exit(99);
    }
    if (shaderLoadHasErrors) {
        errorDelayCounter += 1;
    }

    // imgGui drawing happens before raylib Begin/EndDrawing
    // Then, within the Raylib Begin/EndDrawing the render of imgui frame is requested.
    igPreRender();

    // Test ApplyMultiShader.
    //const shaderCollect = [_]c.Shader{blueShader, redShader, swirlShader};
    const shaderCollect = &.{blueShader};
    const rt = ms.GetMultiShadedRT(shaderCollect, alfredTexture);
    defer ms.UnloadMultiShadedRT();

    // apply crt shader.
    c.BeginTextureMode(crtRenderTexture);
    c.BeginShaderMode(crtShader);
    // AHA! shader value must be set in right context!
    c.SetShaderValueTexture(crtShader, crtShaderTexture1Loc, crtRenderTexturePass2.texture); //fooTexture);
    c.DrawTexture(background, 0, 0, c.WHITE);
    c.EndShaderMode();
    c.EndTextureMode();

    c.BeginDrawing();
    defer c.EndDrawing();
    c.ClearBackground(c.BLACK);

    // NOTE: Render texture must be y-flipped due to default OpenGL coordinates (left-bottom)
    c.DrawTextureRec(
        crtRenderTexture.texture,
        .{ .x = 0, .y = 0, .width = 1280, .height = -768 },
        .{ .x = 0, .y = 0 },
        c.WHITE,
    );

    // This line is just to test the pass 2, but it shouldn't be drawn.
    if (false) {
        c.DrawTextureRec(
            crtRenderTexturePass2.texture,
            .{ .x = 0, .y = 0, .width = 1280, .height = -768 },
            .{ .x = 0, .y = 0 },
            c.WHITE,
        );
    }

    if (true) {
        c.DrawTextureRec(
            rt.texture,
            .{ .x = 0, .y = 0, .width = @floatFromInt(alfredTexture.width), .height = @floatFromInt(-alfredTexture.height) },
            .{ .x = 200, .y = 200 },
            c.WHITE,
        );

        c.BeginShaderMode(blueShader);
        defer c.EndShaderMode();
        c.DrawTexture(alfredTexture, 900, 200, c.WHITE);
    }

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

    c.DrawFPS(20, WinHeight - 40);
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

    // imggui last for now
    igShowFrame();
}

fn renderFFT(bottomY: c_int, height: c_int) void {
    const leftX = 15;
    const width: c_int = @intCast((WinWidth) / frames);
    const xSpacing = 30;
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
