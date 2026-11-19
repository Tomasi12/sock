# unit_test.gd
# Many small tests that look for BUGS in the corners of the game:
#   1. level design rules (every sock stands on something, every checkpoint is safe...)
#   2. the code only uses sounds and keys that really exist
#   3. saving and loading, also with a broken save file
#   4. menus and the HUD with unusual values
#   5. "what if" cases in a level: Q with no socks, a sock falling into a hole,
#      two Toe Socks sent at once, pressing E twice, winning with too few socks...
#
# Run it from a terminal (in the project folder):
#   godot --headless --fixed-fps 60 res://tests/unit_test.tscn
extends Node

const SockTypes = preload("res://scripts/sock_types.gd")
const Builder = preload("res://scripts/level_builder.gd")
const Levels = preload("res://scripts/levels.gd")
const LevelScene = preload("res://scenes/level.tscn")
const Hud = preload("res://scripts/hud.gd")
const Bunny = preload("res://scripts/lint_bunny.gd")

const W := SockTypes.Kind.WOOL
const T := SockTypes.Kind.TOE
const G := SockTypes.Kind.GYM
const R := SockTypes.Kind.RUBBER
const TEST_SAVE := "user://unit_test_save.json"

var failures: Array[String] = []
var checks := 0
var level
var player
var data: Dictionary


func _ready() -> void:
	GameState.saving_enabled = false # never touch the real save file
	AudioServer.set_bus_mute(0, true)
	_run.call_deferred()


func _run() -> void:
	_test_design()
	_test_sounds_and_keys()
	_test_saving()
	await _test_screens()
	await _test_empty_handed()
	await _test_army_rules()
	await _test_toe_socks_together()
	await _test_socks_in_holes()
	await _test_hero_accidents()
	await _test_box_rules()
	await _test_enemy_corner_cases()
	await _test_drain_rules()
	await _test_rubber_corner_cases()

	print("")
	if failures.is_empty():
		print("UNIT TEST: ALL PASSED (%d checks)" % checks)
	else:
		print("UNIT TEST: %d of %d FAILED" % [failures.size(), checks])
		for f in failures:
			print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


# ---------------- 1. Level design rules ----------------

func _test_design() -> void:
	print("-- design rules for every level")
	for d in GameState.levels:
		var id: String = d["id"]
		var bad: Array[String] = []

		if _floor_top(d, d["start"].x) != d["start"].y + 2.0:
			bad.append("the hero does not start on the floor")
		if _floor_top(d, d["drain"].x) != d["drain"].y:
			bad.append("the drain is not on the floor")
		if d["need"] < 1 or d["need"] > d["socks"].size():
			bad.append("need=%d but the level has %d socks" % [d["need"], d["socks"].size()])
		if d["width"] < 1000.0:
			bad.append("the level is too short")

		for cp in d["checkpoints"]:
			if _floor_top(d, cp.x) != cp.y + 2.0:
				bad.append("checkpoint at x=%d is not on the floor" % int(cp.x))
			if _in_water(d, cp.x):
				bad.append("checkpoint at x=%d is in a puddle" % int(cp.x))
		for s in d["socks"]:
			if not _stands_on_something(d, s["pos"]):
				bad.append("sock at %s floats in the air" % str(s["pos"]))
			if _in_water(d, s["pos"].x):
				bad.append("sock at %s is in a puddle" % str(s["pos"]))
		for b in d["boxes"]:
			if _floor_top(d, b.x) != b.y:
				bad.append("box at x=%d is not on the floor" % int(b.x))
		for e in d["enemies"]:
			var pos: Vector2 = e["pos"]
			if pos.x < d["start"].x + 250.0:
				bad.append("%s at x=%d is too close to the start" % [e["type"], int(pos.x)])
			match e["type"]:
				"bunny", "iron":
					# it must be able to walk its whole path on flat floor
					for x in [pos.x, float(e["a"]), float(e["b"])]:
						if _floor_top(d, x) != pos.y:
							bad.append("%s at x=%d: no floor at x=%d" % [e["type"], int(pos.x), int(x)])
					if e["a"] >= e["b"]:
						bad.append("%s at x=%d has an empty path" % [e["type"], int(pos.x)])
				"snapper":
					if _floor_top(d, pos.x) != float(e["a"]):
						bad.append("snapper at x=%d does not know where the floor is" % int(pos.x))
				"spark":
					if e["a"] == e["b"]:
						bad.append("spark at x=%d does not move" % int(pos.x))

		# Normal levels are a chain of pieces with no holes in between.
		var pieces: Array = d["pieces"]
		if d["boss"].is_empty():
			if pieces.is_empty() or pieces[0]["x0"] != 0.0 or pieces[-1]["x1"] != d["width"]:
				bad.append("the pieces do not cover the level")
			if pieces.is_empty() or pieces[-1]["kind"] != "drain":
				bad.append("the last piece is not the drain")
			for i in pieces.size() - 1:
				if pieces[i]["x1"] != pieces[i + 1]["x0"]:
					bad.append("pieces %d and %d do not touch" % [i, i + 1])
		else:
			if not level_has_script(d["boss"].get("type", "")):
				bad.append("unknown boss type")
		for block in d["blocks"]:
			if block["rect"].size.x <= 0.0 or block["rect"].size.y <= 0.0:
				bad.append("a block has no size")

		_check(bad.is_empty(), "%s follows the design rules %s" % [id, "" if bad.is_empty() else str(bad)])

	# The safe ledge: nothing dangerous right where the hero lands after a wall.
	var b := Builder.new("T", "T", 1)
	b.start()
	b.socks([T, T])
	b.wall(280)
	b.snappers(1, 300)
	b.drop(280)
	b.bunnies(1, 300)
	b.drain()
	var d2 := b.finish(1)
	var wall_top_x: float = d2["pieces"][3]["x0"] + 120.0
	var snapper_x: float = d2["enemies"][0]["pos"].x
	_check(snapper_x - wall_top_x > 250.0, "an enemy after a wall waits far from the edge (%d px)" % int(snapper_x - wall_top_x))
	var bunny: Dictionary = d2["enemies"][1]
	var drop_x: float = d2["pieces"][5]["x0"] + 100.0
	_check(bunny["a"] - drop_x > 150.0, "an enemy after a drop walks far from the landing spot (%d px)" % int(bunny["a"] - drop_x))

	# The builder itself complains about impossible designs.
	var wrong := Builder.new("X", "X", 1)
	wrong.start()
	wrong.wall(280)
	wrong.box_puddle()
	wrong.drain()
	_check(wrong.finish(5)["errors"].size() == 3, "the builder reports a wall without Toe Socks, a box without Wool and a too big 'need'")

	# Building the campaign twice gives the same levels (no hidden shared state).
	var again: Array = Levels.build_all()
	var same := again.size() == GameState.levels.size()
	for i in again.size():
		if same and (again[i]["id"] != GameState.levels[i]["id"] or again[i]["width"] != GameState.levels[i]["width"]):
			same = false
	_check(same, "building the campaign twice gives the same levels")


