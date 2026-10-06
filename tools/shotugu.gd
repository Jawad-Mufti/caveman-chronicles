extends Node
## Test harness (not shipped): Ugu in his moves, at play zoom and close up, on
## the open ground by the camp. PNGs to C:/tmp/shots/ugu_*. Run with rendering.
##   args: zoom=<z> (default 1.0), tag=<name>
var level: Node
var p: CaveMan
var zoom := 1.0
var tag := "a"
var start_x := 2700.0

func _process(_delta: float) -> void:
	# runs after the level's camera update: close up, centre on his head
	if p != null and zoom >= 3.0:
		level.cam.limit_bottom = 100000
		level.cam.position_smoothing_enabled = false
		level.cam.global_position = p.global_position + Vector2(0, -60)

func _ready() -> void:
	GameState.reset()
	process_priority = 100
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
		level.cam.zoom = Vector2(zoom, zoom)
		p.invuln = 0.5          # safe, but under the wince (0.8)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/ugu_%s_%s.png" % [tag, name])
	print("shot ", name)

func release() -> void:
	for k in p.touch.keys():
		p.touch[k] = false

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("zoom="):
			zoom = float(a.substr(5))
		if a.begins_with("tag="):
			tag = a.substr(4)
		if a.begins_with("x="):
			start_x = float(a.substr(2))
	p = level.player
	await frames(5)
	p.give_torch()
	p.pick_up_stick()
	p.invuln = 9999.0
	level.hud.visible = false
	level._move_player(Vector2(start_x, 590), 1)
	await frames(40)
	if OS.get_cmdline_user_args().has("sun"):
		GameState.learn("sunfire")
		p.sun_charge = 1.0
		p.start_sunfire()
		while Engine.time_scale < 1.0:
			await get_tree().physics_frame
		await frames(40)
	await shot("idle")
	p.touch["right"] = true
	await frames(30)
	await shot("run")
	p.touch["jump"] = true
	await frames(12)
	await shot("jump")
	p.touch["jump"] = false
	await frames(2)
	p.touch["jump"] = true
	await frames(8)
	await shot("flip")
	await frames(14)
	await shot("spear")
	release()
	await frames(60)
	p.touch["attack"] = true
	await frames(2)
	p.touch["attack"] = false
	await frames(9)
	await shot("swing")
	await frames(40)
	p.touch["throw"] = true
	await frames(5)
	await shot("throw")
	release()
	get_tree().quit()
