# level_builder.gd
# A helper to design levels quickly. A level is a chain of "pieces":
#   b.start()  b.sock(WOOL)  b.box_puddle()  b.bunnies(2)  b.wall(200)  b.drain()
# Each piece adds floor, enemies and so on at the "cursor" (x), then moves the
# cursor to the right. "gy" is the height of the ground right now (600 = low,
# smaller numbers = higher up, because y grows downwards in Godot).
#
# Every piece is built with sizes we know the hero can beat (jump height is
# about 128 px, jump length about 215 px), so new levels stay fair.
extends RefCounted

const SockTypes = preload("res://scripts/sock_types.gd")

const BOTTOM := 900.0
const SAFE_LEDGE := 160.0    # empty floor on top of every wall
const SAFE_LANDING := 120.0  # empty floor below every drop
const BUTTON_TINTS := [Color("fd79a8"), Color("00cec9"), Color("fdcb6e"), Color("a29bfe")]

var d := {}          # the finished level description (a Dictionary)
var x := 0.0         # cursor
var gy := 600.0      # ground height at the cursor
var _last_cp := -9999.0
var _tint := 0
# How many socks of each kind the player can have by now (to catch design mistakes).
var _have := {SockTypes.Kind.WOOL: 0, SockTypes.Kind.TOE: 0, SockTypes.Kind.GYM: 0}


func _init(id: String, title: String, world: int) -> void:
	d = {
		"id": id, "name": title, "world": world, "need": 3, "width": 0.0, "min_gy": 600.0,
		"start": Vector2(120, 598), "hint": "",
		"blocks": [], "water": [], "socks": [], "boxes": [], "enemies": [],
		"signs": [], "lines": [], "checkpoints": [],
		"drain": Vector2.ZERO, "boss": {}, "errors": [],
		"pieces": [], # the list of pieces in order (the automatic test bot reads it)
	}


# ---------------- Small helpers ----------------

func _block(rect: Rect2, style: String, one_way := false, tint := Color.WHITE) -> void:
	d["blocks"].append({"rect": rect, "style": style, "one_way": one_way, "tint": tint})


func _floor(from_x: float, width: float) -> void:
	_block(Rect2(from_x, gy, width, BOTTOM - gy), "floor")


# A safe place to come back to. Every piece starts on solid floor, so the
# start of a piece is always a good checkpoint.
func _cp() -> void:
	if x - _last_cp > 300.0:
		d["checkpoints"].append(Vector2(x + 40.0, gy - 2.0))
		_last_cp = x


func _total_socks() -> int:
	return _have[SockTypes.Kind.WOOL] + _have[SockTypes.Kind.TOE] + _have[SockTypes.Kind.GYM]


func _require(ok: bool, what: String) -> void:
	if not ok:
		d["errors"].append("%s at x=%d: %s" % [d["id"], int(x), what])


# Remember which piece starts here. The test bot uses this list to know what
# is coming (a wall, a puddle...) just like a player sees it on screen.
func _piece(kind: String, extra := {}) -> void:
	var p := {"kind": kind, "x0": x, "x1": x, "gy": gy}
	p.merge(extra)
	d["pieces"].append(p)


func put_sock(kind: int, pos: Vector2) -> void:
	d["socks"].append({"kind": kind, "pos": pos})
	_have[kind] += 1


func put_enemy(type: String, pos: Vector2, a = 0.0, b = 0.0) -> void:
	d["enemies"].append({"type": type, "pos": pos, "a": a, "b": b})


func put_button(left_x: float, height: float) -> void:
	_block(Rect2(left_x, gy - height, 120, 24), "button", true, BUTTON_TINTS[_tint % BUTTON_TINTS.size()])
	_tint += 1


# A sign with help text, floating above the cursor.
func tip(text: String, dx := 140.0, height := 190.0) -> void:
	d["signs"].append({"pos": Vector2(x + dx, gy - height), "text": text})


# ---------------- Pieces ----------------

func start(width := 260.0) -> void:
	_piece("start")
	_floor(0.0, width)
	d["start"] = Vector2(120, gy - 2.0)
	d["checkpoints"].append(Vector2(120, gy - 2.0))
	_last_cp = 0.0
	x = width


func flat(width: float) -> void:
	_piece("flat")
	_cp()
	_floor(x, width)
	x += width


func sock(kind: int) -> void:
	_piece("sock")
	_floor(x, 120.0)
	put_sock(kind, Vector2(x + 60.0, gy))
	x += 120.0


func socks(kinds: Array) -> void:
	for kind in kinds:
		sock(kind)


# A soap box and a puddle too wide to jump. Needs a Wool Sock to push the box in.
func box_puddle() -> void:
	_require(_have[SockTypes.Kind.WOOL] >= 1, "box_puddle needs a Wool Sock")
	_piece("box_puddle", {"box": d["boxes"].size()})
	_cp()
	_floor(x, 250.0)
	d["boxes"].append(Vector2(x + 140.0, gy))
	x += 250.0
	_pit(260.0)


# A puddle you can jump over (150-170 px).
func puddle(width := 150.0) -> void:
	_piece("puddle")
	_cp()
	_floor(x, 100.0)
	x += 100.0
	_pit(width)


func _pit(width: float) -> void:
	_block(Rect2(x, gy + 70.0, width, BOTTOM - gy - 70.0), "pit")
	d["water"].append(Rect2(x, gy + 15.0, width, 55.0))
	x += width


# A hole with no bottom. Fall in = back to the checkpoint.
func gap(width := 150.0) -> void:
	_piece("gap")
	_cp()
	_floor(x, 100.0)
	x += 100.0 + width


