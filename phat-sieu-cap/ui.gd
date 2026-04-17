extends CanvasLayer

@onready var hp_bar = $MarginContainer/VBoxContainer/HPBar
@onready var xp_bar = $MarginContainer/VBoxContainer/XPBar
@onready var level_label = $MarginContainer/VBoxContainer/XPBar/LevelLabel

var timer_label = null
var card_container = null
var boss_hp_bar_container = null
var boss_hp_bar = null
var boss_name_label = null
var active_boss_ref = null
var boss_intro_overlay = null

func _ready():
	if has_node("MarginContainer/VBoxContainer/TimerLabel"):
		timer_label = $MarginContainer/VBoxContainer/TimerLabel
	else:
		var lbl = Label.new()
		lbl.name = "TimerLabel"
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		$MarginContainer/VBoxContainer.add_child(lbl)
		timer_label = lbl

	var comment_lbl = Label.new()
	comment_lbl.set_script(load("res://comment_system.gd"))
	add_child(comment_lbl)

	var mobile_ctrl = load("res://mobile_controls.gd").new()
	add_child(mobile_ctrl)

	var p_btn = Button.new()
	p_btn.text = "||"
	p_btn.tooltip_text = "Tạm dừng"
	p_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p_btn.add_theme_font_size_override("font_size", 24)
	p_btn.custom_minimum_size = Vector2(50, 50)
	p_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	p_btn.anchor_left = 1.0
	p_btn.anchor_top = 0.0
	p_btn.anchor_right = 1.0
	p_btn.anchor_bottom = 0.0
	p_btn.offset_left = -70
	p_btn.offset_top = 20
	p_btn.offset_right = -20
	p_btn.offset_bottom = 70
	p_btn.pressed.connect(_on_pause_clicked)
	add_child(p_btn)

	_style_main_ui()

func _style_main_ui():
	if hp_bar:
		var fill = StyleBoxFlat.new()
		fill.bg_color = Color(0.0, 1.0, 0.4, 1.0)
		fill.border_width_bottom = 2
		fill.border_color = Color(0.8, 1.0, 0.8)
		fill.set_corner_radius_all(4)
		hp_bar.add_theme_stylebox_override("fill", fill)

		var bg = StyleBoxFlat.new()
		bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
		bg.set_corner_radius_all(4)
		hp_bar.add_theme_stylebox_override("background", bg)

func _on_pause_clicked():
	var pause_menu = get_tree().current_scene.get_node_or_null("PauseMenu")
	if not pause_menu:
		pause_menu = get_parent().get_node_or_null("PauseMenu")

	if pause_menu:
		pause_menu.pause()
	else:
		var world = get_parent()
		if world.has_method("find_child"):
			var p = world.find_child("PauseMenu", true, false)
			if p: p.pause()

func show_safeguard_warning(text):
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 40)
	lbl.add_theme_color_override("font_color", Color(1, 0, 0.3))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.add_theme_color_override("outline_color", Color(0,0,0))
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	add_child(lbl)

	var tween = create_tween()
	tween.tween_property(lbl, "scale", Vector2(1.5, 1.5), 0.2).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.2)
	tween.tween_interval(2.0)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tween.tween_callback(lbl.queue_free)

func _process(_delta):
	if active_boss_ref and is_instance_valid(active_boss_ref) and boss_hp_bar:
		boss_hp_bar.value = active_boss_ref.current_hp
	elif active_boss_ref:
		hide_boss_health()

