class_name Minigame
extends Control
## Base class for every task. Hosted by SceneRouter on a layer above the world,
## never parented into a room.
##
## There is exactly one way out. The absence of a `failed` signal is the design,
## not an oversight: tasks can be fumbled and repeated, never lost. A subclass
## that wants to punish a wrong move should shake something and say so -- it
## must not take progress away and must not end.

signal completed

const VIEW := Vector2(320, 180)

var _hint: Label
var _veil: Control
var _awaiting_dismiss := false
var _dismissed := false


## Called by the router once the minigame is in the tree.
func start() -> void:
	pass


## Dark backing, task name, and the status line at the foot of the screen.
func build_chrome(title: String) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.16)
	bg.size = VIEW
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var heading := make_label(title, 8, Color(0.93, 0.93, 0.93))
	heading.position = Vector2(12, 5)
	heading.size = Vector2(296, 12)
	add_child(heading)

	_hint = make_label("", 7, Color(0.72, 0.72, 0.78))
	_hint.position = Vector2(12, 162)
	_hint.size = Vector2(296, 12)
	add_child(_hint)


func set_hint(text: String) -> void:
	if _hint != null:
		_hint.text = text


## Every task ends the same way: a line about what was not found, held on
## screen until the player dismisses it. Never on a timer -- the closing line
## is the joke, and it should not be able to scroll past unread.
func finish(final_line: String) -> void:
	set_hint(final_line)

	# A lid over the finished task: it swallows clicks so nothing can be
	# fiddled with afterwards, and carries the prompt.
	_veil = Control.new()
	_veil.name = "Veil"
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_veil.gui_input.connect(_on_veil_input)
	add_child(_veil)

	var prompt := make_label("[E] jatka", 7, Color(0.75, 0.75, 0.82))
	prompt.position = Vector2(12, 150)
	prompt.size = Vector2(296, 10)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_veil.add_child(prompt)

	# Let the click or drop that finished the task drain out of this frame
	# first, or it dismisses the line it just produced.
	await get_tree().process_frame
	_awaiting_dismiss = true
	while not _dismissed:
		await get_tree().process_frame
	_awaiting_dismiss = false

	completed.emit()


## Keyboard dismissal. Mouse goes through the veil instead, because a Control
## with MOUSE_FILTER_STOP consumes clicks before they reach _unhandled_input.
func _unhandled_input(event: InputEvent) -> void:
	if _awaiting_dismiss and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_dismissed = true


func _on_veil_input(event: InputEvent) -> void:
	if not _awaiting_dismiss:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_dismissed = true


## A labelled backing area -- a shelf, a floor, a heap.
func add_frame(rect: Rect2, fill: Color, title: String) -> void:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", stylebox(fill))
	add_child(p)

	if title != "":
		var l := make_label(title, 7, Color(0.78, 0.78, 0.82))
		l.position = rect.position + Vector2(2, -10)
		l.size = Vector2(rect.size.x, 10)
		add_child(l)


## A draggable/clickable thing with its name on it.
func make_item(text: String, at: Vector2, size: Vector2, fill := Color(0.96, 0.94, 0.86)) -> Panel:
	var p := Panel.new()
	p.position = at
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", stylebox(fill))

	# Anchored rather than sized once: a Label grows past any size you set when
	# the text needs more room, which spills long names outside their item.
	var l := make_label(text, 7, Color(0.1, 0.1, 0.1))
	l.anchor_right = 1.0
	l.anchor_bottom = 1.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	p.add_child(l)

	add_child(p)
	return p


## Wrong-move feedback. Never costs anything -- it only says "not that one".
func nudge(p: Panel) -> void:
	var home := p.position
	var t := create_tween()
	t.tween_property(p, "position:x", home.x - 3.0, 0.04)
	t.tween_property(p, "position:x", home.x + 3.0, 0.08)
	t.tween_property(p, "position:x", home.x, 0.04)


func make_label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l


func stylebox(fill: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = Color.BLACK
	sb.set_border_width_all(1)
	return sb
