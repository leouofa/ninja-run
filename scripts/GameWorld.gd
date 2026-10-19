# scripts/GameWorld.gd
extends Node3D

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var dir_light: DirectionalLight3D = $DirectionalLight3D
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var camera: Camera3D = $Camera3D
@onready var track_gen: WaveformTrackGenerator = $WaveformTrackGenerator
@onready var chrono_controller: ChronoController = $ChronoController

# UI Elements
@onready var hud: Control = $HUD
@onready var score_lbl: Label = $HUD/TopLeft/ScoreLabel
@onready var combo_lbl: Label = $HUD/TopLeft/ComboLabel
@onready var coins_lbl: Label = $HUD/TopLeft/CoinsLabel
@onready var time_bar: ProgressBar = $HUD/TopCenter/TimeBar
@onready var time_lbl: Label = $HUD/TopCenter/TimeLabel
@onready var turn_prompt: Label = $HUD/CenterPrompt
@onready var stumble_warning: Label = $HUD/StumbleWarning
@onready var chrono_slots: HBoxContainer = $HUD/BottomLeft/ChronoSlots
@onready var chrono_bar: ProgressBar = $HUD/BottomLeft/ChronoBar
@onready var postfx_rect: ColorRect = $HUD/PsychedelicPostFX
@onready var slowmo_vignette: ColorRect = $HUD/SlowmoVignette
@onready var pause_menu: Control = $HUD/PauseMenu

# Victory & Game Over Screens
@onready var victory_panel: PanelContainer = $HUD/VictoryPanel
@onready var victory_stats: Label = $HUD/VictoryPanel/VBox/StatsLabel
@onready var game_over_panel: PanelContainer = $HUD/GameOverPanel
@onready var death_reason_lbl: Label = $HUD/GameOverPanel/VBox/ReasonLabel
@onready var death_pct_lbl: Label = $HUD/GameOverPanel/VBox/PctLabel

var player: PlayerNinja
var track_name: String = ""
var track_info: Dictionary = {}
var track_palette: Dictionary = {}
var sky_material: ShaderMaterial
var spectrum_analyzer: AudioEffectSpectrumAnalyzerInstance

var cur_bass: float = 0.0
var cur_mid: float = 0.0
var cur_high: float = 0.0
var cur_drop: float = 0.0
var cur_chrono: float = 0.0
var grid_scroll_offset: float = 0.0
var grid_speed_base: float = 0.65

var duration: float = 180.0
var score: int = 0
var combo: int = 1
var coins: int = 0
var yokai_slain: int = 0
var game_ended: bool = false

# Pursuing spirits visual nodes
var chasing_spirits: Array[Node3D] = []

func _get_gm() -> Node:
	if is_inside_tree() and get_tree() and get_tree().root:
		var gm = get_tree().root.get_node_or_null("GameManager")
		if gm:
			return gm
	if get_parent() and get_parent().has_node("GameManager"):
		return get_parent().get_node("GameManager")
	return null

