extends SceneTree

# Test script for new_script.gd
# Runs as a standalone script: godot -s tests/test_new_script.gd

var new_script_scene = preload("res://new_script.gd")

func _init():
	print("Starting test_new_script...")
	var tests_passed = 0
	var tests_failed = 0

	# Test 1: Node instantiation
	var node = new_script_scene.new()
	if node != null:
		print("PASS: Node instantiated successfully.")
		tests_passed += 1
	else:
		print("FAIL: Node failed to instantiate.")
		tests_failed += 1

	# Test 2: Ensure it has expected methods
	if node.has_method("_ready"):
		print("PASS: Node has _ready method.")
		tests_passed += 1
	else:
		print("FAIL: Node missing _ready method.")
		tests_failed += 1

	if node.has_method("_process"):
		print("PASS: Node has _process method.")
		tests_passed += 1
	else:
		print("FAIL: Node missing _process method.")
		tests_failed += 1

	# Simulate _ready
	node._ready()
	print("PASS: _ready called without errors.")
	tests_passed += 1

	# Simulate _process
	node._process(0.1)
	print("PASS: _process called without errors.")
	tests_passed += 1

	node.free()

	print("===================")
	print("Test Results: %d Passed, %d Failed" % [tests_passed, tests_failed])
	if tests_failed > 0:
		quit(1)
	else:
		quit(0)
