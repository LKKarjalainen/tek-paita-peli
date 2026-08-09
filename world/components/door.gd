class_name Door
extends Interactable
## Sends the player to another room, arriving at a named spawn marker there.
##
## `target_room` is a path rather than a PackedScene on purpose: the corridor
## points at Kattila and Kattila points back at the corridor, which as resource
## references would be a load-time cycle.

@export_file("*.tscn") var target_room: String = ""
@export var target_spawn: String = "default"
@export var locked_lines: Array[String] = ["Ei tänne nyt."]
## Set this and the door ends the run instead of leading anywhere. Takes
## precedence over `target_room`.
@export var loss_reason: String = ""


func interact() -> void:
	if not loss_reason.is_empty():
		SceneRouter.lose(loss_reason)
		return
	if target_room.is_empty():
		Dialogue.say(locked_lines)
		return
	# Deliberately not awaited: the transition frees this door's room, and a
	# coroutine suspended on a freed node is an error on resume.
	SceneRouter.go_to_room(target_room, target_spawn)
