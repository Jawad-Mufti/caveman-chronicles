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
var _say: RichTextLabel          ## the hint banner (see _show_say)
var _say_shown := ""
var _say_t := 0.0
var _say_up := false
var _hits: Control
var _berries: Control
var _boss: Control
var _torch: Control
var _quest: Label
var _fade: ColorRect
var _shells: Control
var _figs: Control
var figs := 0
var _bones: Control
var bones := 0
signal fig_tapped
var _card: Label
var _card_sub: Label
var shells := 0
var _shell_bump := 0.0
signal ability_tapped(id: String)
signal menu_tapped
var player: CaveMan          ## for the ability circles
var _bar: Control
var _menu: Control
var _sun_t := 0.0
var _shown: Array = []          ## what the meters last drew (see _process)
var _shells_shown := -1
var _bag: Control


func _ready() -> void:
	layer = 5
	Pal.install_fonts()
	add_to_group("hud")

	_title = Label.new()
	_title.text = title
	_title.position = Vector2(20, 14)
	_title.add_theme_font_size_override("font_size", 21)
	_title.add_theme_font_override("font", Pal.title_font())
	_title.add_theme_constant_override("outline_size", 6)
	_title.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
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
	_msg.offset_top = -150
	_msg.offset_bottom = -94
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_msg.add_theme_font_size_override("font_size", 26)
	_msg.add_theme_color_override("font_color", Pal.BONE)
	_msg.visible = false            # (it holds the words; the banner below shows them)
	add_child(_msg)
	# the hint BANNER: a little stone tablet that pops up, words in Fredoka, KEY WORDS in gold
	_say = RichTextLabel.new()
	_say.bbcode_enabled = true
	_say.fit_content = true
	_say.scroll_active = false
	_say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_say.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_say.add_theme_font_override("normal_font", Pal.text_font())
	_say.add_theme_font_size_override("normal_font_size", 23)
	_say.add_theme_color_override("default_color", Pal.BONE)
	_say.add_theme_constant_override("outline_size", 7)
	_say.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.095, 0.06, 0.9)
	sb.border_color = Pal.OCHRE
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 8
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_say.add_theme_stylebox_override("normal", sb)
	_say.visible = false
	add_child(_say)

	# what he is trying to do right now, top right
	_quest = Label.new()
	_quest.position = Vector2(760, 14)
	_quest.size = Vector2(500, 30)
	_quest.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quest.add_theme_font_size_override("font_size", 17)
	_quest.add_theme_color_override("font_color", Pal.BONE)
	add_child(_quest)

	# shells, top right under the quest line
	_shells = Control.new()
	_shells.position = Vector2(1130, 44)
	_shells.size = Vector2(130, 30)
	_shells.draw.connect(_draw_shells)
	add_child(_shells)
	# bones: the building material
	_bones = Control.new()
	_bones.position = Vector2(1130, 80)
	_bones.size = Vector2(130, 30)
	_bones.draw.connect(_draw_bones)
	add_child(_bones)
	# THE HOTBAR: his tools in a row, top centre (Terraria-style); tap one to use it
	_hotbar = Control.new()
	_hotbar.position = Vector2(640 - HB_W * 0.5, 54)
	_hotbar.size = Vector2(HB_W, HB_SLOT + 4)
	_hotbar.draw.connect(_draw_hotbar)
	_hotbar.gui_input.connect(_hotbar_input)
	add_child(_hotbar)
	# THE COMBO: hits in a row, under the hearts (hidden when there is none)
	_combo = Control.new()
	_combo.position = Vector2(20, 96)
	_combo.size = Vector2(260, 70)
	_combo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo.draw.connect(_draw_combo)
	add_child(_combo)
	# spirit orbs: streamed in from the beasts he beats (common/spirit_orbs.gd)
	_orbs = Control.new()
	_orbs.position = Vector2(1130, 150)
	_orbs.size = Vector2(130, 30)
	_orbs.draw.connect(_draw_orbs)
	add_child(_orbs)
	# roast figs: tap to eat one (or press H)
	_figs = Control.new()
	_figs.position = Vector2(1130, 114)
	_figs.size = Vector2(130, 34)
	_figs.draw.connect(_draw_figs)
	_figs.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			fig_tapped.emit())
	add_child(_figs)

	# a boss's name, big, across the middle of the screen
	_card = Label.new()
	_card.position = Vector2(0, 250)
	_card.size = Vector2(1280, 60)
	_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_theme_font_size_override("font_size", 56)
	_card.add_theme_font_override("font", Pal.title_font())
	_card.add_theme_constant_override("outline_size", 12)
	_card.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	_card.add_theme_color_override("font_color", Pal.OCHRE)
	_card.modulate.a = 0.0
	add_child(_card)
	_card_sub = Label.new()
	_card_sub.position = Vector2(0, 312)
	_card_sub.size = Vector2(1280, 30)
	_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_sub.add_theme_font_size_override("font_size", 20)
	_card_sub.add_theme_color_override("font_color", Pal.BONE)
	_card_sub.modulate.a = 0.0
	add_child(_card_sub)

	# the two powers he carries: circles at the bottom, shining while ready
	_bar = Control.new()
	_bar.position = Vector2(540, 610)
	_bar.size = Vector2(200, 110)
	_bar.visible = false
	_bar.draw.connect(_draw_bar)
	_bar.gui_input.connect(_bar_input)
	add_child(_bar)
	# the camp menu: a little fire under a hide tent, top middle
	_menu = Control.new()
	_menu.position = Vector2(604, 6)
	_menu.size = Vector2(72, 44)
	_menu.draw.connect(_draw_menu_button)
	_menu.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			menu_tapped.emit())
	add_child(_menu)

	# UGU'S BAG: everything he carries, in small boxes down the right (common/bag.gd)
	_bag = Bag.View.new()
	add_child(_bag)

	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func _process(delta: float) -> void:
	_sun_t += delta
	_update_bar(delta)
	_menu.queue_redraw()
	# the old counters (shells, bones, orbs, figs; berries, rocks, wood) step aside while the bag shows them all
	var old := Bag.mode == 0
	if _shells.visible != old:
		for c in [_shells, _bones, _orbs, _berries]:
			(c as Control).visible = old
	_figs.visible = old and figs > 0
	if msg_time > 0.0:
		msg_time -= delta
		if msg_time <= 0.0:
			_msg.text = ""
	# while someone is talking, hints move up out of the way of the dialogue box
	var talking := get_tree().get_first_node_in_group("dialogue") != null
	_show_say(delta, talking)
	# the meters are redrawn only when what they show has changed
	var shown := [hp, max_hp, berries, max_berries, rocks, gem, wood, torch_on, snappedf(torch_fuel, 0.004), boss_ratio]
	if shown != _shown:
		_shown = shown
		_hits.queue_redraw()
		_berries.queue_redraw()
		_boss.queue_redraw()
		_torch.queue_redraw()
		# extra hearts push the torch meter along
		_torch.position.x = 186.0 + maxf(0.0, max_hp - 5) * 30.0
	if _shell_bump > 0.0 or shells != _shells_shown:
		_shell_bump = maxf(_shell_bump - delta, 0.0)
		_shells_shown = shells
		_shells.queue_redraw()
	if _him == null or not is_instance_valid(_him):
		_him = get_tree().get_first_node_in_group("player") as CaveMan
	if _him != null:
		var sig := [_him.hotbar(), _him.hotbar_selected(), _him.rocks, GameState.figs, Bag.version]
		if sig != _hb_shown:
			_hb_shown = sig
			_hotbar.queue_redraw()
	var hits := _him.combo_hits if _him != null else 0
	if hits != _combo_shown:
		if hits > _combo_shown:
			_combo_bump = 0.16
		_combo_shown = hits
		_combo.queue_redraw()
	if _combo_bump > 0.0:
		_combo_bump = maxf(_combo_bump - delta, 0.0)
		_combo.queue_redraw()
	if GameState.orbs != _orbs_shown:
		_orb_bump = 0.18                     # a little pulse as each one lands
		_orbs_shown = GameState.orbs
	if _orb_bump > 0.0:
		_orb_bump = maxf(_orb_bump - delta, 0.0)
		_orbs.queue_redraw()


