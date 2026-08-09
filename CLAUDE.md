# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Linkin TEK-paita peli" — a Godot 4.6 game project. A 2D top-down Sakari-like: the player searches Kattila and Varasto for a TEK shirt, each place gated behind an Among Us-style minigame, and the game ends in a scripted loss because there is no shirt. In-game text is Finnish; code, filenames and comments are English.

**Read `DESIGN.md` before doing any implementation work** — it holds the location list, the minigame specs, the ending, and the three architectural contracts (minigame base class, router-hosted minigames, `GameState` progress signals) that the whole codebase is organized around.

Build state: **the game is playable start to finish — title screen, three rooms, four locations, three endings.** Three rooms (Käytävä, Kattila, Varasto), four locations — three with minigames, plus Algo which is dialogue-only by design. `main.tscn` boots to the title screen with the tree paused and no room loaded; **Aloita** starts a run. Interior wall collision and §5's message-to-hallitus/credits are what remain. See DESIGN.md §7.

New minigames go in `minigames/<location_id>/` extending `Minigame`, which supplies the shared chrome (`build_chrome`, `make_item`, `set_hint`, `finish`, `nudge`). For another empty-the-cabinet task, extend `DigOutMinigame` instead and override `configure()` — title, contents, closing line, nothing else. Never add a failure path: a wrong move shakes and explains itself, and must not take progress back.

## Commands

The engine is installed system-wide as `godot` (4.6.3 stable).

```sh
godot                              # play the game
godot -e                           # open the editor
godot res://world/rooms/kattila.tscn   # run one scene directly (note: no autoloads-dependent boot)
godot --headless res://tests/smoke.tscn   # end-to-end test, exits 0/1
godot --headless --import          # reimport and report script/scene errors, no UI
godot --check-only -s some.gd      # parse-check one script
```

The smoke test prints `ObjectDB instances leaked at exit` — one suspended coroutine caught by `quit()` mid-frame. It is a harness artifact, not a game bug: `godot --headless --quit-after 240` exits clean. Judge the run by the `smoke:` line and the exit code.

`tests/smoke.tscn` is the only test. It instances `main.tscn` and drives the real components — doors, dialogue, the minigame's own `_gui_input` — rather than poking `GameState`, so it fails if any of the three contracts breaks. Run it after any change to the router, dialogue, or a search point. There is no linter or build script; export templates are not installed.

Screenshots are the only way to catch layout bugs (Godot `Label`s silently grow past a size you set, spilling text outside their parent). A throwaway scene that instances `main.tscn`, awaits `RenderingServer.frame_post_draw`, and calls `get_viewport().get_texture().get_image().save_png(...)` works; a display is available.

## Engine configuration

These are deliberate settings in `project.godot`; changing them has project-wide consequences:

- **Renderer: GL Compatibility** (`gl_compatibility` for both desktop and mobile). Forward+/Mobile-only features — most notably SDFGI, volumetric fog, and many `Environment` effects — will silently do nothing. Verify visual features are Compatibility-supported before relying on them.
- **3D physics: Jolt.** Relevant only if 3D is added; the 2D pipeline is unaffected.
- **Windows rendering device driver: d3d12.**

- **Viewport is 320×180** with `canvas_items` stretch and nearest filtering. `GameCamera` picks integer zoom (max 2) per room and scrolls within the map's bounds.

## Conventions

- Room scenes are named in Finnish (`Kattila`, `Kaytava`) without diacritics in node names and filenames, since `SpawnPoints/<id>` lookups are string-matched. Player-visible text keeps its ä/ö.
- **Maps are PNGs at 1:1** — an uncentred `Sprite2D` at the origin, so image pixel = world position. Interactables are marked in the artwork: **yellow = search, cyan = door, magenta = person**. Run `python3 tools/scan_map.py` to print their coordinates rather than measuring by hand, and re-run it after any map is redrawn. A door's destination comes from the region colour it opens onto (käytävä: red = Aula, blue = Kattila, green = outdoors, orange = Varasto) and is set by hand on the `Door`.
- Only the map's outer edge collides (`Room._build_boundary()`). Walls drawn inside the art are still walkable.
- Rooms are referenced by **path string**, never `preload`/`ExtResource` — Kattila and Käytävä point at each other, which as resource references is a load-time cycle.
- Never `await SceneRouter.go_to_room(...)` from a node inside the room being left: the transition frees it, and the coroutine errors on resume.
- Ending the run goes through `SceneRouter.lose(reason)` — don't add a second game-over path. A `Door` with a non-empty `loss_reason` loses instead of leading anywhere.
- Sound goes through the `Audio` autoload (`step`, `voice_intro`, `voice_loss`). Every clip is optional: a missing file is skipped at load and playing it is a silent no-op, so never guard call sites with existence checks. Headless runs use a dummy audio driver — to check playback really starts, run windowed and inspect `AudioStreamPlayer.playing`.
- `tests/smoke.gd` must keep `$Main.process_mode = PAUSABLE`. The harness node is `PROCESS_MODE_ALWAYS` and `Main` is its child, so without it the game ignores pause — the player then walks around under minigames and steals keypresses meant for overlays. `main.tscn` is the root scene in the real build and pauses correctly.
- The player is not a child of any room. It lives under `main.tscn` and is teleported to `SpawnPoints/<id>` by the router.
- `.godot/` is gitignored — it is regenerated cache and should never be edited or committed. `.editorconfig` sets UTF-8, `.gitattributes` normalizes to LF.
- Scene and resource files are text (`format=3`) and can be edited directly, but `uid://` values and `unique_id` attributes are engine-assigned — don't hand-write or copy them between nodes.
