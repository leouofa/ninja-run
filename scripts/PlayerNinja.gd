# scripts/PlayerNinja.gd
class_name PlayerNinja
extends CharacterBody3D

signal died(reason: String)
signal stumbled()
signal slashed_enemy(enemy_name: String, points: int)
signal coin_collected(value: int)
signal slowdown_collected()
signal turn_executed(direction: int)

const LANE_WIDTH: float = 1.8
const BASE_FORWARD_SPEED: float = 18.0
const JUMP_VELOCITY: float = 8.5
const GRAVITY: float = 24.0

var current_lane: int = 0 # -1: Left, 0: Center, 1: Right
var target_lane_x: float = 0.0
var lane_x: float = 0.0

var is_jumping: bool = false
var is_sliding: bool = false
var slide_timer: float = 0.0
const SLIDE_DURATION: float = 0.65

var is_slashing: bool = false
var slash_timer: float = 0.0
const SLASH_DURATION: float = 0.35

var is_dead: bool = false
var has_stumbled: bool = false
var stumble_timer: float = 0.0
const STUMBLE_RECOVERY_TIME: float = 6.0

var current_direction: Vector3 = Vector3(0, 0, -1)

# QTE Turn Variables
var qte_turn_active: bool = false
var qte_allow_left: bool = false
var qte_allow_right: bool = false
var qte_junction_pos: Vector3 = Vector3.ZERO
var qte_active_zone: TurnZone = null

var is_turning_corner: bool = false
var turn_start_pos: Vector3 = Vector3.ZERO
var turn_target_pos: Vector3 = Vector3.ZERO
var turn_start_dir: Vector3 = Vector3.FORWARD
var turn_target_dir: Vector3 = Vector3.FORWARD
var turn_start_rot_y: float = 0.0
var turn_target_rot_y: float = 0.0
var turn_progress: float = 0.0
const TURN_CORNER_DURATION: float = 0.22 # Smooth auto-steering curve in 0.22s

# Child nodes
var visual_root: Node3D
var slash_mesh: MeshInstance3D
var ninja_model: Node3D

func _ready() -> void:
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)

	# Load ninja model
	var model_scene = load("res://assets/models/ninja_player.glb")
	if model_scene:
		ninja_model = model_scene.instantiate()
		visual_root.add_child(ninja_model)

	_setup_slash_fx()
	_setup_collision()

func _setup_collision() -> void:
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1.2, 1.8, 1.2)
	col.shape = box
	col.position = Vector3(0, 0.9, 0)
	add_child(col)

func _setup_slash_fx() -> void:
	slash_mesh = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(2.4, 1.2)
	slash_mesh.mesh = quad
	slash_mesh.position = Vector3(0, 1.0, -1.2)
	slash_mesh.rotation_degrees = Vector3(-15, 0, 0)

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.9, 1.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 1.0, 1.0)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	slash_mesh.material_override = mat
	slash_mesh.visible = false
	visual_root.add_child(slash_mesh)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_handle_input()
	_update_timers(delta)
	_update_movement(delta)
	_update_animation_blend(delta)

func _handle_input() -> void:
	# QTE Turn takes precedence over lane switching when in a turn window
	if Input.is_action_just_pressed("move_left"):
		if qte_turn_active and qte_allow_left:
			_execute_qte_turn(-1)
		elif not qte_turn_active:
			_switch_lane(-1)

	elif Input.is_action_just_pressed("move_right"):
		if qte_turn_active and qte_allow_right:
			_execute_qte_turn(1)
		elif not qte_turn_active:
			_switch_lane(1)

	# Jump (W / Up Arrow)
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_sliding and not is_turning_corner:
		velocity.y = JUMP_VELOCITY
		is_jumping = true

	# Slide (S / Down Arrow / Ctrl)
	if Input.is_action_just_pressed("slide") and is_on_floor() and not is_sliding and not is_turning_corner:
		is_sliding = true
		slide_timer = SLIDE_DURATION
		visual_root.scale = Vector3(1.0, 0.45, 1.0)
		visual_root.position.y = 0.0

	# Katana Slash (Space / F / Left Click)
	if Input.is_action_just_pressed("slash") and not is_slashing:
		perform_slash()

func _switch_lane(dir: int) -> void:
	var new_lane = clampi(current_lane + dir, -1, 1)
	if new_lane != current_lane:
		current_lane = new_lane
		target_lane_x = float(current_lane) * LANE_WIDTH

func _execute_qte_turn(dir: int) -> void:
	# dir = -1 for Left (90 deg CCW), +1 for Right (90 deg CW)
	qte_turn_active = false
	if qte_active_zone and is_instance_valid(qte_active_zone):
		qte_active_zone.has_turned = true

	is_turning_corner = true
	turn_progress = 0.0

	var current_p = global_position if is_inside_tree() else position
	turn_start_pos = current_p
	turn_start_rot_y = rotation.y
	turn_start_dir = -transform.basis.z

	var rot_angle = PI * 0.5 if dir == -1 else -PI * 0.5
	turn_target_rot_y = turn_start_rot_y + rot_angle
	turn_target_dir = turn_start_dir.rotated(Vector3.UP, rot_angle).normalized()

	# Destination: centered on the new roadway
	var corner_center = Vector3(qte_junction_pos.x, current_p.y, qte_junction_pos.z)
	turn_target_pos = corner_center + turn_target_dir * (LANE_WIDTH * 1.5)

	# Reset lane offset on turn
	current_lane = 0
	target_lane_x = 0.0
	lane_x = 0.0

	if is_inside_tree() and get_tree():
		SoundEffects.play_sound(get_tree(), "turn")
	emit_signal("turn_executed", dir)

