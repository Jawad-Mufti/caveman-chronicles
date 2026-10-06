extends Node
## Test harness (not shipped): Old Scar in each of his moves, lit so he can be seen.
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
func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	p.talking = false
func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
		quiet()
func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.give_torch()
	p.invuln = 999.0
	p.hp = 99
	level._snuffed = true
	level._panicked = true
	level._met_toolmaker = true
	for b in level.get_children():
		if b is NightWoods.Brazier:
			b.lit = true
	level.night.table = [[0.0, 0.25]]     # light the clearing for the pictures
	p.global_position = Vector2(32600, 590)
	await frames(30)
	var sc: OldScar = level.scar
	await frames(40)
	await snap("p_emerge")
	await frames(200)
	sc.set_physics_process(false)
	sc.position = Vector2(32900, 600)
	sc.dir = -1
	p.global_position = Vector2(32660, 590)
	var poses := [["prowl", {"vx": -150.0}], ["roar", {"timer": 0.6}], ["pounce", {"vel": Vector2(-500, -80)}], ["crouch", {}]]
	for pose in poses:
		sc.state = pose[0]
		sc.timer = 9.0
		for k in pose[1]:
			sc.set(k, pose[1][k])
		sc.position.y = 520.0 if pose[0] == "pounce" else 600.0
		for i in 12:
			sc.t += 1.0 / 60.0
			sc._phase_walk += absf(sc.vx) / 60.0
			sc._tail_step(1.0 / 60.0)
			sc.queue_redraw()
			await get_tree().process_frame
			quiet()
		await snap("p_" + pose[0])
	get_tree().quit()
