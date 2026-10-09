extends Node
## Test harness (not shipped): screenshots of the exploring update — the new
## sky lanes and their creatures, the burrow, the Root Hollows, a rare find,
## and the Shelter page. PNGs to C:/tmp/shots/explore_*. Run with rendering.
var level: Node
var p: CaveMan

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue or c is ItemGet:
			c.queue_free()
	p.talking = false

func wait(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		quiet()
		p.torch_fuel = 1.0

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/explore_%s.png" % name)
	print("shot ", name)

func at(name: String, pos: Vector2, frames := 45) -> void:
	level._move_player(pos, 1)
	await wait(frames)
	await shot(name)

func _run() -> void:
	p = level.player
	await wait(5)
	p.give_torch()
	p.invuln = 99999.0
	for c in level.get_children():
		if c is Critter and not c is OldScar:
			c.set_physics_process(false)
	var lanes: Array = level.SKY_LANES_2
	await at("moon_garden", Vector2(2420, -250))
	await at("moon_garden_top", Vector2(2860, -410))
	await at("ray", Vector2(3300, -340))
	await at("firefly_bridge", Vector2(16460, 0))
	await at("feather_peaks", Vector2(24570, -610))
	await at("dig_mouth", Vector2(float(level.DIG_GRID[0]) - 120.0, 590))     # (the underground has no door now: the Dig opens under the graveyard)
	await at("hollows_in", Vector2(41860, 690))
	await at("hollows_worms", Vector2(43000, 770))
	await at("hollows_angler", Vector2(43500, 730))
	# the angler, mid-snap
	var a: Underground.Angler = null
	for c in level.get_children():
		if c is Underground.Angler:
			a = c
	level._move_player(a.global_position + a.lure_at() + Vector2(-40, 50), 1)
	for i in 120:
		await wait(1)
		if a.state == "snap" and a._st > 0.1:
			break
	await shot("angler_snap")
	await at("hollows_snail", Vector2(44120, 690))
	# a rare find: pick one up and catch the moment
	var r: Array = level.DEEP_RELICS[1]
	level._move_player(Vector2(r[0] - 80.0, 730), 1)
	await wait(30)
	p.global_position = Vector2(r[0], r[1] + 30.0)
	await wait(18)
	await shot("relic_moment")
	# (the shelter is its own scene now: tools/homeflow -- shots, shelter/home.tscn -- shot)
	get_tree().quit()

