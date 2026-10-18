# tools/test_game.gd
extends SceneTree

func _init() -> void:
	print("=== RUNNING AUTOMATED GAME ENGINE TESTS ===")
	var passed = 0
	var failed = 0

	# 1. Test GameManager & Levels
	var gm = root.get_node_or_null("GameManager")
	var created_gm = false
	if not gm:
		var gm_script = load("res://scripts/GameManager.gd")
		gm = gm_script.new()
		gm.name = "GameManager"
		root.add_child(gm)
		gm._ready()
		created_gm = true

	print("Levels found:", gm.level_list.size())
	if gm.level_list.size() == 36:
		print("[PASS] All 36 soundtrack levels loaded successfully.")
		passed += 1
	else:
		print("[FAIL] Expected 36 levels, got:", gm.level_list.size())
		failed += 1

	# 2. Test Input Mappings for Space and F
	var has_space = false
	var has_f = false
	if InputMap.has_action("slash"):
		for ev in InputMap.action_get_events("slash"):
			if ev is InputEventKey:
				if ev.physical_keycode == KEY_SPACE:
					has_space = true
				if ev.physical_keycode == KEY_F:
					has_f = true
	if has_space and has_f:
		print("[PASS] Slash action successfully bound to both Space and F.")
		passed += 1
	else:
		print("[FAIL] Slash action missing Space or F binding (has_space=%s, has_f=%s)" % [has_space, has_f])
		failed += 1

	# 3. Test ChronoController (Shift Time Slowdown)
	var chrono = ChronoController.new()
	root.add_child(chrono)
	chrono._ready()
	chrono.charges = 2
	var activated = chrono.activate_slowdown()
	if activated and Engine.time_scale == 0.45 and chrono.charges == 1:
		print("[PASS] Chrono-Focus slowdown works: Engine.time_scale == 0.45, charges decremented.")
		passed += 1
	else:
		print("[FAIL] Chrono-Focus failed to activate properly.")
		failed += 1
	chrono.deactivate_slowdown()
	if Engine.time_scale == 1.0:
		print("[PASS] Chrono-Focus returned time scale to 1.0.")
		passed += 1
	else:
		print("[FAIL] Engine.time_scale was not restored.")
		failed += 1
	chrono.queue_free()

	# 4. Test that EVERY enemy type is killed with a Katana Slash
	var enemy_types = ["spirit", "skeleton", "witch", "samurai", "tengu", "oni", "lantern"]
	var all_enemies_killed = true
	for etype in enemy_types:
		var enemy = EnemyBase.new()
		enemy.enemy_type = etype
		root.add_child(enemy)
		enemy.on_slashed()
		if not enemy.is_dead:
			print("[FAIL] Enemy %s did not register death when slashed!" % etype)
			all_enemies_killed = false
		enemy.queue_free()

	if all_enemies_killed:
		print("[PASS] Every single Yōkai enemy type (%s) is killed with a Katana Slash!" % str(enemy_types))
		passed += 1
	else:
		failed += 1

	# 5. Test Track Generator with First Level
	var track_gen = WaveformTrackGenerator.new()
	root.add_child(track_gen)
	track_gen._ready()
	var test_level = gm.level_list[0]
	track_gen.build_track_for_level(test_level)
	if track_gen.segments.size() > 10 and track_gen.turn_zones.size() > 0:
		print("[PASS] Procedural track generated %d segments and %d turn zones." % [track_gen.segments.size(), track_gen.turn_zones.size()])
		passed += 1
	else:
		print("[FAIL] Track generator failed to produce segments/turns.")
		failed += 1
	track_gen.queue_free()

	# 7. Test QTE Turn Execution & Auto-Steering Arc
	var ninja = PlayerNinja.new()
	root.add_child(ninja)
	ninja._ready()
	var tz = TurnZone.new()
	tz.allow_left = true
	tz.allow_right = false
	ninja.enter_turn_zone(tz, true, false, Vector3(0, 0, -12), Vector3(-1, 0, 0))
	if ninja.qte_turn_active:
		ninja._execute_qte_turn(-1)
		if ninja.is_turning_corner and not ninja.qte_turn_active:
			ninja._update_movement(0.25) # advance past TURN_CORNER_DURATION (0.22s)
			if not ninja.is_turning_corner and ninja.current_direction.x < -0.9:
				print("[PASS] QTE Turn auto-steering Bezier curve successfully turned 90° onto new branch!")
				passed += 1
			else:
				print("[FAIL] QTE Turn did not complete to expected direction:", ninja.current_direction)
				failed += 1
		else:
			print("[FAIL] _execute_qte_turn failed to start turning corner.")
			failed += 1
	else:
		print("[FAIL] ninja did not enter QTE turn state.")
		failed += 1
	tz.queue_free()
	ninja.queue_free()

	if created_gm and is_instance_valid(gm):
		gm.queue_free()

	print("\n=== TEST SUMMARY: %d PASSED, %d FAILED ===" % [passed, failed])
	if failed == 0:
		print("ALL SYSTEMS OPERATIONAL!")
	quit(failed)
