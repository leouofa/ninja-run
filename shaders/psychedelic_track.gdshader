shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 floor_color : source_color = vec4(0.03, 0.03, 0.06, 1.0);
uniform vec4 lane_line_color : source_color = vec4(0.0, 0.9, 1.0, 1.0);
uniform vec4 accent_line_color : source_color = vec4(1.0, 0.1, 0.65, 1.0);
uniform vec4 grid_tint_color : source_color = vec4(0.12, 0.06, 0.22, 1.0);

uniform float lane_width = 3.6;
uniform float line_thickness = 0.08;
uniform float emission_energy = 2.8;

// Audio & Gameplay Reactivity
uniform float bass_energy : hint_range(0.0, 2.0) = 0.0;
uniform float drop_intensity : hint_range(0.0, 2.0) = 0.0;
uniform float chrono_blend : hint_range(0.0, 1.0) = 0.0;
uniform float scroll_speed = 18.0;

varying vec3 v_world_pos;
varying vec3 v_local_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_local_pos = VERTEX;
}

void fragment() {
	float t = TIME * (1.0 - chrono_blend * 0.55);

	// In local coordinate space of roadway box:
	// Lane centers are at x = -3.6, 0.0, +3.6
	// Lane dividers are at x = -1.8 and x = +1.8
	float lx = v_local_pos.x;
	float lz = v_world_pos.z;

	// Distance to lane divider lines (x = -1.8 and x = +1.8)
	float dist_div_1 = abs(lx - (lane_width * 0.5));
	float dist_div_2 = abs(lx + (lane_width * 0.5));
	float dist_to_div = min(dist_div_1, dist_div_2);

	// Outer lane borders (x = -5.4 and x = +5.4)
	float dist_outer_1 = abs(lx - (lane_width * 1.5));
	float dist_outer_2 = abs(lx + (lane_width * 1.5));
	float dist_to_outer = min(dist_outer_1, dist_outer_2);

	// Neon dash pattern along track (3.0m on, 2.0m off)
	float dash_z = lz + t * scroll_speed * (0.8 + bass_energy * 0.4);
	float dash_mod = mod(dash_z, 5.0);
	float dash_mask = smoothstep(0.2, 0.4, dash_mod) * smoothstep(4.8, 4.6, dash_mod);

	// Divider line glow
	float line_aa = smoothstep(line_thickness, 0.0, dist_to_div) * dash_mask;
	float line_glow = smoothstep(line_thickness * 4.5, 0.0, dist_to_div) * 0.35 * dash_mask;

	// Continuous thin outer boundary line
	float outer_line = smoothstep(line_thickness * 0.7, 0.0, dist_to_outer);
	float outer_glow = smoothstep(line_thickness * 3.5, 0.0, dist_to_outer) * 0.3;

	// Subtle synthwave transversal grid lines across the floor (every 4.0 meters)
	float trans_mod = abs(fract(lz * 0.25) - 0.5);
	float trans_line = smoothstep(0.04, 0.0, trans_mod) * 0.25 * (0.6 + bass_energy * 0.8);

	// Palette color transitions
	vec3 c_div = lane_line_color.rgb;
	vec3 c_acc = accent_line_color.rgb;
	vec3 chrono_cyan = vec3(0.25, 0.95, 1.0);
	c_div = mix(c_div, chrono_cyan, chrono_blend * 0.85);
	c_acc = mix(c_acc, vec3(0.8, 0.3, 1.0), chrono_blend * 0.85);

	// Floor base: dark obsidian glass with high contrast
	vec3 albedo_out = floor_color.rgb;
	vec3 emissive_out = vec3(0.0);

	// Combine line and glow emissions
	emissive_out += c_div * (line_aa * 1.5 + line_glow) * (emission_energy + bass_energy * 2.0);
	emissive_out += c_acc * (outer_line * 1.2 + outer_glow) * (emission_energy + drop_intensity * 2.5);
	emissive_out += grid_tint_color.rgb * trans_line * (1.0 + bass_energy * 1.5);

	ALBEDO = albedo_out;
	ROUGHNESS = 0.25;
	METALLIC = 0.15;
	SPECULAR = 0.5;
	EMISSION = emissive_out;
}
