extends Control
class_name GachaSystem

# Signals
signal gacha_closed

# UI Elements
var panel: Panel
var wheel_container: Control
var wheel_rotation_node: Control
var arrow: Polygon2D
var start_btn: Button
var bet_label_container: HBoxContainer
var info_label: Label
var result_label: Label
var bet_amount = 0
var is_spinning = false

# Betting options
const BET_OPTIONS = [1, 2, 5, 20, 50]
var selected_bet_btn: Button = null

# Wheel Configuration
const SEGMENTS = 8
const SEGMENT_ANGLE = 360.0 / SEGMENTS
# Segment Types: 0: x50, 1: Loss, 2: x2, 3: Loss, 4: x2, 5: Loss, 6: x2, 7: Loss
# Result Multipliers: 0->50, 1->0, 2->2, 3->0, 4->2, 5->0, 6->2, 7->0
const SEGMENT_DATA = [
	{"text": "x50", "mult": 50, "color": Color(1, 0.84, 0)}, # Gold
	{"text": "Còn cái nịt", "mult": 0, "color": Color(0.5, 0.5, 0.5)}, # Gray
	{"text": "x2", "mult": 2, "color": Color(0.4, 0.8, 1)}, # Blue
	{"text": "Còn cái nịt", "mult": 0, "color": Color(0.5, 0.5, 0.5)},
	{"text": "x2", "mult": 2, "color": Color(0.4, 0.8, 1)},
	{"text": "Còn cái nịt", "mult": 0, "color": Color(0.5, 0.5, 0.5)},
	{"text": "x2", "mult": 2, "color": Color(0.4, 0.8, 1)},
	{"text": "Còn cái nịt", "mult": 0, "color": Color(0.5, 0.5, 0.5)}
]

# Audio (optional, generic placeholders if we had them)

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

	# Dim Background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Center Panel
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	panel = Panel.new()
	panel.custom_minimum_size = Vector2(800, 600)
	center.add_child(panel)

	setup_ui()

