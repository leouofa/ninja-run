# scripts/TrackPaletteGenerator.gd
class_name TrackPaletteGenerator
extends Object

static func generate_palette(track_info: Dictionary) -> Dictionary:
	var title: String = str(track_info.get("title", track_info.get("filename", "Unknown"))).to_lower()
	var difficulty: int = int(track_info.get("difficulty", 3))
	var duration: float = float(track_info.get("duration", 180.0))
	var wf: Dictionary = track_info.get("waveform", {})
	var seed_val: int = int(wf.get("seed", title.hash()))

	# Compute spectral averages from waveform arrays
	var rms_list: Array = wf.get("rms", [])
	var low_list: Array = wf.get("low", [])
	var high_list: Array = wf.get("high", [])
	var beats: Array = wf.get("beats", [])

	var avg_rms: float = _compute_avg(rms_list, 0.25)
	var avg_low: float = _compute_avg(low_list, 0.22)
	var avg_high: float = _compute_avg(high_list, 0.12)
	var beat_density: float = float(beats.size()) / max(30.0, duration)

	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val

	# Small deterministic jitter per track so every track has a distinct signature
	var hue_jitter: float = rng.randf_range(-0.045, 0.045)
	var sat_boost: float = clamp((avg_rms - 0.2) * 0.4 + float(difficulty - 3) * 0.03, -0.08, 0.15)
	var bass_ratio: float = clamp(avg_low / max(0.05, avg_low + avg_high), 0.2, 0.85)

	var theme_name: String = _detect_theme(title, difficulty, bass_ratio, seed_val)

	var primary_hue: float = 0.52
	var secondary_hue: float = 0.88
	var sun_top_hue: float = 0.14
	var sun_bot_hue: float = 0.92
	var sky_hue: float = 0.76

	match theme_name:
		"frost":
			# Glacial navy, electric ice cyan, frost-blue & pale aurora gold
			sky_hue = _wrap_hue(0.60 + hue_jitter * 0.6)
			primary_hue = _wrap_hue(0.51 + hue_jitter)      # Ice cyan
			secondary_hue = _wrap_hue(0.64 - hue_jitter)    # Deep azure/indigo
			sun_top_hue = _wrap_hue(0.48 + hue_jitter * 0.5)
			sun_bot_hue = _wrap_hue(0.58 + hue_jitter * 0.5)
		"inferno":
			# Obsidian crimson, molten gold/orange, hellfire red/magenta
			sky_hue = _wrap_hue(0.97 + hue_jitter * 0.5)
			primary_hue = _wrap_hue(0.02 + hue_jitter * 0.6)   # Crimson/Scarlet
			secondary_hue = _wrap_hue(0.09 + hue_jitter * 0.6) # Molten orange/gold
			sun_top_hue = _wrap_hue(0.13 + hue_jitter * 0.4)
			sun_bot_hue = _wrap_hue(0.98 + hue_jitter * 0.4)
		"pharaoh":
			# Desert twilight violet, solar gold, turquoise & amethyst
			sky_hue = _wrap_hue(0.79 + hue_jitter * 0.6)
			primary_hue = _wrap_hue(0.12 + hue_jitter * 0.6)   # Solar gold
			secondary_hue = _wrap_hue(0.49 - hue_jitter * 0.7) # Turquoise/teal
			sun_top_hue = _wrap_hue(0.14 + hue_jitter * 0.4)
			sun_bot_hue = _wrap_hue(0.05 + hue_jitter * 0.4)
		"storm":
			# Stormy slate/indigo, volt lightning blue, emerald/gold accents
			sky_hue = _wrap_hue(0.66 + hue_jitter * 0.6)
			primary_hue = _wrap_hue(0.56 + hue_jitter * 0.8)   # Electric storm blue
			secondary_hue = _wrap_hue(0.39 + hue_jitter * 0.8) # Emerald/volt green-cyan
			sun_top_hue = _wrap_hue(0.15 + hue_jitter * 0.5)
			sun_bot_hue = _wrap_hue(0.60 + hue_jitter * 0.5)
		_:
			# Cyber / Outrun Neon: synthesized from seed + bass/treble balance
			var seed_hue_shift = float( abs(seed_val % 1000) ) / 1000.0 * 0.18 - 0.09
			sky_hue = _wrap_hue(0.77 + seed_hue_shift * 0.5)
			primary_hue = _wrap_hue(0.50 + seed_hue_shift + (0.5 - bass_ratio) * 0.12)
			secondary_hue = _wrap_hue(0.89 - seed_hue_shift + (bass_ratio - 0.5) * 0.12)
			sun_top_hue = _wrap_hue(0.14 + hue_jitter * 0.5)
			sun_bot_hue = _wrap_hue(0.91 + seed_hue_shift * 0.5)

	var sky_top_color = Color.from_hsv(sky_hue, clamp(0.78 + sat_boost, 0.5, 0.95), 0.10, 1.0)
	var sky_horizon_color = Color.from_hsv(_wrap_hue(secondary_hue * 0.6 + sky_hue * 0.4), clamp(0.82 + sat_boost, 0.55, 0.96), clamp(0.36 + avg_rms * 0.18, 0.28, 0.52), 1.0)

	var sun_top_color = Color.from_hsv(sun_top_hue, clamp(0.80 + sat_boost * 0.5, 0.60, 0.95), 1.0, 1.0)
	var sun_bottom_color = Color.from_hsv(sun_bot_hue, clamp(0.92 + sat_boost * 0.5, 0.75, 1.0), 0.98, 1.0)

	var grid_primary_color = Color.from_hsv(primary_hue, clamp(0.92 + sat_boost, 0.75, 1.0), 1.0, 1.0)
	var grid_secondary_color = Color.from_hsv(secondary_hue, clamp(0.90 + sat_boost, 0.75, 1.0), 1.0, 1.0)

	var mountain_color = Color.from_hsv(sky_hue, 0.72, 0.14, 1.0)
	var mountain_rim_color = grid_primary_color.lerp(grid_secondary_color, 0.35)

	var fog_color = sky_horizon_color.lerp(grid_secondary_color, 0.22)
	fog_color.v = clamp(fog_color.v * 0.65, 0.12, 0.35)

	var ambient_color = sky_horizon_color.lerp(grid_primary_color, 0.3)
	ambient_color.v = clamp(0.32 + avg_rms * 0.15, 0.25, 0.48)

	var light_color = sun_top_color.lerp(grid_primary_color, 0.35)
	light_color.s = clamp(light_color.s * 0.55, 0.2, 0.65)
	light_color.v = 0.95

	var curb_accent_color = grid_primary_color.lerp(grid_secondary_color, 0.4)

	var grid_speed_base = clamp(0.45 + avg_rms * 0.65 + beat_density * 0.25 + float(difficulty) * 0.05, 0.45, 1.25)

	return {
		"theme": theme_name,
		"sky_top_color": sky_top_color,
		"sky_horizon_color": sky_horizon_color,
		"sun_top_color": sun_top_color,
		"sun_bottom_color": sun_bottom_color,
		"grid_primary_color": grid_primary_color,
		"grid_secondary_color": grid_secondary_color,
		"mountain_color": mountain_color,
		"mountain_rim_color": mountain_rim_color,
		"fog_color": fog_color,
		"ambient_color": ambient_color,
		"light_color": light_color,
		"curb_accent_color": curb_accent_color,
		"grid_speed_base": grid_speed_base,
		"avg_rms": avg_rms,
		"avg_low": avg_low,
		"avg_high": avg_high,
		"difficulty": difficulty,
		"seed": seed_val
	}

