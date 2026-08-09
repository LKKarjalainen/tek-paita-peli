class_name GameCamera
extends Camera2D
## Follows the player, clamped to the current room's drawn area.
##
## The maps are wildly different shapes -- a 159x389 corridor, a 262x191 guild
## room, a 47x76 closet -- so a fixed frame cannot serve all three. Zoom is
## picked per room to fill the screen as much as possible without ever zooming
## *out* (a corridor is meant to scroll, not shrink), and kept to whole numbers
## so the pixels stay square.

const VIEW := Vector2(320, 180)
const MAX_ZOOM := 2

var target: Node2D

var _bounds := Rect2(Vector2.ZERO, VIEW)
var _view := VIEW


func _ready() -> void:
	SceneRouter.room_changed.connect(_on_room_changed)


func _process(_delta: float) -> void:
	_follow()


func _on_room_changed(room: Node2D) -> void:
	_bounds = (room as Room).bounds() if room is Room else Rect2(Vector2.ZERO, VIEW)
	var fit_x := VIEW.x / _bounds.size.x
	var fit_y := VIEW.y / _bounds.size.y
	var z := clampi(int(floor(maxf(fit_x, fit_y))), 1, MAX_ZOOM)
	zoom = Vector2(z, z)
	_view = VIEW / float(z)
	_follow()


func _follow() -> void:
	if target == null:
		return
	var half := _view * 0.5
	var p := target.global_position
	# Per axis: scroll if the room is taller/wider than the frame, otherwise
	# centre it and let the margins show.
	for axis in 2:
		if _bounds.size[axis] > _view[axis]:
			p[axis] = clampf(p[axis], _bounds.position[axis] + half[axis], _bounds.end[axis] - half[axis])
		else:
			p[axis] = _bounds.position[axis] + _bounds.size[axis] * 0.5
	global_position = p.round()
