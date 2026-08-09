extends Minigame
## Kaiva Linkin varaston kasa läpi.
##
## The heap comes apart from the top down. Clicking something with another
## thing on top of it wobbles and says so; nothing is lost, you just have to
## shift what is above it first.

const HEAP := Rect2(40, 44, 232, 94)
const ITEM_SIZE := Vector2(92, 16)

## Bottom of the heap first: entries later in this list are drawn on top, and
## so have to come off first.
const PILE: Array = [
	{"name": "vanhat haalarit", "at": Vector2(62, 98)},
	{"name": "banderolli", "at": Vector2(104, 86)},
	{"name": "vanha tv", "at": Vector2(146, 102)},
	{"name": "vitustijohtoja", "at": Vector2(88, 68)},
	{"name": "2016 ketsuppi", "at": Vector2(140, 90)},
	{"name": "2017 ketsuppi", "at": Vector2(140, 90)},
	{"name": "2018 ketsuppi", "at": Vector2(140, 90)},
	{"name": "2019 ketsuppi", "at": Vector2(140, 90)},
	{"name": "2020 ketsuppi", "at": Vector2(140, 90)},
	{"name": "2021 ketsuppi", "at": Vector2(140, 90)},
	{"name": "2022 ketsuppi", "at": Vector2(140, 90)},
	{"name": "2023 ketsuppi", "at": Vector2(140, 90)},
	{"name": "2024 ketsuppi", "at": Vector2(140, 90)},
	{"name": "2025 ketsuppi", "at": Vector2(140, 90)},
	{"name": "2026 ketsuppi", "at": Vector2(140, 90)},
	{"name": "Styrolit", "at": Vector2(132, 58)},
	{"name": "joulukoristeet", "at": Vector2(170, 80)},
	{"name": "1987 sinap", "at": Vector2(140, 90)},
	{"name": "Lavazza", "at": Vector2(140, 90)},
]

var _stack: Array[Panel] = []
var _finished := false


func start() -> void:
	build_chrome("LINKIN VARASTO")
	add_frame(HEAP, Color(0.38, 0.36, 0.33), "KASA")

	for item in PILE:
		_stack.append(make_item(item["name"], item["at"], ITEM_SIZE))

	_update_hint()


func _gui_input(event: InputEvent) -> void:
	if _finished:
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return

	var hit := _pick(event.position)
	if hit == null:
		return

	if hit != _stack[-1]:
		nudge(hit)
		set_hint("Jotain on sen päällä.")
		return

	_take(hit)


## Topmost remaining thing under the cursor.
func _pick(pos: Vector2) -> Panel:
	for i in range(_stack.size() - 1, -1, -1):
		var p: Panel = _stack[i]
		if Rect2(p.position, p.size).has_point(pos):
			return p
	return null


func _take(p: Panel) -> void:
	_stack.erase(p)

	var away := -ITEM_SIZE.x - 8.0 if _stack.size() % 2 == 0 else VIEW.x + 8.0
	var t := create_tween()
	t.tween_property(p, "position:x", away, 0.16)
	t.tween_callback(p.hide)

	if _stack.is_empty():
		_finished = true
		finish("1000 kpl ketsup mutta ei paita prööt")
	else:
		_update_hint()


func _update_hint() -> void:
	set_hint("Kasassa vielä: %d" % _stack.size())
