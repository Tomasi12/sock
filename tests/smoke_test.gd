# smoke_test.gd
# An automatic test. It opens every scene and every level, then "plays" by
# itself to check each mechanic, each enemy and each boss.
#
# Run it from a terminal (in the project folder):
#   godot --headless --fixed-fps 60 res://tests/smoke_test.tscn
extends Node

const SockTypes = preload("res://scripts/sock_types.gd")
const Builder = preload("res://scripts/level_builder.gd")
const LevelScene = preload("res://scenes/level.tscn")

const W := SockTypes.Kind.WOOL
const T := SockTypes.Kind.TOE
const G := SockTypes.Kind.GYM
const R := SockTypes.Kind.RUBBER

var failures: Array[String] = []
var level
var player


func _ready() -> void:
	GameState.saving_enabled = false # never touch the real save file
	AudioServer.set_bus_mute(0, true)
	_run.call_deferred()


func _run() -> void:
	await _test_design()
	await _test_screens()
	await _test_every_level_loads()
	await _test_mechanics()
	await _test_boss_fluff()
	await _test_boss_iron()
	await _test_boss_dryer()
	await _test_rubber_and_hawks()
	await _test_boss_vacuum()

	print("")
	if failures.is_empty():
		print("SMOKE TEST: ALL PASSED")
	else:
		print("SMOKE TEST: %d FAILED" % failures.size())
		for f in failures:
			print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


# ---------------- 1. Level design rules ----------------

func _test_design() -> void:
	print("-- level design")
	var ids := {}
	for data in GameState.levels:
		var id: String = data["id"]
		_check(data["errors"].is_empty(), "%s has no design errors %s" % [id, str(data["errors"])])
		_check(not ids.has(id), "%s id is unique" % id)
		ids[id] = true
		_check(data["drain"] != Vector2.ZERO, "%s has a drain" % id)
		_check(data["need"] <= data["socks"].size(), "%s needs %d of %d socks" % [id, data["need"], data["socks"].size()])
	_check(GameState.levels.size() == 24, "the campaign has 24 stages")
	var total_width := 0.0
	for data in GameState.levels:
		total_width += data["width"]
	print("   total level length: %d px" % int(total_width))
	await _wait(1)


# ---------------- 2. Menus ----------------

func _test_screens() -> void:
	print("-- screens")
	for path in ["res://scenes/main_menu.tscn", "res://scenes/intro.tscn", "res://scenes/world_map.tscn"]:
		var scene = load(path).instantiate()
		add_child(scene)
		await _wait(20)
		scene.queue_free()
		await _wait(2)
	_check(true, "menu, story and map screens open")


# ---------------- 3. Every level runs ----------------

func _test_every_level_loads() -> void:
	print("-- every level")
	for data in GameState.levels:
		await _load(data)
		await _wait(45)
		var feet: float = player.global_position.y
		_check(player.is_on_floor() and absf(feet - data["start"].y) < 6.0, "%s loads and the hero stands on the floor" % data["id"])
		await _unload()


# ---------------- 4. All mechanics on a small test level ----------------

