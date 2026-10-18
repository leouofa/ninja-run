# scripts/Pickup.gd
class_name Pickup
extends Area3D

@export var pickup_type: String = "koban" # koban (coin), slowdown (Toki-no-Tama)
var visual_mesh: Node3D
var ground_ring: MeshInstance3D
var contrast_halo: MeshInstance3D
var shader_mat: ShaderMaterial

var is_collected: bool = false
const HOVER_HEIGHT: float = 1.05

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	var path = "res://assets/models/pickup_" + pickup_type + ".glb"
	if ResourceLoader.exists(path):
		var scene = load(path)
		if scene:
			visual_mesh = scene.instantiate()
			add_child(visual_mesh)
			visual_mesh.position.y = HOVER_HEIGHT

	_setup_psychedelic_shader()
	_setup_contrast_halo()
	_setup_ground_beacon()

	var col = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.9
	col.shape = sphere
	col.position = Vector3(0, HOVER_HEIGHT, 0)
	add_child(col)

func _setup_psychedelic_shader() -> void:
	var shader = load("res://shaders/psychedelic_entity.gdshader")
	if not shader:
		return

	shader_mat = ShaderMaterial.new()
	shader_mat.shader = shader
	shader_mat.set_shader_parameter("pattern_mode", 0) # Iridescent Shimmer

	if pickup_type == "slowdown":
		shader_mat.set_shader_parameter("albedo_color", Color(0.04, 0.08, 0.15))
		shader_mat.set_shader_parameter("emission_color", Color(0.2, 0.95, 1.0))
		shader_mat.set_shader_parameter("secondary_color", Color(0.85, 0.25, 1.0))
		shader_mat.set_shader_parameter("emission_energy", 5.5)
	else:
		shader_mat.set_shader_parameter("albedo_color", Color(0.12, 0.08, 0.02))
		shader_mat.set_shader_parameter("emission_color", Color(1.0, 0.85, 0.18))
		shader_mat.set_shader_parameter("secondary_color", Color(1.0, 0.18, 0.65))
		shader_mat.set_shader_parameter("emission_energy", 4.8)

	shader_mat.set_shader_parameter("rim_power", 2.0)
	shader_mat.set_shader_parameter("rim_boost", 2.6)
	shader_mat.set_shader_parameter("pattern_speed", 3.2)
	shader_mat.set_shader_parameter("pattern_scale", 4.5)

	# Apply material override recursively to all mesh instances inside visual_mesh
	if visual_mesh:
		_apply_material_recursive(visual_mesh, shader_mat)

func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)

func _setup_contrast_halo() -> void:
	# Subtle dark back-ring that guarantees contrast against blazing sun vistas
	contrast_halo = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.38 if pickup_type == "koban" else 0.48
	torus.outer_radius = 0.48 if pickup_type == "koban" else 0.60
	contrast_halo.mesh = torus
	contrast_halo.rotation_degrees.x = 90.0

	var halo_mat = StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var rim_col = Color(1.0, 0.8, 0.2) if pickup_type == "koban" else Color(0.2, 0.9, 1.0)
	halo_mat.albedo_color = rim_col
	halo_mat.emission_enabled = true
	halo_mat.emission = rim_col
	halo_mat.emission_energy_multiplier = 2.0
	contrast_halo.material_override = halo_mat

	if visual_mesh:
		visual_mesh.add_child(contrast_halo)

func _setup_ground_beacon() -> void:
	# Glowing ground ring on the dark track floor directly beneath the pickup
	ground_ring = MeshInstance3D.new()
	var ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.55
	ring_mesh.outer_radius = 0.72
	ground_ring.mesh = ring_mesh
	ground_ring.position = Vector3(0, 0.04, 0) # Just above track surface

	var ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var emit_col = Color(1.0, 0.75, 0.15) if pickup_type == "koban" else Color(0.15, 0.9, 1.0)
	ring_mat.albedo_color = emit_col
	ring_mat.emission_enabled = true
	ring_mat.emission = emit_col
	ring_mat.emission_energy_multiplier = 3.5
	ground_ring.material_override = ring_mat
	add_child(ground_ring)

func _process(delta: float) -> void:
	if visual_mesh:
		visual_mesh.rotation.y += 2.8 * delta
		visual_mesh.position.y = HOVER_HEIGHT + sin(Time.get_ticks_msec() * 0.005) * 0.12

	if ground_ring:
		var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.007) * 0.12
		ground_ring.scale = Vector3(pulse, 1.0, pulse)

func update_audio_reactivity(bass: float, drop: float, chrono: float) -> void:
	if shader_mat:
		shader_mat.set_shader_parameter("bass_energy", bass)
		shader_mat.set_shader_parameter("drop_intensity", drop)
		shader_mat.set_shader_parameter("chrono_blend", chrono)

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
		tween.set_parallel(true)
		if visual_mesh:
			tween.tween_property(visual_mesh, "scale", Vector3(1.5, 1.5, 1.5), 0.08)
			tween.tween_property(visual_mesh, "scale", Vector3.ZERO, 0.08).set_delay(0.08)
		if ground_ring:
			tween.tween_property(ground_ring, "scale", Vector3.ZERO, 0.1)
		tween.chain().tween_callback(queue_free)
