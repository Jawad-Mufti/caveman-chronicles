extends Node
## Test harness (not shipped): OLD SCAR in his arena, in the game's own light,
## photographed through the fight's moments (run WITH rendering): the
## entrance, prowling, the tell, the pounce, the roar, cowering at the torch.
## PNGs: C:/tmp/shots/scarfight_<tag>_<moment>.png.   args: tag=<name>
var level: Node
var p: CaveMan
var tag := "now"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()


func _run() -> void:
	for i in 5:
		await get_tree().physics_frame
	p = level.player
	for c in level.get_children():
		if c is Dialogue or c is Shop:
			c.queue_free()
	p.talking = false
	p.give_torch()
	level._snuffed = true
	level._panicked = true
	level._met_toolmaker = true
	p.global_position = Vector2(32600, 590)
	var sc: OldScar = level.scar
	var want := {"emerge": "entrance", "prowl": "prowl", "crouch": "tell", "pounce": "pounce", "roar": "roar", "cower": "cower", "swipe": "swipe"}
	var got := {}
	for f in 60 * 70:
		await get_tree().physics_frame
		if p.hp < 3:
			p.hp = p.max_hp                          # (he must live to see it all)
		var s: String = sc.state
		if want.has(s) and not got.has(s) and sc.timer < 0.9 and sc.visible:
			got[s] = true
			await _shot(want[s])
		if got.size() >= want.size():
			break
	print("scarfight: ", got.keys())
	# the new fight: the log, the clouds, the rage
	var ar: Node = level.scar_arena
	ar.fell_tree()
	for f in 100:
		await get_tree().physics_frame
	await _shot("log")
	ar.clouds_on()
	ar._cloud_t = 7.9
	for f in 30:
		await get_tree().physics_frame
	await _shot("clouds")
	ar._clouds_on = false
	sc.position = Vector2(p.global_position.x + 330.0, sc.floor_y)
	sc.state = "prowl"
	sc.phase = 3
	sc._siege = 4
	sc.hp = 14
	sc.take_hit(1, -1)
	for f in 30:
		await get_tree().physics_frame
	await _shot("rage_roar")
	for f in 70:
		await get_tree().physics_frame
		p.hp = p.max_hp
	await _shot("rage_fire")
	sc.state = "prowl"
	for f in 40:
		await get_tree().physics_frame
		p.hp = p.max_hp
	await _shot("rage_prowl")
	get_tree().quit()


func _shot(label: String) -> void:
	get_tree().paused = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("C:/tmp/shots")
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/scarfight_%s_%s.png" % [tag, label])
	get_tree().paused = false
