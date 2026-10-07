class_name Dialogue
extends CanvasLayer
## A conversation, or a moment of narration, in a compact box at the bottom
## of the screen: a coloured name tag for who is speaking, their words typed
## out, and a blinking prompt. While it runs he stands still and can't be
## hurt, and his torch waits.
## Space, Enter, J or E, a click or a tap: finish the line, then go on.
##
## lines: [[speaker, text], ...] — or [speaker, text, callable] to make
## something happen as that line appears (a box opening, a gem changing hands).
## An empty speaker is narration.
##
## A CHOICE is a Dictionary in the list: {"choose": [[answer, [lines...]], ...]}.
## He picks an answer (Up/Down or W/S or 1-3, then Space/Enter/J/E; or click or
## tap it); the answer is said as his line, and that answer's lines follow.
## Calling _next() while a choice is up picks the highlighted one (the first,
## unless moved), so scripted runs go straight through.

signal finished
signal line_started(speaker: String)

const TYPE_SPEED := 60.0      ## characters per second
const GUARD := 0.25           ## ignore presses this soon after a line appears
const W := 620.0
const PAD := 14.0
## Name tags: each talker has a colour.
const TAGS := {"CAVEMAN": Color("b9772f"), "OLD BONGO": Color("c9a93e"), "TOOLMAKER": Color("c75a33"),
	"MOSS": Color("6f9a52"), "NUTMEG": Color("9a6a3e"), "SHIVERS": Color("8fc8e8")}

var lines: Array = []
var player: CaveMan
var _i := -1
var _shown := 0.0
var _age := 0.0
var _box: Panel
var _tag: Panel
var _name: Label
var _text: Label
var _more: Label
var _opts: Array = []           ## the answer rows while choosing
var _choices: Array = []        ## [[answer, lines], ...] while choosing
var _sel := 0


func _ready() -> void:
	layer = 6
	add_to_group("dialogue")
	_box = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Pal.CHARCOAL, 0.9)
	sb.border_color = Color(Pal.OCHRE, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	_box.add_theme_stylebox_override("panel", sb)
	add_child(_box)
	# the name tag sits on the box's top edge, like a label on a jar
	_tag = Panel.new()
	_box.add_child(_tag)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 14)
	_name.add_theme_color_override("font_color", Pal.CHARCOAL)
	_tag.add_child(_name)
	_text = Label.new()
	_text.position = Vector2(PAD + 4, 20)
	_text.size = Vector2(W - PAD * 2 - 24, 50)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 18)
	_text.add_theme_color_override("font_color", Pal.BONE)
	_box.add_child(_text)
	_more = Label.new()
	_more.text = "▸"
	_more.add_theme_font_size_override("font_size", 18)
	_more.add_theme_color_override("font_color", Pal.OCHRE)
	_box.add_child(_more)
	if player != null:
		player.talking = true
	_next()


## Size the box to its contents and keep it centred at the bottom.
func _layout(h: float) -> void:
	_box.size = Vector2(W, h)
	_box.position = Vector2((1280.0 - W) * 0.5, 720.0 - 16.0 - h)
	_more.position = Vector2(W - 26, h - 30)


