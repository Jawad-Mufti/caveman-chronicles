extends "res://tools/harness.gd"
## What the FAR-AWAY world costs: the real frame time at a spot as it is, then
## with every level child further than `far=` px from him (default 2200) not
## processed, alternated three times (medians). The difference is the most
## that putting distant things to sleep could save. Run with rendering and
## --disable-vsync.  args: x:y spots (default the Dig, the graveyard, the start)


func run() -> void:
	p.invuln = 99999.0
	var far := 2200.0
	var spots: Array = []
	for a in args:
		if a.begins_with("far="):
			far = float(a.substr(4))
		elif a.contains(":"):
			spots.append(Vector2(float(a.get_slice(":", 0)), float(a.get_slice(":", 1))))
	if spots.is_empty():
		spots = [Vector2(15020, 640), Vector2(15400, 590), Vector2(400, 590)]
	for at in spots:
		await put(at)
		await frames(120)
		var distant: Array = []
		var kinds := {}
		for c in level.get_children():
			if c is Node2D and c != p and (c as Node2D).global_position.distance_to(p.global_position) > far \
					and c.process_mode != Node.PROCESS_MODE_DISABLED:
				distant.append(c)
				var k: String = _kind(c)
				kinds[k] = int(kinds.get(k, 0)) + 1
		var top := kinds.keys()
		top.sort_custom(func(a, b) -> bool: return int(kinds[a]) > int(kinds[b]))
		if args.has("kinds"):
			print("  far kinds: %s" % ", ".join(top.slice(0, 30).map(func(k) -> String: return "%s x%d" % [k, kinds[k]])))
		var ons: Array = []
		var offs: Array = []
		for r in 3:
			ons.append(await _measure(90))
			for c in distant:
				if is_instance_valid(c):
					c.process_mode = Node.PROCESS_MODE_DISABLED
			offs.append(await _measure(90))
			for c in distant:
				if is_instance_valid(c):
					c.process_mode = Node.PROCESS_MODE_INHERIT
		ons.sort()
		offs.sort()
		print("%s: frame %.2f ms; with the %d far things asleep %.2f ms (saves %.2f)" % [at, ons[1], distant.size(), offs[1], float(ons[1]) - float(offs[1])])


func _measure(n: int) -> float:
	for i in 15:
		await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	for i in n:
		await get_tree().process_frame
	return (Time.get_ticks_usec() - t0) / 1000.0 / n


func _kind(c: Node) -> String:
	var s: Script = c.get_script()
	if s == null:
		return c.get_class()
	if s.get_global_name() != "":
		return s.get_global_name()
	for top in [NightWoods, NightBeasts, World, Caves, CaveTrials, SkyLanes, Steppe, Treasure, Dig, Underground, Canyon, Mountain, TarPits, Friends, OldScar, Hoards]:
		var m: Dictionary = (top as Script).get_script_constant_map()
		for k in m:
			if m[k] is Script and m[k] == s:
				return "%s.%s" % [(top as Script).get_global_name(), k]
	return s.resource_path.get_file()
