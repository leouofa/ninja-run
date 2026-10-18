# scripts/TurnZone.gd
class_name TurnZone
extends Area3D

@export var allow_left: bool = true
@export var allow_right: bool = false

func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(6.2, 4.0, 6.2)
	col.shape = box
	col.position = Vector3(0, 2.0, 0)
	add_child(col)

func _on_body_entered(body: Node3D) -> void:
	if body is PlayerNinja:
		body.enter_turn_zone(self, allow_left, allow_right)

func _on_body_exited(body: Node3D) -> void:
	if body is PlayerNinja:
		body.exit_turn_zone(self)
