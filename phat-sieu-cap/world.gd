extends Node2D

@onready var player = $Player
@onready var ui = $UI
@onready var enemy_scene = preload("res://enemy.tscn")
@onready var xp_orb_scene = preload("res://xp_orb.tscn")

@onready var boss_scene = preload("res://boss.tscn")
@onready var toji_scene = preload("res://boss_toji.tscn")
@onready var pause_menu_scene = preload("res://pause_menu.tscn")

@onready var item_scene = preload("res://item.tscn") # Load generic item
@onready var cursed_object_scene = preload("res://cursed_object.tscn")
@onready var cyber_shader = preload("res://cyber_grid.gdshader")

var spawn_timer = 0.0
var spawn_rate = 1.5
var xp_spawn_timer = 0.0
var xp_spawn_rate = 1.5
var item_spawn_timer = 0.0
var item_spawn_rate = 15.0 # Every 15 seconds

# Game Progression
var game_time = 0.0
var difficulty_multiplier = 1.0
var boss_spawned = false
var is_hard_mode = false
var boss_level = 0 # Tracks how many times boss spawned
var next_boss_time = 50.0

func _ready():
	# Connect UI
	player.health_changed.connect(ui.update_hp)
	player.xp_changed.connect(ui.update_xp)

	# Create Timer for increasing difficulty
	var diff_timer = Timer.new()
	diff_timer.wait_time = 1.0 # Update every second
	diff_timer.timeout.connect(_on_second_tick)
	add_child(diff_timer)
	diff_timer.start()

	# Instantiate and add Pause Menu
	var pause_menu = pause_menu_scene.instantiate()
	add_child(pause_menu)

	# Visual Overhaul: Cyberpunk Background
	_setup_cyberpunk_bg()

	# Visual Overhaul: World Environment (Glow)
	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 1.2 # Increased for Neon
	env.glow_strength = 1.1
	env.glow_bloom = 0.4
	env.glow_hdr_threshold = 0.8
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	world_env.environment = env
	add_child(world_env)

	# Background Music
	if ResourceLoader.exists("res://san.mp3"):
		var bgm = AudioStreamPlayer.new()
		bgm.stream = load("res://san.mp3")
		bgm.autoplay = true
		bgm.finished.connect(func(): bgm.play()) # Manual Loop
		add_child(bgm)
	else:
		print("Music file 'san.mp3' not found in project resources.")


func _setup_cyberpunk_bg():
	var pl = ParallaxBackground.new()
	var layer = ParallaxLayer.new()
	layer.motion_mirroring = Vector2(1000, 1000) # Grid size repetition
	pl.add_child(layer)

	var rect = ColorRect.new()
	rect.custom_minimum_size = Vector2(1000, 1000)
	rect.material = ShaderMaterial.new()
	rect.material.shader = cyber_shader
	rect.material.set_shader_parameter("grid_color", Color(0.0, 1.0, 1.0, 0.3)) # Cyan grid
	rect.material.set_shader_parameter("bg_color", Color(0.05, 0.05, 0.1, 1.0)) # Dark Blue

	# Add Noise Texture to shader if I could, but simple grid is fine.

	layer.add_child(rect)
	add_child(pl)
	move_child(pl, 0) # Send to back

func _process(delta):
	# Item Spawning (Independent of Boss)
	item_spawn_timer -= delta
	if item_spawn_timer <= 0:
		# check every second, 15% chance to spawn
		if randf() < 0.15:
			spawn_item()
		item_spawn_timer = 1.0

	# If boss is present, stop normal spawns (Enemies & XP)
	if boss_spawned:
		return

	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_enemy()
		spawn_timer = spawn_rate

	xp_spawn_timer -= delta
	if xp_spawn_timer <= 0:
		spawn_ambient_xp()
		xp_spawn_timer = xp_spawn_rate

