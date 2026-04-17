extends SceneTree

var gacha_script = preload("res://gacha_system.gd")

var tests_passed = 0
var tests_failed = 0

func _init():
    print("Running Gacha System Tests...")
    test_initialization()
    test_spin()
    test_stop_spin()
    test_close_signal()

    print("Test Summary: %d passed, %d failed" % [tests_passed, tests_failed])
    quit(1 if tests_failed > 0 else 0)

func assert_true(condition: bool, test_name: String):
    if condition:
        tests_passed += 1
        print("  [PASS] " + test_name)
    else:
        tests_failed += 1
        print("  [FAIL] " + test_name)

func assert_false(condition: bool, test_name: String):
    assert_true(not condition, test_name)

func assert_equal(actual, expected, test_name: String):
    if actual == expected:
        tests_passed += 1
        print("  [PASS] " + test_name)
    else:
        tests_failed += 1
        print("  [FAIL] " + test_name + " (Expected: %s, Actual: %s)" % [str(expected), str(actual)])

func test_initialization():
    var gacha = gacha_script.new()
    assert_true(gacha.panel != null, "Panel should be initialized")
    assert_true(gacha.wheel_container != null, "Wheel container should be initialized")
    assert_true(gacha.wheel_rotation_node != null, "Wheel rotation node should be initialized")
    assert_true(gacha.arrow != null, "Arrow should be initialized")
    assert_false(gacha.is_spinning, "Should not be spinning initially")
    gacha.free()

func test_spin():
    var gacha = gacha_script.new()
    assert_true(gacha.spin(), "Spin should return true when starting")
    assert_true(gacha.is_spinning, "is_spinning should be true after spin()")
    assert_false(gacha.spin(), "Spin should return false if already spinning")
    gacha.free()

func test_stop_spin():
    var gacha = gacha_script.new()

    # Try stopping when not spinning
    assert_false(gacha.stop_spin(1.0), "stop_spin should return false if not spinning")

    gacha.spin()

    # Track signal emission
    var reward_emitted = false
    var emitted_reward = ""

    # In Godot 4, we use Callables for signals
    # Since we can't easily mock signal connections in a simple test script without a class,
    # we'll just test the return value and state changes, but we'll try to connect if possible
    # We can connect to an anonymous function or a method in a temporary object

    # Use a simple class to catch the signal
    var signal_catcher = CatchSignal.new()
    gacha.connect("reward_granted", Callable(signal_catcher, "_on_reward"))

    assert_true(gacha.stop_spin(PI / 4.0), "stop_spin should return true when spinning")
    assert_false(gacha.is_spinning, "is_spinning should be false after stop_spin()")
    assert_equal(gacha.current_rotation, PI / 4.0, "current_rotation should be updated")
    assert_equal(gacha.wheel_rotation_node.rotation, PI / 4.0, "wheel_rotation_node.rotation should be updated")

    # Check signal
    assert_true(signal_catcher.was_called, "reward_granted signal should be emitted")
    assert_equal(signal_catcher.reward, "Gojo Figure", "Should give Gojo Figure for rotation < PI/2")

    gacha.free()
    signal_catcher.free()

func test_close_signal():
    var gacha = gacha_script.new()
    var signal_catcher = CatchSignal.new()
    gacha.connect("gacha_closed", Callable(signal_catcher, "_on_closed"))

    gacha.close()

    assert_true(signal_catcher.closed_called, "gacha_closed signal should be emitted")

    gacha.free()
    signal_catcher.free()

# Helper class to catch signals
class CatchSignal extends Object:
    var was_called = false
    var reward = ""
    var closed_called = false

    func _on_reward(r: String):
        was_called = true
        reward = r

    func _on_closed():
        closed_called = true