func level_has_script(type: String) -> bool:
	var scripts: Dictionary = LevelScene.instantiate().ENEMY_SCRIPTS if false else load("res://scripts/level.gd").ENEMY_SCRIPTS
	return scripts.has(type)


# The top of the solid floor at x (the highest block that is not a one-way button).
func _floor_top(d: Dictionary, x: float) -> float:
	var top := INF
	for block in d["blocks"]:
		var r: Rect2 = block["rect"]
		if block.get("one_way", false) or block["style"] == "basket" or block["style"] == "pit":
			continue
		if x >= r.position.x and x <= r.end.x:
			top = minf(top, r.position.y)
	return top


func _stands_on_something(d: Dictionary, pos: Vector2) -> bool:
	for block in d["blocks"]:
		var r: Rect2 = block["rect"]
		if pos.x >= r.position.x and pos.x <= r.end.x and r.position.y == pos.y:
			return true
	return false


func _in_water(d: Dictionary, x: float) -> bool:
	for r in d["water"]:
		if x > r.position.x - 12.0 and x < r.end.x + 12.0:
			return true
	return false


# ---------------- 2. Sounds and keys used by the code ----------------

func _test_sounds_and_keys() -> void:
	print("-- sounds and keys")
	var sound_re := RegEx.new()
	sound_re.compile("Sfx\\.play\\(\"([a-z_]+)\"")
	var action_re := RegEx.new()
	action_re.compile("(?:is_action_just_pressed|is_action_pressed|is_action_just_released|is_action)\\(\"([a-z_]+)\"")
	var axis_re := RegEx.new()
	axis_re.compile("get_axis\\(\"([a-z_]+)\", \"([a-z_]+)\"\\)")

	var sounds := {}
	var actions := {}
	var dir := DirAccess.open("res://scripts")
	for file_name in dir.get_files():
		if not file_name.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string("res://scripts/" + file_name)
		for m in sound_re.search_all(text):
			sounds[m.get_string(1)] = file_name
		for m in action_re.search_all(text):
			actions[m.get_string(1)] = file_name
		for m in axis_re.search_all(text):
			actions[m.get_string(1)] = file_name
			actions[m.get_string(2)] = file_name

	_check(sounds.size() >= 10, "found the sounds used by the code (%d)" % sounds.size())
	for sound in sounds:
		_check(Sfx._sounds.has(sound), "sound '%s' (used in %s) exists" % [sound, sounds[sound]])
	for sound in Sfx._sounds:
		var stream: AudioStreamWAV = Sfx._sounds[sound]
		_check(stream.data.size() > 100, "sound '%s' is not empty" % sound)
	_check(actions.size() >= 10, "found the keys used by the code (%d)" % actions.size())
	for action in actions:
		_check(InputMap.has_action(action), "key action '%s' (used in %s) exists" % [action, actions[action]])
	for action in ["move_left", "move_right", "jump", "recruit", "command", "pick_next", "pick_wool", "pick_toe", "pick_gym", "pick_rubber", "restart", "mute"]:
		_check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(), "'%s' has a key" % action)

	# Playing a sound that does not exist must not crash.
	Sfx.play("this_sound_does_not_exist")
	_check(true, "an unknown sound name is ignored")


