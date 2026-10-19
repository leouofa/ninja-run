# scripts/PauseMenu.gd
extends Control

signal game_paused(is_paused: bool)

enum ConfirmTarget { NONE, RESTART, MAIN_MENU }

@onready var dim_overlay: ColorRect = $DimOverlay
@onready var panel_container: PanelContainer = $PanelContainer
@onready var track_label: Label = $PanelContainer/VBox/TrackLabel
@onready var main_buttons: VBoxContainer = $PanelContainer/VBox/MainButtons
@onready var confirm_box: VBoxContainer = $PanelContainer/VBox/ConfirmBox
@onready var confirm_prompt: Label = $PanelContainer/VBox/ConfirmBox/ConfirmPrompt
@onready var confirm_btn: Button = $PanelContainer/VBox/ConfirmBox/ConfirmBtn
@onready var cancel_btn: Button = $PanelContainer/VBox/ConfirmBox/CancelBtn
@onready var resume_btn: Button = $PanelContainer/VBox/MainButtons/ResumeBtn
@onready var restart_btn: Button = $PanelContainer/VBox/MainButtons/RestartBtn
@onready var main_menu_btn: Button = $PanelContainer/VBox/MainButtons/MainMenuBtn

var confirm_target: ConfirmTarget = ConfirmTarget.NONE
var music_player: AudioStreamPlayer
var game_world: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_show_main_buttons()

	resume_btn.pressed.connect(_on_resume_pressed)
	restart_btn.pressed.connect(_on_restart_pressed)
	main_menu_btn.pressed.connect(_on_main_menu_pressed)
	confirm_btn.pressed.connect(_on_confirm_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)

func setup(world: Node, music: AudioStreamPlayer) -> void:
	game_world = world
	music_player = music
	update_track_label()

func update_track_label() -> void:
	if not track_label:
		return
	var title = ""
	if game_world and "track_info" in game_world and game_world.track_info is Dictionary:
		title = game_world.track_info.get("title", "")
	if title.is_empty() and game_world and "track_name" in game_world:
		title = game_world.track_name.get_basename()
	track_label.text = "Track: %s" % title if not title.is_empty() else ""

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if visible:
			_handle_pause_key_when_open()
		else:
			_try_open_pause_menu()

func _try_open_pause_menu() -> void:
	if game_world and "game_ended" in game_world and game_world.game_ended:
		return
	pause_game()

func pause_game() -> void:
	if game_world and "game_ended" in game_world and game_world.game_ended:
		return

	if is_inside_tree() and get_tree():
		get_tree().paused = true
	if music_player:
		music_player.stream_paused = true

	update_track_label()
	_show_main_buttons()
	visible = true
	if is_inside_tree():
		resume_btn.grab_focus()

	if game_world and "chrono_controller" in game_world and game_world.chrono_controller:
		if game_world.chrono_controller.has_method("set_paused"):
			game_world.chrono_controller.set_paused(true)

	emit_signal("game_paused", true)

func resume_game() -> void:
	if is_inside_tree() and get_tree():
		get_tree().paused = false
	if music_player:
		music_player.stream_paused = false

	if game_world and "chrono_controller" in game_world and game_world.chrono_controller:
		if game_world.chrono_controller.has_method("set_paused"):
			game_world.chrono_controller.set_paused(false)

	visible = false
	_show_main_buttons()
	emit_signal("game_paused", false)

func _handle_pause_key_when_open() -> void:
	if confirm_target != ConfirmTarget.NONE:
		_show_main_buttons()
	else:
		resume_game()

func _show_main_buttons() -> void:
	confirm_target = ConfirmTarget.NONE
	main_buttons.visible = true
	confirm_box.visible = false
	if is_inside_tree() and visible:
		resume_btn.grab_focus()

func _show_confirmation(target: ConfirmTarget, prompt: String, confirm_label: String) -> void:
	confirm_target = target
	main_buttons.visible = false
	confirm_box.visible = true
	confirm_prompt.text = prompt
	confirm_btn.text = confirm_label
	cancel_btn.grab_focus()

func _on_resume_pressed() -> void:
	resume_game()

func _on_restart_pressed() -> void:
	_show_confirmation(
		ConfirmTarget.RESTART,
		"Restart current level?\nAll run progress will be reset.",
		"Restart Level"
	)

func _on_main_menu_pressed() -> void:
	_show_confirmation(
		ConfirmTarget.MAIN_MENU,
		"Return to Main Menu?\nCurrent run progress will be lost.",
		"Return to Menu"
	)

func _on_confirm_pressed() -> void:
	var target = confirm_target
	confirm_target = ConfirmTarget.NONE
	visible = false

	if is_inside_tree() and get_tree():
		get_tree().paused = false
	if music_player:
		music_player.stream_paused = false

	if game_world and "chrono_controller" in game_world and game_world.chrono_controller:
		if game_world.chrono_controller.has_method("set_paused"):
			game_world.chrono_controller.set_paused(false)

	var gm = get_node_or_null("/root/GameManager")
	match target:
		ConfirmTarget.RESTART:
			if gm and game_world and "track_name" in game_world:
				gm.start_level_by_name(game_world.track_name)
		ConfirmTarget.MAIN_MENU:
			if gm:
				gm.return_to_main_menu()

func _on_cancel_pressed() -> void:
	_show_main_buttons()
