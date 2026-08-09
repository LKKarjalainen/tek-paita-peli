extends Node
## Headless end-to-end check of the vertical slice.
##
##     godot --headless res://tests/smoke.tscn
##
## Drives the real components -- doors, dialogue, the minigame's own input
## handler -- rather than poking GameState directly, so it fails if any of the
## three contracts stops holding.

const TIMEOUT_FRAMES := 600

var _failures: Array[String] = []
var _checks := 0
var _all_searched := false
## Everything Audio has played, newest last. Cleared by tests that care.
var _heard: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The harness has to keep running while the game is paused -- but the game
	# must not. main.tscn is the root scene in the real build, so it pauses;
	# here it is a child of this node and would inherit ALWAYS from it. Without
	# this the player keeps walking under minigames and loss screens, and
	# steals the keypress meant for dismissing them.
	$Main.process_mode = Node.PROCESS_MODE_PAUSABLE
	GameState.all_searched.connect(func(): _all_searched = true)
	Audio.played.connect(func(clip: String): _heard.append(clip))
	await _run()
	_report()


func _run() -> void:
	# 0. boot lands on the title screen, not in the game
	var main := get_node("Main")
	if not await _wait_until(func(): return main._title != null, "title screen"):
		return
	_check(get_tree().paused, "world stays frozen behind the title screen")
	_check(SceneRouter.current_room() == null, "no room is loaded until you start")

	if not await _wait_until(func(): return _heard.has("voice_intro"), "intro voice line"):
		return
	_check(true, "launching plays the intro voice line on the title screen")

	_heard.clear()
	var guard := 0
	while main._title != null and guard < 60:
		var ev := InputEventAction.new()
		ev.action = "interact"
		ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().process_frame
		await get_tree().process_frame
		guard += 1
	_check(main._title == null, "[E] on Aloita starts the game")
	_check(not _heard.has("voice_intro"), "the intro line does not replay when the run starts")

	# 1. and that lands in the corridor
	if not await _wait_until(
		func(): return not SceneRouter.is_busy() and SceneRouter.current_room() != null,
		"boot transition"
	):
		return
	_check(SceneRouter.current_room().name == "Kaytava", "boots into Kaytava")
	_check(not get_tree().paused, "world runs once the game has started")

	# 1b. all three clips are present, and walking is audible
	for clip in ["step", "voice_intro", "voice_loss"]:
		_check(Audio.has(clip), "\"%s\" is loaded" % clip)

	_heard.clear()
	var from_x: float = main._player.global_position.x
	Input.action_press("move_right")
	for i in 30:
		await get_tree().physics_frame
	Input.action_release("move_right")
	await get_tree().physics_frame

	_check(main._player.global_position.x > from_x + 4.0, "player walks")
	_check(_heard.has("step"), "walking plays the step sound")

	_heard.clear()
	Audio.say("no_such_clip")
	_check(_heard.is_empty(), "an unknown clip stays silent instead of erroring")
	_check(GameState.searched_count() == 0, "nothing searched at boot")
	_check_bounds(Vector2(159, 389), "Kaytava map is 159x389")

	# 2. the two doors that end the run on the spot
	await _lose_by("Exits/ToAula", "annoit periks, hävisit pelin :D", "Aula")
	await _lose_by("Exits/ToUlos", "koskit nurmikkoa, hävisit pelin :D", "ulos")

	# 3. the real door does
	var door: Door = SceneRouter.current_room().get_node("Exits/ToKattila")
	door.interact()
	if not await _wait_until(
		func(): return not SceneRouter.is_busy() and SceneRouter.current_room().name == "Kattila",
		"corridor -> Kattila"
	):
		return
	_check(true, "corridor -> Kattila")
	_check_bounds(Vector2(262, 191), "Kattila map is 262x191")

	# 4. spawn marker was honoured
	var player: Node2D = get_node("Main/Player")
	var spawn: Node2D = SceneRouter.current_room().get_node("SpawnPoints/kaytava")
	_check(player.global_position == spawn.global_position, "arrived at SpawnPoints/kaytava")

	# 5. search point: dialogue, then minigame
	var sp: SearchPoint = SceneRouter.current_room().get_node("SearchPoints/HallitusKaappi")
	sp.interact()
	if not await _wait_until(func(): return Dialogue.is_active(), "search dialogue"):
		return
	await _clear_dialogue()

	var mg: Minigame = await _wait_for_minigame()
	if mg == null:
		return
	_check(get_tree().paused, "world pauses under the minigame")

	# 6. play it the way a player would
	await _play_dig_out(mg, "Hallitus")
	_check(mg._awaiting_dismiss, "closing line waits for input instead of timing out")
	if not await _dismiss_minigame("Hallitus"):
		return
	_check(GameState.is_searched("hallitus_kaappi"), "location marked searched")
	_check(GameState.searched_count() == 1, "exactly one location searched")
	_check(not GameState.is_searched("varasto"), "other locations untouched")

	# 7. re-searching says so instead of replaying
	sp.interact()
	await _wait_until(func(): return Dialogue.is_active(), "already-searched dialogue")
	_check(Dialogue.is_active(), "already-searched line plays")
	await _clear_dialogue()
	_check(not get_tree().paused, "minigame did not run a second time")

	# 8. second yellow marker: a different task in the same room
	var tapsa: SearchPoint = SceneRouter.current_room().get_node("SearchPoints/TapsaKaappi")
	tapsa.interact()
	if not await _wait_until(func(): return Dialogue.is_active(), "Tapsa dialogue"):
		return
	await _clear_dialogue()
	var tapsa_mg: Minigame = await _wait_for_minigame()
	if tapsa_mg == null:
		return
	_check(_item_names(tapsa_mg) == ["Jaloviina"], "Tapsa's cabinet holds nothing but Jaloviina")
	await _play_dig_out(tapsa_mg, "Tapsa")
	if not await _dismiss_minigame("Tapsa"):
		return
	_check(GameState.is_searched("tapsa_kaappi"), "Tapsa kaappi searched")

	# 8b. the magenta marker: asking Algo, a search with no minigame at all
	var algo: SearchPoint = SceneRouter.current_room().get_node("SearchPoints/Algo")
	algo.interact()
	if not await _wait_until(func(): return Dialogue.is_active(), "Algo dialogue"):
		return
	await _clear_dialogue()
	_check(GameState.is_searched("algo"), "asking Algo counts as a search")
	_check(not get_tree().paused, "dialogue-only search ran no minigame")
	_check(not _all_searched, "3 of 4 searched, ending not triggered yet")

	# 9. back out
	if not await _go(SceneRouter.current_room().get_node("Exits/ToKaytava"), "Kaytava", "Kattila -> corridor"):
		return
	var ret: Node2D = SceneRouter.current_room().get_node("SpawnPoints/kattila")
	_check(player.global_position == ret.global_position, "returned to the Kattila door")

	# 10. the third room
	if not await _go(SceneRouter.current_room().get_node("Exits/ToVarasto"), "Varasto", "corridor -> Varasto"):
		return
	_check_bounds(Vector2(47, 76), "Varasto map is 47x76")

	var pile: SearchPoint = SceneRouter.current_room().get_node("SearchPoints/LinkinVarasto")
	pile.interact()
	if not await _wait_until(func(): return Dialogue.is_active(), "Varasto dialogue"):
		return
	await _clear_dialogue()
	var pile_mg: Minigame = await _wait_for_minigame()
	if pile_mg == null:
		return
	await _play_varasto(pile_mg)
	_heard.clear()
	if not await _dismiss_minigame("Varasto"):
		return
	_check(GameState.is_searched("varasto"), "Varasto searched")

	# 11. that was the last one -- the ending must trigger off it
	_check(GameState.searched_count() == 4, "all 4 locations searched")
	_check(_all_searched, "all_searched fired on the final location")
	if not await _wait_until(func(): return SceneRouter.is_lost(), "ending loss screen"):
		return
	_check(true, "searching everything ends on the loss screen")
	_check(_heard.has("voice_loss"), "the ending plays the voice line too")
	var ending: Label = SceneRouter._loss.get_node("Reason")
	_check(ending.text == "paitaa ei ole, hävisit pelin :D", "ending reason reads \"paitaa ei ole, hävisit pelin :D\"")

	# 12. and it starts over from the corridor, like the other two endings
	await _dismiss_loss()
	if not await _wait_until(func(): return not SceneRouter.is_busy(), "restart after the ending"):
		return
	_check(SceneRouter.current_room().name == "Kaytava", "restart after the ending returns to the corridor")
	_check(GameState.searched_count() == 0, "restart after the ending clears progress")