# ---------------- 3. Saving and loading ----------------

func _test_saving() -> void:
	print("-- saving")
	var old_stars: Dictionary = GameState.stars.duplicate()
	var old_intro: bool = GameState.seen_intro
	var old_current: int = GameState.current
	GameState.save_path = TEST_SAVE
	GameState.saving_enabled = true

	GameState.stars = {}
	_check(GameState.is_unlocked(0), "the first level is always open")
	_check(not GameState.is_unlocked(1), "the second level starts locked")
	_check(GameState.total_stars() == 0, "a new game has 0 stars")

	GameState.current = 0
	GameState.complete(2)
	_check(GameState.stars_for(0) == 2 and GameState.is_unlocked(1), "finishing a level saves its stars and opens the next one")
	GameState.complete(1)
	_check(GameState.stars_for(0) == 2, "a worse run does not erase a better result")
	GameState.complete(3)
	_check(GameState.stars_for(0) == 3 and GameState.total_stars() == 3, "a better run replaces the old result")
	_check(not GameState.is_unlocked(2), "levels open one at a time")

	# save -> forget -> load
	GameState.seen_intro = true
	GameState.save_game()
	GameState.stars = {}
	GameState.seen_intro = false
	GameState.load_game()
	_check(GameState.stars_for(0) == 3 and GameState.seen_intro, "progress survives saving and loading")
	_check(GameState.stars[GameState.levels[0]["id"]] is int, "loaded stars are whole numbers")

	# Broken save files must never crash the game or give strange stars.
	var broken := [
		"", "not json at all {{{", "[1, 2, 3]", "42", "null",
		"{\"stars\": [1, 2]}", "{\"stars\": \"lots\"}",
		"{\"stars\": {\"1-1\": \"three\", \"1-2\": 99, \"1-3\": -5, \"9-9\": 3, \"1-4\": 2.0}, \"seen_intro\": \"yes\"}",
	]
	for text in broken:
		var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		GameState.stars = {}
		GameState.seen_intro = false
		GameState.load_game()
		var fine := GameState.total_stars() >= 0 and GameState.stars is Dictionary
		for i in GameState.levels.size():
			var s: int = GameState.stars_for(i)
			if s < 0 or s > 3:
				fine = false
			GameState.is_unlocked(i)
		for id in GameState.stars:
			if not GameState._has_level(id):
				fine = false
		_check(fine, "a broken save file is handled: %s" % text.left(30))
	_check(GameState.stars_for(1) == 3 and GameState.stars_for(3) == 2 and GameState.stars_for(0) == 0 and GameState.stars_for(2) == 0,
		"only sensible values are read from a strange save file")

	GameState.reset_progress()
	GameState.load_game()
	_check(GameState.total_stars() == 0 and not GameState.seen_intro, "reset_progress erases everything")

	# Stories between worlds and at the end
	var worlds_seen := 0
	for i in GameState.levels.size():
		GameState.current = i
		var story: Dictionary = GameState.next_story()
		var last: bool = i == GameState.levels.size() - 1
		var new_world: bool = not last and GameState.levels[i + 1]["world"] != GameState.levels[i]["world"]
		if new_world or last:
			worlds_seen += 1
			_check(not story.is_empty() and story["big"] != "", "a story is shown after %s" % GameState.levels[i]["id"])
		else:
			_check(story.is_empty(), "no story between %s and the next level" % GameState.levels[i]["id"])
	_check(worlds_seen == 4, "4 worlds end with a story (%d)" % worlds_seen)
	for w in GameState.levels.map(func(l): return l["world"]):
		if not GameState.WORLD_NAMES.has(w):
			_check(false, "world %d has a name" % w)
	GameState.current = GameState.levels.size() - 1
	_check(not GameState.has_next(), "the last level has no next level")
	GameState.current = 0
	_check(GameState.has_next(), "the first level has a next level")

	# put everything back
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	GameState.save_path = GameState.SAVE_PATH
	GameState.saving_enabled = false
	GameState.stars = old_stars
	GameState.seen_intro = old_intro
	GameState.current = old_current
	_check(not FileAccess.file_exists(TEST_SAVE), "the test save file is cleaned up")


# ---------------- 4. Menus and HUD ----------------

