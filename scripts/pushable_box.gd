# pushable_box.gd
# A giant box of washing powder. Too heavy for the hero alone!
# Only Wool Socks can push it. More Wool Socks pushing = faster.
extends CharacterBody2D

const OUTLINE := Color(0.16, 0.11, 0.22)
const SIZE := Vector2(140, 70)
const GRAVITY := 1500.0
const MAX_PUSH_SPEED := 150.0

var _push := 0.0
var _start_y := 0.0


func _ready() -> void:
	add_to_group("pushables")
	_start_y = position.y
	z_index = 2
	collision_layer = 16  # layer 5 = props: the hero can stand on it
	collision_mask = 1    # it only bumps into terrain

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	shape.position = Vector2(0, -SIZE.y / 2.0) # origin = bottom middle
	add_child(shape)


# Used by the hero's "smart command": once the box fell into the puddle,
# there is no point sending more Wool Socks at it.
func is_useful() -> bool:
	return global_position.y < _start_y + 20.0


# Wool Socks call this every frame while they push.
func push(speed: float) -> void:
	_push += speed


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 1200.0)
	velocity.x = clampf(_push, -MAX_PUSH_SPEED, MAX_PUSH_SPEED)
	_push = 0.0 # nobody pushes next frame unless a sock pushes again
	move_and_slide()


func _draw() -> void:
	var r := Rect2(-SIZE.x / 2.0, -SIZE.y, SIZE.x, SIZE.y)
	draw_rect(r, Color("f39c12"))
	draw_rect(Rect2(r.position, Vector2(SIZE.x, 14)), Color("e67e22")) # lid
	draw_rect(Rect2(-SIZE.x / 2.0 + 8, -46, SIZE.x - 16, 26), Color("0984e3"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-SIZE.x / 2.0 + 8, -27), "SUPER SUDS", HORIZONTAL_ALIGNMENT_CENTER, SIZE.x - 16, 18, Color.WHITE)
	for b in [Vector2(-50, -8), Vector2(-40, -6), Vector2(48, -9)]:
		draw_circle(b, 4.0, Color(1, 1, 1, 0.8))
	draw_rect(r, OUTLINE, false, 3.0)
