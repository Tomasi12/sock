# hanger.gd
# A Hanger Hawk: a wire coat hanger with little wings. It glides back and forth
# high above the floor, too high to reach with a normal jump. When you walk
# below it, it shivers for a moment and then DIVES at the spot where you are.
# HOW TO BEAT IT: keep moving when it shivers, so the dive misses. Then jump on
# it from ABOVE: bounce on a Rubber Sock to get high enough, or catch it while
# it climbs back up after a dive.
extends "res://scripts/enemy.gd"

enum S { CRUISE, WARN, DIVE, RISE }

const CRUISE_SPEED := 90.0
const DIVE_SPEED := 520.0
const RISE_SPEED := 170.0
const SEE_DISTANCE := 140.0
const WIRE := Color("dfe6e9")
const OUTLINE := Color(0.16, 0.11, 0.22)

var left_x := 0.0
var right_x := 300.0
var cruise_y := 0.0
var dir := 1.0
var state: int = S.CRUISE
var _target := Vector2.ZERO
var _timer := 0.0
var _cooldown := 1.5
var _t := 0.0


func configure(a, b) -> void:
	left_x = a
	right_x = b


func _ready() -> void:
	cruise_y = position.y
	hurt_center = Vector2.ZERO
	setup_body(Vector2.ZERO, 22.0, 0)
	z_index = 6
	_t = randf() * 10.0


func stun(_seconds: float) -> void:
	pass # wire has no nose


func on_soaked() -> void:
	pass


# Its hook is underneath: from ABOVE you can stomp it, except while it dives.
func can_be_stomped() -> bool:
	return state != S.DIVE


func is_useful() -> bool:
	return false # no sock helps directly (the Rubber Sock helps YOU)


func touch_player(p) -> void:
	if state != S.DIVE and is_stomping(p):
		p.bounce()
		say("BOING-STOMP! The Hanger Hawk is bent for good.")
		defeat()
		return
	p.hit_by_enemy(global_position.x)


func _physics_process(delta: float) -> void:
	if dead:
		return
	_t += delta
	_cooldown -= delta
	var p = hero()
	match state:
		S.CRUISE:
			position.x += dir * CRUISE_SPEED * delta
			if position.x >= right_x:
				dir = -1.0
			elif position.x <= left_x:
				dir = 1.0
			position.y = cruise_y + sin(_t * 2.0) * 8.0 # gentle gliding
			if _cooldown <= 0.0 and p != null and p.is_on_floor():
				var dx: float = absf(p.global_position.x - global_position.x)
				var below: float = p.global_position.y - global_position.y
				if dx < SEE_DISTANCE and below > 120.0 and below < 420.0:
					state = S.WARN
					_timer = 0.45
					_target = p.global_position + Vector2(0, -24)
					Sfx.play("click", 0.6)
		S.WARN:
			_timer -= delta # shivering: this is your warning!
			if _timer <= 0.0:
				state = S.DIVE
		S.DIVE:
			position = position.move_toward(_target, DIVE_SPEED * delta)
			if position.distance_to(_target) < 4.0:
				state = S.RISE
				Sfx.play("snap", 1.4)
		S.RISE:
			position.y = move_toward(position.y, cruise_y, RISE_SPEED * delta)
			if position.y <= cruise_y + 0.5:
				state = S.CRUISE
				_cooldown = 2.5
	queue_redraw()
	check_player_touch()


func _draw() -> void:
	var wobble := sin(_t * 70.0) * 2.0 if state == S.WARN else 0.0
	draw_set_transform(Vector2(wobble, 0), 0.0, Vector2(dir, 1.0))
	# wings, flapping
	var flap := sin(_t * (22.0 if state == S.DIVE else 12.0))
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(side * 14, -2), Vector2(side * 34, -14 - 10 * flap), Vector2(side * 30, 2 - 4 * flap),
		]), Color("b2bec3"))
	# the hanger: a hook on top and a triangle
	draw_arc(Vector2(0, -20), 6.0, PI, TAU + 1.0, 10, WIRE, 3.0)
	draw_line(Vector2(0, -14), Vector2(0, -8), WIRE, 3.0)
	var tri := PackedVector2Array([Vector2(0, -8), Vector2(-24, 12), Vector2(24, 12), Vector2(0, -8)])
	draw_polyline(tri, OUTLINE, 6.0)
	draw_polyline(tri, WIRE, 3.0)
	# angry eyes
	var eye := Color("d63031") if state != S.CRUISE else Color("2d3436")
	draw_circle(Vector2(-6, 4), 2.6, eye)
	draw_circle(Vector2(6, 4), 2.6, eye)
	draw_line(Vector2(-10, -1), Vector2(-3, 2), OUTLINE, 2.0)
	draw_line(Vector2(10, -1), Vector2(3, 2), OUTLINE, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