static func _detect_theme(title: String, difficulty: int, bass_ratio: float, seed_val: int) -> String:
	for kw in ["iced", "myst", "water", "sparkling", "broke car"]:
		if title.contains(kw):
			return "frost"
	for kw in ["armageddon", "wrath", "flame", "lucifer", "lilith", "exorcist", "azrael", "bad side"]:
		if title.contains(kw):
			return "inferno"
	for kw in ["pharaoh", "osiris", "pyramid", "temple", "peaches", "thrones"]:
		if title.contains(kw):
			return "pharaoh"
	for kw in ["thunder", "zeus", "loki", "viking", "mead", "olaf", "immortals", "god mode"]:
		if title.contains(kw):
			return "storm"
	for kw in ["neon", "silicon", "mainframe", "widjet", "beat", "remix", "pantheon", "olympus"]:
		if title.contains(kw):
			return "cyber"

	# Fallback based on spectral profile + difficulty + seed
	if difficulty >= 5 or bass_ratio > 0.68:
		return "inferno"
	elif bass_ratio < 0.45:
		return "frost"
	var themes = ["cyber", "storm", "pharaoh", "inferno", "frost"]
	return themes[abs(seed_val) % themes.size()]

static func _compute_avg(arr: Array, default_val: float) -> float:
	if arr.is_empty():
		return default_val
	var total: float = 0.0
	var step: int = max(1, int(float(arr.size()) / 200.0))
	var count: int = 0
	for i in range(0, arr.size(), step):
		total += float(arr[i])
		count += 1
	return total / float(max(1, count))

static func _wrap_hue(h: float) -> float:
	var res = fmod(h, 1.0)
	if res < 0.0:
		res += 1.0
	return res
