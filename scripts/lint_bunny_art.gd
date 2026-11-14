# lint_bunny_art.gd
# Draws the Lint Bunny: fluffy circles, long ears, angry red eyes.
# When stunned it turns a bit green and stars spin around its head.
extends Node2D

const Art = preload("res://scripts/art.gd")
const OUTLINE := Color(0.16, 0.11, 0.22)

var facing := 1.0:
	set(value):
		facing = value
		queue_redraw()
var stunned := false:
	set(value):
		stunned = value
		queue_redraw()

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if stunned:
		queue_redraw() # the stars move, so redraw every frame


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1.0))
	var fur := Color(0.72, 0.85, 0.5) if stunned else Color(0.78, 0.76, 0.84)
	var dark := fur.darkened(0.25)

	# Ears (drawn first so the body covers their bottom)
	draw_colored_polygon(Art.ellipse(Vector2(-6, -50), 5, 15), dark)
	draw_colored_polygon(Art.ellipse(Vector2(5, -53), 5.5, 16), fur)
	draw_colored_polygon(Art.ellipse(Vector2(5, -53), 2.5, 11), Color("fab1a0"))

	# Fluffy body = many overlapping circles
	for p in [Vector2(-12, -16), Vector2(11, -16), Vector2(0, -26), Vector2(-6, -9), Vector2(8, -9), Vector2(0, -14)]:
		draw_circle(p, 13.0, fur)
	draw_circle(Vector2(-23, -15), 6.0, Color.WHITE) # fluffy tail

	# Bits of colourful lint stuck in the fur
	for speck in [[Vector2(-10, -20), Color("74b9ff")], [Vector2(6, -6), Color("fd79a8")], [Vector2(-3, -30), Color("ffeaa7")]]:
		draw_circle(speck[0], 2.2, speck[1])

	# Face
	if stunned:
		# swirly dizzy eyes
		draw_arc(Vector2(4, -24), 3.5, 0.0, TAU * 0.8, 10, OUTLINE, 1.5)
		draw_arc(Vector2(13, -24), 3.5, 0.0, TAU * 0.8, 10, OUTLINE, 1.5)
		for i in 3:
			var a := _t * 4.0 + i * TAU / 3.0
			_draw_star(Vector2(cos(a) * 20.0, -62.0 + sin(a) * 5.0), 5.0)
	else:
		draw_circle(Vector2(4, -24), 3.2, Color("d63031"))
		draw_circle(Vector2(13, -24), 3.2, Color("d63031"))
		# angry eyebrows
		draw_line(Vector2(0, -31), Vector2(7, -28), OUTLINE, 2.5)
		draw_line(Vector2(17, -31), Vector2(10, -28), OUTLINE, 2.5)
	draw_circle(Vector2(18, -18), 2.0, Color("e17055")) # nose


func _draw_star(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var radius := r if i % 2 == 0 else r * 0.45
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, Color("ffd23f"))
