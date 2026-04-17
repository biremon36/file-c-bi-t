extends CharacterBody2D

signal died(pos)

@export var max_hp = 300.0  # Reduced from 500.0 for "low health" request
@export var speed = 500.0
@export var damage = 25.0
var current_hp = 300.0

@onready var sprite = $Sprite2D
@onready var hp_bar = $ProgressBar
@onready var slash_scene = preload("res://sukuna_slash.tscn")
@onready var floating_text_scene = preload("res://floating_text.tscn")

var player = null
var attack_interval = 0.75
var attack_timer = 2.0
var scale_base = Vector2(1, 1)

func _ready():
	add_to_group("enemies") # Boss is an enemy
	add_to_group("boss")

	current_hp = max_hp
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	if sprite:
		scale_base = sprite.scale

	# Boss Aura (visual only, simple modulation pulse for now)
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "modulate", Color(1.2, 0.8, 0.8), 0.5)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.5)

	tween.tween_property(sprite, "modulate", Color(1.2, 0.8, 0.8), 0.5)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.5)

	if Global.boss_buff_next:
		max_hp *= 1.6
		current_hp = max_hp
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp
		Global.boss_buff_next = false # Consume immediately for boss (since there is only 1 boss per "màn")

func _physics_process(delta):
	if player:
		# Move towards player
		velocity = position.direction_to(player.position) * speed
		move_and_slide()

		# Boss Bobbing (Scale Pulse)
		var breathe = sin(Time.get_ticks_msec() / 150.0) * 0.05
		if sprite:
			var pulse = Vector2(1.0 + breathe, 1.0 - breathe)
			sprite.scale = scale_base * pulse

		# Check distance for catch-up teleport
		var dist = global_position.distance_to(player.global_position)
		if dist > 1200: # Slightly more than the spawn/despawn range of items
			# Teleport to edge of view (approx 700 px)
			# Maintain relative angle so it feels like it just caught up
			var dir_from_player = player.global_position.direction_to(global_position)
			global_position = player.global_position + dir_from_player * 700.0

		# Facing
		if velocity.x != 0:
			sprite.flip_h = velocity.x > 0

		# Attack
		attack_timer -= delta
		if attack_timer <= 0:
			fire_skill()
			attack_timer = attack_interval

func set_target(p):
	player = p

@export var extra_slashes = 0

func fire_skill():
	# Fire 5 random slashes + extra from boss level
	var count = 5 + extra_slashes

	for i in range(count):
		var slash = slash_scene.instantiate()
		slash.target_group = "player" # Target PLAYER

		# User Request: Boss Toji deals 50% of Player's Max HP per hit
		if is_instance_valid(player):
			slash.damage = player.max_hp * 0.5
		else:
			slash.damage = damage

		slash.speed = 900.0 # Boss slash slower slightly so player can dodge?
		slash.modulate = Color(1.0, 0.2, 0.2) # Dark Red
		slash.show_trail = false # Remove red trail for boss to reduce lag

		slash.global_position = global_position

		var random_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		slash.velocity = random_dir * slash.speed
		slash.lifetime = 20.0 # Boss range unlimited (20s * 900speed = 18000px)

		get_parent().call_deferred("add_child", slash)

func take_damage(amount, is_critical = false):
	if first_damage_time == 0.0:
		first_damage_time = Time.get_ticks_msec()

	current_hp -= amount
	hp_bar.value = current_hp

	spawn_floating_text(amount, is_critical)

	if current_hp <= 0:
		die()

func spawn_floating_text(amount, is_critical):
	var txt = floating_text_scene.instantiate()
	txt.setup(amount, is_critical)
	txt.global_position = global_position + Vector2(randf_range(-40,40), -100) # Higher offset for boss
	get_parent().add_child(txt)

func die():
	var kill_duration = 999.0
	if first_damage_time > 0:
		kill_duration = (Time.get_ticks_msec() - first_damage_time) / 1000.0

	if kill_duration < 1.0:
		if not Global.boss_buff_next:
			Global.boss_buff_next = true

			var world = get_parent()
			if world and world.has_node("UI"):
				world.get_node("UI").show_safeguard_warning("CƠ CHẾ AN TOÀN: BUFF BOSS MÀN SAU!")

			var txt = floating_text_scene.instantiate()
			txt.text = "SAFEGUARD!"
			txt.setup(0, true)
			txt.modulate = Color(1, 0, 0)
			txt.scale *= 2.0
			txt.global_position = global_position
			get_parent().call_deferred("add_child", txt)

	emit_signal("died", global_position)
	spawn_death_particles()
	queue_free()

func spawn_death_particles():
	var p = CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.amount = 100
	p.lifetime = 1.5
	p.explosiveness = 0.95
	p.spread = 180
	p.gravity = Vector2(0, 0)
	p.initial_velocity_min = 100
	p.initial_velocity_max = 300
	p.scale_amount_min = 5.0
	p.scale_amount_max = 12.0
	p.color = Color(1.0, 0.2, 0.2, 1.0)
	p.global_position = global_position
	get_parent().add_child(p)

	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(p.queue_free)
	# Maybe Win Game?

var first_damage_time = 0.0
