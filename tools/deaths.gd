extends Node
## Test harness (not shipped): kill one of everything and watch the deaths play out.
var level: Node
var p: CaveMan
func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func _run() -> void:
	for i in 5: await get_tree().physics_frame
	p = level.player
	for c in level.get_children():
		if c is Dialogue: c.queue_free()
	p.talking = false
	var picked := {}
	for c in level.get_children():
		var k := ""
		if c is NightBeasts.Wolf: k = "wolf"
		elif c is NightBeasts.Bat: k = "bat"
		elif c is Caves.Spider: k = "spider"
		elif c is Caves.Rat: k = "rat"
		elif c is Caves.Snake: k = "snake"
		if k != "" and not picked.has(k):
			picked[k] = c
	var track := {}
	for k in picked:
		var c: Critter = picked[k]
		track[k] = [c.global_position, 0.0, 0.0]
		c.take_hit(99, 1)
	var t := 0.0
	while t < 1.5:
		await get_tree().process_frame
		t += get_process_delta_time()
		for k in picked:
			var c = picked[k]
			if is_instance_valid(c):
				var d: Vector2 = c.global_position - track[k][0]
				track[k][1] = maxf(track[k][1], absf(d.x))
				track[k][2] = maxf(track[k][2], absf(c.rotation))
	for k in track:
		print("%-7s thrown %3.0f px, turned up to %.1f rad, gone after the animation: %s" % [k, track[k][1], track[k][2], not is_instance_valid(picked[k])])
	print("time scale back to normal: %s" % (Engine.time_scale == 1.0))
	get_tree().quit()
