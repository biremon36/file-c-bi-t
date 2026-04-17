extends Control

# Signals
signal gacha_closed
signal reward_granted(reward_name)

# UI Elements
var panel: Panel
var wheel_container: Control
var wheel_rotation_node: Control
var arrow: Polygon2D

# State
var is_spinning: bool = false
var current_rotation: float = 0.0

func _init():
    panel = Panel.new()
    wheel_container = Control.new()
    wheel_rotation_node = Control.new()
    arrow = Polygon2D.new()

    add_child(panel)
    panel.add_child(wheel_container)
    wheel_container.add_child(wheel_rotation_node)
    wheel_container.add_child(arrow)

func spin():
    if is_spinning:
        return false
    is_spinning = true
    return true

func stop_spin(final_rotation: float):
    if not is_spinning:
        return false
    is_spinning = false
    current_rotation = final_rotation
    wheel_rotation_node.rotation = final_rotation

    var reward = _determine_reward(final_rotation)
    emit_signal("reward_granted", reward)
    return true

func close():
    emit_signal("gacha_closed")

func _determine_reward(rotation: float) -> String:
    # A simple mock logic to return different rewards based on rotation
    if rotation < PI / 2:
        return "Gojo Figure"
    elif rotation < PI:
        return "Sukuna Finger"
    elif rotation < 3 * PI / 2:
        return "Cursed Energy Potion"
    else:
        return "Special Grade Weapon"
