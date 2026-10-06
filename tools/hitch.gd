extends Node
## Test harness (not shipped): hunts for hitches. Walks him through the
## scripted moments (the wolves' panic, the Boulder Run, the boss's clearing)
## at running speed and reports every frame over 50 ms, and what was near.
## Run with rendering and --disable-vsync.
var level: Node
var p: CaveMan

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.invuln = 99999.0
	p.hp = 999
	p.give_torch()
	for m in level._mouths:
		m._noticed = true
	var spans := [[25600.0, 27700.0], [32000.0, 33500.0], [12300.0, 14800.0]]
	for sp in spans:
		level._move_player(Vector2(sp[0], 590), 1)
		for i in 30:
			await get_tree().process_frame
		var slow := []
		var worst := 0.0
		var sum := 0.0
		var n := 0
		var x: float = sp[0]
		while x < float(sp[1]):
			x += 5.0                       # 300 px/s
			p.global_position = Vector2(x, p.global_position.y)
			var t0 := Time.get_ticks_usec()
			await get_tree().process_frame
			var dt := (Time.get_ticks_usec() - t0) / 1000.0
			for c in level.get_children():
				if c is Dialogue:
					c.queue_free()
			p.talking = false
			sum += dt
			n += 1
			worst = maxf(worst, dt)
			if dt > 50.0:
				slow.append("x %.0f: %.0f ms (nodes %d)" % [x, dt, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
		print("%5.0f-%5.0f: avg %.1f ms, worst %.0f ms, %d frames over 50 ms %s" % [sp[0], sp[1], sum / n, worst, slow.size(), slow.slice(0, 6)])
	get_tree().quit()
