# Test for menu.gd
# Using a standalone script approach suitable for the project structure

extends SceneTree

var passed = 0
var failed = 0

func _init():
	print("Running test_menu.gd")
	test_script_loads()
	test_menu_instantiation()
	print_summary()
	if failed > 0:
		quit(1)
	else:
		quit(0)

func assert_true(condition: bool, message: String):
	if condition:
		passed += 1
		print("PASS: " + message)
	else:
		failed += 1
		printerr("FAIL: " + message)

func test_script_loads():
	var script = load("res://menu.gd")
	assert_true(script != null, "menu.gd script loads successfully")

func test_menu_instantiation():
	var script = load("res://menu.gd")
	if script:
		var instance = script.new()
		assert_true(instance != null, "menu.gd can be instantiated")
		if instance is Node:
			instance.free()

func print_summary():
	print("Tests passed: " + str(passed))
	print("Tests failed: " + str(failed))
