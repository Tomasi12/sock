# recruit_sock.gd
# A lonely sock that can join your army.
#
# It uses a "state machine": the sock is always in exactly ONE state
# (waiting, following, flying, climbing...) and each state has its own code.
extends CharacterBody2D

const SockTypes = preload("res://scripts/sock_types.gd")
const SockBody = preload("res://scripts/sock_body.gd")
const StinkCloud = preload("res://scripts/stink_cloud.gd")
const Art = preload("res://scripts/art.gd")

enum State {
	IDLE,     # standing alone, waiting to be recruited
	FOLLOW,   # walking behind the hero
	THROWN,   # flying through the air after Q
	WALK,     # walking forward on its own (Wool pushes, Toe looks for a wall)
	CLIMB,    # Toe Sock climbing a wall
	PLACED,   # done with its job: now it is a solid block you can stand on
	RETURN,   # flying back to the hero after a whistle
	KNOCKED,  # bonked away by a Lint Bunny
}

const GRAVITY := 1500.0
const LAYER_TERRAIN := 1
const LAYER_PROPS := 16
const THROW_VELOCITY := Vector2(330, -430)
const WALK_SPEED := 110.0
const STEP_HEIGHT := 75.0  # distance between two Toe Socks on a wall

# @export makes the value editable in the Godot Inspector.
@export_enum("Hero", "Wool", "Toe", "Gym") var kind: int = SockTypes.Kind.WOOL

var state: int = State.IDLE
var player = null
var body: Node2D
var dir := 1.0
var climbed := false  # true if this sock is stuck on a wall as a step
var _timer := 0.0
var _hop_time := 0.0
var _climb_target_y := 0.0
var _wall_bump := 0.0
var _dizzy_time := 0.0
var _hint: Label


func _ready() -> void:
	add_to_group("recruits")
	z_index = 4
	body = SockBody.new()
	body.kind = kind
	add_child(body)

	# A small "E" floating above the sock when you are close enough.
	_hint = Art.make_label("E", 22, Color("ffd23f"), 6)
	_hint.position = Vector2(-10, -92)
	_hint.visible = false
	add_child(_hint)

	_set_collision(0, LAYER_TERRAIN | LAYER_PROPS)
	_hop_time = randf() * 10.0


func sock_name() -> String:
	return SockTypes.DATA[kind]["name"]


func can_be_recruited() -> bool:
	return state == State.IDLE


func is_deployed() -> bool:
	return state in [State.THROWN, State.WALK, State.CLIMB, State.PLACED]


# layer = "what I am", mask = "what I bump into"
func _set_collision(layer: int, mask: int) -> void:
	collision_layer = layer
	collision_mask = mask


func _physics_process(delta: float) -> void:
	_hop_time += delta
	if state != State.IDLE:
		_hint.visible = false
	match state:
		State.IDLE:
			_state_idle(delta)
		State.FOLLOW:
			_state_follow(delta)
		State.THROWN, State.KNOCKED:
			_state_flying(delta)
		State.WALK:
			_state_walk(delta)
		State.CLIMB:
			_state_climb(delta)
		_:
			pass # PLACED and RETURN do nothing here


# ---------------- States ----------------

