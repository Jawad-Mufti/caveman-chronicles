extends Node
## Test harness (not shipped): screenshots of the shovel mystery's clues —
## the painting by the clay, Moss's clue, the Mysteries note in the camp,
## the glint in the bramble. PNGs to C:/tmp/shots/clue_*. Run with rendering.
var level: Node
var p: CaveMan

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func wait(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		p.torch_fuel = 1.0

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/clue_%s.png" % name)
	print("shot ", name)

func _run() -> void:
	p = level.player
	await wait(5)
	p.give_torch()
	p.invuln = 99999.0
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	p.talking = false
	# the dead end: clear down to the clay, stand on it, look at the wall
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
	level._move_player(Vector2(float(level.DIG_GRID[0]) + 260.0, float(level.DIG_GRID[1]) + row * Dig.TILE - 2.0), 1)
	await wait(40)
	grid.clay_needs_shovel.emit()
	await wait(10)
	await shot("painting")
	# Moss, with the clue
	level._move_player(Vector2(level.moss.global_position.x - 80.0, 590), 1)
	await wait(30)
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	p.talking = false
	level._meet_moss()
	await wait(4)
	var d: Dialogue = null
	for c in level.get_children():
		if c is Dialogue:
			d = c
	if d != null:
		d._next()
		await wait(20)
	await shot("moss")
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	p.talking = false
	# the camp: the Mysteries note
	level.open_menu()
	for i in 30:
		await get_tree().process_frame
	await shot("menu")
	var m: CampMenu = get_tree().get_first_node_in_group("camp_menu")
	m._close()
	await get_tree().process_frame
	# the bramble, a glint inside
	level._move_player(Vector2(level.BRAMBLE_AT.x - 100.0, level.BRAMBLE_AT.y - 10.0), 1)
	for i in 160:
		await wait(1)
		var spark := 0.0
		for c in level.get_children():
			if c is Dig.Bramble:
				spark = fmod(c._t * 0.9, 2.2)
		if spark > 0.15 and spark < 0.3:
			break
	await shot("bramble")
	get_tree().quit()
