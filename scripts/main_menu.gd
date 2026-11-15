# main_menu.gd
# The first screen: big title, Play / Quit buttons, and dancing socks.
extends Control

const Art = preload("res://scripts/art.gd")
const SockBody = preload("res://scripts/sock_body.gd")



func _ready() -> void:
	var screen := get_viewport_rect().size

	# 1) A background colour that fills the screen
	var bg := ColorRect.new()
	bg.color = Color("6c5ce7")
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 2) Bubbles rising behind everything
	var bubbles := Art.make_bubble_particles(screen.x, 40)
	bubbles.position = Vector2(screen.x / 2.0, screen.y + 30.0)
	add_child(bubbles)

	# 3) Four dancing socks at the bottom (one of each kind)
	for i in 4:
		var holder := Node2D.new()
		holder.position = Vector2(screen.x * (0.2 + i * 0.2), screen.y - 40.0)
		holder.scale = Vector2(2.5, 2.5) # make them big
		add_child(holder)
		var sock := SockBody.new()
		sock.kind = i
		sock.facing = 1.0 if i % 2 == 0 else -1.0
		holder.add_child(sock)
		_make_dance(sock, i * 0.15)

	# 4) Title and buttons, centred with a CenterContainer
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -170 # leave room for the dancing socks
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)

	var title := Art.make_label("The Last Sock", 96, Color("ffd23f"), 14)
	column.add_child(title)
	column.add_child(Art.make_label("A tale of rebellion, lint and laundry", 26, Color.WHITE, 6))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	column.add_child(spacer)

	var play := Art.make_button("Play")
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(_on_play_pressed)
	column.add_child(play)

	var quit := Art.make_button("Quit")
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit.pressed.connect(_on_quit_pressed)
	column.add_child(quit)

	play.grab_focus() # so Enter/Space works without the mouse

	# The title gently bobs up and down forever
	title.pivot_offset = Vector2(300, 50)
	var tw := create_tween().set_loops()
	tw.tween_property(title, "rotation", 0.04, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(title, "rotation", -0.04, 1.2).set_trans(Tween.TRANS_SINE)


# Hop up, fall down, squish, repeat. set_loops() = repeat forever.
func _make_dance(sock: Node2D, delay: float) -> void:
	var tw := sock.create_tween().set_loops()
	tw.tween_interval(0.2 + delay)
	tw.tween_callback(sock.squash.bind(Vector2(0.7, 1.35), 0.3))
	tw.tween_property(sock, "position:y", -30.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sock, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(sock.squash.bind(Vector2(1.35, 0.7), 0.4))
	tw.tween_interval(0.6 - delay)


func _on_play_pressed() -> void:
	Sfx.play("click")
	# The first time, show the story. After that, go straight to the level map.
	if GameState.seen_intro:
		get_tree().change_scene_to_file(GameState.MAP_SCENE)
	else:
		get_tree().change_scene_to_file(GameState.STORY_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
