# Linkin TEK-paita peli — suunnitteludokumentti

A 2D top-down single-player Sakari-like. You search Kattila for Linkin TEK shirt. There is no shirt. You lose.

---

## 1. The premise

The player is a Linkin hallituslainen who is searching for the TEK shirt somewhere. They search various places. At each one, someone makes them do a among sus minigame first. After the last place, they lose.

**Minigames cannot be failed**, only fumbled and repeated. That futility is the whole game.

**Language:** all in-game text is Finnish. Code, filenames and comments are English.

---

## 2. Core loop

```
Käytävä (hub)
	  │
	  ├─ walk to a door ─→ room scene loads
	  │                          │
	  │                     talk to NPC
	  │                          │
	  │                    "Missä TEK-paita?"
	  │                          │
	  │                     "kysyin. ei oo nähty."
	  │                          │
	  │                      Search place
	  │                          │
	  │                     ── MINIGAME ──   (overlay, world paused)
	  │                          │
	  │                    location marked searched
	  │                          │
	  └──────── back to hub ─────┘

after 5/5 → lose
```

Five searches, an intro and an ending land at **~10 minutes**.

---

## 3. Structure and gating

Locations are fully free-order.

| # | Location | Notes |
|---|---|---|
| 1 | **Hallitus kaappi** (Kattila) | |
| 2 | **Tapsa kaappi** (Kattila) | |
| 3 | **Kysy Algolta** (Kattila) | NPC dialog |
| 4 | **Linkin varasto** (Varasto) | |

---

## 4. The places

### Hub — Käytävä

The corridor connecting Kattila, Varasto, Aula and the outside.


### Kattila

Linkki and Algo Guild room. Has Hallitus kaappi, Tapsa kaappi and Algo-person

### Varasto

Has Linkki stuff all in a mess.

---

## 5. The ending

The player sends message to the rest of the hallitus that they can't find the shirt. Player loses the game.
> **PAITAA EI OLE.**
> **HÄVISIT.**

Credits roll over.


---

## 6. Technical design

Godot 4.6, GL Compatibility renderer. Microsoft Paint vibe at a **320×180** base viewport, `canvas_items` stretch, `keep` aspect, integer scaling.

### Project layout

```
main.tscn / main.gd    boot: holds World + the persistent Player, hands both to the router
autoload/
  game_state.gd        progress + signals
  scene_router.gd      room transitions, fades, minigame hosting
  dialogue.gd          owns the dialogue box, awaitable `say()`
  audio.gd             one-shot sfx/music helper
actors/player/         player.tscn (CharacterBody2D) + player.gd
actors/game_camera.gd  per-room framing
world/
  maps/                the hand-drawn PNGs -- kaytava, kattila, varasto
  rooms/kaytava.tscn, kattila.tscn, varasto.tscn, aula.tscn, outside.tscn
  components/room.gd, interactable.gd, door.gd, search_point.gd, npc.gd
audio/
  step.wav, intro.wav, loss.wav
tools/
  scan_map.py          reads marker coordinates off a map PNG
minigames/
  minigame.gd          base class — the contract below
  hallitus_kaappi/ tapsa_kaappi/ varasto/
ui/
  dialogue_box.tscn, title_screen.tscn, loss_screen.tscn
tests/
  smoke.tscn           headless end-to-end run of the loop
```

The fade is built in code by the router rather than being a scene, so nothing has to remember to include it.

### The three contracts worth getting right

Everything else is ordinary Godot. These three are what make the game composable, and they're the parts that span files.

**1. Minigame contract.** Every minigame is a `Control` extending a common base, and exposes exactly one signal. Because nothing can be failed, there is no `failed` signal — that absence *is* the design, enforced in code:

```gdscript
# minigames/minigame.gd
class_name Minigame extends Control

signal completed          ## the only exit. there is no failure path.

func start() -> void:     ## override: set up and begin
	pass
```

**2. The router owns every transition.** Both kinds of context switch — walking into a room, and opening a minigame — go through `SceneRouter`, so nothing else needs to know how the world is assembled.

Käytävä has four doors, so "where does the player appear" is no longer one fixed spot: coming back from Varasto must put you at the Varasto door, not at the Kattila one. Rooms expose named spawn markers and the caller picks one.

Rooms are addressed by **path, not `PackedScene`**. Kattila's door points at the corridor and the corridor's door points back at Kattila; as `ExtResource` references that is a load-time dependency cycle, as strings it is nothing.

```gdscript
# autoload/scene_router.gd
func go_to_room(room_path: String, spawn_id: String) -> void:
	await fade_out()
	_world.remove_child(_current_room)   # out of the tree now, freed on idle
	_current_room.queue_free()
	_current_room = (load(room_path) as PackedScene).instantiate()
	_world.add_child(_current_room)
	_player.global_position = _current_room.get_node("SpawnPoints/" + spawn_id).global_position
	await fade_in()
```

