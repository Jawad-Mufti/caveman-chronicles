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
func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.invuln = 9999.0
	p.hp = 99
	p.give_torch()
	p.global_position = Vector2(26550, 590)
	for i in 20:
		await get_tree().process_frame
		quiet()
	await snap("run_ledge")
	# the chase
	p.touch["right"] = true
	for i in 75:
		await get_tree().physics_frame
		quiet()
	await snap("run_chase")
	p.touch["right"] = false
	# Old Scar taking a hit
	level._snuffed = true
	level._panicked = true
	level._met_toolmaker = true
	level.night.table = [[0.0, 0.25]]
	p.global_position = Vector2(32600, 590)
	for i in 420:
		await get_tree().process_frame
		quiet()
	var sc: OldScar = level.scar
	sc.state = "cower"
	sc.timer = 5.0
	sc.position = Vector2(32820, 600)
	p.global_position = Vector2(32720, 590)
	p.facing = 1
	sc.take_hit(3, 1)
	for i in 5: await get_tree().process_frame
	await snap("scar_hit")
	get_tree().quit()
