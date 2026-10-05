class_name CampMenu
extends CanvasLayer
## The Camp Menu: the game stops, and we are in a firelit cave. On the wall,
## four carved tablets — SAVE (a spiral of memory in a clay pot), SHELTER (a
## hut of tusks and hide; built later), ABILITIES (a hand of fire) and
## TUTORIAL (a cave painting of him leaping).
##   ABILITIES  his powers (Abilities.POWERS): he carries TWO — pick one and
##              press Space (or tap CARRY) to put it in a slot or take it out.
##              The two show as circles at the bottom of the screen.
##   TUTORIAL   his special moves (Abilities.MOVES), and how to do each.
## On both walls every unlocked medallion glows the same sun-gold and every
## locked one is cold slate in chains; the big tablet on the right shows the
## chosen one up close.
##
## Keys: arrows / WASD choose, Space / Enter / J pick, Esc / K back, Tab / M
## close. Mouse and touch: hover or tap.

const INK := Color("f3e3c3")
const DIM := Color("a8957a")
const TEAL := Color("3ee0c8")
const AMBER := Color("ffae42")
const MAGENTA := Color("ff4fd8")
const LIME := Color("9be15d")
const TABLETS := [
	["save", "SAVE", "Keep what he's found", TEAL],
	["shelter", "SHELTER", "Build his home", AMBER],
	["abilities", "ABILITIES", "Pick his two powers", MAGENTA],
	["tutorial", "TUTORIAL", "His special moves", LIME],
]
const COLS := 3
const CARRY := Rect2(820, 604, 300, 46)     ## the CARRY IT / PUT IT DOWN button
const VIEW_BTN := Rect2(40, 650, 260, 40)   ## VIEW: CLOSE / NORMAL / WIDE (also the V key)
const MYST_BOX := Rect2(900, 640, 350, 56)  ## the MYSTERIES note, bottom right
## The mysteries he has run into (GameState.mysteries): [while open, once solved].
const MYSTERIES := {
	"shovel": ["The clay in the Dig needs a SHOVEL... where is one?", "The shovel was in the thorns, up in the windy sky."],
}

var player: CaveMan
var level_name := ""

