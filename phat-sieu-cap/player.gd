extends CharacterBody2D

signal health_changed(current, max)
signal xp_changed(current, max, level)

var SPEED = 400.0

@onready var sprite = $Sprite2D
@onready var camera = $Camera2D
@onready var bullet_scene = preload("res://bullet.tscn")
@onready var vortex_bullet_scene = preload("res://vortex_bullet.tscn")

# Screen Shake
var shake_intensity = 0.0
var shake_decay = 5.0


# Stats
var max_hp = 100.0
var current_hp = 100.0
var damage_reduction_multiplier = 1.0 # Starts at 1.0 (100% damage taken), reduces by 5% per level

# Dash System
var is_dashing = false
var dash_cooldown = 0.0
var dash_duration = 0.0
var dash_speed_multiplier = 3.5
var damage_output_multiplier = 1.0 # Starts at 1.0, increases by 5% per level

# Cursed Object Stats (Added)
var damage_multiplier = 0.0 # Additive bonus (e.g. +0.5)
var damage_taken_multiplier = 1.0 # Multiplicative penalty (e.g. 1.5x taken)
var hp_regen = 0.0 # Health per second
var bullet_range = 0.0 # Extra range from items

# XP System
var xp = 0
var max_xp = 100
var level = 1

# Attack System
# Attack System
var attack_timer = 0.0
var base_attack_cooldown = 1.5
var attack_cooldown = 1.5
var attack_damage = 10.0
var attack_range = 500.0

# Magnet Effect
var magnet_active = false
var base_pickup_range = 50.0 # Standard collection range
var magnet_pickup_range = 300.0 # Expanded range
var magnet_timer = 0.0
var magnet_duration = 10.0

# Upgrades
var upgrade_levels = {
	"speed": 0,
	"damage": 0,
	"hp": 0,
	"range": 0,
	"gojo": 0,
	"sukuna": 0,
	"bullet_plus": 0, # New skill: Bullet Update
	"xp_boost": 0, # New skill: 10% XP Boost
	"rika": 0, # New skill: Summon Rika
	"crit": 0 # New skill: Critical Hit
}
var rika_bonus_damage_percent = 0.0 # Bonus from HP upgrades
var max_upgrade_level = 5

# Crit Stats
var crit_chance = 0.05 # 5% Base
var crit_damage = 1.50 # 150% Base

# Gojo Skill
var rotating_orb_scene = preload("res://rotating_orb.tscn")
var gojo_active = false

# Sukuna Skill
var sukuna_slash_scene = preload("res://sukuna_slash.tscn")
var sukuna_timer = 0.0
var active_sukuna_slash = null # Track the single infinite slash for Lv 6

var sukuna_base_cooldown = 3.0

# Rika Skill
var rika_scene = preload("res://rika.tscn")
var rika_minions = []


var gojo_timer = 0.0 # Tracks cycle (Active <-> Inactive)
var gojo_active_duration = 5.0
var gojo_cooldown_duration = 4.0
var gojo_orbs_node = null # A Node2D to hold orbs and rotate
var gojo_rotation_angle = 0.0
var boss_arrow = null
var fusion_manager = null # For Fusion Skills

# Safeguard Mechanism
var safeguard_active_boss = false
var safeguard_active_normal = false
var last_damage_time = 0.0
var damage_burst_counter = 0.0
var safeguard_cooldown = 0.0

# FPS Optimization
var cached_boss = null # Cache boss reference
var boss_check_timer = 0.0 # Only check for boss every 0.5s
var last_emitted_hp = 100.0 # Track last emitted HP to avoid spam
var scale_base = Vector2(1, 1) # Track base scale for animations


