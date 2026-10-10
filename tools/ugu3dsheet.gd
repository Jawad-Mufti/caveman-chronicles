extends Node3D
## Test harness (not shipped): a MODEL SHEET of the 3D Ugu (shelter/ugu3d.gd):
## idle, running (moving, so the air works on him), in the air; then the
## costumes and era 1. Run with rendering; PNG to C:/tmp/shots/ugu3d_<tag>.png.
##   args: tag=<name>, face (a close-up of the head), body (his bare trunk and
##   arms, close), turn (seen from the side), back (from behind), faces (every
##   feeling in EXPRESSIONS, a close-up each, on one sheet)
const UguModel := preload("res://shelter/ugu3d.gd")

var tag := "now"
var _runners: Array = []


func _ready() -> void:
	process_priority = -10
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("tag="):
			tag = a.substr(4)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("2b2f3a")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("8a94b0")
	env.environment.ambient_light_energy = 0.35
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0)          # high, from the right
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)
	var cam := Camera3D.new()
	add_child(cam)
	var turn := args.has("turn")
	var looks := [[2, "plain", "idle"], [2, "plain", "run"], [2, "plain", "air"], [2, "bear_cloak", "run"], [2, "wolf_hood", "idle"],
		[2, "firekeeper", "idle"], [1, "plain", "idle"]]
	if args.has("moves"):
		looks = [[2, "plain", "sprint"], [2, "plain", "rise"], [2, "plain", "air"], [2, "plain", "flip"], [2, "plain", "land"],
			[2, "plain", "yawn"], [2, "plain", "look"]]
	if args.has("face") or args.has("faces"):
		looks = [[2, "plain", "idle"]]
		cam.position = Vector3(0.3, 1.7, 1.25)
		cam.look_at(Vector3(0, 1.62, 0))
		cam.fov = 38.0
	elif args.has("body"):
		# a close-up of his trunk and arms, bare (era 1): the muscles
		looks = [[1, "plain", "idle"]]
		cam.position = Vector3(0.25, 1.15, 2.2)
		cam.look_at(Vector3(0, 1.1, 0))
		cam.fov = 40.0
	else:
		cam.position = Vector3(0, 1.1, 7.2)
		cam.look_at(Vector3(0, 0.85, 0))
		cam.fov = 40.0
	for i in looks.size():
		GameState.skin = looks[i][1]
		var u: Node3D = UguModel.new()
		u.era = looks[i][0]
		u.position = Vector3((i - (looks.size() - 1) * 0.5) * 1.15, 0, 0)
		u.rotation.y = (PI * 0.5 if turn else 0.35)
		if args.has("back"):
			u.rotation.y = PI + 0.35
		add_child(u)
		match looks[i][2]:
			"run":
				u.speed = 1.0
				_runners.append(u)
			"air":
				u.air = true
				_runners.append(u)
			# (moves) the shot is taken 50 frames in
			"sprint":
				u.speed = 1.0
				u.sprint = 1.0
				u.set_meta("v", Vector3(0, 0, 8.2))
				_runners.append(u)
			"rise":
				u.air = true
				u.set_meta("v", Vector3(0, 5.0, 2.0))
				_runners.append(u)
			"flip":
				u.air = true
				u.set_meta("v", Vector3(0, 2.0, 2.0))
				u.set_meta("at", [33, "jumped"])          # half way round at the shot
				_runners.append(u)
			"land":
				u.set_meta("at", [46, "landed"])
			"yawn":
				u.set("_idle", 6.2)
			"look":
				u.look_at_point = u.position + Vector3(-3.0, 1.0, 1.5)
	GameState.skin = "plain"
	if args.has("faces"):
		_faces.call_deferred(get_children().filter(func(c): return c is UguModel)[0])
		return
	_finish.call_deferred()


## Every feeling in EXPRESSIONS, a close-up each, on one sheet (4 across, in
## the table's order): PNG to C:/tmp/shots/ugu3d_<tag>.png.
func _faces(u: Node3D) -> void:
	u.set("_blink_in", 9999.0)
	u.set("_quirk_in", 9999.0)
	u.set("_gaze_in", 9999.0)
	var names: Array = UguModel.EXPRESSIONS.keys()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			names = Array(a.substr(5).split(","))
	var cols := 4
	var cw := 320
	var ch := 300
	var sheet := Image.create(cw * cols, ch * ceili(names.size() / float(cols)), false, Image.FORMAT_RGB8)
	for i in names.size():
		u.emote(names[i], 9999.0)
		for f in 40:
			await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var part := img.get_region(Rect2i(560 if OS.get_cmdline_user_args().has("turn") else 320, 0, 640, 600))
		part.resize(cw, ch)
		sheet.blit_rect(part, Rect2i(0, 0, cw, ch), Vector2i((i % cols) * cw, (i / cols) * ch))
	DirAccess.make_dir_recursive_absolute("C:/tmp/shots")
	sheet.save_png("C:/tmp/shots/ugu3d_%s.png" % tag)
	print("shot ugu3d_", tag, ": ", ", ".join(names))
	get_tree().quit()


var _frame := 0

func _process(delta: float) -> void:
	_frame += 1
	for u in get_children():
		if u.has_meta("at") and u.get_meta("at")[0] == _frame:
			if u.get_meta("at")[1] == "jumped":
				u.jumped(true)
			else:
				u.landed(1.0)
	# runners run on the spot: before each of them moves (this runs first), tell
	# him where he "was" a frame ago, so he feels a run's velocity (a fall's too)
	for u in _runners:
		var n: Node3D = u
		var v: Vector3 = n.global_transform.basis.z * 5.0 + (Vector3(0, -4.0, 0) if n.air else Vector3.ZERO)
		if n.has_meta("v"):
			var mv: Vector3 = n.get_meta("v")
			v = n.global_transform.basis.z * mv.z + Vector3(0, mv.y, 0)
		n._last = n.global_position - v * delta


func _finish() -> void:
	for i in 50:
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("C:/tmp/shots")
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/ugu3d_%s.png" % tag)
	print("shot ugu3d_", tag)
	get_tree().quit()