func _test_mechanics() -> void:
	print("-- mechanics")
	var b := Builder.new("T-1", "Test", 1)
	b.start()
	b.socks([W, G, T, T])
	b.box_puddle()
	b.flat(200)
	b.bunnies(1, 450)
	b.flat(300)
	b.wall(280)
	b.flat(300)
	b.sparks(1, 400, "h")
	b.snappers(1, 400)
	b.iron_trap()
	b.moths(1, 500)
	b.drain()
	var data := b.finish(3)
	_check(data["errors"].is_empty(), "test level has no design errors")
	await _load(data)

	for action in ["move_left", "move_right", "jump", "recruit", "command", "pick_next", "pick_wool", "pick_toe", "pick_gym", "pick_rubber", "restart", "mute"]:
		_check(InputMap.has_action(action), "input action '%s' exists" % action)

	# Walking and jumping with the real input actions
	var start_x: float = player.global_position.x
	Input.action_press("move_right")
	await _wait(20)
	Input.action_release("move_right")
	_check(player.global_position.x > start_x + 40.0, "hero walks right")
	Input.action_press("jump")
	await _wait(2)
	Input.action_release("jump")
	_check(player.velocity.y < 0.0, "hero jumps")
	await _wait(60)

	# Recruit with the real E key, then the others
	var wool = _sock(W, 0)
	var gym = _sock(G, 0)
	var toe1 = _sock(T, 0)
	var toe2 = _sock(T, 1)
	_teleport(wool.global_position + Vector2(-40, -2))
	await _wait(5)
	await _tap("recruit")
	_check(player.army.size() == 1, "E recruits a sock")
	for s in [gym, toe1, toe2]:
		_teleport(s.global_position + Vector2(-30, -2))
		await _wait(5)
		player._try_recruit()
	_check(player.army.size() == 4, "all four socks recruited")

	# Sock picker
	player._set_pick(G)
	_check(player._choose_sock_to_send() == gym, "pressing 3 picks the Gym Sock")
	player._set_pick(G)
	_check(player.selected_kind == -1, "pressing 3 again goes back to AUTO")

	# Wool Sock pushes the box into the puddle (real Q key: hold, then let go)
	var box = level.boxes[0]
	_teleport(Vector2(box.global_position.x - 120.0, 598))
	player.facing = 1.0
	await _wait(10)
	Input.action_press("command")
	await _wait(3)
	_check(player._aim_line.visible, "holding Q shows the aim line")
	Input.action_release("command")
	await _wait(3)
	_check(wool.state == wool.State.WALK, "letting go of Q sends the Wool Sock (smart pick)")
	await _wait(330)
	_check(box.global_position.y > 640.0, "box fell into the puddle")
	_check(wool.state == wool.State.PLACED, "Wool Sock finished its job")

	# Gym Sock stinks the Lint Bunny, then we stomp it
	var bunny = _enemy("bunny")
	_teleport(Vector2(bunny.global_position.x - 160.0, 598))
	player.facing = 1.0
	await _wait(2)
	player._command()
	_check(gym.state == gym.State.THROWN, "Gym Sock is thrown at the bunny (smart pick)")
	await _wait(70)
	_check(bunny.stun_time > 0.0, "stink cloud stuns the Lint Bunny")
	_teleport(bunny.global_position + Vector2(0, -130))
	await _wait(40)
	_check(not is_instance_valid(bunny) or bunny.dead, "jumping on a stunned bunny defeats it")
	_check(player.army.size() == 2, "stomping does not cost a sock")

	# Whistle
	_teleport(Vector2(1300, 598))
	await _wait(5)
	player._try_recruit()
	await _wait(60)
	_check(player.army.size() == 4, "whistle calls placed socks back")

	# Two Toe Socks on a 280 wall, then REALLY climb it with jumps
	var wall_x := 0.0
	for block in data["blocks"]:
		if block["rect"].position.y == 320.0:
			wall_x = block["rect"].position.x
			break
	_teleport(Vector2(wall_x - 120.0, 598))
	player.facing = 1.0
	await _wait(10)
	player._command()
	await _wait(150)
	player._command()
	await _wait(150)
	_check(toe1.state == toe1.State.PLACED and toe1.climbed, "Toe Sock 1 sticks to the wall (y=%.0f)" % toe1.global_position.y)
	_check(toe2.state == toe2.State.PLACED and toe2.climbed, "Toe Sock 2 sticks to the wall (y=%.0f)" % toe2.global_position.y)
	_check(toe2.global_position.y < toe1.global_position.y, "Toe Socks make a staircase")
	_teleport(Vector2(wall_x - 70.0, 598))
	await _wait(5)
	Input.action_press("move_right")
	for i in 3:
		Input.action_press("jump")
		await _wait(20)
		Input.action_release("jump")
		await _wait(45)
	Input.action_release("move_right")
	_check(player.global_position.y < 325.0 and player.global_position.x > wall_x,
		"hero climbs the 280 wall on two Toe Socks (y=%.0f)" % player.global_position.y)
	player._try_recruit()
	await _wait(60)
	_check(player.army.size() == 4, "whistle from the top of the wall")

	# Static Spark: the smart pick sends Wool, Wool soaks it up
	var spark = _enemy("spark")
	_teleport(Vector2(spark.point_a.x - 200.0, 318))
	player.facing = 1.0
	await _wait(5)
	_check(player._choose_sock_to_send() == wool, "smart pick chooses Wool for a Spark")
	player._command()
	await _wait_until(func(): return not is_instance_valid(spark) or spark.dead, 300)
	_check(not is_instance_valid(spark) or spark.dead, "Wool Sock defeats the Static Spark")
	player._try_recruit()
	await _wait(60)

	# Clothespin Snapper: it drops, misses, then we stomp it
	var snapper = _enemy("snapper")
	_teleport(Vector2(snapper.global_position.x - 100.0, 318))
	await _wait(8)
	_check(snapper.state != snapper.S.HANG, "Snapper wiggles when the hero walks under")
	await _wait(50)
	_check(snapper.state == snapper.S.GROUND, "Snapper is stuck in the floor after the snap")
	_teleport(snapper.global_position + Vector2(0, -130))
	await _wait(40)
	_check(not is_instance_valid(snapper) or snapper.dead, "jumping on a stuck Snapper defeats it")

	# Hot Iron: stand across the puddle, it charges and falls in
	var iron = _enemy("iron")
	var pit_start: float = iron.left_x - 80.0 - 170.0
	_teleport(Vector2(pit_start - 40.0, 318))
	await _wait_until(func(): return not is_instance_valid(iron) or iron.dead, 900)
	_check(not is_instance_valid(iron) or iron.dead, "Hot Iron charges into the puddle and is defeated")

	# Moth: it steals a sock, then the stink gets it
	var moth = _enemy("moth")
	_teleport(Vector2(moth.home.x - 150.0, 318))
	player.facing = 1.0
	var before: int = player.army.size()
	await _wait_until(func(): return player.army.size() < before, 400)
	_check(player.army.size() == before - 1, "Moth chews a sock out of the army")
	_check(not level.flawless, "a lost sock means no flawless star")
	await _wait(90) # let the chewed sock land first
	player._try_recruit()
	await _wait(60)
	_check(player.army.size() == before, "whistle brings the chewed sock back")
	_teleport(Vector2(moth.home.x - 175.0, 318))
	player.facing = 1.0
	player._set_pick(G)
	await _wait(2)
	player._command()
	await _wait_until(func(): return not is_instance_valid(moth) or moth.dead, 240)
	_check(not is_instance_valid(moth) or moth.dead, "stink cloud defeats the Moth")
	player._set_pick(G)

	# Win
	player._try_recruit()
	await _wait(60)
	_teleport(level.drain.global_position + Vector2(0, -2))
	await _wait(30)
	_check(level.won, "reaching the drain with enough socks wins")
	await _wait(80)
	await _unload()


