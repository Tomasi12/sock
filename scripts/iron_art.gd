# iron_art.gd
# Draws a hot iron. Used by the small Hot Iron enemy and by the Iron Baron boss
# (the boss just draws it much bigger).
extends RefCounted

const OUTLINE := Color(0.16, 0.11, 0.22)


# canvas = the node we draw on.  heat = 0 (calm) to 1 (red hot).
static func draw_iron(canvas: CanvasItem, heat: float, dizzy: bool, t: float) -> void:
	var body := Color("636e72").lerp(Color("e17055"), heat * 0.6)
	# the body: flat at the back, pointy at the front
	var shape := PackedVector2Array([
		Vector2(-30, -6), Vector2(36, -6), Vector2(27, -20), Vector2(8, -32), Vector2(-30, -32),
	])
	canvas.draw_colored_polygon(shape, body)
	# the hot metal plate at the bottom
	var plate := Color("dfe6e9").lerp(Color("ff3f34"), heat)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-31, 0), Vector2(38, 0), Vector2(36, -7), Vector2(-31, -7)]), plate)
	# handle
	canvas.draw_arc(Vector2(-8, -32), 15.0, PI, TAU, 12, Color("2d3436"), 6.0)
	var closed := shape.duplicate()
	closed.append(shape[0])
	canvas.draw_polyline(closed, OUTLINE, 2.0, true)
	# face
	var eye := Vector2(14, -20)
	if dizzy:
		canvas.draw_arc(eye, 4.0, t * 8.0, t * 8.0 + TAU * 0.8, 10, Color.WHITE, 2.0)
	else:
		canvas.draw_circle(eye, 4.5, Color.WHITE)
		canvas.draw_circle(eye + Vector2(1.5, 0.5), 2.2, OUTLINE)
		canvas.draw_line(eye + Vector2(-6, -7), eye + Vector2(5, -4), OUTLINE, 2.5) # angry eyebrow
	# steam puffs when hot
	if heat > 0.3:
		for i in 3:
			var k := fposmod(t * 1.5 + i / 3.0, 1.0)
			canvas.draw_circle(Vector2(-20 + i * 14, -36 - k * 26.0), 3.0 + k * 5.0, Color(1, 1, 1, 0.6 * (1.0 - k)))
