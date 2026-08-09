class_name DigOutMinigame
extends Minigame
## Empty a cabinet: drag every item out onto the floor.
##
## Dropping one anywhere but the floor just sends it back to its shelf -- there
## is no wrong move, only a move that has to be made again.
##
## Subclasses supply data and nothing else: override `configure()` to set the
## title, the contents and the closing line.

const CABINET := Rect2(16, 30, 288, 58)
const DROP := Rect2(16, 100, 288, 46)
const ITEM_SIZE := Vector2(72, 16)

## Five shelf positions -- two rows, the lower one inset so it reads as a pile
## rather than a grid. Contents are placed on these by index.
const HOMES: Array = [
	Vector2(20, 36),
	Vector2(124, 36),
	Vector2(228, 36),
	Vector2(72, 62),
	Vector2(176, 62),
]

var task_title := ""
var contents: Array = []
var closing_line := ""

var _panels: Array[Panel] = []
var _home: Dictionary = {}
var _out: Dictionary = {}
var _dragging: Panel = null
var _grab := Vector2.ZERO
var _finished := false


## Override: set `task_title`, `contents` (an array of item names) and
## `closing_line`.
func configure() -> void:
	pass


func start() -> void:
	configure()
	build_chrome(task_title)
	add_frame(CABINET, Color(0.72, 0.58, 0.42), "KAAPPI")
	add_frame(DROP, Color(0.55, 0.66, 0.52), "LATTIA")

	for i in contents.size():
		# More contents than shelves just stacks them, fanned a little so a deep
		# pile reads as a pile instead of as one item.
		var tier: int = i / HOMES.size()
		var at: Vector2 = HOMES[i % HOMES.size()] + Vector2((tier % 3) - 1, tier) * 2.0
		var p := make_item(str(contents[i]), at, ITEM_SIZE)
		_panels.append(p)
		_home[p] = at
		_out[p] = false

	_update_hint()


func _gui_input(event: InputEvent) -> void:
	if _finished:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = _pick(event.position)
			if _dragging != null:
				_grab = event.position - _dragging.position
				move_child(_dragging, get_child_count() - 1)
		elif _dragging != null:
			_drop()
	elif event is InputEventMouseMotion and _dragging != null:
		_dragging.position = event.position - _grab


func _pick(pos: Vector2) -> Panel:
	# Reverse order so the visually topmost item wins an overlap.
	for i in range(_panels.size() - 1, -1, -1):
		var p: Panel = _panels[i]
		if _out[p]:
			continue
		if Rect2(p.position, p.size).has_point(pos):
			return p
	return null


func _drop() -> void:
	var p: Panel = _dragging
	_dragging = null

	if DROP.has_point(p.position + p.size * 0.5):
		_out[p] = true
		p.modulate = Color(0.78, 0.78, 0.78)
	else:
		p.position = _home[p]

	_update_hint()
	for panel in _panels:
		if not _out[panel]:
			return
	_finished = true
	finish(closing_line)


func _update_hint() -> void:
	var n := 0
	for p in _panels:
		if _out[p]:
			n += 1
	set_hint("Kaivettu ulos: %d / %d" % [n, _panels.size()])