func _test_screens() -> void:
	print("-- menus and HUD")
	var old_stars: Dictionary = GameState.stars.duplicate()

	# Level map with nothing finished: only the first button can be pressed.
	GameState.stars = {}
	var map = load("res://scenes/world_map.tscn").instantiate()
	add_child(map)
	await _wait(3)
	var buttons := _level_buttons(map)
	var open := 0
	for b in buttons:
		if not b.disabled:
			open += 1
	_check(buttons.size() == GameState.levels.size(), "the map has one button per level (%d)" % buttons.size())
	_check(open == 1 and not buttons[0].disabled, "a new game has exactly one open level")
	map.queue_free()
	await _wait(2)

	# Level map with everything finished.
	for d in GameState.levels:
		GameState.stars[d["id"]] = 3
	map = load("res://scenes/world_map.tscn").instantiate()
	add_child(map)
	await _wait(3)
	open = 0
	for b in _level_buttons(map):
		if not b.disabled:
			open += 1
	_check(open == GameState.levels.size(), "a finished game has every level open")
	_check(GameState.total_stars() == GameState.levels.size() * 3, "a perfect game has %d stars" % (GameState.levels.size() * 3))
	map.queue_free()
	await _wait(2)
	GameState.stars = old_stars

	# Story screen: the intro, and a custom story (the ending).
	for story in [{}, {"big": "The End", "small": "Thanks!", "next": GameState.MENU_SCENE, "kind": 0}]:
		GameState.story = story
		var screen = load("res://scenes/intro.tscn").instantiate()
		add_child(screen)
		await _wait(10)
		_check(GameState.story.is_empty(), "the story screen uses its text once")
		screen.queue_free()
		await _wait(2)

	var menu = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await _wait(10)
	menu.queue_free()
	await _wait(2)
	_check(true, "the main menu opens")

	# HUD with unusual values
	var hud := Hud.new()
	add_child(hud)
	await _wait(2)
	hud.set_level("")
	hud.set_army([], 0)
	hud.set_army([], 99)
	for kind in [-1, W, T, G]:
		hud.set_pick(kind)
	for seconds in [0.0, 59.99, 60.0, 3599.0, 100000.0]:
		hud.set_time(seconds)
	hud.set_boss("Boss", 3, 3)
	hud.set_boss("Boss", 0, 3)
	hud.set_boss("", 0, 0)
	hud.show_message("")
	hud.show_message("a very long message ".repeat(30))
	hud.show_message("two")
	_check(hud._format_time(0.0) == hud._format_time(0.4), "the clock does not change inside one second")
	hud.show_win(0, 5, false, 1, 0.0)
	await _wait(5)
	hud.queue_free()
	await _wait(2)
	_check(true, "the HUD accepts unusual values")


func _level_buttons(root: Node) -> Array:
	var found: Array = []
	for node in root.find_children("*", "Button", true, false):
		if node.text != "Back to Menu":
			found.append(node)
	return found


# ---------------- 5. "What if" cases in a level ----------------

func _make_level() -> Dictionary:
	var b := Builder.new("U-1", "Unit", 1)
	b.start()
	b.socks([T, T, G, W])      # x = 320, 440, 560, 680
	b.flat(400)                # 740 .. 1140
	b.gap(160)                 # floor 1140 .. 1240, hole 1240 .. 1400
	b.flat(400)                # 1400 .. 1800
	b.puddle(160)              # floor 1800 .. 1900, water 1900 .. 2060
	b.flat(400)                # 2060 .. 2460
	b.box_puddle()             # floor 2460 .. 2710 (box at 2600), water 2710 .. 2970
	b.flat(400)                # 2970 .. 3370
	b.wall(280)                # floor 3370 .. 3490, wall at 3490, ledge up to 3650
	b.bunnies(1, 500)          # 3650 .. 4150
	b.drain()
	return b.finish(3)


func _test_empty_handed() -> void:
	print("-- with no socks")
	await _load(_make_level())
	_check(data["errors"].is_empty(), "the test level has no design errors %s" % str(data["errors"]))

	await _tap("command")
	_check(player.army.is_empty(), "Q with no socks does nothing")
	_teleport(Vector2(900, 598))
	await _wait(5)
	await _tap("recruit")
	_check(player.army.is_empty(), "E far from every sock does nothing")
	for action in ["pick_next", "pick_wool", "pick_toe", "pick_gym", "pick_gym"]:
		await _tap(action)
	_check(player.selected_kind == -1, "picking a kind and pressing it again goes back to AUTO")
	player.hit_by_enemy(player.global_position.x + 10.0)
	await _wait(2)
	_check(level.bonks == 1 and not level.flawless, "a hit with no socks still counts as a bonk")
	player.hit_by_enemy(player.global_position.x + 10.0)
	_check(level.bonks == 1, "no second hit while the hero is blinking")
	_check(player.velocity.x < 0.0, "a hit pushes the hero away from the enemy")
	await _wait(120)

	# Walk into the drain with no socks: no win.
	_teleport(level.drain.global_position + Vector2(0, -2))
	await _wait(30)
	_check(not level.won, "the drain does not open for an empty army")
	await _unload()


