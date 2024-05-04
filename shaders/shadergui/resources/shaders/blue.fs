#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

uniform vec2 iResolution = vec2(179, 191);
uniform vec2 iChannelResolution = vec2(179, 191);
uniform float iTime = 0.4;
uniform sampler2D texture0;

// Output fragment color
out vec4 finalColor;

// Check out water effect: https://www.shadertoy.com/view/MdjBDh

#define PI 3.14159265359
#define SAMPLES 2
#define MAG 0.2
#define TOLERANCE 0.2

void main() {
    // https://www.shadertoy.com/view/MlcSW2
	vec2 uv = gl_FragCoord.xy / iResolution.xy;//gl_FragCoord.xy / iResolution.xy;
    //Animate the cat
    // uv.x /= 6.0;
    // uv.x += (0.15625 * mod(floor(iTime * 10.0), 6.0));
    // uv.x -= 0.01;
    //----------------
    
    //vec3 targetCol = vec3(sin(iTime), cos(iTime), 1.0); //The color of the outline
    vec3 targetCol = vec3(0.0, 0.0, 1.0);
    
    vec4 col = vec4(0);
    
    float rads = ((360.0 / float(SAMPLES)) * PI) / 180.0;	//radians based on SAMPLES
    
    for(int i = 0; i < SAMPLES; i++) {
        if(col.a < TOLERANCE) {
        	float r = float(i + 1) * rads;
    		vec2 offset = vec2(cos(r) * TOLERANCE, -sin(r)) * MAG; //calculate vector based on current radians and multiply by magnitude
    		col = texture(texture0, uv + offset);	//render the texture to the pixel on an offset UV
            if(col.a > 0.0) {
                col.xyz = targetCol;
            }
        }
    }
    
    vec4 tex = texture(texture0, uv);
    if(tex.a > 0.0) {
     	col = tex;   //if the centered texture's alpha is greater than 0, set col to tex
    }
    
    finalColor = col;
}