extends Node
var level: Node
var p: CaveMan
func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level1/level1.tscn").instantiate()
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
	p.invuln = 9999.0
	for x in [600.0, 2600.0, 5200.0, 7200.0]:
		var space: PhysicsDirectSpaceState2D = (level as Node2D).get_world_2d().direct_space_state
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(x, -1200), Vector2(x, 1400), 1))
		p.global_position = Vector2(x, (hit["position"] as Vector2).y - 10.0)
		await wait(0.8)
		await snap("l1_%d" % int(x))
	get_tree().quit()
