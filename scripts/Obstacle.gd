# scripts/Obstacle.gd
class_name Obstacle
extends Area3D

@export var obstacle_type: String = "barricade" # barricade (jump over), high_gate (slide under)
var visual_mesh: Node3D
var ground_marker: MeshInstance3D
var shader_mat: ShaderMaterial

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_setup()
	_setup_psychedelic_shader()
	_setup_ground_marker()

func _setup() -> void:
	var path = "res://assets/models/obstacle_" + obstacle_type + ".glb"
	if ResourceLoader.exists(path):
		var scene = load(path)
		if scene:
			visual_mesh = scene.instantiate()
			add_child(visual_mesh)

	var col = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var box = BoxShape3D.new()
	if obstacle_type == "barricade":
		box.size = Vector3(2.4, 0.7, 0.8) # Low barricade spanning single lane (2.4m)
		col.position = Vector3(0, 0.35, 0)
	else:
		box.size = Vector3(2.4, 0.9, 0.8) # High beam / gate spanning single lane (2.4m)
		col.position = Vector3(0, 1.45, 0)
	col.shape = box
	add_child(col)

func _setup_psychedelic_shader() -> void:
	var shader = load("res://shaders/psychedelic_entity.gdshader")
	if not shader:
		return

	shader_mat = ShaderMaterial.new()
	shader_mat.shader = shader
	shader_mat.set_shader_parameter("pattern_mode", 2) # Neon Hazard Chevrons
	shader_mat.set_shader_parameter("pattern_speed", 2.5)
	shader_mat.set_shader_parameter("pattern_scale", 4.0)
	shader_mat.set_shader_parameter("rim_power", 2.0)
	shader_mat.set_shader_parameter("rim_boost", 2.4)

	if obstacle_type == "barricade":
		# Jump hurdle: Electric Amber & Acid Lime Chevrons
		shader_mat.set_shader_parameter("albedo_color", Color(0.08, 0.05, 0.02))
		shader_mat.set_shader_parameter("emission_color", Color(1.0, 0.8, 0.1))
		shader_mat.set_shader_parameter("secondary_color", Color(0.4, 1.0, 0.2))
		shader_mat.set_shader_parameter("emission_energy", 4.8)
	else:
		# Slide gate: Laser Magenta & Electric Cyan Runes
		shader_mat.set_shader_parameter("albedo_color", Color(0.05, 0.02, 0.08))
		shader_mat.set_shader_parameter("emission_color", Color(1.0, 0.12, 0.65))
		shader_mat.set_shader_parameter("secondary_color", Color(0.15, 0.9, 1.0))
		shader_mat.set_shader_parameter("emission_energy", 5.0)

	if visual_mesh:
		_apply_material_recursive(visual_mesh, shader_mat)

func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)

func _setup_ground_marker() -> void:
	ground_marker = MeshInstance3D.new()
	var b_mesh = BoxMesh.new()
	b_mesh.size = Vector3(2.4, 0.02, 0.4)
	ground_marker.mesh = b_mesh
	ground_marker.position = Vector3(0, 0.03, 0) # On the track floor

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var col = Color(1.0, 0.8, 0.1) if obstacle_type == "barricade" else Color(1.0, 0.15, 0.65)
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 3.0
	ground_marker.material_override = mat
	add_child(ground_marker)

func update_audio_reactivity(bass: float, drop: float, chrono: float) -> void:
	if shader_mat:
		shader_mat.set_shader_parameter("bass_energy", bass)
		shader_mat.set_shader_parameter("drop_intensity", drop)
		shader_mat.set_shader_parameter("chrono_blend", chrono)

func _process(_delta: float) -> void:
	if ground_marker:
		var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.08
		ground_marker.scale = Vector3(pulse, 1.0, pulse)

func on_slashed() -> void:
	SoundEffects.play_sound(get_tree(), "slash")
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		if player.has_method("record_slashed_enemy"):
			player.record_slashed_enemy("barricade", 100)
		else:
			player.slashed_enemy.emit("barricade", 100)
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