func spawn_item():
	# Check if any item is already in view (approx < 1200 distance)
	var existing = get_tree().get_nodes_in_group("items")
	for i in existing:
		if i.global_position.distance_to(player.global_position) < 1200:
			return # An item is already nearby, don't spam

	var angle = randf() * PI * 2
	var dist = randf_range(800, 1100)
	var spawn_pos = player.position + Vector2(cos(angle), sin(angle)) * dist

	# Random type (10% Cursed)
	var roll = randf()
	if roll < 0.10:
		var cursed_item = item_scene.instantiate()
		cursed_item.position = spawn_pos
		var type = ["finger", "eye", "womb"].pick_random()
		cursed_item.setup(type)
		add_child(cursed_item)
		return

	var item = item_scene.instantiate()
	item.position = spawn_pos

	roll = randf()
	if roll < 0.33:
		item.setup("health")
	elif roll < 0.66:
		item.setup("magnet")
	else:
		item.setup("bomb")

	add_child(item)

func spawn_cursed_object(pos):
	var item = item_scene.instantiate()
	item.position = pos
	var type = ["finger", "eye", "womb"].pick_random()
	item.setup(type)
	item.scale = Vector2(1.5, 1.5)
	call_deferred("add_child", item)

func _on_second_tick():
	if boss_spawned:
		return

	game_time += 1.0
	difficulty_multiplier = 1.0 + (game_time * 0.01)

	ui.update_timer(game_time)

	if game_time >= next_boss_time:
		if not boss_spawned:
			spawn_boss()
			next_boss_time += 50.0
		else:
			next_boss_time += 5.0

func spawn_boss():
	boss_spawned = true
	boss_level += 1

	# Clear existing enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		e.queue_free()

	# Spawn Boss
	var boss
	var is_toji = (boss_level % 3 == 0)
	var boss_name = "Great Spirit"
	var boss_sub = "Level " + str(boss_level)

	if is_toji:
		boss = toji_scene.instantiate()
		boss.encounter_level = int(boss_level / 3)
		boss_name = "TOJI FUSHIGURO"
		boss_sub = "The Sorcerer Killer"
	else:
		boss = boss_scene.instantiate()
		if boss_level > 1:
			boss.extra_slashes = boss_level - 1
		boss_name = "CURSED SPIRIT"
		boss_sub = "Grade " + str(boss_level)

	var spawn_pos = player.position + Vector2(1, 0) * 800 # Further away for dramatic pan
	boss.position = spawn_pos
	boss.set_target(player)

	# Scaling
	var hp_mult = pow(1.2, boss_level - 1)
	var dmg_mult = pow(1.15, boss_level - 1)
	boss.max_hp *= hp_mult
	boss.damage *= dmg_mult

	boss.died.connect(_on_boss_died)
	add_child(boss)

	ui.setup_boss_health(boss)

	# TRIGGER CINEMATIC INTRO
	_play_boss_intro_sequence(boss, boss_name, boss_sub)

func _play_boss_intro_sequence(boss, b_name, b_sub):
	# 1. Pause
	get_tree().paused = true

	# 2. Setup Cinema Cam
	# Assuming player has a 'Camera2D' node named 'Camera2D'
	var p_cam = player.get_node_or_null("Camera2D")
	var start_zoom = Vector2(1, 1)
	var start_pos = player.global_position
	if p_cam:
		start_zoom = p_cam.zoom
		start_pos = p_cam.global_position

	var cam = Camera2D.new()
	cam.process_mode = Node.PROCESS_MODE_ALWAYS
	cam.zoom = start_zoom
	cam.global_position = start_pos
	cam.position_smoothing_enabled = true # Smooth
	cam.position_smoothing_speed = 5.0
	add_child(cam)
	cam.make_current()

	# 3. Pan to Boss
	var tw = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # Run in pause
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	# Tweens position directly implies smoothing must be OFF for direct tween control,
	# OR we tween a target. Let's direct tween position.
	cam.position_smoothing_enabled = false
	tw.tween_property(cam, "global_position", boss.global_position, 1.5)

	await tw.finished

	# 4. Show UI
	var ui_tw = ui.play_boss_intro(b_name, b_sub, start_pos, boss.global_position)
	if ui_tw: await ui_tw.finished

	# Hold for reading (2s)
	await get_tree().create_timer(2.0, true, false, true).timeout

	# 5. UI Out
	ui.close_boss_intro()

	# 6. Pan Back
	var tw2 = create_tween()
	tw2.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw2.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(cam, "global_position", start_pos, 1.0)

	await tw2.finished

	# 7. Resume
	cam.queue_free()
	if p_cam: p_cam.make_current()
	get_tree().paused = false


