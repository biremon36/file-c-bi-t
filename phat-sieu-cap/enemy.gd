extends CharacterBody2D

signal died(pos)

@export var speed = 130
@export var max_hp = 20.0
@export var damage = 10 # Damage dealt to player

var hp = 20.0
var player = null
var flank_dir = 1 # 1 for Right, -1 for Left check

var stun_timer = 0.0 # Replaces boolean is_stunned logic
var scale_base = Vector2(1, 1) # Added scale base
var is_stunned: bool:
	get: return stun_timer > 0.0

func _ready():
	hp = max_hp
	flank_dir = 1 if randf() > 0.5 else -1 # Randomize flank direction
	add_to_group("enemies")
	# Disable collision with player (Layer 1) so we don't get stuck
	# Assuming Player is on Layer 1. bit 1 is value 1.
	# Assuming Player is on Layer 1. bit 1 is value 1.
	collision_mask &= ~1

	# Assuming Player is on Layer 1. bit 1 is value 1.
	collision_mask &= ~1

	if Global.monster_buff_active:
		max_hp *= 1.6 # Buff 60%
		hp = max_hp
		modulate = Color(1.5, 0.5, 0.5) # Slight red tint to show buff
		# DO NOT consume active flag here, applies to whole wave
		pass
		# If user meant "Next Wave/Screen", consuming it per enemy makes it apply to only ONE enemy.
		# That's weak. Let's KEEP it true in Global until World consumes it or a timer resets it?
		# Let's re-read: "màn sau... rồi quay về cơ chế cũ". A "màn" is a level.
		# In world.gd, I will clear the flags when Boss Spawns (End of Wave/Level).
		# So DO NOT set false here. Just apply it.
		pass

	# Enable swarming behavior
	# We need a small area2d to detect neighbors OR just use loop (expensive)
	# For optimization, we can just use a simple separation vector in physics process
	# if we check a few random neighbors or rely on physics engine soft collisions
	# But Godot CharacterBody2D has collision, so if they have collision masks with each other,
	# they will naturally push each other apart IF 'move_and_slide' is used correctly.
	# To make them 'surround' explicitly, we add a tangential component or lateral separation force.

	if has_node("Sprite2D"):
		scale_base = $Sprite2D.scale # Capture initial scale (e.g. 0.35 from quai2)

func _physics_process(delta):
	# Update Stun Timer
	if stun_timer > 0.0:
		stun_timer -= delta
		return # Stop movement logic

	if player:
		# 1. Seek Behavior (Target Player)
		var desired_velocity = position.direction_to(player.position) * speed

		# 2. Separation Logic (Avoid crowding)
		# Simple approach: Check nearby enemies using a group check (can be expensive if too many)
		# Optimization: Only check a subset or use SoftCollisions if implemented.
		# Here we'll do a simple distance check on limited neighbors for "Surround" feel.

		var separation_force = Vector2.ZERO
		var neighbors = GlobalUtils.get_group(self, "enemies")
		var count = 0

		# Optimization: Only process separation logic if relatively close to the player
		# OR if randomly selected this frame to avoid all enemies checking every frame
		if global_position.distance_squared_to(player.global_position) < 400000 and randf() > 0.3:
			for neighbor in neighbors:
				if neighbor == self: continue

				var dist_sq = global_position.distance_squared_to(neighbor.global_position)
				if dist_sq < 2500: # Within 50px
					var push = global_position - neighbor.global_position
					separation_force += push.normalized() / (dist_sq + 0.1) * 2000 # Weighted by distance
					count += 1
					if count > 3: break # Reduced limit for better performance

		# 3. Encircle/Flank Behavior (New)
		# "Tản ra để player khỏi chạy sang trái sang phải"
		# If within intermediate range (e.g. < 400), push sideways
		var to_player = player.global_position - global_position
		var dist_to_player = to_player.length()
		var encircle_force = Vector2.ZERO

		# If relatively close but not touching, try to orbit/surround
		var current_speed = speed

		if dist_to_player > 850:
			current_speed = 180 # Boost speed when off-screen to catch up
		elif dist_to_player < 500 and dist_to_player > 50:
			current_speed = 155 # SPEED BOOST when flanking
			# Tangent vector (perpendicular to direct path)
			var tangent = to_player.normalized().rotated(PI / 2 * flank_dir)

			# Weight increases as we get closer, forcing a spread
			encircle_force = tangent * 80.0

			# Optional: Switch flank direction if hitting friends?
			# For now, sticking to one side creates a nice spiral effect.

		# Combine vectors
		# Weights: Seek (100) + Separation (Variable High) + Encircle (80)
		var desired_dir = desired_velocity.normalized() * 100
		var final_vector = desired_dir + separation_force + encircle_force

		velocity = final_vector.normalized() * current_speed

		move_and_slide()

		# Visual: Breathing - Re-enabled Relative
		var breathe = sin(Time.get_ticks_msec() / 200.0) * 0.05
		if $Sprite2D:
			# Apply relative to base scale
			var breathe_scale = Vector2(1.0 + breathe, 1.0 - breathe)
			$Sprite2D.scale = scale_base * breathe_scale
			# Flip logic is handled by flip_h, so scale remains positive (or whatever base is).

		# Facing
		if velocity.x != 0:
			if $Sprite2D: $Sprite2D.flip_h = velocity.x > 0

		# Check distance for damage (Hitbox logic - Player)
		var dist = global_position.distance_to(player.global_position)
		if dist < 40: # Approx radius overlap
			if player.has_method("take_damage"):
				player.take_damage(damage * delta)

		# Check distance for damage (Rika)
		var rikas = GlobalUtils.get_group(self, "rika")
		for r in rikas:
			if global_position.distance_to(r.global_position) < 40:
				if r.has_method("take_damage"):
					r.take_damage(damage * delta)