func perform_slash() -> void:
	is_slashing = true
	slash_timer = SLASH_DURATION
	slash_mesh.visible = true
	if is_inside_tree() and get_tree():
		SoundEffects.play_sound(get_tree(), "slash")

	# Slash visual sword strike rotation
	var tween = create_tween()
	tween.tween_property(visual_root, "rotation:y", deg_to_rad(35.0), 0.08)
	tween.tween_property(visual_root, "rotation:y", deg_to_rad(-25.0), 0.12)
	tween.tween_property(visual_root, "rotation:y", 0.0, 0.1)

	# Detect and kill all enemies within slash cone (up to 4.2m in front)
	var space_state = get_world_3d().direct_space_state
	var forward = -transform.basis.z
	var origin = global_position + Vector3(0, 0.8, 0)

	var shape_query = PhysicsShapeQueryParameters3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(4.5, 2.5, 4.5)
	shape_query.shape = box_shape
	shape_query.transform = Transform3D(Basis(), origin + forward * 2.0)
	shape_query.collide_with_areas = true
	shape_query.collide_with_bodies = true

	var results = space_state.intersect_shape(shape_query, 16)
	for hit in results:
		var collider = hit["collider"]
		if collider and collider.has_method("on_slashed"):
			collider.on_slashed()
		elif collider and collider.get_parent() and collider.get_parent().has_method("on_slashed"):
			collider.get_parent().on_slashed()

func _update_timers(delta: float) -> void:
	if is_slashing:
		slash_timer -= delta
		if slash_timer <= 0.0:
			is_slashing = false
			slash_mesh.visible = false

	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0.0:
			is_sliding = false
			visual_root.scale = Vector3(1.0, 1.0, 1.0)

	if has_stumbled:
		stumble_timer -= delta
		if stumble_timer <= 0.0:
			has_stumbled = false

func _update_movement(delta: float) -> void:
	# If smoothly cornering around an intersection
	if is_turning_corner:
		turn_progress += delta / TURN_CORNER_DURATION
		if turn_progress >= 1.0:
			turn_progress = 1.0
			is_turning_corner = false
			if is_inside_tree():
				global_position = turn_target_pos
			else:
				position = turn_target_pos
			rotation.y = turn_target_rot_y
			current_direction = turn_target_dir
		else:
			var current_y = global_position.y if is_inside_tree() else position.y
			var corner_center = Vector3(qte_junction_pos.x, current_y, qte_junction_pos.z)
			var p0 = turn_start_pos
			var p1 = corner_center
			var p2 = turn_target_pos
			var t = turn_progress
			# Quadratic Bezier curve
			var arc_pos = (1.0 - t) * (1.0 - t) * p0 + 2.0 * (1.0 - t) * t * p1 + t * t * p2
			if is_inside_tree():
				global_position = arc_pos
			else:
				position = arc_pos
			rotation.y = lerp_angle(turn_start_rot_y, turn_target_rot_y, t)
		return

	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		if is_jumping:
			is_jumping = false

	# Lateral lane interpolation
	var responsiveness = 16.0
	if Engine.time_scale < 0.9:
		responsiveness = 26.0 # Snappy responsiveness during Chrono slow-mo!
	lane_x = lerpf(lane_x, target_lane_x, responsiveness * delta)

	# Forward velocity along orientation
	var forward = -transform.basis.z
	var right = transform.basis.x

	var forward_vel = forward * BASE_FORWARD_SPEED
	var lateral_diff = (target_lane_x - lane_x)
	var lateral_vel = right * (lateral_diff * 12.0)

	velocity.x = forward_vel.x + lateral_vel.x
	velocity.z = forward_vel.z + lateral_vel.z

	move_and_slide()

	# Visual tilt on lane switch
	var target_tilt = clampf((target_lane_x - lane_x) * -0.25, -0.35, 0.35)
	visual_root.rotation.z = lerpf(visual_root.rotation.z, target_tilt, 15.0 * delta)

	# Pit fall check
	if global_position.y < -8.0:
		trigger_death("Fell into the abyss")

func _update_animation_blend(_delta: float) -> void:
	if not ninja_model:
		return
	if is_on_floor() and not is_sliding:
		var bob = sin(Time.get_ticks_msec() * 0.018) * 0.08
		ninja_model.position.y = abs(bob)
	else:
		ninja_model.position.y = 0.0

func trigger_stumble() -> void:
	if has_stumbled:
		trigger_death("Overcome by pursuing evil spirits")
		return

	has_stumbled = true
	stumble_timer = STUMBLE_RECOVERY_TIME
	if is_inside_tree() and get_tree():
		SoundEffects.play_sound(get_tree(), "stumble")
	emit_signal("stumbled")

func trigger_death(reason: String) -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector3.ZERO
	visible = false
	if is_inside_tree() and get_tree():
		SoundEffects.play_sound(get_tree(), "stumble")
	emit_signal("died", reason)

func enter_turn_zone(zone: TurnZone, left: bool, right: bool, junction_pos: Vector3, _next_dir: Vector3) -> void:
	qte_turn_active = true
	qte_active_zone = zone
	qte_allow_left = left
	qte_allow_right = right
	qte_junction_pos = junction_pos

func exit_turn_zone(zone: TurnZone) -> void:
	if qte_active_zone == zone:
		if qte_turn_active and not zone.has_turned:
			trigger_death("Missed the corner turn")
		qte_turn_active = false
		qte_active_zone = null

func collect_coin(value: int) -> void:
	coin_collected.emit(value)

func collect_slowdown() -> void:
	slowdown_collected.emit()

func record_slashed_enemy(enemy_name: String, points: int) -> void:
	slashed_enemy.emit(enemy_name, points)

