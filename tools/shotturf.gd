extends Node
## Test harness (not shipped): screenshots of the living turf (level2/turf.gd).
## PNGs to C:/tmp/shots/turf_*. Run with rendering (not headless).
## args: "nodark" for a version without the night
var level: Node
var p: CaveMan
var cam: Camera2D

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	GameState.learn("sunfire")
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue or c is ItemGet:
			c.queue_free()
	p.talking = false

func wait(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		quiet()
		p.torch_fuel = 1.0

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var tag := "_nodark" if OS.get_cmdline_user_args().has("nodark") else ""
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/turf_%s%s.png" % [name, tag])
	print("shot ", name)

func ground_at(x: float) -> Turf.Ground:
	for c in level.get_children():
		if c is Turf.Ground and x >= c.rect.position.x and x <= c.rect.end.x:
			return c
	return null

func _run() -> void:
	p = level.player
	await wait(5)
	p.give_torch()
	p.invuln = 99999.0
	for c in level.get_children():
		if c is Critter and not c is OldScar:
			c.queue_free()
	if OS.get_cmdline_user_args().has("nodark"):
		level.night.table = [[0.0, 0.0]]
	cam = get_viewport().get_camera_2d()
	cam.zoom = Vector2.ONE if OS.get_cmdline_user_args().has("game") else Vector2(1.6, 1.6)
	cam.offset = Vector2.ZERO if OS.get_cmdline_user_args().has("game") else Vector2(0, 230)
	if not OS.get_cmdline_user_args().has("game"):
		cam.limit_bottom = 100000
	cam.position_smoothing_enabled = false
	# standing in the grass
	level._move_player(Vector2(24600, 590), 1)
	await wait(40)
	await shot("stand")
	# running through it
	p.touch["right"] = true
	await wait(22)
	await shot("run")
	p.touch["right"] = false
	await wait(30)
	# a big landing: the ripple
	p.touch["jump"] = true
	await wait(3)
	p.touch["jump"] = false
	var landed := false
	var left_ground := false
	for i in 160:
		await wait(1)
		left_ground = left_ground or not p.is_on_floor()
		if left_ground and p.is_on_floor():
			landed = true
			break
	await wait(4)
	await shot("land")
	# a glowing mushroom: walk onto it
	var g := ground_at(24600.0)
	var shroom_x := -1.0
	for f in g.front._flora:
		if f[1] == "shroom" and float(f[0]) > 300.0:
			shroom_x = g.rect.position.x + float(f[0])
			break
	if shroom_x > 0.0:
		level._move_player(Vector2(shroom_x - 70.0, 590), 1)
		await wait(20)
		p.touch["right"] = true
		for i in 60:
			await wait(1)
			if p.global_position.x > shroom_x + 2.0:
				break
		p.touch["right"] = false
		await wait(10)
		await shot("spores")
	# flowers open as he passes
	await wait(30)
	await shot("bloom")
	# the cliff at the edge of a stretch of ground, with roots dangling
	cam.zoom = Vector2(1.4, 1.4)
	level._move_player(Vector2(24460, 590), -1)
	await wait(30)
	await shot("cliff")
	# SUNFIRE through the grass: embers kicked up
	p.sun_charge = 1.0
	p.start_sunfire()
	while Engine.time_scale < 1.0:
		await wait(1)
	cam.zoom = Vector2.ONE if OS.get_cmdline_user_args().has("game") else Vector2(1.6, 1.6)
	p.touch["right"] = true
	await wait(18)
	await shot("sunfire")
	p.touch["right"] = false
	get_tree().quit()
