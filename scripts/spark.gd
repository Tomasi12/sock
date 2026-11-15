# spark.gd
# A Static Spark: a crackling ball of static electricity that floats back and
# forth between two points. It zaps the hero and any sock thrown at it.
# HOW TO BEAT IT: send a Wool Sock (Q). Wool soaks up static!
# The stink cloud does nothing (sparks have no nose).
extends "res://scripts/enemy.gd"

const SockTypes = preload("res://scripts/sock_types.gd")

const SPEED := 130.0

var point_a := Vector2.ZERO
var point_b := Vector2.ZERO
var _phase := 0.0
var _t := 0.0


func configure(a, b) -> void:
	point_a = a
	point_b = b


func _ready() -> void:
	hurt_center = Vector2.ZERO # a spark's position is its middle, not its feet
	setup_body(Vector2.ZERO, 20.0, 0)
	add_to_group("sparks")
	z_index = 6
	_phase = randf() * TAU


func stun(_seconds: float) -> void:
	pass


func can_be_stomped() -> bool:
	return false


func on_soaked() -> void:
	pass


func _physics_process(delta: float) -> void:
	if dead:
		return
	_t += delta
	# Slide smoothly between the two points (cos makes it slow down at the ends).
	var distance := maxf(point_a.distance_to(point_b), 1.0)
	_phase += delta * SPEED / distance * PI
	global_position = point_a.lerp(point_b, 0.5 - 0.5 * cos(_phase))
	queue_redraw()

	# Socks flying or walking into us
	for sock in get_tree().get_nodes_in_group("recruits"):
		if not sock.is_attacking():
			continue
		if (sock.global_position + Vector2(0, -20)).distance_to(global_position) < 38.0:
			if sock.kind == SockTypes.Kind.WOOL:
				Sfx.play("zap")
				say("FZZZT! The Wool Sock soaked up the static.")
				defeat()
				return
			var away := signf(sock.global_position.x - global_position.x)
			sock.knock_away(away if away != 0.0 else -sock.dir)
			Sfx.play("zap")
			Art.burst(get_parent(), global_position, Color("fff200"), 10, 180.0, 0.6)
			say("ZAP! Only WOOL can soak up static. (Press 1, then Q)")

	check_player_touch()


func _draw() -> void:
	# A jagged star that changes shape all the time
	var pts := PackedVector2Array()
	for i in 14:
		var r := 20.0 if i % 2 == 0 else 9.0
		r += sin(_t * 31.0 + i * 2.3) * 4.0
		var a := TAU * i / 14.0 + _t * 2.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, Color("fff200"))
	draw_circle(Vector2.ZERO, 8.0, Color.WHITE)
	# tiny lightning bolts
	for i in 3:
		var a := _t * 5.0 + i * TAU / 3.0
		var from := Vector2(cos(a), sin(a)) * 22.0
		draw_line(from, from * 1.5 + Vector2(sin(_t * 40.0 + i) * 5.0, 0), Color(0.6, 0.9, 1.0, 0.9), 2.0)
	# grumpy eyes
	draw_circle(Vector2(-3, -1), 1.6, Color.BLACK)
	draw_circle(Vector2(4, -1), 1.6, Color.BLACK)
