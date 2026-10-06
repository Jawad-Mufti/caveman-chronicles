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
	var img := get_viewport().get_texture().get_image()
	var sp := p.get_global_transform_with_canvas().origin
	img.get_region(Rect2i(int(sp.x) - 120, int(sp.y) - 150, 240, 190)).save_png("/tmp/shots/%s.png" % n)
func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.invuln = 9999.0
	level.night.table = [[0.0, 0.05]]
	for c in level.get_children():
		if c is Dialogue: c.queue_free()
	p.talking = false
	p.global_position = Vector2(4300, 300)
	for i in 10: await get_tree().process_frame
	p.set_physics_process(false)
	for kind in ["front", "double", "back"]:
		p.flip_turns = 2.0 if kind == "double" else 1.0
		p.flip_back = kind == "back"
		p.flip_dir = 1.0
		p.facing = -1 if kind == "back" else 1
		p.flip_len = CaveMan.FLIP_TIME * (1.35 if kind == "double" else 1.0)
		p.velocity = Vector2(400, -200)
		p._ghosts.clear()
		var x0 := 4300.0
		for f in 5:
			var k: float = [0.1, 0.3, 0.5, 0.7, 0.9][f]
			p.flip_t = p.flip_len * (1.0 - k)
			p.global_position = Vector2(x0 + k * 220.0, 150.0 - sin(k * PI) * 70.0)
			p._ghosts.clear()
			for g in 5:
				var kg := maxf(k - (g + 1) * 0.06, 0.0)
				p._ghosts.append([Vector2(x0 + kg * 220.0, 150.0 - sin(kg * PI) * 70.0) + Vector2(0, -38), 0.22 - g * 0.04])
			p.queue_redraw()
			await get_tree().process_frame
			await snap("f_%s_%d" % [kind, f])
	get_tree().quit()