func _ready():
	# Store base scale for animations
	scale_base = sprite.scale
	_add_key_mapping("ui_up", KEY_W)
	_add_key_mapping("ui_down", KEY_S)
	_add_key_mapping("ui_left", KEY_A)
	_add_key_mapping("ui_right", KEY_D)
	_add_key_mapping("ui_accept", KEY_SPACE)

	add_to_group("player")

	# Initial UI update
	emit_signal("health_changed", current_hp, max_hp)
	emit_signal("health_changed", current_hp, max_hp)
	emit_signal("xp_changed", xp, max_xp, level)

	# === DEFAULT ZOOM SETTING ===
	# User Request: "tăng tâm nhìn nhân vật tí" -> Zoom OUT (smaller number means closer, larger means farther? No, usually <1 is zoom out in some engines, but in Godot Camera2D Zoom: (1, 1) is default. (2, 2) is 2x ZOOM IN.
	# Wait. "Zoom in game screen (Too wide)" -> I set it to (1.25, 1.25). This is 25% larger/closer.
	# Now they say "tăng tâm nhìn" -> Increase Vision -> See MORE -> Zoom OUT.

	scale_base = sprite.scale # Re-capture in case texture change affected it implicitly?
	# No, texture change doesn't change scale property usually.
	# But Char selection might have changed scale.
	pass
	# So I should reduce the zoom value back towards 1.0 or lower.
	# If current is 1.25 and they want "a bit more vision", let's try 1.1.
	if has_node("Camera2D"):
		$Camera2D.zoom = Vector2(1.0 , 1.0)

	# Load Fusion Manager
	fusion_manager = load("res://fusion_manager.gd").new()
	add_child(fusion_manager)

	# Apply Shop Upgrades
	# Damage: +3% per level
	if Global.shop_dmg_level > 0:
		damage_output_multiplier += (Global.shop_dmg_level * 0.03)

	# Defense: -5% incoming damage per level (Multiplicative)
	if Global.shop_hp_level > 0:
		damage_reduction_multiplier *= pow(0.95, Global.shop_hp_level)

	# Apply Potions (Bought this run)
	if Global.active_potions["damage"]:
		damage_output_multiplier += 0.20 # +20% Damage
	if Global.active_potions["speed"]:
		SPEED *= 1.20 # +20% Speed (Stacks with character bonus)
		upgrade_levels["speed"] += 1 # visual effect only? No, real stat
	if Global.active_potions["xp"]:
		# Applied in gain_xp
		pass

	# Apply Character Selection

	# Apply Character Selection
	var char_name = Global.selected_character
	var texture_path = "res://" + char_name + ".png"
	if ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)

	match char_name:
		"speed":
			SPEED *= 1.20 # +20% movement speed
		"nhin":
			if has_node("Camera2D"):
				# Tăng tầm nhìn lên 30% (Zoom out)
				# Current is 1.1. vision +30% means seeing 30% more area -> Zoom value smaller.
				# 1.1 / 1.3 approx 0.85
				$Camera2D.zoom /= 1.3
		"dien":
			# Tất cả lá bài đều lv 2 (Level 1 in code)
			# Apply each upgrade once
			for type in upgrade_levels.keys():
				apply_upgrade(type)
		"admin":
			# Increase Size
			sprite.scale = Vector2(0.2, 0.2)
			scale_base = Vector2(0.2, 0.2) # Update Scale Base

			# Tất cả skill lv 6
			for type in upgrade_levels.keys():
				upgrade_levels[type] = 6
				# Apply effects if needed
				if type == "hp":
					max_hp += max_hp * 0.10 * 6
					current_hp = max_hp
					damage_reduction_multiplier *= pow(0.95, 6)
				elif type == "damage":
					damage_output_multiplier += 0.10 * 6
				elif type == "speed":
					attack_cooldown = base_attack_cooldown * pow(0.9, 6)
				# Other stats handled dynamically or in process
			create_boss_arrow() # Re-init if needed
		"megumi":
			# Spawn Clone deferred
			call_deferred("spawn_megumi_clone")

	# Initialize Boss Arrow
	create_boss_arrow()

func spawn_megumi_clone():
	var clone_script = load("res://megumi_clone.gd")
	var clone = clone_script.new()
	clone.global_position = global_position + Vector2(50, 0)
	clone.setup(self)
	get_parent().add_child(clone)

func create_boss_arrow():
	boss_arrow = Polygon2D.new()
	boss_arrow.polygon = PackedVector2Array([
		Vector2(0, -10),
		Vector2(0, 10),
		Vector2(20, 0)
	])
	boss_arrow.color = Color(1, 0, 0) # Red Arrow
	boss_arrow.visible = false
	add_child(boss_arrow)

func trigger_screen_shake(intensity: float = 10.0):
	shake_intensity = intensity

