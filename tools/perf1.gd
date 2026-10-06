extends Node
var level: Node
var p: CaveMan
func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level1/level1.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.invuln = 99999.0
	p.hp = 999
	var worst := 0.0
	var worst_at := 0.0
	var sum := 0.0
	var n := 0
	var x := 200.0
	while x < 9200.0:
		var space: PhysicsDirectSpaceState2D = (level as Node2D).get_world_2d().direct_space_state
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(x, -1200), Vector2(x, 1400), 1))
		p.global_position = Vector2(x, ((hit["position"] as Vector2).y - 10.0) if not hit.is_empty() else 500.0)
		for i in 10:
			await get_tree().process_frame
		var calls := 0.0
		for i in 10:
			var t0 := Time.get_ticks_usec()
			await get_tree().process_frame
			sum += (Time.get_ticks_usec() - t0) / 1000.0
			n += 1
			calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		if calls / 10.0 > worst:
			worst = calls / 10.0
			worst_at = x
		x += 500.0
	print("Level 1: average frame %.2f ms, most draw calls %d (at x %d)" % [sum / n, worst, worst_at])
	get_tree().quit()
