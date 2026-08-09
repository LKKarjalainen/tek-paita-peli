extends Node
## Owns the one dialogue box and exposes an awaitable `say()`.
##
## Callers write `await Dialogue.say([...])` and continue when the player has
## clicked through every line. Lives on its own CanvasLayer so it draws over
## the world and keeps running while the tree is paused.

const BOX_SCENE := preload("res://ui/dialogue_box.tscn")

var _box: DialogueBox
var _active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.name = "DialogueLayer"
	layer.layer = 50
	add_child(layer)
	_box = BOX_SCENE.instantiate()
	layer.add_child(_box)


## True while lines are on screen. The player checks this to stop walking.
func is_active() -> bool:
	return _active


func say(lines: Array[String]) -> void:
	if lines.is_empty():
		return
	# Nested calls would fight over the one box; make the second one wait.
	while _active:
		await _box.closed
	_active = true
	await _box.run(lines)
	_active = false
