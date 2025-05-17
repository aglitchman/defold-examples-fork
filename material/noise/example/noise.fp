#version 140

in mediump vec2 var_texcoord0;

uniform fs_uniforms
{
    mediump mat4 mtx_world;
    mediump mat4 mtx_view;
    mediump mat4 mtx_proj;
    mediump vec4 time;
    mediump vec4 screen_size;
};

out mediump vec4 out_fragColor;

#include "/example/debugger.glsl"

// noise shader from https://www.shadertoy.com/view/XXBcDz

// pseudo random generator (white noise)
float rand(vec2 n)
{ 
    return fract(sin(dot(n, vec2(12.9898, 78.233))) * 43758.5453);
}

// value noise
float noise(vec2 p)
{
    vec2 ip = floor(p);
    vec2 u = fract(p);
    u = u * u * (3.0 - 2.0 * u);

    float x = mix(rand(ip),                  rand(ip + vec2(1.0, 0.0)), u.x);
    float y = mix(rand(ip + vec2(0.0, 1.0)), rand(ip + vec2(1.0, 1.0)), u.x);
    float a = u.y;
    float res = mix(x, y, a);
    return res * res;
}

// used to rotate domain of noise function
const mat2 rot = mat2( 0.80,  0.60, -0.60,  0.80 );

// fast implementation
float fbm( vec2 p )
{
    float f = 0.0;
    f += 0.500000 * noise( p ); p = rot * p * 2.02;
    f += 0.031250 * noise( p ); p = rot * p * 2.01;
    f += 0.250000 * noise( p ); p = rot * p * 2.03;
    f += 0.125000 * noise( p + 0.1 * sin(time.x) + 0.8 * time.x ); p = rot * p * 2.01;
    f += 0.062500 * noise( p + 0.3 * sin(time.x) ); p = rot * p * 2.04;
    f += 0.015625 * noise( p );
    return f / 0.96875;
}

// Constants for digit rendering
// const uint dBits[5] = uint[](
//     3959160828u, // 0xECDCBAFC
//     2828738996u, // 0xA89ABC34
//     2881485308u, // 0xABDCE1FC
//     2853333412u, // 0xAA1235A4
//     3958634981u  // 0xEBEBCDE5
// );
// 
// // Renders a single digit (0-9, -1 for minus, 10 for period)
// // px is the pixel coordinate relative to the digit's 3x5 grid cell.
// float DrawDigit(ivec2 px, const int digit) {
//     if (px.x < 0 || px.x > 2 || px.y < 0 || px.y > 4)
//     return 0.0; // Pixel out of bounds for the 3x5 digit character
// 
//     // Determine bit index in dBits based on digit and pixel position
//     int xId = (digit == -1) ? 18 : (31 - (3 * digit + px.x));
// 
//     // Check if the bit is set for this pixel in the font data
//     // Note: (1u << uint(xId)) ensures correct bitwise operation with uint
//     return float((dBits[4 - px.y] & (1u << uint(xId))) != 0u);
// }

void main()
{  
    float n = fbm(var_texcoord0.xy);

    // float v = DrawDigit(ivec2(gl_FragCoord.xy), 0);

    float exampleNumber = 123.0;
    float m = DrawNumberAtLocalPos(gl_FragCoord.xy, vec3(0.0, 0.0, 0.0), exampleNumber, 4);
    // return float4(numberMask.xxx, 1);
    out_fragColor = vec4(m, n, n, 1.0);
    
    // out_fragColor = vec4(n * v, n, n, 1.0);
}

