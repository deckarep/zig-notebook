#version 330

#define CHECKER_SCALE 50. // Scale

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// NOTE: I don't know why I have to double up the width/height and negate y to flip the image
// for the image to be full size and correct. Nevertheless it works.
// For a render texture, the resolution is correct. ??
uniform vec2 iResolution = vec2(1280, 768); //vec2(1280*2, -(768*2));
// These need to be small values.
uniform vec2 blur = vec2(0.05, 0.05);
uniform sampler2D texture0;

// // Output fragment color
out vec4 finalColor;

vec2 uv;

void main(void) {
    // Computing uv instead of varying like glsl 120.
    // Normalized pixel coordinates (from 0 to 1)
    uv = gl_FragCoord.xy / iResolution.xy;

    vec4 sum = texture( texture0, uv ) * 0.2270270270;
    sum += texture(texture0, vec2( uv.x - 4.0 * blur.x, uv.y - 4.0 * blur.y ) ) * 0.0162162162;
    sum += texture(texture0, vec2( uv.x - 3.0 * blur.x, uv.y - 3.0 * blur.y ) ) * 0.0540540541;
    sum += texture(texture0, vec2( uv.x - 2.0 * blur.x, uv.y - 2.0 * blur.y ) ) * 0.1216216216;
    sum += texture(texture0, vec2( uv.x - 1.0 * blur.x, uv.y - 1.0 * blur.y ) ) * 0.1945945946;
    sum += texture(texture0, vec2( uv.x + 1.0 * blur.x, uv.y + 1.0 * blur.y ) ) * 0.1945945946;
    sum += texture(texture0, vec2( uv.x + 2.0 * blur.x, uv.y + 2.0 * blur.y ) ) * 0.1216216216;
    sum += texture(texture0, vec2( uv.x + 3.0 * blur.x, uv.y + 3.0 * blur.y ) ) * 0.0540540541;
    sum += texture(texture0, vec2( uv.x + 4.0 * blur.x, uv.y + 4.0 * blur.y ) ) * 0.0162162162;
    finalColor = sum;
}