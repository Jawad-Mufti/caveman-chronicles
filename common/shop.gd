class_name Shop
extends CanvasLayer
## A trader's shop, over the game. Three tabs — WEAPONS, COSTUMES, SUPPLIES —
## each a grid of cards with a picture, a name and a price in shells. On the
## right, a firelit stage where he stands wearing (or holding) whatever card is
## chosen, so you see it before you buy. Everything bought or put on is saved
## at once.
##
## Keys: arrows choose, Q / E (or Tab) change tabs, Space / J / Enter buys or
## puts it on, Esc / K leaves. Mouse and touch: tap a tab, tap a card, tap the
## big button.
##
## The level supplies the wares and decides what buying does:
##   list_items() -> [{id, tab, name, desc, icon, price, status, can, skin, weapon}]
##     status: "buy" | "equip" | "on" | "maxed" | "locked"
##     note: a short line for locked or special wares ("Needs a Firestone")
##   buy(id) -> String: what happened

signal closed

const TABS := [["weapons", "WEAPONS"], ["costumes", "COSTUMES"], ["supplies", "SUPPLIES"]]
const INK := Color("f3e3c3")
const GOLD := Color("f0b44a")
const WOOD := Color("2b1d14")
const CARD := Color("3a2819")
const CARD_ON := Color("4d3521")

var title := "THE TOOLMAKER'S TRADE"
var player: CaveMan
var list_items: Callable
var buy: Callable

var _tab := 0
var _sel := 0
var _items: Array = []
var _age := 0.0
var _saved := 0.0
var _cards: Array = []
var _grid: Control
var _tabs: Array = []
var _pouch: Control
var _name: Label
var _desc: Label
var _msg: Label
var _button: Control
var _stage: Control
var _man: CaveMan


func _ready() -> void:
	layer = 6
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(60, 34)
	panel.size = Vector2(1160, 652)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(WOOD, 0.97)
	sb.border_color = GOLD.darkened(0.2)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 12
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var head := _label(title, Vector2(96, 50), Vector2(600, 40), 30, GOLD)
	head.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	add_child(head)
	_pouch = Control.new()
	_pouch.position = Vector2(1010, 50)
	_pouch.size = Vector2(190, 40)
	_pouch.draw.connect(_draw_pouch)
	add_child(_pouch)
	for i in TABS.size():
		var tab := Control.new()
		tab.position = Vector2(96 + i * 206, 104)
		tab.size = Vector2(196, 46)
		tab.mouse_filter = Control.MOUSE_FILTER_STOP
		tab.draw.connect(_draw_tab.bind(tab, i))
		tab.gui_input.connect(_tab_input.bind(i))
		add_child(tab)
		_tabs.append(tab)
	_grid = Control.new()
	_grid.position = Vector2(96, 166)
	_grid.size = Vector2(620, 420)
	add_child(_grid)
	# the stage: firelight, a stone floor, and him
	_stage = Control.new()
	_stage.position = Vector2(740, 104)
	_stage.size = Vector2(444, 300)
	_stage.draw.connect(_draw_stage)
	add_child(_stage)
	_man = CaveMan.new()
	_man.preview = true
	_man.position = Vector2(962, 382)
	_man.scale = Vector2(2.3, 2.3)
	add_child(_man)
	_name = _label("", Vector2(740, 414), Vector2(444, 36), 26, GOLD)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name)
	_desc = _label("", Vector2(752, 452), Vector2(420, 96), 17, INK)
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_desc)
	_button = Control.new()
	_button.position = Vector2(822, 560)
	_button.size = Vector2(280, 56)
	_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_button.draw.connect(_draw_button)
	_button.gui_input.connect(func(e: InputEvent) -> void:
		if _pressed(e):
			_act())
	add_child(_button)
	_msg = _label("", Vector2(96, 604), Vector2(620, 30), 18, INK)
	add_child(_msg)
	var hint := _label("←→↑↓ choose     Q / E  tabs     SPACE  buy / put on     ESC  leave", Vector2(96, 640), Vector2(760, 26), 15, Color(INK, 0.55))
	add_child(hint)
	if player != null:
		player.talking = true
		_man.skin = player.skin
		_man.axe = player.axe
		_man.hammer = player.hammer
	_rebuild()


