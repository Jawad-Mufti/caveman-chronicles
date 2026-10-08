extends "res://tools/harness.gd"
## FREEZES: one frame that takes far too long (a new shader compiling, a burst
## of nodes built at once). Sets him down at each spot in turn (args: x:y, or
## the default list) and walks him a little, printing every frame over 40 ms
## with the kinds of node that appeared in it. Run with rendering and
## --disable-vsync (a shader only compiles when it is first drawn).
const SPOTS := [Vector2(400, 590), Vector2(15400, 590), Vector2(15550, 2100), Vector2(15020, 640), Vector2(12150, 600)]


func run() -> void:
	p.invuln = 99999.0
	var spots: Array = []
	for a in args:
		if a.contains(":"):
			spots.append(Vector2(float(a.get_slice(":", 0)), float(a.get_slice(":", 1))))
	if spots.is_empty():
		spots = SPOTS
	for at in spots:
		await put(at)
		var before := _kinds()
		p.touch["right"] = true
		var worst := 0.0
		for i in 240:
			var t0 := Time.get_ticks_usec()
			await get_tree().process_frame
			quiet()
			var dt := (Time.get_ticks_usec() - t0) / 1000.0
			worst = maxf(worst, dt)
			if dt > 40.0:
				var now := _kinds()
				var added := []
				for k in now:
					if int(now[k]) > int(before.get(k, 0)):
						added.append("%s+%d" % [k, int(now[k]) - int(before.get(k, 0))])
				print("  %s frame %d: %.0f ms  (him at %.0f, %.0f)  new: %s" % [at, i, dt, p.global_position.x, p.global_position.y, added])
			if i % 10 == 0:
				before = _kinds()
		release()
		print("%s: worst %.0f ms" % [at, worst])


## How many nodes of each script / class are in the level.
func _kinds() -> Dictionary:
	var out := {}
	for c in level.get_children():
		var s: Script = c.get_script()
		var k: String = c.get_class()
		if s != null:
			k = s.get_global_name() if s.get_global_name() != "" else s.resource_path.get_file()
			if k == "":
				k = str(s).get_slice(":", 0)
		out[k] = int(out.get(k, 0)) + 1
	return out
