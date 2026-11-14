# sock_body.gd
# Draws ONE cute sock with simple shapes (no image files!).
#
# Important idea: the sock's FEET are at (0, 0) and the sock grows upwards
# (negative y). When we squash it (scale.y < 1) it stays standing on the ground
# instead of floating, which makes squash-and-stretch look right.
extends Node2D

const SockTypes = preload("res://scripts/sock_types.gd")
const Art = preload("res://scripts/art.gd")

const OUTLINE := Color(0.16, 0.11, 0.22)

# "set(value):" runs every time the variable changes. We use it to redraw.
var kind: int = SockTypes.Kind.HERO:
	set(value):
		kind = value
		queue_redraw()

# 1 = looking right, -1 = looking left.
var facing := 1.0:
	set(value):
		if facing != value:
			facing = value
			queue_redraw()

# 0 = eyes open, 1 = eyes closed. A Tween changes this to make a blink.
var blink := 0.0:
	set(value):
		blink = value
		queue_redraw()

# Dizzy socks have X eyes (after being bonked by a Lint Bunny).
var dizzy := false:
	set(value):
		dizzy = value
		queue_redraw()

var _squash_tween: Tween
var _blink_timer: Timer


func _ready() -> void:
	# A Timer node counts down and then "rings" (timeout signal).
	_blink_timer = Timer.new()
	_blink_timer.one_shot = true
	add_child(_blink_timer)
	_blink_timer.timeout.connect(_on_blink_timer)
	_blink_timer.start(randf_range(1.0, 4.0))


func _on_blink_timer() -> void:
	# A Tween smoothly changes a value over time: close eyes, then open them.
	var tw := create_tween()
	tw.tween_property(self, "blink", 1.0, 0.07)
	tw.tween_property(self, "blink", 0.0, 0.09)
	_blink_timer.start(randf_range(1.5, 5.0))


# Squash and stretch!  start_scale = how squished we start, e.g.
#   Vector2(0.7, 1.35)  = tall and thin (jumping)
#   Vector2(1.4, 0.65)  = flat and wide (landing)
# Then a bouncy "elastic" tween brings the sock back to normal size.
func squash(start_scale: Vector2, duration := 0.45) -> void:
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()
	scale = start_scale
	_squash_tween = create_tween()
	_squash_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(self, "scale", Vector2.ONE, duration)


func _draw() -> void:
	var info: Dictionary = SockTypes.DATA[kind]
	var w: float = info["half_width"]
	var body_color: Color = info["body"]
	# Mirror everything we draw when the sock looks left.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1.0))

	var shape := _outline_points(w)
	draw_colored_polygon(shape, body_color)
	_draw_pattern(info, w)

	# Toe socks get little toes at the front.
	if kind == SockTypes.Kind.TOE:
		for i in 3:
			var p := Vector2(w + 13.0 - i * 1.5, -11.0 + i * 4.5)
			draw_circle(p, 3.4, body_color)
			draw_arc(p, 3.4, -PI * 0.5, PI * 0.5, 8, OUTLINE, 1.5)

	# The cuff (the stretchy band at the top of the sock).
	var cuff := Rect2(-w - 1.5, -52.0, w * 2.0 + 3.0, 8.0)
	draw_rect(cuff, info["cuff"])
	draw_rect(cuff, OUTLINE, false, 2.0)

	# Dark outline around the sock body (cartoon look).
	var closed := shape.duplicate()
	closed.append(shape[0])
	draw_polyline(closed, OUTLINE, 2.0, true)

	_draw_eyes(w)


# The sock shape: a tube (the leg) with a foot pointing forward.
func _outline_points(w: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-w, -46), Vector2(w, -46), Vector2(w, -18),
		Vector2(w + 7, -16), Vector2(w + 13, -12), Vector2(w + 15, -6),
		Vector2(w + 12, -1), Vector2(w + 6, 0), Vector2(-w + 4, 0),
		Vector2(-w - 1, -3), Vector2(-w - 2, -9), Vector2(-w, -14),
	])


func _draw_pattern(info: Dictionary, w: float) -> void:
	var colors: Array = info["pattern_colors"]
	match info["pattern"]:
		"stripes":
			for i in 4:
				draw_rect(Rect2(-w, -42.0 + i * 7.0, w * 2.0, 3.5), colors[i % colors.size()])
		"gym":
			for i in 2:
				draw_rect(Rect2(-w, -42.0 + i * 6.0, w * 2.0, 3.0), colors[0])
		"dots":
			var spots := [Vector2(-0.5, -40), Vector2(0.5, -27), Vector2(-0.4, -20), Vector2(0.1, -9), Vector2(1.3, -6)]
			for s in spots:
				draw_circle(Vector2(s.x * w, s.y), 2.8, colors[0])


func _draw_eyes(w: float) -> void:
	for ex in [-w * 0.45, w * 0.55]:
		var c := Vector2(ex, -33.0)
		if dizzy:
			draw_line(c + Vector2(-3, -3), c + Vector2(3, 3), OUTLINE, 2.0)
			draw_line(c + Vector2(-3, 3), c + Vector2(3, -3), OUTLINE, 2.0)
			continue
		var open := 1.0 - blink
		if open < 0.35:
			# Eyes closed: just a line.
			draw_line(c + Vector2(-4, 0), c + Vector2(4, 0), OUTLINE, 2.0)
		else:
			draw_colored_polygon(Art.ellipse(c, 4.5, 5.0 * open), Color.WHITE)
			draw_colored_polygon(Art.ellipse(c + Vector2(1.5, 0.5), 2.2, 2.6 * open), OUTLINE)
			draw_circle(c + Vector2(2.3, -1.2 * open), 0.9, Color.WHITE) # shiny spot
