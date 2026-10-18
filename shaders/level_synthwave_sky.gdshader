shader_type sky;

// Track Metadata Palette Uniforms
uniform vec4 sky_top_color : source_color = vec4(0.03, 0.02, 0.10, 1.0);
uniform vec4 sky_horizon_color : source_color = vec4(0.35, 0.06, 0.38, 1.0);
uniform vec4 sun_top_color : source_color = vec4(1.0, 0.92, 0.25, 1.0);
uniform vec4 sun_bottom_color : source_color = vec4(1.0, 0.08, 0.55, 1.0);
uniform vec4 grid_primary_color : source_color = vec4(0.0, 0.95, 1.0, 1.0);
uniform vec4 grid_secondary_color : source_color = vec4(1.0, 0.12, 0.65, 1.0);
uniform vec4 mountain_color : source_color = vec4(0.07, 0.03, 0.15, 1.0);
uniform vec4 mountain_rim_color : source_color = vec4(0.0, 0.92, 1.0, 1.0);

// Audio & Gameplay Reactivity Uniforms
uniform float bass_energy = 0.0;
uniform float mid_energy = 0.0;
uniform float high_energy = 0.0;
uniform float drop_intensity = 0.0;
uniform float chrono_blend = 0.0;
uniform float scroll_offset = 0.0;
uniform float track_seed_offset = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// 360-degree periodic mountain height around azimuth angle (-PI to PI)
float mountain_ridge(float angle, float seed) {
	float h = sin(angle * 6.0 + seed) * 0.032;
	h += sin(angle * 14.0 + seed * 2.1) * 0.018;
	h += sin(angle * 29.0 + seed * 3.7) * 0.009;
	h += sin(angle * 53.0 + seed * 6.3) * 0.004;
	return abs(h);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float y = dir.y;
	float horizon_level = -0.02;

	// Chrono-Focus Time-Warp Palette Overrides
	vec3 c_sky_top = mix(sky_top_color.rgb, vec3(0.01, 0.05, 0.14), chrono_blend * 0.85);
	vec3 c_sky_hor = mix(sky_horizon_color.rgb, vec3(0.04, 0.32, 0.52), chrono_blend * 0.85);
	vec3 c_sun_top = mix(sun_top_color.rgb, vec3(0.75, 0.98, 1.0), chrono_blend * 0.85);
	vec3 c_sun_bot = mix(sun_bottom_color.rgb, vec3(0.0, 0.65, 0.95), chrono_blend * 0.85);
	vec3 c_grid_pri = mix(grid_primary_color.rgb, vec3(0.35, 0.95, 1.0), chrono_blend * 0.85);
	vec3 c_grid_sec = mix(grid_secondary_color.rgb, vec3(0.1, 0.55, 0.95), chrono_blend * 0.85);
	vec3 c_mtn = mix(mountain_color.rgb, vec3(0.02, 0.08, 0.18), chrono_blend * 0.85);
	vec3 c_mtn_rim = mix(mountain_rim_color.rgb, vec3(0.5, 0.98, 1.0), chrono_blend * 0.85);

	// Azimuth angle around the 3D world (-PI to PI)
	float azimuth = atan(dir.x, -dir.z);
	float t = TIME * (1.0 - chrono_blend * 0.55);

	vec3 col = vec3(0.0);

	if (y >= horizon_level) {
		// === UPPER HEMISPHERE: SKY, STARS, AURORA, SUNS & MOUNTAINS ===
		float sky_t = clamp((y - horizon_level) / (1.0 - horizon_level), 0.0, 1.0);
		col = mix(c_sky_hor, c_sky_top, pow(sky_t, 0.65));

		// Audio-reactive aurora / synth nebula ribbons in mid-upper sky
		float aurora_wave = sin(azimuth * 4.0 + y * 12.0 - t * 0.6 + track_seed_offset);
		aurora_wave += sin(azimuth * 9.0 - y * 18.0 + t * 0.4) * 0.5;
		float aurora_mask = smoothstep(0.06, 0.35, y) * smoothstep(0.75, 0.25, y);
		float aurora_glow = max(0.0, aurora_wave) * aurora_mask * (0.12 + high_energy * 0.22 + drop_intensity * 0.25);
		col += mix(c_grid_pri, c_grid_sec, 0.5 + 0.5 * sin(azimuth * 2.0)) * aurora_glow;

		// 3D Starfield (mapped on spherical coordinates so stars stay fixed in world space)
		if (y > 0.04) {
			vec2 star_uv = vec2(azimuth * 28.6478, y * 90.0);
			vec2 star_cell = floor(star_uv);
			vec2 star_f = fract(star_uv) - 0.5;
			float s_rnd = hash21(star_cell + track_seed_offset);
			if (s_rnd > 0.945) {
				float twinkle = 0.5 + 0.5 * sin(t * 4.0 + s_rnd * 6.2831);
				float s_rad = (0.045 + 0.055 * ((s_rnd - 0.945) / 0.055)) * (1.0 + high_energy * 0.85);
				float s_bright = smoothstep(s_rad, 0.0, length(star_f)) * (0.35 + 0.65 * twinkle) * smoothstep(0.04, 0.16, y);
				col += mix(vec3(0.95, 0.98, 1.0), c_grid_pri, s_rnd - 0.5) * s_bright;
			}
		}

		// === CARDINAL RETRO SUNS (4 cardinal directions so 90° turns always frame a vista) ===
		// Fold azimuth into 4 cardinal quadrants (-PI/4 to PI/4)
		float quad_angle = mod(azimuth + 0.78539816, 1.5707963) - 0.78539816;
		float quad_idx = floor(mod(azimuth + 0.78539816, 6.2831853) / 1.5707963);
		float is_primary_sun = (quad_idx < 0.5 || quad_idx > 3.5) ? 1.0 : 0.0;

		float base_sun_r = mix(0.145, 0.195, is_primary_sun) * (1.0 + bass_energy * 0.14 + drop_intensity * 0.08);
		vec2 sun_center = vec2(0.0, horizon_level + mix(0.10, 0.135, is_primary_sun));
		vec2 sun_delta = vec2(quad_angle, y - sun_center.y);
		float sun_dist = length(sun_delta);

		// Sun corona / atmospheric bloom
		float halo = exp(-sun_dist * 5.2) * (0.55 + bass_energy * 0.65 + drop_intensity * 0.45);
		col += mix(c_sun_bot, c_sun_top, 0.4) * halo;

		if (sun_dist < base_sun_r) {
			float sun_v = clamp((y - (sun_center.y - base_sun_r)) / (base_sun_r * 2.0), 0.0, 1.0);
			vec3 sun_col = mix(c_sun_bot, c_sun_top, pow(sun_v, 0.85));

			// Classic 80s horizontal scanline cutouts in lower 65% of sun
			bool cutout = false;
			float stripe_top = sun_center.y + base_sun_r * 0.2;
			if (y < stripe_top) {
				float norm_sy = (stripe_top - y) / (base_sun_r * 1.2);
				float stripe_wave = sin(pow(norm_sy, 1.75) * 42.0 - t * 0.5);
				if (stripe_wave > 0.20) {
					cutout = true;
				}
			}

			if (!cutout) {
				float edge_aa = smoothstep(base_sun_r, base_sun_r - 0.005, sun_dist);
				col = mix(col, sun_col * (1.1 + bass_energy * 0.3), edge_aa);
			}
		}

		// === 360° LAYERED SYNTHWAVE MOUNTAINS ===
		float mtn_scale = 1.0 + mid_energy * 0.55 + drop_intensity * 0.35;

		// Far mountain ridge
		float m1_h = mountain_ridge(azimuth, 13.7 + track_seed_offset) * mtn_scale * 1.25;
		float m1_top = horizon_level + 0.032 + m1_h;
		if (y < m1_top) {
			float m1_rim = smoothstep(0.0045, 0.0, abs(y - m1_top)) * (0.5 + mid_energy * 0.9);
			vec3 m1_body = mix(c_mtn * 0.75, c_sky_hor * 0.45, clamp((m1_top - y) * 6.0, 0.0, 1.0));
			col = m1_body + c_grid_sec * m1_rim;
		}

		// Near mountain ridge with bright neon rim
		float m2_h = mountain_ridge(azimuth + 1.15, 71.3 + track_seed_offset) * mtn_scale * 0.95;
		float m2_top = horizon_level + 0.015 + m2_h;
		if (y < m2_top) {
			float m2_rim = smoothstep(0.004, 0.0, abs(y - m2_top)) * (0.85 + mid_energy * 1.4 + drop_intensity * 0.8);
			// Subtle vertical wireframe lines on near mountains
			float m2_wire = smoothstep(0.04, 0.0, abs(fract(azimuth * 18.0 / 3.14159) - 0.5)) * 0.22 * (0.5 + bass_energy);
			col = c_mtn + c_mtn_rim * (m2_rim + m2_wire);
		}

	} else {
		// === LOWER HEMISPHERE: 3D ABYSSAL PERSPECTIVE SYNTHWAVE GRID ===
		float depth = horizon_level - y;
		float safe_depth = max(depth, 0.002);

		// Project ray onto horizontal abyss plane below the track
		float plane_dist = 1.0 / safe_depth;
		vec2 world_xz = dir.xz * plane_dist * 0.85;

		// Scroll grid continuously + audio-reactive bass wave ripple
		world_xz.y -= scroll_offset;
		float ripple = sin(world_xz.y * 0.45 + t * 2.0) * cos(world_xz.x * 0.45) * (bass_energy * 0.35 + drop_intensity * 0.25);
		world_xz += ripple;

		// Dark reflective abyss floor
		vec3 floor_col = mix(c_sky_top * 0.65, c_sky_hor * 0.45, exp(-depth * 7.0));

		// Cardinal sun reflection beams on the abyss floor
		float quad_angle = mod(azimuth + 0.78539816, 1.5707963) - 0.78539816;
		float refl_beam = exp(-abs(quad_angle) * 6.5) * exp(-depth * 3.5) * (0.35 + bass_energy * 0.5 + drop_intensity * 0.3);
		floor_col += mix(c_sun_bot, c_sun_top, 0.45) * refl_beam;
		col = floor_col;

		// Analytical anti-aliased grid lines (safe for sky shaders & radiance cubemaps)
		vec2 grid_cell = fract(world_xz);
		vec2 dist_to_line = min(grid_cell, 1.0 - grid_cell);

		float line_thickness = clamp(0.016 * plane_dist, 0.014, 0.22);
		vec2 line_aa = smoothstep(vec2(line_thickness), vec2(0.0), dist_to_line);
		float line_val = max(line_aa.x, line_aa.y);

		// Neon outer bloom around grid lines
		float glow_thickness = clamp(0.065 * plane_dist, 0.05, 0.40);
		vec2 glow_aa = smoothstep(vec2(glow_thickness), vec2(0.0), dist_to_line);
		float glow_val = max(glow_aa.x, glow_aa.y) * 0.45;

		// Blend primary and secondary track colors across the grid
		vec3 grid_col = mix(c_grid_pri, c_grid_sec, clamp(line_aa.y * 0.65 + exp(-depth * 4.5), 0.0, 1.0));
		grid_col *= (1.0 + bass_energy * 0.65 + high_energy * 0.35 + drop_intensity * 0.5);

		// Fade grid smoothly at extreme horizon distance to prevent aliasing
		float horizon_fade = smoothstep(0.004, 0.09, depth);
		col += (grid_col * line_val + grid_col * glow_val) * horizon_fade;
	}

	// === 360° HORIZON NEON GLOW BAND ===
	float h_dist = abs(y - horizon_level);
	float h_glow = exp(-h_dist * 32.0) * (0.75 + bass_energy * 0.55 + drop_intensity * 0.45);
	col += mix(c_grid_sec, c_grid_pri, 0.4) * h_glow;

	COLOR = col;
}