## Click past a finished task's closing line. Stops if the world is already
## being ended -- the last task rolls straight into the loss screen, and this
## must not go on to dismiss that too.
func _dismiss_minigame(what: String) -> bool:
	var guard := 0
	while get_tree().paused and not SceneRouter.is_lost() and guard < 60:
		var ev := InputEventAction.new()
		ev.action = "interact"
		ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().process_frame
		await get_tree().process_frame
		guard += 1
	if guard >= 60:
		_fail("%s: closing line would not dismiss" % what)
		return false
	return true


func _dismiss_loss() -> void:
	var guard := 0
	while SceneRouter.is_lost() and guard < 60:
		var ev := InputEventAction.new()
		ev.action = "interact"
		ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().process_frame
		await get_tree().process_frame
		guard += 1


## A door that ends the run: it must freeze the world, say why, and restart
## cleanly back into the corridor.
func _lose_by(path: String, expected: String, what: String) -> void:
	var door: Door = SceneRouter.current_room().get_node(path)
	_heard.clear()
	door.interact()
	if not await _wait_until(func(): return SceneRouter.is_lost(), "%s loss screen" % what):
		return
	_check(get_tree().paused, "%s: world freezes on the loss screen" % what)
	_check(_heard.has("voice_loss"), "%s: loss screen plays the voice line" % what)

	var reason: Label = SceneRouter._loss.get_node("Reason")
	_check(reason.text == expected, "%s: reason reads \"%s\"" % [what, expected])

	await _dismiss_loss()
	if not await _wait_until(func(): return not SceneRouter.is_busy(), "%s restart" % what):
		return
	_check(not get_tree().paused, "%s: restart unpauses" % what)
	_check(SceneRouter.current_room().name == "Kaytava", "%s: restart returns to the corridor" % what)
	_check(GameState.searched_count() == 0, "%s: restart clears progress" % what)


