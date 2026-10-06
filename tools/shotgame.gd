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
	var looks := [["wolf_hood", "axe"], ["ember_paint", "axe"], ["bear_cloak", "club"], ["firekeeper", "hammer"]]
	for i in looks.size():
		p.skin = looks[i][0]
		p.axe = looks[i][1] == "axe"
		p.hammer = looks[i][1] == "hammer"
		p.global_position = Vector2(900, 590)
		p.touch["right"] = true
		await wait(0.35)
		p.touch["right"] = false
		await snap("g_%d" % i)
	get_tree().quit()
