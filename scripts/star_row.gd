# star_row.gd
# Draws 3 stars in a row: gold ones for stars you earned, dark ones for the rest.
extends Control

var stars := 0:
	set(value):
		stars = value
		queue_redraw()
var star_size := 14.0


func _ready() -> void:
	custom_minimum_size = Vector2(star_size * 7.0, star_size * 2.4)


func _draw() -> void:
	for i in 3:
		var center := Vector2(size.x / 2.0 + (i - 1) * star_size * 2.3, size.y / 2.0)
		var pts := PackedVector2Array()
		for k in 10:
			var r := star_size if k % 2 == 0 else star_size * 0.45
			var a := -PI / 2.0 + k * PI / 5.0
			pts.append(center + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, Color("ffd23f") if i < stars else Color(0.16, 0.11, 0.22, 0.6))
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, Color(0.16, 0.11, 0.22), 2.0, true)
