## On-screen layer: title, hits remaining, boss bar, messages, touch buttons.
class_name Hud
extends CanvasLayer

var hp := 5
var max_hp := 5
var berries := 0
var max_berries := 3
var rocks := 0
var gem := false
var boss_ratio := -1.0
var msg_time := 0.0
var title := "LEVEL 1   RAW STONE AGE"
var wood := 0
var torch_on := false     ## false until he carries a torch: no meter in Level 1
var torch_fuel := 0.0

var _title: Label
var _msg: Label
var _hits: Control
var _berries: Control
var _boss: Control
var _torch: Control


func _ready() -> void:
	layer = 5

	_title = Label.new()
	_title.text = title
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
	_berries.size = Vector2(220, 84)
	_berries.draw.connect(_draw_berries)
	add_child(_berries)

	_torch = Control.new()
	_torch.position = Vector2(186, 44)
	_torch.size = Vector2(170, 30)
	_torch.draw.connect(_draw_torch)
	add_child(_torch)

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
	_torch.queue_redraw()


func say(text: String, seconds: float = 4.0) -> void:
	_msg.text = text
	msg_time = seconds


func set_hp(value: int) -> void:
	hp = value


func set_berries(value: int) -> void:
	berries = value


func set_rocks(value: int) -> void:
	rocks = value


func set_gem(value: bool) -> void:
	gem = value


func set_wood(value: int) -> void:
	wood = value


func set_torch(on: bool, fuel: float) -> void:
	torch_on = on
	torch_fuel = fuel


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
	# Only what he is actually carrying. Empty slots used to be drawn as faint
	# outlines, which read as berries he owned but could not spend.
	for i in berries:
		var p := Vector2(14 + i * 22, 11)
		_berries.draw_circle(p, 7.0, Pal.EMBER)
		_berries.draw_circle(p + Vector2(-2, -2), 2.5, Pal.BONE)
	# rocks live on their own row, and are drawn as chipped stone, not dots,
	# so the two counts can never be mistaken for one another
	for i in rocks:
		var q := Vector2(14 + i * 20, 36)
		_berries.draw_polygon(PackedVector2Array([
			q + Vector2(-7, 2), q + Vector2(-4, -6), q + Vector2(5, -7),
			q + Vector2(8, 1), q + Vector2(2, 7),
		]), PackedColorArray([Pal.STONE]))
		_berries.draw_line(q + Vector2(-3, -3), q + Vector2(3, 1), Pal.STONE_DARK, 2.0)
	# wood: a short bundle of sticks each, on the row below the rocks
	for i in wood:
		var w := Vector2(14 + i * 24, 62)
		for k in 3:
			var o := Vector2(0, -4 + k * 4)
			_berries.draw_line(w + o + Vector2(-9, 2), w + o + Vector2(9, -2), Pal.DEADWOOD.darkened(0.1 * k), 3.0)
		_berries.draw_line(w + Vector2(-1, -7), w + Vector2(1, 7), Pal.VINE, 2.0)


## The torch meter. The notch at the middle is the rule the wolves live by:
## above it a lunge breaks on the light, below it the lunge lands.
func _draw_torch() -> void:
	if not torch_on:
		return
	var bar := Rect2(34, 8, 120, 12)
	var lit := torch_fuel > 0.0
	# a little flame, or a smoking stub when it is out
	var f := Vector2(14, 18)
	_torch.draw_line(f + Vector2(0, 8), f + Vector2(-2, -2), Pal.DEADWOOD_DARK, 4.0)
	if lit:
		var h := 8.0 + 8.0 * torch_fuel
		_torch.draw_colored_polygon(PackedVector2Array([
			f + Vector2(-6, -2), f + Vector2(0, -2 - h), f + Vector2(6, -2)]), Pal.FLAME)
		_torch.draw_colored_polygon(PackedVector2Array([
			f + Vector2(-3, -2), f + Vector2(0, -2 - h * 0.55), f + Vector2(3, -2)]), Pal.FLAME_CORE)
	else:
		_torch.draw_circle(f + Vector2(-2, -3), 2.5, Pal.ASH)
	_torch.draw_rect(bar, Color(Pal.CHARCOAL, 0.7))
	var col := Pal.FLAME if torch_fuel >= 0.5 else Pal.EMBER_GLOW
	_torch.draw_rect(Rect2(bar.position, Vector2(bar.size.x * torch_fuel, bar.size.y)), col)
	_torch.draw_rect(bar, Pal.OCHRE, false, 2.0)
	var mid := bar.position.x + bar.size.x * 0.5
	_torch.draw_line(Vector2(mid, bar.position.y - 3), Vector2(mid, bar.end.y + 3), Pal.BONE, 2.0)


func _draw_boss() -> void:
	if boss_ratio < 0.0:
		return
	var w := 600.0
	_boss.draw_rect(Rect2(0, 6, w, 12), Color(Pal.CHARCOAL, 0.7))
	_boss.draw_rect(Rect2(0, 6, w * boss_ratio, 12), Pal.EMBER)
	_boss.draw_rect(Rect2(0, 6, w, 12), Pal.OCHRE, false, 2.0)


func add_touch_controls(player: CaveMan, with_fire: bool = false) -> void:
	var specs := [
		["<", Vector2(30, 560), "left"],
		[">", Vector2(170, 560), "right"],
		["JUMP", Vector2(1000, 560), "jump"],
		["HIT", Vector2(1140, 560), "attack"],
		["EAT", Vector2(1140, 420), "heal"],
		["THROW", Vector2(1010, 420), "throw"],
	]
	if with_fire:
		specs.append(["FIRE", Vector2(1140, 280), "fire"])
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
