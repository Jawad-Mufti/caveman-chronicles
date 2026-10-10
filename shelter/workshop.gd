extends CanvasLayer
## THE WORKSHOP (the home's work table, shelter/home.gd): a window like the
## table itself. Planks of wood, on them a leather mat with everything in his
## BAG (each thing in a box: its picture, how many, its rarity's colour; point
## at one: what it is and what it is for), and a stone slab with what he can
## MAKE here: things for his cave (Bag.HOME_RECIPES; for now the OBSIDIAN
## MIRROR). Each is a card: its picture, what it is, what it needs (have /
## need, green when there is enough), and a MAKE button; made, a stamp.
##   Mouse: point and click.   Up / Down: a card.   E / Enter: MAKE.   Esc: close.

signal closed
signal made(id: String)
signal refused                                  ## MAKE without enough

var rig: CaveMan                                ## his 2D rig (what Bag asks about him)
var sel := 0                                    ## the chosen card
var _board: WorkshopBoard
var _note := ""                                 ## a line under the cards: made / what's missing
var _note_ok := true
var _note_t := 0.0


func _ready() -> void:
	layer = 5
	_board = WorkshopBoard.new()
	_board.ws = self
	_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_board)


## The recipes made here.
func recipes() -> Array:
	return Bag.HOME_RECIPES.filter(func(r: Array) -> bool: return Bag.recipe_open(r[0]))


## MAKE: true if it was made.
func make(id: String) -> bool:
	var miss := Bag.missing(rig, id)
	if miss != "":
		_say(miss, false)
		_board.shake = 0.35
		refused.emit()
		return false
	Bag.craft(rig, id)
	_board.burst = 1.6
	_say("Rub, rub, rub... the %s is READY! It stands in your cave, by the back wall: go and look!" % Bag.name_of(id) if id == "mirror" else "Made: %s!" % Bag.name_of(id), true)
	made.emit(id)
	return true


func close() -> void:
	closed.emit()
	queue_free()


func _say(s: String, ok: bool) -> void:
	_note = s
	_note_ok = ok
	_note_t = 5.0


func _process(delta: float) -> void:
	_note_t = maxf(_note_t - delta, 0.0)


func _input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed) or e.is_echo():
		return
	var rs := recipes()
	match (e as InputEventKey).physical_keycode:
		KEY_UP, KEY_W:
			sel = posmod(sel - 1, maxi(rs.size(), 1))
		KEY_DOWN, KEY_S:
			sel = posmod(sel + 1, maxi(rs.size(), 1))
		KEY_E, KEY_J, KEY_ENTER, KEY_SPACE:
			if not rs.is_empty():
				make(rs[sel][0])
		KEY_ESCAPE, KEY_Q:
			close()
	get_viewport().set_input_as_handled()


