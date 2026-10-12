extends Node2D
## Test harness (not shipped): a MODEL SHEET of OLD SCAR (level2/old_scar.gd),
## big, on a plain backdrop, for design work: his poses side by side, each one
## his own state held (walk, crouch, pounce, roar, swipe, cower), and a big head.
## Run with rendering; PNG to C:/tmp/shots/scarsheet_<tag>.png.
##   args: tag=<name>, night (the dark blue of the Long Dark behind him)
var tag := "now"
var _scars: Array = []

## [label, state, timer, vx, vel]
const POSES := [["walk", "prowl", 0.0, 170.0, Vector2.ZERO], ["the tell", "crouch", 0.4, 0.0, Vector2.ZERO], ["pounce", "pounce", 0.0, 0.0, Vector2(500, -80)],
	["roar", "roar", 0.6, 0.0, Vector2.ZERO], ["swipe", "swipe", 0.3, 0.0, Vector2.ZERO], ["charge", "charge", 0.0, 600.0, Vector2.ZERO], ["dazed", "dazed", 1.0, 0.0, Vector2.ZERO]]


func _ready() -> void:
	Pal.install_fonts()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
	var bg := ColorRect.new()
	bg.color = Color("16203a") if OS.get_cmdline_user_args().has("night") else Color("2b2f3a")
	bg.size = Vector2(1280, 720)
	add_child(bg)
	var floor_line := ColorRect.new()
	floor_line.color = Color(1, 1, 1, 0.08)
	floor_line.position = Vector2(0, 300)
	floor_line.size = Vector2(1280, 2)
	add_child(floor_line)
	for i in 4:
		_scar(Vector2(170 + i * 315, 300), 0.95, POSES[i])
	for i in range(4, POSES.size()):
		_scar(Vector2(170 + (i - 4) * 315, 640), 0.95, POSES[i])
	# the head, big
	_scar(Vector2(860, 900), 2.0, ["head", "roar", 0.6, 0.0, Vector2.ZERO])
	var l := Label.new()
	l.text = "OLD SCAR  (%s)" % tag
	l.position = Vector2(14, 8)
	l.add_theme_font_override("font", Pal.title_font())
	l.add_theme_font_size_override("font_size", 26)
	add_child(l)
	_finish.call_deferred()


func _scar(at: Vector2, s: float, pose: Array) -> void:
	var holder := Node2D.new()
	holder.position = at
	holder.scale = Vector2(s, s)
	add_child(holder)
	var o := OldScar.new()
	holder.add_child(o)
	o.visible = true
	o.set_process(false)
	o.set_physics_process(false)
	o.state = pose[1]
	o.timer = pose[2]
	o.vx = pose[3]
	o.vel = pose[4]
	o.dir = 1
	o.t = 1.3
	_scars.append([o, pose])
	var l := Label.new()
	l.text = pose[0]
	l.position = at + Vector2(-60, 14)
	l.add_theme_font_size_override("font_size", 16)
	add_child(l)


func _finish() -> void:
	# a little time for the walk and the charge to be mid-stride
	for f in 20:
		for e in _scars:
			var o: OldScar = e[0]
			o._phase_walk += absf(o.vx) / 60.0
			o.t += 1.0 / 60.0
			o.queue_redraw()
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("C:/tmp/shots")
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/scarsheet_%s.png" % tag)
	print("shot scarsheet_", tag)
	get_tree().quit()
