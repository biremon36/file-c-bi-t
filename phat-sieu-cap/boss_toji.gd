extends CharacterBody2D

signal died(pos)

@export var max_hp = 300.0
@export var damage = 40.0 # 40% player max HP logic handled in attack
var current_hp = 500.0

@onready var sprite = $Sprite2D
@onready var hp_bar = $ProgressBar
@onready var stun_label = $StunLabel

var player = null
var is_invincible = true
var orbs_active = 0
var max_orbs = 5
var stun_timer = 0.0
var toji_orb_scene = preload("res://toji_orb.tscn")
@onready var floating_text_scene = preload("res://floating_text.tscn")
var arrow_indicators = []

# Attack Logic
var attack_state = "IDLE" # IDLE, PREPARE, WARNING, DASHING, STUNNED
var dash_queue = [] # List of {start: V2, target: V2}
var warning_timer = 0.0
var warning_duration = 1.5
var dash_timer = 0.0
var dash_duration = 0.2
var next_attack_timer = 2.0
var phase = 1 # Phase 1 (>50%), Phase 2 (<50%)
var current_skill = "DASH" # DASH, SMASH, STEALTH
# const GlobalUtils = preload("res://GlobalUtils.gd") # Shadowing fix

# Progression
var encounter_level = 1 # 1st time, 2nd time...
var dashes_per_attack = 1 # Standard 1, increases per level

var warning_line = null # Line2D node
var current_dash_target = Vector2.ZERO
var current_dash_start = Vector2.ZERO

func _ready():
	add_to_group("enemies")
	add_to_group("boss")

	hp_bar.max_value = max_hp
	hp_bar.value = current_hp

	# Create Line2D for warning
	warning_line = Line2D.new()
	warning_line.width = 100 # "dường đỏ của toji to lên"
	warning_line.default_color = Color(1, 0, 0, 0.4) # Transparent red
	add_child(warning_line)
	warning_line.visible = false

	# Spawn Orbs roughly around
	call_deferred("spawn_orbs")

	# Initial Invincible visual
	sprite.modulate = Color(0.3, 0.3, 0.3, 0.8) # Ghostly dark
	stun_label.visible = false

	# Fallback Collider if TCM is missing
	if not has_node("CollisionShape2D"):
		var col = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 40
		col.shape = shape
		add_child(col)

	# FORCE HITBOX (Area2D) for detection
	var hitbox = Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 2 # Enemy Layer
	hitbox.collision_mask = 0 # Doesn't need to scan
	var h_shape = CircleShape2D.new()
	h_shape.radius = 50
	var h_col = CollisionShape2D.new()
	h_col.shape = h_shape
	hitbox.add_child(h_col)
	add_child(hitbox)
	# Bullets check Area entered? Bullet is Area.
	# Bullet uses body_entered. Area-Area detection requires area_entered.
	# Vortex Bullet uses body_entered.
	# Sukuna Slash uses body_entered.
	# CharacterBody IS a body.

	# Fix Collision Layer on Self
	collision_layer = 2 # Layer 2 (Enemy)
	collision_mask = 1 # Mask 1 (Player)

	# Fix Collision Layer on Self
	collision_layer = 2 # Layer 2 (Enemy)
	collision_mask = 1 # Mask 1 (Player)

	# Fix Collision Layer on Self
	if Global.boss_buff_next:
		max_hp *= 1.6 # Buff 60%
		current_hp = max_hp
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp
		Global.boss_buff_next = false

func set_target(p):
	player = p

