shader_type canvas_item;
render_mode blend_mix;

// Colors
uniform vec4 sky_top_color : source_color = vec4(0.04, 0.02, 0.10, 1.0);
uniform vec4 sky_bottom_color : source_color = vec4(0.32, 0.06, 0.34, 1.0);
uniform vec4 sun_top_color : source_color = vec4(1.0, 0.92, 0.25, 1.0);
uniform vec4 sun_bottom_color : source_color = vec4(1.0, 0.08, 0.55, 1.0);
uniform vec4 grid_line_color : source_color = vec4(0.0, 0.95, 1.0, 1.0);
uniform vec4 grid_horizon_color : source_color = vec4(1.0, 0.12, 0.65, 1.0);
uniform vec4 mountain_color : source_color = vec4(0.08, 0.04, 0.16, 1.0);
uniform vec4 mountain_rim_color : source_color = vec4(0.0, 0.92, 1.0, 1.0);

// Geometry & Animation
uniform float horizon_y : hint_range(0.2, 0.8) = 0.53;
uniform float sun_radius : hint_range(0.05, 0.4) = 0.21;
uniform float grid_speed = 0.55;

// Audio-reactive uniforms (driven dynamically by GDScript)
uniform float bass_energy = 0.0;
uniform float mid_energy = 0.0;
uniform float high_energy = 0.0;
uniform float time_val = 0.0;

// Pseudo-random hash for stars
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Mountain ridge generator
float get_mountain_height(float x, float seed) {
    float h = sin(x * 9.0 + seed) * 0.035;
    h += sin(x * 21.0 + seed * 2.3) * 0.018;
    h += sin(x * 47.0 + seed * 4.7) * 0.009;
    h += sin(x * 89.0 + seed * 8.1) * 0.004;
    return abs(h);
}

