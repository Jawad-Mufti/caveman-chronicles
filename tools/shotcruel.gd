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
	p.invuln = 9999.0
	p.hp = 99
	p.give_torch()
	level._snuffed = true
	level._panicked = true
	level._met_toolmaker = true
	level.night.table = [[0.0, 0.25]]
	# the siege: straight to half health, waves out
	p.global_position = Vector2(32600, 590)
	await wait(6.5)
	var sc: OldScar = level.scar
	sc.hp = 61
	sc.take_hit(3, 1)
	await wait(2.6)
	await snap("siege_wolves")
	for c in level._wave:
		if is_instance_valid(c):
			c.take_hit(99, 1)
	await wait(4.5)
	for c in level._wave:
		if is_instance_valid(c):
			c.take_hit(99, 1)
	await wait(4.5)
	await snap("siege_bats")
	get_tree().quit()
