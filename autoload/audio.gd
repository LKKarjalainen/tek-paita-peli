extends Node
## Sound effects and the voice channel.
##
## Every clip is optional. A slot with no file on disk is skipped at load and
## playing it does nothing, so the game runs fine before the audio has been
## recorded -- drop the file in and it starts working with no code change.

signal played(clip: String)

const CLIPS := {
	"step": "res://audio/step.wav",
	"voice_intro": "res://audio/intro.wav",
	"voice_loss": "res://audio/loss.wav",
}

## Enough for footsteps to overlap without cutting each other off.
const SFX_VOICES := 6

var _clips: Dictionary = {}
var _sfx: Array[AudioStreamPlayer] = []
var _voice: AudioStreamPlayer
var _next := 0


func _ready() -> void:
	# Sound keeps going while the world is frozen under a minigame or the loss
	# screen -- those are exactly the moments something needs to be heard.
	process_mode = Node.PROCESS_MODE_ALWAYS

	var missing: Array[String] = []
	for clip: String in CLIPS:
		var path: String = CLIPS[clip]
		if ResourceLoader.exists(path):
			_clips[clip] = load(path)
		elif not missing.has(path):
			missing.append(path)
	if not missing.is_empty():
		print("audio: silent, no file at %s" % ", ".join(missing))

	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)

	_voice = AudioStreamPlayer.new()
	_voice.name = "Voice"
	add_child(_voice)


func has(clip: String) -> bool:
	return _clips.has(clip)


## Fire and forget, round-robined across the pool.
func play(clip: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not _clips.has(clip):
		return
	var p: AudioStreamPlayer = _sfx[_next]
	_next = (_next + 1) % _sfx.size()
	p.stream = _clips[clip]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()
	played.emit(clip)


## The voice channel: one line at a time, and a new line cuts off the old one
## so restarting mid-sentence does not leave two takes talking over each other.
func say(clip: String) -> void:
	if not _clips.has(clip):
		return
	_voice.stream = _clips[clip]
	_voice.play()
	played.emit(clip)


func stop_voice() -> void:
	_voice.stop()
