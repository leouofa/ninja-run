# scripts/Obstacle.gd
class_name Obstacle
extends Area3D

@export var obstacle_type: String = "barricade" # barricade (jump over), high_gate (slide under)
var visual_mesh: Node3D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_setup()

func _setup() -> void:
	var path = "res://assets/models/obstacle_" + obstacle_type + ".glb"
	if ResourceLoader.exists(path):
		var scene = load(path)
		if scene:
			visual_mesh = scene.instantiate()
			add_child(visual_mesh)

	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	if obstacle_type == "barricade":
		box.size = Vector3(1.8, 0.7, 0.8) # Low barricade
		col.position = Vector3(0, 0.35, 0)
	else:
		box.size = Vector3(2.2, 0.9, 0.8) # High beam / gate
		col.position = Vector3(0, 1.45, 0)
	col.shape = box
	add_child(col)

func on_slashed() -> void:
	# Wood splinters on slash
	SoundEffects.play_sound(get_tree(), "slash")
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		players[0].emit_signal("slashed_enemy", "barricade", 100)
	queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body is PlayerNinja:
		if body.is_slashing:
			on_slashed()
			return

		if obstacle_type == "barricade":
			# Can jump over
			if body.global_position.y > global_position.y + 0.65:
				return # Cleared jump
			body.trigger_stumble()
		else: # high_gate
			# Can slide under
			if body.is_sliding:
				return # Cleared slide
			body.trigger_stumble()