func _test_army_rules() -> void:
	print("-- army rules")
	await _load(_make_level())
	var toe1 = _sock(T, 0)
	var gym = _sock(G, 0)
	var wool = _sock(W, 0)

	player.add_to_army(toe1)
	player.add_to_army(toe1)
	_check(player.army.size() == 1, "the same sock cannot join twice")
	player.add_to_army(gym)

	# Picking a kind we do not have falls back to the smart choice.
	player._set_pick(W)
	var chosen = player._choose_sock_to_send()
	_check(chosen != null and chosen in player.army, "picking a kind you do not have still sends a sock you DO have")
	player._set_pick(W)

	# Send everything, then press Q again.
	_teleport(Vector2(900, 598))
	player.facing = 1.0
	await _wait(5)
	player._command()
	player._command()
	_check(player.army.is_empty(), "two Q presses send two socks")
	await _tap("command")
	await _wait(150)
	_check(toe1.state == toe1.State.PLACED and gym.state == gym.State.PLACED, "sent socks land and wait")

	# E twice in a row: socks come back once, no copies.
	player._try_recruit()
	await _wait(3)
	player._try_recruit()
	await _wait(10)
	player._try_recruit()
	await _wait(70)
	_check(player.army.size() == 2 and _no_copies(player.army), "whistling three times brings each sock back once")

	# Socks that never joined do not listen to the whistle.
	_check(wool.state == wool.State.IDLE and not wool.ever_recruited, "a sock you never met ignores the whistle")

	# Whistle while a sock is still flying.
	player._command()
	await _wait(8)
	player._try_recruit()
	await _wait(70)
	_check(player.army.size() == 2 and _no_copies(player.army), "a sock can be called back in mid-air")

	# Send a sock and immediately get hit: the army shrinks, nothing breaks.
	player._command()
	player._invulnerable = 0.0
	player.hit_by_enemy(player.global_position.x + 20.0)
	await _wait(150)
	_check(player.army.is_empty(), "sending one sock and losing the other leaves an empty army")
	# (E first picks up a lonely sock that is close, the next E whistles)
	for i in 3:
		player._try_recruit()
		await _wait(70)
	_check(player.army.size() == 2 and _no_copies(player.army), "both come back with E")

	# Respawn keeps the army together.
	player.respawn(Vector2(1500, 598))
	await _wait(30)
	var close := true
	for s in player.army:
		if s.global_position.distance_to(player.global_position) > 120.0:
			close = false
	_check(close, "after a respawn the army is next to the hero")
	await _unload()


func _test_toe_socks_together() -> void:
	print("-- two Toe Socks at once")
	await _load(_make_level())
	var toe1 = _sock(T, 0)
	var toe2 = _sock(T, 1)
	player.add_to_army(toe1)
	player.add_to_army(toe2)
	_teleport(Vector2(3374, 598))
	player.facing = 1.0
	await _wait(10)
	# Press Q twice as fast as possible.
	player._command()
	await _wait(3)
	player._command()
	await _wait(200)
	_check(toe1.climbed and toe2.climbed, "both Toe Socks stick to the wall")
	_check(absf(toe1.global_position.y - toe2.global_position.y) > 60.0,
		"two Toe Socks sent quickly take DIFFERENT steps (y=%d and y=%d)" % [int(toe1.global_position.y), int(toe2.global_position.y)])

	# and the hero can really climb them
	Input.action_press("move_right")
	for i in 4:
		Input.action_press("jump")
		await _wait(22)
		Input.action_release("jump")
		await _wait(45)
	Input.action_release("move_right")
	_check(player.global_position.y < 326.0 and player.global_position.x > 3490.0,
		"the hero climbs the wall on them (y=%d)" % int(player.global_position.y))
	await _unload()


func _test_socks_in_holes() -> void:
	print("-- socks falling into holes")
	await _load(_make_level())
	var toe = _sock(T, 0)
	var gym = _sock(G, 0)
	var wool = _sock(W, 0)
	for s in [toe, gym, wool]:
		player.add_to_army(s)

	# A sock knocked into the bottomless hole.
	_teleport(Vector2(1200, 598))
	await _wait(5)
	player.lose_sock(toe, 1.0, "test")
	await _wait(200)
	_check(toe.global_position.y > 900.0, "the knocked sock fell into the hole")
	_check(toe.state == toe.State.IDLE, "a sock in a hole stops falling and waits")
	_check(toe.global_position.y < 2000.0, "it does not fall forever (y=%d)" % int(toe.global_position.y))
	player._try_recruit()
	await _wait(70)
	_check(toe in player.army, "the whistle rescues a sock from a hole")

	# A sock THROWN into the hole.
	_teleport(Vector2(1130, 598))
	player.facing = 1.0
	player._set_pick(G)
	await _wait(5)
	player._command()
	await _wait(200)
	_check(gym.global_position.y > 900.0 and gym.global_position.y < 2000.0, "a thrown sock in a hole stops falling")
	player._try_recruit()
	await _wait(70)
	_check(gym in player.army, "the whistle rescues a thrown sock too")
	player._set_pick(G)

	# A Wool Sock that marches into the hole.
	_teleport(Vector2(1200, 598))
	player.facing = 1.0
	player._set_pick(W)
	await _wait(5)
	player._command()
	await _wait(300)
	_check(wool.state == wool.State.PLACED and wool.global_position.y < 2000.0, "a marching Wool Sock in a hole stops and waits")
	player._try_recruit()
	await _wait(70)
	_check(wool in player.army and player.army.size() == 3, "the whistle rescues it")
	player._set_pick(W)

	# A sock thrown into the water is not lost either.
	_teleport(Vector2(1860, 598))
	player.facing = 1.0
	player._set_pick(G)
	await _wait(5)
	player._command()
	await _wait(120)
	player._try_recruit()
	await _wait(70)
	_check(player.army.size() == 3, "a sock thrown into a puddle comes back")
	_check(level.respawns == 0, "throwing socks around never sends the hero back")
	await _unload()


