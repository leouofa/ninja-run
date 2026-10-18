# scripts/GameWorld.gd
extends Node3D

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
@onready var slowmo_vignette: ColorRect = $HUD/SlowmoVignette

# Victory & Game Over Screens
@onready var victory_panel: PanelContainer = $HUD/VictoryPanel
@onready var victory_stats: Label = $HUD/VictoryPanel/VBox/StatsLabel
@onready var game_over_panel: PanelContainer = $HUD/GameOverPanel
@onready var death_reason_lbl: Label = $HUD/GameOverPanel/VBox/ReasonLabel
@onready var death_pct_lbl: Label = $HUD/GameOverPanel/VBox/PctLabel

var player: PlayerNinja
var track_name: String = ""
var track_info: Dictionary = {}
var duration: float = 180.0
var score: int = 0
var combo: int = 1
var coins: int = 0
var yokai_slain: int = 0
var game_ended: bool = false

# Pursuing spirits visual nodes
var chasing_spirits: Array[Node3D] = []

func _ready() -> void:
	# Reset state
	Engine.time_scale = 1.0
	victory_panel.visible = false
	game_over_panel.visible = false
	turn_prompt.visible = false
	stumble_warning.visible = false
	slowmo_vignette.visible = false

	# Setup current level
	var gm = get_node_or_null("/root/GameManager")
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

	# Spawn Player
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
	chrono_controller.charges_changed.connect(_update_chrono_ui)
	chrono_controller.slowdown_started.connect(func(_dur): slowmo_vignette.visible = true)
	chrono_controller.slowdown_ended.connect(func(): slowmo_vignette.visible = false)
	_update_chrono_ui(chrono_controller.charges)

	# Build Track
	track_gen.goal_reached.connect(_on_goal_reached)
	track_gen.build_track_for_level(track_info)

	# Start Music
	var track_path = track_info.get("path", "res://tracks/" + track_name)
	var stream = load(track_path)
	if stream:
		music_player.stream = stream
		music_player.bus = "Music"
		music_player.finished.connect(_on_music_finished)
		music_player.play()

	_setup_chasing_spirits()

func _setup_chasing_spirits() -> void:
	var spirit_scene = load("res://assets/models/enemy_spirit.glb")
	if spirit_scene:
		for i in range(3):
			var sp = spirit_scene.instantiate()
			sp.visible = false
			add_child(sp)
			chasing_spirits.append(sp)

func _input(event: InputEvent) -> void:
	if game_ended:
		return
	if event.is_action_pressed("slow_time"):
		chrono_controller.activate_slowdown()

func _process(delta: float) -> void:
	if game_ended:
		return

	_update_camera(delta)
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

func _on_slowdown_collected() -> void:
	chrono_controller.add_charge()

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
	chrono_controller.deactivate_slowdown()
	SoundEffects.play_sound(get_tree(), "coin")
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.record_completion(track_name, score, combo)

	victory_panel.visible = true
	victory_stats.text = "Final Score: %d\nCoins: %d | Yōkai Slain: %d\nMax Combo: x%d\nTrack Duration: %s" % [
		score, coins, yokai_slain, combo, time_lbl.text
	]

func _on_player_died(reason: String) -> void:
	if game_ended:
		return
	game_ended = true
	chrono_controller.deactivate_slowdown()
	if music_player.playing:
		music_player.stop()

	var curr_time = music_player.get_playback_position()
	var pct = clampf((curr_time / duration) * 100.0, 0.0, 99.9)
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.record_failure(track_name, pct, reason)

	game_over_panel.visible = true
	death_reason_lbl.text = "DEFEAT: %s" % reason
	death_pct_lbl.text = "Track Completed: %.1f%%\nScore: %d | Yōkai Slain: %d" % [pct, score, yokai_slain]

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
