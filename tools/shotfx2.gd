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
func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue: c.queue_free()
	p.talking = false
func wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time() / maxf(Engine.time_scale, 0.05)
		quiet()
func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.invuln = 9999.0
	p.give_torch()
	# the camp fire, with embers and heat haze; his torch's embers
	p.global_position = Vector2(620, 590)
	await wait(2.0)
	await snap("fx_camp")
	# a wolf struck: sparks and the silhouette flash
	var w := NightBeasts.Wolf.new()
	w.left_x = 1000.0
	w.right_x = 1010.0
	w.position = Vector2(1005, 600)
	level.add_child(w)
	w.set_physics_process(false)
	p.global_position = Vector2(930, 590)
	p.facing = 1
	await wait(0.4)
	w.set_physics_process(true)
	w.take_hit(3, 1)
	FX.burst(level, w.global_position + Vector2(-10, -34), "sparks", 1.0)
	await get_tree().physics_frame
	await get_tree().process_frame
	await snap("fx_hit")
	get_tree().quit()
