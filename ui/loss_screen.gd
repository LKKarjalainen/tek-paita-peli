class_name LossScreen
extends Control
## Full-screen "you lost" overlay. The reason is the joke, so it gets the
## biggest text on screen and nothing competes with it.

signal restart_requested


func _ready() -> void:
	set_process_unhandled_input(false)


func show_reason(reason: String) -> void:
	$Reason.text = reason
	# Swallow the very keypress that opened this: it is still travelling
	# through this frame's input and would restart the game instantly.
	await get_tree().process_frame
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		set_process_unhandled_input(false)
		restart_requested.emit()
