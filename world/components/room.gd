class_name Room
extends Node2D
## A room is a hand-drawn PNG pinned at the origin, uncentred and unscaled, so
## image pixel (x, y) IS world (x, y). Marker coordinates read off the artwork
## by tools/scan_map.py drop straight into the scene with no conversion.

@onready var map: Sprite2D = $Map


func _ready() -> void:
	_build_boundary()


func bounds() -> Rect2:
	return Rect2(Vector2.ZERO, map.texture.get_size())


## A wall around the drawn area so you cannot walk off the map. Interior walls
## are NOT derived from the art -- furniture and partitions are still walkable.
func _build_boundary() -> void:
	const T := 24.0
	var b := bounds()
	var body := StaticBody2D.new()
	body.name = "Boundary"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)

	var sides := [
		Rect2(b.position.x - T, b.position.y - T, b.size.x + T * 2.0, T),
		Rect2(b.position.x - T, b.end.y, b.size.x + T * 2.0, T),
		Rect2(b.position.x - T, b.position.y, T, b.size.y),
		Rect2(b.end.x, b.position.y, T, b.size.y),
	]
	for r: Rect2 in sides:
		var shape := RectangleShape2D.new()
		shape.size = r.size
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = r.position + r.size * 0.5
		body.add_child(cs)
