# campaign_bot.gd
# A robot player. It plays every normal level of the campaign from start to
# drain using ONLY the real keys (move, jump, E, Q, 1/2/3). No teleporting.
# If the bot can finish a level, a human can too: the walls can be climbed,
# the puddles can be crossed and every sock can be collected.
#
# Run it from a terminal (in the project folder):
#   godot --headless --fixed-fps 60 res://tests/campaign_bot.tscn
# Only some levels:
#   godot --headless --fixed-fps 60 res://tests/campaign_bot.tscn -- 1-3 2-5
# Stuck on a level? Set the environment variable BOT_TRACE to a piece name
# (for example "wall") and the bot prints where it is while it plays that piece.
extends Node

const SockTypes = preload("res://scripts/sock_types.gd")
const LevelScene = preload("res://scenes/level.tscn")
const Bunny = preload("res://scripts/lint_bunny.gd")
const Snapper = preload("res://scripts/snapper.gd")
const Spark = preload("res://scripts/spark.gd")
const Iron = preload("res://scripts/iron.gd")
const Moth = preload("res://scripts/moth.gd")

const W := SockTypes.Kind.WOOL
const T := SockTypes.Kind.TOE
const G := SockTypes.Kind.GYM
const R := SockTypes.Kind.RUBBER
const PICK_ACTION := {W: "pick_wool", T: "pick_toe", G: "pick_gym", R: "pick_rubber"}

const MAX_SECONDS := 420      # give up on a level after 7 minutes of game time
const MAX_RESPAWNS := 15
const SOLID := 1 | 16         # terrain + props (placed socks, the box)

var failures: Array[String] = []
var level
var player
var data: Dictionary
var _frames := 0
var _aborted := false
var _move := 0.0
var _jump_down := false
var _jump_since := 0
var _attack_cooldown := 0
var _recruit_cooldown := 0
var _tries := {}              # enemy -> how many socks we already sent at it
var _where := ""              # what the bot is doing (printed when it gets stuck)


func _ready() -> void:
	GameState.saving_enabled = false # never touch the real save file
	AudioServer.set_bus_mute(0, true)
	_run.call_deferred()


func _run() -> void:
	var only := OS.get_cmdline_user_args()
	var total_time := 0.0
	var played := 0
	for d in GameState.levels:
		if not d["boss"].is_empty():
			continue # bosses are tested in smoke_test.gd
		if not only.is_empty() and not (d["id"] in only):
			continue
		total_time += await _play(d)
		played += 1

	print("")
	print("bot played %d levels in %d s of game time" % [played, int(total_time)])
	if failures.is_empty():
		print("CAMPAIGN BOT: ALL PASSED")
	else:
		print("CAMPAIGN BOT: %d FAILED" % failures.size())
		for f in failures:
			print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


# Play one level. Returns the game time it took.
func _play(d: Dictionary) -> float:
	data = d
	level = LevelScene.instantiate()
	level.data = d
	add_child(level)
	_frames = 0
	_aborted = false
	_tries.clear()
	await _frame(5)
	player = level.player

	while _alive():
		var piece := _piece_at(player.global_position.x)
		_where = "%s at x=%d" % [piece["kind"], int(piece["x0"])]
		await _handle(piece)
		await _frame()
	_release_all()

	var total: int = d["socks"].size()
	var seconds := _frames / 60.0
	print("  %s %-22s %s  time %3d s  socks %d/%d  bonks %d  respawns %d" % [
		d["id"], d["name"], "WON " if level.won else "LOST", int(seconds),
		player.army.size(), total, level.bonks, level.respawns])
	if not level.won and not _aborted:
		_fail("ran out of time (%s, hero at %s, army %d)" % [_where, str(player.global_position.round()), player.army.size()])
	if level.won:
		if player.army.size() < total:
			_fail("the bot could not bring every sock (%d of %d)" % [player.army.size(), total])
		await _frame(60) # let the win screen appear
	level.queue_free()
	level = null
	await _frame(3)
	return seconds


func _handle(piece: Dictionary) -> void:
	match piece["kind"]:
		"wall":
			await _do_wall(piece)
		"box_puddle":
			await _do_box(piece)
		"iron_trap":
			await _do_iron(piece)
		"buttons":
			await _do_buttons(piece)
		"chasm":
			await _do_chasm(piece)
		"drain":
			await _do_drain()
		_:
			await _travel(piece["x1"] + 6.0)


# ---------------- The pieces that need a plan ----------------

