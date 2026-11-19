# boss_vacuum.gd
# BOSS 4: COUNT SUCKULA, a giant vacuum cleaner that has eaten socks for years.
# He stands still and repeats:
#   1. SPIT  - he blows out a Lint Bunny (later also a Hanger Hawk)
#   2. SUCK  - he sucks air (and YOU) towards his nozzle. Touching it hurts!
#   3. REST
# HOW TO BEAT HIM: while he sucks, send a WOOL Sock (Q). It is so chunky that
# it gets stuck in his nozzle: he is CLOGGED. Now jump on the big red button
# on his head: bounce on a Rubber Sock to get up there! 3 times.
extends "res://scripts/enemy.gd"

enum S { REST, SPIT, SUCK, CLOGGED, HURT }

const SockTypes = preload("res://scripts/sock_types.gd")
const BODY := Vector2(220, 300)
const OUTLINE := Color(0.16, 0.11, 0.22)
const PULL := 150.0          # how hard he pulls the hero while sucking

var state: int = S.REST
var _timer := 2.0
var _t := 0.0
var _spat := false
var _minions: Array = []
var _clog_sock = null
var _told := {}


func _ready() -> void:
	boss_name = "COUNT SUCKULA"
	max_hp = 3
	hp = 3
	hurt_center = Vector2(0, -150)
	setup_body(BODY, 10.0, 0)
	collision_layer = 1 | 8 # he is also a solid block: you can stand on his head
	add_to_group("bosses")
	z_index = 3


func stun(_seconds: float) -> void:
	pass


func can_be_stomped() -> bool:
	return false


func on_soaked() -> void:
	pass


func is_useful() -> bool:
	return false


func touch_player(_p) -> void:
	pass # the nozzle and the button are checked below


func _left_edge() -> float:
	return global_position.x - BODY.x / 2.0


func _top() -> float:
	return global_position.y - BODY.y


# Where the nozzle is: low, on his left side.
func nozzle() -> Vector2:
	return Vector2(_left_edge() - 30.0, global_position.y - 30.0)


func _physics_process(delta: float) -> void:
	if dead:
		return
	_t += delta
	_timer -= delta
	var rage := hp <= 1

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
				state = S.SUCK
				_timer = 4.5 if rage else 5.5
				Sfx.play("suck")
				_tell("suck", "SLUUURP! He sucks you in! Send a chunky WOOL Sock into his nozzle! (press 1, then Q)")
		S.SUCK:
			_pull(delta, rage)
			if _timer <= 0.0:
				state = S.REST
				_timer = 1.6
		S.CLOGGED:
			# The sock was whistled back? Then he is free again.
			if not _sock_still_stuck():
				_unclog(false)
			elif _timer <= 0.0:
				say("PFFT! He blew the sock out. Clog him again!")
				_unclog(true)
		S.HURT:
			if _timer <= 0.0:
				state = S.REST
				_timer = 1.2

	_check_nozzle()
	_check_button()
	queue_redraw()


# While sucking, he pulls the hero and every marching or flying sock.
func _pull(delta: float, rage: bool) -> void:
	var p = hero()
	if p != null and p.global_position.x < _left_edge():
		p.wind_x = PULL * (1.25 if rage else 1.0)
	for sock in get_tree().get_nodes_in_group("recruits"):
		if sock.is_attacking() and sock.global_position.x < _left_edge():
			sock.global_position.x += 90.0 * delta


func _check_nozzle() -> void:
	var mouth := nozzle()
	# The hero touches the nozzle: OUCH (and he spits you away).
	var p = hero()
	if p != null and state == S.SUCK and p.global_position.distance_to(mouth) < 50.0:
		p.hit_by_enemy(global_position.x)
	# A sock reaches the nozzle.
	for sock in get_tree().get_nodes_in_group("recruits"):
		if not sock.is_attacking():
			continue
		if sock.global_position.x < mouth.x - 20.0 or sock.global_position.y < global_position.y - 120.0:
			continue
		if state == S.SUCK and sock.kind == SockTypes.Kind.WOOL:
			_clog(sock)
			return
		sock.global_position.x = mouth.x - 40.0
		sock.knock_away(-1.0)
		Sfx.play("bonk", 1.5)
		if state == S.SUCK:
			_tell("skinny", "Too skinny! It slipped right through. Only a chunky WOOL Sock can clog him!")
		else:
			_tell("closed", "He is not sucking now. Wait until he SUCKS, then send a Wool Sock.")