func say(text: String, seconds: float = 4.0) -> void:
	_msg.text = text
	msg_time = seconds


func set_bones(value: int) -> void:
	bones = value
	_bones.queue_redraw()


func _draw_bones() -> void:
	var b := Batch.new()
	Treasure.shape_into(b, "bone", Vector2.ZERO)
	_bones.draw_set_transform(Vector2(14, 15), 0.0, Vector2(0.8, 0.8))
	b.draw(_bones)
	_bones.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_bones.draw_string(ThemeDB.fallback_font, Vector2(34, 22), str(bones), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.BONE)


## ------------------------------------------------------------ THE HOTBAR
var _hotbar: Control
var _hb_shown: Array = []
const HB_SLOT := 52.0
const HB_GAP := 6.0
const HB_W := 11 * (52.0 + 6.0)


func _hb_x(i: int, n: int) -> float:
	return HB_W * 0.5 - n * (HB_SLOT + HB_GAP) * 0.5 + i * (HB_SLOT + HB_GAP)


func _hotbar_input(e: InputEvent) -> void:
	var at := Vector2.INF
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		at = e.position
	elif e is InputEventScreenTouch and e.pressed:
		at = e.position
	if at == Vector2.INF or _him == null:
		return
	var slots: Array = _him.hotbar()
	for i in slots.size():
		var x := _hb_x(i, slots.size())
		if at.x >= x and at.x <= x + HB_SLOT:
			CaveMan.ui_click_until = Time.get_ticks_msec() + 250     # (the tap isn't a swing too)
			_him.select_slot(i)
			_hotbar.accept_event()
			return


