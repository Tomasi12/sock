# soap_bubble.gd
# A big soap bubble that floats up and wobbles. Touch it and it pops!
extends Node2D

const Art = preload("res://scripts/art.gd")

var min_x := 0.0
var max_x := 3200.0
var floor_y := 600.0

var radius := 18.0
var _speed := 40.0
var _base_x := 0.0
var _t := 0.0
var _popping := false


func _ready() -> void:
	z_index = 7
	_t = randf() * 10.0
	_reset(true)


func _reset(anywhere := false) -> void:
	radius = randf_range(10.0, 28.0)
	_speed = randf_range(25.0, 60.0)
	_base_x = randf_range(min_x, max_x)
	var start_y := randf_range(-100.0, floor_y) if anywhere else floor_y + 20.0
	position = Vector2(_base_x, start_y)
	scale = Vector2.ONE
	modulate.a = 1.0
	_popping = false
	queue_redraw()


func _process(delta: float) -> void:
	if _popping:
		return
	_t += delta
	position.y -= _speed * delta
	position.x = _base_x + sin(_t * 1.5) * 14.0
	# jiggle: a bit wider, then a bit taller
	scale = Vector2(1.0 + sin(_t * 4.0) * 0.06, 1.0 - sin(_t * 4.0) * 0.06)
	if position.y < -250.0:
		_reset()
		return
	var hero = get_tree().get_first_node_in_group("player")
	if hero != null and (hero.global_position + Vector2(0, -23)).distance_to(global_position) < radius + 18.0:
		pop()


func pop() -> void:
	_popping = true
	Art.burst(get_parent(), position, Color(0.9, 0.97, 1.0, 0.9), 10, 100.0, 0.5)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.08)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.08)
	tw.tween_interval(randf_range(1.0, 3.0))
	tw.tween_callback(_reset)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.85, 0.95, 1.0, 0.18))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(1, 1, 1, 0.75), 2.0)
	draw_arc(Vector2.ZERO, radius * 0.7, PI * 1.1, PI * 1.45, 8, Color(1, 1, 1, 0.9), 3.0)
	draw_arc(Vector2.ZERO, radius - 2.0, 0.2, 1.0, 8, Color(1.0, 0.6, 0.9, 0.5), 2.0) # rainbow shine