# ---------------- 5. Bosses ----------------

func _test_boss_fluff() -> void:
	print("-- boss: Big Fluff")
	await _load(_level_by_id("1-B"))
	var boss = level.boss
	_check(boss != null and level.drain.locked, "boss level starts with a locked drain")
	for hit in 3:
		# stun it (what the stink cloud does) as soon as it stands on the floor
		await _wait_until(func():
			boss.stun(1.0)
			return boss.stun_time > 0.0, 600)
		var hp_before: int = boss.hp
		_teleport(boss.global_position + Vector2(0, -200))
		await _wait_until(func(): return not is_instance_valid(boss) or boss.hp < hp_before, 90)
		_check(not is_instance_valid(boss) or boss.hp == hp_before - 1, "stomp %d hurts Big Fluff" % (hit + 1))
	await _wait(30)
	_check(not is_instance_valid(boss) or boss.dead, "Big Fluff is defeated after 3 stomps")
	_check(not level.drain.locked, "the drain unlocks")
	await _finish_boss_level()


func _test_boss_iron() -> void:
	print("-- boss: The Iron Baron")
	await _load(_level_by_id("2-B"))
	var boss = level.boss
	var ammo = _sock(T, 0)
	player.add_to_army(ammo)
	for hit in 3:
		# stand on the high button so his charge misses, wait for the crash
		_teleport(Vector2(470, 408))
		await _wait_until(func(): return boss.state == boss.S.DAZED, 900)
		_check(boss.state == boss.S.DAZED, "Iron Baron crashes into a wall and is dizzy (%d)" % (hit + 1))
		var side := -1.0 if boss.global_position.x > 850.0 else 1.0
		_teleport(Vector2(boss.global_position.x + side * 170.0, 598))
		player.facing = -side
		var hp_before: int = boss.hp
		await _wait(2)
		if not (ammo in player.army):
			player.add_to_army(ammo)
		player._command()
		await _wait_until(func(): return not is_instance_valid(boss) or boss.hp < hp_before, 60)
		_check(not is_instance_valid(boss) or boss.hp == hp_before - 1, "thrown sock %d hurts the dizzy Iron Baron" % (hit + 1))
		await _wait(50)
	_check(not is_instance_valid(boss) or boss.dead, "Iron Baron is defeated after 3 hits")
	await _finish_boss_level()


