# scripts/EnemyBase.gd
class_name EnemyBase
extends Area3D

@export var enemy_type: String = "spirit" # spirit, skeleton, witch, samurai, tengu, oni, lantern
@export var point_value: int = 250
@export var is_fatal: bool = false # Heavy hits vs light hits if unslashed

var is_dead: bool = false
var visual_mesh: Node3D
var ground_ring: MeshInstance3D
var shader_mat: ShaderMaterial

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_load_model()
	_setup_psychedelic_shader()
	_setup_ground_ring()

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

func _setup_psychedelic_shader() -> void:
	var shader = load("res://shaders/psychedelic_entity.gdshader")
	if not shader:
		return

	shader_mat = ShaderMaterial.new()
	shader_mat.shader = shader
	shader_mat.set_shader_parameter("pattern_mode", 1) # Scrolling Plasma Veins
	shader_mat.set_shader_parameter("pattern_speed", 2.8)
	shader_mat.set_shader_parameter("pattern_scale", 4.0)

	if is_fatal or enemy_type in ["oni", "samurai"]:
		# Fatal heavy brute: Deep Blood-Crimson & Hellfire Red-Orange
		shader_mat.set_shader_parameter("albedo_color", Color(0.04, 0.01, 0.01))
		shader_mat.set_shader_parameter("emission_color", Color(1.0, 0.04, 0.06))
		shader_mat.set_shader_parameter("secondary_color", Color(1.0, 0.32, 0.02))
		shader_mat.set_shader_parameter("emission_energy", 4.6)
		shader_mat.set_shader_parameter("rim_power", 2.6)
		shader_mat.set_shader_parameter("rim_boost", 2.8)
	elif enemy_type == "tengu":
		# Aerial swooper: Laser Crimson & Scarlet-Magenta
		shader_mat.set_shader_parameter("albedo_color", Color(0.04, 0.01, 0.02))
		shader_mat.set_shader_parameter("emission_color", Color(1.0, 0.06, 0.14))
		shader_mat.set_shader_parameter("secondary_color", Color(1.0, 0.12, 0.42))
		shader_mat.set_shader_parameter("emission_energy", 4.4)
		shader_mat.set_shader_parameter("rim_power", 2.8)
		shader_mat.set_shader_parameter("rim_boost", 2.5)
	else:
		# Standard slashable Yōkai (spirit, skeleton, witch, lantern): Neon Scarlet Red & Hot Blood-Magenta
		shader_mat.set_shader_parameter("albedo_color", Color(0.04, 0.01, 0.02))
		shader_mat.set_shader_parameter("emission_color", Color(1.0, 0.08, 0.16))
		shader_mat.set_shader_parameter("secondary_color", Color(1.0, 0.06, 0.38))
		shader_mat.set_shader_parameter("emission_energy", 4.4)
		shader_mat.set_shader_parameter("rim_power", 2.8)
		shader_mat.set_shader_parameter("rim_boost", 2.5)

	if visual_mesh:
		_apply_material_recursive(visual_mesh, shader_mat)

func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)

func _setup_ground_ring() -> void:
	# Ground threat marker: Red ring + X-Crosshair blades on the track floor
	ground_ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	var is_heavy = is_fatal or enemy_type in ["oni", "samurai"]
	torus.inner_radius = 0.85 if is_heavy else 0.68
	torus.outer_radius = 1.05 if is_heavy else 0.86
	ground_ring.mesh = torus
	ground_ring.position = Vector3(0, 0.04 - position.y, 0) # Anchored on the track floor

	var ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var col = Color(1.0, 0.04, 0.06) if is_heavy else Color(1.0, 0.08, 0.14)
	ring_mat.albedo_color = col
	ring_mat.emission_enabled = true
	ring_mat.emission = col
	ring_mat.emission_energy_multiplier = 3.4
	ground_ring.material_override = ring_mat

	# Crossed diagonal blades forming an unmistakable Red Target Crosshair
	var cross_len = (torus.inner_radius * 1.8)
	for angle in [45.0, -45.0]:
		var blade = MeshInstance3D.new()
		var b_mesh = BoxMesh.new()
		b_mesh.size = Vector3(cross_len, 0.01, 0.08)
		blade.mesh = b_mesh
		blade.rotation_degrees.y = angle
		blade.material_override = ring_mat
		ground_ring.add_child(blade)

	add_child(ground_ring)

func update_audio_reactivity(bass: float, drop: float, chrono: float) -> void:
	if shader_mat:
		shader_mat.set_shader_parameter("bass_energy", bass)
		shader_mat.set_shader_parameter("drop_intensity", drop)
		shader_mat.set_shader_parameter("chrono_blend", chrono)

func _process(_delta: float) -> void:
	if is_dead:
		return
	# Idle yōkai bobbing / floating animation
	if visual_mesh:
		if enemy_type in ["spirit", "lantern", "tengu"]:
			visual_mesh.position.y = sin(Time.get_ticks_msec() * 0.005) * 0.25

	if ground_ring:
		var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.1
		ground_ring.scale = Vector3(pulse, 1.0, pulse)

func on_slashed() -> void:
	if is_dead:
		return
	is_dead = true
	var found_player = false
	if is_inside_tree() and get_tree():
		SoundEffects.play_sound(get_tree(), "enemy_kill")
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var player = players[0]
			found_player = true
			if player.has_method("record_slashed_enemy"):
				player.record_slashed_enemy(enemy_type, point_value)
			else:
				player.slashed_enemy.emit(enemy_type, point_value)
	if not found_player and get_parent():
		for child in get_parent().get_children():
			if child.is_in_group("player"):
				if child.has_method("record_slashed_enemy"):
					child.record_slashed_enemy(enemy_type, point_value)
				else:
					child.slashed_enemy.emit(enemy_type, point_value)
				break

	# Death burst animation
	if ground_ring:
		ground_ring.queue_free()

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
			# Disperse the enemy after stumble without awarding kill or points
			disperse()

func disperse() -> void:
	if is_dead:
		return
	is_dead = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if ground_ring:
		ground_ring.queue_free()
	if visual_mesh:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(visual_mesh, "scale", Vector3(0.01, 0.01, 0.01), 0.15)
		tween.tween_property(visual_mesh, "position:y", visual_mesh.position.y + 0.8, 0.15)
		tween.chain().tween_callback(queue_free)
	else:
		queue_free()