func _draw_hotbar() -> void:
	if _him == null:
		return
	var slots: Array = _him.hotbar()
	var sel: String = _him.hotbar_selected()
	var font := ThemeDB.fallback_font
	for i in slots.size():
		var id: String = slots[i]
		var x := _hb_x(i, slots.size())
		var on := id == sel
		var r := Rect2(x, 2, HB_SLOT, HB_SLOT)
		var empty := (id == "rocks" and _him.rocks <= 0) or (id == "figs" and GameState.figs <= 0)
		_hotbar.draw_rect(r, Color(0.08, 0.06, 0.05, 0.72 if on else 0.5))
		_hotbar.draw_rect(r, Color("ffd36b") if on else Color(Pal.BONE, 0.35), false, 3.0 if on else 1.5)
		var c := r.get_center() + Vector2(0, 2)
		var a := 0.35 if empty else 1.0
		Hud.draw_tool(_hotbar, id, c, a)
		if empty:
			_hotbar.draw_rect(r.grow(-2), Color(0.05, 0.04, 0.03, 0.55))      # none left: greyed out
		_hotbar.draw_string(font, Vector2(x + 4, 16), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Pal.BONE, 0.7))
		var count := _him.rocks if id == "rocks" else (GameState.figs if id == "figs" else (Bag.count(_him, id) if Bag.HOTBAR.has(id) else -1))
		if count >= 0:
			_hotbar.draw_string(font, Vector2(x + HB_SLOT - 16, HB_SLOT - 2), str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(Pal.BONE, a))