func _physics_process(delta):
	# Screen Shake logic
	if shake_intensity > 0:
		if camera:
			camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_intensity
		shake_intensity = lerp(shake_intensity, 0.0, shake_decay * delta)
		if shake_intensity < 0.1:
			shake_intensity = 0.0
			if camera:
				camera.offset = Vector2.ZERO
	# Update Boss Arrow (Optimized - only check every 0.5s)
	boss_check_timer -= delta
	if boss_check_timer <= 0:
		update_boss_arrow()
		boss_check_timer = 0.5 # Check every 0.5 seconds instead of every frame

	# Dash Input & Logic
	if dash_cooldown > 0:
		dash_cooldown -= delta

	if dash_duration > 0:
		dash_duration -= delta
		if dash_duration <= 0:
			is_dashing = false
			# Provide i-frames or restore collision logic here if desired

	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if Input.is_action_just_pressed("ui_accept") and dash_cooldown <= 0 and direction != Vector2.ZERO:
		is_dashing = true
		dash_duration = 0.15  # Short, quick dash
		dash_cooldown = 1.0   # 1 second cooldown

		# Visual effect: spawn a clone trailing behind (optional ghost effect base)
		var ghost = Sprite2D.new()
		ghost.texture = sprite.texture
		ghost.global_position = global_position
		ghost.scale = sprite.scale
		ghost.flip_h = sprite.flip_h
		ghost.modulate = Color(1, 1, 1, 0.5)
		get_parent().add_child(ghost)

		var tw = create_tween()
		tw.tween_property(ghost, "modulate:a", 0.0, 0.3)
		tw.tween_callback(ghost.queue_free)

	# Movement
	if direction:
		var current_speed = SPEED
		if is_dashing:
			current_speed *= dash_speed_multiplier

		velocity = direction * current_speed
		if direction.x != 0:
			sprite.flip_h = direction.x < 0
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	# Auto Attack
	attack_timer -= delta
	if attack_timer <= 0:
		shoot_nearest_enemy()
		attack_timer = attack_cooldown

	process_gojo_skill(delta)
	process_sukuna_skill(delta)

	# Process Magnet
	if magnet_active:
		magnet_timer -= delta
		if magnet_timer <= 0:
			magnet_active = false
	# Process Magnet
	if magnet_active:
		magnet_timer -= delta
		if magnet_timer <= 0:
			magnet_active = false
			# UI could show "Magnet Ended"

	# Process Safeguard Timers
	if safeguard_cooldown > 0:
		safeguard_cooldown -= delta
	else:
		# Reset burst counter if time passed without damage (1 second window)
		if Time.get_ticks_msec() / 1000.0 - last_damage_time > 1.0:
			damage_burst_counter = 0.0

	# Regen Logic (Optimized - only emit signal when HP changes significantly)
	if hp_regen > 0:
		var heal = hp_regen * delta
		current_hp = min(current_hp + heal, max_hp)
		# Only emit signal if HP changed by more than 1.0 to reduce signal spam
		if abs(current_hp - last_emitted_hp) >= 1.0:
			emit_signal("health_changed", current_hp, max_hp)
			last_emitted_hp = current_hp

	_process_visual_polish(delta)

func _process_visual_polish(delta):
	# 1. Tilt based on movement
	var target_rot = velocity.x * 0.0005 # Slight tilt
	rotation = lerp(rotation, target_rot, 10 * delta)

	# 2. Squash & Stretch (Bobbing) - Re-enabled Relative
	var speed_fraction = velocity.length() / SPEED
	if speed_fraction > 0.1:
		var time = Time.get_ticks_msec() / 100.0
		var bob = sin(time) * 0.05 * speed_fraction
		# Apply relative to base scale!
		sprite.scale = scale_base * Vector2(1.0 + bob, 1.0 - bob)
	else:
		sprite.scale = lerp(sprite.scale, scale_base, 10 * delta)

	# 3. Ghost Trail (Simple)
	if velocity.length() > SPEED * 0.8:
		# Could spawn ghost sprite here, but for now simple scale stretch is enough
		pass

