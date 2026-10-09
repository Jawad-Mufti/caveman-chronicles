extends "res://tools/harness.gd"
## A screenshot SWEEP of the level, for looking it over: he is set down (off
## any vine) at each spot and the picture is taken once he has settled.
## Run with rendering; PNGs to C:/tmp/shots/sweep_*.
##   args: x:y spots (default: the surface every 1600 px, then the underground
##   and the caves); `step=N` for another spacing along the surface


func run() -> void:
	shots = true
	shot_prefix = "sweep"
	p.invuln = 99999.0
	p.give_torch()
	var spots: Array = []
	var step := 1600.0
	for a in args:
		if a.begins_with("step="):
			step = float(a.substr(5))
		elif a.contains(":"):
			spots.append(Vector2(float(a.get_slice(":", 0)), float(a.get_slice(":", 1))))
	if spots.is_empty():
		var x := 400.0
		while x < 34200.0:
			spots.append(Vector2(x, 420))
			x += step
		spots.append_array([Vector2(6200, 280), Vector2(7000, 640), Vector2(15020, 900), Vector2(15550, 2100),
			Vector2(15500, 1150), Vector2(36240, 700), Vector2(39500, 600)])
	for at in spots:
		if p.vine != null:
			p._let_go(Vector2.ZERO)
		await put(at)
		p.hp = p.max_hp
		await frames(50)
		for c in level.hud.get_children():
			if c.has_method("dismiss"):
				c.dismiss()
		await shot("%05d_%04d" % [int(at.x), int(at.y)])
		print("shot %s -> him at %s" % [at, p.global_position])
