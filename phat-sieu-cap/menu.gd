extends Control

@onready var play_btn = $VBoxContainer/PlayButton
@onready var exit_btn = $VBoxContainer/ExitButton

@onready var shop_ui_script = preload("res://shop_ui.gd")
var shop_ui_instance
@onready var cyber_shader = preload("res://cyber_grid.gdshader")

func _ready():
	_setup_cyberpunk_bg()

	# Connect signals
	play_btn.pressed.connect(_on_play_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)

	# Setup animations & Styles
	# Call deferred to ensure size is calculated for pivot
	call_deferred("setup_cyberpunk_button", play_btn, "START GAME")
	call_deferred("setup_cyberpunk_button", exit_btn, "EXIT SYSTEM")

	play_btn.grab_focus()

	# Instantiate Shop UI
	shop_ui_instance = shop_ui_script.new()
	add_child(shop_ui_instance)

	# Add Shop Button
	var shop_btn = TextureButton.new()
	shop_btn.texture_normal = load("res://shop.png")
	shop_btn.ignore_texture_size = true
	shop_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	# Position bottom left
	shop_btn.custom_minimum_size = Vector2(80, 80)
	shop_btn.size = Vector2(80, 80)
	shop_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	shop_btn.anchor_top = 1.0
	shop_btn.anchor_bottom = 1.0
	shop_btn.anchor_left = 0.0
	shop_btn.anchor_right = 0.0
	shop_btn.offset_left = 20
	shop_btn.offset_top = -100
	shop_btn.offset_right = 100
	shop_btn.offset_bottom = -20
	shop_btn.modulate = Color(0.8, 1.0, 1.0) # Slight cyan tint

	add_child(shop_btn)
	shop_btn.pressed.connect(func(): shop_ui_instance.open_shop())

	# Add Character Button
	var char_btn = Button.new()
	char_btn.text = "CHARACTER"
	char_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	char_btn.anchor_top = 1.0
	char_btn.anchor_bottom = 1.0
	char_btn.anchor_left = 1.0
	char_btn.anchor_right = 1.0
	char_btn.offset_left = -180
	char_btn.offset_top = -80
	char_btn.offset_right = -30
	char_btn.offset_bottom = -30
	# Style Character Button
	call_deferred("setup_cyberpunk_button", char_btn, "CHARACTER")

	add_child(char_btn)
	char_btn.pressed.connect(_on_character_btn_pressed)

	# --- Gacha System Integration ---
	# Instantiate Gacha System
	var gacha_system = GachaSystem.new()
	add_child(gacha_system)

	# Add Gacha Button
	var gacha_btn = TextureButton.new()
	if ResourceLoader.exists("res://gacha.png"):
		gacha_btn.texture_normal = load("res://gacha.png")
	else:
		gacha_btn.texture_normal = load("res://icon.svg")

	gacha_btn.ignore_texture_size = true
	gacha_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	gacha_btn.custom_minimum_size = Vector2(120, 120)
	gacha_btn.size = Vector2(120, 120)

	# Position: Top Right
	gacha_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gacha_btn.anchor_left = 1.0
	gacha_btn.anchor_right = 1.0
	gacha_btn.offset_left = -140
	gacha_btn.offset_top = 20
	gacha_btn.offset_right = -20
	gacha_btn.offset_bottom = 140

	# Add Aura/Sparkle Shader
	var shader = load("res://sparkle.gdshader")
	if shader:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("speed", 2.0)
		mat.set_shader_parameter("intensity", 0.8)
		gacha_btn.material = mat

	add_child(gacha_btn)
	gacha_btn.pressed.connect(func(): gacha_system.open_gacha())

	# --- Settings Button ---
	var settings_script = load("res://settings_menu.gd")
	var settings_menu = settings_script.new()
	add_child(settings_menu)

	var settings_btn = Button.new()
	settings_btn.text = "SETTINGS"
	settings_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	settings_btn.anchor_left = 0.0
	settings_btn.anchor_right = 0.0
	settings_btn.offset_left = 20
	settings_btn.offset_top = 20
	settings_btn.offset_right = 180
	settings_btn.offset_bottom = 70
	call_deferred("setup_cyberpunk_button", settings_btn, "SETTINGS")

	add_child(settings_btn)
	settings_btn.pressed.connect(func(): settings_menu.open_settings())

	setup_record_display()
	_add_title_label()