## ------------------------------------------------------------------ the window, drawn
class WorkshopBoard extends Control:
	const BOARD := Rect2(80, 56, 1120, 610)
	const MAT := Rect2(108, 136, 560, 470)
	const SLAB := Rect2(694, 136, 478, 470)
	const BOX := 74.0
	const GAP := 10.0
	const WOOD := Color("6b4a2c")
	const SEAM := Color("3e2a18")
	const LEATHER := Color("8a5a3a")
	const STITCH := Color("e2c49a")
	const STONE := Color("8f8076")
	const HIDE := Color("ecd8b0")
	const INK := Color("3b2a22")
	const GOLD := Color("ffcf40")
	const OK := Color("5f9e3a")
	const SHORT := Color("c0503a")

	var ws: CanvasLayer
	var t := 0.0
	var shake := 0.0
	var burst := 0.0
	var _hover_item := -1
	var _hover := ""                               # "make<i>", "close", ""
	var _items: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(delta: float) -> void:
		t += delta
		shake = maxf(shake - delta, 0.0)
		burst = maxf(burst - delta, 0.0)
		_items = Bag.listing(ws.rig).filter(func(id: String) -> bool: return id != "hands")     # (no stick: not a thing on the table)
		queue_redraw()

	# ---- where things are
	func _cols() -> int:
		return 6 if _items.size() <= 30 else 7

	func _box_rect(i: int) -> Rect2:
		var c := _cols()
		var s := BOX if c == 6 else 64.0
		var x0 := MAT.position.x + (MAT.size.x - (c * s + (c - 1) * GAP)) * 0.5
		return Rect2(x0 + (i % c) * (s + GAP), MAT.position.y + 62 + (i / c) * (s + GAP), s, s)

	func _card_rect(i: int) -> Rect2:
		return Rect2(SLAB.position.x + 20, SLAB.position.y + 66 + i * 236, SLAB.size.x - 40, 220)

	func _make_rect(i: int) -> Rect2:
		var c := _card_rect(i)
		return Rect2(c.end.x - 150, c.end.y - 64, 134, 50)

	func _close_rect() -> Rect2:
		return Rect2(BOARD.end.x - 58, BOARD.position.y + 12, 44, 44)

	# ---- the mouse
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			var p: Vector2 = (e as InputEventMouseMotion).position
			_hover_item = -1
			for i in mini(_items.size(), 35):
				if _box_rect(i).has_point(p):
					_hover_item = i
			_hover = ""
			if _close_rect().has_point(p):
				_hover = "close"
			var rs: Array = ws.recipes()
			for i in rs.size():
				if _make_rect(i).has_point(p):
					_hover = "make%d" % i
				if _card_rect(i).has_point(p):
					ws.sel = i
		elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			if _hover == "close":
				ws.close()
			elif _hover.begins_with("make"):
				var i := int(_hover.substr(4))
				ws.make(ws.recipes()[i][0])
		accept_event()

	# ---- drawing
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.03, 0.02, 0.55))
		_draw_table()
		_draw_bag()
		_draw_make()
		var f := Pal.text_font()
		var foot := "Point at things      Click MAKE  (or E)      Up / Down: a card      Esc: close"
		draw_string_outline(f, Vector2(BOARD.position.x, BOARD.end.y - 18), foot, HORIZONTAL_ALIGNMENT_CENTER, BOARD.size.x, 15, 6, SEAM)
		draw_string(f, Vector2(BOARD.position.x, BOARD.end.y - 18), foot, HORIZONTAL_ALIGNMENT_CENTER, BOARD.size.x, 15, Color("f3e3c3"))

	## The table: planks, seams, grain, nails; the title on a hide banner; the close button.
	func _draw_table() -> void:
		var b := BOARD
		draw_rect(Rect2(b.position + Vector2(8, 10), b.size), Color(0, 0, 0, 0.45))
		var planks := 9
		var ph := b.size.y / planks
		for k in planks:
			var r := Rect2(b.position.x, b.position.y + k * ph, b.size.x, ph)
			draw_rect(r, WOOD.lightened(0.05 * ((k * 7) % 3)).darkened(0.03 * (k % 2)))
			for g in 3:                                            # the grain
				var pts := PackedVector2Array()
				var gy := r.position.y + ph * (0.25 + g * 0.25)
				for s in 29:
					var x := r.position.x + s * r.size.x / 28.0
					pts.append(Vector2(x, gy + sin(x * 0.013 + k * 2.1 + g) * 3.0))
				draw_polyline(pts, Color(SEAM, 0.22), 1.5)
			draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), SEAM, 2.5)
			for nx in [b.position.x + 18.0, b.end.x - 18.0]:           # nails
				draw_circle(Vector2(nx, r.position.y + ph * 0.5), 4.0, Color("2a2420"))
				draw_circle(Vector2(nx - 1, r.position.y + ph * 0.5 - 1), 1.6, Color("9a948c"))
		draw_rect(b, SEAM, false, 6.0)
		# the title, on a hide banner with notched ends
		var tw := 430.0
		var tx := b.position.x + (b.size.x - tw) * 0.5
		var ty := b.position.y + 10.0
		var banner := PackedVector2Array([Vector2(tx - 30, ty), Vector2(tx + tw + 30, ty), Vector2(tx + tw + 12, ty + 28),
			Vector2(tx + tw + 30, ty + 56), Vector2(tx - 30, ty + 56), Vector2(tx - 12, ty + 28)])
		draw_colored_polygon(banner, HIDE.darkened(0.08))
		draw_polyline(banner + PackedVector2Array([banner[0]]), INK, 3.0)
		var tf := Pal.title_font()
		draw_string(tf, Vector2(tx, ty + 46), "THE WORKSHOP", HORIZONTAL_ALIGNMENT_CENTER, tw, 40, INK)
		Bag.draw_icon(self, "axe", Vector2(tx - 2, ty + 28), 0.9, t)
		Bag.draw_icon(self, "shovel", Vector2(tx + tw + 2, ty + 28), 0.9, t)
		# close
		var cr := _close_rect()
		draw_circle(cr.get_center(), 21.0, SHORT.lightened(0.25) if _hover == "close" else SHORT)
		draw_arc(cr.get_center(), 21.0, 0.0, TAU, 24, INK, 3.0)
		var c := cr.get_center()
		draw_line(c + Vector2(-8, -8), c + Vector2(8, 8), Color.WHITE, 4.0)
		draw_line(c + Vector2(8, -8), c + Vector2(-8, 8), Color.WHITE, 4.0)

	## The leather mat: IN YOUR BAG, a box for each thing; the one pointed at, told.
	func _draw_bag() -> void:
		var m := MAT
		draw_rect(Rect2(m.position + Vector2(4, 5), m.size), Color(0, 0, 0, 0.3))
		draw_rect(m, LEATHER)
		draw_rect(m.grow(-1), LEATHER.lightened(0.06), false, 2.0)
		_stitches(m.grow(-9))
		var tf := Pal.title_font()
		var f := Pal.text_font()
		draw_string(tf, m.position + Vector2(24, 44), "IN YOUR BAG", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("ffe7b0"))
		draw_string(f, m.position + Vector2(220, 42), "%d kinds of things" % _items.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("e9d3b0"))
		if _items.is_empty():
			draw_string(f, m.position + Vector2(24, 110), "Nothing yet! Dig, gather and hunt in the levels.", HORIZONTAL_ALIGNMENT_LEFT, 500, 17, Color("f3e3c3"))
		for i in mini(_items.size(), 35):
			var id: String = _items[i]
			var r := _box_rect(i)
			var info := Bag.info(id)
			var rc: Color = Bag.RARITY_COL[clampi(int(info[2]), 0, 4)]
			var hov := i == _hover_item
			if hov:
				r = r.grow(3)
			draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.3))
			draw_rect(r, Color(0.16, 0.1, 0.06, 0.55) if not hov else Color(0.3, 0.2, 0.1, 0.7))
			draw_rect(r, GOLD if hov else rc, false, 3.0 if hov else 2.0)
			var bob := sin(t * 3.0 + i) * 1.5 if hov else 0.0
			Bag.draw_icon(self, id, r.get_center() + Vector2(0, -3 + bob), r.size.x / 62.0, t)
			if not Bag.unique(id):
				var n := Bag.count(ws.rig, id)
				var bc := r.end - Vector2(12, 12)
				draw_circle(bc, 12.0, INK)
				draw_string(f, bc + Vector2(-12, 5), str(n), HORIZONTAL_ALIGNMENT_CENTER, 24, 14 if n < 100 else 11, Color.WHITE)
		# what the pointed-at thing is
		var ir := Rect2(m.position.x + 18, m.end.y - 92, m.size.x - 36, 76)
		draw_rect(ir, Color(0.1, 0.06, 0.04, 0.45))
		if _hover_item >= 0 and _hover_item < _items.size():
			var info2 := Bag.info(_items[_hover_item])
			var rk := clampi(int(info2[2]), 0, 4)
			draw_string(tf, ir.position + Vector2(12, 26), str(info2[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Bag.RARITY_COL[rk])
			draw_string(f, ir.position + Vector2(ir.size.x - 140, 24), Bag.RARITY[rk], HORIZONTAL_ALIGNMENT_RIGHT, 128, 13, Bag.RARITY_COL[rk])
			draw_multiline_string(f, ir.position + Vector2(12, 46), "%s  %s" % [info2[3], info2[4]], HORIZONTAL_ALIGNMENT_LEFT, ir.size.x - 24, 13, 2, Color("f3e3c3"))
		else:
			draw_string(f, ir.position + Vector2(12, 44), "Point at a thing to see what it is, and what it's for.", HORIZONTAL_ALIGNMENT_LEFT, ir.size.x - 24, 15, Color("d8c2a0"))

	func _stitches(r: Rect2) -> void:
		for side in 4:
			var a: Vector2 = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)][side]
			var b: Vector2 = [Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position][side]
			var n := int(a.distance_to(b) / 14.0)
			for k in n:
				draw_line(a.lerp(b, (k + 0.2) / n), a.lerp(b, (k + 0.65) / n), STITCH, 2.0)

	## The stone slab: MAKE, a card per recipe.
	func _draw_make() -> void:
		var s := SLAB
		draw_rect(Rect2(s.position + Vector2(4, 5), s.size), Color(0, 0, 0, 0.3))
		draw_rect(s, STONE)
		for k in 40:                                               # speckles
			var p := s.position + Vector2(fmod(k * 97.3, s.size.x), fmod(k * 53.9 + k * k * 1.7, s.size.y))
			draw_circle(p, 1.5 + (k % 3), STONE.darkened(0.12 + 0.05 * (k % 2)))
		draw_rect(s, Color("5e534c"), false, 4.0)
		var tf := Pal.title_font()
		var f := Pal.text_font()
		draw_string_outline(tf, s.position + Vector2(24, 44), "MAKE", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, INK)
		draw_string(tf, s.position + Vector2(24, 44), "MAKE", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("fff2c0"))
		draw_string(f, s.position + Vector2(120, 42), "things for your cave", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f3e3c3"))
		var rs: Array = ws.recipes()
		for i in rs.size():
			_draw_card(i, rs[i])
		if ws._note_t > 0.0:
			var nr := Rect2(s.position.x + 20, s.end.y - 92, s.size.x - 40, 76)
			draw_rect(nr, Color(0.1, 0.06, 0.04, 0.6))
			draw_multiline_string(f, nr.position + Vector2(12, 26), ws._note, HORIZONTAL_ALIGNMENT_LEFT, nr.size.x - 24, 16, 3, Color("b8f08a") if ws._note_ok else Color("ffb08a"))

	func _draw_card(i: int, r: Array) -> void:
		var id: String = r[0]
		var needs: Dictionary = r[2]
		var c := _card_rect(i)
		if shake > 0.0 and i == ws.sel:
			c.position.x += sin(t * 60.0) * 6.0 * shake / 0.35
		var info := Bag.info(id)
		var rk := clampi(int(info[2]), 0, 4)
		var done := Bag.FOREVER.has(id) and Bag.count(ws.rig, id) > 0
		var can := not done and Bag.missing(ws.rig, id) == ""
		draw_rect(Rect2(c.position + Vector2(3, 4), c.size), Color(0, 0, 0, 0.3))
		draw_rect(c, HIDE)
		draw_rect(c, GOLD if i == ws.sel else Color("8a6a3c"), false, 4.0 if i == ws.sel else 3.0)
		# its picture, in a dark round, glowing when it can be made
		var ic := c.position + Vector2(66, 72)
		if can:
			draw_circle(ic, 56.0 + sin(t * 4.0) * 3.0, Color(GOLD, 0.35))
		draw_circle(ic, 50.0, INK)
		draw_arc(ic, 50.0, 0.0, TAU, 32, Bag.RARITY_COL[rk], 3.0)
		Bag.draw_icon(self, id, ic + Vector2(0, sin(t * 2.0) * 2.0), 2.3, t)
		var tf := Pal.title_font()
		var f := Pal.text_font()
		draw_string(tf, c.position + Vector2(132, 36), str(info[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, INK)
		draw_string(f, c.position + Vector2(132, 56), Bag.RARITY[rk], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Bag.RARITY_COL[rk].darkened(0.35))
		draw_multiline_string(f, c.position + Vector2(132, 78), str(info[3]), HORIZONTAL_ALIGNMENT_LEFT, c.size.x - 146, 14, 3, INK.lightened(0.15))
		# what it needs: a chip each, have / need
		var x := c.position.x + 14
		var y := c.end.y - 64
		draw_string(f, Vector2(x, y - 6), "NEEDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK.lightened(0.3))
		for need in needs:
			var have := Bag.count(ws.rig, need)
			var want: int = needs[need]
			var enough := have >= want or done
			var chip := Rect2(x, y, 82, 50)
			draw_rect(chip, Color(OK, 0.22) if enough else Color(SHORT, 0.2))
			draw_rect(chip, OK if enough else SHORT, false, 2.0)
			Bag.draw_icon(self, need, chip.position + Vector2(22, 25), 0.75, t)
			draw_string(tf, chip.position + Vector2(40, 33), ("x%d" % want) if done else ("%d/%d" % [mini(have, 99), want]), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, OK.darkened(0.25) if enough else SHORT)
			x += 90
		# MAKE / made
		var mr := _make_rect(i)
		if done:
			draw_set_transform(mr.get_center(), -0.12, Vector2.ONE)
			var st := Rect2(-mr.size * 0.5, mr.size)
			draw_rect(st, Color(OK, 0.15))
			draw_rect(st, OK, false, 3.0)
			draw_string(tf, Vector2(-mr.size.x * 0.5, 9), "MADE!", HORIZONTAL_ALIGNMENT_CENTER, mr.size.x, 24, OK)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			var hov := _hover == "make%d" % i
			var col := (GOLD.lightened(0.2) if hov else GOLD) if can else Color("a89a88")
			if can:
				mr.position.y += sin(t * 5.0) * 1.5
			draw_rect(Rect2(mr.position + Vector2(2, 4), mr.size), Color(0, 0, 0, 0.35))
			draw_rect(mr, col)
			draw_rect(mr, INK, false, 3.0)
			draw_string(tf, mr.position + Vector2(0, 34), "MAKE!" if can else "NEED MORE", HORIZONTAL_ALIGNMENT_CENTER, mr.size.x, 24 if can else 17, INK)
		# just made: a flash and sparkles round it
		if burst > 0.0 and i == ws.sel:
			var k := burst / 1.6
			draw_rect(c, Color(1, 1, 0.85, 0.5 * k * k))
			for s in 14:
				var a := s * TAU / 14.0 + t
				var rr := 60.0 + (1.0 - k) * 90.0
				var sp := ic + Vector2(cos(a), sin(a)) * rr
				draw_circle(sp, 4.0 * k + 1.0, Color(1, 0.95, 0.6, k))
