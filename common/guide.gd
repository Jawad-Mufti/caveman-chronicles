class_name Guide
extends CanvasLayer
## A few bright, illustrated pages at the start of a level — what to collect
## and why, what the boss is like, what secrets are out there. Every page can
## be skipped. Shown once per save (the level decides that).
##
## Keys: → / D / Space / Enter / J next, ← / A back, Esc / K skip.
## Mouse and touch: the buttons.
##
## pages: [{title, tag, accent: Color, items: [[icon, heading, words], ...]}]
## icon is a kind the guide knows how to draw (see _icon).

signal done

const INK := Color("f3e3c3")
const WOOD := Color("2b1d14")
const GOLD := Color("f0b44a")

var pages: Array = []
var player: CaveMan
var _page := 0
var _age := 0.0
var _turn := 0.0                ## > 0 just after turning a page: the slide
var _card: Control
var _buttons: Array = []        ## [rect, action]


func _ready() -> void:
	layer = 8
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	add_child(dim)
	_card = Control.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.draw.connect(_draw_card)
	_card.gui_input.connect(_on_click)
	add_child(_card)
	if player != null:
		player.talking = true


func _process(delta: float) -> void:
	_age += delta
	_turn = maxf(_turn - delta, 0.0)
	_card.queue_redraw()


func _go(step: int) -> void:
	var to := _page + step
	if to < 0:
		return
	if to >= pages.size():
		_finish()
		return
	_page = to
	_turn = 0.25


func _finish() -> void:
	if player != null:
		player.talking = false
	done.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or _age < 0.3:
		return
	match (event as InputEventKey).physical_keycode:
		KEY_RIGHT, KEY_D, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_J:
			_go(1)
		KEY_LEFT, KEY_A:
			_go(-1)
		KEY_ESCAPE, KEY_K:
			_finish()
		_:
			return
	get_viewport().set_input_as_handled()


func _on_click(e: InputEvent) -> void:
	var pressed := (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed)
	if not pressed or _age < 0.3:
		return
	var at: Vector2 = e.position
	for b in _buttons:
		if (b[0] as Rect2).has_point(at):
			match String(b[1]):
				"next":
					_go(1)
				"back":
					_go(-1)
				"skip":
					_finish()
			return