func setup_ui():
	# Panel Size - Back to 600 height to ensure it fits on standard screens
	panel.custom_minimum_size = Vector2(800, 600)

	# Title
	var title = Label.new()
	title.text = "GACHA MAY MẮN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.position = Vector2(0, 10)
	title.custom_minimum_size = Vector2(800, 40)
	panel.add_child(title)

	# Info / Rules
	info_label = Label.new()
	info_label.text = "Tỉ lệ: x2 (30%) | x50 (0.2%)"
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.position = Vector2(0, 50)
	info_label.custom_minimum_size = Vector2(800, 30)
	info_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	panel.add_child(info_label)

	# Wheel Container
	# Reduced size and moved up
	wheel_container = Control.new()
	wheel_container.custom_minimum_size = Vector2(320, 320)
	wheel_container.position = Vector2(240, 90) # (800-320)/2 = 240. Y=90
	panel.add_child(wheel_container)

	# Rotating part
	wheel_rotation_node = Control.new()
	wheel_rotation_node.position = Vector2(160, 160) # Center of 320
	wheel_container.add_child(wheel_rotation_node)

	# Draw segments
	var drawer = Node2D.new()
	drawer.set_script(load("res://wheel_drawer.gd"))
	# Scale back to normal/slight boost (drawer base radius 150 -> 1.1 * 150 = 165. Fits in 320)
	drawer.scale = Vector2(1.05, 1.05)
	wheel_rotation_node.add_child(drawer)

	# Labels on wheel
	var radius = 150 * 1.05
	for i in range(SEGMENTS):
		var angle_deg = i * SEGMENT_ANGLE
		var angle_rad = deg_to_rad(angle_deg)
		var text_pos = Vector2(cos(angle_rad), sin(angle_rad)) * radius * 0.70

		var lbl = Label.new()
		lbl.text = SEGMENT_DATA[i]["text"]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		var lbl_w = 120
		var lbl_h = 60
		lbl.custom_minimum_size = Vector2(lbl_w, lbl_h)
		lbl.size = Vector2(lbl_w, lbl_h)
		lbl.position = text_pos - Vector2(lbl_w/2, lbl_h/2)
		lbl.pivot_offset = Vector2(lbl_w/2, lbl_h/2)
		lbl.rotation = angle_rad + PI/2

		lbl.add_theme_color_override("font_color", Color.BLACK if (i == 0 or i%2==0) else Color.WHITE)
		lbl.add_theme_font_size_override("font_size", 16)
		wheel_rotation_node.add_child(lbl)

	# Arrow (Pointer)
	arrow = Polygon2D.new()
	arrow.polygon = PackedVector2Array([
		Vector2(-20, -10),
		Vector2(20, -10),
		Vector2(0, 40)
	])
	arrow.color = Color.RED
	# Wheel top relative to panel is: Y_container(90) + Y_center(160) - Radius(160) = 90.
	# Arrow at 80 overlaps top slightly.
	arrow.position = Vector2(400, 80)
	panel.add_child(arrow)

	# Result Label
	# Wheel bottom ~ 90 + 320 = 410.
	result_label = Label.new()
	result_label.text = ""
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 28)
	result_label.add_theme_color_override("font_color", Color.YELLOW)
	result_label.position = Vector2(0, 410)
	result_label.custom_minimum_size = Vector2(800, 40)
	result_label.visible = false
	panel.add_child(result_label)

	# Bet Buttons container
	var bet_vbox = VBoxContainer.new()
	bet_vbox.position = Vector2(200, 460)
	bet_vbox.custom_minimum_size = Vector2(400, 70)
	panel.add_child(bet_vbox)

	var bet_lbl = Label.new()
	bet_lbl.text = "Chọn mức cược:"
	bet_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bet_vbox.add_child(bet_lbl)

	bet_label_container = HBoxContainer.new()
	bet_label_container.alignment = BoxContainer.ALIGNMENT_CENTER
	bet_label_container.add_theme_constant_override("separation", 20)
	bet_vbox.add_child(bet_label_container)

	for amt in BET_OPTIONS:
		var btn = Button.new()
		btn.text = str(amt) + " xu"
		btn.custom_minimum_size = Vector2(60, 35)
		btn.toggle_mode = true
		btn.pressed.connect(func(): _on_bet_selected(amt, btn))
		bet_label_container.add_child(btn)

	# Start Button Composite
	var start_btn_container = Control.new()
	start_btn_container.custom_minimum_size = Vector2(200, 50)
	start_btn_container.position = Vector2(300, 535) # Near bottom of 600
	panel.add_child(start_btn_container)

	# 1. Background
	var start_bg = ColorRect.new()
	start_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_bg.color = Color(0.2, 0.6, 1.0)

	var shader = load("res://sparkle.gdshader")
	if shader:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("speed", 3.0)
		mat.set_shader_parameter("intensity", 0.5)
		start_bg.material = mat

	start_btn_container.add_child(start_bg)

	# 2. Border
	var border = ReferenceRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.border_color = Color.WHITE
	border.border_width = 2.0
	border.editor_only = false
	start_btn_container.add_child(border)

	# 3. Label
	var start_label = Label.new()
	start_label.text = "BẮT ĐẦU CƯỢC"
	start_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	start_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_label.add_theme_font_size_override("font_size", 20)
	start_label.add_theme_color_override("font_color", Color.WHITE)
	start_label.add_theme_constant_override("outline_size", 4)
	start_label.add_theme_color_override("font_outline_color", Color.BLACK)
	start_btn_container.add_child(start_label)

	# 4. Button
	start_btn = Button.new()
	start_btn.flat = true
	start_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_btn.text = ""
	start_btn_container.add_child(start_btn)
	start_btn.pressed.connect(_on_start_pressed)

	start_btn.set_meta("container", start_btn_container)
	start_btn.disabled = true
	start_btn_container.modulate = Color(0.5, 0.5, 0.5)

	# Close Button
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(760, 10)
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(close_gacha)
	panel.add_child(close_btn)



func open_gacha():
	visible = true
	# Reset state
	start_btn.disabled = true
	selected_bet_btn = null
	bet_amount = 0
	result_label.visible = false
	for child in bet_label_container.get_children():
		child.button_pressed = false

func close_gacha():
	if is_spinning: return # Can't close while spinning
	visible = false
	emit_signal("gacha_closed")

func _on_bet_selected(amount, btn):
	if is_spinning: return

	bet_amount = amount

	# Untoggle others
	for child in bet_label_container.get_children():
		if child != btn:
			child.button_pressed = false

	btn.button_pressed = true
	selected_bet_btn = btn

	var can_afford = Global.coins >= amount
	start_btn.disabled = not can_afford

	if start_btn.has_meta("container"):
		start_btn.get_meta("container").modulate = Color(1, 1, 1) if can_afford else Color(0.5, 0.5, 0.5)

