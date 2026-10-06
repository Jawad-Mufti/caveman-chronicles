extends Node
## Test harness (not shipped): outrun the boulder; and get caught if you stop.
var level: Node
var p: CaveMan
var mode := "run"
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		mode = a
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		for c in level.get_children():
			if c is Dialogue: c.queue_free()
		p.talking = false
func ahead_blocked() -> bool:
	# a gap or a log just ahead?
	var space: PhysicsDirectSpaceState2D = (level as Node2D).get_world_2d().direct_space_state
	var x := p.global_position.x + 28.0
	var ground := space.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(x, 560), Vector2(x, 640), 1))
	var wall := space.intersect_ray(PhysicsRayQueryParameters2D.create(p.global_position + Vector2(0, -20), p.global_position + Vector2(62, -20), 1))
	return ground.is_empty() or not wall.is_empty()
func _run() -> void:
	await get_tree().physics_frame
	p = level.player
	await frames(5)
	p.invuln = 0.0
	p.global_position = Vector2(26450, 590)
	await frames(20)
	var closest := 24299.0
	var caught := false
	var hold := 0
	for f in 60 * 20:
		p.touch["right"] = true
		p.touch["jump"] = hold > 0
		hold = maxi(hold - 1, 0)
		if mode == "stop" and f > 90 and f < 400:
			p.touch["right"] = false
		elif p.is_on_floor() and ahead_blocked() and hold == 0:
			p.touch["jump"] = true
			hold = 14          # hold the button for a full jump, like a player does
		var x_before := p.global_position.x
		var y_before := p.global_position.y
		var st: String = level._boulder.state
		var bx: float = level._boulder.position.x
		await frames(1)
		if x_before - p.global_position.x > 250.0:
			print("  sent back from (%d, %d), boulder %s at %d, on floor %s" % [x_before, y_before, st, bx, p.is_on_floor()])
		if level._run_on and level._boulder.state == "roll":
			closest = minf(closest, p.global_position.x - level._boulder.position.x)
		if x_before - p.global_position.x > 250.0:
			caught = true
			break
		if level._run_done:
			break
	p.touch["right"] = false
	await frames(60)
	var stash := level.get_children().filter(func(c): return c is Treasure.Breakable and c.id == "rstash").size() > 0
	print("%s: boulder done %s, caught %s, closest it came %d px, man at x %d, stash dropped %s, hearts %d" % [mode, level._run_done, caught, closest, p.global_position.x, stash, p.hp])
	get_tree().quit()
