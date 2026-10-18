# scripts/EnemyBase.gd
class_name EnemyBase
extends Area3D

@export var enemy_type: String = "spirit" # spirit, skeleton, witch, samurai, tengu, oni, lantern
@export var point_value: int = 250
@export var is_fatal: bool = false # Heavy hits vs light hits if unslashed

var is_dead: bool = false
var visual_mesh: Node3D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_load_model()

func _load_model() -> void:
	var path = "res://assets/models/enemy_" + enemy_type + ".glb"
	if ResourceLoader.exists(path):
		var scene = load(path)
		if scene:
			visual_mesh = scene.instantiate()
			add_child(visual_mesh)

	# Setup collision shape based on enemy size
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	if enemy_type == "oni":
		box.size = Vector3(2.0, 2.5, 1.5)
		is_fatal = true
		point_value = 500
	elif enemy_type == "samurai":
		box.size = Vector3(1.6, 2.2, 1.4)
		is_fatal = true
		point_value = 400
	elif enemy_type == "witch":
		box.size = Vector3(2.4, 1.8, 1.5)
		point_value = 350
	elif enemy_type == "tengu":
		box.size = Vector3(2.2, 1.6, 1.4)
		position.y = 1.2 # Hovering swooper
		point_value = 300
	else:
		box.size = Vector3(1.4, 1.8, 1.4)
		point_value = 250
	col.shape = box
	col.position = Vector3(0, box.size.y * 0.5, 0)
	add_child(col)

func _process(delta: float) -> void:
	if is_dead:
		return
	# Idle yōkai bobbing / floating animation
	if visual_mesh:
		if enemy_type in ["spirit", "lantern", "tengu"]:
			visual_mesh.position.y = sin(Time.get_ticks_msec() * 0.005) * 0.25

func on_slashed() -> void:
	if is_dead:
		return
	is_dead = true
	if is_inside_tree() and get_tree():
		SoundEffects.play_sound(get_tree(), "enemy_kill")
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			players[0].emit_signal("slashed_enemy", enemy_type, point_value)

	# Death burst animation
	if visual_mesh:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(visual_mesh, "scale", Vector3(0.01, 0.01, 0.01), 0.2)
		tween.tween_property(visual_mesh, "position:y", visual_mesh.position.y + 1.2, 0.2)
		tween.chain().tween_callback(queue_free)
	else:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if is_dead:
		return
	if body is PlayerNinja:
		if body.is_slashing:
			on_slashed()
			return

		# If tengu and player is sliding, player successfully ducks under
		if enemy_type == "tengu" and body.is_sliding:
			return

		if is_fatal:
			body.trigger_death("Struck down by cursed " + enemy_type.capitalize())
		else:
			body.trigger_stumble()
			# Disperse the enemy after stumble
			on_slashed()
