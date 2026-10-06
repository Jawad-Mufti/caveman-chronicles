extends Node
## Test harness (not shipped): ROCK CLIMBING. Holding toward a steep face of
## the mountain's rock, he scrambles up it and heaves himself over the top.
## A few spots in the caves: walk left, then right, into the walls; he must
## climb (rise well above where he started) and never get stuck below a face.
##   shots - also save screenshots (run with rendering) to C:/tmp/shots/climb/*
var level: Node
var p: CaveMan
var shots := false

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		for c in level.get_children():
			if c is Dialogue:
				c.queue_free()
		p.talking = false
		p.invuln = 1.0
		p.hp = p.max_hp

func shot(name: String) -> void:
	if not shots:
		return
	DirAccess.make_dir_recursive_absolute("C:/tmp/shots/climb")
	level.cam.zoom = Vector2(1.6, 1.6)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/climb/%s.png" % name)

func check(name: String, ok: bool, info: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name, info])

func _run() -> void:
	shots = OS.get_cmdline_user_args().has("shots")
	p = level.player
	await frames(5)
	p.pick_up_stick()
	for c in level.get_children():
		if c is Critter:
			c.free()
	var spots := {"crystal grotto": Vector2(6450, 740), "deep hollow": Vector2(8550, 1060)}
	for name in spots:
		var start: Vector2 = level.mountain.ground_y(spots[name].x, spots[name].y - 60.0) * Vector2(0, 1) + Vector2(spots[name].x, -10)
		level._move_player(start, 1)
		await frames(20)
		var y0 := p.global_position.y
		var top := y0
		var climbed := false
		for side in ["left", "right"]:
			p.touch[side] = true
			p.touch["up"] = true          # on the ground, UP + toward the wall starts a climb
			for i in 240:
				await frames(1)
				top = minf(top, p.global_position.y)
				if p.climbing:
					climbed = true
					if i % 30 == 0:
						await shot("%s_%s" % [name.replace(" ", "_"), side])
			p.touch[side] = false
			p.touch["up"] = false
			await frames(10)
		check("climbs in the %s" % name, climbed and y0 - top > 120.0, "rose %.0f px, climbed %s" % [y0 - top, climbed])
	get_tree().quit()
