# player.gd
# The hero: The Last Sock.
# It moves, jumps, recruits lonely socks (E) and sends them to work (Q).
extends CharacterBody2D

# A signal is a message other nodes can listen to. The level listens to these
# to update the counter and the "Q sends:" text on screen.
signal army_changed(count: int)
signal pick_changed(kind: int)

const SockTypes = preload("res://scripts/sock_types.gd")
const SockBody = preload("res://scripts/sock_body.gd")
const Art = preload("res://scripts/art.gd")

# --- Movement numbers. Change them to make the sock feel different! ---
const SPEED := 260.0            # pixels per second
const ACCELERATION := 2200.0    # how fast we reach full speed
const JUMP_VELOCITY := -620.0   # negative = up
const GRAVITY := 1500.0
const MAX_FALL_SPEED := 1100.0
const COYOTE_TIME := 0.1        # you can still jump a moment after leaving a ledge
const JUMP_BUFFER := 0.12       # pressing jump slightly before landing still works

const RECRUIT_RANGE := 90.0     # how close you must be to recruit a sock

# The "trail" is a list of places the hero has been. Followers walk on it,
# which makes them form a wobbly line behind you.
const TRAIL_POINT_GAP := 4.0
const TRAIL_SPACING := 8        # trail points between two followers
const TRAIL_MAX := 120

# Physics layers (each layer is a bit: layer 1 = 1, layer 2 = 2, layer 5 = 16)
const LAYER_TERRAIN := 1
const LAYER_PLAYER := 2
const LAYER_PROPS := 16

# How a thrown sock flies (the recruit uses the same numbers).
const THROW_VELOCITY := Vector2(330, -430)

const SEND_LINES := {
	SockTypes.Kind.WOOL: "Go, Wool Sock! PUSH!",
	SockTypes.Kind.TOE: "Toe Sock, CLIMB!",
	SockTypes.Kind.GYM: "Gym Sock... release the STINK!",
}
# Tab goes through this list. -1 means "AUTO: the game picks for me".
const PICK_ORDER := [-1, SockTypes.Kind.WOOL, SockTypes.Kind.TOE, SockTypes.Kind.GYM]

var facing := 1.0
var army: Array = []                 # recruits following us, front first
var trail: Array[Vector2] = []
var controls_enabled := true
var level = null                     # the level sets this so we can show messages
var body: Node2D                     # the drawing of our sock
var camera: Camera2D
var selected_kind := -1              # which sock type Q sends (-1 = auto)
var wind_x := 0.0                    # a boss can push us with wind

var _coyote := 0.0
var _jump_buffer := 0.0
var _was_on_floor := true
var _walk_time := 0.0
var _invulnerable := 0.0
var _knockback := 0.0
var _shake := 0.0
var _aim_line: Line2D


func _ready() -> void:
	add_to_group("player")
	collision_layer = LAYER_PLAYER
	collision_mask = LAYER_TERRAIN | LAYER_PROPS
	z_index = 5

	body = SockBody.new()
	body.kind = SockTypes.Kind.HERO
	add_child(body)

	# The camera follows the player because it is a child of the player.
	camera = Camera2D.new()
	camera.position = Vector2(0, -80)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	add_child(camera)

	# The dotted line that shows where a thrown sock will fly.
	_aim_line = Line2D.new()
	_aim_line.width = 4.0
	_aim_line.default_color = Color(1, 1, 1, 0.75)
	_aim_line.visible = false
	add_child(_aim_line)


# _physics_process runs 60 times per second. All movement goes here.
func _physics_process(delta: float) -> void:
	_move(delta)
	_animate(delta)
	_update_trail()
	if controls_enabled:
		if Input.is_action_just_pressed("recruit"):
			_try_recruit()
		_handle_picking()
		_handle_command()
	else:
		_aim_line.visible = false


func _move(delta: float) -> void:
	if is_on_floor():
		_coyote = COYOTE_TIME
	else:
		_coyote -= delta
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)

	# get_axis gives -1 (left), 0 (nothing) or 1 (right).
	var input_dir := 0.0
	if controls_enabled:
		input_dir = Input.get_axis("move_left", "move_right")
	if _knockback > 0.0:
		_knockback -= delta # while knocked back, ignore the keys for a moment
	else:
		velocity.x = move_toward(velocity.x, input_dir * SPEED + wind_x, ACCELERATION * delta)
	wind_x = 0.0 # the boss must set it again every frame
	if input_dir != 0.0:
		facing = signf(input_dir)
		body.facing = facing

	# Jumping
	_jump_buffer -= delta
	if controls_enabled and Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer = 0.0
		_coyote = 0.0
		body.squash(Vector2(0.7, 1.35)) # STRETCH!
		Sfx.play("jump")
		Art.burst(get_parent(), global_position, Color(1, 1, 1, 0.8), 6, 80.0, 0.8)
	# Let go of jump early = smaller jump.
	if Input.is_action_just_released("jump") and velocity.y < -200.0:
		velocity.y *= 0.55

	# move_and_slide() moves the body and stops it at walls and floors.
	move_and_slide()

	# Just landed? SQUISH!
	if is_on_floor() and not _was_on_floor:
		body.squash(Vector2(1.4, 0.65))
		Sfx.play("land")
		Art.burst(get_parent(), global_position, Color(0.95, 0.95, 1.0, 0.7), 8, 90.0, 0.7)
	_was_on_floor = is_on_floor()


