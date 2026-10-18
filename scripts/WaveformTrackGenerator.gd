# scripts/WaveformTrackGenerator.gd
class_name WaveformTrackGenerator
extends Node3D

signal track_built(total_distance: float, segment_count: int)
signal goal_reached()

const SEGMENT_LENGTH: float = 24.0
const LANE_WIDTH: float = 3.6
const TRACK_WIDTH: float = 12.4
const CURB_WIDTH: float = 0.5
const CURB_HEIGHT: float = 0.4
const BASE_SPEED: float = 18.0

var track_data: Dictionary = {}
var segments: Array[Node3D] = []
var turn_zones: Array[TurnZone] = []
var active_turn_indices: Array[int] = []

# Materials for procedural walkway
var mat_wood: StandardMaterial3D
var mat_stone: StandardMaterial3D
var mat_lantern_glow: StandardMaterial3D
var base_curb_emission: Color = Color(0.0, 0.9, 1.0)

func _ready() -> void:
	_init_materials()

func _init_materials() -> void:
	mat_wood = StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.20, 0.14, 0.12)
	mat_wood.roughness = 0.62
	mat_wood.metallic = 0.12

	mat_stone = StandardMaterial3D.new()
	mat_stone.albedo_color = Color(0.32, 0.34, 0.40)
	mat_stone.roughness = 0.55
	mat_stone.metallic = 0.25
	mat_stone.emission_enabled = true
	mat_stone.emission = base_curb_emission
	mat_stone.emission_energy_multiplier = 0.45

	mat_lantern_glow = StandardMaterial3D.new()
	mat_lantern_glow.albedo_color = Color(1.0, 0.7, 0.2)
	mat_lantern_glow.emission_enabled = true
	mat_lantern_glow.emission = Color(1.0, 0.6, 0.1)
	mat_lantern_glow.emission_energy_multiplier = 3.0

func apply_track_palette(palette: Dictionary) -> void:
	if not mat_wood or not mat_stone or not mat_lantern_glow:
		_init_materials()

	var curb_col: Color = palette.get("curb_accent_color", Color(0.0, 0.9, 1.0))
	var sky_hor: Color = palette.get("sky_horizon_color", Color(0.25, 0.08, 0.3))
	var sun_top: Color = palette.get("sun_top_color", Color(1.0, 0.85, 0.2))

	base_curb_emission = curb_col
	mat_stone.albedo_color = Color(0.22, 0.22, 0.28).lerp(curb_col, 0.25)
	mat_stone.emission = base_curb_emission
	mat_stone.emission_energy_multiplier = 0.55

	mat_wood.albedo_color = Color(0.18, 0.12, 0.10).lerp(sky_hor, 0.22)

	mat_lantern_glow.albedo_color = sun_top
	mat_lantern_glow.emission = sun_top

func update_audio_reactivity(bass: float, drop: float, chrono: float) -> void:
	if not mat_stone:
		return
	var chrono_col = Color(0.35, 0.95, 1.0)
	mat_stone.emission = base_curb_emission.lerp(chrono_col, chrono * 0.85)
	mat_stone.emission_energy_multiplier = 0.35 + bass * 0.85 + drop * 0.65 + chrono * 0.4