func update_boss_arrow():
	# Use cached boss if still valid
	if is_instance_valid(cached_boss):
		boss_arrow.visible = true
		var dir = global_position.direction_to(cached_boss.global_position)
		boss_arrow.position = dir * 100.0
		boss_arrow.rotation = dir.angle()
		return

	# Otherwise, find boss and cache it
	var bosses = GlobalUtils.get_group(self, "boss")
	if bosses.size() > 0:
		cached_boss = bosses[0] # Cache the boss
		if is_instance_valid(cached_boss):
			boss_arrow.visible = true
			var dir = global_position.direction_to(cached_boss.global_position)
			# Radius 100 around player
			boss_arrow.position = dir * 100.0
			boss_arrow.rotation = dir.angle()
		else:
			boss_arrow.visible = false
			cached_boss = null
	else:
		boss_arrow.visible = false
		cached_boss = null




func process_sukuna_skill(delta):
	var s_level = upgrade_levels["sukuna"]
	if s_level == 0:
		return

	# Level 6 Logic: If slash exists, do nothing (it's infinite). If lost, respawn.
	if s_level >= 6:
		if not is_instance_valid(active_sukuna_slash):
			shoot_sukuna_slash()
		return

	sukuna_timer -= delta
	if sukuna_timer <= 0:
		shoot_sukuna_slash()
		# Cooldown reduced by speed upgrades
		var cd_mult = pow(0.9, upgrade_levels["speed"])
		sukuna_timer = sukuna_base_cooldown * cd_mult

func shoot_sukuna_slash():
	var s_level = upgrade_levels["sukuna"]

	if s_level >= 6:
		# Infinite Slash Mode
		var slash = sukuna_slash_scene.instantiate()
		slash.is_infinite_level6 = true
		slash.max_hp_percent_damage = 0.40
		slash.speed = 1800.0 # Faster speed (Buff)
		slash.global_position = global_position

		# Initial direction: Aim at nearest or random
		var enemy = find_nearest_enemy()
		if enemy:
			slash.velocity = global_position.direction_to(enemy.global_position) * slash.speed
		else:
			slash.velocity = Vector2(1, 0).rotated(randf() * 2 * PI) * slash.speed

		get_parent().call_deferred("add_child", slash)
		active_sukuna_slash = slash
		trigger_screen_shake(15.0) # Massive skill shake
		return # Stop execution here, don't run normal loop

	var count = s_level # 1 to 5 slashes based on level

	# Find target
	var enemies = GlobalUtils.get_group(self, "enemies")

	# Sort enemies by distance
	enemies.sort_custom(func(a, b):
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)

	var targets = []

	if enemies.size() > 0:
		# Assign unique targets first
		for i in range(count):
			if i < enemies.size():
				targets.append(enemies[i])
			else:
				# If more slashes than enemies, cycle through them again or random
				targets.append(enemies[i % enemies.size()])
	else:
		# No enemies - Aim random
		pass

		# No enemies - Aim random
		pass

	var _base_dmg = 30 + (upgrade_levels["damage"] * 5) # Base scaling kept for consistency? Or should it be purely multiplier?
	# User request: "sát thương mỗi lận chọn là tăng 5% tất cả".
	# If we keep the old +5 flat per level AND add 5% multiplier, it's double dipping.
	# But user said "sát thương mỗi lận chọn là tăng 5%". This usually replaces the old flat system.
	# We will use a FIXED base + multiplier.

	# Combine multipliers: Base (Upgrade) + Bonus (Cursed)
	var total_multiplier = damage_output_multiplier + damage_multiplier
	var dmg = 30.0 * total_multiplier

	# Calculate Lifetime based on Range Upgrade
	# Base 1.0s * 1500 = 1500px range.
	# Upgrade: +100 range per level.
	# Lifetime increase = (Level * 100) / speed
	var slash_speed = 1500.0
	var extra_range = upgrade_levels["range"] * 100.0
	var lifetime = 0.6 + (extra_range / slash_speed)

	# Helper for no-target spread
	var base_random_dir = Vector2(randf_range(-1,1), randf_range(-1,1)).normalized()
	if enemies.size() > 0:
		base_random_dir = global_position.direction_to(enemies[0].global_position)

	for i in range(count):
		var slash = sukuna_slash_scene.instantiate()

		# Crit Logic
		var is_crit = (randf() < crit_chance)
		var final_dmg = dmg
		if is_crit:
			final_dmg *= crit_damage

		slash.damage = final_dmg
		slash.is_critical = is_crit

		slash.lifetime = lifetime
		slash.global_position = global_position

		var target_enemy = null
		var default_dir = base_random_dir

		if i < targets.size():
			target_enemy = targets[i]

		# If we have a target, aim at it
		if target_enemy:
			default_dir = global_position.direction_to(target_enemy.global_position)
			slash.target = target_enemy
		else:
			# If no target (count > enemies case or no enemies), spread out
			var spread_angle = (i - (count - 1) / 2.0) * 0.3
			default_dir = base_random_dir.rotated(spread_angle)
			# slash.target remains null, it will fly straight

		slash.velocity = default_dir * slash.speed

		get_parent().call_deferred("add_child", slash)


