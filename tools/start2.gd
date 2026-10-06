extends Node
## Test harness (not shipped): the first frames — how long each takes, and physics steps per frame.
var level: Node
func _ready() -> void:
	var t0 := Time.get_ticks_usec()
	level = load("res://level2/level2.tscn").instantiate()
	var t1 := Time.get_ticks_usec()
	add_child(level)
	var t2 := Time.get_ticks_usec()
	print("load+instantiate %.0f ms, _ready of the level %.0f ms" % [(t1 - t0) / 1000.0, (t2 - t1) / 1000.0])
	_run.call_deferred()
func _run() -> void:
	var last := Time.get_ticks_usec()
	var pf := Engine.get_physics_frames()
	var line := ""
	for i in 150:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var steps := Engine.get_physics_frames() - pf
		pf = Engine.get_physics_frames()
		if i < 12 or (now - last) > 34300:
			line += "f%d:%.0fms/%dsteps  " % [i, (now - last) / 1000.0, steps]
		last = now
	print(line)
	get_tree().quit()
