#version 330

#define DOT 0.4 //for larger spacing + smaller dots, decrease value below 0.4
#define RECT 0.3

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform float iTime;

const float alpha_trans = 0.6;//1.0;
const float pixSizeX = 9.0; //16.0; //width of LED in pixel
const float pixSizeY = 9.0; //16.0; //height of LED in pixel
vec3 dmdColor = vec3(0.8, 0.4, 0.1); //specify color of Dotmatrix LED
float pixThreshold = 0.45; //specify at what threshold a pixel will become either on or off
bool flickering = false;//do you want flickering enabled? emulates line wise updating of LEDs, 0.0 = disabled, 1.0 = enable
float dotOrRect = RECT; //DOT or RECT - LEDs in round or rectangular shape

// Output fragment color
out vec4 finalColor;

// NOTE: Add here your custom variables
uniform vec2 resolution = vec2(10, 10);//vec2(560*2,292*2);//vec2(500*2, -400*2); //vec2(520, 292);

void main()
{
    //indexing shenanigans needed for color averaging
    float indexX = gl_FragCoord.x;
    float indexY = -gl_FragCoord.y; //- .5;
    float cellX = (floor(indexX / pixSizeX)* pixSizeX) + 400;
    float cellY = (floor(indexY / pixSizeY)* pixSizeY) + 465;
    
    //handle mouse input, slide between greyscale and binary pixels
    float binary = 0.0;
   
    //sample texture color and create big dot matrix pixel from video
    //way overkill for this application, single sample should be enough, but here we go anyway..
    float texAvg = 0.0;
    
    //fast version of above nested loop
    vec2 currUV = vec2(cellX/resolution.x, cellY/resolution.y);
    vec3 currTexVal = texture(texture0, currUV).rgb; 
    // Original amounts
    //texAvg = 0.3*currTexVal.r + 0.59*currTexVal.g + 0.11*currTexVal.b;
    texAvg = 0.6*currTexVal.r + 0.89*currTexVal.g + 0.31*currTexVal.b;
    
    //switch pixels on/off
    // NOTE: only needed when we enable binary pixels
    //texAvg = (1.0-binary)*texAvg + binary*step(pixThreshold, texAvg);
    
    //colorize in dmd color
    vec3 col = dmdColor * texAvg;
    
    //Apply black parts of matrix
    vec2 uvDots = vec2(fract(indexX / pixSizeX), fract(indexY / pixSizeY));
    float circle = 1. - step(dotOrRect, length(uvDots - .5));
    col = col * circle;
    
    //TODO: flickering not working because it needs iTime var to oscillate with.
    float f = 0.0;
    if(flickering && length(col) > 0.0){
        f = sin(cellY - iTime * 20)*0.05;
    }
    

    // Output to screen
    finalColor = vec4(col+f, alpha_trans);
}