Callers must **not** `await` this: the transition frees the room the calling door lives in, and a coroutine suspended on a freed node errors when it resumes.

A minigame is never a child of a room scene. The router instantiates it onto a `CanvasLayer` above the world and pauses the tree; the layer is `PROCESS_MODE_ALWAYS` so it keeps running while everything below is frozen.

```gdscript
# autoload/scene_router.gd
func play_minigame(scene: PackedScene, location_id: String) -> void:
	var mg: Minigame = scene.instantiate()
	_minigame_layer.add_child(mg)
	get_tree().paused = true
	mg.completed.connect(_finish_minigame.bind(mg, location_id))
	mg.start()

func _finish_minigame(mg: Minigame, location_id: String) -> void:
	mg.queue_free()
	get_tree().paused = false
	GameState.mark_searched(location_id)
```

Because the minigame is decoupled from the room, Kattila can host three searches in one scene without nesting anything, and Varasto can host one, using identical code.

The base class also owns the chrome every task shares — backdrop, title, the status line at the foot, `finish()`, and `nudge()` for wrong-move feedback that costs nothing. A subclass supplies only its mechanic:

| Task | Verb | Script |
|---|---|---|
| Hallituksen kaappi | drag things out to a target area | `DigOutMinigame` subclass, data only |
| Tapsan kaappi | same, but the cabinet holds five Jaloviina | `DigOutMinigame` subclass, data only |
| Linkin varasto | click in z-order — the heap comes apart top-down | its own mechanic |

The two cabinets share `minigames/dig_out.gd`; each is a `configure()` override setting a title, a list of contents and a closing line. Adding another cabinet-emptying task is a five-line file.

**3. GameState owns progress; rooms only report.** Rooms never ask each other anything. Gating and the ending both read from here.

```gdscript
# autoload/game_state.gd
signal location_searched(id: String)
signal all_searched

const LOCATIONS := ["hallitus_kaappi", "tapsa_kaappi", "algo", "varasto"]

var searched: Dictionary = {}

func is_searched(id: String) -> bool:
	return searched.get(id, false)

func mark_searched(id: String) -> void:
	assert(id in LOCATIONS, "unknown location: %s" % id)
	if is_searched(id): return
	searched[id] = true
	location_searched.emit(id)
	if LOCATIONS.all(is_searched):
		all_searched.emit()
```

The ending listens for `all_searched` and takes over. No room needs to know another exists. §3 makes the order fully free, so there is no gating layer at all — if that ever changes, a `REQUIRES` table read by the doors is the whole mechanism, and nothing else has to move.

Counting lives in exactly one place — `LOCATIONS.all(...)`, never a hardcoded number — so adding or removing a location is a one-line change, and the "5/5" in §2 can't silently drift out of step with the four rows in §3.

### Maps

Each room is a hand-drawn PNG in `world/maps/`, placed as an **uncentred, unscaled `Sprite2D` at the origin**. That makes image pixel `(x, y)` identical to world `(x, y)`, so a marker measured on the artwork drops into the scene with no conversion.

Things the player can interact with are marked on the artwork in pure colours, and `tools/scan_map.py` prints ready-to-paste `position = Vector2(x, y)` lines for them:

| Marker | Means |
|---|---|
| yellow `255,255,0` | a place to search |
| cyan `0,255,255` | a doorway |
| magenta `255,0,255` | a person to ask |

Where a doorway *leads* is read off the region colour it opens onto — in käytävä, **red = Aula, blue = Kattila, green = outdoors, orange = Varasto**. That legend is a drawing convention, not something the code checks; the destination is set by hand on each `Door`.

Re-run the scanner whenever a map is redrawn — the coordinates baked into the room scenes are only as fresh as the last run.

The maps are deliberately different shapes — a 159×389 corridor, a 262×191 guild room, a 47×76 closet — so `GameCamera` picks framing per room: integer zoom (max 2) chosen to fill the frame as far as possible **without ever zooming out**, since a corridor is meant to scroll rather than shrink. Rooms smaller than the frame on an axis are centred on it, and a dark `Letterbox` layer fills whatever margin is left.

Only the outer edge of a map is solid, generated by `Room._build_boundary()`. Walls and furniture drawn *inside* the art are not collidable yet.

### Sound

`Audio` is an autoload with a small pool of one-shot players and one dedicated voice channel, so a line cannot be cut off by a footstep and a new line always replaces the old one.

**Every clip is optional.** A slot whose file is missing is skipped at load and playing it does nothing, so a clip can be swapped, removed or added back without touching a call site.

| Clip | File | When |
|---|---|---|
| `step` | `audio/step.wav` | walking |
| `voice_intro` | `audio/intro.wav` | the title screen appears, once per launch |
| `voice_loss` | `audio/loss.wav` | any of the three losses |

