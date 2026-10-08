extends "res://tools/harness.gd"
## Screenshots of the DIGGING LIGHT (FX.dig_flash) in the Dig: a paused frame
## every 3 through two blows (DOWN + HIT). Run with rendering; PNGs to
## C:/tmp/shots/digflash_*.


func run() -> void:
	shots = true
	shot_prefix = "digflash"
	p.invuln = 99999.0
	p.give_torch()
	var grid: Dig.DigGrid = level._grid
	grid.open_crust(2, 5)
	await put(Vector2(float(level.DIG_GRID[0]) + 4.5 * Dig.TILE, float(level.DIG_GRID[1]) + Dig.TILE))
	await frames(34)
	level.cam.zoom = Vector2(2.4, 2.4)
	await blow("dig_a")
	await blow("dig_b")


## One blow, shot every 3 frames once it lands.
func blow(tag: String) -> void:
	p.touch["down"] = true
	p.touch["attack"] = true
	for i in 24:
		if i == 2:
			p.touch["attack"] = false
		if i % 3 == 0 and i >= 9:
			await shot("%s_%02d" % [tag, i])
		await frames(1)
	p.touch["down"] = false
