extends Node
var level: Node
var p: CaveMan
func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func snap(n: String, at: Vector2) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var sp := (level as Node2D).get_viewport().get_canvas_transform() * at
	img.get_region(Rect2i(int(sp.x) - 130, int(sp.y) - 140, 260, 180)).save_png("/tmp/shots/%s.png" % n)
func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.invuln = 9999.0
	p.give_torch()
	level.night.table = [[0.0, 0.2]]
	p.global_position = Vector2(700, 590)
	for i in 30: await get_tree().process_frame
	for c in level.get_children():
		if c is Dialogue: c.queue_free()
	p.talking = false
	# a wolf stalking, and one crouched to lunge
	var w1 := NightBeasts.Wolf.new()
	w1.left_x = 790.0
	w1.right_x = 800.0
	w1.position = Vector2(795, 600)
	level.add_child(w1)
	w1.set_physics_process(false)
	w1.dir = -1
	w1.state = "stalk"
	var w2 := NightBeasts.Wolf.new()
	w2.left_x = 940.0
	w2.right_x = 950.0
	w2.position = Vector2(945, 600)
	level.add_child(w2)
	w2.set_physics_process(false)
	w2.dir = -1
	w2.state = "crouch"
	var bat := NightBeasts.Bat.new()
	bat.ground_y = 600.0
	bat.position = Vector2(620, 470)
	level.add_child(bat)
	bat.set_physics_process(false)
	for i in 6:
		w1.queue_redraw()
		w2.queue_redraw()
		bat.queue_redraw()
		await get_tree().process_frame
	await snap("b_wolf_stalk", w1.global_position + Vector2(0, -20))
	await snap("b_wolf_crouch", w2.global_position + Vector2(0, -20))
	await snap("b_bat", bat.global_position)
	get_tree().quit()
