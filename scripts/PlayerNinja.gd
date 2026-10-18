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

var current_direction: Vector3 = Vector3.FORWARD
var can_turn_left: bool = false
var can_turn_right: bool = false
var turn_box_active: bool = false
var active_turn_node: Node3D = null

# Child nodes
var visual_root: Node3D
var slash_mesh: MeshInstance3D
var ninja_model: Node3D
var shadow_mesh: Decal

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
	# Lane switching or Turning
	if Input.is_action_just_pressed("move_left"):
		if turn_box_active and can_turn_left:
			_execute_turn(-1)
		else:
			_switch_lane(-1)

	elif Input.is_action_just_pressed("move_right"):
		if turn_box_active and can_turn_right:
			_execute_turn(1)
		else:
			_switch_lane(1)

	# Jump (W / Up Arrow)
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_sliding:
		velocity.y = JUMP_VELOCITY
		is_jumping = true

	# Slide (S / Down Arrow / Ctrl)
	if Input.is_action_just_pressed("slide") and is_on_floor() and not is_sliding:
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

func _execute_turn(dir: int) -> void:
	# dir = -1 for Left (90 deg CCW), +1 for Right (90 deg CW)
	turn_box_active = false
	can_turn_left = false
	can_turn_right = false

	# Snap ninja forward direction
	var rot_angle = -PI / 2.0 if dir == 1 else PI / 2.0
	current_direction = current_direction.rotated(Vector3.UP, rot_angle).normalized()
	rotation.y += rot_angle

	# Align ninja position to the turn junction center
	if active_turn_node and is_instance_valid(active_turn_node):
		var center_pos = active_turn_node.global_position
		# Preserve height
		var current_y = global_position.y
		global_position = Vector3(center_pos.x, current_y, center_pos.z)

	# Reset lane offset on turn
	current_lane = 0
	target_lane_x = 0.0
	lane_x = 0.0

	SoundEffects.play_sound(get_tree(), "turn")
	emit_signal("turn_executed", dir)

func perform_slash() -> void:
	is_slashing = true
	slash_timer = SLASH_DURATION
	slash_mesh.visible = true
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

	# Query overlapping bodies/areas
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

func _update_animation_blend(delta: float) -> void:
	if not ninja_model:
		return
	if is_on_floor() and not is_sliding:
		# Procedural running bob
		var bob = sin(Time.get_ticks_msec() * 0.018) * 0.08
		ninja_model.position.y = abs(bob)
	else:
		ninja_model.position.y = 0.0

func trigger_stumble() -> void:
	if has_stumbled:
		# Second stumble while spirits are close is fatal!
		trigger_death("Overcome by pursuing evil spirits")
		return

	has_stumbled = true
	stumble_timer = STUMBLE_RECOVERY_TIME
	SoundEffects.play_sound(get_tree(), "stumble")
	emit_signal("stumbled")

func trigger_death(reason: String) -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector3.ZERO
	visible = false
	SoundEffects.play_sound(get_tree(), "stumble")
	emit_signal("died", reason)

func enter_turn_zone(turn_node: Node3D, left: bool, right: bool) -> void:
	turn_box_active = true
	active_turn_node = turn_node
	can_turn_left = left
	can_turn_right = right

func exit_turn_zone(turn_node: Node3D) -> void:
	if active_turn_node == turn_node:
		# If the player exits the turn zone without executing a required turn, fatal cliff plunge!
		if turn_box_active and (can_turn_left or can_turn_right):
			trigger_death("Missed the corner turn")
		turn_box_active = false
		can_turn_left = false
		can_turn_right = false
		active_turn_node = null