## ------------------------------------------------------------------ drawing
func _draw_card() -> void:
	if pages.is_empty():
		return
	var pg: Dictionary = pages[_page]
	var accent: Color = pg["accent"]
	var slide := _turn / 0.25
	var ox := slide * 60.0
	var a := clampf(_age / 0.3, 0.0, 1.0) * (1.0 - slide * 0.6)
	var c := _card
	var box := Rect2(Vector2(130 + ox, 60), Vector2(1020, 600))
	# the card: dark wood, a bright band across the top
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(WOOD, 0.97 * a)
	sb.set_corner_radius_all(20)
	sb.border_color = Color(accent, a)
	sb.set_border_width_all(5)
	sb.shadow_color = Color(0, 0, 0, 0.5 * a)
	sb.shadow_size = 16
	c.draw_style_box(sb, box)
	var band := StyleBoxFlat.new()
	band.bg_color = Color(accent, 0.9 * a)
	band.corner_radius_top_left = 16
	band.corner_radius_top_right = 16
	c.draw_style_box(band, Rect2(box.position + Vector2(5, 5), Vector2(box.size.x - 10, 96)))
	# sparkles dancing in the band
	for i in 9:
		var sx := box.position.x + 60.0 + i * 110.0 + sin(_age * 1.3 + i) * 12.0
		var sy := box.position.y + 30.0 + sin(_age * 2.1 + i * 1.7) * 14.0
		_star(c, Vector2(sx, sy), 4.0 + 2.0 * sin(_age * 3.0 + i), Color(1, 1, 1, 0.35 * a))
	var font := ThemeDB.fallback_font
	c.draw_string(font, box.position + Vector2(40, 64), pg["title"], HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(WOOD, a))
	c.draw_string(font, box.position + Vector2(40, 90), pg["tag"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(WOOD.lightened(0.15), a))
	# the three things on this page, each with its picture
	var items: Array = pg["items"]
	for i in items.size():
		var it: Array = items[i]
		var row := box.position + Vector2(40, 130 + i * 138)
		var bob := sin(_age * 2.2 + i * 1.1) * 4.0
		var disc := row + Vector2(62, 58 + bob)
		c.draw_circle(disc, 56.0, Color(accent, 0.18 * a))
		c.draw_circle(disc, 56.0, Color(accent, 0.5 * a), false, 3.0, true)
		_icon(c, String(it[0]), disc, a)
		c.draw_string(font, row + Vector2(144, 34), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(GOLD, a))
		_wrap(c, font, String(it[2]), row + Vector2(144, 62), 790.0, 19, Color(INK, a))
	# page dots
	for i in pages.size():
		var on := i == _page
		c.draw_circle(Vector2(640 + ox + (i - (pages.size() - 1) * 0.5) * 26.0, box.end.y - 38.0), 7.0 if on else 5.0, Color(accent if on else INK, (1.0 if on else 0.4) * a))
	# the buttons
	_buttons.clear()
	var last := _page == pages.size() - 1
	_button(c, Rect2(box.position + Vector2(36, box.size.y - 66), Vector2(130, 46)), "SKIP", Color(INK, 0.15), Color(INK, a), "skip")
	if _page > 0:
		_button(c, Rect2(box.end - Vector2(420, 66), Vector2(130, 46)), "◀ BACK", Color(INK, 0.15), Color(INK, a), "back")
	var pulse := 0.5 + 0.5 * sin(_age * 4.0)
	_button(c, Rect2(box.end - Vector2(270, 66), Vector2(230, 46)), "LET'S GO!" if last else "NEXT ▶", Color(accent, 0.85 + 0.15 * pulse), Color(WOOD, a), "next")


func _button(c: Control, r: Rect2, text: String, bg: Color, fg: Color, action: String) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(14)
	c.draw_style_box(sb, r)
	c.draw_string(ThemeDB.fallback_font, r.position + Vector2(0, 31), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, fg)
	_buttons.append([r, action])


## Word-wrapped text, since draw_string doesn't wrap.
func _wrap(c: Control, font: Font, text: String, at: Vector2, width: float, size: int, col: Color) -> void:
	var line := ""
	var y := at.y
	for word in text.split(" "):
		var test := word if line == "" else line + " " + word
		if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
			c.draw_string(font, Vector2(at.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
			y += size + 6.0
			line = word
		else:
			line = test
	if line != "":
		c.draw_string(font, Vector2(at.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _star(c: Control, at: Vector2, r: float, col: Color) -> void:
	if r < 1.5:
		return
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r * 0.3, 0), at + Vector2(0, r), at + Vector2(-r * 0.3, 0)]), col)
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-r, 0), at + Vector2(0, r * 0.3), at + Vector2(r, 0), at + Vector2(0, -r * 0.3)]), col)


func _treasure(c: Control, kind: String, at: Vector2, k: float) -> void:
	var b := Batch.new()
	Treasure.shape_into(b, kind, Vector2.ZERO)
	c.draw_set_transform(at, 0.0, Vector2(k, k))
	b.draw(c)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The pictures.
