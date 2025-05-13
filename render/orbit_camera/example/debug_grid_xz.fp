#ifdef GL_OES_standard_derivatives
#extension GL_OES_standard_derivatives : enable
#endif

varying highp vec3 var_position;

// Derivative functions are available on:
// - OpenGL (desktop).
// - OpenGL ES 3.0, WebGL 2.0.
// - OpenGL ES 2.0, WebGL 1.0, if the extension GL_OES_standard_derivatives is enabled.
#if !defined(GL_ES) || __VERSION__ >= 300 || defined(GL_OES_standard_derivatives)

// https://bgolus.medium.com/the-best-darn-grid-shader-yet-727f9278b9d8
float bgolus_grid(vec2 uv, vec2 lineWidth)
{
    vec2 ddx = dFdx(uv);
    vec2 ddy = dFdy(uv);

    vec2 uvDeriv = vec2(length(vec2(ddx.x, ddy.x)), length(vec2(ddx.y, ddy.y)));
    bvec2 invertLine = bvec2(lineWidth.x > 0.5, lineWidth.y > 0.5);

    vec2 targetWidth = vec2(
        invertLine.x ? 1.0 - lineWidth.x : lineWidth.x,
        invertLine.y ? 1.0 - lineWidth.y : lineWidth.y
    );

    vec2 drawWidth = clamp(targetWidth, uvDeriv, vec2(0.5));
    vec2 lineAA = uvDeriv * 1.5;
    vec2 gridUV = abs(fract(uv) * 2.0 - 1.0);

    gridUV.x = invertLine.x ? gridUV.x : 1.0 - gridUV.x;
    gridUV.y = invertLine.y ? gridUV.y : 1.0 - gridUV.y;

    vec2 grid2 = smoothstep(drawWidth + lineAA, drawWidth - lineAA, gridUV);

    grid2 *= clamp(targetWidth / drawWidth, 0.0, 1.0);
    grid2 = mix(grid2, targetWidth, clamp(uvDeriv * 2.0 - 1.0, 0.0, 1.0));
    grid2.x = invertLine.x ? 1.0 - grid2.x : grid2.x;
    grid2.y = invertLine.y ? 1.0 - grid2.y : grid2.y;
    return mix(grid2.x, 1.0, grid2.y);
}

#else
// A fallback in the case of derivatives lack
float bgolus_grid(vec2 uv, vec2 lineWidth)
{
    return 0.0;
}
#endif

void main()
{
    float scale_0 = 1.0;
    float scale_1 = 0.2;

    float line_scale_0 = 0.04;
    float line_scale_1 = 0.08;

    vec4 color_0 = vec4(1.0, 1.0, 1.0, 0.25);
    vec4 color_1 = vec4(1.0, 1.0, 1.0, 0.5);

    // Premultiply alpha
    color_0.rgb = color_0.rgb * color_0.a;
    color_1.rgb = color_1.rgb * color_1.a;

    vec4 background_color = vec4(0.0, 0.0, 0.0, 0.25);

    vec4 grid_0 = vec4(bgolus_grid(var_position.xz * scale_0, vec2(line_scale_0 * scale_0)));
    vec4 grid_1 = vec4(bgolus_grid(var_position.xz * scale_1, vec2(line_scale_1 * scale_1)));

    vec4 gridsMixed = mix(grid_0 * color_0, grid_1 * color_1, grid_1);
    float drawBackground = clamp(1.0 - (1.0 * (grid_1.r + grid_0.r)), 0.0, 1.0);

    gl_FragColor = mix(gridsMixed, background_color, drawBackground);
}
