extends Node2D
## Test harness (not shipped): a MODEL SHEET of Ugu's real 2D rig (common/
## player.gd), big, on a plain backdrop, for design work: a row of poses (idle,
## run, swing, the hammer) and a row of looks (Level 1 leaves, Level 2 hide, the
## costumes), plus a face close-up and his in-game size. Run with rendering;
## PNG to C:/tmp/shots/rigsheet_<tag>.png.  args: tag=<name>
var tag := "now"


func _ready() -> void:
	Pal.install_fonts()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
	var bg := ColorRect.new()
	bg.color = Color("2b2f3a")
	bg.size = Vector2(1280, 720)
	add_child(bg)
	if OS.get_cmdline_user_args().has("wind"):
		# in the air: standing (a breeze), running (it streams back), falling (it flies up)
		var wl := [["idle", "plain"], ["run", "plain"], ["fall", "plain"], ["run", "bear_cloak"], ["fall", "wolf_hood"]]
		for k in wl.size():
			_man(Vector2(130 + k * 255, 560), 3.0, 2, wl[k][1], wl[k][0], k * 0.4)
		_label(Vector2(16, 8), "UGU  in the wind: idle, run, fall, cloak, hood  (%s)" % tag)
		_finish.call_deferred()
		return
	if OS.get_cmdline_user_args().has("face"):
		# face close-ups: rest, the attack face, the yawn... and the hood
		var faces := [["idle", "plain", 0.3], ["swing", "plain", 0.8], ["idle", "wolf_hood", 1.4]]
		for k in faces.size():
			_man(Vector2(250 + k * 400, 1030), 6.5, 2, faces[k][1], faces[k][0], faces[k][2])
		_label(Vector2(16, 8), "UGU  faces  (%s)" % tag)
		_finish.call_deferred()
		return
	# row 1: poses, Level 2 hide
	var poses := ["idle", "run", "swing", "hammer", "throw"]
	for i in poses.size():
		_man(Vector2(130 + i * 255, 320), 2.6, 2, "plain", poses[i], i * 0.37)
	# row 2: looks (Level 1 leaves, then the costumes)
	var looks := [[1, "plain"], [2, "wolf_hood"], [2, "ember_paint"], [2, "bear_cloak"], [2, "firekeeper"]]
	for j in looks.size():
		_man(Vector2(130 + j * 255, 690), 2.6, looks[j][0], looks[j][1], "idle", j * 0.5)
	_label(Vector2(16, 8), "UGU  model sheet  (%s)" % tag)
	_finish.call_deferred()


func _man(at: Vector2, s: float, costume: int, skin: String, pose: String, t: float) -> CaveMan:
	var m := CaveMan.new()
	m.preview = true
	m.position = at
	m.scale = Vector2(s, s)
	add_child(m)
	m.has_stick = true
	m.costume = costume
	m.skin = skin
	m.anim_t = t
	match pose:
		"run":
			m.velocity.x = CaveMan.SPEED
			m._run_phase = 1.1
		"swing":
			m._swing_kind = "club"
			m._swing_time = 0.26
			m.attacking = 0.12
		"hammer":
			m.hammer = true
		"fall":
			m.velocity = Vector2(CaveMan.SPEED * 0.6, 700.0)
		"throw":
			m.throwing = 0.14
	return m


func _label(at: Vector2, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_override("font", Pal.title_font())
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color("ffcf40"))
	add_child(l)


func _finish() -> void:
	for i in 40:
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("C:/tmp/shots")
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/rigsheet_%s.png" % tag)
	print("shot rigsheet_", tag)
	get_tree().quit()