## Each tool's little picture, code-drawn like everything else (the hotbar, the bag).
static func draw_tool(ci: CanvasItem, id: String, c: Vector2, a: float) -> void:
	var wood := Color(Color("846141"), a)
	var dark := Color(Color("4a3220"), a)
	match id:
		"club":
			ci.draw_line(c + Vector2(-12, 14), c + Vector2(10, -10), dark, 7.0)
			ci.draw_line(c + Vector2(-12, 14), c + Vector2(10, -10), wood, 4.5)
			ci.draw_circle(c + Vector2(11, -11), 7.0, wood)
		"axe":
			ci.draw_line(c + Vector2(-12, 14), c + Vector2(8, -12), wood, 4.0)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(2, -16), c + Vector2(16, -14), c + Vector2(14, 0), c + Vector2(4, -6)]), Color(Color("8c9cab"), a))
		"hammer":
			ci.draw_line(c + Vector2(-12, 14), c + Vector2(6, -8), wood, 4.0)
			ci.draw_rect(Rect2(c + Vector2(-2, -20), Vector2(20, 14)), Color(Color("7b7469"), a))
			ci.draw_circle(c + Vector2(8, -13), 3.5, Color(Pal.GEM, a))
		"shovel":
			ci.draw_line(c + Vector2(-14, -16), c + Vector2(6, 6), wood, 4.0)
			ci.draw_line(c + Vector2(-18, -12), c + Vector2(-10, -20), dark, 4.0)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(2, 2), c + Vector2(12, -2), c + Vector2(18, 14), c + Vector2(14, 18), c + Vector2(-2, 12)]), Color(Pal.KEY_BONE, a))
		"rocks":
			ci.draw_circle(c + Vector2(-4, 4), 10.0, Color(Pal.STONE_DARK, a))
			ci.draw_circle(c + Vector2(-5, 3), 8.5, Color(Pal.STONE, a))
			ci.draw_circle(c + Vector2(8, -6), 6.0, Color(Pal.STONE, a))
		"figs":
			Hud.draw_fig(ci, c, 1.1)
		"hands":
			ci.draw_circle(c, 10.0, Color(Color("a67148"), a))
			ci.draw_circle(c + Vector2(1, -1), 8.0, Color(Color("c89263"), a))
		_:
			Bag.draw_icon(ci, id, c, 1.05)      # what he made in the bag


var _combo: Control
var _combo_shown := 0
var _combo_bump := 0.0
var _him: CaveMan


## The combo: "12 HITS", hotter in colour as it climbs, and the damage it adds.
func _draw_combo() -> void:
	var n := _combo_shown
	if n < 2:
		return
	var heat := clampf(n / 30.0, 0.0, 1.0)
	var col := Color("fff4d6").lerp(Color("ffb02e"), clampf(heat * 2.0, 0.0, 1.0)).lerp(Color("ff4a2a"), clampf(heat * 2.0 - 1.0, 0.0, 1.0))
	var k := 1.0 + 0.45 * sin(_combo_bump / 0.16 * PI)
	var font := ThemeDB.fallback_font
	var size := int(34 * k)
	var txt := str(n)
	var at := Vector2(4, 40)
	for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		_combo.draw_string(font, at + o, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.12, 0.05, 0.02))
	_combo.draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_combo.draw_string(font, at + Vector2(w + 8, -4), "HITS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
	var bonus := _him.combo_bonus() if _him != null else 0
	if bonus > 0:
		_combo.draw_string(font, at + Vector2(w + 8, 18), "+%d DMG" % bonus, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("ff9a5a"))


var _orbs: Control
var _orbs_shown := -1
var _orb_bump := 0.0


func _draw_orbs() -> void:
	var k := 1.0 + 0.35 * sin(_orb_bump / 0.18 * PI)
	var c := Vector2(14, 15)
	_orbs.draw_circle(c, 11.0 * k, Color("5fb8ff", 0.3))
	_orbs.draw_circle(c, 7.0 * k, Color("cfeeff"))
	_orbs.draw_circle(c + Vector2(-2, -2) * k, 2.6 * k, Color.WHITE)
	_orbs.draw_string(ThemeDB.fallback_font, Vector2(34, 22), str(GameState.orbs), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("cfeeff"))


func set_figs(value: int) -> void:
	figs = value
	_figs.visible = value > 0
	_figs.queue_redraw()


## A roast fig: purple-brown, split open and charred at the edges.
static func draw_fig(c: CanvasItem, at: Vector2, k: float) -> void:
	var body := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		# a little narrower at the top, like a fig
		var w := 11.0 - maxf(0.0, -sin(a)) * 3.0
		body.append(at + Vector2(cos(a) * w, sin(a) * 11.0) * k)
	c.draw_colored_polygon(body, Color("6b3450"))
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-4, -10) * k, at + Vector2(4, -10) * k, at + Vector2(2, -17) * k, at + Vector2(-2, -17) * k]), Color("5a6b2a"))
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-5, -2) * k, at + Vector2(0, -8) * k, at + Vector2(6, -2) * k, at + Vector2(0, 7) * k]), Color("e07a5f"))
	for i in 5:
		c.draw_circle(at + Vector2(-2 + (i % 3) * 2.0, -2 + (i / 3) * 4.0) * k, 1.0 * k, Color("f2d6a0"))
	c.draw_arc(at, 11.0 * k, PI * 0.2, PI * 0.8, 10, Color("2a1420", 0.6), 2.5 * k)


