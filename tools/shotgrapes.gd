extends Node
var level: Node
var p: CaveMan
var which := "l2"
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		which = a
	GameState.reset()
	GameState.seen["level2"] = true
	GameState.shells = 42
	GameState.bones = 17
	GameState.figs = 2
	level = load("res://level1/level1.tscn" if which == "l1" else "res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % n)
func wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time()
		for c in level.get_children():
			if c is Dialogue: c.queue_free()
		p.talking = false
func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.invuln = 11699.0
	p.berries = 2
	p.berries_changed.emit(2)
	var bush: Node2D = level.get_children().filter(func(c): return c is World.BerryBush)[0]
	var space: PhysicsDirectSpaceState2D = (level as Node2D).get_world_2d().direct_space_state
	var x := bush.global_position.x - 140.0
	var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(x, -1200), Vector2(x, 1400), 1))
	p.global_position = Vector2(x, (hit["position"] as Vector2).y - 10.0)
	if which == "l2":
		p.give_torch()
		level.night.table = [[0.0, 0.35]]
	await wait(0.8)
	await snap("g_" + which)
	if which == "l2":
		# bones and shells lying on the first ledge and over the first pit
		p.global_position = Vector2(1300, 590)
		await wait(0.6)
		await snap("g_bones")
	get_tree().quit()
