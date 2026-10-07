extends Node
## Test harness (not shipped): IDLE. He stands still at the start for
## `min=<n>` minutes (default 12), nothing pressed, nothing protecting him
## (`safe` keeps him from harm). Every minute: real frame time (average and
## worst), nodes, objects, memory, beasts near him, his state, and what kinds
## of node grew. Run it WITH rendering: what piles up may be on the GPU side.
var level: Node
var p: CaveMan
var minutes := 12
var safe := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("min="):
			minutes = int(a.split("=")[1])
		safe = safe or a == "safe"
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func kinds() -> Dictionary:
	var d := {}
	var stack: Array = [level]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var k: String = n.get_class()
		var s = n.get_script()
		if s != null and s.get_global_name() != "":
			k = s.get_global_name()
		elif s != null:
			k = s.resource_path.get_file() + ":" + k
		d[k] = int(d.get(k, 0)) + 1
		stack.append_array(n.get_children())
	return d

func _run() -> void:
	p = level.player
	await get_tree().process_frame
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	p.talking = false
	var last := kinds()
	for m in minutes:
		var sum := 0.0
		var worst := 0.0
		var n := 0
		var t_end := Time.get_ticks_msec() + 60000
		while Time.get_ticks_msec() < t_end:
			var t0 := Time.get_ticks_usec()
			await get_tree().process_frame
			var dt := (Time.get_ticks_usec() - t0) / 1000.0
			sum += dt
			worst = maxf(worst, dt)
			n += 1
			if safe:
				p.invuln = 1.0
		var now := kinds()
		var grew := []
		for k in now:
			var d: int = int(now[k]) - int(last.get(k, 0))
			if d != 0:
				grew.append("%s%+d" % [k, d])
		var near := 0
		for c in get_tree().get_nodes_in_group("critters"):
			if (c as Node2D).global_position.distance_to(p.global_position) < 900.0:
				near += 1
		print("min %2d: frame %.1f ms (worst %.0f, %d fps)  nodes %d objects %d mem %.1f MB  beasts near %d  hp %d dead %s torch %.2f  changed: %s" % [m + 1,
			sum / n, worst, n / 60, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, near, p.hp, p.dead, p.torch_fuel, ", ".join(grew.slice(0, 10))])
		last = now
	get_tree().quit()
