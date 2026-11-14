# intro.gd
# The short story screen before the level. The text appears letter by letter
# (a "typewriter" effect) by animating the Label's visible_ratio from 0 to 1.
extends Control

const Art = preload("res://scripts/art.gd")
const SockBody = preload("res://scripts/sock_body.gd")
const SockTypes = preload("res://scripts/sock_types.gd")

const LEVEL_SCENE := "res://scenes/level.tscn"

var _story: Label
var _hint: Label
var _typing: Tween
var _done_typing := false
var _leaving := false
var _angry_sock: Node2D
var _t := 0.0


func _ready() -> void:
	var screen := get_viewport_rect().size

	var bg := ColorRect.new()
	bg.color = Color("1e1a2e")
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# An angry little sock, shaking with rage
	var holder := Node2D.new()
	holder.position = Vector2(screen.x / 2.0, screen.y / 2.0 - 90.0)
	holder.scale = Vector2(3, 3)
	add_child(holder)
	_angry_sock = SockBody.new()
	_angry_sock.kind = SockTypes.Kind.WOOL
	holder.add_child(_angry_sock)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 220
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)

	_story = Art.make_label("Every sock you ever lost is still alive.\nAnd they are angry.", 44, Color.WHITE, 8)
	_story.visible_ratio = 0.0
	column.add_child(_story)

	var small := Art.make_label("The washing machine is a portal. The Dryer King has stolen socks for centuries.\nYou are The Last Sock. Lead the rebellion.", 20, Color("b8b0ff"), 4)
	column.add_child(small)

	_hint = Art.make_label("Press any key", 24, Color("ffd23f"), 4)
	_hint.modulate.a = 0.0
	column.add_child(_hint)

	_typing = create_tween()
	_typing.tween_property(_story, "visible_ratio", 1.0, 3.0)
	_typing.tween_callback(_finish_typing)


func _process(delta: float) -> void:
	_t += delta
	_angry_sock.position.x = sin(_t * 40.0) * 1.2 # trembling with anger
	_angry_sock.rotation = sin(_t * 31.0) * 0.04


func _finish_typing() -> void:
	if _done_typing:
		return
	_done_typing = true
	_story.visible_ratio = 1.0
	_angry_sock.squash(Vector2(1.4, 0.6), 0.6)
	var tw := create_tween().set_loops()
	tw.tween_property(_hint, "modulate:a", 1.0, 0.5)
	tw.tween_property(_hint, "modulate:a", 0.3, 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton):
		return
	if not event.is_pressed() or event.is_echo():
		return
	if not _done_typing:
		# First press: skip the typing animation
		_typing.kill()
		_finish_typing()
	elif not _leaving:
		_leaving = true
		get_tree().change_scene_to_file(LEVEL_SCENE)