func spawn_orbs():
	# Clear old indicators just in case
	for item in arrow_indicators:
		if is_instance_valid(item["arrow"]): item["arrow"].queue_free()
	arrow_indicators.clear()

	orbs_active = 5
	for i in range(5):
		var orb = toji_orb_scene.instantiate()
		orb.setup(self)
		# Spread around boss 300-600 radius - Random scatter ("vị trí mấy quả orb lộn xộn là xa tí")
		var angle = randf() * PI * 2 # Random angle
		var dist = randf_range(300.0, 600.0) # Random distance far
		var pos = global_position + Vector2(cos(angle), sin(angle)) * dist
		orb.global_position = pos
		orb.scale = Vector2(0.3, 0.3) # User request: "giảm kích thước mấy cục đó lại"
		get_parent().add_child(orb)

		# Create Arrow Indicator
		var arrow = Polygon2D.new()
		arrow.polygon = PackedVector2Array([
			Vector2(0, -10), Vector2(0, 10), Vector2(20, 0)
		])
		arrow.color = Color(0, 0, 0) # Black arrow
		arrow.position = Vector2.ZERO
		arrow.visible = false
		add_child(arrow)
		arrow_indicators.append({"arrow": arrow, "target": orb})

func on_orb_collected():
	orbs_active -= 1
	if orbs_active <= 0:
		start_stun()

func start_stun():
	is_invincible = false
	attack_state = "STUNNED"
	stun_timer = 7.0
	sprite.modulate = Color(1, 1, 1, 1) # Normal
	warning_line.visible = false
	stun_label.visible = true

	# KILL TWEENS to stop Dashing immediately
	var tween_killer = create_tween()
	tween_killer.kill() # Dummy to access specific kill? No, use get_tree().create_tween().kill()?
	# Correct way to stop specific tween on self:
	# Keep track of active tween OR just overwrite state so finish_dash checks it.
	# But physics update might move him.
	# Let's rely on state check in finish_dash.

func _physics_process(delta):
	# Update Stun
	if attack_state == "STUNNED":
		stun_timer -= delta
		stun_label.text = "VULNERABLE: " + str(ceil(stun_timer))
		if stun_timer <= 0:
			# Recovery
			is_invincible = true
			sprite.modulate = Color(0.3, 0.3, 0.3, 0.8)
			attack_state = "IDLE"
			stun_label.visible = false
			spawn_orbs() # Respawn mechanic

			# Restore collision (just in case we disabled it?)
			collision_layer = 2 # Enemy layer
		else:
			# Force Invincible OFF during stun (Redundant safety)
			is_invincible = false

		return

	# Update Indicators - Check validity first to prevent crashes
	for item in arrow_indicators:
		# Safety check: Only access arrow if it's valid
		if not is_instance_valid(item.get("arrow")):
			continue

		var arrow = item["arrow"]
		var orb = item.get("target")

		if is_instance_valid(orb) and is_instance_valid(player):
			# Show if orb is far
			var dist = player.global_position.distance_to(orb.global_position)
			if dist > 300: # Only show if "xa quá"
				arrow.visible = true
				arrow.global_position = player.global_position + (player.global_position.direction_to(orb.global_position) * 80.0)
				arrow.look_at(orb.global_position)
			else:
				arrow.visible = false
		else:
			arrow.visible = false

	# Clean arrow list - Remove first, then queue_free to prevent access after free
	for i in range(arrow_indicators.size() - 1, -1, -1):
		var item = arrow_indicators[i]
		var arrow_valid = is_instance_valid(item.get("arrow"))
		var target_valid = is_instance_valid(item.get("target"))

		if not arrow_valid or not target_valid:
			# Remove from array FIRST
			arrow_indicators.remove_at(i)
			# THEN free the arrow if it was valid
			if arrow_valid:
				item["arrow"].queue_free()

	if not is_instance_valid(player): return

	match attack_state:
		"IDLE":
			# Wait for next attack sequence
			next_attack_timer -= delta
			if next_attack_timer <= 0:
				choose_attack()
		"WARNING":
			warning_timer -= delta
			if warning_timer <= 0:
				execute_skill()
		"DASHING", "SMASHING", "STEALTH":
			pass

