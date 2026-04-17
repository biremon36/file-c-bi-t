extends SceneTree

var tests_passed = 0
var tests_failed = 0

func _init():
	print("Starting test_global.gd...")
	run_tests()
	if tests_failed > 0:
		print("TESTS FAILED")
		quit(1)
	else:
		print("ALL TESTS PASSED")
		quit(0)

func assert_eq(actual, expected, test_name):
	if typeof(actual) == typeof(expected) and actual == expected:
		print("PASS: ", test_name)
		tests_passed += 1
	elif typeof(actual) == TYPE_FLOAT and typeof(expected) == TYPE_FLOAT and abs(actual - expected) < 0.001:
		print("PASS: ", test_name)
		tests_passed += 1
	else:
		print("FAIL: ", test_name, " | Expected: ", expected, " | Actual: ", actual)
		tests_failed += 1

func assert_true(actual, test_name):
	if actual:
		print("PASS: ", test_name)
		tests_passed += 1
	else:
		print("FAIL: ", test_name, " | Expected: true | Actual: ", actual)
		tests_failed += 1

func assert_false(actual, test_name):
	if not actual:
		print("PASS: ", test_name)
		tests_passed += 1
	else:
		print("FAIL: ", test_name, " | Expected: false | Actual: ", actual)
		tests_failed += 1

func run_tests():
	# Load the global script to test
	var global_script = load("res://global.gd")
	if not global_script:
		print("FAIL: Could not load global.gd")
		tests_failed += 1
		return

	# Test 1: Initial state
	var g = global_script.new()
	g.SAVE_PATH = "user://test_savegame.save"
	assert_eq(g.coins, 0, "Initial coins should be 0")
	assert_eq(g.shop_dmg_level, 0, "Initial dmg level should be 0")
	assert_eq(g.shop_hp_level, 0, "Initial hp level should be 0")

	# Test 2: Add coins
	g.add_coins(10)
	assert_eq(g.coins, 10, "add_coins should increase coins")

	# Test 3: Upgrade damage
	# Cost for level 0 -> 1 is 1. We have 10 coins.
	var dmg_upgraded = g.upgrade_damage()
	assert_true(dmg_upgraded, "upgrade_damage should succeed if enough coins")
	assert_eq(g.shop_dmg_level, 1, "shop_dmg_level should be 1")
	assert_eq(g.coins, 9, "coins should be deducted by cost (1)")

	# Test 4: Upgrade HP
	# Cost for level 0 -> 1 is 1. We have 9 coins.
	var hp_upgraded = g.upgrade_hp()
	assert_true(hp_upgraded, "upgrade_hp should succeed if enough coins")
	assert_eq(g.shop_hp_level, 1, "shop_hp_level should be 1")
	assert_eq(g.coins, 8, "coins should be deducted by cost (1)")

	# Test 5: Upgrade fails if not enough coins
	g.coins = 0 # reset coins to test failure
	# Cost for level 1 -> 2 is 2.
	var dmg_upgrade_fail = g.upgrade_damage()
	assert_false(dmg_upgrade_fail, "upgrade_damage should fail if not enough coins")
	assert_eq(g.shop_dmg_level, 1, "shop_dmg_level should remain 1")

	# Test 6: Check new record
	g.best_time = 10.0
	var new_record1 = g.check_new_record(5.0)
	assert_false(new_record1, "check_new_record should return false for worse time")
	assert_eq(g.best_time, 10.0, "best_time should not change for worse time")

	var new_record2 = g.check_new_record(15.0)
	assert_true(new_record2, "check_new_record should return true for better time")
	assert_eq(g.best_time, 15.0, "best_time should update to better time")

	# Test 7: Reset potions
	g.active_potions["damage"] = true
	g.active_potions["xp"] = true
	g.reset_potions()
	assert_false(g.active_potions["damage"], "reset_potions should set damage to false")
	assert_false(g.active_potions["xp"], "reset_potions should set xp to false")
	assert_false(g.active_potions["speed"], "reset_potions should set speed to false")

	# Test 8: Save and Load game (Integration test)
	g.coins = 99
	g.shop_dmg_level = 5
	g.shop_hp_level = 3
	g.selected_character = "megumi"
	g.best_time = 123.45
	g.save_game()

	# Create a new instance to simulate a fresh load
	var g2 = global_script.new()
	g2.SAVE_PATH = "user://test_savegame.save"
	g2.load_game()

	assert_eq(g2.coins, 99.0, "Loaded coins should match saved coins")
	assert_eq(g2.shop_dmg_level, 5.0, "Loaded dmg level should match saved dmg level")
	assert_eq(g2.shop_hp_level, 3.0, "Loaded hp level should match saved hp level")
	assert_eq(g2.selected_character, "megumi", "Loaded selected character should match")
	assert_eq(g2.best_time, 123.45, "Loaded best time should match")

	# Cleanup test save file
	if FileAccess.file_exists(g.SAVE_PATH):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove("test_savegame.save")
