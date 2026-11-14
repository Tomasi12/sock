# water.gd
# A soapy puddle. Socks HATE getting wet: touch the deep part and you go
# back to the last checkpoint.
#
# This one is built from Polygon2D (a filled shape) and Line2D (a line),
# and we move their points every frame to make waves.
extends Node2D

signal soaked(body: Node2D)

var size := Vector2(260, 55)
var _t := 0.0
var _water: Polygon2D
var _surface: Line2D
var _foam: CPUParticles2D

const Art = preload("res://scripts/art.gd")


func _ready() -> void:
	z_index = 3
	_water = Polygon2D.new()
	_water.color = Color(0.45, 0.72, 1.0, 0.6)
	add_child(_water)

	_surface = Line2D.new()
	_surface.width = 4.0
	_surface.default_color = Color(1, 1, 1, 0.85)
	add_child(_surface)

	# Foam bubbles popping on top of the water
	_foam = CPUParticles2D.new()
	_foam.texture = Art.bubble_texture()
	_foam.amount = 14
	_foam.lifetime = 1.4
	_foam.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_foam.emission_rect_extents = Vector2(size.x / 2.0, 4)
	_foam.position = Vector2(size.x / 2.0, 4)
	_foam.direction = Vector2.UP
	_foam.initial_velocity_min = 5.0
	_foam.initial_velocity_max = 20.0
	_foam.gravity = Vector2(0, -10)
	_foam.scale_amount_min = 0.15
	_foam.scale_amount_max = 0.45
	_foam.color_ramp = Art.fade_gradient()
	add_child(_foam)

	# The "deep" part that soaks you. It starts 30px below the surface so you
	# can stand on a box or sock in the puddle without getting soaked.
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2 # only the player
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size.x, size.y - 30.0)
	shape.shape = rect
	shape.position = Vector2(size.x / 2.0, 30.0 + (size.y - 30.0) / 2.0)
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(b): soaked.emit(b))


func _process(delta: float) -> void:
	_t += delta
	var top := PackedVector2Array()
	for i in 14:
		var x := size.x * i / 13.0
		top.append(Vector2(x, sin(_t * 3.0 + x * 0.05) * 3.0))
	_surface.points = top
	var poly := top.duplicate()
	poly.append(Vector2(size.x, size.y))
	poly.append(Vector2(0, size.y))
	_water.polygon = poly
