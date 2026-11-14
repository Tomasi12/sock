# backdrop.gd
# The background: the inside of a giant washing machine drum, clotheslines
# with hanging socks, the swirling portal you came through, and far away...
# the evil Dryer King.
extends Node2D

const OUTLINE := Color(0.16, 0.11, 0.22)

var level_width := 3200.0
var _t := 0.0


func _ready() -> void:
	z_index = -100 # behind everything


func _process(delta: float) -> void:
	_t += delta
	queue_redraw() # the portal swirls and the Dryer King's eyes glow


func _draw() -> void:
	# Soft purple bands
	var colors := [Color("8c7ae6"), Color("9c88ff"), Color("b5a8ff"), Color("cec5ff"), Color("e2dcff")]
	var band_h := 1400.0 / colors.size()
	for i in colors.size():
		draw_rect(Rect2(-600, -600 + i * band_h, level_width + 1200, band_h + 1), colors[i])

	# The drum's holes
	var row := 0
	for y in range(-300, 600, 110):
		var shift := 55 if row % 2 == 1 else 0
		for x in range(-400, int(level_width) + 400, 110):
			draw_circle(Vector2(x + shift, y), 22.0, Color(1, 1, 1, 0.13))
		row += 1

	_draw_clothesline(Vector2(300, 120), Vector2(1100, 150))
	_draw_clothesline(Vector2(1500, 80), Vector2(2400, 120))
	_draw_portal(Vector2(120, 380))
	_draw_dryer_king(Vector2(3020, 170))


func _draw_clothesline(a: Vector2, b: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in 21:
		var k := i / 20.0
		pts.append(a.lerp(b, k) + Vector2(0, sin(k * PI) * 40.0)) # the line sags
	draw_polyline(pts, Color(1, 1, 1, 0.6), 2.0, true)
	var sock_colors := [Color("ff7675"), Color("74b9ff"), Color("55efc4"), Color("ffeaa7"), Color("a29bfe")]
	for i in range(2, 20, 4):
		var p := pts[i]
		var col: Color = sock_colors[(i / 4) % sock_colors.size()]
		col.a = 0.7
		# A hanging sock (upside down, swinging a little)
		draw_set_transform(p, sin(_t * 1.5 + i) * 0.12, Vector2.ONE)
		draw_colored_polygon(PackedVector2Array([Vector2(-8, 0), Vector2(8, 0), Vector2(8, 30), Vector2(20, 34), Vector2(18, 44), Vector2(-8, 42)]), col)
		draw_rect(Rect2(-3, -6, 6, 9), Color("fdcb6e")) # clothes pin
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# The washing machine you came out of: a swirling portal.
func _draw_portal(c: Vector2) -> void:
	draw_rect(Rect2(c.x - 170, c.y - 230, 300, 420), Color("dfe6e9"))
	draw_rect(Rect2(c.x - 170, c.y - 230, 300, 50), Color("b2bec3"))
	for i in 3:
		draw_circle(Vector2(c.x - 130 + i * 40, c.y - 205), 10.0, Color("636e72"))
	draw_rect(Rect2(c.x - 170, c.y - 230, 300, 420), OUTLINE, false, 3.0)
	draw_circle(c, 120.0, Color("b2bec3"))
	draw_circle(c, 100.0, Color("6c5ce7"))
	for i in 7:
		var a := _t * 2.0 + i * TAU / 7.0
		draw_arc(c, 20.0 + i * 11.0, a, a + 2.4, 24, Color(1, 1, 1, 0.45), 5.0)
	draw_arc(c, 120.0, 0.0, TAU, 64, OUTLINE, 4.0)


# The villain, far in the background. He is watching you...
func _draw_dryer_king(c: Vector2) -> void:
	var body := Color("2d3436")
	draw_rect(Rect2(c.x - 150, c.y - 110, 300, 330), body)
	draw_circle(c + Vector2(0, 80), 100.0, Color("636e72"))
	draw_circle(c + Vector2(0, 80), 80.0, Color("1e272e"))
	# trapped socks spinning in his door
	for i in 4:
		var a := -_t * 1.5 + i * TAU / 4.0
		draw_circle(c + Vector2(0, 80) + Vector2(cos(a), sin(a)) * 45.0, 10.0, Color(0.9, 0.5, 0.6, 0.6))
	# glowing angry eyes and eyebrows
	var eye := Color(1.0, 0.2 + 0.2 * sin(_t * 4.0), 0.2)
	draw_circle(c + Vector2(-45, -55), 14.0, eye)
	draw_circle(c + Vector2(45, -55), 14.0, eye)
	draw_line(c + Vector2(-75, -85), c + Vector2(-25, -68), Color.BLACK, 8.0)
	draw_line(c + Vector2(75, -85), c + Vector2(25, -68), Color.BLACK, 8.0)
	# crown
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-90, -110), c + Vector2(-90, -170), c + Vector2(-45, -135), c + Vector2(0, -185),
		c + Vector2(45, -135), c + Vector2(90, -170), c + Vector2(90, -110),
	]), Color("fdcb6e"))