func _ready() -> void:
	# Reset state
	Engine.time_scale = 1.0
	if is_inside_tree() and get_tree():
		get_tree().paused = false
	victory_panel.visible = false
	game_over_panel.visible = false
	turn_prompt.visible = false
	stumble_warning.visible = false
	slowmo_vignette.visible = false

	# Setup current level
	var gm = _get_gm()
	if gm:
		track_name = gm.current_track_name
		if track_name.is_empty() and gm.level_list.size() > 0:
			track_name = gm.level_list[0]["filename"]
			gm.current_track_name = track_name

		for lvl in gm.level_list:
			if lvl["filename"] == track_name:
				track_info = lvl
				break

	duration = track_info.get("duration", 180.0)

	# Initialize Audio Spectrum Analyzer & Metadata Procedural Background
	_init_spectrum_analyzer()
	_setup_level_background()

	# Spawn Player (if not already spawned)
	if not player or not is_instance_valid(player):
		player = PlayerNinja.new()
		player.name = "PlayerNinja"
		player.add_to_group("player")
		add_child(player)
		player.position = Vector3(0, 0.5, 0)

		# Connect Player Signals
		player.died.connect(_on_player_died)
		player.stumbled.connect(_on_player_stumbled)
		player.slashed_enemy.connect(_on_enemy_slashed)
		player.coin_collected.connect(_on_coin_collected)
		player.slowdown_collected.connect(_on_slowdown_collected)
		player.turn_executed.connect(_on_turn_executed)

	# Setup ChronoController
	chrono_controller.set_music_player(music_player)
	if not chrono_controller.charges_changed.is_connected(_update_chrono_ui):
		chrono_controller.charges_changed.connect(_update_chrono_ui)
		chrono_controller.slowdown_started.connect(func(_dur): slowmo_vignette.visible = true)
		chrono_controller.slowdown_ended.connect(func(): slowmo_vignette.visible = false)
	_update_chrono_ui(chrono_controller.charges)

	# Build Track with track-specific palette
	track_gen.apply_track_palette(track_palette)
	if not track_gen.goal_reached.is_connected(_on_goal_reached):
		track_gen.goal_reached.connect(_on_goal_reached)
	track_gen.build_track_for_level(track_info)

	# Start Music
	var track_path = track_info.get("path", "res://tracks/" + track_name)
	var stream = load(track_path)
	if stream:
		music_player.stream = stream
		music_player.bus = "Music"
		if not music_player.finished.is_connected(_on_music_finished):
			music_player.finished.connect(_on_music_finished)
		if music_player.is_inside_tree():
			music_player.play()

	if chasing_spirits.is_empty():
		_setup_chasing_spirits()

	if pause_menu:
		pause_menu.setup(self, music_player)

func _init_spectrum_analyzer() -> void:
	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx == -1:
		AudioServer.add_bus()
		music_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_idx, "Music")

	var eff_idx = -1
	for i in range(AudioServer.get_bus_effect_count(music_idx)):
		if AudioServer.get_bus_effect(music_idx, i) is AudioEffectSpectrumAnalyzer:
			eff_idx = i
			break
	if eff_idx == -1:
		var spec = AudioEffectSpectrumAnalyzer.new()
		AudioServer.add_bus_effect(music_idx, spec)
		eff_idx = AudioServer.get_bus_effect_count(music_idx) - 1

	spectrum_analyzer = AudioServer.get_bus_effect_instance(music_idx, eff_idx)

func _setup_level_background() -> void:
	track_palette = TrackPaletteGenerator.generate_palette(track_info)
	grid_speed_base = float(track_palette.get("grid_speed_base", 0.65))

	if world_env and world_env.environment:
		var env = world_env.environment
		env.fog_light_color = track_palette.get("fog_color", Color(0.1, 0.12, 0.18))
		env.ambient_light_color = track_palette.get("ambient_color", Color(0.2, 0.25, 0.35))
		if env.sky and env.sky.sky_material is ShaderMaterial:
			sky_material = env.sky.sky_material as ShaderMaterial
			sky_material.set_shader_parameter("sky_top_color", track_palette["sky_top_color"])
			sky_material.set_shader_parameter("sky_horizon_color", track_palette["sky_horizon_color"])
			sky_material.set_shader_parameter("sun_top_color", track_palette["sun_top_color"])
			sky_material.set_shader_parameter("sun_bottom_color", track_palette["sun_bottom_color"])
			sky_material.set_shader_parameter("grid_primary_color", track_palette["grid_primary_color"])
			sky_material.set_shader_parameter("grid_secondary_color", track_palette["grid_secondary_color"])
			sky_material.set_shader_parameter("mountain_color", track_palette["mountain_color"])
			sky_material.set_shader_parameter("mountain_rim_color", track_palette["mountain_rim_color"])
			var seed_off = float(abs(int(track_palette.get("seed", 0)) % 1000)) * 0.01
			sky_material.set_shader_parameter("track_seed_offset", seed_off)
			sky_material.set_shader_parameter("bass_energy", 0.0)
			sky_material.set_shader_parameter("mid_energy", 0.0)
			sky_material.set_shader_parameter("high_energy", 0.0)
			sky_material.set_shader_parameter("drop_intensity", 0.0)
			sky_material.set_shader_parameter("chrono_blend", 0.0)
			sky_material.set_shader_parameter("scroll_offset", 0.0)

	if dir_light:
		dir_light.light_color = track_palette.get("light_color", Color(0.65, 0.78, 0.95))

