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
	img.save_png("/tmp/shots/%s.png" % n)
	if p != null:
		var sp := p.get_global_transform_with_canvas().origin
		var r := Rect2i(int(sp.x) - 110, int(sp.y) - 170, 220, 220).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
		img.get_region(r).save_png("/tmp/shots/%s_him.png" % n)
func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue: c.queue_free()
	p.talking = false
func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.invuln = 9999.0
	p.global_position = Vector2(4000, 590)
	for i in 50:
		await get_tree().process_frame
		quiet()
	await snap("gorge_a")
	p.global_position = Vector2(4700, 510)
	for i in 40:
		await get_tree().process_frame
		quiet()
	await snap("gorge_b")
	# a flip off a vine: freeze a few moments of it
	p.global_position = Vector2(4400, 300)
	p.velocity = Vector2(420, -380)
	p.flip_t = CaveMan.FLIP_TIME
	p.flip_dir = 1.0
	p.set_physics_process(false)
	for k in [0.15, 0.35, 0.55, 0.8]:
		p.flip_t = CaveMan.FLIP_TIME * (1.0 - k)
		p.global_position = Vector2(4400 + k * 180.0, 330 - sin(k * PI) * 60.0)
		p.queue_redraw()
		await get_tree().process_frame
		await snap("flip_%d" % int(k * 100))
	get_tree().quit()
