# scripts/MainMenu.gd
extends Control

@onready var background: ColorRect = $Background
@onready var title_screen: VBoxContainer = $MarginContainer/TitleScreen
@onready var level_select_screen: VBoxContainer = $MarginContainer/LevelSelectScreen
@onready var high_scores_screen: VBoxContainer = $MarginContainer/HighScoresScreen
@onready var level_list_container: VBoxContainer = $MarginContainer/LevelSelectScreen/ScrollContainer/LevelList
@onready var high_score_list_container: VBoxContainer = $MarginContainer/HighScoresScreen/ScrollContainer/HighScoreList
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var audio_preview_player: AudioStreamPlayer = $AudioPreviewPlayer

var current_preview_track: String = ""
var bg_material: ShaderMaterial
var spectrum_analyzer: AudioEffectSpectrumAnalyzerInstance

var cur_bass: float = 0.0
var cur_mid: float = 0.0
var cur_high: float = 0.0

var bgm_tracks: Array[String] = []
var current_bgm_track: String = ""

func _get_gm() -> Node:
	if is_inside_tree() and get_tree() and get_tree().root:
		var gm = get_tree().root.get_node_or_null("GameManager")
		if gm:
			return gm
	if get_parent() and get_parent().has_node("GameManager"):
		return get_parent().get_node("GameManager")
	return null

func _ready() -> void:
	# Ensure normal engine time scale
	Engine.time_scale = 1.0
	randomize()
	if background and background.material is ShaderMaterial:
		bg_material = background.material as ShaderMaterial
	_init_spectrum_analyzer()
	if not bgm_player.finished.is_connected(_on_bgm_finished):
		bgm_player.finished.connect(_on_bgm_finished)
	if not audio_preview_player.finished.is_connected(_on_preview_finished):
		audio_preview_player.finished.connect(_on_preview_finished)
	_populate_levels()
	_init_bgm_playlist()
	_play_random_bgm()
	_show_title()

func _show_title() -> void:
	title_screen.visible = true
	level_select_screen.visible = false
	high_scores_screen.visible = false
	if audio_preview_player.playing:
		audio_preview_player.stop()
		current_preview_track = ""
	if bgm_player.stream_paused:
		bgm_player.stream_paused = false
	elif not bgm_player.playing:
		_play_random_bgm()

func _show_level_select() -> void:
	title_screen.visible = false
	level_select_screen.visible = true
	high_scores_screen.visible = false

func _show_high_scores() -> void:
	title_screen.visible = false
	level_select_screen.visible = false
	high_scores_screen.visible = true
	_populate_high_scores()