func _label(text: String, at: Vector2, size: Vector2, font: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	l.size = size
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", col)
	return l


func _pressed(e: InputEvent) -> bool:
	return (e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
		or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed)


## ------------------------------------------------------------------ building
func _rebuild() -> void:
	var all: Array = list_items.call() if list_items.is_valid() else []
	var tab_id: String = TABS[_tab][0]
	_items = all.filter(func(w: Dictionary) -> bool: return w["tab"] == tab_id)
	_sel = clampi(_sel, 0, maxi(_items.size() - 1, 0))
	for c in _cards:
		c.queue_free()
	_cards.clear()
	var tall := _items.size() <= 6
	var ch := 196.0 if tall else 128.0
	for i in _items.size():
		var card := Control.new()
		card.position = Vector2((i % 3) * 208, (i / 3) * (ch + 12.0))
		card.size = Vector2(196, ch)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.draw.connect(_draw_card.bind(card, i))
		card.gui_input.connect(_card_input.bind(i))
		_grid.add_child(card)
		_cards.append(card)
	for t in _tabs:
		(t as Control).queue_redraw()
	_pouch.queue_redraw()
	_show()


## The chosen card: its name and words, and him on the stage wearing it.
func _show() -> void:
	for c in _cards:
		(c as Control).queue_redraw()
	_button.queue_redraw()
	if _items.is_empty():
		_name.text = ""
		_desc.text = ""
		return
	var w: Dictionary = _items[_sel]
	_name.text = w["name"]
	_desc.text = w["desc"]
	if player != null:
		_man.skin = w["skin"] if w.get("skin", "") != "" else player.skin
		var wp: String = w.get("weapon", "")
		if wp == "":
			wp = "hammer" if player.hammer else ("axe" if player.axe else "club")
		_man.axe = wp == "axe"
		_man.hammer = wp == "hammer"


## ------------------------------------------------------------------- acting
func _act() -> void:
	if _items.is_empty() or _age < 0.3:
		return
	var w: Dictionary = _items[_sel]
	if not w["can"]:
		_msg.text = w.get("note", "") if w["status"] == "locked" else ("Not enough shells." if w["status"] == "buy" else "")
		return
	var said: String = buy.call(w["id"])
	_msg.text = said
	_saved = 2.0
	if is_inside_tree():
		_rebuild()


func _card_input(e: InputEvent, i: int) -> void:
	if _pressed(e):
		if _sel == i:
			_act()
		else:
			_sel = i
			_show()


func _tab_input(e: InputEvent, i: int) -> void:
	if _pressed(e):
		_tab = i
		_sel = 0
		_rebuild()


func _process(delta: float) -> void:
	_age += delta
	_saved = maxf(_saved - delta, 0.0)
	_stage.queue_redraw()
	if _saved > 0.0:
		_pouch.queue_redraw()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := (event as InputEventKey).physical_keycode
	var cols := 3
	match k:
		KEY_LEFT, KEY_A:
			_sel = maxi(_sel - 1, 0)
			_show()
		KEY_RIGHT, KEY_D:
			_sel = mini(_sel + 1, _items.size() - 1)
			_show()
		KEY_UP, KEY_W:
			_sel = maxi(_sel - cols, 0)
			_show()
		KEY_DOWN, KEY_S:
			_sel = mini(_sel + cols, _items.size() - 1)
			_show()
		KEY_Q:
			_tab = (_tab + TABS.size() - 1) % TABS.size()
			_sel = 0
			_rebuild()
		KEY_E, KEY_TAB:
			_tab = (_tab + 1) % TABS.size()
			_sel = 0
			_rebuild()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_J:
			_act()
		KEY_ESCAPE, KEY_K:
			_close()
		_:
			return
	get_viewport().set_input_as_handled()


func _close() -> void:
	if _age < 0.3:
		return
	if player != null:
		player.talking = false
	closed.emit()
	queue_free()


## ------------------------------------------------------------------ drawing
func _draw_pouch() -> void:
	var b := Batch.new()
	Treasure.shape_into(b, "shell", Vector2.ZERO)
	_pouch.draw_set_transform(Vector2(22, 20), 0.0, Vector2(1.2, 1.2))
	b.draw(_pouch)
	_pouch.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_pouch.draw_string(ThemeDB.fallback_font, Vector2(48, 30), str(GameState.shells), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, INK)
	if _saved > 0.0:
		_pouch.draw_string(ThemeDB.fallback_font, Vector2(-80, 30), "✓ Saved", HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			Color("9fdc8a", clampf(_saved, 0.0, 1.0)))


func _draw_tab(tab: Control, i: int) -> void:
	var on := i == _tab
	var r := Rect2(Vector2.ZERO, tab.size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = GOLD if on else CARD
	sb.set_corner_radius_all(10)
	sb.border_color = GOLD
	sb.set_border_width_all(0 if on else 2)
	tab.draw_style_box(sb, r)
	var icon: String = ["axe", "wolf_hood", "fig"][i]
	Shop.draw_icon(tab, icon, Vector2(30, 24), 0.36)
	tab.draw_string(ThemeDB.fallback_font, Vector2(58, 31), TABS[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, WOOD if on else GOLD)


func _draw_card(card: Control, i: int) -> void:
	if i >= _items.size():
		return
	var w: Dictionary = _items[i]
	var on := i == _sel
	var r := Rect2(Vector2.ZERO, card.size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_ON if on else CARD
	sb.set_corner_radius_all(12)
	sb.border_color = GOLD if on else Color(GOLD, 0.25)
	sb.set_border_width_all(4 if on else 2)
	if on:
		sb.shadow_color = Color(GOLD, 0.35)
		sb.shadow_size = 8
	card.draw_style_box(sb, r)
	var tall := card.size.y > 150.0
	var icon_at := Vector2(card.size.x * 0.5, 70.0 if tall else 44.0)
	# a warm glow behind the picture of the chosen one
	if on:
		card.draw_circle(icon_at, 52.0 if tall else 36.0, Color(GOLD, 0.12))
	Shop.draw_icon(card, w["icon"], icon_at, 1.0 if tall else 0.7)
	var name_y := 148.0 if tall else 92.0
	card.draw_string(ThemeDB.fallback_font, Vector2(0, name_y), w["name"], HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 18, INK)
	# price, or a badge
	var bottom := card.size.y - 18.0
	match String(w["status"]):
		"buy":
			var price: int = w["price"]
			if price <= 0:
				_pill(card, bottom, w.get("note", "FREE"), Color("7a3a8a"), INK)
			else:
				var ok: bool = w["can"]
				var b := Batch.new()
				Treasure.shape_into(b, "shell", Vector2.ZERO)
				var tw := ThemeDB.fallback_font.get_string_size(str(price), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
				var x0 := card.size.x * 0.5 - (tw + 30.0) * 0.5
				card.draw_set_transform(Vector2(x0 + 11.0, bottom - 6.0), 0.0, Vector2(0.8, 0.8))
				b.draw(card)
				card.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				card.draw_string(ThemeDB.fallback_font, Vector2(x0 + 28.0, bottom + 1.0), str(price), HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
					GOLD if ok else Color("d9776a"))
		"equip":
			_pill(card, bottom, "OWNED", Color("3c5a3a"), Color("c8f0b8"))
		"on":
			_pill(card, bottom, "✓ " + String(w.get("note", "IN USE")), Color("2e6b3a"), Color("dfffd0"))
		"maxed":
			_pill(card, bottom, String(w.get("note", "MAX")), Color("4a3a2a"), Color(INK, 0.7))
		"locked":
			_pill(card, bottom, String(w.get("note", "LOCKED")), Color("3a2a2a"), Color("d9a08a"))


func _pill(c: Control, y: float, text: String, bg: Color, fg: Color) -> void:
	var tw := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var r := Rect2(c.size.x * 0.5 - tw * 0.5 - 12.0, y - 16.0, tw + 24.0, 24.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(12)
	c.draw_style_box(sb, r)
	c.draw_string(ThemeDB.fallback_font, Vector2(r.position.x + 12.0, y + 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, fg)


func _draw_stage() -> void:
	var r := Rect2(Vector2.ZERO, _stage.size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1a120c")
	sb.set_corner_radius_all(14)
	sb.border_color = Color(GOLD, 0.35)
	sb.set_border_width_all(2)
	_stage.draw_style_box(sb, r)
	# firelight flickering on the rock behind him
	var flick := 0.85 + 0.15 * sin(_age * 7.0) * sin(_age * 3.1)
	for k in 5:
		_stage.draw_circle(Vector2(222, 170), 170.0 - k * 30.0, Color(1.0, 0.6, 0.25, 0.05 * flick))
	# the stone floor he stands on
	_stage.draw_rect(Rect2(14, 276, 416, 14), Color("3b3128"))
	_stage.draw_rect(Rect2(14, 276, 416, 4), Color("5a4a3a"))


func _draw_button() -> void:
	var r := Rect2(Vector2.ZERO, _button.size)
	if _items.is_empty():
		return
	var w: Dictionary = _items[_sel]
	var text := ""
	var bg := GOLD
	var fg := WOOD
	match String(w["status"]):
		"buy":
			var price: int = w["price"]
			text = "BUY  %d" % price if price > 0 else String(w.get("note", "TAKE IT"))
			if price <= 0 and w.get("note", "") != "":
				text = "FORGE IT" if w["id"] == "hammer" else "TAKE IT"
			if not w["can"]:
				bg = Color("4a3a2e")
				fg = Color("d9776a")
				text = "NOT ENOUGH SHELLS"
		"equip":
			text = "CARRY IT" if w["tab"] == "weapons" else "PUT IT ON"
		"on":
			text = "✓  " + String(w.get("note", "IN USE"))
			bg = Color("2e6b3a")
			fg = Color("dfffd0")
		"maxed":
			text = String(w.get("note", "MAX"))
			bg = Color("4a3a2a")
			fg = Color(INK, 0.7)
		"locked":
			text = String(w.get("note", "LOCKED"))
			bg = Color("3a2a2a")
			fg = Color("d9a08a")
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(14)
	if String(w["status"]) in ["buy", "equip"] and w["can"]:
		sb.shadow_color = Color(GOLD, 0.35 + 0.15 * sin(_age * 4.0))
		sb.shadow_size = 10
	_button.draw_style_box(sb, r)
	_button.draw_string(ThemeDB.fallback_font, Vector2(0, 36), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, fg)


## ------------------------------------------------------------------- pictures
## A picture for each kind of ware, centred on `at`, about 100 px across at k = 1.
static func draw_icon(c: CanvasItem, kind: String, at: Vector2, k: float) -> void:
	var p := func(v: Vector2) -> Vector2: return at + v * k
	var line := func(a: Vector2, b: Vector2, col: Color, w: float) -> void: c.draw_line(p.call(a), p.call(b), col, w * k, true)
	var poly := func(pts: Array, col: Color) -> void:
		var arr := PackedVector2Array()
		for v in pts:
			arr.append(p.call(v))
		c.draw_colored_polygon(arr, col)
	match kind:
		"club":
			line.call(Vector2(-34, 34), Vector2(14, -14), Color("3a2a18"), 14.0)
			line.call(Vector2(-34, 34), Vector2(14, -14), Color("a07a4a"), 9.0)
			c.draw_circle(p.call(Vector2(20, -20)), 20.0 * k, Color("3a2a18"))
			c.draw_circle(p.call(Vector2(20, -20)), 16.0 * k, Color("a07a4a"))
			c.draw_circle(p.call(Vector2(14, -26)), 5.0 * k, Color("c49a64"))
		"axe":
			line.call(Vector2(-34, 38), Vector2(22, -30), Color("3a2a18"), 13.0)
			line.call(Vector2(-34, 38), Vector2(22, -30), Color("c49a64"), 8.0)
			poly.call([Vector2(10, -24), Vector2(6, -46), Vector2(36, -44), Vector2(44, -12), Vector2(22, -8)], Color("3d4650"))
			poly.call([Vector2(12, -24), Vector2(10, -42), Vector2(34, -40), Vector2(40, -14), Vector2(22, -10)], Color("6f7f8f"))
			poly.call([Vector2(18, -30), Vector2(30, -38), Vector2(26, -22)], Color("9fb0bf"))
			line.call(Vector2(34, -40), Vector2(40, -14), Color("d9e4ee"), 3.0)
			for i in 3:
				line.call(Vector2(8 + i * 3, -14 - i * 5), Vector2(20 + i * 3, -24 - i * 5), Color("6b4a2a"), 3.0)
		"hammer":
			line.call(Vector2(-36, 40), Vector2(12, -12), Color("3a2a18"), 14.0)
			line.call(Vector2(-36, 40), Vector2(12, -12), Color("c49a64"), 9.0)
			poly.call([Vector2(-2, -48), Vector2(46, -8), Vector2(30, 10), Vector2(-18, -30)], Color("3d3831"))
			poly.call([Vector2(0, -44), Vector2(42, -8), Vector2(30, 5), Vector2(-14, -30)], Color("8a8378"))
			c.draw_circle(p.call(Vector2(14, -20)), 16.0 * k, Color(Pal.EMBER_GLOW, 0.5))
			poly.call([Vector2(14, -32), Vector2(26, -20), Vector2(14, -8), Vector2(2, -20)], Pal.GEM)
			poly.call([Vector2(14, -32), Vector2(26, -20), Vector2(14, -20)], Pal.GEM_LIGHT)
		"plain":
			poly.call([Vector2(-30, -10), Vector2(30, -10), Vector2(24, 30), Vector2(-24, 30)], Pal.HIDE)
			line.call(Vector2(-32, -10), Vector2(32, -10), Pal.VINE, 7.0)
			for i in 4:
				c.draw_circle(p.call(Vector2(-14 + i * 10, 10 + (i % 2) * 8)), 3.0 * k, Pal.HIDE_DARK)
		"wolf_hood":
			poly.call([Vector2(-34, 14), Vector2(-30, -16), Vector2(-10, -30), Vector2(20, -28), Vector2(40, -12), Vector2(46, 4), Vector2(20, 10), Vector2(-6, 22)], Pal.WOLF)
			poly.call([Vector2(-26, -18), Vector2(-20, -50), Vector2(-6, -26)], Pal.WOLF_DARK)
			poly.call([Vector2(0, -28), Vector2(10, -56), Vector2(18, -28)], Pal.WOLF_DARK)
			poly.call([Vector2(22, -6), Vector2(46, 4), Vector2(22, 8)], Pal.WOLF_BELLY)
			c.draw_circle(p.call(Vector2(46, 2)), 4.0 * k, Pal.OUTLINE)
			c.draw_circle(p.call(Vector2(12, -12)), 4.0 * k, Pal.WOLF_EYE)
			for i in 3:
				poly.call([Vector2(26 + i * 6, 8), Vector2(30 + i * 6, 8), Vector2(28 + i * 6, 16)], Color("f4efe2"))
		"ember_paint":
			for f in [[-24.0, 40.0], [0.0, 56.0], [24.0, 40.0]]:
				var x: float = f[0]
				var h: float = f[1]
				poly.call([Vector2(x - 11, 30), Vector2(x - 6, 30 - h * 0.5), Vector2(x - 1, 30 - h), Vector2(x + 3, 30 - h * 0.6),
					Vector2(x + 6, 30 - h * 0.75), Vector2(x + 11, 30)], Color("d9822b"))
				poly.call([Vector2(x - 5, 30), Vector2(x - 1, 30 - h * 0.6), Vector2(x + 5, 30)], Color("f3c14f"))
			c.draw_rect(Rect2(p.call(Vector2(-40, 32)), Vector2(80, 10) * k), Color(0.12, 0.08, 0.06, 0.9))
		"bear_cloak":
			poly.call([Vector2(-40, 30), Vector2(-36, -8), Vector2(-16, -32), Vector2(16, -32), Vector2(36, -8), Vector2(40, 30)], Color("6b4a2e"))
			for e in [Vector2(-26, -30), Vector2(26, -30)]:
				c.draw_circle(p.call(e), 13.0 * k, Color("6b4a2e"))
				c.draw_circle(p.call(e), 6.0 * k, Color("45301c"))
			c.draw_circle(p.call(Vector2(0, 2)), 16.0 * k, Color("8a6440"))
			c.draw_circle(p.call(Vector2(0, 8)), 5.0 * k, Pal.OUTLINE)
			for cx in [-8.0, 8.0]:
				poly.call([Vector2(cx - 4, 22), Vector2(cx + 4, 22), Vector2(cx + 1, 40)], Color("efe6d2"))
		"firekeeper":
			line.call(Vector2(-40, 0), Vector2(40, -4), Color("3a2a18"), 14.0)
			line.call(Vector2(-40, 0), Vector2(40, -4), Color("a0703c"), 9.0)
			c.draw_circle(p.call(Vector2(20, -3)), 20.0 * k, Color(Pal.EMBER_GLOW, 0.4))
			c.draw_circle(p.call(Vector2(20, -3)), 9.0 * k, Color("ffb347"))
			c.draw_circle(p.call(Vector2(18, -5)), 4.0 * k, Color("fff0b0"))
			poly.call([Vector2(-30, -2), Vector2(-44, -46), Vector2(-34, -44), Vector2(-24, -4)], Color("e8e0cc"))
			poly.call([Vector2(-20, -3), Vector2(-28, -40), Vector2(-20, -38), Vector2(-14, -4)], Color("c0392b"))
		"fig":
			Hud.draw_fig(c, at, 2.6 * k)
		"heart":
			var hr := 16.0 * k
			c.draw_circle(p.call(Vector2(-11, -6)), hr, Color("e04a5a"))
			c.draw_circle(p.call(Vector2(11, -6)), hr, Color("e04a5a"))
			poly.call([Vector2(-27, 0), Vector2(27, 0), Vector2(0, 32)], Color("e04a5a"))
			c.draw_circle(p.call(Vector2(-14, -12)), 5.0 * k, Color("ffb0b8"))
		"torch":
			line.call(Vector2(-10, 40), Vector2(8, -10), Color("6a4a2a"), 10.0)
			for i in 3:
				line.call(Vector2(2 + i * 2, -2 - i * 6), Vector2(14 + i * 2, -6 - i * 6), Color("c49a64"), 4.0)
			poly.call([Vector2(-4, -12), Vector2(6, -52), Vector2(20, -14)], Color("f08a24"))
			poly.call([Vector2(2, -14), Vector2(8, -38), Vector2(14, -14)], Color("ffd36b"))
		"pouch":
			poly.call([Vector2(-28, -8), Vector2(28, -8), Vector2(32, 28), Vector2(0, 38), Vector2(-32, 28)], Color("8a5a2c"))
			poly.call([Vector2(-24, -8), Vector2(24, -8), Vector2(16, -24), Vector2(-16, -24)], Color("a8743c"))
			line.call(Vector2(-18, -10), Vector2(18, -10), Pal.VINE, 5.0)
			c.draw_circle(p.call(Vector2(0, 12)), 7.0 * k, Color("f2dcc0"))
		_:
			c.draw_circle(at, 20.0 * k, INK)
