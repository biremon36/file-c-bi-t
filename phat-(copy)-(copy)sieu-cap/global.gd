extends Node

var coins = 0
var shop_dmg_level = 0
var shop_hp_level = 0
var unlocked_characters = ["yuji"]
var selected_character = "yuji"
var active_potions = {
	"damage": false,
	"xp": false,
	"speed": false
}

const SAVE_PATH = "user://savegame.save"

var best_time = 0.0
# Dynamic Difficulty
var monster_buff_next = false
var monster_buff_active = false
var boss_buff_next = false

func check_new_record(time_val):
	if time_val > best_time:
		best_time = time_val
		save_game()
		return true
	return false

func _ready():
	load_game()

func add_coins(amount):
	coins += amount
	save_game()

func reset_potions():
	active_potions = {
		"damage": false,
		"xp": false,
		"speed": false
	}

func get_next_dmg_cost():
	# Cost 1 for lvl 0->1?
	# "nâng dame thì lv2 cần 2 xu" -> Lv 1 to Lv 2 costs 2.
	# So Cost = Next Level = Current Level + 1
	return shop_dmg_level + 1

func get_next_hp_cost():
	return shop_hp_level + 1

func upgrade_damage():
	var cost = get_next_dmg_cost()
	if coins >= cost:
		coins -= cost
		shop_dmg_level += 1
		save_game()
		return true
	return false

func upgrade_hp():
	var cost = get_next_hp_cost()
	if coins >= cost:
		coins -= cost
		shop_hp_level += 1
		save_game()
		return true
	return false

func get_save_password():
	var env_pass = OS.get_environment("GAME_SAVE_PASSWORD")
	if env_pass != "":
		return env_pass
	return OS.get_unique_id() + "_phat_game_save"

func save_game():
	# Use encrypted save with a dynamic password
	var file = FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.WRITE, get_save_password())
	if file:
		var data = {
			"coins": coins,
			"shop_dmg_level": shop_dmg_level,
			"shop_hp_level": shop_hp_level,
			"unlocked_characters": unlocked_characters,
			"selected_character": selected_character,
			"best_time": best_time
		}
		file.store_line(JSON.stringify(data))
	else:
		print("Error saving encrypted game")

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var data_loaded = false

	# 1. Try to open as an Encrypted file with the new secure password first
	var file = FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.READ, get_save_password())
	if file != null:
		var content = file.get_as_text()
		var json = JSON.new()
		if json.parse(content) == OK:
			_apply_data(json.get_data())
			data_loaded = true

	# 2. Backward compatibility: Try with the old hardcoded password
	if not data_loaded:
		file = FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.READ, "security_password_phat_game")
		if file != null:
			var content = file.get_as_text()
			var json = JSON.new()
			if json.parse(content) == OK:
				_apply_data(json.get_data())
				data_loaded = true
				# Save immediately to update to the new secure password
				save_game()

	# 3. Fallback: If encrypted load failed (likely old plain text save), try normal open
	if not data_loaded:
		file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			var content = file.get_as_text()
			var json = JSON.new()
			if json.parse(content) == OK:
				_apply_data(json.get_data())
				# Immediately save back as encrypted to upgrade the file
				save_game()

func _apply_data(data):
	coins = data.get("coins", 0)
	shop_dmg_level = data.get("shop_dmg_level", 0)
	shop_hp_level = data.get("shop_hp_level", 0)
	unlocked_characters = data.get("unlocked_characters", ["yuji"])
	selected_character = data.get("selected_character", "yuji")
	best_time = data.get("best_time", 0.0)