func choose_attack():
	# Phase Check
	if current_hp < max_hp * 0.5:
		phase = 2
		warning_duration = 1.0 # Faster
		sprite.modulate = Color(1, 0.5, 0.5) # Enrage Red tint when not invincible?
		if is_invincible:
			sprite.modulate = Color(0.3, 0.1, 0.1, 0.8)
		else:
			# If somehow stunned in phase change (rare), keep normal color
			sprite.modulate = Color(1, 0.5, 0.5)

		# Phase 2 Announcement (Once)
		if encounter_level > 0: # Just a check to ensure we don't spam
			# Note: choose_attack is called repeatedly. We shouldn't spawn text every time.
			# But phase logic runs every time.
			# Let's just rely on Color change.
			pass

	var roll = randf()
	var special_chance = 0.3 # 30% Base chance in Phase 1
	if phase == 2: special_chance = 0.8 # 80% in Phase 2

	if roll < special_chance:
		# Special Skill
		if randf() > 0.5:
			start_ground_smash()
		else:
			start_stealth_ambush()
	else:
		start_dash_sequence()

func start_dash_sequence():
	current_skill = "DASH"
	dash_queue.clear()
	var count = encounter_level
	if phase == 2: count += 1 # More dashes

	current_dash_start = global_position
	prepare_next_dash_in_chain(count)

func prepare_next_dash_in_chain(remaining_count):
	if remaining_count <= 0:
		reset_to_idle()
		return

	dashes_per_attack = remaining_count
	attack_state = "WARNING"
	warning_timer = warning_duration
	current_dash_start = global_position

	# DASH LOGIC:
	var dir = global_position.direction_to(player.global_position)
	var dist_to_player = global_position.distance_to(player.global_position)
	var dist = dist_to_player + 1000.0
	current_dash_target = global_position + dir * dist

	warning_line.clear_points()
	warning_line.add_point(Vector2.ZERO)
	warning_line.add_point(to_local(current_dash_target))
	warning_line.width = 100
	warning_line.default_color = Color(1, 0, 0, 0.4)
	warning_line.visible = true

func start_ground_smash():
	current_skill = "SMASH"
	attack_state = "WARNING"
	warning_timer = 2.0 # Long windup
	spawn_floating_text(0, true, "GROUND SMASH!")

	# Teleport above player? Or just jump to them?
	# Let's simple create a BIG circle warning at Player pos
	current_dash_target = player.global_position

	# Visual Warning (Circle) - We can simulate circle with Line2D box or Points
	warning_line.clear_points()
	var sides = 16
	var radius = 250.0
	for i in range(sides + 1):
		var angle = i * PI * 2 / sides
		var p = Vector2(cos(angle), sin(angle)) * radius
		warning_line.add_point(to_local(current_dash_target) + p)

	warning_line.width = 5
	warning_line.default_color = Color(1, 0.5, 0, 0.5) # Orange warning
	warning_line.visible = true

func start_stealth_ambush():
	current_skill = "STEALTH"
	attack_state = "STEALTH"
	spawn_floating_text(0, true, "AMBUSH!")
	# Vanish
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	await tween.finished

	# Wait unseen
	if get_tree():
		await get_tree().create_timer(1.0).timeout
	else:
		return

	if not is_instance_valid(player): return

	# Reappear BEHIND player
	# Find "Behind" vector (-Velocity) if moving, or just random angle
	var offset = Vector2(-100, 0)
	if player.velocity.length() > 10:
		offset = -player.velocity.normalized() * 100
	else:
		offset = Vector2(100, 0).rotated(randf() * 6.28)

	global_position = player.global_position + offset

	# Attack immediately (Surprise!)
	sprite.modulate.a = 1.0
	# "Inverted Spear" Stab
	var dmg = player.max_hp * 0.50 # 50% HP

	# Check distance (if player didn't dash away instantly)
	if global_position.distance_to(player.global_position) < 150:
		player.take_damage(dmg, true) # Crit true
		spawn_floating_text(0, true, "SNEAK ATTACK!")

	reset_to_idle()

