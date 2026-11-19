# boss_dryer.gd
# BOSS 3: THE DRYER KING. He does not move. He repeats 4 steps:
#   1. SPIT  - he spits out a Lint Bunny (later also Static Sparks)
#   2. BLOW  - hot air pushes you away (hold "right" to push back)
#   3. OPEN  - he overheats and his door opens. THIS IS YOUR CHANCE!
#   4. REST
# HOW TO BEAT HIM: while the door is open, run close and throw a sock inside
# (Q). The sock clogs his lint trap and he spits it back out. 5 hits to win.
extends "res://scripts/enemy.gd"

enum S { REST, SPIT, BLOW, OPEN, HURT }

const BODY := Vector2(300, 340)
const OUTLINE := Color(0.16, 0.11, 0.22)

var state: int = S.REST
var _timer := 2.5
var _t := 0.0
var _spat := false
var _minions: Array = []
var _wind: CPUParticles2D
var _clang_cooldown := 0.0
var _told_wind := false


func _ready() -> void:
	boss_name = "THE DRYER KING"
	max_hp = 5
	hp = 5
	hurt_center = Vector2(0, -120)
	setup_body(BODY, 10.0, 0)
	collision_layer = 1 | 8 # he is also a solid wall
	add_to_group("bosses")
	z_index = 3

	# Hot air particles for the BLOW step
	_wind = CPUParticles2D.new()
	_wind.texture = Art.soft_circle()
	_wind.amount = 60
	_wind.lifetime = 1.6
	_wind.position = Vector2(-BODY.x / 2.0, -120)
	_wind.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_wind.emission_rect_extents = Vector2(10, 110)
	_wind.direction = Vector2.LEFT
	_wind.spread = 8.0
	_wind.gravity = Vector2.ZERO
	_wind.initial_velocity_min = 500.0
	_wind.initial_velocity_max = 800.0
	_wind.scale_amount_min = 0.5
	_wind.scale_amount_max = 1.4
	_wind.color = Color(1.0, 0.7, 0.4, 0.5)
	_wind.color_ramp = Art.fade_gradient()
	_wind.emitting = false
	add_child(_wind)


func stun(_seconds: float) -> void:
	pass


func can_be_stomped() -> bool:
	return false


func on_soaked() -> void:
	pass


func is_useful() -> bool:
	return false


func touch_player(_p) -> void:
	pass # he is just a wall


func _left_edge() -> float:
	return global_position.x - BODY.x / 2.0


func _physics_process(delta: float) -> void:
	if dead:
		return
	_t += delta
	_timer -= delta
	_clang_cooldown -= delta
	var rage := hp <= 2 # the last two hits are harder

	match state:
		S.REST:
			if _timer <= 0.0:
				state = S.SPIT
				_timer = 0.9
				_spat = false
		S.SPIT:
			if not _spat and _timer < 0.5:
				_spat = true
				_spit(rage)
			if _timer <= 0.0:
				state = S.BLOW
				_timer = 2.6
				_wind.emitting = true
				Sfx.play("stink", 1.3)
				if not _told_wind:
					_told_wind = true
					say("HOT AIR! Hold D (or the right arrow) to push back!")
		S.BLOW:
			var p = hero()
			if p != null and p.global_position.x < _left_edge():
				p.wind_x = -250.0 if rage else -200.0
			if _timer <= 0.0:
				_wind.emitting = false
				state = S.OPEN
				_timer = 2.9 if rage else 3.7
				Sfx.play("pop", 0.5)
				say("His door is OPEN! Run close and throw a sock inside! (Q)")
		S.OPEN:
			if _timer <= 0.0:
				state = S.REST
				_timer = 1.2
		S.HURT:
			if _timer <= 0.0:
				state = S.REST
				_timer = 0.8

	_check_socks()
	queue_redraw()


func _check_socks() -> void:
	for sock in get_tree().get_nodes_in_group("recruits"):
		if not sock.is_attacking():
			continue
		if sock.global_position.x < _left_edge() - 25.0 or sock.global_position.y < global_position.y - 270.0:
			continue
		# A sock reached the door.
		sock.global_position.x = _left_edge() - 45.0
		sock.knock_away(-1.0)
		if state != S.OPEN:
			Sfx.play("bonk", 1.5)
			if _clang_cooldown <= 0.0:
				_clang_cooldown = 3.0
				say("CLANG! The door is shut. Wait until it opens.")
			continue
		hp -= 1
		hp_changed.emit(hp, max_hp)
		Sfx.play("boss_hit")
		shake(14.0)
		Art.burst(get_parent(), Vector2(_left_edge(), global_position.y - 120.0), Color("ffd23f"), 30, 320.0, 1.4)
		if hp <= 0:
			say("THE DRYER KING IS DEFEATED! But who is humming in the closet...?")
			defeat()
		else:
			say("STUFFED! His lint trap is clogged! %d more!" % hp)
			state = S.HURT
			_timer = 1.5
		return


