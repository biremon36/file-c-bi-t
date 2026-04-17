extends Node

const XPOrb = preload("res://xp_orb.gd")

class MockPlayer extends Node2D:
	var xp_gained = 0
	var magnet_active = false
	var magnet_pickup_range = 100.0
	var base_pickup_range = 50.0

	func _init():
		add_to_group("player")

	func gain_xp(amount):
		xp_gained += amount

var tests_passed = 0
var tests_failed = 0

func _ready():
	print("--- Running xp_orb tests ---")

	test_initial_state()
	test_setup_red()
	test_setup_purple()
	test_setup_default()
	test_on_body_entered()
	test_physics_process_movement()

	print("--- Tests finished. Passed: %d, Failed: %d ---" % [tests_passed, tests_failed])
	queue_free()

func assert_eq(actual, expected, test_name):
	if actual == expected:
		tests_passed += 1
		print("PASS: %s" % test_name)
	else:
		tests_failed += 1
		print("FAIL: %s - Expected %s but got %s" % [test_name, str(expected), str(actual)])

func assert_true(condition, test_name):
	if condition:
		tests_passed += 1
		print("PASS: %s" % test_name)
	else:
		tests_failed += 1
		print("FAIL: %s - Expected true but got false" % [test_name])

func test_initial_state():
	var orb = XPOrb.new()
	assert_eq(orb.xp_value, 10, "test_initial_state: Default xp_value should be 10")
	assert_eq(orb.target, null, "test_initial_state: Default target should be null")
	assert_eq(orb.collected, false, "test_initial_state: Default collected should be false")
	assert_eq(orb.speed, 400, "test_initial_state: Default speed should be 400")
	orb.free()

func test_setup_red():
	var orb = XPOrb.new()
	add_child(orb) # needed for create_tween
	orb.setup("red")
	assert_eq(orb.xp_value, 20, "test_setup_red: XP value should be 20")
	assert_eq(orb.modulate, Color(2.5, 0.5, 0.5), "test_setup_red: Modulate should be red HDR")
	assert_eq(orb.scale, Vector2(0.35, 0.35), "test_setup_red: Scale should be 0.35")
	orb.queue_free()

func test_setup_purple():
	var orb = XPOrb.new()
	add_child(orb)
	orb.setup("purple")
	assert_eq(orb.xp_value, 50, "test_setup_purple: XP value should be 50")
	assert_eq(orb.modulate, Color(0.7, 0.2, 1.0) * 1.5, "test_setup_purple: Modulate should be purple")
	assert_eq(orb.scale, Vector2(0.4, 0.4), "test_setup_purple: Scale should be 0.4")
	orb.queue_free()

func test_setup_default():
	var orb = XPOrb.new()
	add_child(orb)
	orb.setup("other")
	assert_eq(orb.xp_value, 10, "test_setup_default: XP value should be 10")
	assert_eq(orb.modulate, Color(0, 1, 0), "test_setup_default: Modulate should be green")
	assert_eq(orb.scale, Vector2(0.3, 0.3), "test_setup_default: Scale should be 0.3")
	orb.queue_free()

func test_on_body_entered():
	var orb = XPOrb.new()
	var player = MockPlayer.new()

	orb._on_body_entered(player)

	assert_true(orb.collected, "test_on_body_entered: Should be collected when player enters")
	assert_eq(orb.target, player, "test_on_body_entered: Target should be set to player")

	orb.free()
	player.free()

func test_physics_process_movement():
	var orb = XPOrb.new()
	var player = MockPlayer.new()

	orb.collected = true
	orb.target = player

	# Initial positions close enough to trigger collection
	orb.position = Vector2(100, 100)
	player.position = Vector2(100, 100)

	orb._physics_process(0.1)

	assert_eq(player.xp_gained, 10, "test_physics_process_movement: Player should gain XP when distance < 10")
	assert_true(orb.is_queued_for_deletion(), "test_physics_process_movement: Orb should queue free after giving XP")

	orb.free()
	player.free()
