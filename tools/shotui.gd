extends Node
## Test harness (not shipped): dialogue box, the lair entrance, high shells.
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
func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.give_torch()
	p.invuln = 999.0
	# the opening narration, with the new small box
	await wait(1.2)
	await snap("ui_dialogue")
	for c in level.get_children():
		if c is Dialogue: c.queue_free()
	p.talking = false
	# high shells above the path before the first wolves
	p.global_position = Vector2(1000, 590)
	await wait(0.8)
	await snap("ui_high")
	# the entrance: his eyes in the lair, then out into the light
	level._snuffed = true
	level._panicked = true
	level._met_toolmaker = true
	p.global_position = Vector2(32540, 590)
	await wait(1.2)
	await snap("ui_lair")
	await wait(4.2)
	await snap("ui_entrance")
	get_tree().quit()