func _test_hero_accidents() -> void:
	print("-- hero accidents")
	await _load(_make_level())
	var toe = _sock(T, 0)
	player.add_to_army(toe)

	# Walk into the puddle with the real keys.
	_teleport(Vector2(1830, 598))
	await _wait(5)
	await _walk_right_until_sent_back()
	_check(level.respawns == 1, "walking into a puddle sends the hero back once (%d)" % level.respawns)
	_check(not level.flawless, "getting soaked costs the flawless star")
	_check(player.global_position.x < 1900.0 and player.global_position.x > 1400.0 and player.is_on_floor(),
		"the hero comes back at the checkpoint before the puddle (x=%d)" % int(player.global_position.x))
	_check(toe in player.army, "the army is still there after a soak")

	# Walk into the bottomless hole.
	_teleport(Vector2(1180, 598))
	await _wait(5)
	await _walk_right_until_sent_back()
	_check(level.respawns == 2, "falling into a hole sends the hero back once more (%d)" % level.respawns)
	_check(player.global_position.x < 1240.0 and player.is_on_floor(),
		"the hero comes back before the hole (x=%d)" % int(player.global_position.x))

	# The same puddle and hole can be jumped with the real keys.
	for jump_from in [1180.0, 1830.0]:
		var before: int = level.respawns
		_teleport(Vector2(jump_from - 80.0, 598))
		await _wait(5)
		Input.action_press("move_right")
		while player.global_position.x < jump_from + 38.0:
			await _wait(1)
		Input.action_press("jump")
		await _wait(60)
		Input.action_release("jump")
		await _wait(30)
		Input.action_release("move_right")
		_check(level.respawns == before and player.global_position.x > jump_from + 220.0,
			"a running jump clears it (from x=%d to x=%d)" % [int(jump_from), int(player.global_position.x)])

	# The hero cannot leave the level on the left or the right.
	_teleport(Vector2(40, 598))
	Input.action_press("move_left")
	await _wait(90)
	Input.action_release("move_left")
	_check(player.global_position.x > 0.0, "the hero cannot walk out of the left side")
	_teleport(Vector2(data["width"] - 40.0, data["drain"].y - 2.0))
	Input.action_press("move_right")
	await _wait(90)
	Input.action_release("move_right")
	_check(player.global_position.x < data["width"], "the hero cannot walk out of the right side")
	await _unload()


func _test_box_rules() -> void:
	print("-- the soap box")
	await _load(_make_level())
	var gym = _sock(G, 0)
	var wool = _sock(W, 0)
	player.add_to_army(gym)
	player.add_to_army(wool)
	var box = level.boxes[0]
	var box_x: float = box.global_position.x

	# The hero alone is too weak.
	_teleport(Vector2(box_x - 130.0, 598))
	await _wait(5)
	Input.action_press("move_right")
	await _wait(90)
	Input.action_release("move_right")
	_check(absf(box.global_position.x - box_x) < 1.0, "the hero cannot push the box")
	_check(player.global_position.x < box_x - 70.0, "the box stops the hero")

	# A Gym Sock does not push it either.
	_teleport(Vector2(box_x - 130.0, 598))
	player.facing = 1.0
	player._set_pick(G)
	await _wait(5)
	player._command()
	await _wait(120)
	_check(absf(box.global_position.x - box_x) < 1.0, "a Gym Sock cannot push the box")
	player._set_pick(G)
	player._try_recruit()
	await _wait(70)

	# The hero can jump on top of it.
	_teleport(Vector2(box_x, 400))
	await _wait(40)
	_check(player.is_on_floor() and absf(player.global_position.y - (box.global_position.y - 70.0)) < 2.0, "the hero can stand on the box")

	# Wool pushes it in, and then the puddle can be crossed on foot + one jump.
	_teleport(Vector2(box_x - 130.0, 598))
	player.facing = 1.0
	await _wait(5)
	_check(player._choose_sock_to_send() == wool, "the smart pick chooses Wool for the box")
	player._command()
	await _wait(330)
	_check(not box.is_useful() and box.is_on_floor(), "the Wool Sock pushes the box into the puddle")
	player._try_recruit()
	await _wait(70)
	_check(player._choose_sock_to_send() != null, "after the box fell the smart pick still works")
	# The sunk box is a bridge: close enough to hop on, and from its far end
	# one running jump reaches the other side.
	var box_left: float = box.global_position.x - 70.0
	_check(box_left - 2710.0 < 170.0, "the sunk box is one jump from the edge (%d px)" % int(box_left - 2710.0))
	var respawns: int = level.respawns
	_teleport(Vector2(box.global_position.x - 40.0, box.global_position.y - 72.0))
	await _wait(20)
	_check(level.respawns == respawns and player.is_on_floor(), "the hero can stand on the sunk box without getting wet")
	Input.action_press("move_right")
	while player.global_position.x < box.global_position.x + 50.0:
		await _wait(1)
	Input.action_press("jump")
	await _wait(60)
	Input.action_release("jump")
	Input.action_release("move_right")
	await _wait(20)
	_check(level.respawns == respawns and player.global_position.x > 2970.0,
		"a jump from the sunk box reaches the other side (x=%d)" % int(player.global_position.x))
	await _unload()


