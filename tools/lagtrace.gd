extends Node
## Test harness (not shipped): hunts the "sometimes it lags" feeling. Run it
## like the game runs — with rendering and vsync ON (no --disable-vsync):
## moves him along the level at running speed and records every displayed
## frame: how long it took, how many physics steps ran in it, whether time was
## slowed (a hit-stop), and what new things were made that frame.
## Reports: the screen's refresh rate, how even the frames were, and the slow
## ones with their likely cause.
## args: x0 x1 (default 200 33300)
var level: Node
var p: CaveMan
var _added: Array = []

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	get_tree().node_added.connect(func(n: Node) -> void:
		var s: Script = n.get_script()
		_added.append(s.resource_path.get_file() if s != null else n.get_class()))
	_run.call_deferred()

## How many of each kind of thing there are, everywhere in the tree.
func census() -> Dictionary:
	var out := {}
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var s: Script = n.get_script()
		var k := (s.resource_path.get_file() + ":" + n.get_class()) if s != null else n.get_class()
		out[k] = int(out.get(k, 0)) + 1
		stack.append_array(n.get_children())
	return out

func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.invuln = 99999.0
	p.hp = 999
	p.give_torch()
	for m in level._mouths:
		m._noticed = true
	for c in level.get_children():
		if c is World.Trigger:
			c.queue_free()         # no talks stopping him
	var xs: Array = []
	for a in OS.get_cmdline_user_args():
		if a.is_valid_float():
			xs.append(float(a))
	var x0: float = xs[0] if xs.size() > 0 else 200.0
	var x1: float = xs[1] if xs.size() > 1 else 33300.0
	print("screen refresh %.0f Hz, vsync %s, physics %d Hz, physics interpolation %s" % [DisplayServer.screen_get_refresh_rate(),
		DisplayServer.window_get_vsync_mode(), Engine.physics_ticks_per_second, ProjectSettings.get_setting("physics/common/physics_interpolation", false)])
	level._move_player(Vector2(x0, 590), 1)
	for i in 30:
		await get_tree().process_frame
	var kinds0 := census()
	var nodes0 := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var x := x0
	var frames := 0
	var deltas: Array = []
	var steps_hist := {}
	var slow: Array = []
	var last_phys := Engine.get_physics_frames()
	var t_last := Time.get_ticks_usec()
	while x < x1:
		_added.clear()
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - t_last) / 1000.0
		t_last = now
		var steps := Engine.get_physics_frames() - last_phys
		last_phys = Engine.get_physics_frames()
		steps_hist[steps] = int(steps_hist.get(steps, 0)) + 1
		frames += 1
		deltas.append(dt)
		x += 300.0 * dt / 1000.0
		p.global_position.x = x
		for c in level.get_children():
			if c is Dialogue:
				c.queue_free()
		p.talking = false
		p.torch_fuel = 1.0
		if dt > 25.0:
			var made := {}
			for a in _added:
				made[a] = int(made.get(a, 0)) + 1
			slow.append([dt, x, steps, Engine.time_scale, made])
	deltas.sort()
	var n := deltas.size()
	print("%d frames from x %.0f to %.0f: median %.1f ms, 95%% %.1f ms, 99%% %.1f ms, worst %.1f ms" % [n, x0, x1,
		deltas[n / 2], deltas[int(n * 0.95)], deltas[int(n * 0.99)], deltas[n - 1]])
	print("physics steps per displayed frame: %s" % steps_hist)
	print("frames over 25 ms: %d" % slow.size())
	for i in 120:
		await get_tree().process_frame
	var kinds1 := census()
	print("nodes: %d at the start, %d at the end" % [nodes0, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	for k in kinds1:
		var d: int = int(kinds1[k]) - int(kinds0.get(k, 0))
		if d > 3:
			print("  grew: %-30s +%d" % [k, d])
	slow.sort_custom(func(a, b): return a[0] > b[0])
	for s in slow.slice(0, 20):
		print("  %5.1f ms at x %5.0f  steps %d  time scale %.2f  made %s" % [s[0], s[1], s[2], s[3], s[4]])
	get_tree().quit()
