# hud.gd
# The on-screen interface during the game: sock counter, messages,
# controls help, and the "You escaped!" screen.
# A CanvasLayer draws on top of the game and does NOT move with the camera.
extends CanvasLayer

const Art = preload("res://scripts/art.gd")
const SockBody = preload("res://scripts/sock_body.gd")

const MENU_SCENE := "res://scenes/main_menu.tscn"

var _count_label: Label
var _icons: HBoxContainer
var _message: Label
var _msg_tween: Tween


func _ready() -> void:
	layer = 10

	# Top-left panel: the Sock Army counter
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.11, 0.22, 0.75)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(16, 16)
	add_child(panel)

	var column := VBoxContainer.new()
	panel.add_child(column)
	_count_label = Art.make_label("SOCK ARMY: 0", 30, Color("ffd23f"), 6)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_count_label)
	_icons = HBoxContainer.new()
	_icons.custom_minimum_size = Vector2(0, 40)
	column.add_child(_icons)
	var goal := Art.make_label("Goal: bring 3 socks to the glowing drain", 16, Color.WHITE, 4)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(goal)

	# Bottom: controls help
	var help := Art.make_label("A/D or Arrows: move    Space: jump    E: recruit / whistle    Q: send a sock    Esc: menu", 18, Color.WHITE, 5)
	add_child(help)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	help.offset_top = -40
	help.offset_bottom = -10

	# Middle-top: messages that fade away
	_message = Art.make_label("", 28, Color.WHITE, 8)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_message)
	_message.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_message.offset_left = 200
	_message.offset_right = -200
	_message.offset_top = 175
	_message.offset_bottom = 255
	_message.modulate.a = 0.0


# Update the counter and the little sock pictures.
func set_army(army: Array, needed: int) -> void:
	_count_label.text = "SOCK ARMY: %d / %d" % [army.size(), needed]
	var col := Color("55efc4") if army.size() >= needed else Color("ffd23f")
	_count_label.add_theme_color_override("font_color", col)
	for child in _icons.get_children():
		child.queue_free()
	for sock in army:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(26, 40)
		var shrink := Node2D.new()
		shrink.position = Vector2(12, 38)
		shrink.scale = Vector2(0.65, 0.65)
		var icon := SockBody.new()
		icon.kind = sock.kind
		shrink.add_child(icon)
		holder.add_child(shrink)
		_icons.add_child(holder)
		icon.squash(Vector2(0.6, 1.4))


func show_message(text: String, seconds := 2.8) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	if _msg_tween and _msg_tween.is_valid():
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_interval(seconds)
	_msg_tween.tween_property(_message, "modulate:a", 0.0, 0.5)


func show_win(count: int) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.2, 0.75)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)

	column.add_child(Art.make_label("YOU ESCAPED DOWN THE DRAIN!", 56, Color("ffd23f"), 10))
	column.add_child(Art.make_label("%d brave socks slid into the pipes.\nSomewhere, the Dryer King feels a cold draft..." % count, 26, Color.WHITE, 6))

	var again := Art.make_button("Play Again")
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(_on_again_pressed)
	column.add_child(again)
	var menu := Art.make_button("Main Menu")
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.pressed.connect(_on_menu_pressed)
	column.add_child(menu)
	again.grab_focus()

	# Fade in
	dim.modulate.a = 0.0
	center.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(dim, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(center, "modulate:a", 1.0, 0.4)


func _on_again_pressed() -> void:
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
