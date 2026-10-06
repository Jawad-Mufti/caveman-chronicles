extends Node
## Test harness (not shipped): his death, frame by frame — the slow motion,
## the pop, the topple, flat on his back with X eyes and stars. Screenshots
## (with close-ups) to C:/tmp/shots/death_*.png; checks he wakes again after.
var level: Node
var p: CaveMan

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("C:/tmp/shots/death_%s.png" % name)
	var sp := get_viewport().get_canvas_transform() * p.global_position
	var crop := img.get_region(Rect2i(int(sp.x) - 130, int(sp.y) - 200, 260, 230))
	crop.resize(520, 460, Image.INTERPOLATE_NEAREST)
	crop.save_png("C:/tmp/shots/death_%s_zoom.png" % name)

func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.give_torch()
	level.night.table = [[0.0, 0.0]]
	for c in level.get_children():
		if c is Critter or c is Dialogue:
			c.queue_free()
	level._move_player(Vector2(1150, 590), 1)
	level.set_checkpoint(Vector2(1050, 590))
	for i in 40:
		await get_tree().physics_frame
		p.talking = false
	p.hp = 1
	p.invuln = 0.0
	p.hurt(1, p.global_position.x + 50.0)
	var t0 := Time.get_ticks_msec()
	var shots := [[60, "a"], [250, "b"], [600, "c"], [1100, "d"], [1800, "e"]]
	for s in shots:
		while Time.get_ticks_msec() - t0 < int(s[0]):
			await get_tree().process_frame
		await snap(s[1])
		print("%4d ms: time scale %.2f, dead %s, on floor %s" % [Time.get_ticks_msec() - t0, Engine.time_scale, p.dead, p.is_on_floor()])
	while Time.get_ticks_msec() - t0 < 6000 and p.dead:
		await get_tree().process_frame
	print("woke again: %s, hp %d, at x %.0f" % [not p.dead, p.hp, p.global_position.x])
	get_tree().quit()
