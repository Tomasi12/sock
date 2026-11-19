# world_map.gd
# The level select screen: 4 worlds, 6 buttons each (5 levels + a boss).
# A level unlocks when you finish the one before it.
extends Control

const Art = preload("res://scripts/art.gd")
const StarRow = preload("res://scripts/star_row.gd")


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("341f97")
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	center.add_child(column)

	column.add_child(Art.make_label("Choose a level", 36, Color("ffd23f"), 9))
	var max_stars: int = GameState.levels.size() * 3
	column.add_child(Art.make_label("Stars: %d / %d" % [GameState.total_stars(), max_stars], 20, Color.WHITE, 5))

	var focus_button: Button = null
	var row: HBoxContainer = null
	var last_world := -1
	for i in GameState.levels.size():
		var level: Dictionary = GameState.levels[i]
		if level["world"] != last_world:
			# a new world starts: title + a new row of buttons
			last_world = level["world"]
			column.add_child(Art.make_label(GameState.WORLD_NAMES[last_world], 20, Color("b8b0ff"), 5))
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 10)
			column.add_child(row)

		var cell := VBoxContainer.new()
		row.add_child(cell)
		var unlocked: bool = GameState.is_unlocked(i)
		var is_boss: bool = not level["boss"].is_empty()
		var text: String = level["id"] + "\n" + String(level["name"]).replace("FINAL BOSS: ", "").replace("BOSS: ", "")
		var button := Art.make_button(text if unlocked else level["id"] + "\nLocked")
		button.custom_minimum_size = Vector2(176, 58)
		button.add_theme_font_size_override("font_size", 15)
		if is_boss:
			button.get_theme_stylebox("normal").bg_color = Color("d63031")
		button.disabled = not unlocked
		if not unlocked:
			button.modulate.a = 0.45
		button.pressed.connect(_on_level_pressed.bind(i))
		cell.add_child(button)
		var stars := StarRow.new()
		stars.star_size = 7.0
		stars.stars = GameState.stars_for(i)
		cell.add_child(stars)
		if unlocked:
			focus_button = button # ends up being the newest unlocked level

	var back := Art.make_button("Back to Menu")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size = Vector2(220, 42)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_on_back_pressed)
	column.add_child(back)

	if focus_button != null:
		focus_button.grab_focus()


func _on_level_pressed(index: int) -> void:
	Sfx.play("click")
	GameState.go_to_level(index)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(GameState.MENU_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
