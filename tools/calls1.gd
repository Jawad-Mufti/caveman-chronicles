extends Node
var level: Node
var p: CaveMan
var at := 7200.0
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		at = float(a)
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level1/level1.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func calls() -> float:
	var total := 0.0
	for i in 8:
		await get_tree().process_frame
	for i in 8:
		await get_tree().process_frame
		total += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return total / 8.0
func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.invuln = 99999.0
	var space: PhysicsDirectSpaceState2D = (level as Node2D).get_world_2d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(at, -1200), Vector2(at, 1400), 1))
	p.global_position = Vector2(at, (hit["position"] as Vector2).y - 10.0)
	var base: float = await calls()
	print("Level 1 at x %d: %d draw calls" % [at, base])
	var kinds := {"Slab": World.Slab, "Ceiling": World.Ceiling, "SkyFill": World.SkyFill, "Clouds": World.Clouds, "Ridge": World.Ridge,
		"CaveWall": World.CaveWall, "RockPickup": World.RockPickup, "BerryBush": World.BerryBush, "DistantBoar": World.DistantBoar,
		"Bamboo": World.Bamboo, "SpringBush": World.SpringBush, "StickPickup": World.StickPickup, "Canopy": World.Canopy,
		"JungleCliff": World.JungleCliff, "JungleWall": World.JungleWall, "Gem": World.Gem, "Panorama": World.Panorama,
		"Waterfall": World.Waterfall, "LightShafts": World.LightShafts, "Birds": World.Birds, "Motes": World.Motes,
		"Critter": Critter, "CaveMan": CaveMan}
	var rows := []
	var all_nodes: Array = []
	var stack: Array = [level]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			all_nodes.append(c)
			stack.append(c)
	for key in kinds:
		var hits := all_nodes.filter(func(c): return is_instance_of(c, kinds[key]) and c is CanvasItem and c.visible)
		if hits.is_empty():
			continue
		for c in hits:
			c.visible = false
		var n: float = await calls()
		for c in hits:
			c.visible = true
		rows.append([base - n, key, hits.size()])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows.slice(0, 12):
		print("  %5.0f calls  %-16s (%d)" % r)
	get_tree().quit()
