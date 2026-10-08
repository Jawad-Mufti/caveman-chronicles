extends Node
## Test harness (not shipped): screenshots of the DIGGING LIGHT (FX.dig_flash),
## in the Dig and in the mountain's rock, a paused frame every 3 through a blow.
## PNGs to C:/tmp/shots/digflash_*. Run with rendering.
var level: Node
var p: CaveMan

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		for c in level.get_children():
			if c is Dialogue or c is ItemGet:
				c.queue_free()
		p.talking = false
		p.invuln = 1.0

func shot(name: String) -> void:
	level.cam.zoom = Vector2(2.4, 2.4)
	level.cam.limit_bottom = 2400        # (the Dig is near the bottom: see under him)
	level.cam.offset = Vector2(0, 150)
	get_tree().paused = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/digflash_%s.png" % name)
	get_tree().paused = false
	print("shot ", name)

## One blow (DOWN + HIT when down), shot every 3 frames.
func blow(tag: String, down: bool) -> void:
	p.touch["down"] = down
	p.touch["attack"] = true
	for i in 24:
		if i == 2:
			p.touch["attack"] = false
		if i % 3 == 0 and i >= 9:
			await shot("%s_%02d" % [tag, i])
		await frames(1)
	p.touch["down"] = false

func _run() -> void:
	p = level.player
	await frames(5)
	p.give_torch()
	var grid: Dig.DigGrid = level._grid
	grid.open_crust(2, 5)
	level._move_player(Vector2(float(level.DIG_GRID[0]) + 4.5 * Dig.TILE, float(level.DIG_GRID[1]) + Dig.TILE), 1)
	await frames(40)
	await blow("dig_a", true)
	await blow("dig_b", true)
	get_tree().quit()