# A wall: stick Toe Socks on it like stairs, then jump up.
func _do_wall(piece: Dictionary) -> void:
	var height: float = piece["height"]
	if height <= 120.0:
		await _travel(piece["x1"] + 6.0) # low enough to just jump
		return
	var wall_x: float = piece["x0"] + 120.0
	var top_y: float = piece["gy"] - height
	if player.global_position.x > wall_x and player.global_position.y < top_y + 6.0:
		await _travel(piece["x1"] + 6.0) # already on top
		return
	var need := 1
	if height > 300.0:
		need = 3
	elif height > 220.0:
		need = 2

	for attempt in 4:
		if not _alive():
			return
		await _regroup()
		# Too tall for our Toe Socks? Bounce up on the Rubber Sock instead.
		if _has(R) and (height > 370.0 or _count(T) < need):
			if await _rubber_jump(wall_x - 60.0, func(): return _on_top(wall_x, top_y)):
				await _regroup()
				return
			continue
		if not await _travel(piece["x0"] + 4.0, true):
			return
		for i in need:
			if _has(T):
				await _send_and_wait(T)
			elif height <= 170.0 and not player.army.is_empty():
				# No Toe Sock: any sock next to the wall works as a step.
				if not await _travel(wall_x - 60.0, true):
					return
				await _send_and_wait(player.army[0].kind)
			else:
				_fail("wall(%d) at x=%d: no Toe Sock in the army" % [int(height), int(piece["x0"])])
				return
		# Climb: hold right and keep jumping.
		var start := _frames
		while _alive() and _frames - start < 420 and not _on_top(wall_x, top_y):
			_set_move(1.0)
			_jump_when_on_floor()
			await _frame()
		if _on_top(wall_x, top_y):
			await _regroup()
			return
	_fail("wall(%d) at x=%d: the bot could not climb it" % [int(height), int(piece["x0"])])


# A hole too wide to jump: bounce over it on the Rubber Sock.
func _do_chasm(piece: Dictionary) -> void:
	var edge: float = piece["x0"] + 220.0
	if player.global_position.x > edge + 10.0:
		await _travel(piece["x1"] + 6.0) # already on the other side
		return
	for attempt in 4:
		if not _alive():
			return
		await _regroup()
		if not _has(R):
			_fail("chasm at x=%d: no Rubber Sock in the army" % int(piece["x0"]))
			return
		var across := func(): return player.is_on_floor() and player.global_position.x > edge + 20.0
		if await _rubber_jump(edge - 110.0, across):
			await _regroup()
			await _travel(piece["x1"] + 6.0)
			return
	if _alive():
		_fail("chasm at x=%d: the bot could not bounce over it" % int(piece["x0"]))


# Stand at x, drop the Rubber Sock in front, step back, jump on it and hold
# "right" while flying. Returns true when done() says we made it.
func _rubber_jump(drop_x: float, done: Callable) -> bool:
	if not await _travel(drop_x, true):
		return false
	await _send_and_wait(R)
	var sock = null
	for s in get_tree().get_nodes_in_group("recruits"):
		if s.kind == R and s.state == s.State.PLACED and absf(s.global_position.x - drop_x - 50.0) < 90.0 \
				and absf(s.global_position.y - player.global_position.y) < 10.0:
			sock = s
	if sock == null:
		return false # it fell into the hole: the next try whistles it back
	if not await _travel(sock.global_position.x - 75.0, true, false):
		return false
	var respawns: int = level.respawns
	await _hop_to(sock.global_position.x)
	var start := _frames
	while _alive() and _frames - start < 240 and level.respawns == respawns and not done.call():
		_set_move(1.0)
		await _frame()
	_set_move(0.0)
	return level.respawns == respawns and done.call()


func _count(kind: int) -> int:
	var n := 0
	for sock in player.army:
		if sock.kind == kind:
			n += 1
	return n


func _on_top(wall_x: float, top_y: float) -> bool:
	var pos: Vector2 = player.global_position
	return player.is_on_floor() and pos.y < top_y + 6.0 and pos.x > wall_x


# A soap box and a wide puddle: the Wool Sock pushes the box in, we hop over.
func _do_box(piece: Dictionary) -> void:
	var box = level.boxes[piece["box"]]
	var edge: float = piece["x0"] + 250.0
	var tries := 0
	while _alive() and box.is_useful() and tries < 4:
		tries += 1
		await _regroup()
		if not _has(W):
			_fail("box_puddle at x=%d: no Wool Sock in the army" % int(piece["x0"]))
			return
		if not await _travel(box.global_position.x - 110.0, true):
			return
		await _send_and_wait(W, box)
		await _frame(40)
	if box.is_useful():
		_fail("box_puddle at x=%d: the box did not fall into the puddle" % int(piece["x0"]))
		return
	await _regroup()
	if player.global_position.x < edge - 10.0:
		if not await _travel(edge - 16.0, true):
			return
		await _hop_to(box.global_position.x)
	await _travel(piece["x1"] + 6.0)


