# smoke_test.gd
# An automatic test: it opens every scene and "plays" the level by itself to
# check that recruiting, pushing, stinking, climbing, whistling and winning work.
#
# Run it from a terminal (in the project folder):
#   godot --headless --fixed-fps 60 -s res://tests/smoke_test.gd
extends SceneTree

const SockTypes = preload("res://scripts/sock_types.gd")

var failures: Array[String] = []
var level
var player


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# 1) The menu and the intro open without errors
	for path in ["res://scenes/main_menu.tscn", "res://scenes/intro.tscn"]:
		var scene = load(path).instantiate()
		root.add_child(scene)
		await _wait(20)
		scene.queue_free()
		await _wait(2)

	# 2) The level
	level = load("res://scenes/level.tscn").instantiate()
	root.add_child(level)
	await _wait(30)
	player = level.player

	# Input actions exist
	for action in ["move_left", "move_right", "jump", "recruit", "command"]:
		_check(InputMap.has_action(action), "input action '%s' exists" % action)

	# Walking right with the real input action
	var start_x: float = player.global_position.x
	Input.action_press("move_right")
	await _wait(30)
	Input.action_release("move_right")
	_check(player.global_position.x > start_x + 50.0, "player walks right")

	# Jumping
	Input.action_press("jump")
	await _wait(2)
	Input.action_release("jump")
	_check(player.velocity.y < 0.0, "player jumps")
	await _wait(60)

	# Recruit the Wool Sock with the real E key action
	var wool = _sock(SockTypes.Kind.WOOL, 0)
	_teleport(wool.global_position + Vector2(-40, -2))
	await _wait(5)
	Input.action_press("recruit")
	await _wait(2)
	Input.action_release("recruit")
	await _wait(5)
	_check(player.army.size() == 1, "E recruits the Wool Sock")

	var gym = _sock(SockTypes.Kind.GYM, 0)
	_teleport(gym.global_position + Vector2(-40, -2))
	await _wait(5)
	player._try_recruit()
	_check(player.army.size() == 2, "recruit the Gym Sock")

	# Wool Sock pushes the soap box into the puddle
	_teleport(Vector2(level.box.global_position.x - 120.0, 598))
	player.facing = 1.0
	await _wait(10)
	Input.action_press("command")
	await _wait(2)
	Input.action_release("command")
	_check(wool.state == wool.State.WALK, "Q sends the Wool Sock to push")
	await _wait(330)
	_check(level.box.global_position.y > 640.0, "box fell into the puddle (y=%.0f)" % level.box.global_position.y)
	_check(wool.state == wool.State.PLACED, "Wool Sock finished its job")

	# Gym Sock stinks the Lint Bunny
	var bunny = level.bunnies[0]
	bunny.global_position.x = 1300.0
	_teleport(Vector2(bunny.global_position.x - 160.0, 598))
	player.facing = 1.0
	await _wait(2)
	player._command()
	_check(gym.state == gym.State.THROWN, "Gym Sock is thrown at the bunny")
	await _wait(70)
	_check(bunny.stun_time > 0.0, "stink cloud stuns the Lint Bunny")

	# Whistle: the two placed socks come back
	_teleport(Vector2(1000, 598))
	await _wait(5)
	player._try_recruit()
	await _wait(60)
	_check(player.army.size() == 2, "whistle calls placed socks back (army=%d)" % player.army.size())

	# A Lint Bunny hit knocks one sock away (wait until the stink cloud is gone)
	await _wait(120)
	bunny.stun_time = 0.0
	bunny.art.stunned = false
	player._invulnerable = 0.0
	_teleport(bunny.global_position + Vector2(0, -2))
	await _wait(3)
	_check(player.army.size() == 1, "bunny knocks a sock away (army=%d)" % player.army.size())
	await _wait(90)

	# Recruit the two Toe Socks, then climb the big wall
	var toe1 = _sock(SockTypes.Kind.TOE, 0)
	var toe2 = _sock(SockTypes.Kind.TOE, 1)
	for t in [toe1, toe2]:
		_teleport(t.global_position + Vector2(-30, -2))
		await _wait(5)
		player._try_recruit()
	_check(toe1.state == toe1.State.FOLLOW and toe2.state == toe2.State.FOLLOW, "recruit both Toe Socks")

	_teleport(Vector2(1880, 598))
	player.facing = 1.0
	await _wait(10)
	player._command()
	await _wait(150)
	player._command()
	await _wait(150)
	_check(toe1.state == toe1.State.PLACED and toe1.climbed, "Toe Sock 1 climbed the wall (y=%.0f)" % toe1.global_position.y)
	_check(toe2.state == toe2.State.PLACED and toe2.climbed, "Toe Sock 2 climbed the wall (y=%.0f)" % toe2.global_position.y)
	_check(toe2.global_position.y < toe1.global_position.y, "Toe Socks make a staircase")
	# The first step must be low enough to jump on (jump height is about 128 px,
	# and the top of a sock is 40 px above its feet).
	_check(598.0 - (toe1.global_position.y - 40.0) < 125.0, "first Toe step is reachable")

	# Recruit everybody back (whistle) plus any lonely socks, then go to the drain
	player._try_recruit()
	await _wait(60)
	for s in get_nodes_in_group("recruits"):
		if s.can_be_recruited():
			player.add_to_army(s)
	await _wait(5)
	_check(player.army.size() >= 3, "army has 3+ socks (army=%d)" % player.army.size())
	for b in level.bunnies:
		b.stun(10.0)
	_teleport(level.drain.global_position + Vector2(0, -2))
	await _wait(30)
	_check(level.won, "reaching the drain with 3 socks wins")
	await _wait(90)

	# Result
	print("")
	if failures.is_empty():
		print("SMOKE TEST: ALL PASSED")
		quit(0)
	else:
		print("SMOKE TEST: %d FAILED" % failures.size())
		for f in failures:
			print("  FAIL: " + f)
		quit(1)


func _sock(kind: int, nth: int):
	var found := 0
	for s in get_nodes_in_group("recruits"):
		if s.kind == kind:
			if found == nth:
				return s
			found += 1
	return null


func _teleport(pos: Vector2) -> void:
	player.respawn(pos)
	player._invulnerable = 0.0


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures.append(what)


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame
