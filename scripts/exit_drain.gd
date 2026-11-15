# exit_drain.gd
# The goal: a giant glowing drain. Reach it with at least 3 socks to win.
extends Node2D

signal reached(body: Node2D)

const Art = preload("res://scripts/art.gd")
const OUTLINE := Color(0.16, 0.11, 0.22)

var player_inside := false
# A boss level keeps the drain locked until the boss is defeated.
var locked := false
var _t := 0.0
var _foam: CPUParticles2D


func _ready() -> void:
	z_index = 1
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2 # only the player
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(90, 140)
	shape.shape = rect
	shape.position = Vector2(0, -70)
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	# Sparkly foam rising out of the drain
	var foam := CPUParticles2D.new()
	foam.texture = Art.soft_circle()
	foam.amount = 30
	foam.lifetime = 2.0
	foam.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	foam.emission_rect_extents = Vector2(50, 4)
	foam.direction = Vector2.UP
	foam.spread = 20.0
	foam.initial_velocity_min = 30.0
	foam.initial_velocity_max = 90.0
	foam.gravity = Vector2(0, -20)
	foam.scale_amount_min = 0.3
	foam.scale_amount_max = 0.9
	foam.color = Color(0.7, 1.0, 0.95, 0.9)
	foam.color_ramp = Art.fade_gradient()
	foam.position = Vector2(0, -6)
	add_child(foam)
	_foam = foam


func _on_body_entered(body: Node2D) -> void:
	player_inside = true
	reached.emit(body)


func _on_body_exited(_body: Node2D) -> void:
	player_inside = false


func _process(delta: float) -> void:
	_t += delta
	_foam.emitting = not locked
	queue_redraw()


func _draw() -> void:
	var glow := 0.5 + 0.5 * sin(_t * 3.0)
	if locked:
		# closed with a heavy lid: no light, no glow
		var lid := Art.ellipse(Vector2(0, -4), 60, 15, 32)
		draw_colored_polygon(lid, Color("636e72"))
		var lid_rim := lid.duplicate()
		lid_rim.append(lid[0])
		draw_polyline(lid_rim, OUTLINE, 3.0, true)
		draw_string(ThemeDB.fallback_font, Vector2(-70, -40), "LOCKED", HORIZONTAL_ALIGNMENT_CENTER, 140, 22, Color(1, 1, 1, 0.6))
		return
	# beam of light
	draw_colored_polygon(PackedVector2Array([Vector2(-45, 0), Vector2(45, 0), Vector2(85, -260), Vector2(-85, -260)]),
		Color(0.5, 1.0, 0.95, 0.10 + glow * 0.08))
	# glowing rings
	for i in 4:
		draw_colored_polygon(Art.ellipse(Vector2(0, -4), 70.0 + i * 14.0 + glow * 6.0, 18.0 + i * 5.0, 32),
			Color(0.4, 1.0, 0.9, 0.18 - i * 0.035))
	# the drain itself
	var hole := Art.ellipse(Vector2(0, -4), 60, 15, 32)
	draw_colored_polygon(hole, Color("2d3436"))
	for i in range(-4, 5):
		var x := i * 11.0
		var h := 15.0 * sqrt(maxf(0.0, 1.0 - pow(x / 60.0, 2.0)))
		draw_line(Vector2(x, -4 - h * 0.8), Vector2(x, -4 + h * 0.8), Color("b2bec3"), 3.0)
	var rim := hole.duplicate()
	rim.append(hole[0])
	draw_polyline(rim, Color("dfe6e9"), 5.0, true)
	# swirling foam dots
	for i in 6:
		var a := _t * 2.5 + i * TAU / 6.0
		draw_circle(Vector2(cos(a) * 50.0, -4 + sin(a) * 11.0), 4.0, Color(1, 1, 1, 0.8))
	draw_string(ThemeDB.fallback_font, Vector2(-70, -175), "EXIT", HORIZONTAL_ALIGNMENT_CENTER, 140, 44,
		Color(1, 1, 1, 0.7 + 0.3 * glow))