func _populate_levels() -> void:
	# Clear existing items
	for c in level_list_container.get_children():
		c.queue_free()

	var gm = _get_gm()
	if not gm:
		return

	if gm.level_list.is_empty():
		if gm.has_method("_load_waveforms"):
			gm._load_waveforms()
		if gm.has_method("_build_level_list"):
			gm._build_level_list()

	var levels = gm.level_list
	for i in range(levels.size()):
		var item = levels[i]
		var row = PanelContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h_box = HBoxContainer.new()
		h_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h_box.add_theme_constant_override("separation", 15)

		# Index / Title label
		var title_lbl = Label.new()
		title_lbl.custom_minimum_size = Vector2(200, 40)
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_lbl.size_flags_stretch_ratio = 3.2
		title_lbl.clip_text = true
		title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var is_comp = gm.save_data["completed_tracks"].has(item["filename"])
		var comp_mark = " ✓" if is_comp else ""
		title_lbl.text = "%d. %s%s" % [i + 1, item["title"], comp_mark]
		title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h_box.add_child(title_lbl)

		# Duration
		var dur_lbl = Label.new()
		var m = int(floor(item["duration"] / 60.0))
		var s = int(item["duration"]) % 60
		dur_lbl.custom_minimum_size = Vector2(60, 40)
		dur_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dur_lbl.size_flags_stretch_ratio = 0.8
		dur_lbl.text = "%02d:%02d" % [m, s]
		dur_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h_box.add_child(dur_lbl)

		# Difficulty Stars
		var diff_lbl = Label.new()
		diff_lbl.custom_minimum_size = Vector2(75, 40)
		diff_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		diff_lbl.size_flags_stretch_ratio = 1.0
		var stars = ""
		for star in range(item["difficulty"]):
			stars += "★"
		diff_lbl.text = stars
		diff_lbl.modulate = Color(1.0, 0.8, 0.2)
		diff_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h_box.add_child(diff_lbl)

		# High Score & Max Kills
		var hs = gm.get_high_score(item["filename"])
		var mk = gm.get_max_kills(item["filename"])
		var hs_lbl = Label.new()
		hs_lbl.custom_minimum_size = Vector2(90, 40)
		hs_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hs_lbl.size_flags_stretch_ratio = 1.4
		if hs > 0 or mk > 0:
			hs_lbl.text = "%d\n⚔ %d" % [hs, mk]
		else:
			hs_lbl.text = "—"
		hs_lbl.modulate = Color(0.7, 0.9, 1.0) if hs > 0 else Color(0.55, 0.55, 0.6)
		hs_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h_box.add_child(hs_lbl)

		# Mini Waveform Bar
		var wf_bar = ProgressBar.new()
		wf_bar.custom_minimum_size = Vector2(100, 24)
		wf_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wf_bar.size_flags_stretch_ratio = 1.8
		wf_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		wf_bar.max_value = 1.0
		wf_bar.show_percentage = false
		var wf = item.get("waveform", {})
		var rms = wf.get("rms", [])
		if rms.size() > 0:
			var avg_rms = float(rms[min(10, rms.size() - 1)])
			wf_bar.value = avg_rms
		else:
			wf_bar.value = 0.5
		h_box.add_child(wf_bar)

		# Actions Box (Preview and Play)
		var actions_box = HBoxContainer.new()
		actions_box.custom_minimum_size = Vector2(130, 40)
		actions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions_box.size_flags_stretch_ratio = 1.8
		actions_box.alignment = BoxContainer.ALIGNMENT_END
		actions_box.add_theme_constant_override("separation", 8)

		var prev_btn = Button.new()
		prev_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		prev_btn.text = "Preview"
		prev_btn.pressed.connect(func(): _toggle_preview(item["path"], item["filename"]))
		actions_box.add_child(prev_btn)

		var play_btn = Button.new()
		play_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		play_btn.text = "Play"
		play_btn.pressed.connect(func():
			_stop_all_audio()
			var m_gm = _get_gm()
			if m_gm:
				m_gm.start_level_by_name(item["filename"])
		)
		actions_box.add_child(play_btn)

		for btn in [prev_btn, play_btn]:
			btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			for state in ["normal", "hover", "pressed"]:
				var orig = btn.get_theme_stylebox(state)
				if orig is StyleBoxFlat:
					var sb = orig.duplicate()
					sb.content_margin_top = 2.0
					sb.content_margin_bottom = 2.0
					btn.add_theme_stylebox_override(state, sb)
		prev_btn.custom_minimum_size = Vector2(75, 26)
		play_btn.custom_minimum_size = Vector2(60, 26)

		h_box.add_child(actions_box)
		row.add_child(h_box)
		level_list_container.add_child(row)

