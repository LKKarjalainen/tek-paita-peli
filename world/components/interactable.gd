class_name Interactable
extends Area2D
## Anything the player can press E on. Subclasses override `interact()`.
##
## Sits on collision layer 2 and monitors nothing; the player's InteractZone
## does the detecting, so interactables cost nothing when nobody is near.

@export var prompt: String = "Tutki"
@export var prompt_offset := Vector2(0, -20)

var _label: Label


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	monitorable = true
	monitoring = false

	_label = Label.new()
	_label.text = prompt
	_label.size = Vector2(80, 10)
	_label.position = prompt_offset - Vector2(40, 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 7)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 3)
	_label.visible = false
	add_child(_label)


## Called by the player every frame for the one nearest interactable.
func set_highlighted(on: bool) -> void:
	if is_instance_valid(_label):
		_label.visible = on


func interact() -> void:
	pass