func play_boss_intro(boss_name, boss_subtitle, _camera_start_pos, _boss_pos):
	if boss_intro_overlay: boss_intro_overlay.queue_free()

	boss_intro_overlay = Control.new()
	boss_intro_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	boss_intro_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(boss_intro_overlay)

	# Cyberpunk Style Panel
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER) # We will manually animate position, but start CENTER-ish vertically
	# Start off-screen LEFT
	var screen_size = get_viewport().get_visible_rect().size
	# Adjusted Y to -250 to be higher up
	panel.position = Vector2(-800, screen_size.y / 2 - 250)
	panel.custom_minimum_size = Vector2(600, 200)
	boss_intro_overlay.add_child(panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.9) # Dark Blue/Black
	style.border_width_left = 10
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.0, 1.0, 1.0) # Cyan Neon
	style.set_corner_radius_all(0) # Sharp corners
	style.skew = Vector2(0.2, 0.0) # Slanted Look
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = boss_name.to_upper()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 56)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.0, 0.4)) # Neon Pink
	name_lbl.add_theme_constant_override("outline_size", 8)
	name_lbl.add_theme_color_override("outline_color", Color.BLACK)
	vbox.add_child(name_lbl)

	var sub_lbl = Label.new()
	sub_lbl.text = "/// " + boss_subtitle + " ///"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 28)
	sub_lbl.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0)) # Cyan
	vbox.add_child(sub_lbl)

	# Animation: Slide IN -> Hit -> Shake?
	var target_x = (screen_size.x - panel.size.x) / 2 # Center X

	var tw = create_tween().set_parallel(false) # Sequential
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	# Fast Slide In
	tw.tween_property(panel, "global_position:x", target_x, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# "Hit" effect (Shake)
	var shake_tw = create_tween().set_parallel(true)
	shake_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	shake_tw.tween_property(panel, "position:x", target_x + 20, 0.05).set_delay(0.6)
	shake_tw.tween_property(panel, "position:x", target_x - 10, 0.05).set_delay(0.65)
	shake_tw.tween_property(panel, "position:x", target_x, 0.05).set_delay(0.7)

	return tw

func close_boss_intro():
	if boss_intro_overlay:
		var tw = create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(boss_intro_overlay, "modulate:a", 0.0, 0.5)
		tw.tween_callback(boss_intro_overlay.queue_free)
		boss_intro_overlay = null

func setup_boss_health(boss):
	active_boss_ref = boss

	if not boss_hp_bar_container:
		create_boss_bar_ui()

	boss_hp_bar_container.visible = true
	boss_hp_bar.max_value = boss.max_hp
	boss_hp_bar.value = boss.current_hp

	var b_name = "BOSS"
	if "encounter_level" in boss:
		b_name = "TOJI FUSHIGURO"
		if boss.encounter_level >= 1:
			b_name += " (AWAKENED)"

	boss_name_label.text = b_name

func hide_boss_health():
	active_boss_ref = null
	if boss_hp_bar_container:
		boss_hp_bar_container.visible = false

func create_boss_bar_ui():
	boss_hp_bar_container = VBoxContainer.new()
	boss_hp_bar_container.custom_minimum_size = Vector2(600, 0)
	boss_hp_bar_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	boss_hp_bar_container.anchor_left = 0.2
	boss_hp_bar_container.anchor_right = 0.8
	boss_hp_bar_container.offset_top = 80
	add_child(boss_hp_bar_container)

	boss_name_label = Label.new()
	boss_name_label.text = "BOSS"
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_size_override("font_size", 24)
	boss_name_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	boss_name_label.add_theme_constant_override("outline_size", 4)
	boss_name_label.add_theme_color_override("outline_color", Color(0,0,0))
	boss_hp_bar_container.add_child(boss_name_label)

	boss_hp_bar = ProgressBar.new()
	boss_hp_bar.custom_minimum_size = Vector2(0, 25)
	boss_hp_bar.show_percentage = true

	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0, 0, 0.6)
	bg.border_width_left = 2
	bg.border_width_right = 2
	bg.border_width_top = 2
	bg.border_width_bottom = 2
	bg.border_color = Color(0.5, 0, 0, 1.0)
	boss_hp_bar.add_theme_stylebox_override("background", bg)

	var fill = StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.2, 0.2, 1.0)
	fill.set_corner_radius_all(2)
	boss_hp_bar.add_theme_stylebox_override("fill", fill)

	boss_hp_bar_container.add_child(boss_hp_bar)

func update_timer(time_sec):
	if not timer_label:
		return
	var m = int(time_sec) / 60
	var s = int(time_sec) % 60
	timer_label.text = "%02d:%02d" % [m, s]
	if m >= 10:
		timer_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))

func update_hp(current, max_val):
	hp_bar.max_value = max_val
	var tw = create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(hp_bar, "value", current, 0.5).set_trans(Tween.TRANS_SPRING)

	# Add a slight "shake" to the HP bar if damage was taken (current < old_value)
	if current < hp_bar.value:
		var target_x = hp_bar.position.x
		var shake_tw = create_tween()
		shake_tw.tween_property(hp_bar, "position:x", target_x + 5, 0.05)
		shake_tw.tween_property(hp_bar, "position:x", target_x - 5, 0.05)
		shake_tw.tween_property(hp_bar, "position:x", target_x, 0.05)

func update_xp(current, max_val, level):
	xp_bar.max_value = max_val
	var tw = create_tween()
	tw.tween_property(xp_bar, "value", current, 0.5).set_trans(Tween.TRANS_CUBIC)
	level_label.text = "LV " + str(level)

