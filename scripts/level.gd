# level.gd
# Builds the whole level with code: floors, walls, the puddle, buttons,
# the laundry basket, socks to recruit, Lint Bunnies and the exit drain.
#
# Level map (left to right):
#   start -> Wool + Gym socks -> soap box -> PUDDLE -> buttons + Lint Bunny
#   -> laundry basket -> TALL DRUM WALL -> drop down -> Lint Bunny -> EXIT DRAIN
extends Node2D

const PlayerScene = preload("res://scenes/player.tscn")
const RecruitScene = preload("res://scenes/recruit_sock.tscn")
const BunnyScene = preload("res://scenes/lint_bunny.tscn")

const SockTypes = preload("res://scripts/sock_types.gd")
const Art = preload("res://scripts/art.gd")
const Hud = preload("res://scripts/hud.gd")
const Backdrop = preload("res://scripts/backdrop.gd")
const BlockArt = preload("res://scripts/block_art.gd")
const Water = preload("res://scripts/water.gd")
const PushableBox = preload("res://scripts/pushable_box.gd")
const SoapBubble = preload("res://scripts/soap_bubble.gd")
const ExitDrain = preload("res://scripts/exit_drain.gd")

const MENU_SCENE := "res://scenes/main_menu.tscn"
const SOCKS_NEEDED := 3
const LEVEL_WIDTH := 3200.0
const FLOOR_Y := 600.0

# Safe places to go back to after falling in the puddle.
const CHECKPOINTS := [Vector2(120, 598), Vector2(460, 598), Vector2(1010, 598), Vector2(2080, 398), Vector2(2560, 598)]

var player
var hud
var box
var drain
var bunnies: Array = []
var won := false


func _ready() -> void:
	add_child(Backdrop.new())
	_build_world()
	_build_decorations()
	_spawn_things()
	_spawn_player()

	hud = Hud.new()
	add_child(hud)
	hud.set_army([], SOCKS_NEEDED)
	hud.show_message("Lonely socks need you! Walk close to one and press E.", 4.0)


# ---------------- Building the level ----------------

func _build_world() -> void:
	# Left and right walls of the giant drum
	_add_block(Rect2(-120, -600, 120, 1400), "drum")
	_add_block(Rect2(LEVEL_WIDTH, -600, 120, 1400), "drum")

	# Floor 1, the puddle pit, floor 2
	_add_block(Rect2(0, FLOOR_Y, 700, 200), "floor")
	_add_block(Rect2(700, FLOOR_Y + 70, 260, 130), "pit")
	_add_block(Rect2(960, FLOOR_Y, 1040, 200), "floor")
	var puddle := Water.new()
	puddle.position = Vector2(700, FLOOR_Y + 15)
	puddle.size = Vector2(260, 55)
	add_child(puddle)
	puddle.soaked.connect(_on_soaked)

	# Giant buttons. "One way" means you can jump up through them from below.
	_add_block(Rect2(1150, 505, 120, 24), "button", true, Color("fd79a8"))
	_add_block(Rect2(1330, 425, 120, 24), "button", true, Color("00cec9"))

	# Laundry basket
	_add_block(Rect2(1620, 530, 180, 70), "basket")

	# The tall drum wall (200 px high!) and the floor on top of it
	_add_block(Rect2(2000, FLOOR_Y - 200, 500, 400), "drum")

	# Last floor with the exit
	_add_block(Rect2(2500, FLOOR_Y, 700, 200), "floor")


func _add_block(rect: Rect2, style: String, one_way := false, tint := Color.WHITE) -> void:
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
	shape.one_way_collision = one_way
	body.add_child(shape)
	var art := BlockArt.new()
	art.size = rect.size
	art.style = style
	art.tint = tint
	body.add_child(art)
	add_child(body)