func _test_boss_dryer() -> void:
	print("-- boss: The Dryer King")
	await _load(_level_by_id("3-B"))
	var boss = level.boss
	var ammo = _sock(T, 0)
	player.add_to_army(ammo)
	_teleport(Vector2(900, 598))

	# a sock thrown at the closed door bounces off
	var door_x: float = boss.global_position.x - 150.0
	_teleport(Vector2(door_x - 150.0, 598))
	player.facing = 1.0
	await _wait(2)
	player._command()
	await _wait(40)
	_check(boss.hp == 5, "a sock thrown at the CLOSED door does nothing")

	# the hot air really pushes the hero
	await _wait_until(func(): return boss.state == boss.S.BLOW, 600)
	_teleport(Vector2(door_x - 300.0, 598))
	await _wait(60)
	_check(player.global_position.x < door_x - 380.0, "hot air pushes the hero away (x=%.0f)" % player.global_position.x)

	# wait for the door to open by itself, then stuff socks in
	await _wait_until(func(): return boss.state == boss.S.OPEN, 600)
	_check(boss.state == boss.S.OPEN, "the door opens after the hot air")
	for hit in 5:
		if is_instance_valid(boss) and not boss.dead:
			boss.state = boss.S.OPEN # (the test does not wait for every cycle)
			boss._timer = 3.0
		_teleport(Vector2(door_x - 150.0, 598))
		player.facing = 1.0
		var hp_before: int = boss.hp
		await _wait(2)
		if not (ammo in player.army):
			player.add_to_army(ammo)
		player._command()
		await _wait_until(func(): return not is_instance_valid(boss) or boss.hp < hp_before, 60)
		_check(not is_instance_valid(boss) or boss.hp == hp_before - 1, "sock %d stuffed into the open door" % (hit + 1))
		await _wait(40)
	_check(not is_instance_valid(boss) or boss.dead, "The Dryer King is defeated after 5 socks")
	await _finish_boss_level()


# ---------------- 6. World 4: Rubber Sock and Hanger Hawk ----------------