func _draw_figs() -> void:
	for i in figs:
		Hud.draw_fig(_figs, Vector2(14 + i * 22, 16), 0.9)
	_figs.draw_string(ThemeDB.fallback_font, Vector2(14 + figs * 22, 22), "H", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(Pal.BONE, 0.6))


func set_shells(value: int) -> void:
	if value > shells:
		_shell_bump = 0.25
	shells = value


## A name across the middle of the screen, in and out again: a boss arriving.
func title_card(title_text: String, sub: String) -> void:
	_card.text = title_text
	_card_sub.text = sub
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(_card_sub, "modulate:a", 1.0, 0.4)
	tw.tween_interval(2.4)
	tw.tween_property(_card, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(_card_sub, "modulate:a", 0.0, 0.6)


func _draw_shells() -> void:
	# the same scallop as the ones he picks up, a little bigger when one comes in
	var b := Batch.new()
	Treasure.shape_into(b, "shell", Vector2.ZERO)
	var k := 1.0 + _shell_bump * 1.6
	_shells.draw_set_transform(Vector2(14, 15), 0.0, Vector2(k, k) * 0.85)
	b.draw(_shells)
	_shells.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_shells.draw_string(ThemeDB.fallback_font, Vector2(34, 22), str(shells), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.BONE)


func set_quest(text: String) -> void:
	_quest.text = text


## Fade to black, run `between` while the screen is black, fade back in.
## For doorways: whatever jumps in between is never seen.
func through_black(between: Callable, time: float = 0.25) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, time)
	tw.tween_callback(between)
	tw.tween_interval(0.1)
	tw.tween_property(_fade, "color:a", 0.0, time)


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
		var p := Vector2(14 + i * 22, 13)
		_berries.draw_line(p + Vector2(0, -8), p + Vector2(2, -12), Color("6b4a2a"), 2.0)
		for g in [Vector2(-4, -4), Vector2(0, -5), Vector2(4, -4), Vector2(-2, 0), Vector2(2, 0), Vector2(0, 4)]:
			_berries.draw_circle(p + g, 3.4, Color("3e1a52"))
			_berries.draw_circle(p + g, 2.7, Color("7b3aa0"))
			_berries.draw_circle(p + g + Vector2(-0.9, -0.9), 0.9, Color("d9b8ef"))
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


