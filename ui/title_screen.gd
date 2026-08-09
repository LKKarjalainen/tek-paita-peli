class_name TitleScreen
extends Control
## Entry point. Keyboard and mouse both work: W/S or arrows to move, E or Enter
## to choose, or just click.

signal start_pressed
signal quit_pressed

var _buttons: Array[Button] = []
var _caret: Label


func _ready() -> void:
	_caret = $Caret
	_buttons = [$Start, $Quit]

	$Start.pressed.connect(func(): start_pressed.emit())
	$Quit.pressed.connect(func(): quit_pressed.emit())

	for b: Button in _buttons:
		b.mouse_entered.connect(b.grab_focus)
		b.focus_entered.connect(_move_caret)

	$Start.grab_focus()
	_move_caret()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_down"):
		_step(1)
	elif event.is_action_pressed("move_up"):
		_step(-1)
	elif event.is_action_pressed("interact"):
		# Space also maps to ui_accept and the focused Button swallows it before
		# we get here; this branch is what makes E work as well.
		for b: Button in _buttons:
			if b.has_focus():
				get_viewport().set_input_as_handled()
				b.pressed.emit()
				return


func _step(by: int) -> void:
	for i in _buttons.size():
		if _buttons[i].has_focus():
			_buttons[(i + by + _buttons.size()) % _buttons.size()].grab_focus()
			return
	_buttons[0].grab_focus()


## The caret moves instead of the labels gaining a prefix, so the text does not
## shift by a character width as the selection changes. Its position is measured
## from the label rather than tuned by hand, so it still sits right next to the
## text if the wording changes.
func _move_caret() -> void:
	for b: Button in _buttons:
		if not b.has_focus():
			continue
		var font := b.get_theme_font("font")
		var size := b.get_theme_font_size("font_size")
		var width := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var text_left := b.position.x + (b.size.x - width) * 0.5
		_caret.position = Vector2(text_left - 11.0, b.position.y)
		return
