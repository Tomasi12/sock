# stink_cloud.gd
# The Gym Sock's secret weapon: a green cloud that stuns Lint Bunnies.
extends Node2D

const Art = preload("res://scripts/art.gd")

const RADIUS := 170.0
const STUN_SECONDS := 4.0
const ACTIVE_SECONDS := 2.5

var radius := 10.0:
	set(value):
		radius = value
		queue_redraw()
var alpha := 0.35:
	set(value):
		alpha = value
		queue_redraw()

var _active := ACTIVE_SECONDS
var _particles: CPUParticles2D


func _ready() -> void:
	z_index = 6

	# Green puffy particles.
	_particles = CPUParticles2D.new()
	_particles.texture = Art.soft_circle()
	_particles.amount = 40
	_particles.lifetime = 1.6
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_particles.emission_sphere_radius = 70.0
	_particles.direction = Vector2.UP
	_particles.spread = 180.0
	_particles.gravity = Vector2(0, -25)
	_particles.initial_velocity_min = 10.0
	_particles.initial_velocity_max = 40.0
	_particles.scale_amount_min = 1.2
	_particles.scale_amount_max = 3.0
	_particles.color = Color(0.45, 0.85, 0.2, 0.6)
	_particles.color_ramp = Art.fade_gradient()
	add_child(_particles)
	_particles.emitting = true

	# The cloud grows fast, then fades away slowly, then deletes itself.
	var tw := create_tween()
	tw.tween_property(self, "radius", RADIUS, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(ACTIVE_SECONDS - 0.35)
	tw.tween_callback(func(): _particles.emitting = false)
	tw.tween_property(self, "alpha", 0.0, 1.5)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if _active <= 0.0:
		return
	_active -= delta
	# Any enemy inside the cloud gets stunned.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < RADIUS:
			enemy.stun(STUN_SECONDS)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.45, 0.8, 0.15, alpha * 0.5))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.3, 0.6, 0.1, alpha), 3.0)