func _animate(delta: float) -> void:
	if is_on_floor() and absf(velocity.x) > 20.0:
		# Walking wobble: rock left and right and bob up and down.
		_walk_time += delta * 14.0
		body.rotation = sin(_walk_time) * 0.13
		body.position.y = -absf(sin(_walk_time)) * 3.0
	else:
		body.rotation = lerpf(body.rotation, 0.0, minf(1.0, 12.0 * delta))
		body.position.y = lerpf(body.position.y, 0.0, minf(1.0, 12.0 * delta))

	# Blink while invulnerable after a hit.
	if _invulnerable > 0.0:
		_invulnerable -= delta
		body.modulate.a = 0.35 if int(_invulnerable * 15.0) % 2 == 0 else 1.0
	else:
		body.modulate.a = 1.0

	# Screen shake: move the camera a random little bit, less and less.
	if _shake > 0.0:
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
		_shake = move_toward(_shake, 0.0, 40.0 * delta)
	else:
		camera.offset = Vector2.ZERO


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


# Remember where we walked, so followers can walk the same path.
func _update_trail() -> void:
	if trail.is_empty() or trail[0].distance_to(global_position) >= TRAIL_POINT_GAP:
		trail.push_front(global_position)
		while trail.size() > TRAIL_MAX:
			trail.pop_back()


# Where should follower number "index" stand? (0 = first in line)
func get_trail_point(index: int) -> Vector2:
	if trail.is_empty():
		return global_position
	var i := mini((index + 1) * TRAIL_SPACING, trail.size() - 1)
	return trail[i]


# --- E key: recruit a lonely sock, or whistle socks back ---
func _try_recruit() -> void:
	var best = null
	var best_distance := RECRUIT_RANGE
	for sock in get_tree().get_nodes_in_group("recruits"):
		if not sock.can_be_recruited():
			continue
		var d: float = global_position.distance_to(sock.global_position)
		if d < best_distance:
			best = sock
			best_distance = d
	if best != null:
		add_to_army(best)
		Sfx.play("recruit")
		Art.burst(get_parent(), best.global_position + Vector2(0, -30), Color("ffd23f"), 14, 160.0)
		_say("%s joined the rebellion!" % best.sock_name())
		return

	# No lonely sock nearby: whistle! Every sock that was in our army comes back.
	var called := 0
	for sock in get_tree().get_nodes_in_group("recruits"):
		if sock.can_be_whistled():
			sock.recall(self)
			called += 1
	if called > 0:
		Sfx.play("whistle")
		_say("*WHISTLE*  %d sock(s) coming back!" % called)
	else:
		_say("No socks nearby. Walk closer to a lonely sock!")


func add_to_army(sock) -> void:
	if sock in army:
		return
	army.append(sock)
	sock.join(self)
	body.squash(Vector2(0.85, 1.15))
	army_changed.emit(army.size())


# --- Tab / 1 / 2 / 3: choose which kind of sock Q sends ---
func _handle_picking() -> void:
	if Input.is_action_just_pressed("pick_next"):
		var i := PICK_ORDER.find(selected_kind)
		_set_pick(PICK_ORDER[(i + 1) % PICK_ORDER.size()])
	elif Input.is_action_just_pressed("pick_wool"):
		_set_pick(SockTypes.Kind.WOOL)
	elif Input.is_action_just_pressed("pick_toe"):
		_set_pick(SockTypes.Kind.TOE)
	elif Input.is_action_just_pressed("pick_gym"):
		_set_pick(SockTypes.Kind.GYM)


func _set_pick(kind: int) -> void:
	# Pressing the same number again goes back to AUTO.
	selected_kind = -1 if kind == selected_kind else kind
	Sfx.play("click")
	pick_changed.emit(selected_kind)


# --- Q key: HOLD to aim (a line shows the path), LET GO to send the sock ---
func _handle_command() -> void:
	if Input.is_action_just_pressed("command") and army.is_empty():
		_say("No socks to command! Recruit some first (E).")
	if Input.is_action_pressed("command") and not army.is_empty():
		_show_aim(_choose_sock_to_send())
	else:
		_aim_line.visible = false
	if Input.is_action_just_released("command") and not army.is_empty():
		_command()