func show_cursed_popup(type, player):
	var popup = load("res://cursed_popup.tscn").instantiate()
	popup.setup(type)
	add_child(popup)
	get_tree().paused = true

	popup.selected.connect(func(accepted):
		get_tree().paused = false
		if accepted:
			_apply_cursed_effect(type, player)
	)

func _apply_cursed_effect(type, player):
	match type:
		"finger":
			player.damage_multiplier += 0.5
			player.max_hp *= 0.7
			player.current_hp = min(player.current_hp, player.max_hp)
			_spawn_ui_text(player, "Ngón Tay Sukuna: Sức Mạnh Tăng Đại!", Color(1, 0, 0))
		"eye":
			player.bullet_range += 200
			player.crit_chance += 0.20
			if "damage_taken_multiplier" in player:
				player.damage_taken_multiplier += 0.5
			else:
				player.max_hp *= 0.8
			_spawn_ui_text(player, "Lục Nhãn: Tầm Nhìn Thấu Suốt!", Color(0.3, 0.3, 1))
		"womb":
			player.hp_regen += 5
			player.SPEED *= 0.8
			_spawn_ui_text(player, "Chú Thai: Hồi Phục Bất Tử!", Color(0.3, 1, 0.3))

	player.emit_signal("health_changed", player.current_hp, player.max_hp)

func _spawn_ui_text(_player, text, color):
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_color_override("outline_color", Color.BLACK)
	lbl.position = Vector2(400, 200)
	add_child(lbl)
	var tw = create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0, -100), 2.0)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 2.0)
	tw.tween_callback(lbl.queue_free)

