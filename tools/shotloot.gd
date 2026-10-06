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
	p.invuln = 999.0
	level._snuffed = true
	level._panicked = true
	for m in level._mouths:
		m._noticed = true
	# the stash under the great tree, pots and a hare in the valley
	p.global_position = Vector2(23330, 590)
	await wait(0.8)
	await snap("l_valley")
	var stash: Node2D = level.get_children().filter(func(c): return c is Treasure.Breakable and c.kind == "stash")[0]
	stash.take_hit(3, -1)
	stash.take_hit(3, -1)
	await wait(0.35)
	await snap("l_fountain")
	# a totem spitting shells
	p.global_position = Vector2(2380, 590)
	await wait(0.6)
	var totem: Node2D = level.get_children().filter(func(c): return c is Treasure.ShellTotem)[0]
	totem.take_hit(3, 1)
	await wait(0.2)
	await snap("l_totem")
	get_tree().quit()