# A Hot Iron behind a puddle: wait on the near side until it falls in.
func _do_iron(piece: Dictionary) -> void:
	var iron = null
	for e in level.enemies:
		if is_instance_valid(e) and not e.dead and e.get_script() == Iron \
				and e.global_position.x > piece["x0"] and e.global_position.x < piece["x1"]:
			iron = e
	if iron != null and player.global_position.x < piece["x0"] + 150.0:
		if not await _travel(piece["x0"] + 125.0, true):
			return
		var start := _frames
		while _alive() and is_instance_valid(iron) and not iron.dead and _frames - start < 60 * 30:
			await _frame()
		if is_instance_valid(iron) and not iron.dead:
			_fail("iron_trap at x=%d: the iron never fell into the water" % int(piece["x0"]))
			return
	await _travel(piece["x1"] + 6.0)


# Giant buttons like stairs, with a sock on the last one.
func _do_buttons(piece: Dictionary) -> void:
	var heights: Array = piece["heights"]
	var last := heights.size() - 1
	var sock_pos := Vector2(piece["x0"] + 160.0 + 180.0 * last, piece["gy"] - heights[last])
	var sock = null
	for s in get_tree().get_nodes_in_group("recruits"):
		if not s.ever_recruited and s.global_position.distance_to(sock_pos) < 40.0:
			sock = s
	if sock == null:
		await _travel(piece["x1"] + 6.0) # nothing to fetch up there
		return

	for attempt in 4:
		if not await _travel(piece["x0"] + 60.0, true):
			return
		var ok := true
		for i in heights.size():
			var left: float = piece["x0"] + 100.0 + 180.0 * i
			if i > 0 and not await _travel(left - 72.0, true, false):
				return
			await _hop_to(left + 60.0)
			if absf(player.global_position.y - (piece["gy"] - heights[i])) > 8.0:
				ok = false # missed the button: start again from the floor
				break
		if ok:
			break
	await _tap("recruit")
	if not sock.ever_recruited:
		_fail("buttons at x=%d: the bot could not reach the sock on top" % int(piece["x0"]))
		return
	await _travel(piece["x1"] + 6.0)


func _do_drain() -> void:
	await _regroup()
	await _travel(data["drain"].x, true)
	var start := _frames
	while _alive() and _frames - start < 240:
		await _frame()
	if _alive():
		_fail("standing in the drain with %d socks (need %d) but no win" % [player.army.size(), data["need"]])


# ---------------- Moving ----------------

# Walk to x. precise = stop exactly there. Returns false if we were sent back
# to a checkpoint on the way (the main loop then starts again from there).
func _travel(tx: float, precise := false, jumping := true) -> bool:
	var respawns: int = level.respawns
	var best: float = absf(player.global_position.x - tx)
	var best_frame := _frames
	while _alive():
		var px: float = player.global_position.x
		if level.respawns != respawns:
			_release_all()
			return false
		# Not getting closer for 6 seconds? Something pushed us off our plan
		# (for example a bunny knocked us off a wall). Let the main loop think again.
		if absf(px - tx) < best - 2.0:
			best = absf(px - tx)
			best_frame = _frames
		elif _frames - best_frame > 360:
			_set_move(0.0)
			return false
		if precise:
			if absf(px - tx) <= 6.0 and player.is_on_floor():
				break
		elif px >= tx:
			return true
		await _maybe_recruit()
		if await _maybe_attack():
			continue
		_drive(tx if precise else tx + 30.0, jumping)
		await _frame()
	_set_move(0.0)
	return _alive()


# One frame of walking towards x: choose the keys to hold.
func _drive(tx: float, jumping := true) -> void:
	var px: float = player.global_position.x
	var want := 0.0
	if px < tx - 4.0:
		want = 1.0
	elif px > tx + 4.0:
		want = -1.0
	if want != 0.0 and _must_wait(want):
		want = 0.0
	_set_move(want)
	_jump_if(jumping and want != 0.0 and _should_jump(want))


func _jump_when_on_floor() -> void:
	_jump_if(true)


# Press jump (if wanted) when we stand on the floor, and HOLD it until we land
# again: holding gives the full jump height. The game notices a key one frame
# after the test presses it, so we never let go in the first frames.
func _jump_if(wanted: bool) -> void:
	if not player.is_on_floor():
		return
	if _jump_down:
		if _frames - _jump_since >= 5:
			Input.action_release("jump")
			_jump_down = false
	elif wanted:
		Input.action_press("jump")
		_jump_down = true
		_jump_since = _frames