func _go(door: Door, room_name: String, what: String) -> bool:
	door.interact()
	if not await _wait_until(
		func(): return not SceneRouter.is_busy() and SceneRouter.current_room().name == room_name,
		what
	):
		return false
	_check(true, what)
	return true


func _check_bounds(expected: Vector2, what: String) -> void:
	var room := SceneRouter.current_room()
	_check(room is Room and (room as Room).bounds().size == expected, what)


## Both cabinets: drag everything onto the floor. A bad drop must cost nothing.
func _play_dig_out(mg: Minigame, what: String) -> void:
	var panels: Array = mg._panels
	_check(panels.size() == mg.contents.size(), "%s built %d items" % [what, mg.contents.size()])

	# Drop one item somewhere invalid first: it must bounce home, not be lost.
	# Ask _pick which one is actually on top -- items can be stacked.
	var first: Panel = mg._pick(panels[0].position + panels[0].size * 0.5)
	var home: Vector2 = first.position
	_drag(mg, first, Vector2(160, 12))
	_check(first.position == home, "%s: invalid drop returns the item home" % what)
	_check(not mg._out[first], "%s: invalid drop does not count as progress" % what)

	# Take whatever is on top at each shelf until the cabinet is empty. Walking
	# the panel list in order would not do: contents can be stacked, and a
	# panel's position changes the moment it is dragged.
	var guard := 0
	while guard < panels.size() * 4:
		guard += 1
		var buried: Panel = null
		for p: Panel in panels:
			if not mg._out[p]:
				buried = p
				break
		if buried == null:
			break
		var top: Panel = mg._pick(buried.position + buried.size * 0.5)
		_drag(mg, top if top != null else buried, Vector2(60, 120))
		await get_tree().process_frame

	_check(guard < panels.size() * 4, "%s: cabinet emptied without stalling" % what)


