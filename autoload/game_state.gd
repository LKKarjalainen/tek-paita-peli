extends Node
## Owns all search progress.
##
## Rooms and search points only ever report *into* here; nothing reads progress
## out of a room. That is what keeps Kattila's three searches from having to
## know about each other, or about Varasto.

signal location_searched(id: String)
signal all_searched

## The single source of truth for how many searches exist. Nothing anywhere
## hardcodes a count -- adding a location here is the whole change.
const LOCATIONS: Array[String] = [
	"hallitus_kaappi",
	"tapsa_kaappi",
	"algo",
	"varasto",
]

var searched: Dictionary = {}


func is_searched(id: String) -> bool:
	return searched.get(id, false)


func mark_searched(id: String) -> void:
	assert(id in LOCATIONS, "unknown location id: %s" % id)
	if is_searched(id):
		return
	searched[id] = true
	location_searched.emit(id)
	if LOCATIONS.all(is_searched):
		all_searched.emit()


func searched_count() -> int:
	return searched.size()


func reset() -> void:
	searched.clear()