func bunnies(count := 1, width := 450.0) -> void:
	_piece("bunnies")
	_cp()
	_floor(x, width)
	for i in count:
		put_enemy("bunny", Vector2(x + width * (i + 1) / (count + 1), gy), x + 50.0, x + width - 50.0)
	x += width


# The ground goes UP. 100 = just jump. 160 = needs 1 sock as a step.
# 200 = 1 Toe Sock.  280 = 2 Toe Socks.  360 = 3 Toe Socks.
func wall(height: float) -> void:
	var toes: int = _have[SockTypes.Kind.TOE]
	if height > 300.0:
		_require(toes >= 3, "wall(360) needs 3 Toe Socks")
	elif height > 220.0:
		_require(toes >= 2, "wall(280) needs 2 Toe Socks")
	elif height > 170.0:
		_require(toes >= 1 or _total_socks() >= 3, "wall(200) needs a Toe Sock or 3 socks")
	elif height > 120.0:
		_require(_total_socks() >= 1, "wall(160) needs 1 sock")
	_piece("wall", {"height": height})
	_cp()
	_floor(x, 120.0)
	x += 120.0
	gy -= height
	d["min_gy"] = minf(d["min_gy"], gy)
	# A safe ledge on top: no enemy may wait right where the hero lands.
	_floor(x, SAFE_LEDGE)
	x += SAFE_LEDGE


# The ground goes DOWN (just walk off the edge).
func drop(height: float) -> void:
	_piece("drop")
	_cp()
	_floor(x, 100.0)
	x += 100.0
	gy = minf(gy + height, 600.0)
	# A safe place to land at the bottom.
	_floor(x, SAFE_LANDING)
	x += SAFE_LANDING


# Giant buttons to jump on, like stairs. "heights" are above the ground,
# each one at most 95 higher than the one before.
func buttons(heights: Array, sock_kind := -1, with_bunny := false) -> void:
	_piece("buttons", {"heights": heights, "has_sock": sock_kind >= 0})
	_cp()
	var width := 120.0 + 180.0 * heights.size()
	_floor(x, width)
	for i in heights.size():
		put_button(x + 100.0 + 180.0 * i, heights[i])
	if sock_kind >= 0:
		var last: float = heights[heights.size() - 1]
		put_sock(sock_kind, Vector2(x + 160.0 + 180.0 * (heights.size() - 1), gy - last))
	if with_bunny:
		put_enemy("bunny", Vector2(x + width / 2.0, gy), x + 50.0, x + width - 50.0)
	x += width


# A laundry basket (70 px high), maybe with a sock on top.
func basket(sock_kind := -1) -> void:
	_piece("basket")
	_cp()
	_floor(x, 300.0)
	_block(Rect2(x + 60.0, gy - 70.0, 180, 70), "basket")
	if sock_kind >= 0:
		put_sock(sock_kind, Vector2(x + 150.0, gy - 70.0))
	x += 300.0


# Static Sparks. mode "h" = slides left-right near the floor (jump over it, or
# send a Wool Sock). mode "v" = bobs up and down (run under it at the right time).
func sparks(count := 1, width := 400.0, mode := "h") -> void:
	_piece("sparks")
	_cp()
	_floor(x, width)
	for i in count:
		var sx := x + width * (i + 1) / (count + 1)
		if mode == "v":
			put_enemy("spark", Vector2(sx, gy - 30.0), Vector2(sx, gy - 30.0), Vector2(sx, gy - 210.0))
		else:
			put_enemy("spark", Vector2(sx - 90.0, gy - 32.0), Vector2(sx - 90.0, gy - 32.0), Vector2(sx + 90.0, gy - 32.0))
	x += width


# Clothespin Snappers hanging from a clothesline.
func snappers(count := 1, width := 400.0) -> void:
	_piece("snappers")
	_cp()
	_floor(x, width)
	d["lines"].append([Vector2(x + 10.0, gy - 285.0), Vector2(x + width - 10.0, gy - 285.0)])
	for i in count:
		put_enemy("snapper", Vector2(x + width * (i + 1) / (count + 1), gy - 250.0), gy)
	x += width


# A Hot Iron waiting on the far side of a small puddle. Stand on the near side:
# it charges at you and falls into the water.
func iron_trap() -> void:
	_piece("iron_trap")
	_cp()
	_floor(x, 160.0)
	x += 160.0
	_pit(170.0)
	_floor(x, 520.0)
	put_enemy("iron", Vector2(x + 300.0, gy), x + 80.0, x + 460.0)
	x += 520.0


# Moths hovering above the path.
func moths(count := 1, width := 450.0) -> void:
	_piece("moths")
	_cp()
	_floor(x, width)
	for i in count:
		put_enemy("moth", Vector2(x + width * (i + 1) / (count + 1), gy - 150.0))
	x += width


# The exit. Always the last piece.
func drain() -> void:
	_piece("drain")
	_cp()
	_floor(x, 520.0)
	d["drain"] = Vector2(x + 330.0, gy)
	x += 520.0


# Call this last. "need" = how many socks you must bring to the drain.
func finish(need: int) -> Dictionary:
	d["need"] = need
	d["width"] = x
	# Each piece ends where the next one starts.
	var pieces: Array = d["pieces"]
	for i in pieces.size():
		pieces[i]["x1"] = pieces[i + 1]["x0"] if i + 1 < pieces.size() else x
	_require(need <= d["socks"].size(), "need is bigger than the number of socks")
	return d