## The distinct labels on a dig-out task's items.
func _item_names(mg: Minigame) -> Array[String]:
	var names: Array[String] = []
	for p: Panel in mg._panels:
		for child in p.get_children():
			if child is Label and not names.has((child as Label).text):
				names.append((child as Label).text)
	names.sort()
	return names


## Varasto: the heap comes apart top-down, and a buried thing cannot be taken.
func _play_varasto(mg: Minigame) -> void:
	_check(mg._stack.size() == mg.PILE.size(), "heap built %d things" % mg.PILE.size())

	var bottom: Panel = mg._stack[0]
	var spot: Vector2 = _uncovered_point(mg, bottom)
	_check(spot != Vector2.INF, "bottom of the heap is partly visible")
	if spot != Vector2.INF:
		var before: int = mg._stack.size()
		_click(mg, spot)
		_check(mg._stack.size() == before, "buried thing cannot be taken")
		_check(mg._stack.has(bottom), "buried thing stays in the heap")

	while not mg._stack.is_empty():
		var top: Panel = mg._stack[-1]
		_click(mg, top.position + top.size * 0.5)
		await get_tree().process_frame


## A point on `panel` that no other remaining panel covers.
func _uncovered_point(mg: Minigame, panel: Panel) -> Vector2:
	for dy in range(2, int(panel.size.y) - 1, 2):
		for dx in range(2, int(panel.size.x) - 1, 2):
			var p: Vector2 = panel.position + Vector2(dx, dy)
			if mg._pick(p) == panel:
				return p
	return Vector2.INF


func _click(mg: Minigame, at: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	mg._gui_input(press)


func _drag(mg: Minigame, panel: Panel, to: Vector2) -> void:
	var from: Vector2 = panel.position + panel.size * 0.5

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	mg._gui_input(press)

	var move := InputEventMouseMotion.new()
	move.position = to
	mg._gui_input(move)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to
	mg._gui_input(release)


func _wait_for_minigame() -> Minigame:
	var found: Array[Minigame] = []
	var ok := await _wait_until(func():
		for layer in SceneRouter.get_children():
			if layer.name != "MinigameLayer":
				continue
			for c in layer.get_children():
				if c is Minigame:
					found.append(c)
					return true
		return false
	, "minigame appears")
	if not ok:
		return null
	_check(true, "minigame appears")
	return found[0]


## Clicks through however many lines are on screen.
func _clear_dialogue() -> void:
	var guard := 0
	while Dialogue.is_active() and guard < 60:
		var ev := InputEventAction.new()
		ev.action = "interact"
		ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().process_frame
		await get_tree().process_frame
		guard += 1


func _wait_until(cond: Callable, what: String) -> bool:
	for i in TIMEOUT_FRAMES:
		if cond.call():
			return true
		await get_tree().process_frame
	_fail("timed out waiting for: %s" % what)
	return false


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   %s" % what)
	else:
		_fail(what)


func _fail(what: String) -> void:
	_failures.append(what)
	print("  FAIL %s" % what)


func _report() -> void:
	print("")
	if _failures.is_empty():
		print("smoke: %d checks passed" % _checks)
		get_tree().quit(0)
	else:
		print("smoke: %d FAILED of %d checks" % [_failures.size(), _checks])
		get_tree().quit(1)
