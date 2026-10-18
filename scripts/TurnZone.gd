# scripts/TurnZone.gd
class_name TurnZone
extends Area3D

@export var allow_left: bool = true
@export var allow_right: bool = false
@export var junction_world_pos: Vector3 = Vector3.ZERO
@export var turn_angle_rad: float = 0.0 # ±PI/2
@export var next_direction: Vector3 = Vector3.FORWARD

var has_turned: bool = false

func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func setup_zone(incoming_dir: Vector3, junction_pos: Vector3, left: bool, right: bool) -> void:
	allow_left = left
	allow_right = right
	junction_world_pos = junction_pos

	# Calculate next direction
	if right and not left:
		turn_angle_rad = -PI * 0.5
		next_direction = incoming_dir.rotated(Vector3.UP, -PI * 0.5).normalized()
	elif left and not right:
		turn_angle_rad = PI * 0.5
		next_direction = incoming_dir.rotated(Vector3.UP, PI * 0.5).normalized()
	else: # T-junction: can go either way
		turn_angle_rad = 0.0
		next_direction = incoming_dir

	# Create collision box extending 14m back along incoming path
	# and 3m past junction center
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	var total_len = 16.0
	box.size = Vector3(14.0, 4.0, total_len)
	col.shape = box

	# Position the box so it covers 13m before junction and 3m past it
	var local_offset_z = (total_len * 0.5) - 3.0
	col.position = Vector3(0, 2.0, local_offset_z)
	add_child(col)

func _on_body_entered(body: Node3D) -> void:
	if body is PlayerNinja:
		body.enter_turn_zone(self, allow_left, allow_right, junction_world_pos, next_direction)

func _on_body_exited(body: Node3D) -> void:
	if body is PlayerNinja:
		body.exit_turn_zone(self)