func _show_tag(who: String) -> void:
	_tag.visible = who != ""
	if who == "":
		return
	_name.text = who
	var col: Color = TAGS.get(who, Pal.OCHRE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(9)
	_tag.add_theme_stylebox_override("panel", sb)
	var w := _name.get_minimum_size().x + 20.0
	_tag.size = Vector2(w, 22)
	_tag.position = Vector2(PAD, -11)
	_name.position = Vector2(10, 1)


func _clear_options() -> void:
	for o in _opts:
		(o as Node).queue_free()
	_opts.clear()
	_choices = []


func _next() -> void:
	if not _choices.is_empty():
		_pick(_sel)
		return
	_i += 1
	if _i >= lines.size():
		if player != null:
			player.talking = false
		finished.emit()
		queue_free()
		return
	if lines[_i] is Dictionary:
		_ask(lines[_i]["choose"])
		return
	var line: Array = lines[_i]
	var who: String = line[0]
	_show_tag(who)
	_text.visible = true
	_text.text = line[1]
	# narration reads in a quieter colour
	_text.add_theme_color_override("font_color", Pal.BONE if who != "" else Pal.OCHRE.lightened(0.35))
	_text.size = Vector2(W - PAD * 2 - 24, 0)
	# measure the wrapped text with the font, so a two-line line gets a taller box
	var font := _text.get_theme_font("font")
	var th := font.get_multiline_string_size(_text.text, HORIZONTAL_ALIGNMENT_LEFT, W - PAD * 2 - 24, 18).y
	var h := maxf(th, 24.0) + 36.0
	_text.size = Vector2(W - PAD * 2 - 24, th + 4.0)
	_layout(h)
	_shown = 0.0
	_age = 0.0
	_text.visible_characters = 0
	line_started.emit(who)
	if line.size() > 2 and line[2] is Callable:
		(line[2] as Callable).call()


## Put up the answers he can give.
func _ask(choices: Array) -> void:
	_clear_options()
	_choices = choices
	_sel = 0
	_show_tag("CAVEMAN")
	_text.visible = false
	_more.visible = false
	for k in choices.size():
		var row := Label.new()
		row.text = "%d  %s" % [k + 1, choices[k][0]]
		row.position = Vector2(PAD + 4, 20 + k * 28)
		row.size = Vector2(W - PAD * 2 - 8, 26)
		row.add_theme_font_size_override("font_size", 18)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box.add_child(row)
		_opts.append(row)
	_layout(30.0 + choices.size() * 28.0)
	_age = 0.0
	_shown = 0.0
	_mark()
	line_started.emit("CAVEMAN")


## Highlight the chosen row.
func _mark() -> void:
	for k in _opts.size():
		var row: Label = _opts[k]
		var on := k == _sel
		row.add_theme_color_override("font_color", Pal.BONE if on else Color(Pal.BONE, 0.45))
		row.text = ("▸ " if on else "   ") + "%d  %s" % [k + 1, _choices[k][0]]


## He has chosen: his answer becomes his line, and its lines come after it.
func _pick(k: int) -> void:
	var c: Array = _choices[k]
	_clear_options()
	var follow: Array = [["CAVEMAN", c[0]]]
	follow.append_array(c[1] if c.size() > 1 else [])
	for j in follow.size():
		lines.insert(_i + 1 + j, follow[j])
	_next()


func _process(delta: float) -> void:
	_age += delta
	if not _choices.is_empty():
		return
	_shown += delta * TYPE_SPEED
	var total := _text.text.length()
	_text.visible_characters = mini(int(_shown), total)
	_more.visible = int(_shown) >= total and fmod(_age, 0.8) < 0.5


func _input(event: InputEvent) -> void:
	if not _choices.is_empty():
		_input_choice(event)
		return
	var press := false
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		press = k in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_J, KEY_E]
	elif event is InputEventMouseButton and event.pressed:
		press = true
	elif event is InputEventScreenTouch and event.pressed:
		press = true
	if not press:
		return
	get_viewport().set_input_as_handled()
	if _age < GUARD:
		return
	if int(_shown) < _text.text.length():
		_shown = float(_text.text.length())
	else:
		_next()


func _input_choice(event: InputEvent) -> void:
	var pick := -1
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k in [KEY_UP, KEY_W]:
			_sel = (_sel + _opts.size() - 1) % _opts.size()
			_mark()
		elif k in [KEY_DOWN, KEY_S]:
			_sel = (_sel + 1) % _opts.size()
			_mark()
		elif k >= KEY_1 and k < KEY_1 + _opts.size():
			pick = k - KEY_1
		elif k in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_J, KEY_E]:
			pick = _sel
	elif (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		# a click or tap on a row picks it
		var at: Vector2 = event.position
		for k in _opts.size():
			var row: Label = _opts[k]
			if Rect2(row.global_position - Vector2(6, 2), row.size + Vector2(12, 4)).has_point(at):
				pick = k
	elif event is InputEventMouseMotion:
		var at2: Vector2 = event.position
		for k in _opts.size():
			var row2: Label = _opts[k]
			if k != _sel and Rect2(row2.global_position - Vector2(6, 2), row2.size + Vector2(12, 4)).has_point(at2):
				_sel = k
				_mark()
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()
	if pick >= 0 and _age >= GUARD:
		_pick(pick)
