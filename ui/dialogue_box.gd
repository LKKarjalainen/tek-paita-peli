class_name DialogueBox
extends Control
## One line at a time, advanced with `interact`. No typewriter effect yet.

signal closed

var _advanced_this_line := false


func _ready() -> void:
	visible = false
	set_process_unhandled_input(false)


func run(lines: Array[String]) -> void:
	visible = true
	# Swallow the very keypress that opened the box: it is still travelling
	# through this frame's input, and would otherwise skip the first line.
	await get_tree().process_frame
	set_process_unhandled_input(true)

	for line in lines:
		$Panel/Text.text = line
		_advanced_this_line = false
		while not _advanced_this_line:
			await get_tree().process_frame

	set_process_unhandled_input(false)
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_advanced_this_line = true