func show_levelup_options():
	if card_container:
		card_container.queue_free()

	card_container = Control.new()
	card_container.process_mode = Node.PROCESS_MODE_ALWAYS
	card_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(card_container)

	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_container.add_child(bg)

	var title = Label.new()
	title.text = "LEVEL UP!"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.offset_top = 50
	card_container.add_child(title)

	var t_tw = create_tween()
	t_tw.tween_property(title, "scale", Vector2(1.2, 1.2), 0.5).set_trans(Tween.TRANS_SINE)
	t_tw.tween_property(title, "scale", Vector2(1.0, 1.0), 0.5)

	var center_cont = CenterContainer.new()
	center_cont.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_container.add_child(center_cont)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 30)
	center_cont.add_child(hbox)

	var player = get_parent().get_node("Player")
	var upgrades = player.upgrade_levels
	var possible_types = []
	for type in upgrades:
		if type == "hp" or type == "damage" or type == "xp_boost" or type == "crit":
			possible_types.append(type)
		elif type == "bullet_plus" or type == "gojo" or type == "rika":
			if upgrades[type] < 6:
				possible_types.append(type)
		elif upgrades[type] < player.max_upgrade_level:
			possible_types.append(type)

	if possible_types.is_empty():
		possible_types.append("heal")

	var choices = []
	var rare_skills = []
	if upgrades.has("gojo") and upgrades["gojo"] < 6: rare_skills.append("gojo")
	if upgrades.has("sukuna") and upgrades["sukuna"] < 6: rare_skills.append("sukuna")
	if upgrades.has("bullet_plus") and upgrades["bullet_plus"] < 6: rare_skills.append("bullet_plus")
	if upgrades.has("rika") and upgrades["rika"] < 6: rare_skills.append("rika")

	var special_picked = false
	if not rare_skills.is_empty():
		if randf() < 0.3:
			var pick = rare_skills.pick_random()
			choices.append(pick)
			possible_types.erase(pick)
			special_picked = true

	var cards_to_pick = 3
	if special_picked:
		cards_to_pick = 2

	for i in range(cards_to_pick):
		if possible_types.is_empty():
			break
		var pick = possible_types.pick_random()
		choices.append(pick)
		possible_types.erase(pick)

	var fusion_pick = null
	if player.fusion_manager:
		var avail_fusions = player.fusion_manager.check_available_fusions(player.upgrade_levels)
		if not avail_fusions.is_empty():
			fusion_pick = avail_fusions[0]
			if choices.size() >= 3:
				choices.pop_back()
			choices.insert(0, "FUSION:" + fusion_pick)

	for type_raw in choices:
		var type = type_raw
		var is_fusion = false
		if type is String and type.begins_with("FUSION:"):
			is_fusion = true
			type = type.replace("FUSION:", "")

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(220, 320)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
		card_style.border_width_bottom = 4
		card_style.border_width_top = 2
		card_style.border_width_left = 2
		card_style.border_width_right = 2
		card_style.corner_radius_top_left = 10
		card_style.corner_radius_bottom_right = 10

		var card_title = ""
		var card_desc = ""
		var card_level = ""
		var border_color = Color.WHITE

		if is_fusion:
			var f_data = player.fusion_manager.fusions[type]
			card_title = f_data["name"]
			card_desc = f_data["desc"]
			card_level = "ULTIMATE"
			border_color = Color(1.0, 0.0, 1.0)
		elif type == "heal":
			card_title = "Hồi Phục"
			card_desc = "Hồi 50 HP ngay lập tức"
			card_level = ""
			border_color = Color(0.0, 1.0, 0.0)
		else:
			var current_lvl = upgrades[type]
			var next_lvl = current_lvl + 1
			card_level = "LV " + str(next_lvl)

			match type:
				"speed":
					card_title = "Tốc Độ"
					card_desc = "Tăng tốc độ đánh +10%"
					border_color = Color(0.0, 1.0, 1.0)
				"damage":
					card_title = "Sát Thương"
					card_desc = "Tăng 10% sát thương"
					border_color = Color(1.0, 0.2, 0.2)
				"hp":
					card_title = "Sinh Lực"
					card_desc = "Tăng 10% Máu + Kháng"
					border_color = Color(0.2, 1.0, 0.2)
				"range":
					card_title = "Tầm Xa"
					card_desc = "+100 Phạm vi tấn công"
					border_color = Color(1.0, 1.0, 0.0)
				"crit":
					card_title = "Chí Mạng"
					card_desc = "+5% Tỉ lệ, +20% Damage"
					border_color = Color(1.0, 0.5, 0.0)
				"xp_boost":
					card_title = "Thí Nghiệm"
					card_desc = "Tăng 12% XP"
					border_color = Color(0.8, 0.8, 0.8)
				"gojo":
					card_title = "Gojo Satoru"
					card_desc = "Cầu năng lượng hộ thể"
					if next_lvl == 6: card_desc = "MAX: Tử (Purple)!"
					border_color = Color(0.6, 0.0, 1.0)
				"sukuna":
					card_title = "Ryōmen Sukuna"
					card_desc = "Nhát chém không gian"
					if next_lvl == 6: card_desc = "MAX: Vô Hạn Trảm!"
					border_color = Color(1.0, 0.0, 0.4)
				"rika":
					card_title = "Rika Orimoto"
					card_desc = "Nguyền hồn bảo hộ"
					if next_lvl == 6: card_desc = "MAX: Nữ Hoàng Rika!"
					border_color = Color(0.6, 0.0, 0.0)
				"bullet_plus":
					card_title = "Vũ Khí Mới"
					card_desc = "Thêm nòng súng (+1 đạn)"
					if next_lvl == 6: card_desc = "MAX: Đạn Từ Trường!"
					border_color = Color(0.5, 0.5, 1.0)

		card_style.border_color = border_color
		btn.add_theme_stylebox_override("normal", card_style)
		btn.add_theme_stylebox_override("hover", card_style)
		btn.add_theme_stylebox_override("pressed", card_style)

		btn.text = card_title + "\n\n" + card_desc + "\n\n" + card_level
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", border_color)

		if is_fusion:
			btn.pressed.connect(_on_fusion_selected.bind(type, player))
		else:
			btn.pressed.connect(_on_card_selected.bind(type, player))

		hbox.add_child(btn)

		btn.pivot_offset = Vector2(110, 160)
		btn.scale = Vector2.ZERO
		var b_tw = create_tween()
		b_tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_delay(randf()*0.2)

func _on_fusion_selected(id, player):
	if player.fusion_manager:
		player.fusion_manager.activate_fusion(id, player)
	_close_levelup_ui(player)

func _close_levelup_ui(player):
	if card_container:
		var tw = create_tween()
		tw.tween_property(card_container, "modulate:a", 0.0, 0.2)
		tw.tween_callback(card_container.queue_free)

	if player.xp >= player.max_xp:
		player.level_up()
	else:
		get_tree().paused = false

func _on_card_selected(type, player):
	if type == "heal":
		player.current_hp = min(player.current_hp + 50, player.max_hp)
		player.emit_signal("health_changed", player.current_hp, player.max_hp)
	else:
		player.apply_upgrade(type)

	_close_levelup_ui(player)