func process_gojo_skill(delta):
	if upgrade_levels["gojo"] == 0:
		return

	var speed_maxed = upgrade_levels["speed"] >= max_upgrade_level

	if speed_maxed:
		# Permanent active
		if not gojo_active:
			spawn_gojo_orbs()
			gojo_active = true
	else:
		gojo_timer -= delta
		if gojo_active:
			if gojo_timer <= 0:
				despawn_gojo_orbs()
				gojo_active = false
				gojo_timer = gojo_cooldown_duration
		else:
			if gojo_timer <= 0:
				spawn_gojo_orbs()
				gojo_active = true
				gojo_timer = gojo_active_duration

	# Rotate Orbs
	if gojo_active and gojo_orbs_node:
		var base_rot_speed = 2.0
		if upgrade_levels["gojo"] >= 6:
			base_rot_speed = 5.0 # Super fast rotation

		var rot_speed = base_rot_speed + (upgrade_levels["speed"] * 0.2) # Speed affects rot speed
		gojo_orbs_node.rotation += rot_speed * delta

func spawn_gojo_orbs():
	if gojo_orbs_node:
		gojo_orbs_node.queue_free()

	gojo_orbs_node = Node2D.new()
	add_child(gojo_orbs_node)

	var g_level = upgrade_levels["gojo"]
	var count = g_level
	if g_level >= 6:
		count = 6 # Cap count at 6? Or let is spawn 6.

	var radius = 100 + (upgrade_levels["range"] * 20) # Range affects radius

	# REBALANCED: Gojo Base Damage 20 -> 50
	var dmg = 50.0 * damage_output_multiplier

	var is_purple = false
	if g_level >= 6:
		is_purple = true
		dmg *= 3.5 # Nerfed from 5x to 3.5x

	for i in range(count):
		var orb = rotating_orb_scene.instantiate()
		orb.damage = dmg
		orb.position = Vector2(cos(i * 2 * PI / count), sin(i * 2 * PI / count)) * radius

		if is_purple:
			# Visuals for Level 6
			orb.modulate = Color(0.6, 0.0, 1.0) # Purple
			orb.scale = Vector2(1.5, 1.5) # Bigger

		# Crit Logic for Orbs (Snapshot per spawn)
		var is_crit = (randf() < crit_chance)
		var final_dmg = dmg
		if is_crit:
			final_dmg *= crit_damage

		orb.damage = final_dmg
		orb.is_critical = is_crit

		gojo_orbs_node.add_child(orb)

func despawn_gojo_orbs():
	if gojo_orbs_node:
		gojo_orbs_node.queue_free()
		gojo_orbs_node = null

func shoot_nearest_enemy():
	var enemies = GlobalUtils.get_group(self, "enemies")
	if enemies.size() > 0:
		var nearest = null
		var min_dist = INF

		for enemy in enemies:
			var total_range = attack_range + bullet_range
			var dist = global_position.distance_to(enemy.global_position)
			if dist < min_dist and dist <= total_range:
				nearest = enemy
				min_dist = dist

		if nearest == null:
			return

		# Standard Fire OR Burst Fire
		var bullet_count = 1 + upgrade_levels["bullet_plus"]

		# User requested specific sequential burst: "fire 1, then 2... then wait 2s"
		# This means the attack_timer handles the "wait 2s".
		# We just need to fire the burst sequence here.

		fire_burst(bullet_count, nearest)