void fragment() {
    float aspect = (SCREEN_PIXEL_SIZE.x > 0.0 && SCREEN_PIXEL_SIZE.y > 0.0) 
        ? (SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x) 
        : (16.0 / 9.0);
    
    float t = TIME + time_val;
    vec3 col = vec3(0.0);
    
    // Effective dynamic values
    float cur_sun_radius = sun_radius * (1.0 + bass_energy * 0.12);
    vec2 sun_center = vec2(0.5, horizon_y - 0.035);

    if (UV.y < horizon_y) {
        // === SKY & STARS ===
        float sky_t = clamp(UV.y / horizon_y, 0.0, 1.0);
        vec3 sky = mix(sky_top_color.rgb, sky_bottom_color.rgb, pow(sky_t, 1.4));
        col = sky;
        
        // Procedural Starfield
        vec2 star_cell = floor(UV * vec2(aspect * 90.0, 90.0));
        vec2 star_fract = fract(UV * vec2(aspect * 90.0, 90.0)) - 0.5;
        float star_rnd = hash(star_cell);
        if (star_rnd > 0.955 && UV.y < horizon_y - 0.06) {
            float twinkle = sin(t * 3.5 + star_rnd * 6.2831) * 0.5 + 0.5;
            float star_r = (0.04 + 0.05 * ((star_rnd - 0.955) / 0.045)) * (1.0 + high_energy * 0.9);
            float d_star = length(star_fract);
            float star_glow = smoothstep(star_r, 0.0, d_star) * (0.35 + 0.65 * twinkle);
            vec3 star_color = mix(vec3(0.9, 0.95, 1.0), vec3(0.4, 0.95, 1.0), star_rnd * 2.0 - 1.0);
            col += star_color * star_glow;
        }

        // === SUN ===
        vec2 sun_offset = vec2((UV.x - sun_center.x) * aspect, UV.y - sun_center.y);
        float sun_dist = length(sun_offset);
        
        // Sun ambient halo / glow
        float sun_halo = exp(-sun_dist * 4.2) * (0.65 + bass_energy * 0.7);
        col += mix(sun_bottom_color.rgb, sun_top_color.rgb, 0.4) * sun_halo;
        
        if (sun_dist < cur_sun_radius) {
            // Sun body vertical gradient
            float sun_v = clamp((UV.y - (sun_center.y - cur_sun_radius)) / (cur_sun_radius * 2.0), 0.0, 1.0);
            vec3 sun_col = mix(sun_top_color.rgb, sun_bottom_color.rgb, pow(sun_v, 1.2));
            
            // Retro horizontal stripe blinds in bottom section
            bool in_cutout = false;
            float stripe_start = sun_center.y - cur_sun_radius * 0.15;
            if (UV.y > stripe_start) {
                float norm_stripe_y = (UV.y - stripe_start) / (cur_sun_radius * 1.15);
                // Stripes widen exponentially towards the bottom
                float stripe_wave = sin(pow(norm_stripe_y, 1.8) * 44.0 - t * 0.4);
                if (stripe_wave > 0.22) {
                    in_cutout = true;
                }
            }
            
            if (!in_cutout) {
                // Crisp anti-aliased sun perimeter
                float edge_aa = smoothstep(cur_sun_radius, cur_sun_radius - 0.005, sun_dist);
                col = mix(col, sun_col, edge_aa);
            }
        }

        // === DISTANT MOUNTAINS ===
        // Back mountain range
        float mtn1_h = get_mountain_height(UV.x * 2.2, 42.1) * (0.9 + mid_energy * 0.4);
        float mtn1_y = horizon_y - 0.055 - mtn1_h;
        if (UV.y > mtn1_y) {
            vec3 mtn1_col = mix(mountain_color.rgb * 0.7, sky_bottom_color.rgb * 0.5, (UV.y - mtn1_y) * 4.0);
            col = mix(col, mtn1_col, 0.85);
        }

        // Front mountain range with neon glowing rim
        float mtn2_h = get_mountain_height(UV.x * 3.8 + 0.35, 87.5) * (1.0 + mid_energy * 0.6);
        float mtn2_y = horizon_y - 0.032 - mtn2_h;
        if (UV.y > mtn2_y) {
            float rim_dist = abs(UV.y - mtn2_y);
            float rim = smoothstep(0.005, 0.0, rim_dist) * (0.8 + mid_energy * 1.4);
            vec3 mtn2_col = mountain_color.rgb;
            col = mtn2_col + mountain_rim_color.rgb * rim;
        }

    } else {
        // === PERSPECTIVE RETRO GRID FLOOR ===
        float depth = UV.y - horizon_y;
        float safe_depth = max(depth, 0.001);
        
        // 3D perspective mapping
        float p_y = 1.0 / safe_depth;
        float p_x = (UV.x - 0.5) * aspect * p_y * 0.65;
        
        // Animated motion moving towards camera
        float scroll = t * grid_speed;
        p_y += scroll;
        
        // Audio-reactive terrain wave deformation
        float wave = sin(p_y * 0.6 - scroll * 1.2) * cos(p_x * 0.4) * (bass_energy * 0.45);
        p_x += wave;
        
        // Floor base reflection
        vec3 floor_base = mix(vec3(0.03, 0.02, 0.07), vec3(0.14, 0.03, 0.18), exp(-depth * 6.5));
        
        // Vertical reflection beam of the retro sun
        float sun_refl_x = abs(UV.x - sun_center.x);
        float sun_refl = exp(-sun_refl_x * 7.5) * exp(-depth * 3.8) * (0.35 + bass_energy * 0.45);
        floor_base += mix(sun_bottom_color.rgb, sun_top_color.rgb, 0.5) * sun_refl;
        col = floor_base;

        // Perspective grid lines
        vec2 grid_uv = vec2(p_x, p_y);
        vec2 grid_cell = fract(grid_uv);
        vec2 dist_to_line = min(grid_cell, 1.0 - grid_cell);
        
        // Anti-aliased line width using screen-space derivatives
        vec2 fw = fwidth(grid_uv);
        vec2 line_aa = smoothstep(fw * 1.5, vec2(0.0), dist_to_line);
        float line_val = max(line_aa.x, line_aa.y);
        
        // Outer soft glow for neon look
        vec2 glow_aa = smoothstep(fw * 5.0, vec2(0.0), dist_to_line);
        float glow_val = max(glow_aa.x, glow_aa.y) * 0.45;
        
        // Grid line color blending: horizontal lines shift towards magenta/horizon, vertical lines cyan
        vec3 line_col = mix(grid_line_color.rgb, grid_horizon_color.rgb, clamp(line_aa.y * 0.7 + exp(-depth * 4.0), 0.0, 1.0));
        line_col *= (1.0 + bass_energy * 0.5 + high_energy * 0.3);
        
        // Distance fade into horizon fog
        float dist_fade = smoothstep(0.005, 0.12, depth);
        col += (line_col * line_val + line_col * glow_val) * dist_fade;
    }

    // === HORIZON NEON HAZE / FOG ===
    float horizon_dist = abs(UV.y - horizon_y);
    float horizon_haze = exp(-horizon_dist * 28.0) * (0.75 + bass_energy * 0.5);
    vec3 haze_color = mix(grid_horizon_color.rgb, grid_line_color.rgb, 0.35);
    col += haze_color * horizon_haze;

    // === RETRO CRT SCANLINES & VIGNETTE ===
    // Scanlines
    float scanline_count = (SCREEN_PIXEL_SIZE.y > 0.0) ? (0.5 / SCREEN_PIXEL_SIZE.y) : 360.0;
    float scanline = 0.965 + 0.035 * sin(UV.y * scanline_count * 3.14159);
    col *= scanline;
    
    // Vignette
    vec2 vig_uv = (UV - 0.5) * vec2(aspect, 1.0);
    float vig = smoothstep(1.35, 0.5, length(vig_uv));
    col *= vig;

    COLOR = vec4(col, 1.0);
}
