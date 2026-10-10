extends Node
## Test harness (not shipped): what the home (shelter/home.gd) costs per frame.
## Real frames (run WITH rendering, --disable-vsync), 240 each, medians:
## everything; without the 3D Ugu; without shadows on the lights; and the
## draw calls / objects drawn. One HOMECOST line per case.
var home: Node3D


func _ready() -> void:
	GameState.seen["level2"] = true
	home = load("res://shelter/home.tscn").instantiate()
	add_child(home)
	_run.call_deferred()


func _frames(n: int) -> Array:
	var times: Array = []
	var last := Time.get_ticks_usec()
	for i in n:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	times.sort()
	return times


func _case(name: String) -> void:
	await _frames(60)
	var t: Array = await _frames(240)
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var objs := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	print("HOMECOST %-22s median %5.2f ms  p95 %5.2f ms  worst %6.2f ms  draw calls %d  objects %d" % [name, t[120], t[228], t[239], calls, objs])


func _run() -> void:
	if OS.get_cmdline_user_args().has("paper"):
		home.call("swap_ugu")                  # the paper Ugu (his 2D rig on a card) instead of the 3D figure
	await _frames(30)
	var ugu: Node3D = home.get("_model")
	var meshes := ugu.find_children("*", "MeshInstance3D", true, false).size()
	print("HOMECOST the 3D Ugu: %d meshes; %d still shapes merged into one mesh" % [meshes, int(home.get("_baked"))])
	# what is still drawn on its own, and why
	var kinds := {}
	for n in home.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		var why := g.get_class()
		if g is MeshInstance3D:
			var mi := g as MeshInstance3D
			if mi.mesh == null:
				continue
			var m := mi.material_override
			if ugu.is_ancestor_of(mi):
				why = "Ugu"
			elif m is ShaderMaterial:
				why = "shader"
			elif m is StandardMaterial3D:
				var sm := m as StandardMaterial3D
				why = "glow" if sm.emission_enabled else ("transparent" if sm.transparency != 0 else ("vertex colour (merged)" if sm.vertex_color_use_as_albedo else "plain, kept (moves / fades)"))
			else:
				why = "no material"
		kinds[why] = int(kinds.get(why, 0)) + 1
	print("HOMECOST still separate: ", kinds)
	await _case("all")
	ugu.visible = false
	ugu.process_mode = Node.PROCESS_MODE_DISABLED
	await _case("no Ugu")
	ugu.visible = true
	ugu.process_mode = Node.PROCESS_MODE_INHERIT
	var lights := home.find_children("*", "Light3D", true, false)
	var shadowed := 0
	for l in lights:
		if (l as Light3D).shadow_enabled and not l is DirectionalLight3D:
			shadowed += 1
			(l as Light3D).shadow_enabled = false
	print("HOMECOST %d lights, %d omni/spot with shadows (now off)" % [lights.size(), shadowed])
	await _case("no omni shadows")
	get_tree().quit()
