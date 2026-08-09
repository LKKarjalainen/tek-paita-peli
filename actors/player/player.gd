class_name Player
extends CharacterBody2D
## Persistent across rooms -- lives under main.tscn, never inside a room scene.
## The router teleports it to the target room's spawn marker.
##
## Origin is at the character's feet so world positions read as floor positions.

const SPEED := 62.0
const STEP_INTERVAL := 0.32

@onready var _zone: Area2D = $InteractZone

var _nearest: Interactable = null
var _step_cooldown := 0.0


func _physics_process(delta: float) -> void:
	if _frozen():
		velocity = Vector2.ZERO
	else:
		var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = dir * SPEED
	move_and_slide()
	_footsteps(delta)
	_update_nearest()


## A step on setting off and every STEP_INTERVAL after, pitched slightly
## differently each time so a long corridor does not turn into a metronome.
func _footsteps(delta: float) -> void:
	if velocity.length_squared() < 1.0:
		# Reset rather than pause, so the next move steps immediately instead of
		# waiting out whatever was left on the clock.
		_step_cooldown = 0.0
		return
	_step_cooldown -= delta
	if _step_cooldown <= 0.0:
		_step_cooldown = STEP_INTERVAL
		Audio.play("step", randf_range(0.92, 1.09))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if _frozen() or not is_instance_valid(_nearest):
		return
	get_viewport().set_input_as_handled()
	_nearest.interact()


## No walking or interacting while someone is talking, the screen is fading, or
## the run is over. The pause during a loss already stops this node, but saying
## it out loud means a door cannot steal the keypress meant for that screen.
func _frozen() -> bool:
	return Dialogue.is_active() or SceneRouter.is_busy() or SceneRouter.is_lost()


func _update_nearest() -> void:
	var best: Interactable = null
	if not _frozen():
		var best_dist := INF
		for area in _zone.get_overlapping_areas():
			if area is Interactable:
				var d: float = global_position.distance_squared_to(area.global_position)
				if d < best_dist:
					best_dist = d
					best = area

	if best == _nearest:
		return
	# The old one may have been freed with its room, hence the validity check.
	if is_instance_valid(_nearest):
		_nearest.set_highlighted(false)
	_nearest = best
	if is_instance_valid(_nearest):
		_nearest.set_highlighted(true)
