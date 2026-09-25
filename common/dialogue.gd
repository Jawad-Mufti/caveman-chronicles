class_name Dialogue
extends CanvasLayer
## A conversation, or a moment of narration, in a box at the bottom of the
## screen: who is speaking, their words typed out, and a blinking prompt.
## While it runs he stands still and can't be hurt, and his torch waits.
## Space, Enter, J or E, a click or a tap: finish the line, then go on.
##
## lines: [[speaker, text], ...] — or [speaker, text, callable] to make
## something happen as that line appears (a box opening, a gem changing hands).
## An empty speaker is narration.

signal finished
signal line_started(speaker: String)

const TYPE_SPEED := 50.0      ## characters per second
const GUARD := 0.25           ## ignore presses this soon after a line appears

var lines: Array = []
var player: CaveMan
var _i := -1
var _shown := 0.0
var _age := 0.0
var _box: Panel
var _name: Label
var _text: Label
var _more: Label


func _ready() -> void:
	layer = 6
	_box = Panel.new()
	_box.position = Vector2(160, 500)
	_box.size = Vector2(960, 172)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Pal.CHARCOAL, 0.93)
	sb.border_color = Pal.OCHRE
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	_box.add_theme_stylebox_override("panel", sb)
	add_child(_box)
	_name = Label.new()
	_name.position = Vector2(26, 14)
	_name.add_theme_font_size_override("font_size", 19)
	_name.add_theme_color_override("font_color", Pal.OCHRE)
	_box.add_child(_name)
	_text = Label.new()
	_text.position = Vector2(26, 46)
	_text.size = Vector2(900, 100)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 23)
	_text.add_theme_color_override("font_color", Pal.BONE)
	_box.add_child(_text)
	_more = Label.new()
	_more.text = "▸"
	_more.position = Vector2(918, 128)
	_more.add_theme_font_size_override("font_size", 24)
	_more.add_theme_color_override("font_color", Pal.OCHRE)
	_box.add_child(_more)
	if player != null:
		player.talking = true
	_next()


func _next() -> void:
	_i += 1
	if _i >= lines.size():
		if player != null:
			player.talking = false
		finished.emit()
		queue_free()
		return
	var line: Array = lines[_i]
	var who: String = line[0]
	_name.text = who
	_text.text = line[1]
	# narration reads in a quieter colour
	_text.add_theme_color_override("font_color", Pal.BONE if who != "" else Pal.OCHRE.lightened(0.35))
	_shown = 0.0
	_age = 0.0
	_text.visible_characters = 0
	line_started.emit(who)
	if line.size() > 2 and line[2] is Callable:
		(line[2] as Callable).call()


func _process(delta: float) -> void:
	_age += delta
	_shown += delta * TYPE_SPEED
	var total := _text.text.length()
	_text.visible_characters = mini(int(_shown), total)
	_more.visible = int(_shown) >= total and fmod(_age, 0.8) < 0.5


func _input(event: InputEvent) -> void:
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
