# moth.gd
# A Moth. It hovers in the air and, when you come close, swoops down to chew
# the LAST sock in your line (the sock gets knocked away).
# HOW TO BEAT IT: moths hate the smell of Gym Socks: one whiff of a stink cloud
# and they are gone. You can also stomp them when they swoop low.
extends "res://scripts/enemy.gd"

enum S { HOVER, SWOOP, RETURN }

const SEE_DISTANCE := 460.0
const SWOOP_SPEED := 250.0

var home := Vector2.ZERO
var state: int = S.HOVER
var _target = null
var _cooldown := 1.5
var _t := 0.0


func _ready() -> void:
	home = position
	hurt_center = Vector2.ZERO
	setup_body(Vector2.ZERO, 20.0, 0)
	z_index = 6
	_t = randf() * 10.0


func stun(_seconds: float) -> void:
	if dead:
		return
	say("The moth can't stand the stink!")
	defeat()


func can_be_stomped() -> bool:
	return true


func on_soaked() -> void:
	pass


# A moth does not hurt the hero. It only wants socks.
func touch_player(p) -> void:
	if p.velocity.y > 50.0 and p.global_position.y < global_position.y:
		p.bounce()
		defeat()


func _physics_process(delta: float) -> void:
	if dead:
		return
	_t += delta
	_cooldown -= delta
	var p = hero()
	match state:
		S.HOVER:
			# fly in a lazy figure-8 around home
			var spot := home + Vector2(sin(_t * 1.3) * 60.0, sin(_t * 2.6) * 25.0)
			position = position.lerp(spot, minf(1.0, 3.0 * delta))
			if _cooldown <= 0.0 and p != null and not p.army.is_empty() \
					and p.global_position.distance_to(home) < SEE_DISTANCE:
				_target = p.army.back()
				state = S.SWOOP
		S.SWOOP:
			if p == null or not is_instance_valid(_target) or not (_target in p.army):
				state = S.RETURN
			else:
				var goal: Vector2 = _target.global_position + Vector2(0, -25)
				position = position.move_toward(goal, SWOOP_SPEED * delta)
				if position.distance_to(goal) < 22.0:
					var away := signf(_target.global_position.x - p.global_position.x)
					p.lose_sock(_target, away if away != 0.0 else -p.facing,
						"MUNCH! A moth chewed your %s. Go get it (E)!" % _target.sock_name())
					state = S.RETURN
					_cooldown = 5.0
				elif position.distance_to(home) > 700.0:
					state = S.RETURN
					_cooldown = 2.0
		S.RETURN:
			position = position.move_toward(home, 200.0 * delta)
			if position.distance_to(home) < 10.0:
				state = S.HOVER
	queue_redraw()
	check_player_touch()


func _draw() -> void:
	var flap := sin(_t * 26.0) # wings go up and down very fast
	var wing := Color("c8a27a")
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(side * 3, -2), Vector2(side * 26, -16 * flap - 6), Vector2(side * 22, 8 - 6 * flap), Vector2(side * 4, 6),
		]), wing)
		draw_circle(Vector2(side * 16, -6 * flap), 3.0, wing.darkened(0.35)) # wing spot
	draw_colored_polygon(Art.ellipse(Vector2.ZERO, 6, 11), Color("8d6e63"))
	draw_circle(Vector2(-2.5, -5), 2.0, Color("ff7675")) # red eyes
	draw_circle(Vector2(2.5, -5), 2.0, Color("ff7675"))
	draw_line(Vector2(-2, -10), Vector2(-7, -18), Color("5d4037"), 1.5) # antennae
	draw_line(Vector2(2, -10), Vector2(7, -18), Color("5d4037"), 1.5)