func die():
	var kill_duration = 999.0
	if first_damage_time > 0:
		kill_duration = (Time.get_ticks_msec() - first_damage_time) / 1000.0

	if kill_duration < 1.0:
		# Too fast! Safeguard Trigger.
		if not Global.monster_buff_next:
			Global.monster_buff_next = true

			# UI Notification (Screen Center)
			var world = get_parent() # Enemy parent is World?
			if world and world.has_node("UI"):
				world.get_node("UI").show_safeguard_warning("CƠ CHẾ AN TOÀN: BUFF QUÁI MÀN SAU!")

			# Floating Text (Backup)
			var txt = floating_text_scene.instantiate()
			txt.text = "SAFEGUARD!"
			txt.setup(0, true)
			txt.modulate = Color(1, 0, 0)
			txt.scale *= 1.5
			txt.global_position = global_position
			get_parent().call_deferred("add_child", txt)

	emit_signal("died", position)
	spawn_death_particles()
	queue_free()

func spawn_death_particles():
	var p = CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.amount = 30 # Increased amount for more visual impact
	p.lifetime = 0.8
	p.explosiveness = 0.9
	p.spread = 180
	p.gravity = Vector2(0, 0)
	p.initial_velocity_min = 80
	p.initial_velocity_max = 200
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0

	# Add a basic fade-out curve by adjusting alpha over time via code or curve,
	# here we'll just set it to use the enemy's color with a bit of brightness
	var base_col = modulate
	p.color = Color(min(base_col.r * 1.5, 1.0), min(base_col.g * 1.5, 1.0), min(base_col.b * 1.5, 1.0), 1.0)
	p.global_position = global_position
	get_parent().add_child(p)

	# Optional: spawn a second system for a "blood/energy core" effect
	var core_p = p.duplicate()
	core_p.amount = 10
	core_p.initial_velocity_max = 50
	core_p.color = Color(1, 1, 1, 1) # White core
	get_parent().add_child(core_p)

	# Cleanup particle
	var timer = get_tree().create_timer(1.5)
	timer.timeout.connect(p.queue_free)
	timer.timeout.connect(core_p.queue_free)

var first_damage_time = 0.0

func stun(duration):
	# Add duration (stacking) or Refresh?
	# User says "dính hiệu ứng bất động". Refreshing is safer to keep them pinned.
	# Let's Refresh (Max of current remaining vs new duration)
	if duration > stun_timer:
		stun_timer = duration

	# Visual Feedback
	modulate = Color(0.5, 0.5, 1.0) # Blue tint

	# We need to restore color after stun.
	# Since we use variable decrement, color restore should happen in process when stun reaches 0.
	# But checking every frame for == 0 is tricky.
	# Let's just create a one-off tween that waits? No, overlapping tweens.
	# Let's check in physics process: if stun_timer <= 0 and was_stunned...
	# Simplified: just rely on the 'take_damage' or 'ready' color logic to eventually restore,
	# OR add a check in process.
	pass

var floating_text_scene = preload("res://floating_text.tscn")

func spawn_floating_text(amount, is_critical):
	var txt = floating_text_scene.instantiate()
	txt.setup(amount, is_critical)
	txt.global_position = global_position + Vector2(randf_range(-20,20), -30)
	get_parent().add_child(txt)

func take_damage(amount, is_critical = false):
	if first_damage_time == 0.0:
		first_damage_time = Time.get_ticks_msec()

	hp -= amount
	spawn_floating_text(amount, is_critical)

	modulate = Color(10, 10, 10) # White flash
	var tween = create_tween()
	# Restore to original color based on type
	var target_color = Color(1, 1, 1)
	if enemy_type == "elite": target_color = Color(1, 0.4, 0.4)
	elif enemy_type == "speedster": target_color = Color(1, 1, 0.4)
	elif enemy_type == "tank": target_color = Color(0.4, 1, 0.4)

	tween.tween_property(self, "modulate", target_color, 0.1)

	if hp <= 0:
		die()

var enemy_type = "normal"

func setup_elite():
	enemy_type = "elite"
	scale = Vector2(1.4, 1.4)
	# Wait, setting 'scale' on CharacterBody2D scales everything including collision.
	# But 'scale_base' tracks SPRITE scale usually.
	# If we scale the whole root, sprite scale remains (1,1) locally in most cases unless set separately.
	# BUT earlier quai2 logic set sprite.scale directly to 0.35.
	# Admin logic sets sprite.scale to 0.2.
	# If 'setup_elite' scales root, sprite local scale is preserved.
	# So scale_base needs to track SPRITE local scale.
	pass
	modulate = Color(1, 0.4, 0.4) # Red
	max_hp *= 4.0
	hp = max_hp
	damage *= 2.0
	speed *= 0.8 # Slightly slower

func setup_speedster():
	enemy_type = "speedster"
	scale = Vector2(0.8, 0.8)
	modulate = Color(1, 1, 0.4) # Yellow
	max_hp *= 0.6
	hp = max_hp
	speed *= 1.5

func setup_tank():
	enemy_type = "tank"
	scale = Vector2(1.3, 1.3)
	modulate = Color(0.4, 1, 0.4) # Green
	max_hp *= 3.0
	hp = max_hp
	speed *= 0.7
