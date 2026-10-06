extends Node
## Test harness (not shipped): smash everything; check every piece lands somewhere reachable.
var level: Node
var p: CaveMan
func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
func _run() -> void:
	await frames(5)
	p = level.player
	p.global_position = Vector2(50, 590)
	p.set_physics_process(false)
	var sources := level.get_children().filter(func(c): return c is Treasure.Breakable or c is Treasure.ShellTotem or c is Treasure.GoldenHare)
	print("things to smash: %d" % sources.size())
	for src in sources:
		for k in 8:
			if is_instance_valid(src):
				src.take_hit(3, 1 if k % 2 == 0 else -1)
				await frames(2)
	await frames(300)
	var space: PhysicsDirectSpaceState2D = (level as Node2D).get_world_2d().direct_space_state
	var total := 0
	var flying := 0
	var buried := 0
	var floating := 0
	var worst := []
	for c in level.get_children():
		if not (c is Treasure.Pickup) or c.id.begins_with("s") or c.id.begins_with("c") or c.id.begins_with("a") or c.id.begins_with("v") or c.id.begins_with("k") or c.id.begins_with("m"):
			continue
		total += 1
		if c.vel != Vector2.ZERO:
			flying += 1
			worst.append("still flying %s at %s" % [c.id, c.global_position.round()])
			continue
		var pq := PhysicsPointQueryParameters2D.new()
		pq.position = c.global_position
		pq.collision_mask = 1
		if not space.intersect_point(pq).is_empty():
			buried += 1
			worst.append("inside rock %s at %s" % [c.id, c.global_position.round()])
			continue
		var rq := PhysicsRayQueryParameters2D.create(c.global_position, c.global_position + Vector2(0, 40), 1)
		if space.intersect_ray(rq).is_empty():
			floating += 1
			worst.append("no ground under %s at %s" % [c.global_position.round(), c.id])
	print("popped pieces: %d | still flying %d, inside rock %d, hanging in the air %d" % [total, flying, buried, floating])
	for w in worst.slice(0, 12):
		print("  ", w)
	get_tree().quit()
