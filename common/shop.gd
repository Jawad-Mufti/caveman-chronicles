class_name Shop
extends CanvasLayer
## A trader's wares in a panel over the game. He stands still while it is
## open. Arrow keys and Space / Enter / J, or tap an item; Esc, K or Leave to
## go. The level supplies what is for sale and what buying does, so every
## level's trader can sell different things.

signal closed

var title := "TRADER"
var player: CaveMan
## Returns the wares: [{id, name, desc, price_text, enabled}]
var list_items: Callable
## Called with a ware's id; returns a line saying what happened.
var buy: Callable

var _list: VBoxContainer
var _desc: Label
var _shells: Label
var _msg: Label
var _age := 0.0


func _ready() -> void:
	layer = 6
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	add_child(dim)
	var box := Panel.new()
	box.position = Vector2(270, 36)
	box.size = Vector2(740, 640)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Pal.CHARCOAL, 0.95)
	sb.border_color = Pal.OCHRE
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	box.add_theme_stylebox_override("panel", sb)
	add_child(box)
	var head := Label.new()
	head.text = title
	head.position = Vector2(28, 18)
	head.add_theme_font_size_override("font_size", 26)
	head.add_theme_color_override("font_color", Pal.OCHRE)
	box.add_child(head)
	_shells = Label.new()
	_shells.position = Vector2(520, 22)
	_shells.size = Vector2(190, 30)
	_shells.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_shells.add_theme_font_size_override("font_size", 20)
	_shells.add_theme_color_override("font_color", Color("f3d08a"))
	box.add_child(_shells)
	_list = VBoxContainer.new()
	_list.position = Vector2(28, 70)
	_list.size = Vector2(684, 440)
	_list.add_theme_constant_override("separation", 4)
	box.add_child(_list)
	_desc = Label.new()
	_desc.position = Vector2(28, 530)
	_desc.size = Vector2(684, 50)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.add_theme_font_size_override("font_size", 18)
	_desc.add_theme_color_override("font_color", Pal.BONE)
	box.add_child(_desc)
	_msg = Label.new()
	_msg.position = Vector2(28, 590)
	_msg.size = Vector2(684, 40)
	_msg.add_theme_font_size_override("font_size", 18)
	_msg.add_theme_color_override("font_color", Pal.OCHRE.lightened(0.3))
	box.add_child(_msg)
	if player != null:
		player.talking = true
	_refresh(0)


func _refresh(focus_index: int) -> void:
	for c in _list.get_children():
		c.queue_free()
	_shells.text = "Shells: %d" % GameState.shells
	var wares: Array = list_items.call()
	var buttons: Array = []
	for w in wares:
		var b := Button.new()
		b.text = "%s      %s" % [w["name"], w["price_text"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 19)
		b.custom_minimum_size = Vector2(684, 38)
		b.disabled = not w["enabled"]
		b.focus_mode = Control.FOCUS_ALL
		var id: String = w["id"]
		var desc: String = w["desc"]
		var idx := buttons.size()
		b.pressed.connect(func() -> void: _pick(id, idx))
		b.focus_entered.connect(func() -> void: _desc.text = desc)
		b.mouse_entered.connect(func() -> void: _desc.text = desc)
		_list.add_child(b)
		buttons.append(b)
	var leave := Button.new()
	leave.text = "Leave"
	leave.add_theme_font_size_override("font_size", 19)
	leave.custom_minimum_size = Vector2(684, 38)
	leave.pressed.connect(_close)
	leave.focus_entered.connect(func() -> void: _desc.text = "")
	_list.add_child(leave)
	buttons.append(leave)
	(buttons[clampi(focus_index, 0, buttons.size() - 1)] as Button).call_deferred("grab_focus")


func _pick(id: String, idx: int) -> void:
	if _age < 0.3:
		return
	_msg.text = buy.call(id)
	_refresh(idx)


func _process(delta: float) -> void:
	_age += delta


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := (event as InputEventKey).physical_keycode
	if k == KEY_ESCAPE or k == KEY_K:
		get_viewport().set_input_as_handled()
		_close()
	elif k == KEY_J or k == KEY_E:
		get_viewport().set_input_as_handled()
		var f := get_viewport().gui_get_focus_owner()
		if f is Button and not (f as Button).disabled:
			(f as Button).pressed.emit()


func _close() -> void:
	if _age < 0.3:
		return
	if player != null:
		player.talking = false
	closed.emit()
	queue_free()