func _icon(c: Control, kind: String, at: Vector2, a: float) -> void:
	match kind:
		"shells":
			_treasure(c, "shell", at + Vector2(-26, 10), 1.3)
			_treasure(c, "conch", at + Vector2(22, 12), 1.2)
			_treasure(c, "amber", at + Vector2(0, -22), 1.2)
		"bones":
			_treasure(c, "tusk", at + Vector2(-4, 10), 1.8)
			_treasure(c, "bone", at + Vector2(10, 20), 1.5)
		"shelter":
			# a Stone Age hut of mammoth bones, hides stretched over it
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(-44, 30), at + Vector2(-30, -8), at + Vector2(0, -30), at + Vector2(30, -8), at + Vector2(44, 30)]), Color("8a6440"))
			for i in 5:
				var x := -36.0 + i * 18.0
				c.draw_arc(at + Vector2(x * 0.5, 34), 30.0 - absf(x) * 0.3, PI * 1.05, PI * 1.95, 12, Color("efe4cc"), 4.0, true)
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(-10, 30), at + Vector2(-8, 8), at + Vector2(8, 8), at + Vector2(10, 30)]), Color("2a1a10"))
			c.draw_circle(at + Vector2(30, 24), 6.0, Color(1.0, 0.7, 0.3, 0.8))
		"health":
			Hud.draw_fig(c, at + Vector2(22, 8), 2.0)
			for g in [Vector2(-6, -8), Vector2(0, -9), Vector2(6, -8), Vector2(-3, -2), Vector2(3, -2), Vector2(0, 4)]:
				var p: Vector2 = at + Vector2(-20, 4) + g * 2.2
				c.draw_circle(p, 9.0, Color("3e1a52"))
				c.draw_circle(p, 7.6, Color("7b3aa0"))
				c.draw_circle(p + Vector2(-2.5, -2.5), 2.5, Color("e6ccf5"))
			c.draw_line(at + Vector2(-20, -24), at + Vector2(-14, -38), Color("6b4a2a"), 3.0, true)
		"scar":
			# a sabre-tooth's face out of the dark, eyes burning
			var fur := Color("b58d58")
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(-40, -10), at + Vector2(-30, -34), at + Vector2(30, -34), at + Vector2(40, -10), at + Vector2(26, 22), at + Vector2(-26, 22)]), fur)
			for e in [Vector2(-34, -30), Vector2(34, -30)]:
				c.draw_colored_polygon(PackedVector2Array([at + e + Vector2(-8, 6), at + e + Vector2(0, -12), at + e + Vector2(8, 6)]), fur.darkened(0.3))
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(-16, 6), at + Vector2(16, 6), at + Vector2(10, 24), at + Vector2(-10, 24)]), Color("e2d0a6"))
			for sx in [-1.0, 1.0]:
				c.draw_circle(at + Vector2(sx * 16, -12), 6.0, Color(1.0, 0.7, 0.2))
				c.draw_circle(at + Vector2(sx * 16, -12), 2.5, Color("2a1a10"))
			c.draw_line(at + Vector2(-26, -24), at + Vector2(-8, 0), Color("e2d0a6"), 3.0, true)
			for sx in [-1.0, 1.0]:
				c.draw_colored_polygon(PackedVector2Array([at + Vector2(sx * 8 - 3, 20), at + Vector2(sx * 8 + 3, 20), at + Vector2(sx * 8, 50)]), Color("f4efe2"))
			c.draw_circle(at + Vector2(0, 4), 5.0, Color("2a1a10"))
		"torch":
			Shop.draw_icon(c, "torch", at, 1.0)
			for i in 2:
				c.draw_arc(at + Vector2(6, -30), 14.0 + i * 8.0, -2.2, -0.9, 10, Color(1.0, 0.75, 0.3, 0.35 - i * 0.1), 3.0, true)
		"tricks":
			# eyes in the dark, and a rock flying at an open jaw
			c.draw_circle(at, 44.0, Color(0.05, 0.05, 0.08))
			for e in [Vector2(-22, -8), Vector2(22, -8)]:
				c.draw_circle(at + e + Vector2(-6, 0), 4.0, Color(1.0, 0.75, 0.3))
				c.draw_circle(at + e + Vector2(6, 0), 4.0, Color(1.0, 0.75, 0.3))
			c.draw_circle(at + Vector2(-30, 26), 9.0, Color("8a8378"))
			c.draw_line(at + Vector2(-44, 36), at + Vector2(-34, 30), Color(1, 1, 1, 0.4), 2.0, true)
			c.draw_string(ThemeDB.fallback_font, at + Vector2(-8, 36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, 0.8))
		"gem":
			var g := 0.6 + 0.4 * sin(_age * 3.0)
			c.draw_circle(at, 36.0 + g * 6.0, Color(Pal.EMBER_GLOW, 0.35 * g))
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -30), at + Vector2(24, -6), at + Vector2(0, 30), at + Vector2(-24, -6)]), Pal.GEM)
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -30), at + Vector2(24, -6), at + Vector2(0, -6)]), Pal.GEM_LIGHT)
			_star(c, at + Vector2(16, -22), 8.0 * g, Color(1, 1, 1, g))
		"hammer", "axe", "club":
			Shop.draw_icon(c, kind, at, 0.9)
		"weapons":
			Shop.draw_icon(c, "club", at + Vector2(-20, 6), 0.55)
			Shop.draw_icon(c, "axe", at + Vector2(18, 0), 0.55)
		_:
			c.draw_circle(at, 20.0, Color(INK, a))
