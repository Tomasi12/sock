# art.gd
# Helper functions that make "art" with code: textures, particle effects,
# shapes and styled UI. Every function is "static", which means you call it
# straight on the script:  Art.burst(...)  (no need to create an object).
extends RefCounted

const OUTLINE := Color(0.16, 0.11, 0.22)

# We remember the textures after making them once (making images is slow).
static var _soft_circle: Texture2D
static var _bubble: Texture2D


# A white dot that fades out at the edges. Used by most particles.
static func soft_circle() -> Texture2D:
	if _soft_circle == null:
		var size := 32
		var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
		var center := Vector2(size, size) / 2.0
		for y in size:
			for x in size:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(center) / (size / 2.0)
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a))
		_soft_circle = ImageTexture.create_from_image(img)
	return _soft_circle


# A soap bubble: see-through middle, bright edge, and a shiny spot.
static func bubble_texture() -> Texture2D:
	if _bubble == null:
		var size := 48
		var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
		var center := Vector2(size, size) / 2.0
		var shine := Vector2(size * 0.34, size * 0.3)
		for y in size:
			for x in size:
				var p := Vector2(x + 0.5, y + 0.5)
				var d := p.distance_to(center) / (size / 2.0 - 1.0)
				var a := 0.0
				if d <= 1.0:
					a = 0.1 + pow(d, 6.0) * 0.85
				var s := p.distance_to(shine) / size
				if s < 0.1:
					a = maxf(a, 0.95 * (1.0 - s / 0.1))
				img.set_pixel(x, y, Color(0.9, 0.97, 1.0, a))
		_bubble = ImageTexture.create_from_image(img)
	return _bubble


# A list of points shaped like an ellipse (a squashed circle).
static func ellipse(center: Vector2, rx: float, ry: float, segments := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var angle := TAU * i / segments
		pts.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return pts


# A colour fade: invisible -> visible -> invisible. Particles use it so they
# appear softly and disappear softly.
static func fade_gradient() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.15, Color(1, 1, 1, 1))
	g.add_point(0.75, Color(1, 1, 1, 1))
	return g


# A quick "poof" of particles (dust, splash, sparkles...).
# It deletes itself after a second.
static func burst(parent: Node, pos: Vector2, color: Color, amount := 12, speed := 120.0, size := 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.texture = soft_circle()
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.6
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 300)
	p.scale_amount_min = 0.2 * size
	p.scale_amount_max = 0.5 * size
	p.color = color
	p.color_ramp = fade_gradient()
	p.z_index = 6
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(1.2).timeout.connect(p.queue_free)


# Bubbles that rise forever from a wide line (background decoration).
static func make_bubble_particles(width: float, amount: int) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = bubble_texture()
	p.amount = amount
	p.lifetime = 10.0
	p.preprocess = 10.0 # start "already running" so the screen is not empty
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(width / 2.0, 10.0)
	p.direction = Vector2.UP
	p.spread = 12.0
	p.gravity = Vector2(0, -8)
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 65.0
	p.tangential_accel_min = -6.0
	p.tangential_accel_max = 6.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.9
	p.color_ramp = fade_gradient()
	return p


# A Label with big outlined text (titles, signs, messages).
static func make_label(text: String, font_size: int, color: Color, outline := 8) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", outline)
	return l


# A big round cartoon button.
static func make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 64)
	b.add_theme_font_size_override("font_size", 32)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", OUTLINE)
	b.add_theme_constant_override("outline_size", 6)
	var looks := {
		"normal": Color("ff7675"),
		"hover": Color("fd79a8"),
		"pressed": Color("e84393"),
		"focus": Color(0, 0, 0, 0), # focus is drawn on top: only a yellow border
	}
	for state_name in looks:
		var sb := StyleBoxFlat.new()
		sb.bg_color = looks[state_name]
		sb.set_corner_radius_all(20)
		sb.set_border_width_all(4)
		sb.border_color = Color("ffd23f") if state_name == "focus" else OUTLINE
		b.add_theme_stylebox_override(state_name, sb)
	return b