func _update_reactive_background(delta: float) -> void:
	var target_bass: float = 0.0
	var target_mid: float = 0.0
	var target_high: float = 0.0
	var target_drop: float = 0.0

	# 1. Sample live audio spectrum
	if spectrum_analyzer:
		var mag_bass = spectrum_analyzer.get_magnitude_for_frequency_range(20.0, 150.0).length()
		var mag_mid = spectrum_analyzer.get_magnitude_for_frequency_range(150.0, 2000.0).length()
		var mag_high = spectrum_analyzer.get_magnitude_for_frequency_range(2000.0, 10000.0).length()

		target_bass = clamp(mag_bass * 3.0, 0.0, 1.5)
		target_mid = clamp(mag_mid * 3.8, 0.0, 1.5)
		target_high = clamp(mag_high * 4.8, 0.0, 1.5)

	# 2. Sample precomputed 10Hz track waveform envelope for drop intensity & fallback
	var wf: Dictionary = track_info.get("waveform", {})
	var curr_time: float = music_player.get_playback_position() if (music_player and music_player.playing) else 0.0
	var bucket_idx: int = int(curr_time * 10.0)
	var rms_list: Array = wf.get("rms", [])
	var low_list: Array = wf.get("low", [])
	var high_list: Array = wf.get("high", [])

	if bucket_idx >= 0 and bucket_idx < rms_list.size():
		var wf_rms = float(rms_list[bucket_idx])
		var wf_low = float(low_list[bucket_idx]) if bucket_idx < low_list.size() else wf_rms
		var wf_high = float(high_list[bucket_idx]) if bucket_idx < high_list.size() else wf_rms * 0.5

		target_bass = max(target_bass, wf_low * 1.35)
		target_mid = max(target_mid, wf_rms * 1.25)
		target_high = max(target_high, wf_high * 1.45)

		var avg_rms: float = float(track_palette.get("avg_rms", 0.25))
		if wf_rms > avg_rms * 1.15 or wf_low > 0.45:
			target_drop = clamp((wf_rms - avg_rms) * 2.5 + max(0.0, wf_low - 0.4) * 1.5, 0.0, 1.2)

	var attack = min(1.0, 26.0 * delta)
	var decay = min(1.0, 7.5 * delta)

	cur_bass = lerp(cur_bass, target_bass, attack if target_bass > cur_bass else decay)
	cur_mid = lerp(cur_mid, target_mid, attack if target_mid > cur_mid else decay)
	cur_high = lerp(cur_high, target_high, attack if target_high > cur_high else decay)
	cur_drop = lerp(cur_drop, target_drop, min(1.0, 6.0 * delta))

	var target_chrono: float = 1.0 if (chrono_controller and chrono_controller.is_slowed) else 0.0
	cur_chrono = lerp(cur_chrono, target_chrono, min(1.0, 8.0 * delta))

	var scroll_mult = (1.0 + cur_bass * 0.55 + cur_drop * 0.75) * lerp(1.0, 0.35, cur_chrono)
	grid_scroll_offset += delta * grid_speed_base * scroll_mult

	if sky_material:
		sky_material.set_shader_parameter("bass_energy", cur_bass)
		sky_material.set_shader_parameter("mid_energy", cur_mid)
		sky_material.set_shader_parameter("high_energy", cur_high)
		sky_material.set_shader_parameter("drop_intensity", cur_drop)
		sky_material.set_shader_parameter("chrono_blend", cur_chrono)
		sky_material.set_shader_parameter("scroll_offset", grid_scroll_offset)

	if world_env and world_env.environment:
		var base_fog: Color = track_palette.get("fog_color", Color(0.1, 0.12, 0.18))
		var pri_col: Color = track_palette.get("grid_primary_color", Color(0.0, 0.9, 1.0))
		var chrono_fog = Color(0.03, 0.22, 0.38)
		world_env.environment.fog_light_color = base_fog.lerp(pri_col * 0.45, cur_drop * 0.35).lerp(chrono_fog, cur_chrono * 0.8)
		world_env.environment.glow_bloom = 0.35 + cur_bass * 0.15 + cur_drop * 0.15

	if postfx_rect and postfx_rect.material is ShaderMaterial:
		var pfx_mat = postfx_rect.material as ShaderMaterial
		pfx_mat.set_shader_parameter("bass_energy", cur_bass)
		pfx_mat.set_shader_parameter("mid_energy", cur_mid)
		pfx_mat.set_shader_parameter("high_energy", cur_high)
		pfx_mat.set_shader_parameter("drop_intensity", cur_drop)
		pfx_mat.set_shader_parameter("chrono_blend", cur_chrono)
		var combo_ratio = clampf(float(combo - 1) / 7.0, 0.0, 1.0)
		pfx_mat.set_shader_parameter("combo_ratio", combo_ratio)

	if track_gen:
		track_gen.update_audio_reactivity(cur_bass, cur_drop, cur_chrono)

