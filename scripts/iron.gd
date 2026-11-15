# iron.gd
# A Hot Iron. It slides around slowly, but when it sees you it heats up and
# CHARGES. It is too hot to stomp and it does not care about stink.
# HOW TO BEAT IT: water! Stand on the other side of a puddle. The iron charges
# straight ahead and falls in. TSSSS!
extends "res://scripts/enemy.gd"

const IronArt = preload("res://scripts/iron_art.gd")

enum S { PATROL, WARN, CHARGE, REST }

const PATROL_SPEED := 45.0
const CHARGE_SPEED := 250.0
const SEE_DISTANCE := 430.0

var left_x := 0.0
var right_x := 300.0
var dir := -1.0
var state: int = S.PATROL
var _timer := 0.0
var _t := 0.0


func configure(a, b) -> void:
	left_x = a
	right_x = b


func _ready() -> void:
	hurt_center = Vector2(0, -20)
	setup_body(Vector2(60, 38), 30.0)


func stun(_seconds: float) -> void:
	pass # too hot to smell anything


func can_be_stomped() -> bool:
	return false # jumping on a hot iron is a bad idea


func on_soaked() -> void:
	if dead:
		return
	Art.burst(get_parent(), global_position + Vector2(0, -30), Color(1, 1, 1, 0.9), 30, 260.0, 1.6)
	Sfx.play("splash")
	say("TSSSSS! The iron cooled down for good.")
	defeat()


func _physics_process(delta: float) -> void:
	if dead:
		return
	_t += delta
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 1200.0)
	if global_position.y > 1200.0:
		defeat() # fell out of the world
		return

	match state:
		S.PATROL:
			if global_position.x >= right_x:
				dir = -1.0
			elif global_position.x <= left_x:
				dir = 1.0
			elif is_on_wall():
				dir = -dir
			velocity.x = dir * PATROL_SPEED
			var p = hero()
			if p != null and is_on_floor():
				var dx: float = p.global_position.x - global_position.x
				var dy: float = absf(p.global_position.y - global_position.y)
				if absf(dx) < SEE_DISTANCE and dy < 70.0:
					dir = signf(dx) if dx != 0.0 else dir
					state = S.WARN
					_timer = 0.55
					Sfx.play("stink", 1.8)
		S.WARN:
			velocity.x = 0.0 # heating up... this is your warning!
			_timer -= delta
			if _timer <= 0.0:
				state = S.CHARGE
				_timer = 2.2
		S.CHARGE:
			velocity.x = dir * CHARGE_SPEED
			_timer -= delta
			if is_on_wall() or _timer <= 0.0:
				state = S.REST
				_timer = 1.0
		S.REST:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			_timer -= delta
			if _timer <= 0.0:
				state = S.PATROL

	move_and_slide()
	queue_redraw()
	check_player_touch()


func _draw() -> void:
	var heat := 0.25
	if state == S.WARN:
		heat = 0.5 + 0.5 * sin(_t * 30.0) # flashing = about to charge
	elif state == S.CHARGE:
		heat = 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(dir, 1.0))
	IronArt.draw_iron(self, heat, false, _t)