var _page := "main"
var _sel := 0               ## tablet on the main page
var _pick := 0              ## medallion on the abilities page
var _t := 0.0
var _page_t := 0.0          ## time since the page opened (for the entrance)
var _saved_t := -1.0        ## >= 0: the SAVED! stamp is showing
var _embers: Array = []     ## [pos, vel, life, hue]
var _view: Control
var _name: Label
var _status: Label
var _desc: Label
var _keys: Label
var _how: Label
var _was_paused := false
var _flash := 0.0           ## > 0: just put in a slot; < 0: just taken out
var _counter := ""          ## "n / m unlocked", worked out while drawing the wall
var _view_flash := 0.0      ## > 0: the VIEW button was just pressed


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("camp_menu")
	_was_paused = get_tree().paused
	get_tree().paused = true
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_view)
	add_child(_view)
	_name = _label(Vector2(740, 330), Vector2(460, 50), 36, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_status = _label(Vector2(740, 380), Vector2(460, 30), 17, Sunfire.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_desc = _label(Vector2(760, 412), Vector2(420, 110), 17, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_keys = _label(Vector2(760, 532), Vector2(420, 26), 17, Sunfire.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_how = _label(Vector2(760, 560), Vector2(420, 40), 15, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for i in 46:
		_embers.append(_new_ember(true))
	_go("main")


func _label(at: Vector2, size: Vector2, font: int, col: Color, align: int) -> Label:
	var l := Label.new()
	l.position = at
	l.size = size
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _new_ember(anywhere: bool) -> Array:
	var x := randf_range(380, 900) if randf() < 0.7 else randf_range(0, 1280)
	var y := randf_range(0, 720) if anywhere else 700.0
	return [Vector2(x, y), Vector2(randf_range(-14, 14), randf_range(-70, -30)), randf_range(2.0, 6.0), randf()]


func _go(page: String) -> void:
	_page = page
	_page_t = 0.0
	var grid := _grid()
	for l in [_name, _status, _desc, _keys, _how]:
		l.visible = grid
	if grid:
		_pick = 0
		_show_ability()


## The abilities and the tutorial are both walls of medallions.
func _grid() -> bool:
	return _page == "abilities" or _page == "tutorial"


func _list() -> Array:
	return Abilities.POWERS if _page == "abilities" else Abilities.MOVES


## Put the chosen power in a slot, or take it out.
func _carry() -> void:
	if _page != "abilities":
		return
	var id: String = _list()[_pick][0]
	match Abilities.toggle(id, player):
		"on":
			_flash = 0.6
		"off":
			_flash = -0.6
	_show_ability()




func _close() -> void:
	get_tree().paused = _was_paused
	queue_free()


func _process(delta: float) -> void:
	_t += delta
	_page_t += delta
	_flash = move_toward(_flash, 0.0, delta)
	_view_flash = maxf(_view_flash - delta, 0.0)
	if _saved_t >= 0.0:
		_saved_t += delta
		if _saved_t > 1.8:
			_saved_t = -1.0
	for i in _embers.size():
		var e: Array = _embers[i]
		e[0] = (e[0] as Vector2) + (e[1] as Vector2) * delta + Vector2(sin(_t * 2.0 + i) * 8.0 * delta, 0)
		e[2] = float(e[2]) - delta
		if float(e[2]) <= 0.0 or (e[0] as Vector2).y < -10.0:
			_embers[i] = _new_ember(false)
	_view.queue_redraw()


## ------------------------------------------------------------------ input
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		match _page:
			"main":
				match k:
					KEY_LEFT, KEY_A:
						_sel = (_sel + TABLETS.size() - 1) % TABLETS.size()
					KEY_RIGHT, KEY_D:
						_sel = (_sel + 1) % TABLETS.size()
					KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_J:
						_choose(_sel)
					KEY_V:
						_cycle_view()
					KEY_ESCAPE, KEY_K, KEY_TAB, KEY_M:
						_close()
			"abilities", "tutorial":
				var n := _list().size()
				match k:
					KEY_LEFT, KEY_A:
						_pick = (_pick + n - 1) % n
						_show_ability()
					KEY_RIGHT, KEY_D:
						_pick = (_pick + 1) % n
						_show_ability()
					KEY_UP, KEY_W:
						_pick = (_pick + n - _cols()) % n
						_show_ability()
					KEY_DOWN, KEY_S:
						_pick = (_pick + _cols()) % n
						_show_ability()
					KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_J:
						if _page == "abilities":
							_carry()
						else:
							_go("main")
					KEY_ESCAPE, KEY_K:
						_go("main")
					KEY_TAB, KEY_M:
						_close()
			_:
				if k in [KEY_TAB, KEY_M]:
					_close()
				else:
					_go("main")
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var at := (event as InputEventMouseMotion).position
		var hit := _hit(at)
		if hit >= 0:
			if _page == "main":
				_sel = hit
			elif _grid() and hit != _pick:
				_pick = hit
				_show_ability()
	elif (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
			or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		var at2: Vector2 = event.position
		if _page == "main" and VIEW_BTN.has_point(at2):
			_cycle_view()
		elif Rect2(1150, 24, 110, 44).has_point(at2):
			if _page == "main":
				_close()
			else:
				_go("main")
		else:
			var hit2 := _hit(at2)
			if _page == "main" and hit2 >= 0:
				_sel = hit2
				_choose(hit2)
			elif _page == "abilities" and CARRY.has_point(at2):
				_carry()
			elif _grid() and hit2 >= 0:
				if _page == "abilities" and hit2 == _pick:
					_carry()                # a second tap on the chosen one carries it
				_pick = hit2
				_show_ability()
			elif _page == "shelter":
				_go("main")
		get_viewport().set_input_as_handled()


## Which tablet / medallion is under the pointer (-1: none).
func _hit(at: Vector2) -> int:
	if _page == "main":
		for i in TABLETS.size():
			if Rect2(_tablet_x(i) - 118.0, 240.0, 236.0, 300.0).has_point(at):
				return i
	elif _grid():
		for i in _list().size():
			if at.distance_to(_medal_at(i)) < 62.0:
				return i
	return -1


func _choose(i: int) -> void:
	match TABLETS[i][0]:
		"save":
			GameState.save()
			_saved_t = 0.0
		"shelter":
			_go("shelter")
		"abilities":
			_go("abilities")
		"tutorial":
			_go("tutorial")


## ------------------------------------------------------------------ layout
func _tablet_x(i: int) -> float:
	return 205.0 + i * 290.0


## Three across; four when the wall has more than nine.
func _cols() -> int:
	return 4 if _list().size() > 9 else COLS


func _medal_at(i: int) -> Vector2:
	if _cols() == 4:
		return Vector2(110.0 + (i % 4) * 140.0, 232.0 + (i / 4) * 150.0)
	return Vector2(150.0 + (i % COLS) * 170.0, 232.0 + (i / COLS) * 150.0)


func _show_ability() -> void:
	var row: Array = _list()[_pick]
	var id: String = row[0]
	var open := Abilities.unlocked(id, player)
	_name.text = row[1]
	_desc.text = row[2]
	if open:
		var slot := Abilities.slots(player).find(id)
		_status.text = "★  UNLOCKED  ★"
		if _page == "abilities":
			_status.text = ("★  CARRIED — SLOT %d  ★" % (slot + 1)) if slot >= 0 else "UNLOCKED — not carried"
		_status.add_theme_color_override("font_color", Sunfire.GOLD if slot >= 0 or _page == "tutorial" else Color("e8c99a"))
		_keys.text = ("KEY:  " if _page == "abilities" else "KEYS:  ") + str(row[3])
		_how.text = ""
		if id == "sunfire" and player != null:
			if player.sun_t > 0.0:
				_how.text = "BURNING! %d seconds left." % ceili(player.sun_t)
			elif player.sun_charge >= 1.0:
				_how.text = "The sun is FULL — press Q to let it out!"
			else:
				_how.text = "The sun is %d%% full. Hit beasts, grab shells, sit by fires." % int(player.sun_charge * 100.0)
	else:
		_status.text = "LOCKED"
		_status.add_theme_color_override("font_color", Color("9aa3b5"))
		_keys.text = ""
		_how.text = "TO UNLOCK:  " + str(row[4])


## ------------------------------------------------------------------ drawing
func _draw_view() -> void:
	var b := Batch.new()
	_draw_cave(b)
	match _page:
		"main":
			_draw_main(b)
		"abilities", "tutorial":
			_draw_grid(b)
		"shelter":
			_draw_shelter(b)
	# embers over everything, in fire colours with a few magic ones
	for e in _embers:
		var hue: float = e[3]
		var col := Color.from_hsv(0.04 + hue * 0.1, 0.8, 1.0) if hue < 0.85 else Color.from_hsv(randf(), 0.6, 1.0)
		var life: float = clampf(float(e[2]) / 2.0, 0.0, 1.0)
		b.circle(e[0], 2.2 + hue * 1.6, Color(col, 0.75 * life), 6)
	# the close button
	b.circle(Vector2(1205, 46), 20.0, Color(0, 0, 0, 0.4), 18)
	b.line(Vector2(1196, 37), Vector2(1214, 55), INK, 3.0)
	b.line(Vector2(1214, 37), Vector2(1196, 55), INK, 3.0)
	b.draw(_view)
	_texts()


## The cave: warm dark rock, jagged edges, stalactites, faded paintings, and
## the campfire's light breathing at the bottom.
func _draw_cave(b: Batch) -> void:
	for i in 12:
		var k := i / 11.0
		b.rect(Rect2(0, i * 60.0, 1280, 61), Color("1a0f12").lerp(Color("3a1d17"), k))
	var flick := 0.85 + 0.1 * sin(_t * 7.0) + 0.05 * sin(_t * 13.0)
	for i in 6:
		var r := (520.0 - i * 70.0) * flick
		b.circle(Vector2(640, 760), r, Color(1.0, 0.45, 0.15, 0.05 + i * 0.012), 40)
	# the paintings on the wall: hand prints, a mammoth, little hunters
	var ochre := Color("c8553d", 0.16)
	for hp in [Vector2(90, 130), Vector2(1170, 180), Vector2(140, 600), Vector2(1110, 560)]:
		_handprint(b, hp, 0.9, ochre)
	b.circle(Vector2(1060, 650), 34.0, ochre, 18)
	b.circle(Vector2(1030, 640), 22.0, ochre, 14)
	for lx in [1040.0, 1066.0, 1082.0]:
		b.line(Vector2(lx, 670), Vector2(lx, 700), ochre, 7.0)
	b.polyline(PackedVector2Array([Vector2(1010, 640), Vector2(996, 668), Vector2(1004, 690)]), ochre, 6.0)
	for hx in [200.0, 236.0]:
		b.circle(Vector2(hx, 660), 6.0, ochre, 8)
		b.line(Vector2(hx, 666), Vector2(hx, 692), ochre, 4.0)
		b.line(Vector2(hx, 692), Vector2(hx - 8, 708), ochre, 3.0)
		b.line(Vector2(hx, 692), Vector2(hx + 8, 708), ochre, 3.0)
		b.line(Vector2(hx - 14, 668), Vector2(hx + 20, 660), ochre, 3.0)
	# jagged rock around the edges and stalactites hanging from the roof
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var top := PackedVector2Array([Vector2(0, 0)])
	for i in 33:
		top.append(Vector2(i * 40.0, rng.randf_range(10, 40) + (rng.randf_range(30, 70) if i % 5 == 2 else 0.0)))
	top.append(Vector2(1280, 0))
	b.poly(top, Color("0d0709"))
	for side in [0.0, 1280.0]:
		var edge := PackedVector2Array([Vector2(side, 0)])
		for j in 13:
			edge.append(Vector2(absf(side - rng.randf_range(8, 38)), j * 60.0))
		edge.append(Vector2(side, 720))
		b.poly(edge, Color("0d0709"))
	b.rect(Rect2(0, 690, 1280, 30), Color("0d0709"))


func _handprint(b: Batch, at: Vector2, s: float, col: Color) -> void:
	b.circle(at, 16.0 * s, col, 14)
	for f in 5:
		var a := -PI * 0.5 + (f - 2) * 0.38
		var fl := (26.0 if f in [1, 2, 3] else 20.0) * s
		b.line(at + Vector2.from_angle(a) * 10.0 * s, at + Vector2.from_angle(a) * (10.0 * s + fl), col, 7.0 * s)


## The four tablets.
func _draw_main(b: Batch) -> void:
	_campfire(b, Vector2(640, 690), 1.0)
	for i in TABLETS.size():
		var tab: Array = TABLETS[i]
		var accent: Color = tab[3]
		var on := i == _sel
		var enter := clampf((_page_t - i * 0.08) / 0.35, 0.0, 1.0)
		var bounce := 1.0 - pow(1.0 - enter, 3.0)
		var lift := (-16.0 + sin(_t * 3.0) * 3.0) if on else 0.0
		var c := Vector2(_tablet_x(i), 390.0 + lift + (1.0 - bounce) * 300.0)
		var s := 1.06 if on else 1.0
		# the slab: a chunky stone, a little uneven, its rim lit in its colour
		var slab := PackedVector2Array()
		var rng := RandomNumberGenerator.new()
		rng.seed = 11 + i
		for j in 20:
			var a := j * TAU / 20.0
			var rx := 114.0 * s
			var ry := 150.0 * s
			var p := Vector2(clampf(cos(a) * 1.5, -1.0, 1.0) * rx, clampf(sin(a) * 1.4, -1.0, 1.0) * ry)
			slab.append(c + p + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6)))
		if on:
			var glow := 0.35 + 0.15 * sin(_t * 5.0)
			for g in 3:
				b.poly(_grow(slab, c, 1.0 + 0.035 * (g + 1)), Color(accent, glow / (g + 1.5)))
		b.poly(_grow(slab, c + Vector2(6, 10), 1.0), Color(0, 0, 0, 0.45))
		b.poly(slab, Color("4a3a33") if on else Color("3a2e29"))
		b.poly(_grow(slab, c, 0.9), Color("57463d") if on else Color("43352f"))
		b.polyline(_closed(slab), Color(accent, 0.9 if on else 0.3), 4.0 if on else 2.0)
		# cracks and chisel marks
		b.line(c + Vector2(-90, -116) * s, c + Vector2(-62, -88) * s, Color(0, 0, 0, 0.25), 2.0)
		b.line(c + Vector2(80, 106) * s, c + Vector2(52, 124) * s, Color(0, 0, 0, 0.25), 2.0)
		# the medallion and its symbol
		var mc := c + Vector2(0, -36) * s
		b.circle(mc, 74.0 * s, Color(0.08, 0.05, 0.05, 0.85), 40)
		b.arc(mc, 74.0 * s, 0.0, TAU, 48, Color(accent, 0.8 if on else 0.35), 4.0)
		for d in 12:
			var a2 := d * TAU / 12.0 + (_t * 0.6 if on else 0.0)
			b.circle(mc + Vector2.from_angle(a2) * 84.0 * s, 3.0, Color(accent, 0.8 if on else 0.25), 6)
		var tt := _t * (1.6 if on else 0.6)
		match tab[0]:
			"save":
				_symbol_save(b, mc, 52.0 * s, accent, tt)
			"shelter":
				_symbol_shelter(b, mc, 52.0 * s, accent, tt)
			"abilities":
				_symbol_abilities(b, mc, 52.0 * s, accent, tt)
			"tutorial":
				_symbol_tutorial(b, mc, 52.0 * s, accent, tt)
		# the SAVED! stamp
		if tab[0] == "save" and _saved_t >= 0.0:
			var k := clampf(_saved_t / 0.18, 0.0, 1.0)
			var sz := 2.0 - k
			for r in 10:
				var a3 := r * TAU / 10.0 + _saved_t * 2.0
				b.line(mc + Vector2.from_angle(a3) * 50.0 * sz, mc + Vector2.from_angle(a3) * (90.0 + 50.0 * _saved_t) * sz, Color(TEAL, 0.8 * (1.0 - _saved_t / 1.8)), 5.0)
	# the mysteries he has met, on a scrap of hide: open ones first
	if not GameState.mysteries.is_empty():
		b.rect(MYST_BOX, Color("2a1d14", 0.85))
		b.rect(Rect2(MYST_BOX.position, Vector2(MYST_BOX.size.x, 3)), Color(AMBER, 0.7))
	# the VIEW button, bottom left
	var vb := VIEW_BTN.grow(_view_flash * 8.0)
	b.rect(vb, Color(0, 0, 0, 0.45))
	b.rect(Rect2(vb.position, Vector2(vb.size.x, 3)), Color(TEAL, 0.6 + _view_flash))
	for i in 3:
		var on: bool = ["close", "normal", "wide"][i] == GameState.view_name()
		b.rect(Rect2(VIEW_BTN.position + Vector2(180.0 + i * 24.0, 12.0 + (2 - i) * 4.0), Vector2(16.0, 16.0 - (2 - i) * 4.0)), TEAL if on else Color(1, 1, 1, 0.25))
	# the soon ribbon on the shelter tablet
	var sx := _tablet_x(1) + 70.0
	var sy := 260.0 + (-16.0 if _sel == 1 else 0.0)
	b.quad(Vector2(sx - 46, sy - 12), Vector2(sx + 46, sy + 4), Vector2(sx + 42, sy + 26), Vector2(sx - 50, sy + 10), Color("c0392b"))


func _grow(pts: PackedVector2Array, c: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + (p - c) * k)
	return out


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out


## A spiral of memory, cut into a clay pot, with sparks of what's kept.
func _symbol_save(b: Batch, c: Vector2, r: float, col: Color, t: float) -> void:
	var pot := PackedVector2Array([c + Vector2(-0.55, 0.85) * r, c + Vector2(-0.8, 0.2) * r, c + Vector2(-0.6, -0.45) * r,
		c + Vector2(-0.35, -0.6) * r, c + Vector2(0.35, -0.6) * r, c + Vector2(0.6, -0.45) * r, c + Vector2(0.8, 0.2) * r, c + Vector2(0.55, 0.85) * r])
	b.poly(pot, Color("a4623a"))
	b.rect(Rect2(c + Vector2(-0.42, -0.75) * r, Vector2(0.84, 0.18) * r), Color("7a4526"))
	var sp := PackedVector2Array()
	for i in 40:
		var q := i / 39.0
		sp.append(c + Vector2(0, 0.12 * r) + Vector2.from_angle(q * TAU * 2.2 + t * 2.0) * (4.0 + q * 0.42 * r))
	b.polyline(sp, col, 4.0)
	for i in 5:
		var a := t * 1.5 + i * TAU / 5.0
		var p := c + Vector2(0, -0.9 * r) + Vector2(cos(a) * 0.5 * r, -absf(sin(a * 1.3)) * 0.3 * r)
		_star(b, p, 6.0, col.lightened(0.4))


## A hut of mammoth tusks and hide, smoke curling up, the moon over it.
func _symbol_shelter(b: Batch, c: Vector2, r: float, col: Color, t: float) -> void:
	b.circle(c + Vector2(0.6, -0.65) * r, 0.18 * r, Color("f6f0d8"), 16)
	b.circle(c + Vector2(0.66, -0.7) * r, 0.15 * r, Color(0.08, 0.05, 0.05), 16)
	b.poly(PackedVector2Array([c + Vector2(-0.85, 0.75) * r, c + Vector2(-0.55, -0.1) * r, c + Vector2(0, -0.45) * r,
		c + Vector2(0.55, -0.1) * r, c + Vector2(0.85, 0.75) * r]), Color("8a5a3a"))
	for s in [-1.0, 1.0]:
		b.polyline(PackedVector2Array([c + Vector2(s * 0.8, 0.75) * r, c + Vector2(s * 0.62, 0.0) * r, c + Vector2(s * 0.1, -0.5) * r]), Color("efe6cf"), 6.0)
	b.poly(PackedVector2Array([c + Vector2(-0.22, 0.75) * r, c + Vector2(0, 0.2) * r, c + Vector2(0.22, 0.75) * r]), Color(0.1, 0.05, 0.03))
	Sunfire.flame(b, c + Vector2(0, 0.74) * r, 0.2 * r, t * 1.2, 0.9)
	for i in 3:
		var q := fmod(t * 0.5 + i / 3.0, 1.0)
		b.circle(c + Vector2(0.05 + sin(q * 6.0 + t) * 0.12, -0.5 - q * 0.5) * r, (0.06 + q * 0.08) * r, Color(col, 0.5 * (1.0 - q)), 10)


## A hand of fire, with sparks of every colour circling it.
func _symbol_abilities(b: Batch, c: Vector2, r: float, col: Color, t: float) -> void:
	for i in 12:
		var a := i * TAU / 12.0 + t * 0.8
		var ray := r * (0.85 + 0.12 * sin(t * 6.0 + i))
		b.tri(c + Vector2.from_angle(a + 0.13) * r * 0.5, c + Vector2.from_angle(a) * ray, c + Vector2.from_angle(a - 0.13) * r * 0.5, Color(col, 0.75))
	_handprint(b, c + Vector2(0, 0.12 * r), r / 34.0, Sunfire.GOLD)
	for i in 6:
		var a2 := -t * 1.6 + i * TAU / 6.0
		_star(b, c + Vector2.from_angle(a2) * r * 1.05, 5.0, Color.from_hsv(fmod(i / 6.0 + t * 0.1, 1.0), 0.7, 1.0))


func _star(b: Batch, at: Vector2, r: float, col: Color) -> void:
	b.quad(at + Vector2(0, -r * 1.6), at + Vector2(r * 0.4, 0), at + Vector2(0, r * 1.6), at + Vector2(-r * 0.4, 0), col)
	b.quad(at + Vector2(-r * 1.6, 0), at + Vector2(0, r * 0.4), at + Vector2(r * 1.6, 0), at + Vector2(0, -r * 0.4), col)


func _campfire(b: Batch, at: Vector2, s: float) -> void:
	b.line(at + Vector2(-40, 4) * s, at + Vector2(40, -8) * s, Color("5e452f"), 12.0 * s)
	b.line(at + Vector2(-40, -8) * s, at + Vector2(40, 4) * s, Color("6e5238"), 12.0 * s)
	for i in 4:
		Sunfire.flame(b, at + Vector2(-24.0 + i * 16.0, -6.0) * s, (44.0 + 14.0 * sin(_t * 3.0 + i)) * s, _t * 1.2 + i * 1.7)


## A wall of medallions (the powers, or the moves), and the chosen one up close.
func _draw_grid(b: Batch) -> void:
	var list := _list()
	var carried := Abilities.slots(player)
	var n := list.size()
	var got := 0
	for i in n:
		var row: Array = list[i]
		var id: String = row[0]
		var open := Abilities.unlocked(id, player)
		if open:
			got += 1
		var on := i == _pick
		var enter := clampf((_page_t - i * 0.035) / 0.3, 0.0, 1.0)
		var c := _medal_at(i)
		var r := 54.0 * (1.12 if on else 1.0) * (0.3 + 0.7 * (1.0 - pow(1.0 - enter, 3.0)))
		if open:
			b.circle(c, r + 12.0 + 3.0 * sin(_t * 3.0 + i), Color(Abilities.GOLD, 0.12), 28)
			b.circle(c, r, Color("2a1a12"), 32)
			b.circle(c, r * 0.9, Color("3b2619"), 32)
			b.arc(c, r, 0.0, TAU, 40, Abilities.GOLD, 4.0)
			Abilities.draw_symbol(b, id, c, r * 0.76, Abilities.GOLD, _t * (1.4 if on else 0.5) + i)
		else:
			b.circle(c, r, Color("1c1e25"), 32)
			b.circle(c, r * 0.9, Color("262933"), 32)
			b.arc(c, r, 0.0, TAU, 40, Abilities.SLATE, 3.0)
			Abilities.draw_symbol(b, id, c, r * 0.72, Color(Abilities.SLATE, 0.55), 0.0)
			# chains across, and a padlock
			for s in [-1.0, 1.0]:
				for j in 7:
					var q := (j - 3) / 3.5
					var p := c + Vector2(q * r, q * r * 0.55 * s)
					b.arc(p, 6.0, 0.0, TAU, 10, Color("6c7385"), 3.0)
			b.rect(Rect2(c + Vector2(-11, r * 0.5), Vector2(22, 18)), Color("8a8f9e"))
			b.arc(c + Vector2(0, r * 0.5), 8.0, PI, TAU, 10, Color("8a8f9e"), 3.5)
			b.circle(c + Vector2(0, r * 0.5 + 9.0), 3.0, Color("2a2c33"), 6)
		# carried: a badge in the power's own colour, with its slot number
		var slot := carried.find(id) if _page == "abilities" else -1
		if slot >= 0:
			var bp := c + Vector2(r * 0.72, -r * 0.72)
			b.circle(bp, 15.0, Color(0, 0, 0, 0.5), 16)
			b.circle(bp, 13.0, Abilities.colour(id), 16)
		if on:
			# a turning dotted ring round the chosen one
			for d in 16:
				var a := d * TAU / 16.0 + _t * 1.5
				b.circle(c + Vector2.from_angle(a) * (r + 16.0), 3.0, Color(INK, 0.9) if d % 2 == 0 else Color(MAGENTA if _page == "abilities" else LIME, 0.9), 6)
	if _page == "abilities":
		_draw_slots(b, carried)
	# the big tablet on the right
	var tc := Vector2(970, 400)
	var slab := PackedVector2Array([tc + Vector2(-250, -330), tc + Vector2(240, -322), tc + Vector2(256, 268), tc + Vector2(-244, 276)])
	b.poly(_grow(slab, tc + Vector2(8, 12), 1.0), Color(0, 0, 0, 0.45))
	b.poly(slab, Color("3a2e29"))
	b.poly(_grow(slab, tc, 0.96), Color("4a3a33"))
	var pick: Array = list[_pick]
	var pid: String = pick[0]
	var popen := Abilities.unlocked(pid, player)
	var bc := Vector2(970, 196)
	var pop := 1.0 + 0.25 * maxf(0.0, 1.0 - _page_t * 4.0)
	if popen:
		var ray_col := Abilities.colour(pid) if _page == "abilities" else Abilities.GOLD
		for i in 16:
			var a := i * TAU / 16.0 + _t * 0.4
			b.tri(bc + Vector2.from_angle(a + 0.1) * 70.0, bc + Vector2.from_angle(a) * (128.0 + 10.0 * sin(_t * 4.0 + i)), bc + Vector2.from_angle(a - 0.1) * 70.0, Color(ray_col, 0.25))
		b.circle(bc, 92.0 * pop, Color("2a1a12"), 40)
		b.arc(bc, 92.0 * pop, 0.0, TAU, 48, Abilities.GOLD, 5.0)
		Abilities.draw_symbol(b, pid, bc, 74.0 * pop, Abilities.GOLD, _t * 1.6)
	else:
		b.circle(bc, 92.0, Color("1c1e25"), 40)
		b.arc(bc, 92.0, 0.0, TAU, 48, Abilities.SLATE, 4.0)
		Abilities.draw_symbol(b, pid, bc, 60.0, Color(Abilities.SLATE, 0.5), 0.0)
		b.polyline(PackedVector2Array([bc + Vector2(-60, -50), bc + Vector2(-20, -10), bc + Vector2(-34, 20), bc + Vector2(10, 64)]), Color(0, 0, 0, 0.6), 3.0)
	# the CARRY IT / PUT IT DOWN button
	if _page == "abilities" and popen:
		var on2 := carried.has(pid)
		var col := Abilities.colour(pid)
		var glow := 0.5 + 0.5 * sin(_t * 4.0)
		b.rect(CARRY.grow(4.0 + 3.0 * glow), Color(col, 0.18) if not on2 else Color(0, 0, 0, 0.0))
		b.rect(CARRY, col.darkened(0.55) if on2 else col.darkened(0.15))
		b.rect(Rect2(CARRY.position, Vector2(CARRY.size.x, 4)), Color(1, 1, 1, 0.25))
	_counter = "%d / %d unlocked" % [got, n]


## The two slots under the wall: what he carries, in their own colours —
## the same circles he sees at the bottom of the screen in the game.
func _draw_slots(b: Batch, carried: Array) -> void:
	for i in Abilities.SLOTS:
		var c := Vector2(250.0 + i * 140.0, 590.0)
		if i < carried.size():
			var id: String = carried[i]
			var col := Abilities.colour(id)
			var pulse := 1.0 + (0.12 * absf(_flash) / 0.6 if i == carried.size() - 1 else 0.0)
			for g in 3:
				b.circle(c, (44.0 + g * 6.0 + 3.0 * sin(_t * 4.0 + i)) * pulse, Color(col, 0.13 - g * 0.035), 28)
			b.circle(c, 40.0 * pulse, Color("2a1a12"), 30)
			b.arc(c, 40.0 * pulse, 0.0, TAU, 36, col, 4.0)
			Abilities.draw_symbol(b, id, c, 28.0 * pulse, col, _t * 1.5)
		else:
			for d in 18:
				var a := d * TAU / 18.0 + _t * 0.3
				b.circle(c + Vector2.from_angle(a) * 40.0, 2.5, Color(1, 1, 1, 0.3), 6)


## A cave painting of him mid-leap, arrows of motion around him.
func _symbol_tutorial(b: Batch, c: Vector2, r: float, col: Color, t: float) -> void:
	var bob := sin(t * 3.0) * 0.08 * r
	var hd := c + Vector2(0.1 * r, -0.55 * r + bob)
	b.circle(hd, 0.16 * r, col, 14)
	var hip := c + Vector2(-0.05 * r, 0.05 * r + bob)
	b.line(hd + Vector2(0, 0.14 * r), hip, col, 0.12 * r)
	b.line(hd + Vector2(-0.02, 0.3) * r, hd + Vector2(0.45, 0.05) * r, col, 0.09 * r)
	b.line(hd + Vector2(-0.02, 0.3) * r, hd + Vector2(-0.4, 0.45) * r, col, 0.09 * r)
	b.line(hip, hip + Vector2(0.45, 0.25) * r, col, 0.1 * r)
	b.line(hip + Vector2(0.45, 0.25) * r, hip + Vector2(0.35, 0.6) * r, col, 0.1 * r)
	b.line(hip, hip + Vector2(-0.35, 0.45) * r, col, 0.1 * r)
	for i in 3:
		var y := (-0.3 + i * 0.3) * r
		var x := -0.75 * r - fmod(t * 0.6 * r + i * 9.0, 0.3 * r)
		b.line(c + Vector2(x, y), c + Vector2(x + 0.3 * r, y), Color(col, 0.7), 0.06 * r)
	b.arc(c + Vector2(0, 0.1 * r), 0.95 * r, -PI * 0.85, -PI * 0.15, 16, Color(col, 0.6), 0.05 * r)
	b.tri(c + Vector2(0.84, -0.48) * r, c + Vector2(0.62, -0.62) * r, c + Vector2(0.7, -0.36) * r, Color(col, 0.8))




## The shelter: just a dream for now — the outline of a hut, in bones.
func _draw_shelter(b: Batch) -> void:
	_campfire(b, Vector2(640, 690), 0.8)
	var c := Vector2(380, 380)
	for s in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for i in 9:
			var q := i / 8.0
			pts.append(c + Vector2(s * (220.0 - q * 200.0), 160.0 - sin(q * PI * 0.5) * 300.0))
		for i in pts.size() - 1:
			if i % 2 == 0:
				b.line(pts[i], pts[i + 1], Color(AMBER, 0.6), 6.0)
	b.line(c + Vector2(-260, 160), c + Vector2(260, 160), Color(AMBER, 0.4), 4.0)
	for i in 6:
		var bx := -200.0 + i * 80.0
		b.line(c + Vector2(bx - 18, 196), c + Vector2(bx + 18, 196), Color("efe6cf"), 7.0)
		b.circle(c + Vector2(bx - 20, 192), 5.0, Color("efe6cf"), 8)
		b.circle(c + Vector2(bx - 20, 200), 5.0, Color("efe6cf"), 8)
		b.circle(c + Vector2(bx + 20, 192), 5.0, Color("efe6cf"), 8)
		b.circle(c + Vector2(bx + 20, 200), 5.0, Color("efe6cf"), 8)
	# the rare finds, on a shelf: found ones in their colours, the rest dark
	var kinds := Relics.KINDS.keys()
	for i in kinds.size():
		var at := _relic_slot(i)
		var have := int(GameState.relics.get(kinds[i], 0))
		b.circle(at, 46.0, Color(0, 0, 0, 0.4), 28)
		if have > 0:
			var col := Relics.colour(kinds[i])
			b.circle(at, 44.0 + 3.0 * sin(_t * 3.0 + i), Color(col, 0.18), 28)
			b.arc(at, 44.0, 0.0, TAU, 32, col, 3.0)
			Relics.draw_icon(b, kinds[i], at, 24.0, _t + i)
		else:
			b.arc(at, 44.0, 0.0, TAU, 32, Color(1, 1, 1, 0.15), 2.0)
			var sil := Batch.new()
			Relics.draw_icon(sil, kinds[i], at, 24.0, 0.0)
			for k in sil.colors.size():
				sil.colors[k] = Color(0.05, 0.04, 0.05, 0.85)
			b.points.append_array(sil.points)
			b.colors.append_array(sil.colors)
	b.rect(Rect2(740, 548, 470, 10), Color("5e452f"))


func _relic_slot(i: int) -> Vector2:
	return Vector2(820.0 + (i % 3) * 155.0, 270.0 + (i / 3) * 150.0)


## Text drawn straight on the view (titles, names under tablets, hints).
func _texts() -> void:
	var f := ThemeDB.fallback_font
	match _page:
		"main":
			_centred(f, "THE CAMP", Vector2(640, 110), 64, Sunfire.GOLD, true)
			_centred(f, level_name, Vector2(640, 150), 18, DIM, false)
			for i in TABLETS.size():
				var tab: Array = TABLETS[i]
				var on := i == _sel
				var y := 500.0 + (-16.0 if on else 0.0)
				_centred(f, tab[1], Vector2(_tablet_x(i), y), 30 if on else 26, tab[3] if on else INK, true)
				_centred(f, tab[2], Vector2(_tablet_x(i), y + 26.0), 15, DIM, false)
			_view.draw_set_transform(Vector2(_tablet_x(1) + 60.0, 278.0 + (-16.0 if _sel == 1 else 0.0)), 0.17, Vector2.ONE)
			_view.draw_string(f, Vector2(-26, 0), "SOON", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
			_view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if _saved_t >= 0.0:
				var a := clampf(1.0 - (_saved_t - 1.2) / 0.6, 0.0, 1.0)
				var sz := int(46.0 * (2.0 - clampf(_saved_t / 0.18, 0.0, 1.0)))
				_centred(f, "SAVED!", Vector2(_tablet_x(0), 380), sz, Color(TEAL.lightened(0.3), a), true)
			_centred(f, "← →  choose      SPACE  open      ESC  back to the game", Vector2(640, 606), 16, DIM, false)
			_view.draw_string(f, VIEW_BTN.position + Vector2(14, 27), "VIEW: %s   V" % GameState.view_name().to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
			if not GameState.mysteries.is_empty():
				_view.draw_string(f, MYST_BOX.position + Vector2(12, 18), "MYSTERIES", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, AMBER)
				var y := 36.0
				for id in GameState.mysteries:
					if not MYSTERIES.has(id) or y > 52.0:
						continue
					var solved: bool = GameState.mysteries[id] == "solved"
					var line: String = (MYSTERIES[id] as Array)[1 if solved else 0]
					_view.draw_string(f, MYST_BOX.position + Vector2(12, y + 6), ("✓ " if solved else "? ") + line, HORIZONTAL_ALIGNMENT_LEFT, MYST_BOX.size.x - 20.0, 13, Color("9be15d") if solved else INK)
					y += 18.0
		"abilities":
			_centred(f, "ABILITIES", Vector2(320, 92), 50, Sunfire.GOLD, true)
			_centred(f, "%s  ·  he carries TWO" % _counter, Vector2(320, 126), 18, DIM, false)
			_centred(f, "CARRIED", Vector2(320, 530), 16, INK, true)
			var carried := Abilities.slots(player)
			for i in Abilities.SLOTS:
				_centred(f, str(i + 1), Vector2(250.0 + i * 140.0, 650.0), 14, DIM, false)
			for i in _list().size():
				var slot := carried.find(_list()[i][0])
				if slot >= 0:
					var r := 54.0 * (1.12 if i == _pick else 1.0)
					_centred(f, str(slot + 1), _medal_at(i) + Vector2(r * 0.72, -r * 0.72 + 6.0), 17, Color.BLACK, false)
			var pr: Array = _list()[_pick]
			if Abilities.unlocked(pr[0], player):
				var label := "PUT IT DOWN" if carried.has(pr[0]) else ("CARRY IT" if carried.size() < Abilities.SLOTS else "CARRY IT (swap)")
				_centred(f, label + "   SPACE", CARRY.get_center() + Vector2(0, 7), 20, INK, true)
			_centred(f, "ARROWS  choose      SPACE  carry      ESC  back", Vector2(320, 690), 15, DIM, false)
		"tutorial":
			_centred(f, "SPECIAL MOVES", Vector2(320, 92), 46, LIME, true)
			_centred(f, "%s  ·  always his, once learned" % _counter, Vector2(320, 126), 18, DIM, false)
			_centred(f, "ARROWS  choose      ESC  back", Vector2(320, 690), 15, DIM, false)
		"shelter":
			_centred(f, "THE SHELTER", Vector2(640, 110), 56, AMBER, true)
			_centred(f, "Coming soon: build his home from bones — and the rare finds out in the world.", Vector2(640, 150), 19, INK, false)
			_centred(f, "Bones gathered:  %d" % GameState.bones, Vector2(380, 620), 24, Color("efe6cf"), true)
			_centred(f, "RARE FINDS", Vector2(975, 205), 24, AMBER, true)
			var kinds := Relics.KINDS.keys()
			for i in kinds.size():
				var have := int(GameState.relics.get(kinds[i], 0))
				var at := _relic_slot(i)
				_centred(f, Relics.name_of(kinds[i]) if have > 0 else "?", at + Vector2(0, 66), 13, INK if have > 0 else DIM, false)
				if have > 1:
					_centred(f, "x%d" % have, at + Vector2(34, -30), 15, Color.WHITE, true)
			_centred(f, "any key  back", Vector2(640, 662), 16, DIM, false)


func _centred(f: Font, text: String, at: Vector2, size: int, col: Color, shadow: bool) -> void:
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if shadow:
		_view.draw_string(f, at + Vector2(-w * 0.5 + 3, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.6 * col.a))
	_view.draw_string(f, at + Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Close -> Normal -> Wide: how much of the world the camera shows. Saved,
## and the level's camera changes at once (the game is paused behind us).
func _cycle_view() -> void:
	GameState.next_view()
	var level := player.get_parent() if player != null else null
	if level != null and level.has_method("apply_view"):
		level.apply_view()
	_view_flash = 0.5