# Jump now and steer in the air to land at x.
func _hop_to(tx: float) -> void:
	if _jump_down:
		Input.action_release("jump")
		_jump_down = false
		await _frame()
	Input.action_press("jump")
	_jump_down = true
	_jump_since = _frames
	var start := _frames
	var left_floor := false
	while _alive() and _frames - start < 150:
		var px: float = player.global_position.x
		_set_move(0.0 if absf(px - tx) < 5.0 else signf(tx - px))
		await _frame()
		if not player.is_on_floor():
			left_floor = true
		elif left_floor or _frames - start > 10:
			break
	_set_move(0.0)
	Input.action_release("jump")
	_jump_down = false
	await _frame(2)


func _set_move(dir: float) -> void:
	if dir == _move:
		return
	_move = dir
	if dir > 0.0:
		Input.action_release("move_left")
		Input.action_press("move_right")
	elif dir < 0.0:
		Input.action_release("move_right")
		Input.action_press("move_left")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")


func _release_all() -> void:
	_set_move(0.0)
	_jump_down = false
	for action in ["jump", "recruit", "command", "move_left", "move_right"]:
		Input.action_release(action)


# Should we press jump? Yes for a step, a hole, or an enemy in the way.
func _should_jump(dir: float) -> bool:
	var pos: Vector2 = player.global_position
	# 1. something solid right in front of our feet
	if not _ray(pos + Vector2(0, -12), pos + Vector2(dir * 30.0, -12)).is_empty():
		return true
	# 2. a hole or a puddle ahead (a step down is fine: just walk off)
	var probe := pos + Vector2(dir * 18.0, -4)
	var hit := _ray(probe, probe + Vector2(0, 520))
	if hit.is_empty():
		return true
	for water in data["water"]:
		if probe.x > water.position.x and probe.x < water.end.x and absf(water.position.y - pos.y) < 60.0:
			return true
	# 3. an enemy walking on the floor ahead: jump over it
	for e in level.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var kind = e.get_script()
		if kind == Bunny and e.stun_time > 0.0:
			continue # dizzy bunnies are harmless
		if kind != Bunny and kind != Iron and not (kind == Spark and _is_flat(e)):
			continue
		var dx: float = (e.global_position.x - pos.x) * dir
		if dx > 30.0 and dx < 105.0 and absf(e.global_position.y - pos.y) < 60.0:
			return true
	return false


# Should we stop and wait? Yes for a Snapper about to drop and for a Spark
# that is bobbing down in front of us.
func _must_wait(dir: float) -> bool:
	var pos: Vector2 = player.global_position
	for e in level.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var dx: float = (e.global_position.x - pos.x) * dir
		var kind = e.get_script()
		if kind == Snapper:
			if dx < 44.0 or dx > 135.0 or absf(pos.y - e.ground_y) > 100.0:
				continue
			if e.state == e.S.GROUND and e._hurt_time <= 0.0 and e._timer > 0.9:
				continue # stuck in the floor: run past it
			if e.state == e.S.HANG and dx > 114.0:
				continue # walk a bit closer to make it drop
			return true
		elif kind == Spark and not _is_flat(e):
			if dx < 36.0 or dx > 75.0 or absf(pos.y - e.point_a.y) > 120.0:
				continue
			var rising := sin(e._phase) > 0.0
			var high: float = pos.y - e.global_position.y
			if high > 190.0 or (high > 150.0 and rising):
				continue # high enough: run under it
			return true
	return false


func _is_flat(spark) -> bool:
	return absf(spark.point_a.y - spark.point_b.y) < 1.0


func _ray(from: Vector2, to: Vector2) -> Dictionary:
	var space = player.get_world_2d().direct_space_state
	return space.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, SOLID))


# ---------------- Socks ----------------

func _has(kind: int) -> bool:
	return player._first_of_kind(kind) != null


# Press E when a lonely sock is close.
func _maybe_recruit() -> void:
	if _recruit_cooldown > 0:
		return
	for s in get_tree().get_nodes_in_group("recruits"):
		if s.can_be_recruited() and player.global_position.distance_to(s.global_position) < 75.0:
			_recruit_cooldown = 8
			await _tap("recruit")
			return


