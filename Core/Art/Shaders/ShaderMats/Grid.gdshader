shader_type spatial;

// Uniforms (parameters) for configuring the material
uniform sampler2D grid_texture; // Grid texture
uniform vec4 base_color : source_color; // Color parameter to tint the object
uniform float grid_scale = 2.0; // Scale of the grid texture
uniform float grid_opacity = 1.0; // Opacity of the grid pattern
uniform float metallic = 0.0; // Metallic property
uniform float specular = 0.2; // Specular property
uniform float roughness = 0.8; // Roughness property
uniform float emissive_strength = 0.0; // Emissive strength

// Offset for the world position (adjustable through the inspector)
uniform vec2 world_offset = vec2(1.0, 1.0); // X and Z offset

varying vec3 world_position;

void vertex() {
    // Get the world position of the vertex
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {

    // Apply the offset to the X and Z coordinates of the world position
    vec2 offset_world_position = world_position.xz + world_offset;

    // Scale the offset world position to create the grid effect
    vec2 scaled_uv = offset_world_position / grid_scale;

    // Sample the grid texture using the scaled UV coordinates
    vec4 grid_tex = texture(grid_texture, scaled_uv);

    // Interpolate between the grid texture and the base color using opacity
    vec4 final_color = mix(base_color, grid_tex, grid_opacity) * base_color;

    // Set the final material properties
    ALBEDO = final_color.rgb;
    METALLIC = metallic;
    SPECULAR = specular;
    ROUGHNESS = roughness;
    EMISSION = final_color.rgb * emissive_strength;
}