func _clog(sock) -> void:
	_clog_sock = sock
	sock.global_position = nozzle() + Vector2(-6, 18)
	sock._place() # stuck: it is a solid block now
	state = S.CLOGGED
	_timer = 5.0 if hp > 1 else 4.0
	Sfx.play("bonk", 0.6)
	shake(8.0)
	Art.burst(get_parent(), nozzle(), Color(0.85, 0.8, 0.75), 20, 220.0, 1.2)
	say("CLOGGED! Quick: jump on the red button on his head! (bounce on a Rubber Sock)")


func _sock_still_stuck() -> bool:
	return is_instance_valid(_clog_sock) and _clog_sock.state == _clog_sock.State.PLACED \
		and _clog_sock.global_position.distance_to(nozzle() + Vector2(-6, 18)) < 30.0


func _unclog(spit_out: bool) -> void:
	if spit_out and _sock_still_stuck():
		_clog_sock.global_position.x -= 30.0
		_clog_sock.knock_away(-1.0)
		Sfx.play("pop", 0.5)
	_clog_sock = null
	state = S.REST
	_timer = 1.4


# The hero lands on his head while he is clogged: a hit!
func _check_button() -> void:
	var p = hero()
	if p == null or not p.is_on_floor():
		return
	var on_head: bool = absf(p.global_position.x - global_position.x) < BODY.x / 2.0 + 10.0 \
		and absf(p.global_position.y - _top()) < 6.0
	if not on_head:
		return
	if state != S.CLOGGED:
		_tell("head", "The button only works when he is CLOGGED with a Wool Sock!")
		return
	hp -= 1
	hp_changed.emit(hp, max_hp)
	Sfx.play("boss_hit")
	shake(14.0)
	p.bounce()
	Art.burst(get_parent(), Vector2(global_position.x, _top()), Color("ff7675"), 30, 320.0, 1.4)
	_unclog(true)
	if hp <= 0:
		say("COUNT SUCKULA IS BROKEN! No more stolen socks, ever!")
		defeat()
	else:
		say("CLICK! He coughs up dust! %d more!" % hp)
		state = S.HURT
		_timer = 1.5


func _spit(rage: bool) -> void:
	if level == null:
		return
	_minions = _minions.filter(func(m): return is_instance_valid(m) and not m.dead)
	if _minions.size() >= (3 if rage else 2):
		return
	Sfx.play("pop", 0.6)
	var left := _left_edge()
	var floor_y := global_position.y
	if hp <= 2 and randf() < 0.5:
		_minions.append(level.spawn_enemy("hanger", Vector2(left - 300.0, floor_y - 240.0), 260.0, left - 120.0))
		_tell("hawk", "He coughs out a Hanger Hawk!")
	else:
		_minions.append(level.spawn_enemy("bunny", Vector2(left - 60.0, floor_y - 10.0), 100.0, left - 70.0))


# Say something only once per fight (so the screen is not full of text).
func _tell(key: String, text: String) -> void:
	if not _told.has(key):
		_told[key] = true
		say(text)


func defeat() -> void:
	if dead:
		return
	for i in 6:
		Art.burst(get_parent(), global_position + Vector2(randf_range(-100, 100), randf_range(-300, -20)),
			[Color("ffd23f"), Color("ff7675"), Color("55efc4"), Color("74b9ff")][i % 4], 30, 380.0, 1.8)
	shake(20.0)
	super()


