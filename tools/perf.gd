extends Node
## Test harness (not shipped): where does Level 2 spend its time?
var level: Node
var p: CaveMan
var mode := "walk"
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		mode = a
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue: c.queue_free()
	p.talking = false
func sample(n: int) -> Dictionary:
	var proc := 0.0
	var phys := 0.0
	var worst := 0.0
	var calls := 0.0
	var frame_worst := 0.0
	var frame_sum := 0.0
	for i in n:
		var t0 := Time.get_ticks_usec()
		await get_tree().process_frame
		var dt := (Time.get_ticks_usec() - t0) / 1000.0
		frame_worst = maxf(frame_worst, dt)
		frame_sum += dt
		quiet()
		var pr := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var ph := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		proc += pr
		phys += ph
		worst = maxf(worst, pr + ph)
		calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return {"proc": proc / n, "phys": phys / n, "worst": worst, "calls": calls / n, "frame_worst": frame_worst, "frame": frame_sum / n}
func _run() -> void:
	if mode == "start":
		# the first seconds of the level, frame by frame
		var spikes := []
		for i in 240:
			var t0 := Time.get_ticks_usec()
			await get_tree().process_frame
			var dt := (Time.get_ticks_usec() - t0) / 1000.0
			if i > 0 and dt > 40.0:
				spikes.append("frame %d: %.0f ms" % [i, dt])
		print("start of level: frames over 40 ms: %d  %s" % [spikes.size(), spikes.slice(0, 12)])
		get_tree().quit()
		return
	await get_tree().process_frame
	p = level.player
	p.invuln = 99999.0
	p.hp = 999
	p.give_torch()
	level._snuffed = true
	level._panicked = true
	for m in level._mouths:
		m._noticed = true
	var spots := []
	var x := 200.0
	while x < 33400.0:
		spots.append(x)
		x += 400.0
	spots.append_array([34800.0, 35600.0, 36300.0, 37300.0, 38100.0, 38600.0])
	var rows := []
	for sx in spots:
		var gy := 590.0
		if sx < 34300.0:
			var space: PhysicsDirectSpaceState2D = (level as Node2D).get_world_2d().direct_space_state
			var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(sx, -1200), Vector2(sx, 1400), 1))
			if not hit.is_empty():
				gy = (hit["position"] as Vector2).y - 10.0
		p.global_position = Vector2(sx, gy)
		p.velocity = Vector2.ZERO
		for i in 15:
			await get_tree().process_frame
			quiet()
		var s := await sample(30)
		rows.append([sx, s])
	rows.sort_custom(func(a, b): return a[1]["frame"] > b[1]["frame"])
	print("nodes in the level: %d" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var tot := 0.0
	for r in rows:
		tot += r[1]["frame"]
	print("average frame (game work only) over the level: %.2f ms" % (tot / rows.size()))
	print("worst spots: average frame, worst frame, draw calls")
	for r in rows.slice(0, 14):
		var s: Dictionary = r[1]
		print("  x %5d   %.2f ms   worst %.1f ms   draw calls %d" % [r[0], s["frame"], s["frame_worst"], s["calls"]])
	get_tree().quit()
