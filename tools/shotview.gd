extends Node
## Test harness (not shipped): the default (PC) view all over both levels, to
## check nothing shows past the edge of the world when the camera pulls back.
## PNGs to C:/tmp/shots/view_*. args: "level1" for Level 1 spots.
var level: Node
var p: CaveMan

func _ready() -> void:
	GameState.reset()
	GameState.seen["level1"] = true
	GameState.seen["level2"] = true
	var l1 := OS.get_cmdline_user_args().has("level1")
	level = load("res://level1/level1.tscn" if l1 else "res://level2/level2.tscn").instantiate()
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

func _run() -> void:
	p = level.player
	await wait(5)
	p.invuln = 99999.0
	var spots := [["start", 300.0, 590.0], ["chamber", 5800.0, 890.0], ["end", 8600.0, 590.0]]
	if not OS.get_cmdline_user_args().has("level1"):
		p.give_torch()
		spots = [["woods", 1300.0, 590.0], ["mountain", 7000.0, -60.0], ["steppe", 13500.0, 590.0], ["tar", 16640.0, 530.0],
			["canyon", 21000.0, 440.0], ["tree", 23400.0, 590.0], ["boulder", 26700.0, 590.0], ["cave_a", 35300.0, 690.0],
			["cave_b", 39800.0, 590.0], ["arena", 32900.0, 590.0], ["far_right", 33500.0, 590.0]]
	for s in spots:
		if level.has_method("_move_player"):
			level._move_player(Vector2(s[1], s[2]), 1)
		else:
			p.global_position = Vector2(s[1], s[2])
		await wait(50)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("C:/tmp/shots/view_%s.png" % s[0])
		print("shot ", s[0], " zoom ", get_viewport().get_camera_2d().zoom.x)
	get_tree().quit()
