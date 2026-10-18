# scripts/Pickup.gd
class_name Pickup
extends Area3D

@export var pickup_type: String = "koban" # koban (coin), slowdown (Toki-no-Tama)
var visual_mesh: Node3D

var is_collected: bool = false

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
	if is_collected:
		return
	if body is PlayerNinja:
		is_collected = true
		var tree = get_tree() if (is_inside_tree() and get_tree()) else null
		if pickup_type == "slowdown":
			if tree:
				SoundEffects.play_sound(tree, "slow_start")
			if body.has_method("collect_slowdown"):
				body.collect_slowdown(150)
			else:
				body.slowdown_collected.emit(150)
		else:
			if tree:
				SoundEffects.play_sound(tree, "coin")
			if body.has_method("collect_coin"):
				body.collect_coin(100)
			else:
				body.coin_collected.emit(100)

		# Disable monitoring and collisions immediately
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)

		# Vanish pickup with scale animation
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector3(1.3, 1.3, 1.3), 0.08)
		tween.tween_property(self, "scale", Vector3.ZERO, 0.08)
		tween.tween_callback(queue_free)