`voice_loss` is fired from `SceneRouter.lose()` rather than from each caller, so all three endings speak by construction.

Footsteps are the player's own: one on setting off and one every `STEP_INTERVAL` after, each pitched slightly differently so a long corridor does not become a metronome.

### Starting and restarting

`main.tscn` boots to the title screen with the tree paused and no room loaded — otherwise WASD would walk the parked player around behind the menu. The intro voice line plays once the menu has faded in. Picking **Aloita** fades out, drops the menu, and loads the corridor; **Lopeta** quits.

Restarting after a loss goes straight back into a fresh run rather than to the menu, because the loss screen offers *Uudestaan*, not *päävalikkoon*. Both paths funnel through `main.gd`, the only script that knows where the game begins.

### Losing early

There are three ways to lose and no way to win. All three land on the same screen:

| Trigger | Reason |
|---|---|
| Ulos (green door) | `koskit nurmikkoa, hävisit pelin :D` |
| Aula (red door) | `annoit periks, hävisit pelin :D` |
| Searching every location | `paitaa ei ole, hävisit pelin :D` |

Doing the whole job properly is not a fourth outcome — it is the third way of losing, and it costs the most effort to reach.

A `Door` with a non-empty `loss_reason` calls `SceneRouter.lose()` instead of moving the player, so a losing exit is a field on an ordinary door and not a separate kind of thing. `main.gd` calls the same function from `all_searched`. The loss screen is hosted exactly like a minigame — its own layer above the world, everything below it frozen — and dismissing it emits `restart_requested`, which `main.gd` answers by clearing `GameState` and returning to the start.

§5's remaining pieces — the message to the hallitus and the credits — belong inside this screen, not beside it.

### Room scene convention

Rooms hold a *variable* number of searches — Kattila has three, Varasto has one, Aula and outside have none — so the convention is node groups rather than fixed single nodes:

- `SpawnPoints/<id>` (Marker2D) — one per way in. Kattila entered from the corridor → `SpawnPoints/kaytava`.
- `Exits/*` (Door) — each calls `SceneRouter.go_to_room(target, spawn_id)`
- `SearchPoints/*` (SearchPoint) — zero or more
- `NPCs/*` (NPC) — plain dialogue, no effect on progress

**Searches with and without a minigame.** "Kysy Algolta" is a search made of dialogue only, so `SearchPoint` treats the minigame as optional. This is the one spot where §1 ("someone makes them do a minigame") and §3 ("NPC dialog") disagree — the code supports both, so the writing can settle it later without a refactor.

```gdscript
# world/components/search_point.gd
class_name SearchPoint extends Interactable

@export var location_id: String
@export var lines: Array[String]
@export var minigame: PackedScene   ## leave empty for a dialogue-only search

func interact() -> void:
	if GameState.is_searched(location_id):
		await Dialogue.say(["Tästä on jo katsottu."])
		return
	await Dialogue.say(lines)
	if minigame:
		SceneRouter.play_minigame(minigame, location_id)
	else:
		GameState.mark_searched(location_id)
```

Aula and outside carry no `SearchPoints` at all. They are worth building anyway: a corridor with two live doors and two dead ones reads as a much smaller world than one where every door opens onto something.

### Setup still needed in `project.godot`

- `run/main_scene` — currently unset, so a bare `godot` runs nothing
- Input actions: `move_up/down/left/right`, `interact` (E), `ui_cancel`
- Viewport 320×180, stretch mode `canvas_items`, aspect `keep`
- Texture import default → **Nearest** filtering, or the MS Paint art comes out smeared
- Mouse is a first-class input — the minigames are drag-based, so the cursor must stay visible and unconfined

---

## 7. Build order

Vertical slice first — Käytävä plus one search in Kattila exercises all three contracts before any content is mass-produced.

1. ~~Player movement, `Interactable`, `Dialogue`~~ **done**
2. ~~`GameState` + `SceneRouter` + fade + named spawn points~~ **done**
3. ~~Käytävä → Kattila → **Hallitus kaappi** and back~~ **done** — the whole loop, one search, playable
4. ~~**Tapsa kaappi** — proves a second search in the same room~~ **done**
5. ~~dialogue-only search path~~ **done** — Tapsa, Algo and Varasto all run on it
6. ~~Varasto~~ **done**
7. ~~All four locations placed; game completable end to end~~ **done**
8. ~~Minigames for `tapsa_kaappi` and `varasto`~~ **done** — Algo stays dialogue-only by design, so every location now has its final form
9. ~~All three losses land on a real screen~~ **done** — no placeholders left in the flow
10. Interior wall collision — only the outer edge of each map is solid today
11. The message to the hallitus and the credits, inside the loss screen (§5)
12. Audio pass

The three contracts are proven: two independent searches coexist in Kattila, searches with and without a minigame use the same component, and the ending triggers itself off `GameState` with nothing wired to tell it to. What is left is content, collision, and the ending.