func _populate_high_scores() -> void:
	for c in high_score_list_container.get_children():
		c.queue_free()

	var gm = _get_gm()
	if not gm:
		return

	if gm.level_list.is_empty():
		if gm.has_method("_load_waveforms"):
			gm._load_waveforms()
		if gm.has_method("_build_level_list"):
			gm._build_level_list()

	var levels = gm.level_list
	for i in range(levels.size()):
		var item = levels[i]
		var row = PanelContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h_box = HBoxContainer.new()
		h_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h_box.add_theme_constant_override("separation", 15)

		# Index / Title
		var title_lbl = Label.new()
		title_lbl.custom_minimum_size = Vector2(250, 40)
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_lbl.size_flags_stretch_ratio = 4.0
		title_lbl.clip_text = true
		title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var is_comp = gm.save_data.get("completed_tracks", []).has(item["filename"])
		var comp_mark = " ✓" if is_comp else ""
		title_lbl.text = "%d. %s%s" % [i + 1, item["title"], comp_mark]
		title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h_box.add_child(title_lbl)

		# Duration
		var dur_lbl = Label.new()
		var m = int(floor(item["duration"] / 60.0))
		var s = int(item["duration"]) % 60
		dur_lbl.custom_minimum_size = Vector2(65, 40)
		dur_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dur_lbl.size_flags_stretch_ratio = 1.0
		dur_lbl.text = "%02d:%02d" % [m, s]
		dur_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h_box.add_child(dur_lbl)

		# High Score
		var hs = gm.get_high_score(item["filename"])
		var hs_lbl = Label.new()
		hs_lbl.custom_minimum_size = Vector2(110, 40)
		hs_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hs_lbl.size_flags_stretch_ratio = 1.8
		hs_lbl.text = str(hs) if hs > 0 else "—"
		hs_lbl.modulate = Color(0.4, 1.0, 0.5) if hs > 0 else Color(0.55, 0.55, 0.6)
		hs_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h_box.add_child(hs_lbl)

		# Max Kills
		var kills = gm.get_max_kills(item["filename"])
		var kills_lbl = Label.new()
		kills_lbl.custom_minimum_size = Vector2(95, 40)
		kills_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kills_lbl.size_flags_stretch_ratio = 1.5
		kills_lbl.text = str(kills) if kills > 0 else "—"
		kills_lbl.modulate = Color(1.0, 0.45, 0.3) if kills > 0 else Color(0.55, 0.55, 0.6)
		kills_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h_box.add_child(kills_lbl)

		# Completion Status
		var status_lbl = Label.new()
		status_lbl.custom_minimum_size = Vector2(120, 40)
		status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		status_lbl.size_flags_stretch_ratio = 1.7
		if is_comp:
			status_lbl.text = "Torii Cleared"
			status_lbl.modulate = Color(0.3, 0.9, 1.0)
		else:
			var pct = gm.save_data.get("best_percentages", {}).get(item["filename"], 0.0)
			if pct > 0:
				status_lbl.text = "Best: %.1f%%" % pct
				status_lbl.modulate = Color(0.9, 0.7, 0.2)
			else:
				status_lbl.text = "Unattempted"
				status_lbl.modulate = Color(0.5, 0.5, 0.55)
		status_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h_box.add_child(status_lbl)

		row.add_child(h_box)
		high_score_list_container.add_child(row)

func _toggle_preview(path: String, filename: String) -> void:
	if current_preview_track == filename and audio_preview_player.playing:
		audio_preview_player.stop()
		current_preview_track = ""
		_resume_bgm()
		return

	# Pause BGM while listening to preview
	if bgm_player.playing:
		bgm_player.stream_paused = true

	var stream = load(path)
	if stream:
		current_preview_track = filename
		audio_preview_player.stream = stream
		audio_preview_player.bus = "Music"
		audio_preview_player.play()

func _on_preview_finished() -> void:
	current_preview_track = ""
	_resume_bgm()

func _resume_bgm() -> void:
	if bgm_player.stream:
		bgm_player.stream_paused = false
		if not bgm_player.playing:
			bgm_player.play()
	else:
		_play_random_bgm()

