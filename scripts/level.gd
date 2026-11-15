# level.gd
# Builds a level from its description (a Dictionary made in levels.gd) and
# checks the rules: winning, falling in water, stars, bosses.
# The same script plays every level of the game.
extends Node2D

const PlayerScene = preload("res://scenes/player.tscn")
const RecruitScene = preload("res://scenes/recruit_sock.tscn")

const Art = preload("res://scripts/art.gd")
const Hud = preload("res://scripts/hud.gd")
const Backdrop = preload("res://scripts/backdrop.gd")
const BlockArt = preload("res://scripts/block_art.gd")
const Water = preload("res://scripts/water.gd")
const PushableBox = preload("res://scripts/pushable_box.gd")
const SoapBubble = preload("res://scripts/soap_bubble.gd")
const ExitDrain = preload("res://scripts/exit_drain.gd")

# Every kind of enemy and boss, by name.
const ENEMY_SCRIPTS := {
	"bunny": preload("res://scripts/lint_bunny.gd"),
	"spark": preload("res://scripts/spark.gd"),
	"snapper": preload("res://scripts/snapper.gd"),
	"iron": preload("res://scripts/iron.gd"),
	"moth": preload("res://scripts/moth.gd"),
	"boss_fluff": preload("res://scripts/boss_fluff.gd"),
	"boss_iron": preload("res://scripts/boss_iron.gd"),
	"boss_dryer": preload("res://scripts/boss_dryer.gd"),
}

# Colours of each world.
const THEMES := {
	1: {
		"sky": [Color("8c7ae6"), Color("9c88ff"), Color("b5a8ff"), Color("cec5ff"), Color("e2dcff")],
		"floor": Color("7f8fa6"), "wall": Color("a4b0be"), "holes": Color(1, 1, 1, 0.13),
	},
	2: {
		"sky": [Color("f8a978"), Color("fbbf8f"), Color("fdd3a8"), Color("fee3c4"), Color("fff1e0")],
		"floor": Color("5aa9a3"), "wall": Color("d9a066"), "holes": Color(1, 1, 1, 0.22),
	},
	3: {
		"sky": [Color("2d1b3d"), Color("44224f"), Color("5e2a52"), Color("7a3350"), Color("96404a")],
		"floor": Color("6c5b7b"), "wall": Color("7d6b8a"), "holes": Color(1.0, 0.6, 0.2, 0.12),
	},
}

var data: Dictionary = {}   # the level description
var player
var hud
var drain
var boss = null
var boxes: Array = []
var enemies: Array = []
var won := false
var flawless := true        # nobody got bonked or soaked (third star)
var time := 0.0
var _theme: Dictionary


func _ready() -> void:
	if data.is_empty():
		data = GameState.current_level()
	_theme = THEMES[data["world"]]

	var backdrop := Backdrop.new()
	backdrop.level_width = data["width"]
	backdrop.top_y = data["min_gy"] - 1200.0
	backdrop.sky = _theme["sky"]
	backdrop.hole_color = _theme["holes"]
	backdrop.lines = data["lines"]
	backdrop.show_king = data["world"] == 3 and data["boss"].is_empty()
	add_child(backdrop)

	_build_world()
	_build_decorations()
	_spawn_things()
	_spawn_player()

	hud = Hud.new()
	add_child(hud)
	hud.set_level("%s  %s" % [data["id"], data["name"]])
	hud.set_army([], data["need"])
	hud.set_pick(-1)
	if boss != null:
		hud.set_boss(boss.boss_name, boss.hp, boss.max_hp)
	if data["hint"] != "":
		hud.show_message(data["hint"], 4.5)


# ---------------- Building the level ----------------

func _build_world() -> void:
	var width: float = data["width"]
	# Left and right walls of the giant machine
	_add_block({"rect": Rect2(-120, -1600, 120, 2600), "style": "drum"})
	_add_block({"rect": Rect2(width, -1600, 120, 2600), "style": "drum"})
	for block in data["blocks"]:
		_add_block(block)
	for rect in data["water"]:
		var puddle := Water.new()
		puddle.position = rect.position
		puddle.size = rect.size
		add_child(puddle)
		puddle.soaked.connect(_on_soaked)


func _add_block(block: Dictionary) -> void:
	var rect: Rect2 = block["rect"]
	# A StaticBody2D is something solid that never moves.
	var body := StaticBody2D.new()
	body.collision_layer = 1 # terrain
	body.collision_mask = 0
	body.position = rect.position
	var shape := CollisionShape2D.new()
	var box_shape := RectangleShape2D.new()
	box_shape.size = rect.size
	shape.shape = box_shape
	shape.position = rect.size / 2.0
	shape.one_way_collision = block.get("one_way", false)
	body.add_child(shape)
	var art := BlockArt.new()
	art.size = rect.size
	art.style = block["style"]
	art.tint = block.get("tint", Color.WHITE)
	art.floor_color = _theme["floor"]
	art.wall_color = _theme["wall"]
	body.add_child(art)
	add_child(body)


func _build_decorations() -> void:
	var width: float = data["width"]
	# Bubbles rising from the floor across the whole level
	var bubbles := Art.make_bubble_particles(width, int(width / 45.0))
	bubbles.position = Vector2(width / 2.0, 610.0)
	bubbles.z_index = -50
	add_child(bubbles)

	# Big poppable bubbles
	for i in int(width / 320.0):
		var b := SoapBubble.new()
		b.min_x = 200.0
		b.max_x = width - 100.0
		b.floor_y = 600.0
		add_child(b)

	for s in data["signs"]:
		var label := Art.make_label(s["text"], 18, Color.WHITE, 6)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(300, 0)
		label.position = s["pos"] - Vector2(150, 0)
		label.z_index = 3
		add_child(label)


