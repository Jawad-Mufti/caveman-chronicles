extends Node
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
	p.give_torch()
	p.invuln = 11699.0
	level._snuffed = true
	level._panicked = true
	for m in level._mouths:
		m._noticed = true
	level.night.table = [[0.0, 0.3]]
	# the caveman running with the torch, wolves in the hollow
	p.global_position = Vector2(2950, 690)
	p.touch["right"] = true
	await wait(0.3)
	await snap("k_hollow")
	p.touch["right"] = false
	# the great tree: monkeys and Old Bongo
	p.global_position = Vector2(23500, -418)
	await wait(0.6)
	await snap("k_tree")
	# the Toolmaker
	p.global_position = Vector2(30900, 590)
	await wait(0.6)
	await snap("k_tool")
	# a cave: spiders, rats, snake
	level._enter_cave(1)
	await wait(1.0)
	p.global_position = Vector2(37450, 590)
	await wait(0.6)
	await snap("k_cave")
	get_tree().quit()