func _setup_chasing_spirits() -> void:
	var spirit_scene = load("res://assets/models/enemy_spirit.glb")
	if spirit_scene:
		var shader = load("res://shaders/psychedelic_entity.gdshader")
		var ghost_mat: ShaderMaterial = null
		if shader:
			ghost_mat = ShaderMaterial.new()
			ghost_mat.shader = shader
			ghost_mat.set_shader_parameter("pattern_mode", 1)
			ghost_mat.set_shader_parameter("albedo_color", Color(0.04, 0.01, 0.02))
			ghost_mat.set_shader_parameter("emission_color", Color(1.0, 0.08, 0.16))
			ghost_mat.set_shader_parameter("secondary_color", Color(1.0, 0.12, 0.42))
			ghost_mat.set_shader_parameter("emission_energy", 3.8)
			ghost_mat.set_shader_parameter("rim_power", 2.5)

		for i in range(3):
			var sp = spirit_scene.instantiate()
			sp.visible = false
			if ghost_mat:
				_apply_ghost_mat_recursive(sp, ghost_mat)
			add_child(sp)
			chasing_spirits.append(sp)

func _apply_ghost_mat_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_ghost_mat_recursive(child, mat)

func _input(event: InputEvent) -> void:
	if game_ended:
		return
	if event.is_action_pressed("slow_time"):
		chrono_controller.activate_slowdown()

func _process(delta: float) -> void:
	if game_ended:
		return

	_update_camera(delta)
	_update_reactive_background(delta)
	_update_hud()
	_update_turn_prompt(delta)
	_update_chasing_spirits(delta)

func _update_camera(delta: float) -> void:
	if not player or not is_instance_valid(player):
		return

	# Follow camera behind player
	var target_basis = player.transform.basis
	var cam_offset = target_basis.z * 5.2 + Vector3(0, 3.4, 0)
	var target_cam_pos = player.global_position + cam_offset

	camera.global_position = camera.global_position.lerp(target_cam_pos, 12.0 * delta)
	var look_target = player.global_position + Vector3(0, 1.6, 0) - target_basis.z * 2.0
	camera.look_at(look_target, Vector3.UP)