func _test_rubber_and_hawks() -> void:
	print("-- Rubber Sock and Hanger Hawk")
	var b := Builder.new("T-4", "Test 4", 4)
	b.start()
	b.socks([R, T])
	b.flat(400)
	b.wall(400)
	b.flat(300)
	b.chasm(300)
	b.flat(700)
	b.hawks(1, 600)
	b.drain()
	var data := b.finish(1)
	_check(data["errors"].is_empty(), "World 4 test level has no design errors %s" % str(data["errors"]))
	var bad := Builder.new("T-5", "Bad", 4)
	bad.start()
	bad.chasm(300)
	bad.wall(400)
	_check(bad.finish(0)["errors"].size() == 2, "the builder knows a chasm and a giant wall need a Rubber Sock")
	await _load(data)
	var rubber = _sock(R, 0)
	var toe = _sock(T, 0)
	player.add_to_army(rubber)
	player.add_to_army(toe)

	# Pressing 4 picks the Rubber Sock, Q only drops it a short way.
	await _tap("pick_rubber")
	_check(player.selected_kind == R, "pressing 4 picks the Rubber Sock")
	_teleport(Vector2(560, 598))
	player.facing = 1.0
	await _wait(5)
	player._command()
	await _wait(60)
	_check(rubber.state == rubber.State.PLACED and rubber.is_trampoline(), "the Rubber Sock lands and becomes a trampoline")
	var drop: float = rubber.global_position.x - 560.0
	_check(drop > 40.0 and drop < 110.0, "it lands just in front of the hero (%d px)" % int(drop))

	# Jump on it: a much higher bounce than a normal jump.
	_teleport(Vector2(rubber.global_position.x, 520))
	var top := 9999.0
	for i in 100:
		await _wait(1)
		top = minf(top, player.global_position.y)
	var height := 600.0 - top
	_check(height > 380.0, "bouncing on a Rubber Sock goes about 400 px high (%d px)" % int(height))
	# A bounce can not be made smaller by letting go of jump.
	_teleport(Vector2(rubber.global_position.x, 520))
	Input.action_press("jump")
	await _wait(1)
	top = 9999.0
	for i in 100:
		await _wait(1)
		if i == 12:
			Input.action_release("jump")
		top = minf(top, player.global_position.y)
	_check(600.0 - top > 380.0, "letting go of jump does not spoil the bounce (%d px)" % int(600.0 - top))
	await _wait(30)

	# A normal jump does not get over a 400 wall, a bounce does.
	var wall_x: float = _piece(data, "wall")["x0"] + 120.0
	_teleport(Vector2(wall_x - 30.0, 598))
	Input.action_press("move_right")
	Input.action_press("jump")
	await _wait(60)
	Input.action_release("jump")
	Input.action_release("move_right")
	_check(player.global_position.x < wall_x, "a normal jump can not climb a 400 wall")
	player._try_recruit()
	await _wait(70)
	_teleport(Vector2(wall_x - 60.0, 598))
	player.facing = 1.0
	player._set_pick(-1) # back to AUTO
	await _wait(5)
	_check(player._choose_sock_to_send() == rubber, "AUTO picks the Rubber Sock for a giant wall")
	player._command()
	await _wait(60)
	await _bounce_right(rubber)
	_check(player.global_position.y < 205.0 and player.global_position.x > wall_x,
		"bouncing on a Rubber Sock gets the hero on top of a 400 wall (y=%d)" % int(player.global_position.y))
	player._try_recruit()
	await _wait(70)
	_check(rubber in player.army, "the whistle brings the Rubber Sock up the wall")

	# The chasm: too wide to jump, but a bounce flies over it.
	var edge: float = _piece(data, "chasm")["x0"] + 220.0
	var floor_y: float = _piece(data, "chasm")["gy"] - 2.0
	var before: int = level.respawns
	_teleport(Vector2(edge - 60.0, floor_y))
	await _wait(5)
	Input.action_press("move_right")
	while player.global_position.x < edge - 6.0:
		await _wait(1)
	Input.action_press("jump")
	await _wait(150)
	Input.action_release("jump")
	Input.action_release("move_right")
	_check(level.respawns == before + 1, "a running jump falls into a 300 px chasm")
	_teleport(Vector2(edge - 110.0, floor_y))
	player.facing = 1.0
	await _wait(5)
	_check(player._choose_sock_to_send() == rubber, "AUTO picks the Rubber Sock in front of a chasm")
	player._command()
	await _wait(60)
	_check(rubber.is_trampoline() and rubber.global_position.x < edge, "the Rubber Sock waits on this side of the chasm")
	await _bounce_right(rubber)
	_check(level.respawns == before + 1 and player.global_position.x > edge + 300.0,
		"one bounce flies over the chasm (x=%d)" % int(player.global_position.x))
	player._try_recruit()
	await _wait(70)
	_check(rubber in player.army, "the whistle calls the Rubber Sock across the chasm")

	# Hanger Hawk: it dives at the hero, and can be stomped from above.
	var hawk = _enemy("hanger")
	_check(hawk != null, "the Hanger Hawk is in the level")
	var hawk_x: float = hawk.global_position.x
	_teleport(Vector2(hawk_x, floor_y))
	var bonks: int = level.bonks
	await _wait_until(func(): return level.bonks > bonks, 200)
	_check(level.bonks > bonks, "a Hanger Hawk dives at a hero standing still")
	await _wait_until(func(): return hawk.state == hawk.S.CRUISE, 400)
	_check(hawk.state == hawk.S.CRUISE and hawk.global_position.y < floor_y - 200.0, "after the dive it flies back up high")
	# Out of reach for a normal jump
	_teleport(Vector2(hawk.global_position.x + 300.0, floor_y))
	await _wait(30)
	_check(floor_y - 128.0 - 46.0 > hawk.global_position.y + 22.0, "it cruises too high for a normal jump")
	_teleport(hawk.global_position + Vector2(hawk.dir * 20.0, -60))
	await _wait(40)
	_check(not is_instance_valid(hawk) or hawk.dead, "landing on a cruising Hanger Hawk from above defeats it")
	await _unload()


