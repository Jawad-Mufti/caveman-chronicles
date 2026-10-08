extends "res://tools/harness.gd"
## A/B: the SLEEPER on and off at a few spots (the real frame time, three
## alternations, medians). Run with rendering and --disable-vsync.
##   args: x:y spots (default the Dig, the graveyard, the start)


func run() -> void:
	p.invuln = 99999.0
	var spots: Array = []
	for a in args:
		if a.contains(":"):
			spots.append(Vector2(float(a.get_slice(":", 0)), float(a.get_slice(":", 1))))
	if spots.is_empty():
		spots = [Vector2(15020, 640), Vector2(15400, 590), Vector2(400, 590)]
	var sl: Sleeper = level.sleeper
	for at in spots:
		await put(at)
		await frames(60)
		var ons: Array = []
		var offs: Array = []
		var asleep := 0
		for r in 3:
			sl.process_mode = Node.PROCESS_MODE_ALWAYS
			await frames(12)                      # (it takes a few frames to doze them all)
			asleep = sl.asleep()
			ons.append(await _measure(90))
			sl.process_mode = Node.PROCESS_MODE_DISABLED
			sl.wake_all()
			offs.append(await _measure(90))
		sl.process_mode = Node.PROCESS_MODE_ALWAYS
		ons.sort()
		offs.sort()
		check("%s: the sleeper saves time (%d asleep)" % [at, asleep], float(ons[1]) < float(offs[1]),
			"%.2f ms with it, %.2f ms without (saves %.2f)" % [ons[1], offs[1], float(offs[1]) - float(ons[1])])


func _measure(n: int) -> float:
	for i in 15:
		await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	for i in n:
		await get_tree().process_frame
	return (Time.get_ticks_usec() - t0) / 1000.0 / n
