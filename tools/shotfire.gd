extends Node
## Test harness (not shipped): bonfire, burst and darkness after the changes.
var level: Node
func _ready() -> void:
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % n)
func _run() -> void:
	await get_tree().create_timer(0.3).timeout
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	var p: CaveMan = level.player
	p.talking = false
	p.give_torch()
	p.invuln = 99.0
	p.global_position = Vector2(560, 590)
	await get_tree().create_timer(1.0).timeout
	await snap("camp")
	p.global_position = Vector2(2250, 590)
	await get_tree().create_timer(1.0).timeout
	p.wood = 2
	p.touch["fire"] = true
	await get_tree().process_frame
	p.touch["fire"] = false
	await get_tree().create_timer(0.72).timeout
	await snap("burst")
	get_tree().quit()
