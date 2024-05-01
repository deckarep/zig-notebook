#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

uniform float iTime;
uniform vec2 iResolution = vec2(1280, 768); // Hardcode for now, should be passed in.
uniform vec3 modulate = vec3(1.0);
uniform float useFrame = 0.0;
uniform sampler2D texture0; // (default - implicitely passed via Raylib)
uniform sampler2D texture1; // texture1 (blurbuffer)

vec2 uv;

// Per original code: range for these values is -1.0 - 1.0, default=0.0.
// uniform float cfgCurvature = 0.0;
// uniform float cfgScanlines = 0.0;
// uniform float cfgShadowMask = 0.0; 
// uniform float cfgSeparation = 0.0; 
// uniform float cfgGhosting = 0.0; 
// uniform float cfgNoise = 0.0; 
// uniform float cfgFlicker = 0.0; 
// uniform float cfgVignette = 0.0; 
// uniform float cfgDistortion = 0.0; 
// uniform float cfgAspect_lock;
// uniform float cfgHpos = 0.0; 
// uniform float cfgVpos = 0.0; 
// uniform float cfgHsize = 0.0; 
// uniform float cfgVsize = 0.0; 
// uniform float cfgContrast = 0.0; 
// uniform float cfgBrightness = 0.0; 
// uniform float cfgSaturation = 0.0; 
// uniform float cfgDegauss = 0.0; 

// Output fragment color
out vec4 finalColor;

vec3 tsample(sampler2D samp, vec2 tc, float offs, vec2 resolution) {
    vec3 s = pow(abs(texture(samp, vec2( tc.x, 1.0 - tc.y)).rgb), vec3(2.2));
    return s * vec3(1.25);
}

vec3 filmic( vec3 LinearColor ) {
    vec3 x = max(vec3(0.0), LinearColor - vec3(0.004));
    return ( x *(6.2 * x + 0.5)) / (x * (6.2 * x + 1.7) + 0.06);
}

vec2 curve( vec2 uv ) {
    uv = (uv - 0.5) * 2.0;
    uv *= vec2(1.049, 1.042);
    uv -= vec2(-0.008, 0.008);
    uv.x *= 1.0 + pow((abs(uv.y) / 5.0), 2.0);
    uv.y *= 1.0 + pow((abs(uv.x) / 4.0), 2.0);
    uv  = (uv / 2.0) + 0.5;
    return uv;
}

float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898, 78.233))) * 43758.5453);
}
    
