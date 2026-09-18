## On-screen layer: title, hits remaining, boss bar, messages, touch buttons.
class_name Hud
extends CanvasLayer

var hp := 5
var max_hp := 5
var berries := 0
var max_berries := 3
var boss_ratio := -1.0
var msg_time := 0.0

var _title: Label
var _msg: Label
var _hits: Control
var _berries: Control
var _boss: Control


func _ready() -> void:
	layer = 5

	_title = Label.new()
	_title.text = "LEVEL 1   RAW STONE AGE"
	_title.position = Vector2(20, 14)
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", Pal.OCHRE)
	add_child(_title)

	_hits = Control.new()
	_hits.position = Vector2(20, 44)
	_hits.size = Vector2(200, 30)
	_hits.draw.connect(_draw_hits)
	add_child(_hits)

	_berries = Control.new()
	_berries.position = Vector2(20, 78)
	_berries.size = Vector2(200, 26)
	_berries.draw.connect(_draw_berries)
	add_child(_berries)

	_boss = Control.new()
	_boss.position = Vector2(340, 20)
	_boss.size = Vector2(600, 24)
	_boss.draw.connect(_draw_boss)
	add_child(_boss)

	_msg = Label.new()
	_msg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_msg.offset_top = -96
	_msg.offset_bottom = -40
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_msg.add_theme_font_size_override("font_size", 26)
	_msg.add_theme_color_override("font_color", Pal.BONE)
	add_child(_msg)


func _process(delta: float) -> void:
	if msg_time > 0.0:
		msg_time -= delta
		if msg_time <= 0.0:
			_msg.text = ""
	_hits.queue_redraw()
	_berries.queue_redraw()
	_boss.queue_redraw()


func say(text: String, seconds: float = 4.0) -> void:
	_msg.text = text
	msg_time = seconds


func set_hp(value: int) -> void:
	hp = value


func set_berries(value: int) -> void:
	berries = value


func set_boss(ratio: float) -> void:
	boss_ratio = ratio


func _draw_hits() -> void:
	for i in max_hp:
		var p := Vector2(12 + i * 30, 14)
		var pts := PackedVector2Array([
			p + Vector2(-10, 4), p + Vector2(-6, -8), p + Vector2(4, -10),
			p + Vector2(11, -2), p + Vector2(8, 8), p + Vector2(-3, 10)
		])
		if i < hp:
			_hits.draw_colored_polygon(pts, Pal.OCHRE)
		else:
			var closed := PackedVector2Array(pts)
			closed.append(pts[0])
			_hits.draw_polyline(closed, Color(Pal.OCHRE, 0.5), 2.0)


func _draw_berries() -> void:
	for i in max_berries:
		var p := Vector2(14 + i * 24, 12)
		if i < berries:
			_berries.draw_circle(p, 7.0, Pal.EMBER)
			_berries.draw_circle(p + Vector2(-2, -2), 2.5, Pal.BONE)
		else:
			_berries.draw_arc(p, 7.0, 0.0, TAU, 18, Color(Pal.EMBER, 0.4), 2.0)


func _draw_boss() -> void:
	if boss_ratio < 0.0:
		return
	var w := 600.0
	_boss.draw_rect(Rect2(0, 6, w, 12), Color(Pal.CHARCOAL, 0.7))
	_boss.draw_rect(Rect2(0, 6, w * boss_ratio, 12), Pal.EMBER)
	_boss.draw_rect(Rect2(0, 6, w, 12), Pal.OCHRE, false, 2.0)


func add_touch_controls(player: CaveMan) -> void:
	var specs := [
		["<", Vector2(30, 560), "left"],
		[">", Vector2(170, 560), "right"],
		["JUMP", Vector2(1000, 560), "jump"],
		["HIT", Vector2(1140, 560), "attack"],
		["EAT", Vector2(1140, 420), "heal"],
	]
	for s in specs:
		var b := Button.new()
		b.text = s[0]
		b.position = s[1]
		b.size = Vector2(120, 120)
		b.modulate = Color(1, 1, 1, 0.55)
		b.add_theme_font_size_override("font_size", 24)
		b.focus_mode = Control.FOCUS_NONE
		var key: String = s[2]
		b.button_down.connect(func() -> void: player.touch[key] = true)
		b.button_up.connect(func() -> void: player.touch[key] = false)
		add_child(b)
