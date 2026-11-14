# lint_bunny.gd
# The enemy: a grumpy ball of dryer lint with ears.
# It hops left and right. If it touches you, one of your socks gets knocked away.
extends CharacterBody2D

const BunnyArt = preload("res://scripts/lint_bunny_art.gd")
const Art = preload("res://scripts/art.gd")

const SPEED := 75.0
const GRAVITY := 1500.0

# The level sets these: the bunny walks between left_x and right_x.
@export var left_x := 0.0
@export var right_x := 300.0

var dir := 1.0
var stun_time := 0.0
var art: Node2D
var _t := 0.0
var _hurtbox: Area2D


func _ready() -> void:
	add_to_group("enemies")
	z_index = 4
	collision_layer = 8          # layer 4 = enemies
	collision_mask = 1 | 16      # bump into terrain and props
	art = BunnyArt.new()
	add_child(art)

	# An Area2D does not block anything; it only "feels" who is inside it.
	_hurtbox = Area2D.new()
	_hurtbox.collision_layer = 0
	_hurtbox.collision_mask = 2  # it only feels the player
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	shape.position = Vector2(0, -20)
	_hurtbox.add_child(shape)
	add_child(_hurtbox)


# Used by the hero's "smart command": a stunned bunny is not a threat.
func is_useful() -> bool:
	return stun_time <= 0.0


func stun(seconds: float) -> void:
	if stun_time <= 0.0:
		art.position.y = 0.0
		Art.burst(get_parent(), global_position + Vector2(0, -50), Color("ffd23f"), 10, 120.0)
	stun_time = maxf(stun_time, seconds)
	art.stunned = true


func _physics_process(delta: float) -> void:
	_t += delta
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 1200.0)

	if stun_time > 0.0:
		stun_time -= delta
		velocity.x = 0.0
		if stun_time <= 0.0:
			art.stunned = false
	else:
		velocity.x = dir * SPEED
		var too_far_right := dir > 0.0 and global_position.x >= right_x
		var too_far_left := dir < 0.0 and global_position.x <= left_x
		if too_far_right or too_far_left or is_on_wall():
			dir = -dir
			art.facing = dir

	move_and_slide()

	if stun_time <= 0.0:
		art.position.y = -absf(sin(_t * 7.0)) * 8.0 # hop hop hop
		for other in _hurtbox.get_overlapping_bodies():
			if other.has_method("hit_by_enemy"):
				other.hit_by_enemy(global_position.x)