void main(void) {
    // Computing uv instead of varying like glsl 120.
    // Normalized pixel coordinates (from 0 to 1)
    uv = gl_FragCoord.xy / iResolution.xy;
    
    // Curve
    vec2 curved_uv = mix(curve(uv), uv, 0.4 );
    float scale = 0.04;
    vec2 scuv = curved_uv * (1.0 - scale) + scale / 2.0 + vec2(0.003, -0.001);
    scuv = curved_uv;

    // Main color, Bleed
    vec3 col;
    float x = sin(0.1 * iTime + curved_uv.y * 13.0) * sin(0.23 * iTime + curved_uv.y * 19.0) * sin(0.3 + 0.11 * iTime + curved_uv.y * 23.0) * 0.0012;
    float o = sin(gl_FragCoord.y / 1.5) / iResolution.x;
    x += o * 0.25;
    x *= 0.2;
    col.r = tsample(texture0, vec2(x + scuv.x + 0.0009, scuv.y + 0.0009), iResolution.y / 800.0, iResolution).x + 0.02;
    col.g = tsample(texture0, vec2(x + scuv.x + 0.0000, scuv.y - 0.0011), iResolution.y / 800.0, iResolution).y + 0.02;
    col.b = tsample(texture0, vec2(x + scuv.x - 0.0015, scuv.y + 0.0000), iResolution.y / 800.0, iResolution).z + 0.02;
    float i = clamp(col.r * 0.299 + col.g * 0.587 + col.b * 0.114, 0.0, 1.0);
    i = pow(1.0 - pow(i, 2.0), 1.0);
    i = (1.0 - i) * 0.85 + 0.15;

    // Ghosting - needs to sample from blur buffer.
    float ghs = 3.15; // 0.15 Turning this up made a difference, now i see it.
    vec3 r = tsample(texture1, vec2(x - 0.014 * 1.0, -0.027) * 0.85 + 0.007 * vec2(0.35 * sin(1.0 / 7.0 + 15.0 * curved_uv.y + 0.9 * iTime),
        0.35 * sin(2.0 / 7.0 + 10.0 * curved_uv.y + 1.37 * iTime)) + vec2(scuv.x + 0.001, scuv.y + 0.001),
        5.5 + 1.3 * sin(3.0 / 9.0 + 31.0 * curved_uv.x + 1.70 * iTime), iResolution).xyz * vec3(0.5, 0.25, 0.25);
    vec3 g = tsample(texture1, vec2(x - 0.019 * 1.0, -0.020) * 0.85 + 0.007 * vec2( 0.35 * cos(1.0 / 9.0 + 15.0 * curved_uv.y + 0.5 * iTime),
        0.35 * sin(2.0 / 9.0 + 10.0 * curved_uv.y + 1.50 * iTime)) + vec2(scuv.x + 0.000, scuv.y - 0.002),
        5.4 + 1.3 * sin(3.0 / 3.0 + 71.0 * curved_uv.x + 1.90 * iTime), iResolution).xyz * vec3(0.25, 0.5, 0.25);
    vec3 b = tsample(texture1, vec2(x - 0.017 * 1.0, -0.003) * 0.85 + 0.007 * vec2(0.35 * sin(2.0 / 3.0 + 15.0 * curved_uv.y + 0.7 * iTime),
        0.35 * cos(2.0 / 3.0 + 10.0 * curved_uv.y + 1.63 * iTime)) + vec2(scuv.x - 0.002, scuv.y + 0.000),
        5.3 + 1.3 * sin(3.0 / 7.0 + 91.0 * curved_uv.x + 1.65 * iTime), iResolution).xyz * vec3(0.25, 0.25, 0.5);

    col += vec3(ghs * (1.0 - 0.299)) * pow(clamp(vec3(3.0) * r, vec3(0.0), vec3(1.0)), vec3(2.0)) * vec3(i);
    col += vec3(ghs * (1.0 - 0.587)) * pow(clamp(vec3(3.0) * g, vec3(0.0), vec3(1.0)), vec3(2.0)) * vec3(i);
    col += vec3(ghs * (1.0 - 0.114)) * pow(clamp(vec3(3.0) * b, vec3(0.0), vec3(1.0)), vec3(2.0)) * vec3(i);

    // Level adjustment (curves)
    col *= vec3(0.95, 1.05, 0.95);
    col = clamp(col * 1.3 + 0.75 * col * col + 1.25 * col * col * col * col * col, vec3(0.0), vec3(10.0));

    // Vignette
    float vig = (0.1 + 1.0 * 16.0 * curved_uv.x * curved_uv.y * (1.0 - curved_uv.x) * (1.0 - curved_uv.y));
    vig = 1.3 * pow(vig, 0.5);
    col *= vig;

    // Scanlines
    float scans = clamp(0.35 + 0.18 * sin(6.0 * iTime + curved_uv.y * iResolution.y * 1.5), 0.0, 1.0);
    float s = pow(scans, 0.9);
    col *= vec3(s);

    // Vertical lines (shadow mask)
    col *= 1.0 - 0.23 * (clamp((mod(gl_FragCoord.xy.x, 30.0)) / 2.0, 0.0, 1.0));

    // Tone map
    col = filmic( col );

    // Noise
    // INVESTIGATE THESE LINES (tabbed over)
    //       vec2 seed = floor(curved_uv*iResolution.xy*vec2(0.5))/iResolution.xy;
    vec2 seed = curved_uv*iResolution.xy;
    //vec2 seed = curved_uv;
    //col -= 0.015 * pow(vec3(rand( seed + iTime ), rand( seed + iTime * 2.0 ), rand( seed + iTime * 3.0 ) ), vec3(1.5) );

    // Flicker - ?? rc: Don't really see this effect, investigate.
    col *= (1.0 - 0.004 * (sin(50.0 * iTime + curved_uv.y * 2.0) * 0.5 + 0.5));

    // // Clamp
    if (curved_uv.x < 0.0 || curved_uv.x > 1.0)
        col *= 0.0;
    if (curved_uv.y < 0.0 || curved_uv.y > 1.0)
        col *= 0.0;

    // Frame
    vec2 fscale = vec2(-0.019, -0.018);
    vec4 f = texture(texture0, uv * ((1.0) + 2.0 * fscale) - fscale - vec2(-0.0, 0.005));
    f.xyz = mix( f.xyz, vec3(0.5, 0.5, 0.5), 0.5 );
    float fvig = clamp(-0.00 + 512.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y), 0.2, 0.8 );
    col = mix( col, mix( max( col, 0.0), pow( abs( f.xyz ), vec3( 1.4 ) ) * fvig, f.w * f.w), vec3( useFrame ) );

    finalColor = vec4( col, 1.0 ); //* vec4( modulate, 1.0 );
}