func fire_burst(count, target):
	for i in range(count):
		if not is_instance_valid(target):
			# If target died mid-burst, try to find new one or stop
			target = find_nearest_enemy()
			if not target:
				return


		var bullet
		var is_crit = (randf() < crit_chance)
		var total_multiplier = damage_output_multiplier + damage_multiplier
		var damage_val = attack_damage * total_multiplier

		# Apply Crit
		var is_black_flash = false
		if is_crit:
			damage_val *= crit_damage
			# 10% chance for a Black Flash on Critical Hits!
			if randf() < 0.1:
				is_black_flash = true
				damage_val *= 2.5 # Massive damage
				trigger_screen_shake(12.0)

		if i == 0 and upgrade_levels["bullet_plus"] == 6:
			bullet = vortex_bullet_scene.instantiate()
			# Increase base damage for vortex if needed, but script multiplies it by 5 on explosion
			bullet.damage = damage_val
			bullet.is_critical = is_crit # Assign property
		else:
			bullet = bullet_scene.instantiate()
			bullet.damage = damage_val
			bullet.is_critical = is_crit

		if is_black_flash:
			bullet.modulate = Color(0.1, 0.1, 0.1) # Dark color
			bullet.scale *= 2.5 # Huge bullet

		bullet.global_position = global_position
		bullet.direction = global_position.direction_to(target.global_position)
		get_parent().add_child(bullet)

		if is_black_flash:
			var txt = floating_text_scene.instantiate()
			txt.text = "HẮC THIỂM!"
			txt.setup(0, true)
			txt.modulate = Color(0, 0, 0)
			txt.scale *= 2.0
			txt.global_position = global_position + Vector2(0, -60)
			get_parent().add_child(txt)

		# Wait before next shot
		if i < count - 1:
			await get_tree().create_timer(0.2).timeout

func find_nearest_enemy():
	var enemies = GlobalUtils.get_group(self, "enemies")
	var nearest = null
	var min_dist = INF
	for enemy in enemies:
		var total_range = attack_range + bullet_range
		var dist = global_position.distance_to(enemy.global_position)
		if dist < min_dist and dist <= total_range:
			nearest = enemy
			min_dist = dist
	return nearest

func gain_xp(amount):
	# Apply XP Boost Multiplier (upgrade_levels["xp_boost"] * 0.12)
	var multiplier = 1.0 + (upgrade_levels["xp_boost"] * 0.12)
	if Global.active_potions["xp"]:
		multiplier += 0.28 # +28% XP
	xp += amount * multiplier

	if xp >= max_xp:
		level_up()
	emit_signal("xp_changed", xp, max_xp, level)

func gain_boss_xp(base_amount):
	# Calculate Total Bonus Percent first
	var bonus_percent = (upgrade_levels["xp_boost"] * 0.12)
	if Global.active_potions["xp"]:
		bonus_percent += 0.28

	# Nerf: Reduce the total bonus by 40% (Retain 60%)
	# "trừ đi 40% của tổng đó" => 60% of the bonus effectiveness
	var nerfed_bonus = bonus_percent * 0.60

	var final_multiplier = 1.0 + nerfed_bonus
	var final_xp = base_amount * final_multiplier

	xp += final_xp

	if xp >= max_xp:
		level_up()
	emit_signal("xp_changed", xp, max_xp, level)

