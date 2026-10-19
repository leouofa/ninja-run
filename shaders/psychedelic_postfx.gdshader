shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

// Audio & Gameplay Reactivity Uniforms
uniform float bass_energy : hint_range(0.0, 2.0) = 0.0;
uniform float mid_energy : hint_range(0.0, 2.0) = 0.0;
uniform float high_energy : hint_range(0.0, 2.0) = 0.0;
uniform float drop_intensity : hint_range(0.0, 2.0) = 0.0;
uniform float chrono_blend : hint_range(0.0, 1.0) = 0.0;
uniform float combo_ratio : hint_range(0.0, 1.0) = 0.0;

uniform float base_aberration = 0.004;
uniform float ripple_intensity = 0.005;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center_delta = uv - vec2(0.5);
	float dist_from_center = length(center_delta);

	// 1. Audio-reactive UV Bass Ripple
	// Concentric psychedelic sound waves expand outward on heavy bass & drops
	float ripple_phase = dist_from_center * 28.0 - TIME * (6.0 + bass_energy * 4.0);
	float ripple_amount = sin(ripple_phase) * (bass_energy * 0.003 + drop_intensity * ripple_intensity);
	vec2 ripple_uv = uv;
	if (dist_from_center > 0.001) {
		ripple_uv += (center_delta / dist_from_center) * ripple_amount;
	}

	// 2. Radial Chromatic Aberration
	// Scales toward the screen edges and spikes with bass, drops, combo, and chrono slowmo
	float edge_factor = pow(dist_from_center * 1.45, 1.7);
	float total_ca = (base_aberration + bass_energy * 0.005 + drop_intensity * 0.009 + combo_ratio * 0.005 + chrono_blend * 0.007) * edge_factor;

	vec2 ca_dir = (dist_from_center > 0.001) ? normalize(center_delta) : vec2(0.0);

	float col_r = texture(screen_texture, ripple_uv + ca_dir * total_ca).r;
	float col_g = texture(screen_texture, ripple_uv).g;
	float col_b = texture(screen_texture, ripple_uv - ca_dir * total_ca).b;
	vec3 col = vec3(col_r, col_g, col_b);

	// 3. Subtle Peripheral Psychedelic Iridescence
	// Rainbow rim glow in extreme corners at high combos or drops without hurting center lane focus
	float corner_mask = smoothstep(0.48, 0.85, dist_from_center);
	float iris_t = TIME * 2.0 + atan(center_delta.y, center_delta.x) * 2.0;
	vec3 iris_glow = 0.5 + 0.5 * cos(iris_t + vec3(0.0, 2.0, 4.0));
	col += iris_glow * corner_mask * (0.08 + combo_ratio * 0.14 + drop_intensity * 0.16);

	// 4. Chrono-Focus Time-Warp Screen Tone
	if (chrono_blend > 0.01) {
		// Cool icy-cyan tint and heightened peripheral vignette
		float luma = dot(col, vec3(0.299, 0.587, 0.114));
		vec3 chrono_tint = mix(vec3(luma), col, 0.65) * vec3(0.65, 1.05, 1.25);
		col = mix(col, chrono_tint, chrono_blend * 0.7);

		float chrono_vignette = smoothstep(0.3, 0.85, dist_from_center) * chrono_blend * 0.35;
		col = mix(col, vec3(0.02, 0.15, 0.28), chrono_vignette);
	}

	COLOR = vec4(col, 1.0);
}
