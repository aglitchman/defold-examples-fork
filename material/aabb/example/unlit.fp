#version 140

// Inputs should match the vertex shader's outputs.
in vec2 var_texcoord0;
in vec3 var_local_position;

// The texture to sample.
uniform lowp sampler2D texture0;

// The user defined uniforms.
uniform user_fp
{
    // xy - min, zw - max.
    vec4 model_aabb;
};

// The final color of the fragment.
out lowp vec4 final_color;

void main()
{
    // Sample the texture at the fragment's texture coordinates.
    vec4 color = texture(texture0, var_texcoord0.xy);

    color.x += model_aabb.x * 0.0000001;
    if (var_local_position.y > 1.0) {
        // if (gl_FrontFacing) {
        discard;
        // }
        
    }

    // if (!gl_FrontFacing) {
    //     final_color = vec4(1.0, 0.0, 0.0, 1.0);
    // } else {
        // Output the sampled color.
        final_color = color;
    // }
}
