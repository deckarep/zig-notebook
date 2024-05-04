// From Cat game.

#version 330

in vec2 fragTexCoord;
in vec4 fragColor;
uniform sampler2D texture0;
out vec4 finalColor;

vec2 uv_aa_smoothstep(vec2 uv, vec2 res, float width) {
    vec2 pixels = uv * res;

    vec2 pixels_floor = floor(pixels + 0.5);
    vec2 pixels_fract = fract(pixels + 0.5);
    vec2 pixels_aa = fwidth(pixels) * width * 0.5;
    pixels_fract = smoothstep( vec2(0.5) - pixels_aa, vec2(0.5) + pixels_aa, pixels_fract );

    return (pixels_floor + pixels_fract - 0.5) / res;
}

void main() {
    //ivec2 tsize = textureSize(texture0, 0); // In Cat and Onions, but this function: textureSize doesn't work for me, why? same version too.
    ivec2 tsize = ivec2(30, 30);
    finalColor = fragColor * texture(texture0, uv_aa_smoothstep(fragTexCoord, tsize, 1.5));
}