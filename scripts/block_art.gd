# block_art.gd
# Draws one piece of the level: floor, drum wall, laundry basket or giant button.
# The level creates it and tells it its "size" and "style".
extends Node2D

const Art = preload("res://scripts/art.gd")
const OUTLINE := Color(0.16, 0.11, 0.22)

var size := Vector2(100, 100)
var style := "floor"
var tint := Color("fd79a8") # colour of giant buttons


func _draw() -> void:
	match style:
		"floor":
			_draw_steel(Color("7f8fa6"))
		"pit":
			_draw_steel(Color("57606f"))
		"drum":
			_draw_drum()
		"basket":
			_draw_basket()
		"button":
			_draw_button()


# Shiny steel with holes, like the inside of a washing machine drum.
func _draw_steel(col: Color) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), col)
	draw_rect(Rect2(0, 0, size.x, 12), col.lightened(0.45))
	var row := 0
	for y in range(40, int(size.y), 46):
		var shift := 23 if row % 2 == 1 else 0
		for x in range(20, int(size.x) - 20, 46):
			draw_circle(Vector2(x + shift, y), 8.0, col.darkened(0.3))
		row += 1
	draw_rect(Rect2(Vector2.ZERO, size), OUTLINE, false, 3.0)


func _draw_drum() -> void:
	var col := Color("a4b0be")
	draw_rect(Rect2(Vector2.ZERO, size), col)
	# vertical ribs
	for x in range(30, int(size.x), 70):
		draw_rect(Rect2(x, 0, 14, size.y), col.darkened(0.12))
	# rows of holes
	for y in range(40, int(size.y), 50):
		for x in range(15, int(size.x) - 10, 35):
			draw_circle(Vector2(x, y), 6.0, col.darkened(0.35))
	draw_rect(Rect2(0, 0, size.x, 10), col.lightened(0.4))
	draw_rect(Rect2(Vector2.ZERO, size), OUTLINE, false, 3.0)


func _draw_basket() -> void:
	var col := Color("d4a373")
	draw_rect(Rect2(Vector2.ZERO, size), col)
	# woven pattern
	for y in range(14, int(size.y), 12):
		draw_line(Vector2(0, y), Vector2(size.x, y), col.darkened(0.25), 2.0)
	for x in range(0, int(size.x), 16):
		draw_line(Vector2(x, 10), Vector2(x + 8, size.y), col.darkened(0.15), 2.0)
	# handle holes
	draw_colored_polygon(Art.ellipse(Vector2(28, 28), 12, 6), col.darkened(0.5))
	draw_colored_polygon(Art.ellipse(Vector2(size.x - 28, 28), 12, 6), col.darkened(0.5))
	# a T-shirt sleeve hanging out, for fun
	draw_colored_polygon(PackedVector2Array([Vector2(60, 0), Vector2(95, 0), Vector2(100, -12), Vector2(70, -16)]), Color("55efc4"))
	draw_rect(Rect2(-4, 0, size.x + 8, 10), Color("bc6c25")) # rim
	draw_rect(Rect2(Vector2.ZERO, size), OUTLINE, false, 3.0)


# A giant shirt button you can jump on.
func _draw_button() -> void:
	var c := size / 2.0
	draw_colored_polygon(Art.ellipse(c + Vector2(0, 5), size.x / 2.0, size.y / 2.0 + 4.0, 32), tint.darkened(0.35))
	var top := Art.ellipse(c, size.x / 2.0, size.y / 2.0 + 4.0, 32)
	draw_colored_polygon(top, tint)
	var closed := top.duplicate()
	closed.append(top[0])
	draw_polyline(closed, OUTLINE, 3.0, true)
	for h in [Vector2(-12, -3), Vector2(12, -3), Vector2(-12, 4), Vector2(12, 4)]:
		draw_circle(c + h, 4.0, tint.darkened(0.5))
	draw_line(c + Vector2(-12, -3), c + Vector2(12, 4), Color.WHITE, 2.0) # thread
	draw_line(c + Vector2(12, -3), c + Vector2(-12, 4), Color.WHITE, 2.0)
