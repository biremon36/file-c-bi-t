extends SceneTree

const Bullet = preload("res://bullet.gd")

var tests_passed = 0
var tests_failed = 0

func _init():
	print("Starting tests for bullet.gd...")

	test_initialization()
	test_physics_process()
	test_on_body_entered_enemy_with_take_damage()
	test_on_body_entered_enemy_without_take_damage()
	test_on_body_entered_non_enemy()

	print("\nTest summary: %d passed, %d failed" % [tests_passed, tests_failed])

	if tests_failed > 0:
		quit(1)
	else:
		quit(0)

func assert_true(condition: bool, test_name: String):
	if condition:
		print("[PASS] " + test_name)
		tests_passed += 1
	else:
		print("[FAIL] " + test_name)
		tests_failed += 1

func assert_equal(actual, expected, test_name: String):
	if actual == expected:
		print("[PASS] " + test_name)
		tests_passed += 1
	else:
		print("[FAIL] " + test_name + " - Expected: " + str(expected) + ", but got: " + str(actual))
		tests_failed += 1

func test_initialization():
	var bullet = Bullet.new()
	assert_equal(bullet.speed, 450, "test_initialization: Default speed is 450")
	assert_equal(bullet.damage, 10, "test_initialization: Default damage is 10")
	assert_equal(bullet.direction, Vector2.RIGHT, "test_initialization: Default direction is RIGHT")
	assert_equal(bullet.is_critical, false, "test_initialization: Default is_critical is false")
	bullet.free()

func test_physics_process():
	var bullet = Bullet.new()
	var root = get_root()
	root.add_child(bullet)

	bullet.position = Vector2(0, 0)
	bullet.direction = Vector2(1, 0) # RIGHT
	bullet.speed = 100

	bullet._physics_process(0.5) # delta = 0.5

	var expected_pos = Vector2(50, 0)
	assert_equal(bullet.position, expected_pos, "test_physics_process: Bullet moves correctly based on speed and delta")

	bullet.queue_free()

class MockEnemy extends Node2D:
	var damage_taken = 0
	var was_critical = false
	func take_damage(amount, critical):
		damage_taken = amount
		was_critical = critical

class MockEnemyNoDamage extends Node2D:
	pass

class MockNonEnemy extends Node2D:
	pass

func test_on_body_entered_enemy_with_take_damage():
	var bullet = Bullet.new()
	var root = get_root()
	root.add_child(bullet)
	bullet.damage = 15
	bullet.is_critical = true

	var mock_enemy = MockEnemy.new()
	root.add_child(mock_enemy)
	mock_enemy.add_to_group("enemies")

	bullet._on_body_entered(mock_enemy)

	assert_equal(mock_enemy.damage_taken, 15, "test_on_body_entered_enemy_with_take_damage: Correct damage dealt")
	assert_equal(mock_enemy.was_critical, true, "test_on_body_entered_enemy_with_take_damage: Correct critical flag passed")
	assert_true(bullet.is_queued_for_deletion(), "test_on_body_entered_enemy_with_take_damage: Bullet is queued for deletion")

	mock_enemy.queue_free()
	bullet.queue_free()

func test_on_body_entered_enemy_without_take_damage():
	var bullet = Bullet.new()
	var root = get_root()
	root.add_child(bullet)

	var mock_enemy = MockEnemyNoDamage.new()
	root.add_child(mock_enemy)
	mock_enemy.add_to_group("enemies")

	bullet._on_body_entered(mock_enemy)

	assert_true(bullet.is_queued_for_deletion(), "test_on_body_entered_enemy_without_take_damage: Bullet is queued for deletion even if no take_damage method")

	mock_enemy.queue_free()
	bullet.queue_free()

func test_on_body_entered_non_enemy():
	var bullet = Bullet.new()
	var root = get_root()
	root.add_child(bullet)

	var mock_non_enemy = MockNonEnemy.new()
	root.add_child(mock_non_enemy)

	bullet._on_body_entered(mock_non_enemy)

	assert_equal(bullet.is_queued_for_deletion(), false, "test_on_body_entered_non_enemy: Bullet is NOT queued for deletion when hitting non-enemy")

	mock_non_enemy.queue_free()
	bullet.queue_free()
