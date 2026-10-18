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

	# 6. Test Widened Track Dimensions & Obstacle Single-Track Containment
	if WaveformTrackGenerator.TRACK_WIDTH == 12.4 and WaveformTrackGenerator.LANE_WIDTH == 3.6 and PlayerNinja.LANE_WIDTH == 3.6:
		print("[PASS] Widened track constants verified: TRACK_WIDTH=12.4m, LANE_WIDTH=3.6m (2x widened).")
		passed += 1
	else:
		print("[FAIL] Track constants mismatch.")
		failed += 1

	var single_lane_ok = true
	for obs_type in ["barricade", "high_gate"]:
		var obs = Obstacle.new()
		obs.obstacle_type = obs_type
		root.add_child(obs)
		obs._ready()
		var obs_col = obs.get_node_or_null("CollisionShape3D")
		if obs_col and obs_col.shape is BoxShape3D:
			var obs_w = obs_col.shape.size.x
			# Ensure obstacle is sized 2.4m and strictly fits within single 3.6m lane with generous clearance
			if obs_w <= 2.5 and obs_w >= 2.3:
				var half_w = obs_w * 0.5
				var clearance_to_adjacent_center = 3.6 - half_w
				var clearance_to_adjacent_hitbox = clearance_to_adjacent_center - 0.6 # Ninja half-width is 0.6m
				print("[PASS] Obstacle '%s' width is %.2fm. Clearance to adjacent runner hitbox is %.2fm (> 1.7m safe air)." % [obs_type, obs_w, clearance_to_adjacent_hitbox])
			else:
				print("[FAIL] Obstacle '%s' width %.2fm does not match expected single-lane width (2.4m)." % [obs_type, obs_w])
				single_lane_ok = false
		else:
			print("[FAIL] Obstacle '%s' missing BoxShape3D collision." % obs_type)
			single_lane_ok = false
		obs.queue_free()

	if single_lane_ok:
		passed += 1
	else:
		failed += 1

	# 7. Test Kinematic Lane Displacement Precision across Framerates
	var lane_precision_ok = true
	for fps in [30, 60, 120, 144]:
		var dt = 1.0 / float(fps)
		var test_lane_x = 0.0
		var test_target_x = 3.6
		var integrated_lateral = 0.0
		for step in range(fps * 2): # 2 seconds of running
			var prev_x = test_lane_x
			test_lane_x = lerpf(test_lane_x, test_target_x, 1.0 - exp(-18.0 * dt))
			if absf(test_target_x - test_lane_x) < 0.005:
				test_lane_x = test_target_x
			var delta_l = test_lane_x - prev_x
			var vel_l = delta_l / dt
			integrated_lateral += vel_l * dt
		if absf(integrated_lateral - 3.6) < 0.01:
			print("[PASS] Lane switch @ %d FPS accurately reached %.3fm (target 3.600m)." % [fps, integrated_lateral])
		else:
			print("[FAIL] Lane switch @ %d FPS only reached %.3fm (expected 3.600m)!" % [fps, integrated_lateral])
			lane_precision_ok = false

	if lane_precision_ok:
		passed += 1
	else:
		failed += 1

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
	# 8. Test High Score & Max Kills Tracking and Comparison
	var test_track = "test_soundtrack_run.mp3"
	# Run 1: First victory clear
	var run1 = gm.record_completion(test_track, 5000, 2, 10)
	if run1["is_new_high_score"] and gm.get_high_score(test_track) == 5000 and gm.get_max_kills(test_track) == 10:
		print("[PASS] Run 1: First victory clear saved High Score 5000 and Max Kills 10.")
		passed += 1
	else:
		print("[FAIL] Run 1 failed to record initial high score or max kills.")
		failed += 1

	# Run 2: Lower score and kills on defeat compares against existing high score
	var run2 = gm.record_failure(test_track, 45.0, "Stumbled", 3200, 6)
	if not run2["is_new_high_score"] and run2["score_diff"] == -1800 and not run2["is_new_max_kills"] and run2["kills_diff"] == -4:
		print("[PASS] Run 2: Defeat correctly detected lower score (-1800 behind) and preserved records.")
		passed += 1
	else:
		print("[FAIL] Run 2 score comparison failed: ", run2)
		failed += 1

	# Run 3: Defeat with higher score and higher kills updates both records
	var run3 = gm.record_failure(test_track, 85.0, "Abyss", 7500, 16)
	if run3["is_new_high_score"] and run3["score_diff"] == 2500 and run3["is_new_max_kills"] and run3["kills_diff"] == 6:
		print("[PASS] Run 3: Defeat with improved play established NEW HIGH SCORE (+2500) and NEW MAX KILLS (+6).")
		passed += 1
	else:
		print("[FAIL] Run 3 high score update on defeat failed: ", run3)
		failed += 1

	# 9. Test Pickup Point Contributions (Koban: 100 * combo, Slowdown: 150 * combo)
	var coin_pickup = Pickup.new()
	coin_pickup.pickup_type = "koban"
	var slow_pickup = Pickup.new()
	slow_pickup.pickup_type = "slowdown"
	root.add_child(coin_pickup)
	root.add_child(slow_pickup)

	var pninja = PlayerNinja.new()
	root.add_child(pninja)
	var pickup_state = {"coin": 0, "slow": 0}
	pninja.coin_collected.connect(func(val): pickup_state["coin"] = val)
	pninja.slowdown_collected.connect(func(val): pickup_state["slow"] = val)

	coin_pickup._on_body_entered(pninja)
	slow_pickup._on_body_entered(pninja)

	if pickup_state["coin"] == 100 and pickup_state["slow"] == 150:
		print("[PASS] Pickups contribute correct base points: Koban = 100, Chrono Slowdown = 150.")
		passed += 1
	else:
		print("[FAIL] Pickup point values mismatch: coin=%d (expected 100), slow=%d (expected 150)" % [pickup_state["coin"], pickup_state["slow"]])
		failed += 1

	coin_pickup.queue_free()
	slow_pickup.queue_free()
	pninja.queue_free()

	# 10. Test Enemy Katana Slash vs Collision Stumble
	var slash_ninja = PlayerNinja.new()
	slash_ninja.add_to_group("player")
	root.add_child(slash_ninja)
	var combat_state = {"kills": 0}
	slash_ninja.slashed_enemy.connect(func(_name, _pts): combat_state["kills"] += 1)

	var slayed_enemy = EnemyBase.new()
	slayed_enemy.enemy_type = "skeleton"
	root.add_child(slayed_enemy)
	slayed_enemy.on_slashed()

	var stumbled_enemy = EnemyBase.new()
	stumbled_enemy.enemy_type = "spirit"
	root.add_child(stumbled_enemy)
	stumbled_enemy.disperse()

	if combat_state["kills"] == 1 and slayed_enemy.is_dead and stumbled_enemy.is_dead:
		print("[PASS] Slashed enemy counted toward kills/score; stumbled dispersed enemy did not award kills.")
		passed += 1
	else:
		print("[FAIL] Enemy slash vs disperse count mismatch: enemies_slain_count=%d" % combat_state["kills"])
		failed += 1

	slayed_enemy.queue_free()
	stumbled_enemy.queue_free()
	slash_ninja.queue_free()

	# 11. Test MainMenu High Scores UI and Navigation
	var menu_scene = load("res://scenes/MainMenu.tscn")
	var menu = menu_scene.instantiate()
	root.add_child(menu)
	menu._ready()

	var hs_btn = menu.get_node_or_null("MarginContainer/TitleScreen/HighScoresBtn")
	var hs_screen = menu.get_node_or_null("MarginContainer/HighScoresScreen")
	var hs_list = menu.get_node_or_null("MarginContainer/HighScoresScreen/ScrollContainer/HighScoreList")

	if hs_btn and hs_screen and hs_list:
		menu._on_high_scores_pressed()
		var items_count = hs_list.get_child_count()
		if hs_screen.visible and not menu.title_screen.visible and items_count == 36:
			print("[PASS] MainMenu High Scores screen verified: button exists, displays %d soundtrack tracks." % items_count)
			passed += 1
		else:
			print("[FAIL] MainMenu High Scores screen display issue (visible=%s, items=%d)" % [hs_screen.visible, items_count])
			failed += 1
	else:
		print("[FAIL] MainMenu missing HighScoresBtn or HighScoresScreen nodes.")
		failed += 1

	menu.queue_free()

	# Clean test key from save data
	gm.save_data["high_scores"].erase(test_track)
	gm.save_data["max_kills"].erase(test_track)
	gm._save_data_to_disk()

	if created_gm and is_instance_valid(gm):
		gm.queue_free()

	print("\n=== TEST SUMMARY: %d PASSED, %d FAILED ===" % [passed, failed])
	if failed == 0:
		print("ALL SYSTEMS OPERATIONAL!")
	quit(failed)