func _setup_cyberpunk_bg():
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Dark Background
	bg.color = Color(0.02, 0.02, 0.05)
	add_child(bg)
	move_child(bg, 0)

	# Grid Layer if shader exists
	if cyber_shader:
		var grid = ColorRect.new()
		grid.set_anchors_preset(Control.PRESET_FULL_RECT)
		var mat = ShaderMaterial.new()
		mat.shader = cyber_shader
		mat.set_shader_parameter("grid_color", Color(0.0, 1.0, 1.0, 0.2))
		mat.set_shader_parameter("bg_color", Color(0.0, 0.0, 0.0, 0.0))
		grid.material = mat
		add_child(grid)
		move_child(grid, 1)

func _add_title_label():
	var title = Label.new()
	title.text = "CYBER\nSORCERER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 50)
	title.add_theme_color_override("font_color", Color(1.0, 0.0, 0.5)) # Magenta
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("outline_color", Color(0.0, 1.0, 1.0)) # Cyan Outline

	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 100
	add_child(title)

	# Glitch Animation
	var tw = create_tween().set_loops()
	tw.tween_property(title, "modulate:a", 0.8, 0.1)
	tw.tween_property(title, "modulate:a", 1.0, 0.1)
	tw.tween_interval(2.0)
	tw.tween_callback(func():
		title.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0))
		title.add_theme_color_override("outline_color", Color(1.0, 0.0, 0.5))
	)
	tw.tween_interval(0.1)
	tw.tween_callback(func():
		title.add_theme_color_override("font_color", Color(1.0, 0.0, 0.5))
		title.add_theme_color_override("outline_color", Color(0.0, 1.0, 1.0))
	)

func setup_record_display():
	var time = Global.best_time
	var m = int(time) / 60
	var s = int(time) % 60
	var time_str = "%02d:%02d" % [m, s]

	var panel = PanelContainer.new()
	# Cyberpunk Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.0, 1.0, 0.0)
	style.skew = Vector2(-0.2, 0)

	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(250, 60)

	# Position at bottom center
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -125
	panel.offset_right = 125
	panel.offset_top = -80
	panel.offset_bottom = -20

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var lbl_title = Label.new()
	lbl_title.text = "RECORD SURVIVAL"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(lbl_title)

	var lbl_time = Label.new()
	lbl_time.text = time_str
	lbl_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_time.add_theme_color_override("font_color", Color.GREEN)
	lbl_time.add_theme_font_size_override("font_size", 24)
	vbox.add_child(lbl_time)

	add_child(panel)
	move_child(panel, 2)

func _on_character_btn_pressed():
	var scene = load("res://character_selection.tscn").instantiate()
	add_child(scene)

func _on_play_pressed():
	get_tree().change_scene_to_file("res://potion_selection.tscn")

func _on_exit_pressed():
	get_tree().quit()

func setup_cyberpunk_button(btn: Button, text: String):
	btn.text = text
	btn.pivot_offset = btn.size / 2

	# Base Style
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.0, 0.0, 0.0, 0.8)
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(0.0, 0.6, 0.8) # Cyan Dim
	normal.set_corner_radius_all(0)

	var hover = normal.duplicate()
	hover.bg_color = Color(0.0, 0.2, 0.3, 0.9)
	hover.border_color = Color(0.0, 1.0, 1.0) # Cyan Bright
	hover.shadow_color = Color(0.0, 1.0, 1.0, 0.5)
	hover.shadow_size = 10

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(0.0, 1.0, 1.0))
	btn.add_theme_font_size_override("font_size", 24)

	btn.mouse_entered.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.1)
	)

	btn.mouse_exited.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	)