func add_touch_controls(man: CaveMan) -> void:
	var specs := [
		["<", Vector2(30, 560), "left"],
		[">", Vector2(170, 560), "right"],
		["JUMP", Vector2(1000, 560), "jump"],
		["HIT", Vector2(1140, 560), "attack"],
		["THROW", Vector2(1010, 420), "throw"],
		["SPECIAL", Vector2(1140, 420), "special"],
		["TALK", Vector2(870, 560), "talk"],
		["STOMP", Vector2(870, 420), "stomp"],
		["DOWN", Vector2(100, 420), "down"],
		["UP", Vector2(100, 280), "up"],
	]
	# the powers are tapped on their circles at the bottom (see _draw_bar)
	for s in specs:
		var b := Button.new()
		b.text = s[0]
		b.position = s[1]
		b.size = Vector2(120, 120)
		b.modulate = Color(1, 1, 1, 0.55)
		b.add_theme_font_size_override("font_size", 24)
		b.focus_mode = Control.FOCUS_NONE
		var key: String = s[2]
		b.button_down.connect(func() -> void: man.touch[key] = true)
		b.button_up.connect(func() -> void: man.touch[key] = false)
		add_child(b)


## ------------------------------------------------------------------ ABILITIES
## The two powers he carries, at the bottom of the screen: a circle each, in
## its own colour. READY, it shines — a breathing glow, a spark running round
## the rim. USED, it bursts in rings and blazes while the power runs. SPENT, it
## goes dark and a thin arc shows it filling again (the sun's charge, or the
## wood for the fire ring) until it is ready and shines once more.
const BAR_C := [Vector2(600, 668), Vector2(680, 668)]
const BAR_R := 31.0
var _bar_was: Array = ["", ""]     ## each circle's last state, to catch "just used" / "just ready"
var _bar_pop: Array = [0.0, 0.0]   ## > 0: the burst when it was used
var _bar_ready: Array = [0.0, 0.0] ## > 0: the flash when it became ready again


## What a power is doing right now: "on" (running), "ready", or "spent";
## and how full it is (0..1) when spent.
func _power_state(id: String) -> Array:
	if player == null:
		return ["spent", 0.0]
	match id:
		"sunfire":
			if player.sun_t > 0.0:
				return ["on", player.sun_t / Sunfire.DURATION]
			if player.sun_charge >= 1.0:
				return ["ready", 1.0]
			return ["spent", player.sun_charge]
		"firering":
			if player.fury >= 0.0:
				return ["on", 1.0 - player.fury / CaveMan.FURY_TIME]
			if player.wood >= CaveMan.FIRE_COST:
				return ["ready", 1.0]
			return ["spent", float(player.wood) / CaveMan.FIRE_COST]
	return ["spent", 0.0]


func _update_bar(delta: float) -> void:
	var ids := Abilities.slots(player) if player != null else []
	_bar.visible = not ids.is_empty()
	for i in 2:
		_bar_pop[i] = maxf(float(_bar_pop[i]) - delta, 0.0)
		_bar_ready[i] = maxf(float(_bar_ready[i]) - delta, 0.0)
		var st := ""
		if i < ids.size():
			st = str(_power_state(ids[i])[0])
		if st == "on" and _bar_was[i] != "on" and _bar_was[i] != "":
			_bar_pop[i] = 0.6
		if st == "ready" and _bar_was[i] in ["spent", "on"]:
			_bar_ready[i] = 0.8
		_bar_was[i] = st
	_bar.queue_redraw()


