# snapper.gd
# A Clothespin Snapper hangs on a clothesline. When you walk under it, it
# wiggles for a moment and then drops down with a SNAP.
# HOW TO BEAT IT: stop when it wiggles so it misses you. It stays stuck in the
# floor for a few seconds: jump on it! A stink cloud also makes it fall.
extends "res://scripts/enemy.gd"

enum S { HANG, SHAKE, DROP, GROUND, RISE }

const TRIGGER_DISTANCE := 120.0
const DROP_SPEED := 1200.0
const OUTLINE := Color(0.16, 0.11, 0.22)

var state: int = S.HANG
var hang_y := 0.0
var ground_y := 600.0
var _timer := 0.0
var _hurt_time := 0.0
var _ground_time := 2.6
var _t := 0.0


func configure(a, _b) -> void:
	ground_y = a


func _ready() -> void:
	hang_y = position.y
	hurt_center = Vector2(0, -22)
	setup_body(Vector2.ZERO, 30.0, 0)
	_t = randf() * 10.0


func stun(seconds: float) -> void:
	if dead:
		return
	if state == S.HANG or state == S.SHAKE:
		state = S.DROP
		_ground_time = maxf(2.6, seconds)
	elif state == S.GROUND:
		_timer = maxf(_timer, seconds)


func can_be_stomped() -> bool:
	return state == S.GROUND and _hurt_time <= 0.0


func is_useful() -> bool:
	return not dead and (state == S.HANG or state == S.SHAKE)


func on_soaked() -> void:
	pass


func touch_player(p) -> void:
	if state == S.DROP or (state == S.GROUND and _hurt_time > 0.0):
		p.hit_by_enemy(global_position.x)
	elif state == S.GROUND and is_stomping(p):
		p.bounce()
		defeat()


func _physics_process(delta: float) -> void:
	if dead:
		return
	_t += delta
	rotation = 0.0
	match state:
		S.HANG:
			rotation = sin(_t * 2.0) * 0.06 # swinging gently
			var p = hero()
			if p != null:
				var dx: float = absf(p.global_position.x - global_position.x)
				var below: float = p.global_position.y - global_position.y
				if dx < TRIGGER_DISTANCE and below > 0.0 and below < 420.0:
					state = S.SHAKE
					_timer = 0.22
		S.SHAKE:
			rotation = sin(_t * 60.0) * 0.18 # WARNING wiggle
			_timer -= delta
			if _timer <= 0.0:
				state = S.DROP
		S.DROP:
			position.y += DROP_SPEED * delta
			if position.y >= ground_y:
				position.y = ground_y
				state = S.GROUND
				_timer = _ground_time
				_ground_time = 2.6
				_hurt_time = 0.12
				Sfx.play("snap")
				shake(4.0)
				Art.burst(get_parent(), global_position, Color(1, 1, 1, 0.8), 8, 120.0, 0.7)
		S.GROUND:
			_timer -= delta
			_hurt_time -= delta
			rotation = sin(_t * 9.0) * 0.08 # stuck and wobbling
			if _timer <= 0.0:
				state = S.RISE
		S.RISE:
			position.y -= 220.0 * delta
			if position.y <= hang_y:
				position.y = hang_y
				state = S.HANG
	queue_redraw()
	check_player_touch()


func _draw() -> void:
	var wood := Color("e1a95f")
	# Two wooden legs. They are open while hanging, closed after the snap.
	var open := 9.0 if (state == S.HANG or state == S.SHAKE or state == S.RISE) else 3.0
	draw_colored_polygon(PackedVector2Array([Vector2(-open - 6, 0), Vector2(-open, 0), Vector2(-1, -52), Vector2(-9, -52)]), wood)
	draw_colored_polygon(PackedVector2Array([Vector2(open, 0), Vector2(open + 6, 0), Vector2(9, -52), Vector2(1, -52)]), wood.darkened(0.15))
	draw_polyline(PackedVector2Array([Vector2(-open - 6, 0), Vector2(-9, -52), Vector2(9, -52), Vector2(open + 6, 0)]), OUTLINE, 2.0)
	# metal spring
	draw_arc(Vector2(0, -30), 7.0, 0.0, TAU, 12, Color("b2bec3"), 3.0)
	# angry eyes (dizzy X eyes when stuck in the floor)
	for ex in [-4.0, 4.0]:
		var c := Vector2(ex, -42)
		if state == S.GROUND:
			draw_line(c + Vector2(-2, -2), c + Vector2(2, 2), OUTLINE, 1.5)
			draw_line(c + Vector2(-2, 2), c + Vector2(2, -2), OUTLINE, 1.5)
		else:
			draw_circle(c, 2.2, Color("d63031"))
