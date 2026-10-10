extends Node
## Test harness (not shipped): WHERE the home's frame time goes (run WITH
## rendering, --disable-vsync). After the warm-up, a baseline, then one thing
## switched off at a time (and back): each shelter system, the 3D Ugu, the
## CPU particles, the grass and flowers, the shadows, the lights... Each line:
## the frame (median, p95) and the process time (scripts), and what switching
## it off saved.   args: all (everything built, every relic), at=<x>,<z> (where
## he stands; default the plaza), night
var home: Node3D
var base := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	GameState.reset()
	GameState.seen["level2"] = true
	if args.has("all"):
		GameState.bones = 50
		GameState.trophies = ["sabre_fang", "bonejaw"]
		for k in Relics.KINDS:
			GameState.relics[k] = 1
		GameState.shelter = {"built": ["hammock", "campfire", "gate", "bridge", "totem", "lookout"], "seen_relics": [], "visits": 3}
		GameState.give_item("obsidian_mirror")
		GameState.give_item("fishing_stick")
	home = load("res://shelter/home.tscn").instantiate()
	add_child(home)
	_run.call_deferred()


func _frames(n: int) -> Array:
	var times: Array = []
	var proc := 0.0
	var last := Time.get_ticks_usec()
	for i in n:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	times.sort()
	return [times[n / 2], times[int(n * 0.95)], proc / n]


func _case(name: String) -> float:
	var r: Array = await _frames(180)
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var saved := "" if base == 0.0 else "  saves %5.2f ms" % (base - float(r[0]))
	print("HOMEPROF %-26s frame %5.2f ms  p95 %5.2f  process %5.2f ms  draws %4d%s" % [name, r[0], r[1], r[2], calls, saved])
	return r[0]


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var at := Vector2(0, -6)
	for a in args:
		if a.begins_with("at="):
			var p := a.substr(3).split(",")
			at = Vector2(float(p[0]), float(p[1]))
	home._pos = Vector3(at.x, home.height(at.x, at.y), at.y)
	if args.has("night"):
		home._night = 0.85
		home._night_to = 0.85
		home._apply_daylight(true)
	await _frames(400)                                     # (the warm-up: the first seconds run slow anyway)
	base = await _case("baseline")
	if args.has("quick"):
		get_tree().quit()
		return
	for s in home._systems:
		s.set_process(false)
		await _case("no " + str(s.get_script().resource_path.get_file()) + " process")
		s.set_process(true)
	var ugu: Node3D = home._model
	ugu.process_mode = Node.PROCESS_MODE_DISABLED
	await _case("no Ugu process")
	ugu.process_mode = Node.PROCESS_MODE_INHERIT
	ugu.visible = false
	await _case("no Ugu drawn")
	ugu.visible = true
	await _toggle("no CPU particles", home.find_children("*", "CPUParticles3D", true, false), "visible")
	await _toggle("no multimeshes (grass...)", home.find_children("*", "MultiMeshInstance3D", true, false), "visible")
	await _toggle("no Label3Ds", home.find_children("*", "Label3D", true, false), "visible")
	var omni := home.find_children("*", "OmniLight3D", true, false)
	print("HOMEPROF (%d omni lights, %d CPU particle systems, %d multimeshes, %d mesh instances)" % [omni.size(), home.find_children("*", "CPUParticles3D", true, false).size(),
		home.find_children("*", "MultiMeshInstance3D", true, false).size(), home.find_children("*", "MeshInstance3D", true, false).size()])
	await _toggle("no omni lights", omni, "visible")
	home._sun.shadow_enabled = false
	await _case("no sun shadows")
	home._sun.shadow_enabled = true
	home.set_process(false)
	await _case("no home._process")
	home.set_process(true)
	get_tree().quit()


func _toggle(name: String, nodes: Array, prop: String) -> void:
	var was: Array = []
	for n in nodes:
		was.append(n.get(prop))
		n.set(prop, false)
	await _case(name)
	for i in nodes.size():
		nodes[i].set(prop, was[i])
