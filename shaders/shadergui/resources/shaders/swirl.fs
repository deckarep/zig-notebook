#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// This needs to get passed in as well.
uniform vec2 center = vec2(90, 96);

// Output fragment color
out vec4 finalColor;

// NOTE: Render size values should be passed from code
const float renderWidth = 179;
const float renderHeight = 191;

float radius = 250.0; // How large the eye of the twirl is.
float angle = .1; // How much twirl.

void main() {
    vec2 texSize = vec2(renderWidth, renderHeight);
    vec2 tc = fragTexCoord*texSize;
    tc -= center;

    float dist = length(tc);

    if (dist < radius) {
        float percent = (radius - dist)/radius;
        float theta = percent*percent*angle*8.0;
        float s = sin(theta);
        float c = cos(theta);

        tc = vec2(dot(tc, vec2(c, -s)), dot(tc, vec2(s, c)));
    }

    tc += center;
    vec4 color = texture(texture0, tc/texSize)*colDiffuse * fragColor;

    // Use this to do the real swirl.
    finalColor = vec4(color.rgb, color.a);

    // Use this for vanilla testing.
    //finalColor = texture(texture0, fragTexCoord);
}