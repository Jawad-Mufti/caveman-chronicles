extends Node3D
## Test harness (not shipped): a MODEL SHEET of the 3D Ugu (shelter/ugu3d.gd):
## idle, running (moving, so the air works on him), in the air; then the
## costumes and era 1. Run with rendering; PNG to C:/tmp/shots/ugu3d_<tag>.png.
##   args: tag=<name>, face (a close-up of the head), turn (seen from the side)
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
	if args.has("face"):
		looks = [[2, "plain", "idle"]]
		cam.position = Vector3(0.25, 1.75, 1.15)
		cam.look_at(Vector3(0, 1.68, 0))
		cam.fov = 38.0
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
		add_child(u)
		match looks[i][2]:
			"run":
				u.speed = 1.0
				_runners.append(u)
			"air":
				u.air = true
				_runners.append(u)
	GameState.skin = "plain"
	_finish.call_deferred()


func _process(delta: float) -> void:
	# runners run on the spot: before each of them moves (this runs first), tell
	# him where he "was" a frame ago, so he feels a run's velocity (a fall's too)
	for u in _runners:
		var n: Node3D = u
		var v: Vector3 = n.global_transform.basis.z * 5.0 + (Vector3(0, -4.0, 0) if n.air else Vector3.ZERO)
		n._last = n.global_position - v * delta


func _finish() -> void:
	for i in 50:
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("C:/tmp/shots")
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/ugu3d_%s.png" % tag)
	print("shot ugu3d_", tag)
	get_tree().quit()