func apply_upgrade(type):
	if type == "hp" or type == "damage" or type == "xp_boost" or type == "crit":
		# Allow unlimited logic
		pass
	elif type == "bullet_plus" or type == "gojo" or type == "rika" or type == "sukuna":
		if upgrade_levels[type] >= 6: # Max level 6
			if type == "rika" and upgrade_levels[type] >= 6: return # Now level 6 is Max for Rika too
			if type != "rika" and upgrade_levels[type] >= 6: return


	elif upgrade_levels[type] >= max_upgrade_level:
		return

	upgrade_levels[type] += 1
	var lvl = upgrade_levels[type]

	match type:
		"speed":
			# Reduce cooldown by 10% each level
			attack_cooldown = base_attack_cooldown * pow(0.9, lvl)
		"damage":
			# "tăng 10% tất cả những thứ gây sát thương"
			damage_output_multiplier += 0.10
			# No longer increasing attack_damage base flatly
		"hp":
			# "cộng 10% của máu hiện tại" (Max HP)
			var gain = max_hp * 0.10
			max_hp += gain
			current_hp += gain # Heal the gained amount

			# "giảm 5% sát thương nhận phải" of current HP logic?
			# Implemented as multiplicative damage reduction for unlimited scaling safety
			damage_reduction_multiplier *= 0.95

			# Buff Rika Damage
			rika_bonus_damage_percent += 0.13

			emit_signal("health_changed", current_hp, max_hp)
		"range":
			# Increase range by 50
			attack_range = 500.0 + (lvl * 100.0)
		"gojo":
			# Just update, process loop handles spawn
			if gojo_active:
				spawn_gojo_orbs() # Refresh (e.g. add new orb count immed)
		"sukuna":
			# Sukuna upgrade
			pass
		"bullet_plus":
			# Handled in shoot logic.
			# User: "wait 2 seconds then shoot again" -> This is a heavy recoil penalty.
			# Rebalance: Increase cooldown by 50% instead of fixed 2s, to allow speed scaling still.
			var _penalty_factor = 1.5
			# Apply penalty to BASE, so speed upgrades still reduce it normally from that new base
			# But here we are modifying 'attack_cooldown' which is dynamic.
			# Let's just set a flag or handle it in cooldown calculation.
			# Actually, simplest is to reset cooldown to a "Penalty Base" when this is upgraded.
			# Let's say adding a bullet increases base recoil.
			base_attack_cooldown += 0.05 # Rebalanced: Reduced from 0.3 to 0.05 to avoid DPS loss

			# Recalculate current cooldown based on Speed level
			var speed_lvl = upgrade_levels["speed"]
			attack_cooldown = base_attack_cooldown * pow(0.9, speed_lvl)
		"rika":
			update_rika_minions()
		"crit":
			crit_chance += 0.05 # +5% Chance
		"crit":
			crit_chance += 0.05 # +5% Chance
			crit_damage += 0.20 # +20% Damage
			# Cap chance? Let's cap at 100% implicitly by logic, but no hard cap variable needed yet.

	# Verify stats update for minions on any upgrade
	if type == "damage" or type == "hp":
		for minion in rika_minions:
			if is_instance_valid(minion):
				minion.update_stats_snapshot()

	# Check for Fusions
	if fusion_manager:
		var available = fusion_manager.check_available_fusions(upgrade_levels)
		for fusion_id in available:
			# Auto Activate for now (since user didn't ask for a selection UI for this specifically, or implicit?)
			# "Modify ui.gd to show Fusion Cards" -> Oh, we need UI.
			# Let's add it to UI logic. If fusion available, show Card NEXT level up?
			# Or trigger immediately?
			# Request says: "Fusion Skill System (End-Game Power)... Modify ui.gd to show Fusion Cards".
			# This implies they are selected like upgrades.
			# So: Don't activate here. Just know they are unlocked.
			pass
			# Actually, `ui.gd` `show_levelup_options` handles card generation.
			# We need to tell UI about fusions.
			# Fusion Manager `check_available_fusions` returns list.
			# UI should call this when generating cards.


	# Removed: get_tree().paused = false - Controlled by UI now for consecutive level ups

func update_rika_minions():
	var r_level = upgrade_levels["rika"]
	var target_count = r_level
	if r_level >= 6:
		target_count = 1 # Level 6: Only 1 Queen Rika
	elif target_count > 5:
		target_count = 5


	# Clean up invalid minions
	for i in range(rika_minions.size() - 1, -1, -1):
		if not is_instance_valid(rika_minions[i]):
			rika_minions.remove_at(i)

	# Spawn required amount
	var current_count = rika_minions.size()
	if current_count < target_count:
		var needed = target_count - current_count
		for i in range(needed):
			var r = rika_scene.instantiate()
			# Pass level 6 flag if applicable.
			var is_lvl6 = (level >= 6)
			r.setup(self, is_lvl6)
			r.global_position = global_position + Vector2(randf_range(-50,50), randf_range(-50,50))
			get_parent().call_deferred("add_child", r)
			rika_minions.append(r)
	elif current_count > target_count:
		# Remove excess for Level 6 transition (5 -> 1)
		var excess = current_count - target_count
		for i in range(excess):
			var r = rika_minions.pop_back()
			if is_instance_valid(r):
				r.queue_free()


	# Update all stats (and level 6 status for existing ones)
	for minion in rika_minions:
		if is_instance_valid(minion):
			var is_lvl6 = (r_level >= 6)
			# Re-setup to update Level 6 status
			minion.setup(self, is_lvl6)
			minion.update_stats_snapshot()



