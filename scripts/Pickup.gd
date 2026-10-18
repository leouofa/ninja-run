# scripts/Pickup.gd
class_name Pickup
extends Area3D

@export var pickup_type: String = "koban" # koban (coin), slowdown (Toki-no-Tama)
var visual_mesh: Node3D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	body_entered.connect(_on_body_entered)

	var path = "res://assets/models/pickup_" + pickup_type + ".glb"
	if ResourceLoader.exists(path):
		var scene = load(path)
		if scene:
			visual_mesh = scene.instantiate()
			add_child(visual_mesh)

	var col = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.8
	col.shape = sphere
	col.position = Vector3(0, 0.9, 0)
	add_child(col)

func _process(delta: float) -> void:
	if visual_mesh:
		visual_mesh.rotation.y += 2.5 * delta
		visual_mesh.position.y = 0.9 + sin(Time.get_ticks_msec() * 0.006) * 0.15

func _on_body_entered(body: Node3D) -> void:
	if body is PlayerNinja:
		if pickup_type == "slowdown":
			SoundEffects.play_sound(get_tree(), "slow_start")
			body.emit_signal("slowdown_collected")
		else:
			SoundEffects.play_sound(get_tree(), "coin")
			body.emit_signal("coin_collected", 100)

		# Vanish pickup with tween
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector3(1.5, 1.5, 1.5), 0.1)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.1)
		tween.tween_callback(queue_free)