func build_track_for_level(level_dict: Dictionary) -> void:
	_clear_track()
	track_data = level_dict.get("waveform", {})
	var duration = level_dict.get("duration", 180.0)
	if duration <= 0.0:
		duration = 180.0

	var total_distance = duration * BASE_SPEED
	var segment_count = int(ceil(total_distance / SEGMENT_LENGTH))
	var seed_val = track_data.get("seed", 12345)
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val

	var rms_list: Array = track_data.get("rms", [])
	var low_list: Array = track_data.get("low", [])
	var beats: Array = track_data.get("beats", [])

	var current_pos = Vector3.ZERO
	var current_dir = Vector3(0, 0, -1) # Facing -Z (Godot forward)
	var last_turn_segment = -10
	var turn_dir_alternator = 1
	var prev_was_turn = false

	for seg_idx in range(segment_count):
		var time_sec = seg_idx * (SEGMENT_LENGTH / BASE_SPEED)
		var bucket_idx = int(time_sec * 10.0)

		var rms = 0.3
		var low = 0.3
		if bucket_idx < rms_list.size():
			rms = float(rms_list[bucket_idx])
		if bucket_idx < low_list.size():
			low = float(low_list[bucket_idx])

		# Check if this segment should be a 90-degree corner or T-junction
		var is_turn = false
		var is_t_junction = false
		var turn_left = false
		var turn_right = false

		var can_turn = (seg_idx - last_turn_segment >= 8) and (seg_idx > 3) and (seg_idx < segment_count - 5)
		if can_turn:
			# Check beat timestamps
			for b in beats:
				if abs(float(b) - time_sec) < 0.4:
					is_turn = true
					break

			if not is_turn and low > 0.6:
				is_turn = true

		if is_turn:
			last_turn_segment = seg_idx
			if rms > 0.7 and rng.randf() < 0.5:
				# T-junction!
				is_t_junction = true
				turn_left = true
				turn_right = true
			else:
				# 90 degree corner turn
				turn_dir_alternator *= -1
				if turn_dir_alternator > 0:
					turn_right = true
				else:
					turn_left = true

		# Create Segment Node
		var seg_node = Node3D.new()
		seg_node.name = "Segment_%d" % seg_idx
		seg_node.position = current_pos
		add_child(seg_node)
		segments.append(seg_node)

		# Align segment to forward direction
		var angle = atan2(-current_dir.x, -current_dir.z)
		seg_node.rotation.y = angle

		# Build visual roadway mesh & collisions
		_build_segment_mesh(seg_node, is_turn, is_t_junction, turn_left, turn_right, prev_was_turn)

		var junction_pos = current_pos + current_dir * SEGMENT_LENGTH

		# Add TurnZone if turn segment
		if is_turn:
			var tz = TurnZone.new()
			seg_node.add_child(tz)
			tz.position = Vector3(0, 0, -SEGMENT_LENGTH)
			tz.setup_zone(current_dir, junction_pos, turn_left, turn_right)
			turn_zones.append(tz)

		# Populate obstacles, pickups, and folklore Yokai
		if not is_turn and seg_idx > 1 and seg_idx < segment_count - 1:
			_populate_segment_contents(seg_node, rms, low, rng)

		# If last segment, place Grand Goal Torii Gate
		if seg_idx == segment_count - 1:
			_place_goal_shrine(seg_node)

		# Advance current position and direction for next segment
		if is_turn:
			var rot_y = -PI * 0.5 if turn_right else PI * 0.5
			current_pos = junction_pos
			current_dir = current_dir.rotated(Vector3.UP, rot_y).normalized()
			prev_was_turn = true
		else:
			current_pos = junction_pos
			prev_was_turn = false

	emit_signal("track_built", total_distance, segment_count)

