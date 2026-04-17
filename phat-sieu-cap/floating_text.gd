extends Label

var amount = 0
var is_critical = false
var velocity = Vector2(0, -50) # Move up
var duration = 0.8

func setup(dmg_amount, critical):
	amount = dmg_amount
	is_critical = critical

	text = str(int(amount))

	if is_critical:
		modulate = Color(1, 0.2, 0.2) # Red
		scale = Vector2(1.5, 1.5)
		velocity = Vector2(0, -80) # Move up faster
		text += "!"
	else:
		modulate = Color(1, 1, 1) # White
		scale = Vector2(0.8, 0.8) # Slightly smaller

func _ready():
	# Center pivot for scale
	pivot_offset = size / 2

	var target_scale = scale
	scale = scale * 0.5
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SPRING)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", target_scale * 1.2, 0.2)
	tween.tween_property(self, "scale", target_scale, 0.1)

func _process(delta):
	position += velocity * delta

	duration -= delta
	if duration <= 0:
		queue_free()

	# Fade out near end smoothly
	if duration < 0.4:
		modulate.a = lerp(modulate.a, 0.0, 10.0 * delta)
