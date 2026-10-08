extends "res://tools/harness.gd"
## What the darkness costs (Night): how many lights and glows the level has,
## and the time of Night's per-frame work at a few spots, called directly
## (headless is fine: it is script time, not drawing).


func run() -> void:
	var night: Night = level.night
	print("lights %d, glows %d, nodes in the tree %d" % [get_tree().get_nodes_in_group("light").size(),
		get_tree().get_nodes_in_group("glow").size(), get_tree().get_node_count()])
	for at in [Vector2(400, 590), Vector2(15020, 640), Vector2(15400, 590), Vector2(15550, 2100)]:
		await put(at)
		await frames(30)
		var n := 200
		var t0 := Time.get_ticks_usec()
		for i in n:
			night._physics_process(0.016)
		var phys := (Time.get_ticks_usec() - t0) / 1000.0 / n
		t0 = Time.get_ticks_usec()
		for i in n:
			night._process(0.016)
		var proc := (Time.get_ticks_usec() - t0) / 1000.0 / n
		var glow: Node2D = null
		for c in night.get_children(true):
			if c is Night.Glow:
				glow = c
		for c in level.get_children():
			if c is Night.Glow:
				glow = c
		var near := 0
		var cx := p.global_position.x
		for g in get_tree().get_nodes_in_group("glow"):
			if g is Node2D and absf((g as Node2D).global_position.x - cx) < 900.0:
				near += 1
		print("%s: Night physics %.3f ms, process %.3f ms; glows near %d; glow layer found %s" % [at, phys, proc, near, glow != null])