func _add_curb(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var curb = MeshInstance3D.new()
	var c_mesh = BoxMesh.new()
	c_mesh.size = size
	c_mesh.material = mat_stone
	curb.mesh = c_mesh
	curb.position = pos
	parent.add_child(curb)

func _build_segment_mesh(parent: Node3D, is_turn: bool, is_t_junction: bool, left: bool, right: bool, prev_was_turn: bool = false) -> void:
	# Main roadway box (StaticBody3D + CollisionShape3D + MeshInstance3D)
	var body = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	parent.add_child(body)

	var half_width = TRACK_WIDTH * 0.5
	var curb_offset = half_width - CURB_WIDTH * 0.5
	var curb_y = CURB_HEIGHT * 0.5
	var j_z = -SEGMENT_LENGTH

	# Straight section boundaries
	var straight_start_z = -half_width if prev_was_turn else 0.0
	var straight_end_z = (j_z + half_width) if is_turn else -SEGMENT_LENGTH
	var straight_len = straight_start_z - straight_end_z
	var straight_center_z = (straight_start_z + straight_end_z) * 0.5

	# Main straight slab
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(TRACK_WIDTH, 1.0, straight_len)
	col.shape = box
	col.position = Vector3(0, -0.5, straight_center_z)
	body.add_child(col)

	var mesh_inst = MeshInstance3D.new()
	var b_mesh = BoxMesh.new()
	b_mesh.size = box.size
	b_mesh.material = mat_wood
	mesh_inst.mesh = b_mesh
	mesh_inst.position = col.position
	body.add_child(mesh_inst)

	# Side stone curbstones along straight section
	for side in [-1, 1]:
		_add_curb(body, Vector3(side * curb_offset, curb_y, straight_center_z), Vector3(CURB_WIDTH, CURB_HEIGHT, straight_len))

	# If corner or T-junction, add solid square intersection platform and seamless junction curbstones
	if is_turn:
		# Center intersection square at end of segment
		var j_col = CollisionShape3D.new()
		var j_box = BoxShape3D.new()
		j_box.size = Vector3(TRACK_WIDTH, 1.0, TRACK_WIDTH)
		j_col.shape = j_box
		j_col.position = Vector3(0, -0.5, j_z)
		body.add_child(j_col)

		var j_mesh = MeshInstance3D.new()
		var j_bmesh = BoxMesh.new()
		j_bmesh.size = j_box.size
		j_bmesh.material = mat_wood
		j_mesh.mesh = j_bmesh
		j_mesh.position = j_col.position
		body.add_child(j_mesh)

		# 1. Back wall curb: closes off the forward path (dead end) facing the incoming runner
		_add_curb(body, Vector3(0.0, curb_y, j_z - curb_offset), Vector3(TRACK_WIDTH, CURB_HEIGHT, CURB_WIDTH))

		# 2. Side walls & Inner corners:
		if left and not right:
			# Single LEFT turn:
			# Left side is inner corner: square flush corner block connecting to outgoing inner curb
			_add_curb(body, Vector3(-curb_offset, curb_y, j_z + curb_offset), Vector3(CURB_WIDTH, CURB_HEIGHT, CURB_WIDTH))
			# Right side is outer wall: continuous wall enclosing the outer perimeter
			_add_curb(body, Vector3(curb_offset, curb_y, j_z), Vector3(CURB_WIDTH, CURB_HEIGHT, TRACK_WIDTH))

		elif right and not left:
			# Single RIGHT turn:
			# Right side is inner corner: square flush corner block connecting to outgoing inner curb
			_add_curb(body, Vector3(curb_offset, curb_y, j_z + curb_offset), Vector3(CURB_WIDTH, CURB_HEIGHT, CURB_WIDTH))
			# Left side is outer wall: continuous wall enclosing the outer perimeter
			_add_curb(body, Vector3(-curb_offset, curb_y, j_z), Vector3(CURB_WIDTH, CURB_HEIGHT, TRACK_WIDTH))

		else:
			# T-Junction: both left and right are open branches
			_add_curb(body, Vector3(-curb_offset, curb_y, j_z + curb_offset), Vector3(CURB_WIDTH, CURB_HEIGHT, CURB_WIDTH))
			_add_curb(body, Vector3(curb_offset, curb_y, j_z + curb_offset), Vector3(CURB_WIDTH, CURB_HEIGHT, CURB_WIDTH))
			_add_turn_arm(body, -1)
			_add_turn_arm(body, 1)

	# Prop: Torii Arch on straight paths periodically
	if not is_turn and not prev_was_turn and (parent.name.ends_with("4") or parent.name.ends_with("8")):
		var arch_scene = load("res://assets/models/env_shrine_arch.glb")
		if arch_scene:
			var arch = arch_scene.instantiate()
			arch.position = Vector3(0, 0, -SEGMENT_LENGTH * 0.5)
			parent.add_child(arch)

func _add_turn_arm(body: StaticBody3D, side_dir: int) -> void:
	# Branch slab connecting at junction end z = -SEGMENT_LENGTH
	var arm_col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(TRACK_WIDTH * 1.5, 1.0, TRACK_WIDTH)
	arm_col.shape = box
	arm_col.position = Vector3(side_dir * (TRACK_WIDTH * 0.75), -0.5, -SEGMENT_LENGTH)
	body.add_child(arm_col)

	var arm_mesh = MeshInstance3D.new()
	var b_mesh = BoxMesh.new()
	b_mesh.size = box.size
	b_mesh.material = mat_wood
	arm_mesh.mesh = b_mesh
	arm_mesh.position = arm_col.position
	body.add_child(arm_mesh)

func _populate_segment_contents(parent: Node3D, rms: float, low: float, rng: RandomNumberGenerator) -> void:
	var lanes = [-LANE_WIDTH, 0.0, LANE_WIDTH]
	var occupied_lanes = []

	# Low RMS quiet sections: spawn Slowdown (Toki-no-Tama) powerup and Koban gold coins
	if rms < 0.35 and rng.randf() < 0.4:
		var lane = lanes[rng.randi() % 3]
		occupied_lanes.append(lane)
		var pickup = Pickup.new()
		pickup.pickup_type = "slowdown"
		pickup.position = Vector3(lane, 0.0, -SEGMENT_LENGTH * 0.5)
		parent.add_child(pickup)

	# Koban coins along lanes
	if rng.randf() < 0.6:
		var coin_lane = lanes[rng.randi() % 3]
		if not occupied_lanes.has(coin_lane):
			for z_off in [-5.0, 0.0, 5.0]:
				var coin = Pickup.new()
				coin.pickup_type = "koban"
				coin.position = Vector3(coin_lane, 0.0, -SEGMENT_LENGTH * 0.5 + z_off)
				parent.add_child(coin)

	# High energy: spawn Japanese folklore Yokai enemies
	if rms > 0.45 or low > 0.55:
		var enemy_lane = lanes[rng.randi() % 3]
		var enemy = EnemyBase.new()

		# Determine enemy type based on audio intensity
		if low > 0.7:
			enemy.enemy_type = "oni" # Heavy horned brute on massive bass
		elif rms > 0.75:
			enemy.enemy_type = "samurai" # Undead samurai on peak energy
		elif rms > 0.6:
			var pool = ["witch", "tengu"]
			enemy.enemy_type = pool[rng.randi() % pool.size()]
		else:
			var pool = ["spirit", "skeleton", "lantern"]
			enemy.enemy_type = pool[rng.randi() % pool.size()]

		enemy.position = Vector3(enemy_lane, 0.0, -SEGMENT_LENGTH * 0.5)
		parent.add_child(enemy)
		occupied_lanes.append(enemy_lane)

	# Environmental barricade or high gate obstacle
	elif rng.randf() < 0.45:
		var obs_lane = lanes[rng.randi() % 3]
		var obs = Obstacle.new()
		obs.obstacle_type = "barricade" if rng.randf() < 0.5 else "high_gate"
		obs.position = Vector3(obs_lane, 0.0, -SEGMENT_LENGTH * 0.5)
		parent.add_child(obs)

func _place_goal_shrine(parent: Node3D) -> void:
	var goal_scene = load("res://assets/models/env_goal_shrine.glb")
	if goal_scene:
		var goal = goal_scene.instantiate()
		goal.position = Vector3(0, 0, -SEGMENT_LENGTH * 0.8)
		parent.add_child(goal)

	# Goal trigger area
	var goal_area = Area3D.new()
	goal_area.collision_layer = 16
	goal_area.collision_mask = 1
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(TRACK_WIDTH, 4.0, 2.0)
	col.shape = box
	col.position = Vector3(0, 2.0, -SEGMENT_LENGTH * 0.8)
	goal_area.add_child(col)
	goal_area.body_entered.connect(func(body):
		if body is PlayerNinja:
			emit_signal("goal_reached")
	)
	parent.add_child(goal_area)

func _clear_track() -> void:
	for seg in segments:
		if is_instance_valid(seg):
			seg.queue_free()
	segments.clear()
	turn_zones.clear()