func _spit(rage: bool) -> void:
	if level == null:
		return
	_minions = _minions.filter(func(m): return is_instance_valid(m) and not m.dead)
	if _minions.size() >= (3 if rage else 2):
		return
	Sfx.play("pop", 0.6)
	var left := _left_edge()
	var floor_y := global_position.y
	if rage and randf() < 0.5:
		var a := Vector2(left - 80.0, floor_y - 32.0)
		_minions.append(level.spawn_enemy("spark", a, a, Vector2(left - 620.0, floor_y - 32.0)))
		say("He spits out a Static Spark! (Wool Sock!)")
	else:
		_minions.append(level.spawn_enemy("bunny", Vector2(left - 50.0, floor_y - 10.0), 100.0, left - 60.0))


func defeat() -> void:
	if dead:
		return
	_wind.emitting = false
	# lots of happy explosions
	for i in 6:
		Art.burst(get_parent(), global_position + Vector2(randf_range(-140, 140), randf_range(-320, -20)),
			[Color("ffd23f"), Color("ff7675"), Color("55efc4"), Color("74b9ff")][i % 4], 30, 380.0, 1.8)
	shake(20.0)
	super()


func _draw() -> void:
	var w := BODY.x
	var h := BODY.y
	var shake_x := sin(_t * 50.0) * 3.0 if (state == S.BLOW or state == S.HURT) else 0.0
	draw_set_transform(Vector2(shake_x, 0), 0.0, Vector2.ONE)

	var body := Color("2d3436")
	if state == S.HURT and int(_t * 16.0) % 2 == 0:
		body = Color("d63031") # flash red when hurt
	elif state == S.OPEN:
		body = Color("4a2c2a") # overheated
	draw_rect(Rect2(-w / 2.0, -h, w, h), body)
	draw_rect(Rect2(-w / 2.0, -h, w, 70), body.lightened(0.12)) # control panel
	draw_rect(Rect2(-w / 2.0, -h, w, h), OUTLINE, false, 4.0)

	# crown
	draw_colored_polygon(PackedVector2Array([
		Vector2(-90, -h), Vector2(-90, -h - 60), Vector2(-45, -h - 25), Vector2(0, -h - 75),
		Vector2(45, -h - 25), Vector2(90, -h - 60), Vector2(90, -h),
	]), Color("fdcb6e"))

	# eyes
	var eye_y := -h + 36.0
	for side in [-1.0, 1.0]:
		var c := Vector2(side * 50.0, eye_y)
		if state == S.HURT:
			draw_line(c + Vector2(-10, -10), c + Vector2(10, 10), Color.WHITE, 4.0)
			draw_line(c + Vector2(-10, 10), c + Vector2(10, -10), Color.WHITE, 4.0)
		else:
			draw_circle(c, 14.0, Color(1.0, 0.25 + 0.2 * sin(_t * 4.0), 0.2))
			draw_line(c + Vector2(-side * 28.0, -22), c + Vector2(side * 20.0, -8), Color.BLACK, 7.0)

	# the door
	var door := Vector2(0, -130)
	draw_circle(door, 100.0, Color("636e72"))
	match state:
		S.OPEN:
			# glowing open door: the target!
			var glow := 0.6 + 0.4 * sin(_t * 10.0)
			draw_circle(door, 82.0, Color(1.0, 0.5 * glow, 0.1))
			draw_circle(door, 50.0, Color(1.0, 0.9, 0.4, glow))
			draw_arc(door, 96.0, 0.0, TAU, 48, Color(1, 1, 0.6, glow), 6.0)
			draw_string(ThemeDB.fallback_font, door + Vector2(-80, 150), "THROW! (Q)", HORIZONTAL_ALIGNMENT_CENTER, 160, 26, Color(1, 1, 0.6, glow))
		S.BLOW:
			draw_circle(door, 82.0, Color("e17055"))
			for i in 6:
				var a := _t * 9.0 + i * TAU / 6.0
				draw_arc(door, 30.0 + i * 8.0, a, a + 1.8, 12, Color(1, 1, 1, 0.6), 5.0)
		_:
			# closed: you can see the stolen socks spinning inside
			draw_circle(door, 82.0, Color("1e272e"))
			for i in 5:
				var a := -_t * 1.5 + i * TAU / 5.0
				var col: Color = [Color("ff7675"), Color("74b9ff"), Color("55efc4"), Color("ffeaa7"), Color("a29bfe")][i]
				draw_circle(door + Vector2(cos(a), sin(a)) * 48.0, 11.0, col)
			draw_arc(door, 82.0, -2.4, -1.4, 10, Color(1, 1, 1, 0.3), 6.0) # glass shine
	draw_arc(door, 100.0, 0.0, TAU, 48, OUTLINE, 4.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
