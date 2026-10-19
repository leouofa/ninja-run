# scripts/ChronoController.gd
class_name ChronoController
extends Node

signal charges_changed(new_count: int)
signal slowdown_started(duration_sec: float)
signal slowdown_ended()

const MAX_CHARGES: int = 3
const SLOWDOWN_FACTOR: float = 0.45
const SLOWDOWN_REAL_DURATION: float = 4.0 # 4 real-time seconds

var charges: int = 1
var is_slowed: bool = false
var slowdown_start_time_msec: int = 0
var _paused_at_msec: int = 0
var music_player: AudioStreamPlayer = null
var lowpass_filter: AudioEffectLowPassFilter = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var music_bus_idx = AudioServer.get_bus_index("Music")
	if music_bus_idx != -1:
		for i in range(AudioServer.get_bus_effect_count(music_bus_idx)):
			var eff = AudioServer.get_bus_effect(music_bus_idx, i)
			if eff is AudioEffectLowPassFilter:
				lowpass_filter = eff
				break

func set_music_player(player: AudioStreamPlayer) -> void:
	music_player = player

func add_charge() -> bool:
	if charges < MAX_CHARGES:
		charges += 1
		emit_signal("charges_changed", charges)
		return true
	return false

func activate_slowdown() -> bool:
	if is_slowed or charges <= 0:
		return false

	charges -= 1
	emit_signal("charges_changed", charges)
	is_slowed = true
	slowdown_start_time_msec = Time.get_ticks_msec()

	Engine.time_scale = SLOWDOWN_FACTOR
	if music_player:
		music_player.pitch_scale = SLOWDOWN_FACTOR

	if lowpass_filter:
		lowpass_filter.cutoff_hz = 2800.0

	if is_inside_tree() and get_tree():
		SoundEffects.play_sound(get_tree(), "slow_start")
	emit_signal("slowdown_started", SLOWDOWN_REAL_DURATION)
	return true

func set_paused(paused: bool) -> void:
	if paused:
		_paused_at_msec = Time.get_ticks_msec()
	else:
		if _paused_at_msec > 0:
			var pause_duration = Time.get_ticks_msec() - _paused_at_msec
			slowdown_start_time_msec += pause_duration
			_paused_at_msec = 0

func _process(_delta: float) -> void:
	if is_inside_tree() and get_tree().paused:
		return
	if is_slowed:
		var elapsed_real = (Time.get_ticks_msec() - slowdown_start_time_msec) / 1000.0
		if elapsed_real >= SLOWDOWN_REAL_DURATION:
			deactivate_slowdown()

func deactivate_slowdown() -> void:
	if not is_slowed:
		return
	is_slowed = false
	Engine.time_scale = 1.0
	if music_player:
		music_player.pitch_scale = 1.0

	if lowpass_filter:
		lowpass_filter.cutoff_hz = 20500.0

	if is_inside_tree() and get_tree():
		SoundEffects.play_sound(get_tree(), "slow_end")
	emit_signal("slowdown_ended")

func get_remaining_slowdown_ratio() -> float:
	if not is_slowed:
		return 0.0
	var elapsed_real = (Time.get_ticks_msec() - slowdown_start_time_msec) / 1000.0
	return clampf(1.0 - (elapsed_real / SLOWDOWN_REAL_DURATION), 0.0, 1.0)