func spawn_enemy():
	# Cap the max enemies to ensure performance doesn't degrade too much late game
	var max_enemies = min(25 + (boss_level * 2), 60)
	if get_tree().get_nodes_in_group("enemies").size() >= max_enemies:
		return

	var angle
	if randf() < 0.5 and player.velocity.length() > 10:
		var move_angle = player.velocity.angle()
		var deviation = randf_range(-1.2, 1.2)
		angle = move_angle + deviation
	else:
		angle = randf() * PI * 2

	var distance = 900
	var spawn_pos = player.position + Vector2(cos(angle), sin(angle)) * distance

	var enemy = enemy_scene.instantiate()
	enemy.position = spawn_pos
	enemy.player = player

	var hp_mult = pow(1.1, boss_level)
	var dmg_mult = pow(1.15, boss_level)
	enemy.max_hp *= hp_mult * difficulty_multiplier
	enemy.damage *= dmg_mult * difficulty_multiplier
	enemy.speed *= (1.0 + (boss_level * 0.05))

	var roll = randf()
	var elite_chance = 0.05 + (game_time / 600.0) * 0.05
	var speedster_chance = 0.20
	var tank_chance = 0.15

	if roll < elite_chance:
		enemy.setup_elite()
	elif roll < elite_chance + speedster_chance:
		enemy.setup_speedster()
	elif roll < elite_chance + speedster_chance + tank_chance:
		enemy.setup_tank()
	else:
		if boss_level >= 1:
			var sprite = enemy.get_node("Sprite2D")
			if sprite:
				sprite.texture = load("res://quai2.png")
				sprite.scale = Vector2(0.35, 0.35)
				if "scale_base" in enemy:
					enemy.scale_base = Vector2(0.35, 0.35)

	enemy.died.connect(_on_enemy_died)
	add_child(enemy)

func _on_boss_died(pos):
	boss_spawned = false
	ui.hide_boss_health()

	Global.monster_buff_active = Global.monster_buff_next
	Global.monster_buff_next = false
	spawn_rate = max(0.2, 1.5 * pow(0.88, boss_level))
	Global.add_coins(boss_level)

	spawn_cursed_object(pos)

	if is_instance_valid(player):
		var base_xp_reward = player.max_xp * 1.5
		player.gain_boss_xp(base_xp_reward)

func _on_enemy_died(pos):
	if randf() > 0.5:
		return
	var orb = xp_orb_scene.instantiate()
	orb.position = pos
	var type_roll = randf()
	if is_hard_mode or boss_level >= 1:
		if type_roll < 0.20: orb.setup("purple")
		elif type_roll < 0.50: orb.setup("red")
		else: orb.setup("green")
	else:
		if type_roll < 0.08: orb.setup("purple")
		elif type_roll < 0.33: orb.setup("red")
		else: orb.setup("green")
	call_deferred("add_child", orb)

func _on_difficulty_increase():
	if spawn_rate > 0.1:
		spawn_rate -= 0.1

func spawn_ambient_xp():
	var roll = randf()
	var spawn_pos = Vector2.ZERO
	var valid_spawn = false

	if roll < 0.3:
		var angle = randf() * PI * 2
		var dist = randf_range(100, 500)
		spawn_pos = player.position + Vector2(cos(angle), sin(angle)) * dist
		valid_spawn = true
	elif roll < 0.7:
		var angle = randf() * PI * 2
		var dist = randf_range(800, 1100)
		spawn_pos = player.position + Vector2(cos(angle), sin(angle)) * dist
		valid_spawn = true

	if valid_spawn:
		var orb = xp_orb_scene.instantiate()
		orb.position = spawn_pos
		var type_roll = randf()
		if is_hard_mode:
			if type_roll < 0.20: orb.setup("purple")
			elif type_roll < 0.50: orb.setup("red")
			else: orb.setup("green")
		else:
			if type_roll < 0.08: orb.setup("purple")
			elif type_roll < 0.28: orb.setup("red")
			else: orb.setup("green")
		add_child(orb)
