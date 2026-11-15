# boss_iron.gd
# BOSS 2: THE IRON BARON, a giant hot iron.
# He aims at you, then charges across the whole room.
# HOW TO BEAT HIM: jump on the buttons so he misses. He crashes into the wall
# and gets dizzy. Run close and throw a sock at him (Q). Do that 3 times.
# Socks thrown while he is NOT dizzy just bounce off.
extends "res://scripts/enemy.gd"

const IronArt = preload("res://scripts/iron_art.gd")

enum S { AIM, CHARGE, DAZED, RECOVER }

var state: int = S.AIM
var dir := -1.0
var _timer := 2.0
var _t := 0.0
var _clang_cooldown := 0.0


func _ready() -> void:
	boss_name = "THE IRON BARON"
	max_hp = 3
	hp = 3
	hurt_center = Vector2(0, -48)
	setup_body(Vector2(150, 96), 48.0, 1)
	add_to_group("bosses")


func stun(_seconds: float) -> void:
	pass


func can_be_stomped() -> bool:
	return false


func on_soaked() -> void:
	pass


func is_useful() -> bool:
	return false # don't auto-pick the Gym Sock for him


func touch_player(p) -> void:
	if state == S.AIM or state == S.CHARGE:
		p.hit_by_enemy(global_position.x)


func _physics_process(delta: float) -> void:
	if dead:
		return
	_t += delta
	_clang_cooldown -= delta
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 1300.0)
	var rage := max_hp - hp

	match state:
		S.AIM:
			velocity.x = 0.0
			_timer -= delta
			var p = hero()
			if p != null and _timer > 0.3: # he stops turning just before charging
				var d := signf(p.global_position.x - global_position.x)
				if d != 0.0:
					dir = d
			if _timer <= 0.0:
				state = S.CHARGE
				Sfx.play("stink", 1.6)
		S.CHARGE:
			velocity.x = dir * (380.0 + 70.0 * rage)
			if is_on_wall():
				# CRASH!
				state = S.DAZED
				_timer = 2.8 - 0.4 * rage
				velocity.x = 0.0
				shake(12.0)
				Sfx.play("bonk", 0.6)
				Art.burst(get_parent(), global_position + Vector2(dir * 70.0, -50), Color("ffd23f"), 20, 260.0, 1.2)
				say("CRASH! He is dizzy. Throw a sock at him NOW! (Q)")
		S.DAZED:
			velocity.x = 0.0
			_timer -= delta
			if _timer <= 0.0:
				state = S.AIM
				_timer = 1.0
		S.RECOVER:
			_timer -= delta
			if _timer <= 0.0:
				state = S.AIM
				_timer = 0.9

	if state != S.RECOVER:
		_check_sock_hits(state == S.DAZED)
	move_and_slide()
	queue_redraw()
	check_player_touch()


# Did a flying (or marching) sock reach us?
func _check_sock_hits(vulnerable: bool) -> void:
	var middle := global_position + Vector2(0, -48)
	for sock in get_tree().get_nodes_in_group("recruits"):
		if not sock.is_attacking():
			continue
		if (sock.global_position + Vector2(0, -20)).distance_to(middle) > 95.0:
			continue
		var away := signf(sock.global_position.x - global_position.x)
		sock.knock_away(away if away != 0.0 else -dir)
		if not vulnerable:
			Sfx.play("bonk", 1.5)
			if _clang_cooldown <= 0.0:
				_clang_cooldown = 3.0
				say("CLANG! It bounced off. Wait until he crashes into a wall.")
			continue
		hp -= 1
		hp_changed.emit(hp, max_hp)
		Sfx.play("boss_hit")
		shake(10.0)
		if hp <= 0:
			say("The Iron Baron cools down... forever.")
			defeat()
		else:
			say("BONK! Right on the handle! He is steaming mad.")
			state = S.RECOVER
			_timer = 1.2
		return


func _draw() -> void:
	var heat := 0.3
	if state == S.AIM:
		heat = 0.5 + 0.5 * sin(_t * 24.0)
	elif state == S.CHARGE:
		heat = 1.0
	elif state == S.DAZED:
		heat = 0.0
	var wobble := sin(_t * 10.0) * 0.05 if state == S.DAZED else 0.0
	if state == S.RECOVER and int(_t * 14.0) % 2 == 0:
		return # blink while recovering
	draw_set_transform(Vector2.ZERO, wobble, Vector2(dir * 2.6, 2.6))
	IronArt.draw_iron(self, heat, state == S.DAZED, _t)