func _bar_input(e: InputEvent) -> void:
	if not ((e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed):
		return
	var at: Vector2 = e.position + _bar.position
	var ids := Abilities.slots(player)
	for i in ids.size():
		if at.distance_to(BAR_C[i]) < BAR_R + 8.0:
			ability_tapped.emit(ids[i])


func _draw_bar() -> void:
	var b := Batch.new()
	var ids := Abilities.slots(player) if player != null else []
	var o := -_bar.position
	var t := _sun_t
	for i in 2:
		var c: Vector2 = BAR_C[i] + o
		if i >= ids.size():
			# an empty slot: a faint ring, waiting for a power
			b.arc(c, BAR_R, 0.0, TAU, 32, Color(1, 1, 1, 0.18), 2.0)
			continue
		var id: String = ids[i]
		var col := Abilities.colour(id)
		var s: Array = _power_state(id)
		var st: String = s[0]
		var k: float = s[1]
		match st:
			"ready":
				# shining: a breathing glow, rays, and a spark running round the rim
				var br := 0.5 + 0.5 * sin(t * 4.0 + i)
				for g in 3:
					b.circle(c, BAR_R + 6.0 + g * 5.0 + br * 4.0, Color(col, 0.12 - g * 0.03), 28)
				for r in 8:
					var a := r * TAU / 8.0 + t * 0.8
					b.tri(c + Vector2.from_angle(a + 0.12) * (BAR_R + 2.0), c + Vector2.from_angle(a) * (BAR_R + 12.0 + 4.0 * br), c + Vector2.from_angle(a - 0.12) * (BAR_R + 2.0), Color(col, 0.55))
				b.circle(c, BAR_R, Color("2a1a12"), 28)
				b.arc(c, BAR_R, 0.0, TAU, 32, col, 3.5)
				Abilities.draw_symbol(b, id, c, BAR_R * 0.7, col, t * 1.5)
				var sp := c + Vector2.from_angle(t * 3.0) * BAR_R
				b.quad(sp + Vector2(0, -7), sp + Vector2(2, 0), sp + Vector2(0, 7), sp + Vector2(-2, 0), Color.WHITE)
				b.quad(sp + Vector2(-7, 0), sp + Vector2(0, 2), sp + Vector2(7, 0), sp + Vector2(0, -2), Color.WHITE)
			"on":
				# blazing: white-hot core, its colour all round, a ring of time
				for g in 2:
					b.circle(c, BAR_R + 10.0 + g * 6.0 + 3.0 * sin(t * 12.0), Color(col, 0.22 - g * 0.08), 28)
				b.circle(c, BAR_R, col.darkened(0.45), 28)
				b.circle(c, BAR_R * 0.82, col.darkened(0.2), 28)
				Abilities.draw_symbol(b, id, c, BAR_R * 0.72 * (1.0 + 0.06 * sin(t * 14.0)), Color("fff3c4"), t * 3.0)
				b.arc(c, BAR_R + 3.0, -PI * 0.5, -PI * 0.5 + TAU * k, 40, Color("fff3c4"), 4.0)
				for f in 4:
					var fa := -PI * 0.5 + (f - 1.5) * 0.45
					Sunfire.flame(b, c + Vector2.from_angle(fa) * BAR_R, 12.0, t * 1.4 + f * 1.3, 0.9)
			_:
				# spent: dark and still, filling back up
				b.circle(c, BAR_R, Color(0.08, 0.07, 0.08, 0.85), 28)
				b.arc(c, BAR_R, 0.0, TAU, 32, Color(0.35, 0.35, 0.38), 2.0)
				Abilities.draw_symbol(b, id, c, BAR_R * 0.7, col.darkened(0.6).lerp(Color(0.3, 0.3, 0.33), 0.5), 0.0)
				if k > 0.0:
					b.arc(c, BAR_R, -PI * 0.5, -PI * 0.5 + TAU * k, 40, Color(col, 0.75), 3.5)
		# just used: rings racing out in its colour
		var pop: float = _bar_pop[i]
		if pop > 0.0:
			var q := 1.0 - pop / 0.6
			b.arc(c, BAR_R + q * 70.0, 0.0, TAU, 36, Color(col, 1.0 - q), 6.0 * (1.0 - q) + 1.0)
			b.arc(c, BAR_R + q * 40.0, 0.0, TAU, 36, Color(1, 1, 1, 0.8 * (1.0 - q)), 3.0)
		# ready again: a white flash
		var rd: float = _bar_ready[i]
		if rd > 0.0:
			b.circle(c, BAR_R + 4.0, Color(1, 1, 1, 0.5 * rd / 0.8), 28)
	b.draw(_bar)
	var f2 := ThemeDB.fallback_font
	for i in ids.size():
		var row := Abilities.row(ids[i])
		var key: String = row[3]
		var c2: Vector2 = BAR_C[i] + o + Vector2(BAR_R * 0.62, BAR_R * 0.5)
		_bar.draw_circle(c2 + Vector2(4, -5), 10.0, Color(0, 0, 0, 0.7))
		_bar.draw_string(f2, c2 + Vector2(-0.5, 1), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.95))
		if ids[i] == "firering" and _power_state("firering")[0] == "spent" and player != null:
			_bar.draw_string(f2, BAR_C[i] + o + Vector2(-12, -BAR_R - 6), "%d/%d" % [player.wood, CaveMan.FIRE_COST], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.7))
		if ids[i] == "sunfire" and player != null and player.sun_t > 0.0:
			_bar.draw_string(f2, BAR_C[i] + o + Vector2(-8, -BAR_R - 8), "%d" % ceili(player.sun_t), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("fff3c4"))