func _on_start_pressed():
	if bet_amount > Global.coins:
		return

	Global.add_coins(-bet_amount)
	is_spinning = true
	start_btn.disabled = true
	if start_btn.has_meta("container"):
		start_btn.get_meta("container").modulate = Color(0.5, 0.5, 0.5)

	result_label.visible = false

	# Determine Result
	var rand = randf()
	var result_index = 0
	var fake_index = -1 # -1 means no teasing

	# 0.2% for x50 (Index 0)
	if rand < 0.002:
		result_index = 0
	# 30% for x2 (Indices 2, 4, 6)
	elif rand < 0.302:
		var options = [2, 4, 6]
		result_index = options.pick_random()
	else:
		# Loss (Indices 1, 3, 5, 7)
		# High chance to "Rig/Tease" (70%)
		if randf() < 0.7:
			# Pick a Prize to tease (0=x50, 2,4,6=x2)
			# Let's give x50 slightly higher weight for the "rage" factor?
			# Random pick:
			fake_index = [0, 2, 4, 6].pick_random()

			# Decide actual result (Must be a neighbor Loss)
			# Neighbors of i are i-1 and i+1.
			# Since Prizes are even (0,2,4,6), neighbors are always odd (Loss).
			var offset = 1 if randf() < 0.5 else -1
			result_index = fake_index + offset

			# Wrap indices
			if result_index < 0: result_index = 7
			if result_index > 7: result_index = 0

		else:
			# Just a normal loss
			var options = [1, 3, 5, 7]
			result_index = options.pick_random()

	spin_wheel(result_index, fake_index)

func spin_wheel(target_idx, fake_idx):
	var rounds = 5 + randi() % 3

	# Target Rotation Calculation
	# Rotation R makes Segment i appear at Arrow (-90).
	# R = -90 - (i * 45) + N*360
	var target_seg_deg = target_idx * SEGMENT_ANGLE
	var arrow_offset = -90.0
	var final_rot_deg = arrow_offset - target_seg_deg + (rounds * 360.0)

	# Randomize visual offset within the segment so it's not always centered
	var rand_offset = randf_range(-15, 15)
	final_rot_deg -= rand_offset

	var tween = create_tween()

	if fake_idx != -1:
		# TEASE MODE
		# We spin to fake_idx first, then slip to target_idx

		var fake_seg_deg = fake_idx * SEGMENT_ANGLE
		var fake_rot_deg = arrow_offset - fake_seg_deg + (rounds * 360.0)

		# Add a tiny offset to look convincing (centered on the fake prize)
		fake_rot_deg -= randf_range(-5, 5)

		# Spin to Fake (Slower end to heighten tension)
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(wheel_rotation_node, "rotation_degrees", fake_rot_deg, 4.5)

		# Pause for a split second (User thinks they won)
		tween.tween_interval(0.4)

		# SLIP to Real (The "Ouch" moment)
		# Fast snappy movement
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(wheel_rotation_node, "rotation_degrees", final_rot_deg, 0.6)

	else:
		# Standard Spin
		tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(wheel_rotation_node, "rotation_degrees", final_rot_deg, 4.0)

	tween.finished.connect(func(): _on_spin_finished(target_idx))



func _on_spin_finished(idx):
	is_spinning = false
	var mult = SEGMENT_DATA[idx]["mult"]
	var win_amount = bet_amount * mult

	if mult > 1:
		result_label.text = "BẠN THẮNG %d XU!" % win_amount
		result_label.add_theme_color_override("font_color", Color.GREEN)
		Global.add_coins(win_amount)
	else:
		result_label.text = "CÒN CÁI NỊT! CHÚC MAY MẮN LẦN SAU"
		result_label.add_theme_color_override("font_color", Color.RED)

	result_label.visible = true

	# Enable start button if enough coins
	if Global.coins >= bet_amount:
		start_btn.disabled = false
		if start_btn.has_meta("container"):
			start_btn.get_meta("container").modulate = Color(1, 1, 1)
	else:
		if selected_bet_btn:
			selected_bet_btn.button_pressed = false
			selected_bet_btn = null
		bet_amount = 0
		start_btn.disabled = true
		if start_btn.has_meta("container"):
			start_btn.get_meta("container").modulate = Color(0.5, 0.5, 0.5)
