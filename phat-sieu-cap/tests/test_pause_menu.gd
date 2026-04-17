extends SceneTree

# Standalone test script for pause_menu.gd
# Run with: godot --script tests/test_pause_menu.gd

var tests_passed = 0
var tests_failed = 0

func _init():
	print("Running tests for pause_menu.gd...")

	test_get_help_text()

	print("\n--- Test Summary ---")
	print("Passed: ", tests_passed)
	print("Failed: ", tests_failed)

	if tests_failed > 0:
		print("TESTS FAILED")
		quit(1)
	else:
		print("ALL TESTS PASSED")
		quit(0)

func assert_true(condition: bool, test_name: String):
	if condition:
		tests_passed += 1
		print("  [PASS] ", test_name)
	else:
		tests_failed += 1
		print("  [FAIL] ", test_name)

func assert_false(condition: bool, test_name: String):
	assert_true(not condition, test_name)

func assert_eq(actual, expected, test_name: String):
	if actual == expected:
		tests_passed += 1
		print("  [PASS] ", test_name)
	else:
		tests_failed += 1
		print("  [FAIL] ", test_name, " (Expected: ", expected, ", Actual: ", actual, ")")

# Tests

func test_get_help_text():
	var pause_menu = load("res://pause_menu.gd").new()
	var help_text = pause_menu.get_help_text()

	assert_true(help_text.length() > 0, "test_get_help_text_not_empty")
	assert_true(help_text.contains("CÁCH CHƠI"), "test_get_help_text_contains_gameplay_section")
	assert_true(help_text.contains("KỸ NĂNG & NÂNG CẤP"), "test_get_help_text_contains_skills_section")
	assert_true(help_text.contains("HỢP THỂ (FUSION)"), "test_get_help_text_contains_fusion_section")
	assert_true(help_text.contains("VẬT PHẨM BỊ NGUYỀN"), "test_get_help_text_contains_cursed_items_section")

	pause_menu.free()
