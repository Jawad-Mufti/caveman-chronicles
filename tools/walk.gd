extends Node
## Test harness (not shipped): Old Scar's walk and gallop, frame by frame.
var level: Node
var p: CaveMan
func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % n)
func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.give_torch()
	p.invuln = 999.0
	level._snuffed = true
	level._panicked = true
	level._met_toolmaker = true
	for c in level.get_children():
		if c is Dialogue: c.queue_free()
	p.talking = false
	level.night.table = [[0.0, 0.2]]
	p.global_position = Vector2(32500, 590)
	for i in 30: await get_tree().process_frame
	var sc: OldScar = level.scar
	for i in 380:
		await get_tree().process_frame
		if sc.state == "prowl":
			break
	sc.set_physics_process(false)
	sc.position = Vector2(32950, 600)
	sc.dir = 1
	for mode in ["walk", "gallop"]:
		sc.state = "prowl" if mode == "walk" else "charge"
		sc.vx = 170.0 if mode == "walk" else 600.0
		var step := (110.0 if mode == "walk" else 200.0) * OldScar.SIZE / 6.0
		for f in 6:
			sc._phase_walk += step
			sc.t += 0.1
			sc.queue_redraw()
			await get_tree().process_frame
			await snap("%s_%d" % [mode, f])
	get_tree().quit()