func _update_hud() -> void:
	score_lbl.text = "SCORE: %d" % score
	combo_lbl.text = "COMBO: x%d" % combo
	coins_lbl.text = "KOBAN: %d" % coins

	var curr_time = music_player.get_playback_position() if music_player.playing else 0.0
	var cur_m = int(floor(curr_time / 60.0))
	var cur_s = int(curr_time) % 60
	var tot_m = int(floor(duration / 60.0))
	var tot_s = int(duration) % 60

	time_lbl.text = "%02d:%02d / %02d:%02d" % [cur_m, cur_s, tot_m, tot_s]
	time_bar.max_value = duration
	time_bar.value = curr_time

	# Chrono slowdown countdown bar
	if chrono_controller.is_slowed:
		chrono_bar.visible = true
		chrono_bar.value = chrono_controller.get_remaining_slowdown_ratio()
	else:
		chrono_bar.visible = false

	# Stumble alert
	if player and player.has_stumbled:
		stumble_warning.visible = true
		stumble_warning.text = "⚠ SPIRITS PURSUING! AVOID HITS (%ds)" % int(ceil(player.stumble_timer))
	else:
		stumble_warning.visible = false

var turn_feedback_timer: float = 0.0

func _update_turn_prompt(delta: float) -> void:
	if not player:
		return

	if turn_feedback_timer > 0.0:
		turn_feedback_timer -= delta
		turn_prompt.visible = true
		return

	if player.qte_turn_active:
		turn_prompt.visible = true
		turn_prompt.modulate = Color(1.0, 0.85, 0.2, 1.0)
		var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.016) * 0.08
		turn_prompt.scale = Vector2(pulse, pulse)
		if player.qte_allow_left and player.qte_allow_right:
			turn_prompt.text = "◄◄ [A / LEFT] TURN LEFT  |  TURN RIGHT [D / RIGHT] ►►"
		elif player.qte_allow_left:
			turn_prompt.text = "◄◄ [A / LEFT] TURN LEFT ◄◄"
		elif player.qte_allow_right:
			turn_prompt.text = "►► [D / RIGHT] TURN RIGHT ►►"
	else:
		turn_prompt.visible = false
		turn_prompt.scale = Vector2.ONE

func _update_chasing_spirits(delta: float) -> void:
	if not player:
		return
	var show_spirits = player.has_stumbled
	for i in range(chasing_spirits.size()):
		var sp = chasing_spirits[i]
		sp.visible = show_spirits
		if show_spirits:
			var behind = player.transform.basis.z * (2.2 + i * 0.8)
			var side = player.transform.basis.x * ((i - 1) * 1.2)
			var target_pos = player.global_position + behind + side + Vector3(0, 0.8, 0)
			sp.global_position = sp.global_position.lerp(target_pos, 10.0 * delta)
			sp.look_at(player.global_position, Vector3.UP)

func _update_chrono_ui(count: int) -> void:
	for i in range(chrono_slots.get_child_count()):
		var orb = chrono_slots.get_child(i) as Control
		if orb:
			orb.modulate = Color(0.2, 0.9, 1.0, 1.0) if i < count else Color(0.2, 0.2, 0.3, 0.4)

func _on_enemy_slashed(_type: String, points: int) -> void:
	yokai_slain += 1
	var gained = points * combo
	score += gained
	combo = mini(combo + 1, 8)

func _on_coin_collected(val: int) -> void:
	coins += 1
	score += val * combo

func _on_slowdown_collected(val: int = 150) -> void:
	chrono_controller.add_charge()
	score += val * combo

func _on_turn_executed(_dir: int) -> void:
	var gained = 250 * combo
	score += gained
	turn_prompt.visible = true
	turn_prompt.text = "★ PERFECT TURN! +%d ★" % gained
	turn_prompt.modulate = Color(0.2, 1.0, 0.4, 1.0)
	turn_prompt.scale = Vector2(1.15, 1.15)
	turn_feedback_timer = 0.65

func _on_player_stumbled() -> void:
	combo = 1

