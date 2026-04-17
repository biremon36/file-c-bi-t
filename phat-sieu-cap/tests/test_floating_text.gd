extends SceneTree

var FloatingText = load("res://floating_text.gd")

func _initialize():
	print("--- Running tests for floating_text.gd ---")
	call_deferred("_run_tests")

func _run_tests():
	await process_frame

	await test_setup_normal()
	await test_setup_critical()
	await test_setup_float_amount()

	print("--- All tests passed! ---")
	quit()

func assert_eq(actual, expected, message=""):
	if actual != expected:
		push_error("Assertion failed: " + message + " (Expected " + str(expected) + " but got " + str(actual) + ")")
		assert(false)

func test_setup_normal():
	print("Running test_setup_normal...")
	var ft = FloatingText.new()
	ft.setup(50, false)

	# Before adding to tree
	assert_eq(ft.amount, 50, "Amount should be 50")
	assert_eq(ft.is_critical, false, "Should not be critical")
	assert_eq(ft.text, "50", "Text should be '50'")
	assert_eq(ft.modulate, Color(1, 1, 1), "Color should be white")
	assert_eq(ft.scale, Vector2(0.8, 0.8), "Scale should be 0.8")

	root.add_child(ft)

	# Now _ready has run, scale should be halved (0.4)
	assert_eq(ft.scale, Vector2(0.4, 0.4), "Scale should be halved in _ready")

	# Wait a frame for tween to maybe start, or just clean up
	await process_frame

	ft.queue_free()

func test_setup_critical():
	print("Running test_setup_critical...")
	var ft = FloatingText.new()
	ft.setup(100, true)

	assert_eq(ft.amount, 100, "Amount should be 100")
	assert_eq(ft.is_critical, true, "Should be critical")
	assert_eq(ft.text, "100!", "Text should be '100!'")
	assert_eq(ft.modulate, Color(1, 0.2, 0.2), "Color should be red")
	assert_eq(ft.scale, Vector2(1.5, 1.5), "Scale should be 1.5")
	assert_eq(ft.velocity, Vector2(0, -80), "Velocity should be -80")

	root.add_child(ft)

	# After _ready
	assert_eq(ft.scale, Vector2(0.75, 0.75), "Scale should be halved in _ready")

	await process_frame

	ft.queue_free()

func test_setup_float_amount():
	print("Running test_setup_float_amount...")
	var ft = FloatingText.new()
	ft.setup(45.6, false)

	assert_eq(ft.amount, 45.6, "Amount should be 45.6")
	assert_eq(ft.text, "45", "Text should truncate float to integer")

	root.add_child(ft)
	await process_frame
	ft.queue_free()
