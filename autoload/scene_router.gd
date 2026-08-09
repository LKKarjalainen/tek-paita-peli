extends Node
## Owns every context switch: walking into a room, and opening a minigame.
##
## Rooms are children of a World node supplied by main.tscn. The player is NOT
## a child of a room -- it persists across transitions and gets teleported to
## the target room's named spawn marker, so a four-door corridor can put you
## back at the door you came from.
##
## Rooms are addressed by *path*, not PackedScene. Kattila's door points at the
## corridor and the corridor's door points at Kattila; as ExtResources that is a
## dependency cycle, as strings it is nothing.

signal room_changed(room: Node2D)
## Emitted when the loss screen has been dismissed. Whoever knows where the
## game starts (main.gd) is responsible for putting the player back there.
signal restart_requested

const FADE_TIME := 0.22
const LOSS_SCENE := preload("res://ui/loss_screen.tscn")

var _world: Node2D
var _player: Node2D
var _current_room: Node2D
var _fade: ColorRect
var _minigame_layer: CanvasLayer
var _loss_layer: CanvasLayer
var _loss: LossScreen
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_minigame_layer = CanvasLayer.new()
	_minigame_layer.name = "MinigameLayer"
	_minigame_layer.layer = 40
	add_child(_minigame_layer)

	_loss_layer = CanvasLayer.new()
	_loss_layer.name = "LossLayer"
	_loss_layer.layer = 80
	add_child(_loss_layer)

	var fade_layer := CanvasLayer.new()
	fade_layer.name = "FadeLayer"
	fade_layer.layer = 100
	add_child(fade_layer)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Start opaque so the game boots on black rather than flashing an empty
	# world for the length of the first fade-out.
	_fade.modulate.a = 1.0
	fade_layer.add_child(_fade)


func register(world: Node2D, player: Node2D) -> void:
	_world = world
	_player = player


## True mid-transition. The player checks this so you cannot walk or interact
## while the screen is black.
func is_busy() -> bool:
	return _busy


func current_room() -> Node2D:
	return _current_room


func go_to_room(room_path: String, spawn_id: String) -> void:
	if _busy:
		return
	_busy = true

	await fade_out()

	if is_instance_valid(_current_room):
		# Out of the tree immediately, freed on the idle frame -- otherwise the
		# outgoing room processes for one more frame alongside the incoming one.
		_world.remove_child(_current_room)
		_current_room.queue_free()

	var scene: PackedScene = load(room_path)
	_current_room = scene.instantiate()
	_world.add_child(_current_room)

	var spawn := _current_room.get_node_or_null("SpawnPoints/" + spawn_id)
	if spawn == null:
		push_error("no SpawnPoints/%s in %s" % [spawn_id, room_path])
	else:
		_player.global_position = spawn.global_position

	room_changed.emit(_current_room)
	await fade_in()
	_busy = false


## A minigame is never a child of a room. It goes on a layer above the world
## and freezes everything below it, which is what lets one Kattila scene host
## three independent searches without nesting any of them.
func play_minigame(scene: PackedScene, location_id: String) -> void:
	var mg: Minigame = scene.instantiate()
	_minigame_layer.add_child(mg)
	get_tree().paused = true
	mg.completed.connect(_finish_minigame.bind(mg, location_id), CONNECT_ONE_SHOT)
	mg.start()


## End the run. Hosted the same way as a minigame -- a layer above the world
## with everything below it frozen -- so losing is just another context the
## router owns, not a special case rooms have to know about.
func lose(reason: String) -> void:
	if _loss != null:
		return
	_loss = LOSS_SCENE.instantiate()
	_loss_layer.add_child(_loss)
	get_tree().paused = true
	Audio.say("voice_loss")
	_loss.restart_requested.connect(_on_restart, CONNECT_ONE_SHOT)
	_loss.show_reason(reason)


func is_lost() -> bool:
	return _loss != null


func _on_restart() -> void:
	_loss.queue_free()
	_loss = null
	get_tree().paused = false
	restart_requested.emit()


func _finish_minigame(mg: Minigame, location_id: String) -> void:
	mg.queue_free()
	get_tree().paused = false
	GameState.mark_searched(location_id)


func fade_out() -> void:
	_fade.visible = true
	var t := create_tween()
	t.tween_property(_fade, "modulate:a", 1.0, FADE_TIME)
	await t.finished


func fade_in() -> void:
	var t := create_tween()
	t.tween_property(_fade, "modulate:a", 0.0, FADE_TIME)
	await t.finished
	_fade.visible = false