func _on_music_finished() -> void:
	_on_goal_reached()

func _on_goal_reached() -> void:
	if game_ended:
		return
	game_ended = true
	if pause_menu and pause_menu.visible:
		pause_menu.resume_game()
	chrono_controller.deactivate_slowdown()
	SoundEffects.play_sound(get_tree(), "coin")

	var record_info: Dictionary = {
		"is_new_high_score": false,
		"prev_high_score": 0,
		"score_diff": 0,
		"is_new_max_kills": false,
		"prev_max_kills": 0,
		"kills_diff": 0,
		"high_score": score,
		"max_kills": yokai_slain
	}
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		record_info = gm.record_completion(track_name, score, combo, yokai_slain)

	victory_panel.visible = true

	var hs_line = ""
	if record_info.get("is_new_high_score", false):
		if record_info.get("prev_high_score", 0) > 0:
			hs_line = "★ NEW HIGH SCORE! (+%d over prev %d) ★" % [record_info["score_diff"], record_info["prev_high_score"]]
		else:
			hs_line = "★ FIRST CLEAR HIGH SCORE! ★"
	else:
		var best = record_info.get("high_score", score)
		var behind = best - score
		hs_line = "High Score: %d (%d behind record)" % [best, behind]

	var kills_line = "Yōkai Slain: %d" % yokai_slain
	if record_info.get("is_new_max_kills", false):
		if record_info.get("prev_max_kills", 0) > 0:
			kills_line += " (★ NEW RECORD! +%d ★)" % record_info["kills_diff"]
		else:
			kills_line += " (★ NEW RECORD! ★)"
	else:
		kills_line += " (Record: %d)" % record_info.get("max_kills", yokai_slain)

	victory_stats.text = "%s\nFinal Score: %d\nCoins: %d | %s\nMax Combo: x%d | Track Time: %s" % [
		hs_line, score, coins, kills_line, combo, time_lbl.text
	]

func _on_player_died(reason: String) -> void:
	if game_ended:
		return
	game_ended = true
	if pause_menu and pause_menu.visible:
		pause_menu.resume_game()
	chrono_controller.deactivate_slowdown()
	if music_player.playing:
		music_player.stop()

	var curr_time = music_player.get_playback_position()
	var pct = clampf((curr_time / duration) * 100.0, 0.0, 99.9)

	var record_info: Dictionary = {
		"is_new_high_score": false,
		"prev_high_score": 0,
		"score_diff": 0,
		"is_new_max_kills": false,
		"prev_max_kills": 0,
		"kills_diff": 0,
		"high_score": score,
		"max_kills": yokai_slain
	}
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		record_info = gm.record_failure(track_name, pct, reason, score, yokai_slain)

	game_over_panel.visible = true
	death_reason_lbl.text = "DEFEAT: %s" % reason

	var hs_line = ""
	if record_info.get("is_new_high_score", false):
		if record_info.get("prev_high_score", 0) > 0:
			hs_line = "★ NEW HIGH SCORE! (+%d) ★\n" % record_info["score_diff"]
		else:
			hs_line = "★ NEW HIGH SCORE! ★\n"
	else:
		var best = record_info.get("high_score", score)
		var behind = best - score
		hs_line = "High Score: %d (%d behind)\n" % [best, behind]

	var kills_line = "Yōkai Slain: %d" % yokai_slain
	if record_info.get("is_new_max_kills", false):
		kills_line += " (★ NEW RECORD! ★)"
	else:
		kills_line += " (Record: %d)" % record_info.get("max_kills", yokai_slain)

	death_pct_lbl.text = "%sTrack Completed: %.1f%%\nScore: %d | %s" % [
		hs_line, pct, score, kills_line
	]

# Button Callbacks
func _on_next_level_pressed() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.advance_to_next_level()

func _on_replay_pressed() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.start_level_by_name(track_name)

func _on_level_select_pressed() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.return_to_main_menu()
