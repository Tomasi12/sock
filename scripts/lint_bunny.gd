# lint_bunny.gd
# A grumpy ball of dryer lint with ears. It hops left and right.
# If it touches you, one of your socks gets knocked away.
# HOW TO BEAT IT: Gym Sock stink cloud (Q) makes it dizzy, then JUMP on it.
extends "res://scripts/enemy.gd"

const BunnyArt = preload("res://scripts/lint_bunny_art.gd")

const SPEED := 75.0

var left_x := 0.0
var right_x := 300.0
var dir := 1.0
var art: Node2D
var _t := 0.0


func configure(a, b) -> void:
	left_x = a
	right_x = b


func _ready() -> void:
	setup_body(Vector2(40, 34), 22.0)
	art = BunnyArt.new()
	add_child(art)


func stun(seconds: float) -> void:
	if dead:
		return
	if stun_time <= 0.0:
		art.position.y = 0.0
		Art.burst(get_parent(), global_position + Vector2(0, -50), Color("ffd23f"), 10, 120.0)
	super(seconds) # run the parent's stun() too
	art.stunned = true


func _physics_process(delta: float) -> void:
	if dead:
		return
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
		if global_position.x >= right_x:
			dir = -1.0
		elif global_position.x <= left_x:
			dir = 1.0
		elif is_on_wall():
			dir = -dir
		art.facing = dir
		art.position.y = -absf(sin(_t * 7.0)) * 8.0 # hop hop hop

	move_and_slide()
	check_player_touch()
