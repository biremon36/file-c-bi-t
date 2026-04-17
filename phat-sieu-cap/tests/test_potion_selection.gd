extends Node

const PotionSelection = preload("res://potion_selection.tscn")

func _ready():
	print("Running Potion Selection Tests...")

	test_initial_state()
	test_buy_success()
	test_buy_insufficient_coins()
	test_buy_already_purchased()

	print("All Potion Selection Tests Passed!")
	get_tree().quit()

func test_initial_state():
	print("Test: test_initial_state")
	Global.coins = 100
	Global.active_potions["damage"] = true # Set to true to test reset

	var potion_ui = PotionSelection.instantiate()
	add_child(potion_ui)

	assert(Global.active_potions["damage"] == false, "Potions should be reset on ready")
	assert(potion_ui.coin_label.text == "Xu: 100", "Coin label should display correct initial coins")

	potion_ui.queue_free()
	print("-> Pass")

func test_buy_success():
	print("Test: test_buy_success")
	Global.coins = 10
	Global.active_potions["xp"] = false

	var potion_ui = PotionSelection.instantiate()
	add_child(potion_ui)

	# Simulate buying XP potion (cost 8)
	var btn = Button.new()
	potion_ui._on_buy_pressed("xp", btn)

	assert(Global.coins == 2, "Coins should be reduced by 8")
	assert(Global.active_potions["xp"] == true, "Potion should be marked as active")
	assert(btn.text == "Đã Mua", "Button text should change")
	assert(btn.disabled == true, "Button should be disabled")

	potion_ui.queue_free()
	print("-> Pass")

func test_buy_insufficient_coins():
	print("Test: test_buy_insufficient_coins")
	Global.coins = 5
	Global.active_potions["speed"] = false

	var potion_ui = PotionSelection.instantiate()
	add_child(potion_ui)

	var btn = Button.new()
	btn.text = "Mua"
	potion_ui._on_buy_pressed("speed", btn)

	assert(Global.coins == 5, "Coins should not be reduced")
	assert(Global.active_potions["speed"] == false, "Potion should not be active")
	assert(btn.text == "Mua", "Button text should not change")

	potion_ui.queue_free()
	print("-> Pass")

func test_buy_already_purchased():
	print("Test: test_buy_already_purchased")
	Global.coins = 20
	Global.active_potions["damage"] = true

	var potion_ui = PotionSelection.instantiate()
	add_child(potion_ui)

	# Try to buy again
	var btn = Button.new()
	btn.text = "Mua"
	potion_ui._on_buy_pressed("damage", btn)

	assert(Global.coins == 20, "Coins should not be reduced if already bought")
	assert(Global.active_potions["damage"] == true, "Potion should still be active")

	potion_ui.queue_free()
	print("-> Pass")