## The camp button: a hide tent with a little fire, and the word.
func _draw_menu_button() -> void:
	var b := Batch.new()
	b.circle(Vector2(36, 22), 21.0, Color(0, 0, 0, 0.35), 20)
	b.tri(Vector2(18, 32), Vector2(36, 8), Vector2(54, 32), Color("b07a4a"))
	b.tri(Vector2(30, 32), Vector2(36, 18), Vector2(42, 32), Color("3a2414"))
	b.line(Vector2(34, 6), Vector2(38, 2), Color("6b4a2a"), 2.0)
	Sunfire.flame(b, Vector2(36, 33), 8.0, _sun_t * 1.4, 0.9)
	b.draw(_menu)
	_menu.draw_string(ThemeDB.fallback_font, Vector2(14, 44), "MENU  Esc", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(Pal.BONE, 0.7))


## ------------------------------------------------------------ THE HINT BANNER
## The words in _msg, on a little stone tablet: it pops in (a bounce) when the
## words change, fades out at the end, and while someone is talking it moves
## up out of the dialogue box's way. Words in CAPITALS (SHOVEL, SUNFIRE...)
## are the important ones: gold.
func _show_say(delta: float, talking: bool) -> void:
	var text := _msg.text
	if text != _say_shown or talking != _say_up:
		if text != _say_shown:
			_say_t = 0.0
		_say_shown = text
		_say_up = talking
		_say.visible = text != ""
		if text == "":
			return
		var font := Pal.text_font()
		var w := minf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x + 60.0, 920.0)
		_say.text = "[center]" + _gold_caps(text) + "[/center]"
		_say.custom_minimum_size = Vector2(w, 0)
		_say.size = Vector2(w, 0)
		_say.reset_size()
		_say.position.x = 640.0 - w * 0.5
	if text == "":
		return
	_say_t += delta
	var h := _say.size.y
	_say.position.y = 112.0 if talking else 720.0 - 92.0 - h
	_say.pivot_offset = _say.size * 0.5
	var pop := clampf(_say_t / 0.22, 0.0, 1.0)
	var k := lerpf(0.7, 1.0, pop) + sin(pop * PI) * 0.08          # a little bounce past full size
	_say.scale = Vector2(k, k)
	_say.modulate.a = clampf(minf(_say_t / 0.12, msg_time / 0.35), 0.0, 1.0)


## SHOUTY words (two capital letters or more) in gold.
static func _gold_caps(text: String) -> String:
	var out := ""
	for word in text.split(" "):
		var core := word.strip_edges().rstrip(".,!?:;)\"'").lstrip("(\"'")
		var caps := core.length() >= 2 and core == core.to_upper() and core != core.to_lower()
		out += ("[color=#ffd36b]%s[/color]" % word if caps else word) + " "
	return out.strip_edges()