func _test_enemy_corner_cases() -> void:
	print("-- enemy corner cases")
	await _load(_make_level())
	var gym = _sock(G, 0)
	player.add_to_army(gym)
	var bunny = level.enemies[0]

	# A bunny that is not stunned cannot be stomped.
	_teleport(bunny.global_position + Vector2(0, -150))
	await _wait(40)
	_check(not bunny.dead and level.bonks == 1, "jumping on a bunny that is NOT dizzy hurts")
	_check(player.army.is_empty(), "and it knocks a sock away")
	await _wait(120)
	player._try_recruit()
	await _wait(70)
	_check(player.army.size() == 1, "the sock comes back")

	# Stun, then defeat it twice (two things happening in the same frame).
	bunny.stun(5.0)
	bunny.defeat()
	bunny.defeat()
	bunny.stun(5.0)
	bunny.on_soaked()
	await _wait(30)
	_check(not is_instance_valid(bunny) or bunny.dead, "an enemy can only be defeated once")
	_check(get_tree().get_nodes_in_group("enemies").is_empty(), "a defeated enemy leaves the enemy list")

	# With no enemy left the smart pick and the stink cloud still work.
	player.facing = 1.0
	player._command()
	await _wait(120)
	_check(gym.state == gym.State.PLACED, "a stink cloud with no enemy near is harmless")
	player._try_recruit()
	await _wait(70)

	# An enemy spawned later (bosses do this) behaves like the others.
	var extra = level.spawn_enemy("bunny", Vector2(3900, 320), 3700.0, 4100.0)
	await _wait(30)
	_check(extra.is_on_floor() and extra in level.enemies, "an enemy can join during the level")
	extra.stun(4.0)
	_teleport(extra.global_position + Vector2(0, -150))
	await _wait(40)
	_check(not is_instance_valid(extra) or extra.dead, "a dizzy bunny can be stomped" + ("" if not is_instance_valid(extra) else " (bunny %s stun %.1f hero %s vel %s bonks %d)" % [str(extra.global_position.round()), extra.stun_time, str(player.global_position.round()), str(player.velocity.round()), level.bonks]))
	await _unload()

	# Stomping must work from every height, also for enemies that were
	# created during the level (they are checked in a different order).
	for height in [50.0, 90.0, 130.0, 200.0, 300.0, 500.0]:
		await _load(_make_level())
		var first = level.enemies[0]
		var late = level.spawn_enemy("bunny", Vector2(4050, 320), 4000.0, 4100.0)
		await _wait(20)
		var stomped := 0
		for target in [first, late]:
			target.stun(6.0)
			await _wait(2)
			_teleport(target.global_position + Vector2(0, -height))
			await _wait(70)
			if not is_instance_valid(target) or target.dead:
				stomped += 1
		_check(stomped == 2 and level.bonks == 0,
			"a dizzy bunny is stomped when the hero falls %d px (%d of 2)" % [int(height), stomped])
		await _unload()


func _test_drain_rules() -> void:
	print("-- the drain")
	await _load(_make_level())
	var socks := [_sock(T, 0), _sock(T, 1), _sock(G, 0), _sock(W, 0)]
	GameState.current = 0
	var id: String = GameState.levels[0]["id"]
	var old = GameState.stars.get(id, null)
	GameState.stars.erase(id)

	player.add_to_army(socks[0])
	player.add_to_army(socks[1])
	_teleport(level.drain.global_position + Vector2(0, -2))
	await _wait(30)
	_check(not level.won, "2 socks are not enough when the level needs 3")

	# The third sock arrives while the hero already stands in the drain.
	player.add_to_army(socks[2])
	await _wait(10)
	_check(level.won, "the level is won as soon as the third sock arrives")
	_check(not player.controls_enabled, "the hero stops listening to the keys after winning")
	_check(GameState.stars.get(id, 0) == 2, "3 of 4 socks and no accident = 2 stars (got %d)" % GameState.stars.get(id, 0))
	var time_at_win: float = level.time
	Input.action_press("move_left")
	Input.action_press("command")
	await _wait(60)
	Input.action_release("move_left")
	Input.action_release("command")
	_check(level.time == time_at_win, "the clock stops after winning")
	_check(player.army.size() == 3, "keys pressed after winning do nothing")
	await _unload()

	# All socks + flawless = 3 stars.  Too many accidents = 1 star.
	for case in [[4, true, 3], [4, false, 2], [3, false, 1]]:
		GameState.stars.erase(id)
		await _load(_make_level())
		socks = [_sock(T, 0), _sock(T, 1), _sock(G, 0), _sock(W, 0)]
		for i in case[0]:
			player.add_to_army(socks[i])
		if not case[1]:
			level.note_bonk()
		_teleport(level.drain.global_position + Vector2(0, -2))
		await _wait(30)
		_check(level.won and GameState.stars.get(id, 0) == case[2],
			"%d of 4 socks, flawless=%s gives %d star(s)" % [case[0], str(case[1]), case[2]])
		await _unload()

	if old == null:
		GameState.stars.erase(id)
	else:
		GameState.stars[id] = old


