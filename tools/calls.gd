extends Node
## Test harness (not shipped): which things cost the most draw calls?
var level: Node
var p: CaveMan
var at := 3000.0
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		at = float(a)
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue: c.queue_free()
	p.talking = false
func calls() -> float:
	var total := 0.0
	for i in 10:
		await get_tree().process_frame
		quiet()
	for i in 10:
		await get_tree().process_frame
		quiet()
		total += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return total / 10.0
func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.invuln = 99999.0
	p.give_torch()
	level._snuffed = true
	level._panicked = true
	var space: PhysicsDirectSpaceState2D = (level as Node2D).get_world_2d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(at, -1200), Vector2(at, 1400), 1))
	p.global_position = Vector2(at, (hit["position"] as Vector2).y - 10.0)
	var base: float = await calls()
	print("at x %d: %d draw calls" % [at, base])
	# classify every direct child of the level
	var groups := {}
	for c in level.get_children():
		if not (c is CanvasItem):
			continue
		var key := c.get_class()
		var sc: Script = c.get_script()
		if sc != null:
			key = sc.resource_path.get_file() + ":" + (c.get_script().get_global_name() if c.get_script().get_global_name() != "" else "")
		# inner classes: name by what they are
		for pair in [["Pickup", Treasure.Pickup], ["Breakable", Treasure.Breakable], ["Wolf", NightBeasts.Wolf], ["Bat", NightBeasts.Bat],
				["Monkey", NightBeasts.Monkey], ["Bonfire", NightWoods.Bonfire], ["DeadTree", NightWoods.DeadTree], ["Undergrowth", World.Undergrowth],
				["Slab", World.Slab], ["Crag", NightWoods.Crag], ["CaveMan", CaveMan], ["Night", Night], ["Elder", NightBeasts.Elder],
				["Branch", NightWoods.Branch], ["MoonPuff", NightWoods.MoonPuff], ["Totem", Treasure.ShellTotem], ["Hare", Treasure.GoldenHare]]:
			if is_instance_of(c, pair[1]):
				key = pair[0]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(c)
	var rows := []
	for key in groups:
		for c in groups[key]:
			(c as CanvasItem).visible = false
		var n: float = await calls()
		for c in groups[key]:
			(c as CanvasItem).visible = true
		rows.append([base - n, key, groups[key].size()])
	# the HUD and other layers
	for layer in level.get_children().filter(func(c): return c is CanvasLayer):
		layer.visible = false
		var n: float = await calls()
		layer.visible = true
		rows.append([base - n, "layer " + layer.name + " (" + layer.get_class() + ")", 1])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows.slice(0, 16):
		print("  %5.0f calls  %-40s (%d of them)" % r)
	get_tree().quit()