# Use the right sock on an enemy ahead. Returns true if we did something.
func _maybe_attack() -> bool:
	if _attack_cooldown > 0 or not player.is_on_floor():
		return false
	var pos: Vector2 = player.global_position
	for e in level.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var kind = e.get_script()
		var dx: float = e.global_position.x - pos.x
		var dy: float = e.global_position.y - pos.y
		if _tries.get(e, 0) >= 3:
			continue # tried enough: just run past it
		if kind == Bunny and _has(G) and e.stun_time <= 0.0 and dx > 110.0 and dx < 250.0 and absf(dy) < 50.0:
			_tries[e] = _tries.get(e, 0) + 1
			await _send_and_wait(G)
			await _regroup()
			return true
		if kind == Moth and _has(G):
			var hx: float = e.home.x - pos.x
			if hx > 185.0 and hx < 240.0 and e.home.y < pos.y and e.home.y > pos.y - 260.0:
				_tries[e] = _tries.get(e, 0) + 1
				await _send_and_wait(G)
				await _regroup()
				return true
		if kind == Spark and _is_flat(e) and _has(W):
			var ax: float = e.point_a.x - pos.x
			if ax > 55.0 and ax < 250.0 and absf(e.point_a.y - pos.y) < 80.0:
				_tries[e] = _tries.get(e, 0) + 1
				await _send_and_wait(W, e)
				await _regroup()
				return true
	return false


# Stop, pick a sock kind, press Q, and wait until the sock has done its job.
# "until" can be an enemy (wait until it is gone) or the box (until it fell).
func _send_and_wait(kind: int, until = null) -> void:
	_set_move(0.0)
	var start := _frames
	while _alive() and _frames - start < 40 and not (player.is_on_floor() and absf(player.velocity.x) < 20.0):
		await _frame()
	if player.facing < 0.0:
		_set_move(1.0)
		await _frame(2)
		_set_move(0.0)
		await _frame(8)
	if player.selected_kind != kind:
		await _tap(PICK_ACTION[kind])
	var sock = player._first_of_kind(kind)
	if sock == null:
		return
	await _tap("command")
	# (the game sees the key one frame later: wait until the sock really left)
	start = _frames
	while _alive() and _frames - start < 20 and sock in player.army:
		await _frame()
	start = _frames
	while _alive() and _frames - start < 300 and sock.is_attacking():
		if until != null:
			if not is_instance_valid(until):
				break
			if until.has_method("is_useful") and not until.is_useful():
				break
		await _frame()
	_attack_cooldown = 30


# Whistle (E) until every sock we ever recruited is back in the army.
func _regroup() -> void:
	_set_move(0.0)
	var start := _frames
	while _alive() and _frames - start < 420:
		var want := 0
		var flying := false
		for s in get_tree().get_nodes_in_group("recruits"):
			if s.ever_recruited:
				want += 1
			if s.state == s.State.KNOCKED or s.state == s.State.RETURN:
				flying = true
		if player.army.size() >= want:
			return
		if flying:
			await _frame()
		else:
			await _tap("recruit")
			await _frame(6)


# ---------------- Helpers ----------------

func _piece_at(x: float) -> Dictionary:
	var pieces: Array = data["pieces"]
	var found: Dictionary = pieces[0]
	for p in pieces:
		if p["x0"] <= x + 1.0:
			found = p
	return found


func _alive() -> bool:
	if _aborted or not is_instance_valid(level) or level.won:
		return false
	if level.respawns > MAX_RESPAWNS:
		_fail("sent back to a checkpoint %d times (%s)" % [level.respawns, _where])
		return false
	return _frames < MAX_SECONDS * 60


func _fail(what: String) -> void:
	var text := "%s: %s" % [data["id"], what]
	print("  FAIL " + text)
	failures.append(text)
	_aborted = true


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frame(2)
	Input.action_release(action)
	await _frame()


func _frame(count := 1) -> void:
	for i in count:
		await get_tree().physics_frame
		_frames += 1
		_attack_cooldown = maxi(0, _attack_cooldown - 1)
		_recruit_cooldown = maxi(0, _recruit_cooldown - 1)
		if OS.has_environment("BOT_TRACE") and is_instance_valid(player) and _frames % 4 == 0 and _where.contains(OS.get_environment("BOT_TRACE")):
			var socks := ""
			for s in get_tree().get_nodes_in_group("recruits"):
				if s.ever_recruited:
					socks += " %d:%d@%d,%d%s" % [s.kind, s.state, int(s.global_position.x), int(s.global_position.y), "c" if s.climbed else ""]
			print("    t %d pos %s vel %s floor %s move %d jump %s bonks %d |%s" % [_frames, str(player.global_position.round()), str(player.velocity.round()), str(player.is_on_floor()), int(_move), str(_jump_down), level.bonks, socks])
