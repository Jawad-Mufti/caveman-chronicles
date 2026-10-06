extends Node
var level: Node
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
	for i in 40: await get_tree().process_frame
	var guide: Guide = level.get_children().filter(func(c): return c is Guide)[0]
	for page in 3:
		guide._page = page
		guide._turn = 0.0
		for i in 12: await get_tree().process_frame
		await snap("guide_%d" % page)
	get_tree().quit()
