# backdrop.gd
# The background: the inside of a giant machine with rows of holes, clotheslines
# with hanging socks, and the swirling portal you came through.
# Each world gives it different colours (see THEMES in level.gd).
extends Node2D

const OUTLINE := Color(0.16, 0.11, 0.22)

var level_width := 3200.0
var top_y := -600.0               # how high the level goes
var sky: Array = []               # 5 colours, from top to bottom
var hole_color := Color(1, 1, 1, 0.13)
var lines: Array = []             # clotheslines: [point_a, point_b]
var show_king := false            # draw the Dryer King far away (world 3)
var _t := 0.0


func _ready() -> void:
	z_index = -100 # behind everything


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# Levels are very long, so we only draw the part near the camera.
	var cam := get_viewport().get_camera_2d()
	var cam_x := cam.get_screen_center_position().x if cam != null else 640.0
	var left := cam_x - 1100.0
	var right := cam_x + 1100.0

	# Coloured bands
	var total := 900.0 - top_y
	var band_h := total / sky.size()
	for i in sky.size():
		draw_rect(Rect2(left, top_y + i * band_h, right - left, band_h + 1.0), sky[i])

	# Rows of holes, like the inside of a washing machine drum
	var row := 0
	var first_x := int(floor(left / 110.0)) * 110
	for y in range(int(top_y) + 60, 600, 110):
		var shift := 55 if row % 2 == 1 else 0
		for x in range(first_x, int(right) + 110, 110):
			draw_circle(Vector2(x + shift, y), 22.0, hole_color)
		row += 1

	for line in lines:
		if line[1].x > left and line[0].x < right:
			_draw_clothesline(line[0], line[1])
	if left < 400.0:
		_draw_portal(Vector2(120, 380))
	if show_king and right > level_width - 400.0:
		_draw_dryer_king(Vector2(level_width - 180.0, 170))


func _draw_clothesline(a: Vector2, b: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in 21:
		var k := i / 20.0
		pts.append(a.lerp(b, k) + Vector2(0, sin(k * PI) * 30.0)) # the line sags
	draw_polyline(pts, Color(1, 1, 1, 0.6), 2.0, true)
	var sock_colors := [Color("ff7675"), Color("74b9ff"), Color("55efc4"), Color("ffeaa7"), Color("a29bfe")]
	for i in range(2, 20, 4):
		var p := pts[i]
		var col: Color = sock_colors[int(i / 4.0) % sock_colors.size()]
		col.a = 0.7
		# A hanging sock, swinging a little
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
	var body := Color(0.1, 0.08, 0.12, 0.75)
	draw_rect(Rect2(c.x - 150, c.y - 110, 300, 330), body)
	draw_circle(c + Vector2(0, 80), 100.0, Color(0.3, 0.25, 0.3, 0.8))
	draw_circle(c + Vector2(0, 80), 80.0, Color(0.08, 0.06, 0.1, 0.9))
	var eye := Color(1.0, 0.2 + 0.2 * sin(_t * 4.0), 0.2)
	draw_circle(c + Vector2(-45, -55), 14.0, eye)
	draw_circle(c + Vector2(45, -55), 14.0, eye)
	draw_line(c + Vector2(-75, -85), c + Vector2(-25, -68), Color.BLACK, 8.0)
	draw_line(c + Vector2(75, -85), c + Vector2(25, -68), Color.BLACK, 8.0)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-90, -110), c + Vector2(-90, -170), c + Vector2(-45, -135), c + Vector2(0, -185),
		c + Vector2(45, -135), c + Vector2(90, -170), c + Vector2(90, -110),
	]), Color("fdcb6e"))