func _init_bgm_playlist() -> void:
	bgm_tracks.clear()
	var gm = _get_gm()
	if gm:
		if gm.level_list.is_empty():
			if gm.has_method("_load_waveforms"):
				gm._load_waveforms()
			if gm.has_method("_build_level_list"):
				gm._build_level_list()
		if gm.level_list.size() > 0:
			for lvl in gm.level_list:
				bgm_tracks.append(lvl["path"])
		elif gm.has_method("_discover_track_files"):
			for f in gm._discover_track_files():
				bgm_tracks.append("res://tracks/" + f)

	if bgm_tracks.is_empty():
		var dir = DirAccess.open("res://tracks")
		if dir:
			dir.list_dir_begin()
			var f = dir.get_next()
			while f != "":
				if not dir.current_is_dir():
					var clean_name = f
					if clean_name.ends_with(".remap"):
						clean_name = clean_name.trim_suffix(".remap")
					elif clean_name.ends_with(".import"):
						clean_name = clean_name.trim_suffix(".import")
					if clean_name.to_lower().ends_with(".mp3"):
						bgm_tracks.append("res://tracks/" + clean_name)
				f = dir.get_next()
			dir.list_dir_end()

func _play_random_bgm() -> void:
	if bgm_tracks.is_empty():
		_init_bgm_playlist()
	if bgm_tracks.is_empty():
		return

	var candidates = bgm_tracks.duplicate()
	if candidates.size() > 1 and current_bgm_track != "":
		candidates.erase(current_bgm_track)

	var picked_path = candidates[randi() % candidates.size()]
	current_bgm_track = picked_path

	var stream = load(picked_path)
	if stream:
		bgm_player.stream = stream
		bgm_player.bus = "Music"
		if bgm_player.is_inside_tree():
			bgm_player.play()

func _on_bgm_finished() -> void:
	_play_random_bgm()

func _stop_all_audio() -> void:
	if bgm_player.playing:
		bgm_player.stop()
	if audio_preview_player.playing:
		audio_preview_player.stop()

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

func _process(delta: float) -> void:
	if not bg_material:
		return

	var target_bass: float = 0.0
	var target_mid: float = 0.0
	var target_high: float = 0.0

	if spectrum_analyzer:
		var mag_bass = spectrum_analyzer.get_magnitude_for_frequency_range(20.0, 150.0).length()
		var mag_mid = spectrum_analyzer.get_magnitude_for_frequency_range(150.0, 2000.0).length()
		var mag_high = spectrum_analyzer.get_magnitude_for_frequency_range(2000.0, 10000.0).length()

		target_bass = clamp(mag_bass * 3.0, 0.0, 1.5)
		target_mid = clamp(mag_mid * 3.8, 0.0, 1.5)
		target_high = clamp(mag_high * 4.8, 0.0, 1.5)

	var attack = min(1.0, 28.0 * delta)
	var decay = min(1.0, 7.5 * delta)

	cur_bass = lerp(cur_bass, target_bass, attack if target_bass > cur_bass else decay)
	cur_mid = lerp(cur_mid, target_mid, attack if target_mid > cur_mid else decay)
	cur_high = lerp(cur_high, target_high, attack if target_high > cur_high else decay)

	bg_material.set_shader_parameter("bass_energy", cur_bass)
	bg_material.set_shader_parameter("mid_energy", cur_mid)
	bg_material.set_shader_parameter("high_energy", cur_high)

func _on_campaign_pressed() -> void:
	_stop_all_audio()
	var gm = _get_gm()
	if gm:
		if gm.level_list.is_empty():
			if gm.has_method("_load_waveforms"):
				gm._load_waveforms()
			if gm.has_method("_build_level_list"):
				gm._build_level_list()
		var unl_idx = gm.save_data.get("unlocked_campaign_index", 0)
		gm.start_level_by_index(unl_idx)

func _on_level_select_pressed() -> void:
	_show_level_select()

func _on_high_scores_pressed() -> void:
	_show_high_scores()

func _on_exit_pressed() -> void:
	_stop_all_audio()
	get_tree().quit()

func _on_back_pressed() -> void:
	_show_title()
