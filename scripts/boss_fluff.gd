# boss_fluff.gd
# BOSS 1: BIG FLUFF, the giant Lint Bunny.
# It jumps at you in big hops and calls little bunnies to help.
# HOW TO BEAT IT: hit it with a Gym Sock stink cloud (Q). It goes flat and
# dizzy. Jump on its head! Do that 3 times. It gets faster each time.
extends "res://scripts/enemy.gd"

const BunnyArt = preload("res://scripts/lint_bunny_art.gd")

enum S { WAIT, AIR }

const NORMAL_SCALE := Vector2(2.8, 2.8)
const FLAT_SCALE := Vector2(3.3, 1.5)

var state: int = S.WAIT
var art: Node2D
var _timer := 1.8
var _hops := 0
var _invulnerable := 0.0
var _minions: Array = []
var _t := 0.0


func _ready() -> void:
	boss_name = "BIG FLUFF"
	max_hp = 3
	hp = 3
	hurt_center = Vector2(0, -50)
	setup_body(Vector2(100, 90), 52.0, 1) # mask 1: only terrain stops it
	add_to_group("bosses")
	art = BunnyArt.new()
	art.scale = NORMAL_SCALE
	add_child(art)


func stun(_seconds: float) -> void:
	# Only works when it is standing on the floor and not flashing.
	if dead or _invulnerable > 0.0 or not is_on_floor() or stun_time > 0.0:
		return
	stun_time = 3.5
	art.stunned = true
	art.scale = FLAT_SCALE
	art.position.y = 0.0
	Sfx.play("stink", 0.7)
	say("Big Fluff is DIZZY! Jump on its head!")


func on_soaked() -> void:
	pass


func on_stomped() -> void:
	hp -= 1
	hp_changed.emit(hp, max_hp)
	Sfx.play("boss_hit")
	shake(10.0)
	stun_time = 0.0
	_wake_up()
	if hp <= 0:
		say("Big Fluff explodes into a cloud of lint!")
		defeat()
		return
	say("OOF! Big Fluff is FURIOUS!")
	_invulnerable = 2.0
	# It leaps away from the hero.
	var p = hero()
	var away := -1.0
	if p != null and p.global_position.x < global_position.x:
		away = 1.0
	velocity = Vector2(away * 260.0, -700.0)
	state = S.AIR


func _wake_up() -> void:
	art.stunned = false
	art.scale = NORMAL_SCALE


func _physics_process(delta: float) -> void:
	if dead:
		return
	_t += delta
	_invulnerable -= delta
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 1300.0)
	var rage := max_hp - hp # 0, 1 or 2: it gets faster when hurt

	if stun_time > 0.0:
		stun_time -= delta
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
		if stun_time <= 0.0:
			_wake_up()
	else:
		match state:
			S.WAIT:
				velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
				_timer -= delta
				# crouch a little before jumping (so you can see it coming)
				art.scale = NORMAL_SCALE * Vector2(1.0 + 0.1 * sin(_t * 12.0), 1.0 - 0.1 * sin(_t * 12.0))
				var p = hero()
				if _timer <= 0.0 and is_on_floor() and p != null:
					var d := signf(p.global_position.x - global_position.x)
					if d == 0.0:
						d = 1.0
					art.facing = d
					art.scale = NORMAL_SCALE
					velocity = Vector2(d * (210.0 + rage * 55.0), -640.0)
					state = S.AIR
					Sfx.play("jump", 0.5)
			S.AIR:
				if is_on_floor() and velocity.y >= 0.0:
					# Landed with a thump.
					state = S.WAIT
					_timer = 1.3 - 0.25 * rage
					_hops += 1
					shake(6.0)
					Sfx.play("land", 0.6)
					Art.burst(get_parent(), global_position, Color(1, 1, 1, 0.8), 14, 200.0, 1.2)
					if _hops % 3 == 0:
						_call_minion()

	move_and_slide()
	# flash while it cannot be stunned
	art.modulate.a = 0.5 if (_invulnerable > 0.0 and int(_t * 14.0) % 2 == 0) else 1.0
	check_player_touch()


func _call_minion() -> void:
	if level == null:
		return
	_minions = _minions.filter(func(m): return is_instance_valid(m) and not m.dead)
	if _minions.size() >= 2:
		return
	var width: float = level.data["width"]
	_minions.append(level.spawn_enemy("bunny", global_position + Vector2(0, -20), 100.0, width - 100.0))
	say("Big Fluff calls a little bunny!")
