shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Pattern modes:
// 0: Iridescent Shimmer (Coins, Powerups)
// 1: Scrolling Plasma Veins (Yokai Enemies)
// 2: Neon Hazard Chevrons / Runes (Barricades & Gates)
uniform int pattern_mode : hint_range(0, 2) = 0;

uniform vec4 albedo_color : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform vec4 emission_color : source_color = vec4(1.0, 0.82, 0.15, 1.0);
uniform vec4 secondary_color : source_color = vec4(1.0, 0.15, 0.65, 1.0);

uniform float emission_energy : hint_range(0.0, 16.0) = 4.0;
uniform float rim_power : hint_range(0.5, 8.0) = 2.2;
uniform float rim_boost : hint_range(0.5, 6.0) = 2.5;
uniform float pattern_speed : hint_range(0.0, 10.0) = 3.0;
uniform float pattern_scale : hint_range(0.5, 20.0) = 4.0;

// Audio & Gameplay Reactivity
uniform float bass_energy : hint_range(0.0, 2.0) = 0.0;
uniform float drop_intensity : hint_range(0.0, 2.0) = 0.0;
uniform float chrono_blend : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_world_pos;
varying vec3 v_local_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_local_pos = VERTEX;

	// Audio-reactive vertex breath pulse on heavy bass
	float pulse = (bass_energy * 0.035 + drop_intensity * 0.03) * sin(TIME * 12.0 + VERTEX.y * 4.0);
	VERTEX += NORMAL * pulse;
}

void fragment() {
	float t = TIME * (1.0 - chrono_blend * 0.55);
	vec3 view_dir = normalize(VIEW);
	vec3 norm = normalize(NORMAL);

	// Crisp Fresnel rim calculation
	float fresnel = pow(clamp(1.0 - dot(norm, view_dir), 0.0, 1.0), rim_power);

	vec3 c_emit = emission_color.rgb;
	vec3 c_sec = secondary_color.rgb;

	// Time-warp shift during Chrono-Focus
	vec3 chrono_cyan = vec3(0.25, 0.95, 1.0);
	vec3 chrono_violet = vec3(0.7, 0.35, 1.0);
	c_emit = mix(c_emit, chrono_cyan, chrono_blend * 0.85);
	c_sec = mix(c_sec, chrono_violet, chrono_blend * 0.85);

	vec3 emit_final = vec3(0.0);
	vec3 albedo_final = albedo_color.rgb;

	if (pattern_mode == 0) {
		// --- 0: Iridescent Solar / Prismatic Shimmer (Coins, Pickups) ---
		// Dynamic angle-based spectral iridescent fringe
		float angle_term = dot(norm, view_dir) * 4.0 + v_local_pos.y * pattern_scale + t * pattern_speed;
		float rainbow_wave = sin(angle_term);
		vec3 iris = mix(c_emit, c_sec, 0.5 + 0.5 * rainbow_wave);

		// High-specular golden glint
		vec3 light_fake = normalize(vec3(0.3, 0.8, 0.5));
		vec3 half_v = normalize(view_dir + light_fake);
		float glint = pow(max(0.0, dot(norm, half_v)), 28.0) * 2.2;

		albedo_final = mix(albedo_color.rgb, iris * 0.4, 0.6);
		emit_final = (iris * (fresnel * rim_boost + 0.5) + vec3(glint)) * emission_energy;
		emit_final *= (1.0 + bass_energy * 0.75 + drop_intensity * 0.5);

	} else if (pattern_mode == 1) {
		// --- 1: Scrolling Plasma Veins (Yokai Enemies) ---
		float wave1 = sin(v_local_pos.y * pattern_scale * 3.5 - t * pattern_speed);
		float wave2 = cos(v_local_pos.x * pattern_scale * 2.8 + v_local_pos.z * pattern_scale * 2.0 + t * 2.0);
		float plasma = smoothstep(0.15, 0.75, wave1 * 0.6 + wave2 * 0.4);

		vec3 plasma_col = mix(c_emit, c_sec, 0.5 + 0.5 * sin(t * 3.0 + v_local_pos.y * 4.0));
		float vein_power = plasma * (0.8 + bass_energy * 0.8);

		albedo_final = albedo_color.rgb * 0.6;
		emit_final = (plasma_col * vein_power + c_emit * (fresnel * rim_boost)) * emission_energy;
		emit_final *= (1.0 + bass_energy * 0.85 + drop_intensity * 0.65);

	} else {
		// --- 2: Neon Hazard Chevrons / Runes (Obstacles) ---
		float stripe_pos = (v_local_pos.x * 1.8 + v_local_pos.y * 2.2) * pattern_scale - t * pattern_speed;
		float stripe = smoothstep(-0.15, 0.15, sin(stripe_pos));

		vec3 stripe_col = mix(c_sec * 0.3, c_emit, stripe);
		albedo_final = mix(albedo_color.rgb, stripe_col * 0.3, stripe);
		emit_final = (stripe_col * (0.6 + stripe * 0.8) + c_sec * (fresnel * rim_boost)) * emission_energy;
		emit_final *= (1.0 + bass_energy * 0.65 + drop_intensity * 0.5);
	}

	ALBEDO = albedo_final;
	METALLIC = 0.2;
	ROUGHNESS = 0.3;
	EMISSION = emit_final;
}
