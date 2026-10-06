extends Node
## Test harness (not shipped): the same spots at different camera zooms, to
## choose how much of the world a PC screen should show.
## PNGs to C:/tmp/shots/zoom_<spot>_<zoom>.png. Run with rendering.
var level: Node
var p: CaveMan

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
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

func _run() -> void:
	p = level.player
	await wait(5)
	p.give_torch()
	p.invuln = 99999.0
	var cam := get_viewport().get_camera_2d()
	for spot in [["woods", 2400.0], ["canyon", 21000.0]]:
		level._move_player(Vector2(spot[1], 590 if spot[0] == "woods" else 440), 1)
		for z in [1.0, 0.8, 0.67]:
			cam.zoom = Vector2(z, z)
			await wait(40)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("C:/tmp/shots/zoom_%s_%s.png" % [spot[0], str(z)])
			print("shot ", spot[0], " ", z)
	get_tree().quit()
