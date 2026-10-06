extends Node
## Test harness (not shipped): pictures of the new end of Level 2.
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
		if c is Dialogue:
			c.queue_free()
	p.talking = false
func wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time()
		quiet()
func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.give_torch()
	p.invuln = 999.0
	level._panicked = true
	# the Long Dark: torch out, fireflies, a vine, the eyes
	p.global_position = Vector2(28980, 560)
	await wait(0.3)
	level._snuffed = true
	p.torch_fuel = 0.0
	p.velocity = Vector2(260, -200)
	await wait(0.35)
	await snap("longdark")
	# the Toolmaker, and his shop, with the fire club and war paint
	GameState.shells = 140
	GameState.gems["level2"] = "found"
	level.gem_found = true
	p.hammer = true
	p.skin = "war_paint"
	p.torch_fuel = 1.0
	level._met_toolmaker = true
	p.global_position = Vector2(30930, 590)
	await wait(1.0)
	await snap("toolmaker")
	await snap("shop")
	for c in level.get_children():
		if c is Shop:
			c.queue_free()
	p.talking = false
	p.global_position = Vector2(30940, 590)
	await wait(0.2)
	await snap("toolmaker2")
	# Old Scar
	p.global_position = Vector2(32600, 590)
	await wait(4.5)
	await snap("scar_intro")
	var sc: OldScar = level.scar
	for i in 600:
		await get_tree().process_frame
		quiet()
		p.facing = 1 if sc.global_position.x > p.global_position.x else -1
		if sc.state == "crouch":
			break
	await snap("scar_crouch")
	for i in 120:
		await get_tree().process_frame
		quiet()
		p.facing = 1 if sc.global_position.x > p.global_position.x else -1
		if sc.state == "cower":
			break
	await wait(0.15)
	await snap("scar_cower")
	level._time = 754.0
	level._secrets = {"crevice": true, "lookout": true, "weeping": true}
	level._show_scroll()
	await wait(1.2)
	await snap("scroll")
	get_tree().quit()
