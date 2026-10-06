extends Node
## Test harness (not shipped): Ugu's moves up close — the club combo (BONK,
## uppercut, finisher), the dig, swinging on a vine, clinging to a chimney wall.
## PNGs to C:/tmp/shots/moves_*. Run with rendering.
var level: Node
var p: CaveMan
var zoom := 2.6

func _ready() -> void:
	process_priority = 100
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func _process(_delta: float) -> void:
	# after the level's camera update: close up on him
	if p != null:
		level.cam.zoom = Vector2(zoom, zoom)
		level.cam.limit_bottom = 100000
		level.cam.limit_top = -100000
		level.cam.position_smoothing_enabled = false
		level.cam.global_position = p.global_position + Vector2(0, -70)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		for c in level.get_children():
			if c is Dialogue:
				c.queue_free()
		p.talking = false
		p.invuln = 0.5          # safe, but under the wince (0.8)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/moves_%s.png" % name)
	print("shot ", name)

func release() -> void:
	for k in p.touch.keys():
		p.touch[k] = false

func tap(key: String) -> void:
	p.touch[key] = true
	await frames(2)
	p.touch[key] = false

func _run() -> void:
	p = level.player
	await frames(5)
	p.give_torch()
	p.pick_up_stick()
	level.hud.visible = false
	# the combo, by a wolf
	var wolf: Node2D = null
	for c in level.get_children():
		if c.get_class() == "Area2D" and c.has_method("take_hit") and c is Critter:
			wolf = c
			break
	level._move_player(Vector2(2300, 590), 1)
	await frames(30)
	var kinds := []
	for i in 3:
		await tap("attack")
		var sw: Array = CaveMan.SWINGS[p._swing_kind]
		kinds.append(p._swing_kind)
		await frames(int(float(sw[0]) * 60.0 * 0.62))
		await shot("combo%d" % i)
		while p.attack_cd > 0.0:
			await frames(1)
	print("combo kinds: ", kinds)
	# the dig
	var grid: Dig.DigGrid = level._grid
	grid.open_crust(2, 5)
	level._move_player(Vector2(float(level.DIG_GRID[0]) + 4.5 * Dig.TILE, float(level.DIG_GRID[1]) + Dig.TILE - 2.0), 1)
	await frames(20)
	p.touch["down"] = true
	await tap("attack")
	await frames(6)
	await shot("dig_lift")
	await frames(10)
	await shot("dig_hit")
	release()
	await frames(30)
	# a vine, swinging
	var vine: Node2D = null
	for c in level.get_children():
		if c is NightWoods.Vine:
			vine = c
			break
	level._move_player(vine.global_position + Vector2(0, vine.length + CaveMan.HANG), 1)
	await frames(1)
	p.velocity = Vector2(500, 0)
	p.grab_vine(vine)
	await frames(12)
	await shot("vine")
	await frames(30)
	await shot("vine2")
	p._let_go(Vector2.ZERO)
	await frames(20)
	# a chimney wall: hold into it, falling
	var wall: Node2D = null
	for c in get_tree().get_nodes_in_group("kick_wall"):
		wall = c
		break
	level._move_player(wall.global_position + Vector2(-20, 180), 1)
	p.touch["right"] = true
	for i in 60:
		await frames(1)
		if p.wall_cling:
			break
	await frames(6)
	await shot("cling")
	release()
	get_tree().quit()
