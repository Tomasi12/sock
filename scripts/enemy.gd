# enemy.gd
# The parent script of every enemy and boss. It holds what they all share:
# being stunned, being stomped, being defeated, and hurting the hero.
# Other enemy scripts start with:  extends "res://scripts/enemy.gd"
# and only change the parts that are different ("override").
extends CharacterBody2D

signal defeated(enemy)
signal hp_changed(hp: int, max_hp: int) # only bosses use this

const Art = preload("res://scripts/art.gd")
const GRAVITY := 1500.0

var level = null             # the level sets this
var stun_time := 0.0
var dead := false
var hurt_center := Vector2(0, -20) # middle of the "ouch" circle, from our feet

# Bosses
var boss_name := ""
var hp := 0
var max_hp := 0

var _hurtbox: Area2D


# The level calls this before the enemy enters the scene. "a" and "b" mean
# different things for each enemy (patrol limits, path points...).
func configure(_a, _b) -> void:
	pass


# Create the solid body and the circle that detects the hero.
func setup_body(body_size: Vector2, hurt_radius: float, mask := 1 | 16) -> void:
	add_to_group("enemies")
	z_index = 4
	collision_layer = 8 # layer 4 = enemies
	collision_mask = mask
	if body_size != Vector2.ZERO:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = body_size
		shape.shape = rect
		shape.position = Vector2(0, -body_size.y / 2.0)
		add_child(shape)
	_hurtbox = Area2D.new()
	_hurtbox.collision_layer = 0
	_hurtbox.collision_mask = 2 # it only feels the player
	var hurt_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = hurt_radius
	hurt_shape.shape = circle
	hurt_shape.position = hurt_center
	_hurtbox.add_child(hurt_shape)
	add_child(_hurtbox)


func hero():
	return get_tree().get_first_node_in_group("player")


# Used by the hero's "smart command": is this enemy still a threat?
func is_useful() -> bool:
	return not dead and stun_time <= 0.0


# The stink cloud calls this.
func stun(seconds: float) -> void:
	stun_time = maxf(stun_time, seconds)


func can_be_stomped() -> bool:
	return stun_time > 0.0


func on_stomped() -> void:
	defeat()


# Fell in a puddle.
func on_soaked() -> void:
	defeat()


func defeat() -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemies")
	Art.burst(get_parent(), global_position + hurt_center, Color(0.9, 0.9, 1.0), 18, 200.0, 1.0)
	Sfx.play("stomp")
	defeated.emit(self)
	_hurtbox.set_deferred("monitoring", false)
	# Squash flat, then disappear.
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.4, 0.1), 0.15)
	tw.tween_callback(queue_free)


# Call this every frame: did we touch the hero?
func check_player_touch() -> void:
	if dead:
		return
	for other in _hurtbox.get_overlapping_bodies():
		if other.is_in_group("player"):
			touch_player(other)


# Is the hero falling onto us from above?
# We look at where the hero's feet were two frames ago. A fast fall moves
# 10 pixels per frame, and without this a stomp could be missed just because
# the hero moved a moment before we checked.
func is_stomping(p) -> bool:
	var speed: float = p.falling_speed()
	if speed <= 50.0:
		return false
	var feet_before: float = p.global_position.y - speed * get_physics_process_delta_time() * 2.0
	return feet_before < global_position.y + hurt_center.y


func touch_player(p) -> void:
	if can_be_stomped():
		if is_stomping(p):
			p.bounce()
			on_stomped()
		return
	p.hit_by_enemy(global_position.x)


func say(text: String) -> void:
	if level != null:
		level.show_message(text)


func shake(amount: float) -> void:
	if level != null:
		level.shake(amount)