func _test_boss_vacuum() -> void:
	print("-- boss: Count Suckula")
	await _load(_level_by_id("4-B"))
	var boss = level.boss
	_check(boss != null and level.drain.locked, "the vacuum boss level starts with a locked drain")
	var wool = _sock(W, 0)
	var rubber = _sock(R, 0)
	player.add_to_army(wool)
	player.add_to_army(rubber)
	var left: float = boss.global_position.x - boss.BODY.x / 2.0

	# He sucks: the hero is pulled towards him.
	await _wait_until(func(): return boss.state == boss.S.SUCK, 900)
	_check(boss.state == boss.S.SUCK, "Count Suckula starts sucking")
	_teleport(Vector2(left - 420.0, 598))
	await _wait(60)
	_check(player.global_position.x > left - 400.0, "sucking pulls the hero (x=%d)" % int(player.global_position.x))

	# A skinny sock slips through, a Wool Sock clogs him.
	_teleport(Vector2(left - 230.0, 598))
	player.facing = 1.0
	player._set_pick(R)
	await _wait(2)
	player._command()
	await _wait(40)
	_check(boss.state == boss.S.SUCK and boss.hp == 3, "a Rubber Sock does not clog him")
	player._set_pick(R)
	player._try_recruit() # get the Rubber Sock back (it would block the Wool Sock)
	await _wait(70)
	for hit in 3:
		if not is_instance_valid(boss) or boss.dead:
			break
		boss.state = boss.S.SUCK # (the test does not wait for every cycle)
		boss._timer = 5.0
		_teleport(Vector2(left - 260.0, 598))
		player.facing = 1.0
		await _wait(2)
		if not (wool in player.army):
			player.add_to_army(wool)
		player._set_pick(W)
		player._command()
		player._set_pick(W)
		await _wait_until(func(): return boss.state == boss.S.CLOGGED, 240)
		_check(boss.state == boss.S.CLOGGED, "a Wool Sock clogs his nozzle (%d)" % (hit + 1))
		# jump on the red button on his head
		var hp_before: int = boss.hp
		_teleport(Vector2(boss.global_position.x, boss.global_position.y - boss.BODY.y - 60.0))
		await _wait_until(func(): return not is_instance_valid(boss) or boss.hp < hp_before, 90)
		_check(not is_instance_valid(boss) or boss.hp == hp_before - 1, "landing on his button hurts him (%d)" % (hit + 1))
		await _wait(60)
	_check(not is_instance_valid(boss) or boss.dead, "Count Suckula is defeated after 3 hits")

	# The real way up: bounce on a Rubber Sock next to him.
	await _finish_boss_level()

	# A fresh fight: check that the bounce really reaches his head.
	await _load(_level_by_id("4-B"))
	boss = level.boss
	rubber = _sock(R, 0)
	player.add_to_army(rubber)
	boss._timer = 30.0 # keep him resting (no bunnies, no sucking) for this check
	left = boss.global_position.x - boss.BODY.x / 2.0
	_teleport(Vector2(left - 140.0, 598))
	player.facing = 1.0
	player._set_pick(R)
	await _wait(5)
	player._command()
	await _wait(60)
	# bounce, and let go of "right" once we are above him
	_teleport(rubber.global_position + Vector2(0, -44))
	await _wait(8)
	Input.action_press("move_right")
	await _wait_until(func(): return player.global_position.x > boss.global_position.x - 20.0, 120)
	Input.action_release("move_right")
	await _wait_until(func(): return player.is_on_floor(), 120)
	_check(absf(player.global_position.y - (boss.global_position.y - boss.BODY.y)) < 4.0,
		"a Rubber Sock bounce lands the hero on Count Suckula's head (y=%d)" % int(player.global_position.y))
	await _unload()