func _build_decorations() -> void:
	# Bubbles rising from the floor across the whole level
	var bubbles := Art.make_bubble_particles(LEVEL_WIDTH, 70)
	bubbles.position = Vector2(LEVEL_WIDTH / 2.0, FLOOR_Y + 10)
	bubbles.z_index = -50
	add_child(bubbles)

	# Big poppable bubbles
	for i in 10:
		var b := SoapBubble.new()
		b.min_x = 200.0
		b.max_x = LEVEL_WIDTH - 100.0
		b.floor_y = FLOOR_Y
		add_child(b)

	# Foam spilling out of the washing machine portal
	var foam := CPUParticles2D.new()
	foam.texture = Art.soft_circle()
	foam.amount = 24
	foam.lifetime = 1.6
	foam.position = Vector2(120, 480)
	foam.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	foam.emission_rect_extents = Vector2(80, 6)
	foam.direction = Vector2(1, -1)
	foam.spread = 40.0
	foam.initial_velocity_min = 40.0
	foam.initial_velocity_max = 90.0
	foam.gravity = Vector2(0, 160)
	foam.scale_amount_min = 0.6
	foam.scale_amount_max = 1.4
	foam.color = Color(1, 1, 1, 0.9)
	foam.color_ramp = Art.fade_gradient()
	foam.z_index = -40
	add_child(foam)

	# Tutorial signs
	_add_sign(Vector2(300, 440), "Lonely socks! Walk close and press E to recruit.")
	_add_sign(Vector2(600, 400), "Too heavy for you! Press Q near it: Wool Socks PUSH.")
	_add_sign(Vector2(1120, 330), "Lint Bunny! Press Q: Gym Socks release a STINK cloud.")
	_add_sign(Vector2(1830, 300), "Huge wall! Toe Socks CLIMB walls (Q). Or throw socks to build a pile!")
	_add_sign(Vector2(2200, 230), "Left socks behind? Press E with no sock near you to WHISTLE them back.")
	_add_sign(Vector2(2700, 420), "THE DRAIN is near. Bring 3 socks to escape!")


func _add_sign(pos: Vector2, text: String) -> void:
	var label := Art.make_label(text, 18, Color.WHITE, 6)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(280, 0)
	label.position = pos - Vector2(140, 0)
	label.z_index = 3
	add_child(label)


func _spawn_things() -> void:
	_add_recruit(SockTypes.Kind.WOOL, Vector2(300, FLOOR_Y))
	_add_recruit(SockTypes.Kind.GYM, Vector2(420, FLOOR_Y))
	_add_recruit(SockTypes.Kind.TOE, Vector2(1390, 425))   # on the high button
	_add_recruit(SockTypes.Kind.TOE, Vector2(1710, 530))   # on the laundry basket
	_add_recruit(SockTypes.Kind.GYM, Vector2(2300, 400))   # on top of the wall

	box = PushableBox.new()
	box.position = Vector2(590, FLOOR_Y)
	add_child(box)

	_add_bunny(Vector2(1300, FLOOR_Y), 1100.0, 1560.0)
	_add_bunny(Vector2(2720, FLOOR_Y), 2580.0, 2860.0)

	drain = ExitDrain.new()
	drain.position = Vector2(2990, FLOOR_Y)
	add_child(drain)
	drain.reached.connect(_on_drain_reached)


func _add_recruit(kind: int, pos: Vector2) -> void:
	# instantiate() makes a copy of a scene, like a stamp.
	var sock = RecruitScene.instantiate()
	sock.kind = kind
	sock.position = pos
	add_child(sock)


func _add_bunny(pos: Vector2, left_x: float, right_x: float) -> void:
	var bunny = BunnyScene.instantiate()
	bunny.position = pos
	bunny.left_x = left_x
	bunny.right_x = right_x
	add_child(bunny)
	bunnies.append(bunny)


func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	player.position = CHECKPOINTS[0]
	player.level = self
	add_child(player)
	player.army_changed.connect(_on_army_changed)
	var cam: Camera2D = player.camera
	cam.limit_left = -60
	cam.limit_right = int(LEVEL_WIDTH) + 60
	cam.limit_top = -300
	cam.limit_bottom = 760


# ---------------- Game rules ----------------

func _physics_process(_delta: float) -> void:
	if won:
		return
	# Fell out of the world? Back to a checkpoint.
	if player.global_position.y > 900.0:
		_send_back("Whoops! Lost in the lint trap. Try again!")
	# Standing in the drain and the army just became big enough? Win!
	if drain.player_inside and player.army.size() >= SOCKS_NEEDED:
		_win()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MENU_SCENE)


func show_message(text: String) -> void:
	hud.show_message(text)


func _on_army_changed(_count: int) -> void:
	hud.set_army(player.army, SOCKS_NEEDED)


func _on_soaked(body: Node2D) -> void:
	if body == player and not won:
		Art.burst(self, player.global_position, Color(0.5, 0.8, 1.0, 0.9), 20, 220.0, 1.2)
		_send_back("SPLOOSH! Socks hate getting wet. Back to the checkpoint.")


func _send_back(text: String) -> void:
	var spot: Vector2 = CHECKPOINTS[0]
	for c in CHECKPOINTS:
		if c.x <= player.global_position.x:
			spot = c
	# call_deferred: move the player after the physics step finishes (safer)
	player.respawn.call_deferred(spot)
	show_message(text)


func _on_drain_reached(body: Node2D) -> void:
	if body != player or won:
		return
	var count: int = player.army.size()
	if count < SOCKS_NEEDED:
		show_message("Only %d sock(s) in your army. The drain needs %d! (E = whistle)" % [count, SOCKS_NEEDED])


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
	hud.show_win(player.army.size())
