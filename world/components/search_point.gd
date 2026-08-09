class_name SearchPoint
extends Interactable
## One of the places on the checklist. Says its lines, optionally runs a
## minigame, then reports the location as searched.
##
## The minigame is optional so that a dialogue-only search ("Kysy Algolta")
## uses this same component instead of a special case.

@export var location_id: String = ""
@export var lines: Array[String] = []
@export var searched_lines: Array[String] = ["Tästä on jo katsottu."]
@export var minigame: PackedScene


func interact() -> void:
	if GameState.is_searched(location_id):
		await Dialogue.say(searched_lines)
		return

	await Dialogue.say(lines)

	if minigame != null:
		SceneRouter.play_minigame(minigame, location_id)
	else:
		GameState.mark_searched(location_id)
