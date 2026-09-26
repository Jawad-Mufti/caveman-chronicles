class_name LevelEnd
extends CanvasLayer
## The scroll at the end of a level, Captain Claw style: what he found, what
## he missed, how long it took. Space, Enter, J or a tap to go on.

signal done

var title := ""
## [[what, how many / value]]
var lines: Array = []
var _age := 0.0


func _ready() -> void:
	layer = 7
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	var scroll := Panel.new()
	scroll.position = Vector2(340, 90)
	scroll.size = Vector2(600, 540)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("e2d3b0")
	sb.border_color = Color("8a6a3e")
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(18)
	scroll.add_theme_stylebox_override("panel", sb)
	add_child(scroll)
	var head := Label.new()
	head.text = title
	head.position = Vector2(0, 30)
	head.size = Vector2(600, 40)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 30)
	head.add_theme_color_override("font_color", Color("4a3218"))
	scroll.add_child(head)
	for i in lines.size():
		var row: Array = lines[i]
		var a := Label.new()
		a.text = row[0]
		a.position = Vector2(70, 110 + i * 52)
		a.add_theme_font_size_override("font_size", 24)
		a.add_theme_color_override("font_color", Color("4a3218"))
		scroll.add_child(a)
		var b := Label.new()
		b.text = row[1]
		b.position = Vector2(300, 110 + i * 52)
		b.size = Vector2(230, 30)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_theme_font_size_override("font_size", 24)
		b.add_theme_color_override("font_color", Color("7a3d17"))
		scroll.add_child(b)
	var foot := Label.new()
	foot.text = "Space or tap to continue"
	foot.position = Vector2(0, 480)
	foot.size = Vector2(600, 30)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", 18)
	foot.add_theme_color_override("font_color", Color("6b5536"))
	scroll.add_child(foot)
	scroll.modulate.a = 0.0
	create_tween().tween_property(scroll, "modulate:a", 1.0, 0.6)


func _process(delta: float) -> void:
	_age += delta


func _input(event: InputEvent) -> void:
	var press := false
	if event is InputEventKey and event.pressed and not event.echo:
		press = (event as InputEventKey).physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_J]
	elif (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		press = true
	if press and _age > 1.0:
		get_viewport().set_input_as_handled()
		done.emit()
