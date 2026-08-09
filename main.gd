extends Node
## Boot scene. Holds the two things that outlive a room -- the World container
## rooms get swapped into, and the Player -- and hands both to the router.
##
## Also owns the title screen, because starting a run and restarting after a
## loss are the same act and only this scene knows where the game begins.

const START_ROOM := "res://world/rooms/kaytava.tscn"
const START_SPAWN := "start"
const TITLE_SCENE := preload("res://ui/title_screen.tscn")

@onready var _world: Node2D = $World
@onready var _player: Player = $Player
@onready var _camera: GameCamera = $Camera2D

var _title: TitleScreen
var _title_layer: CanvasLayer


func _ready() -> void:
	GameState.all_searched.connect(_on_all_searched)
	SceneRouter.restart_requested.connect(_on_restart)
	_camera.target = _player
	SceneRouter.register(_world, _player)

	_title_layer = CanvasLayer.new()
	_title_layer.name = "TitleLayer"
	_title_layer.layer = 60
	# The world is frozen behind the menu, so this has to keep running.
	_title_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_title_layer)

	_show_title()


func _show_title() -> void:
	# Nothing is loaded yet and the player is parked off-map; freezing the tree
	# stops WASD from walking an invisible character around behind the menu.
	get_tree().paused = true

	_title = TITLE_SCENE.instantiate()
	_title_layer.add_child(_title)
	_title.start_pressed.connect(_start_game, CONNECT_ONE_SHOT)
	_title.quit_pressed.connect(get_tree().quit.bind(0), CONNECT_ONE_SHOT)

	# The router boots opaque so the game starts on black; clear it to reveal
	# the menu rather than the empty world.
	await SceneRouter.fade_in()

	# Greets you on the title screen, once per launch -- not on every run, since
	# a restart after a loss goes straight back into the corridor.
	Audio.say("voice_intro")


func _start_game() -> void:
	await SceneRouter.fade_out()
	_title.queue_free()
	_title = null
	get_tree().paused = false
	GameState.reset()
	SceneRouter.go_to_room(START_ROOM, START_SPAWN)


## Dismissing a loss screen starts a fresh run straight away rather than going
## back to the menu -- the screen offers "Uudestaan", not "päävalikkoon".
func _on_restart() -> void:
	GameState.reset()
	SceneRouter.go_to_room(START_ROOM, START_SPAWN)


## Every place searched. Same screen as walking out or giving up -- there is
## only one way this ends, and doing it properly is not one of the ways out.
func _on_all_searched() -> void:
	SceneRouter.lose("paitaa ei ole, hävisit pelin :D")
