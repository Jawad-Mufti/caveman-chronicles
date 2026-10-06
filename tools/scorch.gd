extends Node
var level: Node
var p: CaveMan
var shots := false
func _ready() -> void:
	shots = OS.get_cmdline_user_args().has("shots")
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func snap(n: String) -> void:
	if not shots:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var sp := p.get_global_transform_with_canvas().origin
	img.get_region(Rect2i(int(sp.x) - 150, int(sp.y) - 170, 300, 210)).save_png("/tmp/shots/%s.png" % n)
func _run() -> void:
	await get_tree().physics_frame
	p = level.player
	for i in 5: await get_tree().physics_frame
	for c in level.get_children():
		if c is Dialogue: c.queue_free()
	p.talking = false
	var fire: Node2D = level.get_children().filter(func(c): return c is NightWoods.Bonfire and not (c is NightWoods.Brazier))[0]
	p.global_position = fire.global_position + Vector2(0, -10)
	var smoked_at := -1.0
	var t := 0.0
	var x_at := 0.0
	while t < 3.6:
		await get_tree().physics_frame
		p.talking = false
		t += 1.0 / 60.0
		if smoked_at < 0.0 and level.get_children().any(func(c): return c is CPUParticles2D and c.color_ramp != null and c.color_ramp.colors[0].r < 0.35):
			smoked_at = t
		if p.scorch_t > 0.0 and x_at == 0.0:
			x_at = p.global_position.x
			for i in 6: await get_tree().process_frame
			await snap("scorch")
	var x0 := p.global_position.x
	for i in 50: await get_tree().physics_frame
	print("smoke first at %.1f s; scorched %s; ran %d px in 0.8 s; sooty face %s; hearts %d" % [smoked_at, x_at != 0.0, absf(p.global_position.x - x0), p.soot_t > 0.0, p.hp])
	if shots:
		for i in 20: await get_tree().process_frame
		await snap("soot")
		# a trotting wolf, a few frames apart
		var w := NightBeasts.Wolf.new()
		w.left_x = 300.0
		w.right_x = 2000.0
		w.position = Vector2(p.global_position.x + 250.0, 600)
		level.add_child(w)
		p.give_torch()
		for f in 3:
			for i in 7: await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var sp := w.get_global_transform_with_canvas().origin
			img.get_region(Rect2i(int(sp.x) - 70, int(sp.y) - 70, 140, 80)).save_png("/tmp/shots/trot_%d.png" % f)
	get_tree().quit()