func _show_aim(sock) -> void:
	var points := PackedVector2Array()
	if sock.kind == SockTypes.Kind.WOOL:
		# Wool Socks walk: show a straight arrow on the ground.
		points.append(Vector2(facing * 18.0, -12.0))
		points.append(Vector2(facing * 220.0, -12.0))
		points.append(Vector2(facing * 200.0, -24.0))
	else:
		# Other socks fly. School physics: position = start + speed*t + gravity*t*t/2
		var start := Vector2(facing * 18.0, -30.0)
		var speed := Vector2(THROW_VELOCITY.x * facing, THROW_VELOCITY.y)
		var t := 0.0
		while t < 1.2:
			var p := start + speed * t + Vector2(0, 0.5 * GRAVITY * t * t)
			points.append(p)
			if p.y > 10.0:
				break
			t += 0.05
	_aim_line.points = points
	_aim_line.default_color = SockTypes.DATA[sock.kind]["body"].lerp(Color.WHITE, 0.4)
	_aim_line.visible = true


func _command() -> void:
	var sock = _choose_sock_to_send()
	army.erase(sock)
	sock.command(facing, global_position)
	Sfx.play("throw")
	army_changed.emit(army.size())
	_say(SEND_LINES.get(sock.kind, "Go!"))


# Which sock does Q send?
# If you picked a kind (1/2/3/Tab) and you have one: that one.
# Otherwise a bit of "smart" help: Box ahead -> Wool. Spark ahead -> Wool.
# Enemy ahead -> Gym. Wall ahead -> Toe. If nothing fits: the first in line.
func _choose_sock_to_send():
	if selected_kind >= 0:
		var picked = _first_of_kind(selected_kind)
		if picked != null:
			return picked
	if _thing_ahead("pushables", 260.0) or _thing_ahead("sparks", 320.0):
		var wool = _first_of_kind(SockTypes.Kind.WOOL)
		if wool != null:
			return wool
	if _thing_ahead("enemies", 400.0):
		var gym = _first_of_kind(SockTypes.Kind.GYM)
		if gym != null:
			return gym
	if _wall_ahead(260.0):
		var toe = _first_of_kind(SockTypes.Kind.TOE)
		if toe != null:
			return toe
	return army[0]


func _first_of_kind(kind: int):
	for sock in army:
		if sock.kind == kind:
			return sock
	return null


func _thing_ahead(group_name: String, max_distance: float) -> bool:
	for thing in get_tree().get_nodes_in_group(group_name):
		if thing.has_method("is_useful") and not thing.is_useful():
			continue
		if group_name == "enemies" and thing.is_in_group("sparks"):
			continue # sparks do not care about stink
		var dx: float = (thing.global_position.x - global_position.x) * facing
		var dy: float = absf(thing.global_position.y - global_position.y)
		if dx > 0.0 and dx < max_distance and dy < 230.0:
			return true
	return false


# Shoot an invisible ray forward to see if a wall is in front of us.
func _wall_ahead(max_distance: float) -> bool:
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(0, -25)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(facing * max_distance, 0), LAYER_TERRAIN)
	return not space.intersect_ray(query).is_empty()


# Called by an enemy when it touches us.
func hit_by_enemy(from_x: float) -> void:
	if _invulnerable > 0.0 or not controls_enabled:
		return
	_invulnerable = 1.3
	var away := signf(global_position.x - from_x)
	if away == 0.0:
		away = -facing
	velocity = Vector2(away * 330.0, -380.0)
	_knockback = 0.3
	body.squash(Vector2(1.3, 0.7))
	Sfx.play("bonk")
	shake(6.0)
	if level != null:
		level.note_bonk()
	if army.is_empty():
		_say("Ouch! That really hurt.")
	else:
		var lost = army.pop_back()
		lost.knock_away(away)
		army_changed.emit(army.size())
		_say("BONK! Your %s got knocked away! Go get it (E)." % lost.sock_name())


# A moth (or something else) takes one sock out of the army.
func lose_sock(sock, direction: float, text: String) -> void:
	if not (sock in army):
		return
	army.erase(sock)
	sock.knock_away(direction)
	army_changed.emit(army.size())
	Sfx.play("bonk", 1.4)
	if level != null:
		level.note_bonk()
	_say(text)


# Jumping on an enemy makes us bounce up.
func bounce() -> void:
	velocity.y = -480.0
	_coyote = 0.0
	body.squash(Vector2(0.75, 1.3))


# Put the hero (and the followers) back at a safe spot.
func respawn(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	trail.clear()
	for sock in army:
		sock.global_position = pos
	body.squash(Vector2(0.6, 1.4))
	_invulnerable = 1.0


func _say(text: String) -> void:
	if level != null:
		level.show_message(text)
