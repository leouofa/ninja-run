# scripts/GameManager.gd
extends Node

signal level_started(track_name: String)
signal level_completed(track_name: String, score: int, max_combo: int)
signal level_failed(track_name: String, percentage: float, reason: String)

const WAVEFORMS_PATH = "res://data/waveforms.json"
const SAVE_PATH = "user://ninja_save.json"

var waveforms: Dictionary = {}
var level_list: Array[Dictionary] = []
var current_level_index: int = 0
var current_track_name: String = ""

# Player Save state
var save_data: Dictionary = {
	"high_scores": {},
	"best_percentages": {},
	"completed_tracks": [],
	"unlocked_campaign_index": 0
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input_actions()
	_setup_audio_buses()
	_load_waveforms()
	_build_level_list()
	_load_save_data()

func _setup_input_actions() -> void:
	var actions = {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_W, KEY_UP],
		"slide": [KEY_S, KEY_DOWN, KEY_CTRL],
		"slash": [KEY_SPACE, KEY_F],
		"slow_time": [KEY_SHIFT],
		"pause": [KEY_ESCAPE, KEY_P]
	}

	for action in actions.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode in actions[action]:
			var ev = InputEventKey.new()
			ev.physical_keycode = keycode
			# Check if event already exists
			var exists = false
			for existing in InputMap.action_get_events(action):
				if existing is InputEventKey and existing.physical_keycode == keycode:
					exists = true
					break
			if not exists:
				InputMap.action_add_event(action, ev)

	# Add mouse click for slash
	var mouse_ev = InputEventMouseButton.new()
	mouse_ev.button_index = MOUSE_BUTTON_LEFT
	var mouse_exists = false
	for existing in InputMap.action_get_events("slash"):
		if existing is InputEventMouseButton and existing.button_index == MOUSE_BUTTON_LEFT:
			mouse_exists = true
			break
	if not mouse_exists:
		InputMap.action_add_event("slash", mouse_ev)

func _setup_audio_buses() -> void:
	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx == -1:
		AudioServer.add_bus()
		music_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_idx, "Music")

	# Check or add LowPassFilter on Music bus
	var has_lpf = false
	for i in range(AudioServer.get_bus_effect_count(music_idx)):
		if AudioServer.get_bus_effect(music_idx, i) is AudioEffectLowPassFilter:
			has_lpf = true
			break
	if not has_lpf:
		var lpf = AudioEffectLowPassFilter.new()
		lpf.cutoff_hz = 20500.0
		AudioServer.add_bus_effect(music_idx, lpf)

	# Check or add SpectrumAnalyzer on Music bus
	var has_spec = false
	for i in range(AudioServer.get_bus_effect_count(music_idx)):
		if AudioServer.get_bus_effect(music_idx, i) is AudioEffectSpectrumAnalyzer:
			has_spec = true
			break
	if not has_spec:
		var spec = AudioEffectSpectrumAnalyzer.new()
		AudioServer.add_bus_effect(music_idx, spec)

	# SFX Bus
	var sfx_idx = AudioServer.get_bus_index("SFX")
	if sfx_idx == -1:
		AudioServer.add_bus()
		sfx_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(sfx_idx, "SFX")

func _load_waveforms() -> void:
	if FileAccess.file_exists(WAVEFORMS_PATH):
		var file = FileAccess.open(WAVEFORMS_PATH, FileAccess.READ)
		var text = file.get_as_text()
		var json = JSON.new()
		if json.parse(text) == OK:
			waveforms = json.data

func _build_level_list() -> void:
	level_list.clear()
	var dir = DirAccess.open("res://tracks")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.to_lower().ends_with(".mp3"):
				var wf = waveforms.get(file_name, {})
				var duration = wf.get("duration", 180.0)
				var difficulty = wf.get("difficulty", 3)
				var beats = wf.get("beats", [])
				level_list.append({
					"filename": file_name,
					"title": file_name.get_basename(),
					"path": "res://tracks/" + file_name,
					"duration": duration,
					"difficulty": difficulty,
					"beats_count": beats.size(),
					"waveform": wf
				})
			file_name = dir.get_next()
		dir.list_dir_end()

	# Sort levels by duration and difficulty for campaign flow
	level_list.sort_custom(func(a, b):
		if a["difficulty"] == b["difficulty"]:
			return a["duration"] < b["duration"]
		return a["difficulty"] < b["difficulty"]
	)

func get_waveform_for_track(track_name: String) -> Dictionary:
	if waveforms.has(track_name):
		return waveforms[track_name]
	# Fallback synthetic waveform if untracked
	return {
		"duration": 180.0,
		"bucket_rate_hz": 10,
		"sample_count_buckets": 1800,
		"rms": [],
		"low": [],
		"high": [],
		"beats": [],
		"seed": track_name.hash(),
		"difficulty": 3
	}

func start_level_by_name(track_name: String) -> void:
	current_track_name = track_name
	for i in range(level_list.size()):
		if level_list[i]["filename"] == track_name:
			current_level_index = i
			break
	emit_signal("level_started", track_name)
	get_tree().change_scene_to_file("res://scenes/GameWorld.tscn")

func start_level_by_index(idx: int) -> void:
	if idx >= 0 and idx < level_list.size():
		current_level_index = idx
		current_track_name = level_list[idx]["filename"]
		get_tree().change_scene_to_file("res://scenes/GameWorld.tscn")

func advance_to_next_level() -> void:
	var next_idx = (current_level_index + 1) % level_list.size()
	start_level_by_index(next_idx)

func return_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func record_completion(track_name: String, score: int, max_combo: int) -> void:
	if not save_data["completed_tracks"].has(track_name):
		save_data["completed_tracks"].append(track_name)
	var prev_score = save_data["high_scores"].get(track_name, 0)
	if score > prev_score:
		save_data["high_scores"][track_name] = score
	save_data["best_percentages"][track_name] = 100.0

	var curr_idx = 0
	for i in range(level_list.size()):
		if level_list[i]["filename"] == track_name:
			curr_idx = i
			break
	if curr_idx + 1 > save_data["unlocked_campaign_index"]:
		save_data["unlocked_campaign_index"] = curr_idx + 1

	_save_data_to_disk()
	emit_signal("level_completed", track_name, score, max_combo)

func record_failure(track_name: String, percentage: float, reason: String) -> void:
	var prev_pct = save_data["best_percentages"].get(track_name, 0.0)
	if percentage > prev_pct:
		save_data["best_percentages"][track_name] = percentage
	_save_data_to_disk()
	emit_signal("level_failed", track_name, percentage, reason)

func _save_data_to_disk() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))

func _load_save_data() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			if json.data is Dictionary:
				for k in json.data.keys():
					save_data[k] = json.data[k]
