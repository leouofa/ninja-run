# scripts/MainMenu.gd
extends Control

@onready var title_screen: VBoxContainer = $MarginContainer/TitleScreen
@onready var level_select_screen: VBoxContainer = $MarginContainer/LevelSelectScreen
@onready var high_scores_screen: VBoxContainer = $MarginContainer/HighScoresScreen
@onready var level_list_container: VBoxContainer = $MarginContainer/LevelSelectScreen/ScrollContainer/LevelList
@onready var high_score_list_container: VBoxContainer = $MarginContainer/HighScoresScreen/ScrollContainer/HighScoreList
@onready var audio_preview_player: AudioStreamPlayer = $AudioPreviewPlayer

var current_preview_track: String = ""

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
	_populate_levels()
	_show_title()

func _show_title() -> void:
	title_screen.visible = true
	level_select_screen.visible = false
	high_scores_screen.visible = false
	if audio_preview_player.playing:
		audio_preview_player.stop()

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

	var levels = gm.level_list
	for i in range(levels.size()):
		var item = levels[i]
		var row = PanelContainer.new()
		var h_box = HBoxContainer.new()
		h_box.add_theme_constant_override("separation", 15)

		# Index / Title label
		var title_lbl = Label.new()
		title_lbl.custom_minimum_size = Vector2(280, 40)
		var is_comp = gm.save_data["completed_tracks"].has(item["filename"])
		var comp_mark = " ✓" if is_comp else ""
		title_lbl.text = "%d. %s%s" % [i + 1, item["title"], comp_mark]
		title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h_box.add_child(title_lbl)

		# Duration
		var dur_lbl = Label.new()
		var m = int(floor(item["duration"] / 60.0))
		var s = int(item["duration"]) % 60
		dur_lbl.custom_minimum_size = Vector2(70, 40)
		dur_lbl.text = "%02d:%02d" % [m, s]
		dur_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h_box.add_child(dur_lbl)

		# Difficulty Stars
		var diff_lbl = Label.new()
		diff_lbl.custom_minimum_size = Vector2(90, 40)
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
		hs_lbl.custom_minimum_size = Vector2(130, 40)
		if hs > 0 or mk > 0:
			hs_lbl.text = "High: %d\n⚔ %d kills" % [hs, mk]
		else:
			hs_lbl.text = "High: 0"
		hs_lbl.modulate = Color(0.7, 0.9, 1.0)
		hs_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h_box.add_child(hs_lbl)

		# Mini Waveform Bar
		var wf_bar = ProgressBar.new()
		wf_bar.custom_minimum_size = Vector2(160, 24)
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

		# Preview Button
		var prev_btn = Button.new()
		prev_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		prev_btn.text = "Preview"
		prev_btn.pressed.connect(func(): _toggle_preview(item["path"], item["filename"]))
		h_box.add_child(prev_btn)

		# Play Button
		var play_btn = Button.new()
		play_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		play_btn.text = "Play"
		play_btn.pressed.connect(func():
			if audio_preview_player.playing:
				audio_preview_player.stop()
			var m_gm = _get_gm()
			if m_gm:
				m_gm.start_level_by_name(item["filename"])
		)
		h_box.add_child(play_btn)

		row.add_child(h_box)
		level_list_container.add_child(row)

func _populate_high_scores() -> void:
	for c in high_score_list_container.get_children():
		c.queue_free()

	var gm = _get_gm()
	if not gm:
		return

	var levels = gm.level_list
	for i in range(levels.size()):
		var item = levels[i]
		var row = PanelContainer.new()
		var h_box = HBoxContainer.new()
		h_box.add_theme_constant_override("separation", 15)

		# Index / Title
		var title_lbl = Label.new()
		title_lbl.custom_minimum_size = Vector2(280, 40)
		var is_comp = gm.save_data.get("completed_tracks", []).has(item["filename"])
		var comp_mark = " ✓" if is_comp else ""
		title_lbl.text = "%d. %s%s" % [i + 1, item["title"], comp_mark]
		title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h_box.add_child(title_lbl)

		# Duration
		var dur_lbl = Label.new()
		var m = int(floor(item["duration"] / 60.0))
		var s = int(item["duration"]) % 60
		dur_lbl.custom_minimum_size = Vector2(60, 40)
		dur_lbl.text = "%02d:%02d" % [m, s]
		dur_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h_box.add_child(dur_lbl)

		# Difficulty Stars
		var diff_lbl = Label.new()
		diff_lbl.custom_minimum_size = Vector2(70, 40)
		var stars = ""
		for star in range(item["difficulty"]):
			stars += "★"
		diff_lbl.text = stars
		diff_lbl.modulate = Color(1.0, 0.8, 0.2)
		diff_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h_box.add_child(diff_lbl)

		# High Score
		var hs = gm.get_high_score(item["filename"])
		var hs_lbl = Label.new()
		hs_lbl.custom_minimum_size = Vector2(140, 40)
		hs_lbl.text = "Score: %d" % hs
		hs_lbl.modulate = Color(0.4, 1.0, 0.5) if hs > 0 else Color(0.55, 0.55, 0.6)
		hs_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h_box.add_child(hs_lbl)

		# Max Kills
		var kills = gm.get_max_kills(item["filename"])
		var kills_lbl = Label.new()
		kills_lbl.custom_minimum_size = Vector2(130, 40)
		kills_lbl.text = "⚔ %d Kills" % kills
		kills_lbl.modulate = Color(1.0, 0.45, 0.3) if kills > 0 else Color(0.55, 0.55, 0.6)
		kills_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h_box.add_child(kills_lbl)

		# Completion Status
		var status_lbl = Label.new()
		status_lbl.custom_minimum_size = Vector2(130, 40)
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

		# Play Button
		var play_btn = Button.new()
		play_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		play_btn.text = "Play"
		play_btn.pressed.connect(func():
			if audio_preview_player.playing:
				audio_preview_player.stop()
			var m_gm = _get_gm()
			if m_gm:
				m_gm.start_level_by_name(item["filename"])
		)
		h_box.add_child(play_btn)

		row.add_child(h_box)
		high_score_list_container.add_child(row)

func _toggle_preview(path: String, filename: String) -> void:
	if current_preview_track == filename and audio_preview_player.playing:
		audio_preview_player.stop()
		current_preview_track = ""
		return

	var stream = load(path)
	if stream:
		current_preview_track = filename
		audio_preview_player.stream = stream
		audio_preview_player.bus = "Music"
		audio_preview_player.play()

func _on_campaign_pressed() -> void:
	if audio_preview_player.playing:
		audio_preview_player.stop()
	var gm = _get_gm()
	if gm:
		var unl_idx = gm.save_data.get("unlocked_campaign_index", 0)
		gm.start_level_by_index(unl_idx)

func _on_level_select_pressed() -> void:
	_show_level_select()

func _on_high_scores_pressed() -> void:
	_show_high_scores()

func _on_back_pressed() -> void:
	_show_title()