func _draw() -> void:
	var w := BODY.x
	var h := BODY.y
	var shake_x := sin(_t * 50.0) * 3.0 if (state == S.SUCK or state == S.CLOGGED or state == S.HURT) else 0.0
	draw_set_transform(Vector2(shake_x, 0), 0.0, Vector2.ONE)

	var body := Color("6c5ce7")
	if state == S.HURT and int(_t * 16.0) % 2 == 0:
		body = Color("d63031")
	elif state == S.CLOGGED:
		body = Color("8e44ad")
	# the dust bag (a big round belly) and the motor at the bottom
	draw_rect(Rect2(-w / 2.0, -h + 40, w, h - 40), body)
	draw_circle(Vector2(0, -h + 60), w / 2.0, body)
	draw_rect(Rect2(-w / 2.0 - 10, -50, w + 20, 50), Color("2d3436"))
	draw_rect(Rect2(-w / 2.0, -h + 40, w, h - 40), OUTLINE, false, 4.0)
	for x in [-70.0, 70.0]:
		draw_circle(Vector2(x, -6), 16.0, Color("636e72")) # wheels
		draw_arc(Vector2(x, -6), 16.0, 0.0, TAU, 16, OUTLINE, 3.0)

	# the red button on his head (the target!)
	var glow := 0.5 + 0.5 * sin(_t * 10.0) if state == S.CLOGGED else 0.0
	draw_rect(Rect2(-40, -h - 14, 80, 18), Color("d63031").lightened(glow * 0.4))
	draw_rect(Rect2(-40, -h - 14, 80, 18), OUTLINE, false, 3.0)
	if state == S.CLOGGED:
		draw_string(ThemeDB.fallback_font, Vector2(-90, -h - 30), "JUMP HERE!", HORIZONTAL_ALIGNMENT_CENTER, 180, 24, Color(1, 1, 0.6, 0.5 + glow * 0.5))

	# a cape collar and two fangs (he is a COUNT, after all)
	draw_colored_polygon(PackedVector2Array([Vector2(-w / 2.0, -h + 110), Vector2(-w / 2.0 - 30, -h + 30), Vector2(-30, -h + 100)]), Color("2d3436"))
	draw_colored_polygon(PackedVector2Array([Vector2(w / 2.0, -h + 110), Vector2(w / 2.0 + 30, -h + 30), Vector2(30, -h + 100)]), Color("2d3436"))
	var eye_y := -h + 80.0
	for side in [-1.0, 1.0]:
		var c := Vector2(side * 40.0, eye_y)
		if state == S.HURT or state == S.CLOGGED:
			draw_line(c + Vector2(-10, -10), c + Vector2(10, 10), Color.WHITE, 4.0)
			draw_line(c + Vector2(-10, 10), c + Vector2(10, -10), Color.WHITE, 4.0)
		else:
			draw_circle(c, 13.0, Color("ffeaa7"))
			draw_circle(c + Vector2(-4, 2), 6.0, Color("d63031"))
			draw_line(c + Vector2(-side * 22.0, -20), c + Vector2(side * 16.0, -8), Color.BLACK, 6.0)
	draw_line(Vector2(-35, -h + 125), Vector2(35, -h + 125), OUTLINE, 4.0)
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(side * 20, -h + 125), Vector2(side * 10, -h + 125), Vector2(side * 15, -h + 142)]), Color.WHITE)

	# the hose and nozzle on the left
	var mouth := nozzle() - global_position
	draw_line(Vector2(-w / 2.0, -150), mouth + Vector2(10, -20), Color("2d3436"), 18.0)
	draw_rect(Rect2(mouth.x - 26, mouth.y - 24, 52, 48), Color("2d3436"))
	draw_rect(Rect2(mouth.x - 26, mouth.y - 24, 52, 48), OUTLINE, false, 3.0)
	if state == S.SUCK:
		# air lines rushing into the nozzle
		for i in 6:
			var k := fposmod(_t * 1.8 + i / 6.0, 1.0)
			var y := mouth.y + sin(i * 2.1) * 30.0
			var x0 := mouth.x - 40.0 - (1.0 - k) * 360.0
			draw_line(Vector2(x0, y), Vector2(x0 + 40, y), Color(1, 1, 1, 0.5 * k), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