func execute_skill():
	if current_skill == "DASH":
		execute_dash()
	elif current_skill == "SMASH":
		execute_smash()

func execute_smash():
	attack_state = "SMASHING"
	warning_line.visible = false

	# Teleport/Land on target
	global_position = current_dash_target

	# Shake Screen? (Optional)

	# Check Hit
	var dist = global_position.distance_to(player.global_position)
	if dist < 250: # Radius
		var dmg = player.max_hp * 0.60 # Heavy Damage
		player.take_damage(dmg)
		# Stun player?
		# if player.has_method("stun"): player.stun(1.0)

	# Recovery
	if get_tree():
		await get_tree().create_timer(1.0).timeout
	reset_to_idle()

func execute_dash():
	attack_state = "DASHING"
	check_hit_player()

	var tween = create_tween()
	tween.tween_property(self, "global_position", current_dash_target, 0.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_callback(finish_dash)

func reset_to_idle():
	attack_state = "IDLE"
	next_attack_timer = 1.5 if phase == 2 else 2.0
	warning_line.visible = false

func check_hit_player():
	# Simple segment check
	# Toji width is roughly 50px. Line width 40px.
	var p_pos = player.global_position
	var start = current_dash_start
	var end = current_dash_target

	# Math for distance point to segment
	var closest = Geometry2D.get_closest_point_to_segment(p_pos, start, end)
	# "to nhưng vẫn đủ để player chạy" - radius should be close to half width + player size
	# Width 100 -> Radius ~50. Let's give it 80 radius (approx 160 width hitbox) for "to".
	if p_pos.distance_to(closest) < 80.0: # Hit radius
		# Deal 40% Max HP
		var dmg = player.max_hp * 0.40
		player.take_damage(dmg)

func finish_dash():
	# CRITICAL FIX: If Stunned mid-dash, DO NOT proceed to next dash
	if attack_state == "STUNNED":
		return

	# Next dash?
	warning_line.visible = false
	prepare_next_dash_in_chain(dashes_per_attack - 1)

func take_damage(amount, is_critical = false):
	if is_invincible:
		# Double check if we should actually be invincible
		# If attack state is STUNNED, force OFF invincibility
		if attack_state == "STUNNED":
			is_invincible = false
		else:
			spawn_floating_text(0, false, "MISS")
			return # No damage

	if first_damage_time == 0.0:
		first_damage_time = Time.get_ticks_msec()

	current_hp -= amount
	hp_bar.value = current_hp

	spawn_floating_text(amount, is_critical)

	if current_hp <= 0:
		die()

func spawn_floating_text(amount, is_critical, custom_text = ""):
	var txt = floating_text_scene.instantiate()
	if custom_text != "":
		txt.text = custom_text # Override
		txt.setup(0, false) # Setup basics
		txt.text = custom_text # Re-apply text after setup
		txt.modulate = Color(0.5, 0.5, 0.5) # Grey for miss
	else:
		txt.setup(amount, is_critical)

	txt.global_position = global_position + Vector2(randf_range(-40,40), -120)
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

	# Clear Orbs
	get_tree().call_group("toji_orbs", "queue_free")

	# Clear cached boss reference in player
	if is_instance_valid(player) and player.has_method("clear_cached_boss"):
		player.clear_cached_boss()

	emit_signal("died", global_position)
	spawn_death_particles()
	queue_free()

func spawn_death_particles():
	var p = CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.amount = 150
	p.lifetime = 2.0
	p.explosiveness = 0.95
	p.spread = 180
	p.gravity = Vector2(0, 0)
	p.initial_velocity_min = 150
	p.initial_velocity_max = 400
	p.scale_amount_min = 6.0
	p.scale_amount_max = 15.0
	p.color = Color(0.2, 0.2, 1.0, 1.0) # Toji Blue
	p.global_position = global_position
	get_parent().add_child(p)

	var timer = get_tree().create_timer(2.5)
	timer.timeout.connect(p.queue_free)

var first_damage_time = 0.0