func _test_rubber_corner_cases() -> void:
	print("-- Rubber Sock corner cases")
	var b := Builder.new("U-4", "Unit 4", 4)
	b.start()
	b.socks([R, R, G])
	b.flat(600)
	b.chasm(300)
	b.flat(600)
	b.drain()
	await _load(b.finish(1))
	var r1 = _sock(R, 0)
	var r2 = _sock(R, 1)
	player.add_to_army(r1)
	player.add_to_army(r2)
	player._set_pick(R)

	# Press jump just before landing on the trampoline: still the BIG bounce.
	_teleport(Vector2(700, 598))
	player.facing = 1.0
	await _wait(3)
	player._command()
	await _wait(60)
	_teleport(r1.global_position + Vector2(0, -90))
	var top := 9999.0
	for i in 90:
		if i == 10:
			Input.action_press("jump")
		await _wait(1)
		top = minf(top, player.global_position.y)
	Input.action_release("jump")
	_check(600.0 - top > 380.0, "pressing jump while landing on a Rubber Sock keeps the big bounce (%d px)" % int(600.0 - top))
	await _wait(40)

	# Two Rubber Socks on top of each other: no endless bounce and no crash.
	_teleport(Vector2(r1.global_position.x - 40.0, 598))
	player.facing = 1.0
	await _wait(3)
	player._command()
	await _wait(80)
	_check(r2.state == r2.State.PLACED, "a second Rubber Sock lands next to or on the first one")
	var bounces := 0
	_teleport(r2.global_position + Vector2(0, -60))
	var going_up := false
	for i in 300:
		await _wait(1)
		if player.velocity.y < -900.0 and not going_up:
			bounces += 1
		going_up = player.velocity.y < -900.0
	_check(bounces >= 1, "the hero bounces on the pile (%d bounces in 5 s)" % bounces)
	player._try_recruit()
	await _wait(70)
	_check(player.army.size() == 2, "both Rubber Socks come back")

	# A Rubber Sock dropped INTO the chasm can be called back.
	var edge: float = 260.0 + 3 * 120.0 + 600.0 + 220.0
	_teleport(Vector2(edge - 30.0, 598))
	player.facing = 1.0
	await _wait(3)
	player._command()
	await _wait(200)
	_check(r1.global_position.y > 900.0 and r1.global_position.y < 2000.0, "a Rubber Sock dropped into a chasm stops falling")
	player._try_recruit()
	await _wait(70)
	_check(r1 in player.army, "and the whistle brings it back")
	_check(not r1.is_trampoline() and not r2.is_trampoline(), "a sock in the army is not a trampoline")
	player._set_pick(R)
	await _unload()


# ---------------- Helpers ----------------

func _load(d: Dictionary) -> void:
	data = d
	level = LevelScene.instantiate()
	level.data = d
	add_child(level)
	await _wait(5)
	player = level.player


func _unload() -> void:
	for action in ["move_left", "move_right", "jump", "recruit", "command"]:
		Input.action_release(action)
	level.queue_free()
	level = null
	player = null
	await _wait(3)


# Hold "right" until the level sends the hero back to a checkpoint.
func _walk_right_until_sent_back() -> void:
	var before: int = level.respawns
	Input.action_press("move_right")
	var guard := 0
	while level.respawns == before and guard < 300:
		await _wait(1)
		guard += 1
	Input.action_release("move_right")
	await _wait(20)


func _sock(kind: int, nth: int):
	var found := 0
	for s in get_tree().get_nodes_in_group("recruits"):
		if s.kind == kind and not s.is_queued_for_deletion():
			if found == nth:
				return s
			found += 1
	return null


func _no_copies(list: Array) -> bool:
	var seen := {}
	for item in list:
		if seen.has(item):
			return false
		seen[item] = true
	return true


func _teleport(pos: Vector2) -> void:
	player.respawn(pos)
	player._invulnerable = 0.0


func _tap(action: String) -> void:
	Input.action_press(action)
	await _wait(3)
	Input.action_release(action)
	await _wait(3)


func _check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures.append(what)


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame
