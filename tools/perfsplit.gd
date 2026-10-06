extends Node
## Test harness (not shipped): what costs the frame time at a spot? Measures
## the average frame, then switches off each kind of thing in turn (hidden,
## not processed) and reports how much time that saved. Run with rendering and
## --disable-vsync.  args: x positions (default 1400 1800)
var level: Node
var p: CaveMan

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	p.talking = false

func measure(n: int) -> float:
	for i in 10:
		await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	for i in n:
		await get_tree().process_frame
		quiet()
	return (Time.get_ticks_usec() - t0) / 1000.0 / n

## Every inner class of the game's classes, by script, so a node can be named.
func class_names() -> Dictionary:
	var out := {}
	var tops := {"NightWoods": NightWoods, "World": World, "NightBeasts": NightBeasts, "Caves": Caves,
		"CaveTrials": CaveTrials, "SkyLanes": SkyLanes, "Steppe": Steppe, "Treasure": Treasure, "Night": Night}
	for tn in tops:
		var s: Script = tops[tn]
		out[s] = tn
		for k in s.get_script_constant_map():
			var v = s.get_script_constant_map()[k]
			if v is Script:
				out[v] = "%s.%s" % [tn, k]
	return out

func label(n: Node, names: Dictionary) -> String:
	var s: Script = n.get_script()
	if s != null and names.has(s):
		return names[s]
	if s != null and s.get_global_name() != "":
		return s.get_global_name()
	return n.get_class()

func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.invuln = 99999.0
	p.hp = 999
	p.give_torch()
	level._snuffed = true
	level._panicked = true
	for m in level._mouths:
		m._noticed = true
	var xs := []
	for a in OS.get_cmdline_user_args():
		if a.is_valid_float():
			xs.append(float(a))
	if xs.is_empty():
		xs = [1400.0, 1800.0]
	var names := class_names()
	for x in xs:
		p.global_position = Vector2(x, 590)
		p.velocity = Vector2.ZERO
		await measure(30)
		var base := await measure(120)
		# group the level's direct children by kind
		var kinds := {}
		for c in level.get_children():
			if c == p:
				continue
			var k := label(c, names)
			if not kinds.has(k):
				kinds[k] = []
			kinds[k].append(c)
		var rows := []
		for k in kinds:
			var nodes: Array = kinds[k]
			var saved := []
			for n in nodes:
				if not is_instance_valid(n):
					saved.append([0, true])
					continue
				saved.append([n.process_mode, n.visible if n is CanvasItem else true])
				n.process_mode = Node.PROCESS_MODE_DISABLED
				if n is CanvasItem:
					n.visible = false
			var t := await measure(60)
			for i in nodes.size():
				if not is_instance_valid(nodes[i]):
					continue
				var n: Node = nodes[i]
				n.process_mode = saved[i][0]
				if n is CanvasItem:
					n.visible = saved[i][1]
			rows.append([k, nodes.size(), base - t])
		rows.sort_custom(func(a, b): return a[2] > b[2])
		print("x %.0f: frame %.2f ms; the costliest kinds (time saved with them off):" % [x, base])
		for r in rows.slice(0, 14):
			print("   %-28s x%-4d %5.2f ms" % [r[0], r[1], r[2]])
	get_tree().quit()
