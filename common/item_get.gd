class_name ItemGet
extends CanvasLayer
## The "you got something special" moment: the screen dims, rays of light
## turn behind a big picture of the thing, its name, and a line on how to use
## it. He holds it up high meanwhile (the level sets that). Space, J or a tap
## to go on.

signal done

var title := ""
var line := ""
## Draws the item into a Control, centred on (0, 0), about 150 px across.
var icon: Callable
var player: CaveMan
var _age := 0.0
var _card: Control


func _ready() -> void:
	layer = 7
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_card = Control.new()
	_card.position = Vector2(640, 250)
	_card.draw.connect(_draw_card)
	add_child(_card)
	var name_label := Label.new()
	name_label.text = title
	name_label.position = Vector2(0, 400)
	name_label.size = Vector2(1280, 50)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 40)
	name_label.add_theme_color_override("font_color", Pal.OCHRE.lightened(0.2))
	add_child(name_label)
	var how := Label.new()
	how.text = line
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size = Vector2(800, 0)
	how.add_theme_font_size_override("font_size", 21)
	how.add_theme_color_override("font_color", Pal.BONE)
	add_child(how)
	how.position = Vector2(240, 456)
	how.size = Vector2(800, 90)
	var go := Label.new()
	go.text = "Space or tap"
	go.position = Vector2(0, 560)
	go.size = Vector2(1280, 30)
	go.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go.add_theme_font_size_override("font_size", 16)
	go.add_theme_color_override("font_color", Pal.OCHRE)
	add_child(go)
	if player != null:
		player.talking = true
	for c in get_children():
		if c is CanvasItem:
			(c as CanvasItem).modulate.a = 0.0
			create_tween().tween_property(c, "modulate:a", 1.0, 0.4)


func _process(delta: float) -> void:
	_age += delta
	if player != null:
		player.showing_off = 0.5
	_card.queue_redraw()


func _draw_card() -> void:
	# turning rays of light, and a glow, behind the treasure
	for i in 12:
		var a := TAU * i / 12.0 + _age * 0.4
		_card.draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a - 0.12) * 190.0, Vector2.from_angle(a + 0.12) * 190.0]),
			Color(1.0, 0.85, 0.5, 0.16))
	_card.draw_circle(Vector2.ZERO, 95.0 + sin(_age * 3.0) * 5.0, Color(1.0, 0.8, 0.45, 0.2))
	var k := 1.0 + sin(_age * 2.0) * 0.04
	_card.draw_set_transform(Vector2(0, sin(_age * 2.2) * 5.0), sin(_age * 1.1) * 0.08, Vector2(k, k))
	if icon.is_valid():
		icon.call(_card)
	_card.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _input(event: InputEvent) -> void:
	var press := false
	if event is InputEventKey and event.pressed and not event.echo:
		press = (event as InputEventKey).physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_J]
	elif (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		press = true
	if press and _age > 1.0:
		get_viewport().set_input_as_handled()
		if player != null:
			player.talking = false
			player.showing_off = 0.0
		done.emit()
		queue_free()
