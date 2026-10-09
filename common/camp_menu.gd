class_name CampMenu
extends CanvasLayer
## The Camp Menu: the game stops, and we are in a firelit cave. A list down
## the left — RESUME, SAVE, LOAD, ABILITIES, SPECIAL MOVES, SHELTER — and a
## card on the right about the chosen row, with what he has gathered.
##   SAVE       everything, and WHERE he stands (GameState.spot).
##   LOAD       the level again, from where he last saved (asks twice).
##   ABILITIES  his powers (Abilities.POWERS) on a ROADMAP: he carries TWO —
##              pick one and press Space (or tap CARRY) to put it in a slot or
##              take it out. The two show as circles at the bottom of the screen.
##   TUTORIAL   his special moves (Abilities.MOVES), a roadmap too.
## On a roadmap the stops he has unlocked glow sun-gold on a lit trail; locked
## ones are slate and padlocked on a dotted one, the next to get pulsing. The
## card on the right shows the chosen one up close.
##
## Keys: arrows / WASD choose, Space / Enter / J pick, Esc / K back, Tab / M
## close. Mouse and touch: hover or tap.

const INK := Color("f3e3c3")
const DIM := Color("a8957a")
const TEAL := Color("3ee0c8")
const AMBER := Color("ffae42")
const MAGENTA := Color("ff4fd8")
const LIME := Color("9be15d")
const SKY := Color("7fb8ff")
const ITEMS := [
	["resume", "RESUME", "Back to the night, right where he is.", INK],
	["save", "SAVE", "Keep everything he has found, and the spot where he stands.", TEAL],
	["load", "LOAD", "Wake up where he last saved.", SKY],
	["abilities", "ABILITIES", "His powers, and the road to unlocking them. He carries TWO.", MAGENTA],
	["tutorial", "SPECIAL MOVES", "Every move he knows, and how to do it.", LIME],
	["shelter", "UGU'S CAVE", "His home, between the eras: cook, trade with Kekko, see what he has brought back.", AMBER],
	["restart", "RESTART LEVEL", "Start this level again from the very beginning. What he has found stays found.", Color("ff8a5c")],
	["exit", "EXIT GAME", "Close the game. Everything earned is already kept; SAVE first to keep his spot.", Color("d8c8b0")],
]
const LIST := Vector2(72, 196)              ## the top left of the list
const ROW := Vector2(400, 44)               ## one row of it
const ROW_GAP := 52.0
const CARD := Rect2(528, 196, 690, 384)     ## the card about the chosen row
const VIEW_BTN := Rect2(72, 626, 400, 44)   ## VIEW: CLOSE / NORMAL / WIDE (also the V key)
const MYST_BOX := Rect2(528, 596, 690, 74)  ## the MYSTERIES note, under the card
const CLOSE := Rect2(1150, 24, 110, 44)
const MAP := Rect2(36, 150, 632, 486)       ## a roadmap's panel
const INFO := Rect2(700, 150, 540, 486)     ## the card about the chosen stop
const CARRY := Rect2(820, 584, 300, 40)     ## the CARRY IT / PUT IT DOWN button
const STOP_R := 26.0                        ## a stop on the roadmap
const TOP := 214.0                          ## the first row of stops
## The mysteries he has run into (GameState.mysteries): [while open, once solved].
const MYSTERIES := {
	"shovel": ["The Dig's clay needs a SHOVEL. The painting by the clay shows where it went.", "The shovel was in the thorns, up in the windy sky."],
	"windbreak": ["Shivers, at the foot of the mountain, is freezing. A wall against the wind?", "Shivers has a windbreak, and is Grog again. Toasty!"],
	"pip": ["Pip's baby goat Baa is stuck up a tall rock. A ladder?", "Baa is down, safe in Pip's arms. MEHHH!"],
	"taka": ["Taka the hunter tripped over a snail. His foot needs a salve.", "Taka's foot is fixed. Wiggle wiggle!"],
	"ooma": ["Old Ooma sits in the Long Dark. Her fire needs a spark.", "Ooma's fire burns in the Long Dark."],
	"one_eye": ["A giant one-eyed worm lives under the Dig, in the Root Hollows. It hates LIGHT: a GLARE TRAP?", "Old One-Eye is beaten! The mountain is quiet."],
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
var _confirm := 0.0         ## > 0: LOAD was pressed once; again loads
var _box: StyleBoxFlat


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
	_name = _label(Vector2(720, 336), Vector2(500, 44), 32, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_name.add_theme_font_override("font", Pal.title_font())
	_status = _label(Vector2(720, 380), Vector2(500, 26), 16, Sunfire.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_desc = _label(Vector2(740, 410), Vector2(460, 100), 16, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_keys = _label(Vector2(740, 514), Vector2(460, 24), 16, Sunfire.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_how = _label(Vector2(740, 540), Vector2(460, 40), 14, DIM, HORIZONTAL_ALIGNMENT_CENTER)
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
	_confirm = 0.0
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
	_confirm = maxf(_confirm - delta, 0.0)
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
					KEY_UP, KEY_W, KEY_LEFT, KEY_A:
						_select((_sel + ITEMS.size() - 1) % ITEMS.size())
					KEY_DOWN, KEY_S, KEY_RIGHT, KEY_D:
						_select((_sel + 1) % ITEMS.size())
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
						_step_row(-1)
					KEY_DOWN, KEY_S:
						_step_row(1)
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
				_select(hit)
			elif _grid() and hit != _pick:
				_pick = hit
				_show_ability()
	elif (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
			or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		var at2: Vector2 = event.position
		if _page == "main" and VIEW_BTN.has_point(at2):
			_cycle_view()
		elif CLOSE.has_point(at2):
			if _page == "main":
				_close()
			else:
				_go("main")
		else:
			var hit2 := _hit(at2)
			if _page == "main" and hit2 >= 0:
				_select(hit2)
				_choose(hit2)
			elif _page == "abilities" and CARRY.has_point(at2):
				_carry()
			elif _grid() and hit2 >= 0:
				if _page == "abilities" and hit2 == _pick:
					_carry()                # a second tap on the chosen one carries it
				_pick = hit2
				_show_ability()
		get_viewport().set_input_as_handled()


## Which tablet / medallion is under the pointer (-1: none).
func _hit(at: Vector2) -> int:
	if _page == "main":
		for i in ITEMS.size():
			if _row_rect(i).has_point(at):
				return i
	elif _grid():
		for i in _list().size():
			if at.distance_to(_medal_at(i)) < STOP_R + 12.0:
				return i
	return -1


func _select(i: int) -> void:
	if i != _sel:
		_confirm = 0.0
	_sel = i


func _choose(i: int) -> void:
	_choose_id(ITEMS[i][0])


func _choose_id(id: String) -> void:
	match id:
		"resume":
			if player == null or not player.dead:
				_close()
		"restart", "exit":
			if _confirm <= 0.0:
				_confirm = 3.0                # once more to really do it
				return
			get_tree().paused = false
			if id == "exit":
				get_tree().quit()
			else:
				get_tree().reload_current_scene()
		"save":
			var level := _level()
			if level != null:
				level.save_spot()
			else:
				GameState.save()
			_saved_t = 0.0
		"load":
			if GameState.spot.is_empty() or _level() == null:
				return
			if _confirm <= 0.0:
				_confirm = 3.0                # once more to really load
				return
			_level().load_spot()
		"shelter":
			if GameState.home_unlocked() and _level() != null:
				_level().go_home()
		"abilities", "tutorial":
			_go(id)


func row_of(id: String) -> int:
	for i in ITEMS.size():
		if ITEMS[i][0] == id:
			return i
	return 0


func _level() -> LevelBase:
	return player.get_parent() as LevelBase if player != null else null


## ------------------------------------------------------------------ layout
func _row_rect(i: int) -> Rect2:
	return Rect2(LIST + Vector2(0, i * ROW_GAP), ROW)


## Stops along a row of the roadmap: five on the long one, three on a short one.
func _cols() -> int:
	return 5 if _list().size() > 9 else 3


## The road snakes: left to right, then back right to left on the next row.
func _medal_at(i: int) -> Vector2:
	var cols := _cols()
	var row := i / cols
	var col := i % cols
	if row % 2 == 1:
		col = cols - 1 - col
	var x0 := MAP.position.x + 88.0
	var x1 := MAP.end.x - 88.0
	return Vector2(x0 + (x1 - x0) * col / (cols - 1), TOP + row * (118.0 if cols == 5 else 128.0))


## Up or down a row of the roadmap: the stop nearest straight above / below.
func _step_row(d: int) -> void:
	var cols := _cols()
	var n := _list().size()
	var row := _pick / cols + d
	if row < 0 or row * cols >= n:
		return
	var x := _medal_at(_pick).x
	var best := _pick
	var bd := INF
	for i in range(row * cols, mini((row + 1) * cols, n)):
		var dx := absf(_medal_at(i).x - x)
		if dx < bd:
			bd = dx
			best = i
	_pick = best
	_show_ability()


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
	var bg := Batch.new()
	_draw_cave(bg)
	bg.draw(_view)
	var b := Batch.new()             # the panels go straight on the view, between the two
	match _page:
		"main":
			_draw_main(b)
		"abilities", "tutorial":
			_draw_grid(b)
	# embers over everything, in fire colours with a few magic ones
	for e in _embers:
		var hue: float = e[3]
		var col := Color.from_hsv(0.04 + hue * 0.1, 0.8, 1.0) if hue < 0.85 else Color.from_hsv(randf(), 0.6, 1.0)
		var life: float = clampf(float(e[2]) / 2.0, 0.0, 1.0)
		b.circle(e[0], 2.2 + hue * 1.6, Color(col, 0.75 * life), 6)
	# the close button
	b.circle(CLOSE.get_center(), 20.0, Color(0, 0, 0, 0.4), 18)
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


## A rounded panel, straight on the view (under the batch drawn after it).
func _panel(r: Rect2, edge: Color, fill: Color = Color(0.07, 0.045, 0.035, 0.84)) -> void:
	if _box == null:
		_box = StyleBoxFlat.new()
		_box.set_border_width_all(2)
		_box.set_corner_radius_all(12)
		_box.shadow_color = Color(0, 0, 0, 0.4)
		_box.shadow_size = 8
		_box.shadow_offset = Vector2(0, 4)
	_box.bg_color = fill
	_box.border_color = edge
	_view.draw_style_box(_box, r)


## The list on the left, the card about the chosen row on the right.
func _draw_main(b: Batch) -> void:
	b.rect(Rect2(LIST.x, 170, CARD.end.x - LIST.x, 2), Color(Sunfire.GOLD, 0.35))
	for i in ITEMS.size():
		var r := _row_rect(i)
		var accent: Color = ITEMS[i][3]
		var on := i == _sel
		var enter := clampf((_page_t - i * 0.05) / 0.3, 0.0, 1.0)
		r.position.x -= 40.0 * pow(1.0 - enter, 3.0)
		if on:
			_panel(r.grow(2.0), accent, Color(accent.darkened(0.72), 0.94))
			b.rect(Rect2(r.position + Vector2(10, 12), Vector2(4, r.size.y - 24)), accent)
		else:
			_panel(r, Color(1, 1, 1, 0.07), Color(0.06, 0.04, 0.03, 0.62))
		var lit := 1.0 if on else (0.25 if _row_off(i) else 0.6)
		_symbol(b, ITEMS[i][0], r.position + Vector2(44, r.size.y * 0.5), 14.0, Color(accent, lit), _t * 1.6 if on else 0.0)
	# the card
	var item: Array = ITEMS[_sel]
	var accent2: Color = item[3]
	_panel(CARD, Color(accent2, 0.55))
	var mc := CARD.position + Vector2(130, 150)
	var pop := 1.0 + 0.12 * maxf(0.0, 1.0 - _page_t * 5.0)
	b.circle(mc, 84.0, Color(accent2, 0.08 + 0.04 * sin(_t * 3.0)), 36)
	b.circle(mc, 72.0 * pop, Color(0.08, 0.05, 0.05, 0.9), 40)
	b.arc(mc, 72.0 * pop, 0.0, TAU, 48, accent2, 3.0)
	for d in 12:
		var a := d * TAU / 12.0 + _t * 0.5
		b.circle(mc + Vector2.from_angle(a) * 82.0, 2.5, Color(accent2, 0.7), 6)
	_symbol(b, item[0], mc, 48.0 * pop, accent2, _t * 1.6)
	if _saved_t >= 0.0:
		var sz := 2.0 - clampf(_saved_t / 0.18, 0.0, 1.0)
		for r2 in 10:
			var a3 := r2 * TAU / 10.0 + _saved_t * 2.0
			b.line(mc + Vector2.from_angle(a3) * 50.0 * sz, mc + Vector2.from_angle(a3) * (90.0 + 50.0 * _saved_t) * sz, Color(TEAL, 0.8 * (1.0 - _saved_t / 1.8)), 5.0)
	if item[0] == "load" and _confirm > 0.0:
		b.rect(Rect2(CARD.position + Vector2(260, 236), Vector2(400.0 * _confirm / 3.0, 3)), SKY)
	# what he has gathered, along the bottom of the card
	var sy := CARD.end.y - 76.0
	b.rect(Rect2(CARD.position.x + 24, sy, CARD.size.x - 48, 1), Color(1, 1, 1, 0.12))
	for i in 3:
		var sx := CARD.position.x + CARD.size.x * (i + 1) / 4.0
		b.rect(Rect2(sx, sy + 16, 1, 44), Color(1, 1, 1, 0.1))
	# the VIEW button
	_panel(VIEW_BTN.grow(_view_flash * 6.0), Color(TEAL, 0.35 + _view_flash), Color(0.06, 0.04, 0.03, 0.62))
	for i in 3:
		var on2: bool = ["close", "normal", "wide"][i] == GameState.view_name()
		b.rect(Rect2(VIEW_BTN.position + Vector2(320.0 + i * 22.0, 14.0 + (2 - i) * 4.0), Vector2(14.0, 16.0 - (2 - i) * 4.0)), TEAL if on2 else Color(1, 1, 1, 0.25))
	if not GameState.mysteries.is_empty():
		_panel(MYST_BOX, Color(AMBER, 0.45))


## A row that can't do anything now (LOAD with nothing saved, RESUME when he
## did not make it).
func _row_off(i: int) -> bool:
	match ITEMS[i][0]:
		"load":
			return GameState.spot.is_empty()
		"shelter":
			return not GameState.home_unlocked()
		"resume":
			return player != null and player.dead
	return false


## The little note at the right end of a row.
func _row_note(id: String) -> String:
	match id:
		"save", "load":
			return str(GameState.spot.get("when", "")).substr(11) if not GameState.spot.is_empty() else ("" if id == "save" else "nothing yet")
		"abilities":
			return "%d / %d" % [_unlocked(Abilities.POWERS), Abilities.POWERS.size()]
		"tutorial":
			return "%d / %d" % [_unlocked(Abilities.MOVES), Abilities.MOVES.size()]
		"shelter":
			return "" if GameState.home_unlocked() else "LOCKED"
		"restart", "exit":
			return "press twice" if _confirm > 0.0 and ITEMS[_sel][0] == id else ""
	return ""


## The line under the card's words: where, when, how many.
func _card_note(id: String) -> String:
	var when := "%s,  %s" % [str(GameState.spot.get("title", "")).replace("   ", " · "), str(GameState.spot.get("when", ""))]
	match id:
		"resume":
			return "He did not make it: RESTART LEVEL, or LOAD." if player != null and player.dead else level_name.replace("   ", " · ")
		"save":
			return "Last saved: " + when if not GameState.spot.is_empty() else "Not saved yet."
		"load":
			if GameState.spot.is_empty():
				return "Nothing saved yet: SAVE first."
			if _confirm > 0.0:
				return "Press again to load. Steps since the save are lost; what he found stays found."
			return "Saved: " + when
		"restart":
			return "Press again to restart the level." if _confirm > 0.0 else "Treasure he found stays found."
		"exit":
			return "Press again to close the game." if _confirm > 0.0 else ""
		"abilities":
			var names: Array = []
			for c in Abilities.slots(player):
				names.append(Abilities.row(c)[1])
			return "Carrying: " + (", ".join(names) if not names.is_empty() else "nothing yet")
		"tutorial":
			return "%d of %d moves learned." % [_unlocked(Abilities.MOVES), Abilities.MOVES.size()]
		"shelter":
			return ("Bones gathered: %d. Walk in!" % GameState.bones) if GameState.home_unlocked() else "Drive Old Scar off (finish Level 2) to open it."
	return ""


func _unlocked(list: Array) -> int:
	var n := 0
	for r in list:
		if Abilities.unlocked(r[0], player):
			n += 1
	return n


func _relic_count() -> int:
	var n := 0
	for k in GameState.relics:
		n += int(GameState.relics[k])
	return n


## A stop's short name on the roadmap: "LAUNCH, JUGGLE..." is LAUNCH.
func _short(name: String) -> String:
	return name.split(",")[0].split(":")[0]


func _symbol(b: Batch, id: String, c: Vector2, r: float, col: Color, t: float) -> void:
	match id:
		"resume":
			_symbol_resume(b, c, r, col, t)
		"save":
			_symbol_save(b, c, r, col, t)
		"load":
			_symbol_load(b, c, r, col, t)
		"shelter":
			_symbol_shelter(b, c, r, col, t)
		"abilities":
			_symbol_abilities(b, c, r, col, t)
		"tutorial":
			_symbol_tutorial(b, c, r, col, t)
		"restart":
			_symbol_restart(b, c, r, col, t)
		"exit":
			_symbol_exit(b, c, r, col, t)


## Round again: an arrow chasing its own tail.
func _symbol_restart(b: Batch, c: Vector2, r: float, col: Color, t: float) -> void:
	var a0 := -t * 1.5
	var w := maxf(0.14 * r, 2.5)
	b.arc(c, 0.6 * r, a0, a0 + TAU * 0.78, 24, col, w)
	var tip := c + Vector2.from_angle(a0) * 0.6 * r
	var back := Vector2.from_angle(a0 - PI * 0.5)       # the way the arc is heading at its start
	var side := Vector2.from_angle(a0)
	b.tri(tip + back * 0.36 * r, tip + side * 0.3 * r, tip - side * 0.3 * r, col)


## The way out: the cave mouth, and a little arrow going through it.
func _symbol_exit(b: Batch, c: Vector2, r: float, col: Color, t: float) -> void:
	var w := maxf(0.12 * r, 2.0)
	b.polyline(PackedVector2Array([c + Vector2(0.1, -0.75) * r, c + Vector2(-0.6, -0.75) * r, c + Vector2(-0.6, 0.75) * r, c + Vector2(0.1, 0.75) * r]), col, w)
	var push := fmod(t * 0.5, 1.0) * 0.15 * r
	b.line(c + Vector2(-0.2 * r + push, 0), c + Vector2(0.5 * r + push, 0), col, w)
	b.tri(c + Vector2(0.85 * r + push, 0), c + Vector2(0.45 * r + push, -0.32 * r), c + Vector2(0.45 * r + push, 0.32 * r), col)


## On his way again: a fat arrow, with streaks of speed behind it.
func _symbol_resume(b: Batch, c: Vector2, r: float, col: Color, t: float) -> void:
	var push := sin(t * 3.0) * 0.06 * r
	b.tri(c + Vector2(-0.3 * r + push, -0.62 * r), c + Vector2(0.7 * r + push, 0), c + Vector2(-0.3 * r + push, 0.62 * r), col)
	for i in 3:
		var y := (-0.3 + i * 0.3) * r
		b.line(c + Vector2(-0.9 * r, y), c + Vector2(-0.5 * r, y), Color(col, col.a * 0.6), maxf(0.1 * r, 2.0))


## The pot of memory, its spiral turning back, and him rising out of it.
func _symbol_load(b: Batch, c: Vector2, r: float, col: Color, t: float) -> void:
	var pot := PackedVector2Array([c + Vector2(-0.5, 0.85) * r, c + Vector2(-0.75, 0.3) * r, c + Vector2(-0.55, -0.15) * r,
		c + Vector2(0.55, -0.15) * r, c + Vector2(0.75, 0.3) * r, c + Vector2(0.5, 0.85) * r])
	b.poly(pot, Color(Color("a4623a"), col.a))
	var sp := PackedVector2Array()
	for i in 24:
		var q := i / 23.0
		sp.append(c + Vector2(0, 0.38 * r) + Vector2.from_angle(-q * TAU * 1.6 - t * 2.0) * (2.0 + q * 0.3 * r))
	b.polyline(sp, col, maxf(0.08 * r, 2.0))
	var up := fmod(t * 0.5, 1.0) * 0.12 * r
	b.tri(c + Vector2(0, -0.95 * r - up), c + Vector2(0.32 * r, -0.5 * r - up), c + Vector2(-0.32 * r, -0.5 * r - up), col)
	b.rect(Rect2(c + Vector2(-0.1 * r, -0.52 * r - up), Vector2(0.2 * r, 0.3 * r)), col)


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


## A roadmap (the powers, or the moves): stops along a snaking trail, lit as
## far as he has got, and the chosen one up close on the card at the right.
func _draw_grid(b: Batch) -> void:
	var list := _list()
	var carried := Abilities.slots(player)
	var n := list.size()
	var open: Array = []
	for i in n:
		open.append(Abilities.unlocked(list[i][0], player))
	var got := open.count(true)
	var next := open.find(false)              # the next stop to unlock pulses
	var pid: String = list[_pick][0]
	var popen: bool = open[_pick]
	var tint := (Abilities.colour(pid) if _page == "abilities" else Abilities.GOLD) if popen else Abilities.SLATE
	_panel(MAP, Color(1, 1, 1, 0.08), Color(0.05, 0.035, 0.03, 0.72))
	_panel(INFO, Color(tint, 0.55))
	for i in n - 1:
		_road(b, i, open[i] and open[i + 1])
	for i in n:
		_stop(b, i, list[i][0], open[i], i == next, carried)
	if _page == "abilities":
		_draw_slots(b, carried)
	# the chosen one, up close
	var bc := Vector2(INFO.get_center().x, 262)
	var pop := 1.0 + 0.2 * maxf(0.0, 1.0 - _page_t * 4.0)
	if popen:
		for i in 16:
			var a := i * TAU / 16.0 + _t * 0.4
			b.tri(bc + Vector2.from_angle(a + 0.1) * 62.0, bc + Vector2.from_angle(a) * (90.0 + 8.0 * sin(_t * 4.0 + i)), bc + Vector2.from_angle(a - 0.1) * 62.0, Color(tint, 0.22))
		b.circle(bc, 58.0 * pop, Color("2a1a12"), 40)
		b.arc(bc, 58.0 * pop, 0.0, TAU, 48, Abilities.GOLD, 4.0)
		Abilities.draw_symbol(b, pid, bc, 46.0 * pop, Abilities.GOLD, _t * 1.6)
	else:
		b.circle(bc, 58.0, Color("1c1e25"), 40)
		b.arc(bc, 58.0, 0.0, TAU, 48, Abilities.SLATE, 3.0)
		Abilities.draw_symbol(b, pid, bc, 40.0, Color(Abilities.SLATE, 0.5), 0.0)
		_padlock(b, bc + Vector2(40, 40), 1.6)
	# the CARRY IT / PUT IT DOWN button
	if _page == "abilities" and popen:
		var on2 := carried.has(pid)
		var col := Abilities.colour(pid)
		var glow := 0.5 + 0.5 * sin(_t * 4.0)
		_panel(CARRY.grow(0.0 if on2 else 2.0 * glow), Color(col, 0.9), col.darkened(0.6) if on2 else col.darkened(0.25))
	_counter = "%d / %d unlocked" % [got, n]


## The trail from stop i to the next: straight along a row, a U-turn at its end.
func _road(b: Batch, i: int, lit: bool) -> void:
	var a := _medal_at(i)
	var c := _medal_at(i + 1)
	var bulge := Vector2.ZERO
	if absf(a.y - c.y) > 1.0:
		bulge = Vector2((1.0 if a.x > MAP.get_center().x else -1.0) * 70.0, 0.0)
	var pts := PackedVector2Array()
	for k in 21:
		var q := k / 20.0
		var u := 1.0 - q
		pts.append(a * u * u * u + (a + bulge) * 3.0 * u * u * q + (c + bulge) * 3.0 * u * q * q + c * q * q * q)
	if lit:
		b.polyline(pts, Color(Abilities.GOLD.darkened(0.6), 0.9), 9.0)
		b.polyline(pts, Abilities.GOLD, 4.0)
		for s in 2:                           # sparks running along it
			var q2 := fmod(_t * 0.45 + s * 0.5 + i * 0.17, 1.0)
			b.circle(pts[int(q2 * 20.0)], 3.0, Color(1.0, 0.95, 0.75, 0.9), 6)
		return
	b.polyline(pts, Color(0, 0, 0, 0.35), 6.0)
	var gap := 0.0                            # a dotted trail, a dot every 13 px
	for k in pts.size() - 1:
		var seg := pts[k].distance_to(pts[k + 1])
		while gap <= seg:
			b.circle(pts[k].lerp(pts[k + 1], gap / seg), 2.5, Color(Abilities.SLATE, 0.85), 6)
			gap += 13.0
		gap -= seg


## One stop on the road: gold and glowing if he has it, slate and padlocked
## if not; a badge with its slot number if he carries it.
func _stop(b: Batch, i: int, id: String, open: bool, next: bool, carried: Array) -> void:
	var on := i == _pick
	var enter := clampf((_page_t - i * 0.03) / 0.25, 0.0, 1.0)
	var c := _medal_at(i)
	var r := STOP_R * (1.15 if on else 1.0) * (0.3 + 0.7 * (1.0 - pow(1.0 - enter, 3.0)))
	b.circle(c + Vector2(2, 4), r + 3.0, Color(0, 0, 0, 0.45), 24)
	if open:
		b.circle(c, r + 7.0 + 2.0 * sin(_t * 3.0 + i), Color(Abilities.GOLD, 0.14), 24)
		b.circle(c, r, Color("2a1a12"), 28)
		b.circle(c, r * 0.86, Color("3b2619"), 28)
		b.arc(c, r, 0.0, TAU, 32, Abilities.GOLD, 3.0)
		Abilities.draw_symbol(b, id, c, r * 0.7, Abilities.GOLD, _t * (1.4 if on else 0.5) + i)
	else:
		if next:
			var q := fmod(_t * 0.8, 1.0)
			b.arc(c, r + 4.0 + 12.0 * q, 0.0, TAU, 32, Color(Abilities.GOLD, 0.6 * (1.0 - q)), 2.0)
		b.circle(c, r, Color("1c1e25"), 28)
		b.circle(c, r * 0.86, Color("262933"), 28)
		b.arc(c, r, 0.0, TAU, 32, Color(Abilities.GOLD, 0.6) if next else Abilities.SLATE, 2.5)
		Abilities.draw_symbol(b, id, c, r * 0.66, Color(Abilities.SLATE, 0.55), 0.0)
		_padlock(b, c + Vector2(r * 0.68, r * 0.68), 1.0)
	var slot := carried.find(id) if _page == "abilities" else -1
	if slot >= 0:
		var bp := c + Vector2(r * 0.72, -r * 0.72)
		b.circle(bp, 11.0, Color(0, 0, 0, 0.5), 14)
		b.circle(bp, 9.5, Abilities.colour(id), 14)
	if on:
		for d in 14:
			var a := d * TAU / 14.0 + _t * 1.5
			b.circle(c + Vector2.from_angle(a) * (r + 9.0), 2.5, Color(INK, 0.9) if d % 2 == 0 else Color(MAGENTA if _page == "abilities" else LIME, 0.9), 6)


func _padlock(b: Batch, at: Vector2, s: float) -> void:
	b.circle(at, 10.0 * s, Color("15161b"), 14)
	b.arc(at + Vector2(0, -2.0 * s), 4.5 * s, PI, TAU, 8, Color("a3a9b8"), 2.0 * s)
	b.rect(Rect2(at + Vector2(-6.0, -2.0) * s, Vector2(12.0, 8.0) * s), Color("a3a9b8"))


## The two slots under the road: what he carries, in their own colours —
## the same circles he sees at the bottom of the screen in the game.
func _draw_slots(b: Batch, carried: Array) -> void:
	for i in Abilities.SLOTS:
		var c := _slot_at(i)
		if i < carried.size():
			var id: String = carried[i]
			var col := Abilities.colour(id)
			var pulse := 1.0 + (0.12 * absf(_flash) / 0.6 if i == carried.size() - 1 else 0.0)
			for g in 3:
				b.circle(c, (38.0 + g * 5.0 + 3.0 * sin(_t * 4.0 + i)) * pulse, Color(col, 0.13 - g * 0.035), 28)
			b.circle(c, 34.0 * pulse, Color("2a1a12"), 30)
			b.arc(c, 34.0 * pulse, 0.0, TAU, 36, col, 3.5)
			Abilities.draw_symbol(b, id, c, 24.0 * pulse, col, _t * 1.5)
		else:
			for d in 16:
				var a := d * TAU / 16.0 + _t * 0.3
				b.circle(c + Vector2.from_angle(a) * 34.0, 2.5, Color(1, 1, 1, 0.3), 6)


func _slot_at(i: int) -> Vector2:
	return Vector2(MAP.get_center().x - 70.0 + i * 140.0, 540.0)


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




## Text drawn straight on the view (titles, names, the cards, hints).
func _texts() -> void:
	var f := ThemeDB.fallback_font
	var tf := Pal.title_font()
	match _page:
		"main":
			_left(tf, "THE CAMP", Vector2(LIST.x, 132), 58, Sunfire.GOLD, true)
			_view.draw_string(f, Vector2(LIST.x, 132), level_name, HORIZONTAL_ALIGNMENT_RIGHT, CARD.end.x - LIST.x, 17, DIM)
			for i in ITEMS.size():
				var it: Array = ITEMS[i]
				var r := _row_rect(i)
				r.position.x -= 40.0 * pow(1.0 - clampf((_page_t - i * 0.05) / 0.3, 0.0, 1.0), 3.0)
				var on := i == _sel
				var col := INK if on else (Color(DIM, 0.5) if _row_off(i) else DIM.lightened(0.15))
				_left(tf, it[1], r.position + Vector2(76, 31), 21, col, on)
				_view.draw_string(f, r.position + Vector2(0, 28), _row_note(it[0]), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 18.0, 14, Color(it[3], 0.85 if on else 0.5))
			# the card
			var item: Array = ITEMS[_sel]
			var tx := CARD.position + Vector2(260, 0)
			var tw := CARD.size.x - 290.0
			_left(tf, item[1], tx + Vector2(0, 98), 40, item[3], true)
			_view.draw_multiline_string(f, tx + Vector2(0, 134), item[2], HORIZONTAL_ALIGNMENT_LEFT, tw, 18, -1, INK)
			_view.draw_multiline_string(f, tx + Vector2(0, 204), _card_note(item[0]), HORIZONTAL_ALIGNMENT_LEFT, tw, 16, -1, Sunfire.GOLD if _confirm > 0.0 else DIM)
			if _saved_t >= 0.0:
				var a := clampf(1.0 - (_saved_t - 1.2) / 0.6, 0.0, 1.0)
				var sz := int(40.0 * (2.0 - clampf(_saved_t / 0.18, 0.0, 1.0)))
				_centred(tf, "SAVED!", CARD.position + Vector2(130, 164), sz, Color(TEAL.lightened(0.3), a), true)
			var stats := [["SHELLS", GameState.shells], ["SPIRIT ORBS", GameState.orbs], ["BONES", GameState.bones], ["RARE FINDS", _relic_count()]]
			for i in stats.size():
				var cx := CARD.position.x + CARD.size.x * (i + 0.5) / 4.0
				_centred(tf, str(stats[i][1]), Vector2(cx, CARD.end.y - 26.0), 26, INK, true)
				_centred(f, stats[i][0], Vector2(cx, CARD.end.y - 54.0), 12, DIM, false)
			_view.draw_string(f, VIEW_BTN.position + Vector2(18, 28), "VIEW:  %s" % GameState.view_name().to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
			_view.draw_string(f, VIEW_BTN.position + Vector2(0, 28), "V", HORIZONTAL_ALIGNMENT_RIGHT, 300.0, 14, DIM)
			if not GameState.mysteries.is_empty():
				_view.draw_string(tf, MYST_BOX.position + Vector2(16, 24), "MYSTERIES", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, AMBER)
				var y := 44.0
				var order: Array = GameState.mysteries.keys()      # the open ones first: only two lines fit
				order.sort_custom(func(a, b) -> bool: return GameState.mysteries[a] != "solved" and GameState.mysteries[b] == "solved")
				for id in order:
					if not MYSTERIES.has(id) or y > 62.0:
						continue
					var solved: bool = GameState.mysteries[id] == "solved"
					var line: String = (MYSTERIES[id] as Array)[1 if solved else 0]
					_view.draw_string(f, MYST_BOX.position + Vector2(16, y), ("✓ " if solved else "? ") + line, HORIZONTAL_ALIGNMENT_LEFT, MYST_BOX.size.x - 32.0, 13, Color("9be15d") if solved else INK)
					y += 19.0
			_centred(f, "↑ ↓  choose      SPACE  select      V  view      ESC  back to the game", Vector2(640, 700), 15, DIM, false)
		"abilities", "tutorial":
			var title := "ABILITIES" if _page == "abilities" else "SPECIAL MOVES"
			var mx := MAP.get_center().x
			_centred(tf, title, Vector2(mx, 96), 46, Sunfire.GOLD if _page == "abilities" else LIME, true)
			_centred(f, _counter + ("  ·  he carries TWO" if _page == "abilities" else "  ·  always his, once learned"), Vector2(mx, 128), 17, DIM, false)
			var list := _list()
			var carried := Abilities.slots(player)
			for i in list.size():
				var open := Abilities.unlocked(list[i][0], player)
				var r := STOP_R * (1.15 if i == _pick else 1.0)
				var c := _medal_at(i)
				_centred(f, _short(list[i][1]), c + Vector2(0, r + 20.0), 12, (INK if i == _pick else DIM.lightened(0.2)) if open else Color(DIM, 0.6), false)
				var slot := carried.find(list[i][0]) if _page == "abilities" else -1
				if slot >= 0:
					_centred(f, str(slot + 1), c + Vector2(r * 0.72, -r * 0.72 + 5.0), 13, Color.BLACK, false)
			if _page == "abilities":
				_centred(tf, "CARRIED", Vector2(mx, 488), 16, INK, true)
				for i in Abilities.SLOTS:
					_centred(f, str(i + 1), _slot_at(i) + Vector2(0, 56), 13, DIM, false)
				var pr: Array = list[_pick]
				if Abilities.unlocked(pr[0], player):
					var label := "PUT IT DOWN" if carried.has(pr[0]) else ("CARRY IT" if carried.size() < Abilities.SLOTS else "CARRY IT (swap)")
					_centred(tf, label + "   SPACE", CARRY.get_center() + Vector2(0, 7), 18, INK, true)
			_centred(f, "ARROWS  choose" + ("      SPACE  carry" if _page == "abilities" else "") + "      ESC  back", Vector2(mx, 668), 15, DIM, false)


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



func _left(f: Font, text: String, at: Vector2, size: int, col: Color, shadow: bool) -> void:
	if shadow:
		_view.draw_string(f, at + Vector2(3, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.6 * col.a))
	_view.draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