func _state_idle(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	move_and_slide()
	body.rotation = sin(_hop_time * 2.5) * 0.08 # sad little sway
	if _dizzy_time > 0.0:
		_dizzy_time -= delta
		if _dizzy_time <= 0.0:
			body.dizzy = false
	var hero = get_tree().get_first_node_in_group("player")
	_hint.visible = hero != null and hero.global_position.distance_to(global_position) < 90.0
	_hint.modulate.a = 0.6 + 0.4 * sin(_hop_time * 6.0)


func _state_follow(delta: float) -> void:
	var index: int = player.army.find(self)
	if index < 0:
		return
	var target: Vector2 = player.get_trail_point(index)
	var before := global_position
	# lerp = move a part of the way to the target each frame (smooth!)
	global_position = global_position.lerp(target, minf(1.0, 12.0 * delta))
	var moved := global_position.x - before.x
	if absf(moved) > 0.2:
		body.facing = signf(moved)
		body.position.y = -absf(sin(_hop_time * 13.0)) * 7.0      # hop
		body.rotation = sin(_hop_time * 6.5 + index) * 0.18         # wobble
	else:
		body.position.y = lerpf(body.position.y, 0.0, minf(1.0, 10.0 * delta))
		body.rotation = lerpf(body.rotation, sin(_hop_time * 2.0 + index) * 0.05, minf(1.0, 10.0 * delta))


func _state_flying(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, 1200.0)
	move_and_slide()
	body.rotation += dir * 10.0 * delta # spin through the air
	if state == State.THROWN and kind == SockTypes.Kind.TOE and is_on_wall():
		_start_climb()
		return
	if is_on_floor():
		body.rotation = 0.0
		body.squash(Vector2(1.4, 0.65))
		Art.burst(get_parent(), global_position, Color(1, 1, 1, 0.7), 6, 70.0, 0.6)
		if state == State.KNOCKED:
			state = State.IDLE
			velocity = Vector2.ZERO
		elif kind == SockTypes.Kind.GYM:
			_release_stink()
			_place()
		elif kind == SockTypes.Kind.TOE:
			# Landed on the floor: scurry forward and look for a wall.
			state = State.WALK
			_timer = 1.2
		else:
			_place()


func _state_walk(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = dir * WALK_SPEED
	move_and_slide()
	_timer -= delta
	body.facing = dir
	body.rotation = dir * 0.2 + sin(_hop_time * 14.0) * 0.06 # leaning forward
	body.position.y = -absf(sin(_hop_time * 12.0)) * 3.0

	if kind == SockTypes.Kind.TOE and is_on_wall():
		_start_climb()
		return

	# Wool Socks push anything that has a push() function (the soap box).
	var pushing := false
	for i in get_slide_collision_count():
		var other := get_slide_collision(i).get_collider()
		if other != null and other.has_method("push") and kind == SockTypes.Kind.WOOL:
			other.push(dir * WALK_SPEED * 0.9)
			pushing = true
	if is_on_wall() and not pushing:
		_wall_bump += delta
	else:
		_wall_bump = 0.0
	if _timer <= 0.0 or _wall_bump > 0.25:
		_place()


func _state_climb(delta: float) -> void:
	# Go up (or slide down, if we hit the wall too high) towards our step.
	var gap := _climb_target_y - global_position.y
	if absf(gap) < 4.0:
		global_position.y = _climb_target_y
		climbed = true
		_place()
		return
	velocity = Vector2(dir * 60.0, 150.0 * signf(gap)) # press into the wall
	move_and_slide()
	body.rotation = sin(_hop_time * 16.0) * 0.1
	if gap < 0.0 and global_position.y <= _climb_target_y:
		climbed = true
		_place()
	elif not is_on_wall():
		# We reached the top of the wall! Hop onto it.
		state = State.THROWN
		_set_collision(0, LAYER_TERRAIN | LAYER_PROPS)
		velocity = Vector2(dir * 120.0, -220.0)


# ---------------- Actions called by the hero ----------------

func join(hero) -> void:
	player = hero
	state = State.FOLLOW
	climbed = false
	_set_collision(0, 0) # followers don't bump into anything
	velocity = Vector2.ZERO
	body.rotation = 0.0
	body.dizzy = false
	body.squash(Vector2(0.7, 1.3))


func command(direction: float, from_pos: Vector2) -> void:
	dir = direction
	body.facing = dir
	global_position = from_pos + Vector2(dir * 18.0, -30.0)
	_set_collision(0, LAYER_TERRAIN | LAYER_PROPS)
	if kind == SockTypes.Kind.WOOL:
		# Wool is too heavy to throw far: it marches forward instead.
		state = State.WALK
		_timer = 3.5
		velocity = Vector2(0, -150)
	else:
		state = State.THROWN
		velocity = Vector2(THROW_VELOCITY.x * dir, THROW_VELOCITY.y)
	body.squash(Vector2(0.7, 1.3))


func knock_away(direction: float) -> void:
	state = State.KNOCKED
	dir = direction
	_set_collision(0, LAYER_TERRAIN | LAYER_PROPS)
	velocity = Vector2(direction * 280.0, -480.0)
	body.dizzy = true
	_dizzy_time = 2.0


func recall(hero) -> void:
	state = State.RETURN
	climbed = false
	player = hero
	_set_collision(0, 0)
	body.position = Vector2.ZERO
	var start := global_position
	# tween_method calls _return_step with a number going from 0 to 1.
	var tw := create_tween()
	tw.tween_method(_return_step.bind(start), 0.0, 1.0, 0.6)
	tw.tween_callback(func(): hero.add_to_army(self))


func _return_step(k: float, start: Vector2) -> void:
	var target: Vector2 = player.global_position + Vector2(0, -10)
	# Move in a straight line + add a curve upwards = a nice arc.
	global_position = start.lerp(target, k) + Vector2(0, -sin(k * PI) * 140.0)
	body.rotation = k * TAU * dir


# ---------------- Helpers ----------------

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 1200.0)


# The job is done: become a solid block other socks and the hero can stand on.
func _place() -> void:
	state = State.PLACED
	velocity = Vector2.ZERO
	_set_collision(LAYER_PROPS, LAYER_TERRAIN | LAYER_PROPS)
	body.rotation = 0.0
	body.position = Vector2.ZERO
	body.squash(Vector2(1.25, 0.8))


func _start_climb() -> void:
	state = State.CLIMB
	# While climbing we only touch terrain, so we can pass other stuck socks.
	_set_collision(0, LAYER_TERRAIN)
	var steps_here := 0
	for sock in get_tree().get_nodes_in_group("recruits"):
		if sock != self and sock.climbed and sock.state == State.PLACED \
				and absf(sock.global_position.x - global_position.x) < 50.0:
			steps_here += 1
	# Each new Toe Sock stops one step higher than the last one: a staircase!
	_climb_target_y = _ground_y() - STEP_HEIGHT * (steps_here + 1)
	body.squash(Vector2(0.8, 1.2))


# Find the floor below us with an invisible ray.
func _ground_y() -> float:
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(-dir * 20.0, 0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 800), LAYER_TERRAIN)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return global_position.y
	return hit["position"].y


func _release_stink() -> void:
	var cloud := StinkCloud.new()
	cloud.position = global_position + Vector2(0, -20)
	# call_deferred = "do it at the end of this frame" (safe during physics)
	get_parent().add_child.call_deferred(cloud)
