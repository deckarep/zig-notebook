#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

uniform vec2 iResolution = vec2(272, 185);
uniform float iTime = 0.4;
uniform sampler2D texture0;

// Output fragment color
out vec4 finalColor;

void main() {
    vec4 col = texture(texture0, fragTexCoord);
    finalColor = vec4(col.r, col.r, col.r, col.a);
}