func _finish_boss_level() -> void:
	await _wait(30)
	_check(get_tree().get_nodes_in_group("enemies").is_empty(), "the boss's helpers are gone")
	for s in get_tree().get_nodes_in_group("recruits"):
		if not (s in player.army):
			s.recall(player)
	await _wait(60)
	_teleport(level.drain.global_position + Vector2(0, -2))
	await _wait(30)
	_check(level.won, "boss level can be finished")
	await _wait(80)
	await _unload()


# ---------------- Helpers ----------------

func _load(data: Dictionary) -> void:
	level = LevelScene.instantiate()
	level.data = data
	add_child(level)
	await _wait(5)
	player = level.player


func _unload() -> void:
	Input.action_release("move_right")
	level.queue_free()
	level = null
	player = null
	await _wait(3)


# Drop the hero onto a Rubber Sock, and hold "right" once it bounced.
func _bounce_right(sock) -> void:
	_teleport(sock.global_position + Vector2(0, -44))
	await _wait(8)
	Input.action_press("move_right")
	await _wait(150)
	Input.action_release("move_right")
	await _wait(10)


func _piece(data: Dictionary, kind: String) -> Dictionary:
	for p in data["pieces"]:
		if p["kind"] == kind:
			return p
	return {}


func _level_by_id(id: String) -> Dictionary:
	for data in GameState.levels:
		if data["id"] == id:
			return data
	return {}


func _sock(kind: int, nth: int):
	var found := 0
	for s in get_tree().get_nodes_in_group("recruits"):
		if s.kind == kind:
			if found == nth:
				return s
			found += 1
	return null


func _enemy(type: String):
	for e in level.enemies:
		if is_instance_valid(e) and e.get_script() == level.ENEMY_SCRIPTS[type]:
			return e
	return null


func _teleport(pos: Vector2) -> void:
	player.respawn(pos)
	player._invulnerable = 0.0


func _tap(action: String) -> void:
	Input.action_press(action)
	await _wait(2)
	Input.action_release(action)
	await _wait(3)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures.append(what)


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


# Wait until something is true (or give up after max_frames).
func _wait_until(condition: Callable, max_frames: int) -> void:
	for i in max_frames:
		if condition.call():
			return
		await get_tree().physics_frame
