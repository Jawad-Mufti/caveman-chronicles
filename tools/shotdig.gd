extends Node
## Test harness (not shipped): screenshots of the Dig and the shovel hunt.
## PNGs to C:/tmp/shots/dig_*. Run with rendering.
var level: Node
var p: CaveMan

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	p.talking = false

func wait(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		quiet()
		p.torch_fuel = 1.0

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/dig_%s.png" % name)
	print("shot ", name)

func blow() -> void:
	p.touch["down"] = true
	p.touch["attack"] = true
	await wait(2)
	p.touch["attack"] = false
	await wait(24)
	p.touch["down"] = false

func _run() -> void:
	p = level.player
	await wait(5)
	p.give_torch()
	p.invuln = 99999.0
	# beside the Dig, then on top of it (the underground has no door now: the Dig opens under the graveyard)
	level._move_player(Vector2(float(level.DIG_GRID[0]) - 140.0, 590), 1)
	await wait(40)
	await shot("beside")
	level._move_player(Vector2(float(level.DIG_GRID[0]) + 4.5 * Dig.TILE, float(level.DIG_GRID[1]) - 10.0), 1)
	await wait(40)
	await shot("top")
	for i in 7:
		await blow()
	p.touch["down"] = true
	p.touch["attack"] = true
	await wait(10)
	await shot("digging")
	p.touch["attack"] = false
	p.touch["down"] = false
	# the Sun Stone's hollow
	var stone: Node2D = null
	for c in level.get_children():
		if c is Dig.SunStone:
			stone = c
	level._move_player(stone.global_position + Vector2(-70, -6), 1)
	await wait(40)
	await shot("sunstone")
	# the clay, the dead end, and the root tunnel beside it
	var grid: Dig.DigGrid = null
	for c in level.get_children():
		if c is Dig.DigGrid:
			grid = c
	var row: int = level.DIG_CLAY[0]
	for y in range(row - 4, row):
		for x in 8:
			var cl := Vector2i(x, y)
			if grid.solid(cl):
				grid.cells[grid.idx(cl)] = Dig.AIR
				(grid._shapes[grid.idx(cl)] as Node).queue_free()
				grid._shapes[grid.idx(cl)] = null
	grid.queue_redraw()
	level._move_player(Vector2(float(level.DIG_GRID[0]) + 200.0, float(level.DIG_GRID[1]) + row * Dig.TILE - 2.0), 1)
	await wait(30)
	await blow()
	await wait(4)
	await shot("clay")
	# the windy heights and the bramble
	level._move_player(Vector2(level.BRAMBLE_AT.x - 90.0, level.BRAMBLE_AT.y - 10.0), 1)
	await wait(40)
	await shot("bramble")
	GameState.learn("sunfire")
	p.sun_charge = 1.0
	p.start_sunfire()
	while Engine.time_scale < 1.0:
		await wait(1)
	for c in level.get_children():
		if c is Dig.Bramble:
			c.take_hit(1, 1)
	await wait(40)
	await shot("bramble_burning")
	await wait(80)
	await shot("shovel")
	get_tree().quit()
