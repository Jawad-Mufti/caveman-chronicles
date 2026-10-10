extends CanvasLayer
## A small menu panel for the home (shelter/home.gd): Kekko's trades, the
## Toolmaker's upgrades, the workbench, the store. A title, a line about it,
## and rows: [label, right-hand note, can (bool), action (Callable) or null].
## Up / Down (W / S) choose, E / J / Enter does it, Esc / Q closes. `rows_fn` is
## called again after every action, so prices, stock and "can" stay true.

signal closed
signal acted(label: String)
signal refused                          ## a row he can't have (too dear, done)

var title := ""
var line := ""
var accent := Color("ffcf40")
var rows_fn: Callable
var _rows: Array = []
var _sel := 0
var _panel: Panel
var _title: Label
var _line: Label
var _list: VBoxContainer
var _foot: Label
var _note: Label
var _note_t := 0.0


func _ready() -> void:
	layer = 5
	_panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.07, 0.05, 0.93)
	sb.border_color = Color(accent, 0.9)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.position = Vector2(370, 120)
	_panel.size = Vector2(540, 440)
	add_child(_panel)
	_title = _label(Vector2(28, 16), Vector2(484, 44), 34, accent, Pal.title_font())
	_line = _label(Vector2(28, 62), Vector2(484, 48), 16, Color("d8c8b0"), Pal.text_font())
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list = VBoxContainer.new()
	_list.position = Vector2(20, 116)
	_list.size = Vector2(500, 260)
	_list.add_theme_constant_override("separation", 4)
	_panel.add_child(_list)
	_note = _label(Vector2(28, 362), Vector2(484, 30), 17, Color("9be15d"), Pal.text_font())
	_foot = _label(Vector2(28, 400), Vector2(484, 26), 14, Color("a8957a"), Pal.text_font())
	_foot.text = "Up / Down: choose      E: do it      Esc: close"
	_title.text = title
	_line.text = line
	_refresh()


func _label(at: Vector2, size: Vector2, fs: int, col: Color, font: Font) -> Label:
	var l := Label.new()
	l.position = at
	l.size = size
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	_panel.add_child(l)
	return l


func _refresh() -> void:
	_rows = rows_fn.call()
	_sel = clampi(_sel, 0, maxi(_rows.size() - 1, 0))
	for c in _list.get_children():
		c.queue_free()
	for i in _rows.size():
		var r: Array = _rows[i]
		var row := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(accent, 0.22) if i == _sel else Color(1, 1, 1, 0.04)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 5
		sb.content_margin_bottom = 5
		row.add_theme_stylebox_override("panel", sb)
		var h := HBoxContainer.new()
		row.add_child(h)
		var name := Label.new()
		name.text = ("▶ " if i == _sel else "   ") + str(r[0])
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.add_theme_font_override("font", Pal.text_font())
		name.add_theme_font_size_override("font_size", 19)
		var can: bool = r[2]
		name.add_theme_color_override("font_color", Color("f3e3c3") if can else Color("8a7a6a"))
		h.add_child(name)
		var note := Label.new()
		note.text = str(r[1])
		note.add_theme_font_override("font", Pal.text_font())
		note.add_theme_font_size_override("font_size", 16)
		note.add_theme_color_override("font_color", accent if can else Color("8a7a6a"))
		h.add_child(note)
		_list.add_child(row)


func _process(delta: float) -> void:
	_note_t = maxf(_note_t - delta, 0.0)
	_note.modulate.a = clampf(_note_t / 0.4, 0.0, 1.0)


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	get_viewport().set_input_as_handled()
	match (e as InputEventKey).physical_keycode:
		KEY_UP, KEY_W:
			_sel = (_sel + _rows.size() - 1) % maxi(_rows.size(), 1)
			_refresh()
		KEY_DOWN, KEY_S:
			_sel = (_sel + 1) % maxi(_rows.size(), 1)
			_refresh()
		KEY_E, KEY_J, KEY_ENTER, KEY_SPACE:
			act()
		KEY_ESCAPE, KEY_Q:
			close()


## Do the chosen row (tests call this too).
func act() -> void:
	if _rows.is_empty():
		return
	var r: Array = _rows[_sel]
	if not bool(r[2]) or not (r[3] is Callable):
		say(str(r[1]) if str(r[1]) != "" else "Not now.", Color("ff9a6a"))
		refused.emit()
		return
	var said = (r[3] as Callable).call()
	say(str(said) if said != null else "Done!", Color("9be15d"))
	acted.emit(str(r[0]))
	_refresh()


func pick(i: int) -> void:
	_sel = i
	_refresh()


func say(text: String, col: Color) -> void:
	_note.text = text
	_note.add_theme_color_override("font_color", col)
	_note_t = 2.5


func close() -> void:
	closed.emit()
	queue_free()