func _spawn_things() -> void:
	for s in data["socks"]:
		# instantiate() makes a copy of a scene, like a stamp.
		var sock = RecruitScene.instantiate()
		sock.kind = s["kind"]
		sock.position = s["pos"]
		add_child(sock)

	for pos in data["boxes"]:
		var box := PushableBox.new()
		box.position = pos
		add_child(box)
		boxes.append(box)

	for e in data["enemies"]:
		spawn_enemy(e["type"], e["pos"], e["a"], e["b"])

	drain = ExitDrain.new()
	drain.position = data["drain"]
	add_child(drain)
	drain.reached.connect(_on_drain_reached)

	if not data["boss"].is_empty():
		drain.locked = true
		boss = spawn_enemy(data["boss"]["type"], data["boss"]["pos"])
		boss.hp_changed.connect(_on_boss_hp_changed)
		boss.defeated.connect(_on_boss_defeated)


# Create one enemy. Bosses also use this to call their helpers.
func spawn_enemy(type: String, pos: Vector2, a = 0.0, b = 0.0):
	var enemy = ENEMY_SCRIPTS[type].new()
	enemy.position = pos
	enemy.level = self
	enemy.configure(a, b)
	add_child(enemy)
	enemies.append(enemy)
	return enemy


func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	player.position = data["start"]
	player.level = self
	add_child(player)
	player.army_changed.connect(_on_army_changed)
	player.pick_changed.connect(_on_pick_changed)
	var cam: Camera2D = player.camera
	cam.limit_left = -60
	cam.limit_right = int(data["width"]) + 60
	cam.limit_top = int(data["min_gy"]) - 900
	cam.limit_bottom = 760


# ---------------- Game rules ----------------

func _physics_process(delta: float) -> void:
	if won:
		return
	time += delta
	hud.set_time(time)
	# Fell out of the world? Back to a checkpoint.
	if player.global_position.y > 900.0:
		_send_back("Whoops! Lost in the lint trap. Try again!")
	# Standing in the drain with a big enough army? Win!
	if drain.player_inside and not drain.locked and player.army.size() >= data["need"]:
		_win()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(GameState.MAP_SCENE)
	elif event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func show_message(text: String) -> void:
	hud.show_message(text)


func shake(amount: float) -> void:
	player.shake(amount)


# Something bad happened: no "flawless" star this time.
func note_bonk() -> void:
	flawless = false


func _on_army_changed(_count: int) -> void:
	hud.set_army(player.army, data["need"])


func _on_pick_changed(kind: int) -> void:
	hud.set_pick(kind)


func _on_soaked(body: Node2D) -> void:
	if body == player:
		if not won:
			flawless = false
			Sfx.play("splash")
			Art.burst(self, player.global_position, Color(0.5, 0.8, 1.0, 0.9), 20, 220.0, 1.2)
			_send_back("SPLOOSH! Socks hate getting wet. Back to the checkpoint.")
	elif body.has_method("on_soaked"):
		body.on_soaked() # an enemy fell in


func _send_back(text: String) -> void:
	var spot: Vector2 = data["checkpoints"][0]
	for c in data["checkpoints"]:
		if c.x <= player.global_position.x:
			spot = c
	# call_deferred: move the player after the physics step finishes (safer)
	player.respawn.call_deferred(spot)
	show_message(text)


func _on_drain_reached(body: Node2D) -> void:
	if body != player or won:
		return
	if drain.locked:
		show_message("The drain is LOCKED. Defeat the boss first!")
		return
	var count: int = player.army.size()
	if count < data["need"]:
		show_message("Only %d sock(s) in your army. The drain needs %d! (E = whistle)" % [count, data["need"]])


func _on_boss_hp_changed(hp: int, max_hp: int) -> void:
	hud.set_boss(boss.boss_name, hp, max_hp)


func _on_boss_defeated(_boss) -> void:
	hud.set_boss("", 0, 0)
	drain.locked = false
	# The boss's helpers run away (they vanish in a puff).
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.is_in_group("bosses"):
			enemy.defeat()
	Sfx.play("win")


func _win() -> void:
	won = true
	player.controls_enabled = false
	player.set_physics_process(false)
	# The hero spins and slides into the drain.
	var tw := create_tween()
	tw.tween_property(player, "global_position", drain.global_position + Vector2(0, -4), 0.4)
	tw.parallel().tween_property(player.body, "rotation", TAU * 2.0, 0.8)
	tw.parallel().tween_property(player.body, "scale", Vector2(0.1, 0.1), 0.8)
	for sock in player.army:
		sock.body.squash(Vector2(0.6, 1.5), 0.8)
	Art.burst(self, drain.global_position + Vector2(0, -20), Color(0.6, 1.0, 0.95), 40, 300.0, 1.5)
	Sfx.play("win")

	# Stars: 1 for finishing, 1 for bringing EVERY sock, 1 for a flawless run.
	var total: int = data["socks"].size()
	var all_socks: bool = player.army.size() >= total
	var stars := 1 + (1 if all_socks else 0) + (1 if flawless else 0)
	GameState.complete(stars)
	hud.show_win(player.army.size(), total, flawless, stars, time)
