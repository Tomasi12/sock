# hud.gd
# The on-screen interface during the game: sock counter, which sock Q sends,
# level name and timer, messages, the boss health bar, and the win screen.
# A CanvasLayer draws on top of the game and does NOT move with the camera.
extends CanvasLayer

const Art = preload("res://scripts/art.gd")
const SockBody = preload("res://scripts/sock_body.gd")
const SockTypes = preload("res://scripts/sock_types.gd")
const StarRow = preload("res://scripts/star_row.gd")

var _count_label: Label
var _icons: HBoxContainer
var _pick_label: Label
var _level_label: Label
var _time_label: Label
var _message: Label
var _msg_tween: Tween
var _boss_box: VBoxContainer
var _boss_label: Label
var _boss_bar: HBoxContainer
var _need := 3


func _ready() -> void:
	layer = 10

	# Top-left panel: the Sock Army counter
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.position = Vector2(16, 16)
	add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	_count_label = _left_label("SOCK ARMY: 0", 28, Color("ffd23f"))
	column.add_child(_count_label)
	_icons = HBoxContainer.new()
	_icons.custom_minimum_size = Vector2(0, 40)
	column.add_child(_icons)
	_pick_label = _left_label("", 16, Color.WHITE)
	column.add_child(_pick_label)

	# Top-right panel: level name and timer
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", _panel_style())
	add_child(right)
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -16
	right.offset_top = 16
	var right_column := VBoxContainer.new()
	right.add_child(right_column)
	_level_label = _left_label("", 20, Color("ffd23f"))
	right_column.add_child(_level_label)
	_time_label = _left_label("0:00", 18, Color.WHITE)
	right_column.add_child(_time_label)

	# Bottom: controls help
	var help := Art.make_label("A/D: move   Space: jump   E: recruit / whistle   Q: hold to aim, let go to send   Tab or 1-4: pick sock   R: restart   Esc: map   M: sound", 15, Color.WHITE, 5)
	add_child(help)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	help.offset_top = -36
	help.offset_bottom = -8

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

	# Top-middle: boss name and health (hidden until a boss shows up)
	_boss_box = VBoxContainer.new()
	add_child(_boss_box)
	_boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_boss_box.offset_top = 20
	_boss_label = Art.make_label("", 26, Color("ff7675"), 8)
	_boss_box.add_child(_boss_label)
	_boss_bar = HBoxContainer.new()
	_boss_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_boss_box.add_child(_boss_bar)
	_boss_box.visible = false


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.11, 0.22, 0.75)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(12)
	return sb


func _left_label(text: String, font_size: int, color: Color) -> Label:
	var label := Art.make_label(text, font_size, color, 5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label


func set_level(text: String) -> void:
	_level_label.text = text


func set_time(seconds: float) -> void:
	_time_label.text = _format_time(seconds)


func _format_time(seconds: float) -> String:
	var whole := int(seconds)
	return "%d:%02d" % [whole / 60, whole % 60]


# Update the counter and the little sock pictures.
func set_army(army: Array, needed: int) -> void:
	_need = needed
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


# Show which kind of sock the Q key sends.
func set_pick(kind: int) -> void:
	if kind < 0:
		_pick_label.text = "Q sends: AUTO (smart pick)"
		_pick_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		_pick_label.text = "Q sends: %s" % String(SockTypes.DATA[kind]["name"]).to_upper()
		_pick_label.add_theme_color_override("font_color", SockTypes.DATA[kind]["body"].lerp(Color.WHITE, 0.5))


# The boss health bar: one red block per hit left. max_hp 0 hides it.
func set_boss(boss_name: String, hp: int, max_hp: int) -> void:
	_boss_box.visible = max_hp > 0 and hp > 0
	_boss_label.text = boss_name
	for child in _boss_bar.get_children():
		child.queue_free()
	for i in max_hp:
		var block := ColorRect.new()
		block.custom_minimum_size = Vector2(44, 16)
		block.color = Color("d63031") if i < hp else Color(0.16, 0.11, 0.22, 0.7)
		_boss_bar.add_child(block)


func show_message(text: String, seconds := 2.8) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	if _msg_tween and _msg_tween.is_valid():
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_interval(seconds)
	_msg_tween.tween_property(_message, "modulate:a", 0.0, 0.5)


func show_win(count: int, total: int, flawless: bool, stars: int, seconds: float) -> void:
	_message.modulate.a = 0.0
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.2, 0.78)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)

	column.add_child(Art.make_label("YOU ESCAPED DOWN THE DRAIN!", 52, Color("ffd23f"), 10))
	var star_row := StarRow.new()
	star_row.star_size = 30.0
	star_row.stars = stars
	column.add_child(star_row)

	var lines := "Level finished: 1 star\n"
	lines += "Socks saved: %d of %d  %s\n" % [count, total, "(+1 star!)" if count >= total else "(save them ALL for a star)"]
	lines += "Flawless run: %s\n" % ("YES (+1 star!)" if flawless else "no (don't get bonked or soaked for a star)")
	lines += "Time: %s" % _format_time(seconds)
	column.add_child(Art.make_label(lines, 22, Color.WHITE, 5))

	var next := Art.make_button("Next Level" if GameState.has_next() else "The End")
	next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next.pressed.connect(_on_next_pressed)
	column.add_child(next)
	var again := Art.make_button("Play Again")
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(_on_again_pressed)
	column.add_child(again)
	var map := Art.make_button("Level Map")
	map.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	map.pressed.connect(_on_map_pressed)
	column.add_child(map)

	# Fade in. The button only gets "focus" after the fade, so a Space press
	# from your last jump cannot skip this screen by accident.
	dim.modulate.a = 0.0
	center.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(dim, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(center, "modulate:a", 1.0, 0.4)
	tw.tween_callback(next.grab_focus)


func _on_next_pressed() -> void:
	GameState.go_next()


func _on_again_pressed() -> void:
	get_tree().reload_current_scene()


func _on_map_pressed() -> void:
	get_tree().change_scene_to_file(GameState.MAP_SCENE)