func level_up():
	level += 1
	xp = xp - max_xp
	max_xp = int(max_xp * 1.2)
	# Emit signal again just in case there is overflow
	emit_signal("xp_changed", xp, max_xp, level)

	# Trigger UI
	get_parent().ui.show_levelup_options()
	get_tree().paused = true

@onready var floating_text_scene = preload("res://floating_text.tscn")
func take_damage(amount, is_critical = false):
	if Global.selected_character == "admin":
		# 40% Dodge
		if randf() < 0.4:
			# Teleport small distance left/right
			var offset = 100.0
			if randf() > 0.5: offset = -100.0
			global_position.x += offset
			# Show "DODGE" text? Optional.
			return

	# Apply percentage reduction (Upgrades) * Penalty (Cursed Items)
	var final_damage = amount * damage_reduction_multiplier * damage_taken_multiplier

	# Optional: Apply "flat reduction based on HP" interpretation if strictly needed?
	# "giảm 5% sát thương nhận phải của máu hiện tại"
	# User might mean: Damage Reduced = 5% of Current HP?
	# That would be: final_damage -= (current_hp * (0.05 * upgrade_levels["hp"]))
	# IF user complains about not being tanky enough, switch to that.
	# For now, multiplicative % reduction is safest for "unlimited levels".

	# === Safeguard Logic ===
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_damage_time < 1.0:
		damage_burst_counter += final_damage
	else:
		damage_burst_counter = final_damage # Start new burst count
	last_damage_time = now

	# Check threshold (e.g. 50% HP or just big visible chunk in 1 second)
	# User said: "rút quá nhanh chưa tới 1 giây"
	# Let's say if damage taken in < 1s exceeds 30% of MAX HP.
	if safeguard_cooldown <= 0 and damage_burst_counter > max_hp * 0.3:
		trigger_safeguard()

	current_hp -= final_damage
	if final_damage > 0:
		trigger_screen_shake(min(final_damage * 0.5, 20.0))  # Cap shake intensity at 20

	if current_hp < 0:
		current_hp = 0
		# Game Over logic here later
		# Game Over logic
		if "game_time" in get_parent():
			Global.check_new_record(get_parent().game_time)

		get_tree().change_scene_to_file("res://menu.tscn")

	emit_signal("health_changed", current_hp, max_hp)

	# Show damage number on player
	var txt = floating_text_scene.instantiate()
	txt.setup(final_damage, is_critical)
	txt.global_position = global_position + Vector2(randf_range(-20,20), -50)
	txt.modulate = Color(1, 0.3, 0.3)
	get_parent().add_child(txt)

func _add_key_mapping(action_name, key_code):
	if not InputMap.has_action(action_name):
		return
	var events = InputMap.action_get_events(action_name)
	var has_key = false
	for event in events:
		if event is InputEventKey and event.keycode == key_code:
			has_key = true
			break
	if not has_key:
		var new_event = InputEventKey.new()
		new_event.keycode = key_code
		InputMap.action_add_event(action_name, new_event)

func trigger_safeguard():
	safeguard_cooldown = 2.0
	Global.monster_buff_next = false # Reset any pending buff

	# Knockback all enemies
	var enemies = GlobalUtils.get_group(self, "enemies")
	for e in enemies:
		var dir = global_position.direction_to(e.global_position)
		e.position += dir * 300 # Push 300px
		if e.has_method("stun"):
			e.stun(2.0)

	# Floating Text
	var txt = floating_text_scene.instantiate()
	txt.text = "SAFEGUARD ACTIVATED!"
	txt.setup(0, true)
	txt.modulate = Color(0, 1, 1) # Cyan
	txt.scale *= 2.0
	txt.global_position = global_position
	get_parent().add_child(txt)

func activate_magnet():
	magnet_active = true

	# Find ALL XP Orbs in the scene and pull them
	# Orbs should be in group "xp_orbs"
	var orbs = get_tree().get_nodes_in_group("xp_orbs")
	for orb in orbs:
		orb.collected = true
		orb.target = self
		# Boost speed massively for instant feeling
		orb.speed = 1200.0

	# End magnet flag after short duration (just for range pickup logic fallback)
	await get_tree().create_timer(1.0).timeout
	magnet_active = false

func clear_cached_boss():
	cached_boss = null
	boss_arrow.visible = false
