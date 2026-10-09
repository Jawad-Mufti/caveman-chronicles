extends Node
## Test harness (not shipped): the Dig and the hunt for the shovel.
##   mega      - a plain stomp only THUDs on the burrow; a MEGA stomp breaks it
##   down      - DOWN + HIT digs down through the earth, block after block
##   ahead     - HIT digs the block in front of him
##   sunstone  - touching the Sun Stone teaches SUNFIRE
##   clay      - packed clay won't give without the shovel; with it, it does
##   bramble   - blows don't burn the bramble; under SUNFIRE they do — and the shovel is in it
##   wind      - the sky gusts blow only up in the sky, not on the ground below
##   ways      - the root tunnel above the clay and the far end of the Hollows: updrafts float him up
##   den       - into the den: trapped; the Gulper; six hits while it is stuck; its teeth; the way out
##   mystery   - the clay opens the shovel mystery; a painting and Moss give the clue; the shovel solves it
## args: any of the above (default all)
var level: Node
var p: CaveMan
var runs := 0
var fails := 0

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		quiet()

func report(label: String, ok: bool, info: String) -> void:
	runs += 1
	if not ok:
		fails += 1
	print("%-46s %s  %s" % [label, "PASS" if ok else "FAIL", info])

func quiet() -> void:
	for c in level.get_children():
		if is_instance_valid(c) and (c is Dialogue or c is ItemGet):
			c.queue_free()
	p.talking = false

func release() -> void:
	for k in ["left", "right", "jump", "attack", "stomp", "down"]:
		p.touch[k] = false

func put(at: Vector2) -> void:
	release()
	while Engine.time_scale < 1.0:
		await get_tree().physics_frame
	level._move_player(at, 1)
	p.velocity = Vector2.ZERO
	p.hp = 5
	p.invuln = 99.0
	await frames(8)

func has(args: Array, n: String) -> bool:
	return args.is_empty() or args.has(n)

func first(cls) -> Node:
	for c in level.get_children():
		if is_instance_of(c, cls):
			return c
	return null

## Jump (twice for a mega) and stomp at the top; wait until he has landed.
func stomp(double: bool) -> void:
	while not p.is_on_floor():
		await frames(1)
	p.touch["jump"] = true
	var jumped2 := not double
	var pressed := false
	for i in 200:
		await frames(1)
		if not jumped2 and p.velocity.y > -150.0:
			p.touch["jump"] = false
			await frames(1)
			p.touch["jump"] = true
			jumped2 = true
			continue
		if jumped2 and not pressed and p.velocity.y > -120.0 and not p.is_on_floor():
			p.touch["stomp"] = true
			pressed = true
			continue
		if pressed:
			p.touch["stomp"] = false
			if p.stomp_state == "" and p.is_on_floor():
				break
	release()

## One blow: DOWN + HIT (or HIT alone), and let the swing play out.
func blow(down: bool) -> void:
	p.touch["down"] = down
	p.touch["attack"] = true
	await frames(2)
	p.touch["attack"] = false
	await frames(26)
	p.touch["down"] = false

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	p = level.player
	await frames(5)
	p.give_torch()
	for m in level._mouths:
		m._noticed = true
	quiet()
	var grid: Dig.DigGrid = level._grid
	var top := Vector2(float(level.DIG_GRID[0]) + 4.5 * Dig.TILE, float(level.DIG_GRID[1]) + Dig.TILE)   # the middle of a block, under the crust

	if has(args, "mega"):
		var b: Underground.Burrow = level._burrow
		b.open = false
		await put(Vector2(b.global_position.x, 590))
		await stomp(false)
		var held := not b.open
		await frames(20)
		await stomp(true)
		report("mega: a plain stomp thuds, a MEGA stomp breaks it", held and b.open, "held %s, opened %s" % [held, b.open])

	if has(args, "down"):
		grid.open_crust(2, 5)
		await put(top)
		var y0 := p.global_position.y
		for i in 14:
			await blow(true)
			if args.has("trace"):
				var f := p.global_position - grid.global_position
				var c := grid.cell_at(f + Vector2(0, 10))
				print("   p (%.0f, %.0f) floor %s cell %s solid %s hits %d dd %s atk %.2f stick %s" % [p.global_position.x, p.global_position.y, p.is_on_floor(), c, grid.solid(c), grid.hits[grid.idx(c)] if grid.inside(c) else -1, p.digging_down, p.attacking, p.has_stick])
		var dug := p.global_position.y - y0
		report("down: DOWN + HIT digs down", dug >= 3.0 * Dig.TILE, "went down %.0f px (%d blocks)" % [dug, int(dug / Dig.TILE)])

	if has(args, "ahead"):
		# stand on the clay-free top rows, dig the block in front
		grid.open_crust(2, 5)
		# one block already dug down (by hand), so there is earth in front at his feet
		var hole := Vector2i(4, 1)
		grid.cells[grid.idx(hole)] = Dig.AIR
		if grid._shapes[grid.idx(hole)] != null:
			(grid._shapes[grid.idx(hole)] as Node).queue_free()
			grid._shapes[grid.idx(hole)] = null
		await put(top + Vector2(0, Dig.TILE - 2.0))
		p.facing = 1
		var feet := p.global_position - grid.global_position
		var front := grid.cell_at(feet + Vector2(30, -14))
		var was := grid.solid(front)
		for i in 4:
			if not grid.solid(front):
				break
			await blow(false)
		report("ahead: HIT digs the block in front", was and not grid.solid(front), "block %s was solid %s, now %s" % [front, was, grid.solid(front)])

	if has(args, "sunstone"):
		var s: Dig.SunStone = first(Dig.SunStone)
		await put(s.global_position + Vector2(-60, -6))
		p.touch["right"] = true
		for i in 60:
			await frames(1)
			if GameState.abilities.has("sunfire"):
				break
		release()
		report("sunstone: touching it teaches SUNFIRE", GameState.abilities.has("sunfire") and s.spent, "")

	if has(args, "clay"):
		var gx2: float = level.DIG_GRID[0]
		var gy2: float = level.DIG_GRID[1]
		var row: int = level.DIG_CLAY[0]
		# clear a spot down to the clay, by hand, and stand on it
		for y in row:
			for x in 3:
				var c := Vector2i(2 + x, y)
				if grid.solid(c):
					grid.cells[grid.idx(c)] = Dig.AIR
					if grid._shapes[grid.idx(c)] != null:
						(grid._shapes[grid.idx(c)] as Node).queue_free()
						grid._shapes[grid.idx(c)] = null
		await put(Vector2(gx2 + 3.5 * Dig.TILE, gy2 + row * Dig.TILE - 2.0))
		var target := Vector2i(3, row)
		for i in 3:
			await blow(true)
		var held := grid.solid(target)
		GameState.give_item("shovel")
		await put(Vector2(gx2 + 3.5 * Dig.TILE, gy2 + row * Dig.TILE - 2.0))     # (back over the clay: the clangs can nudge him a block over)
		for i in 4:
			if not grid.solid(target):
				break
			await blow(true)
		report("clay: needs the shovel, then gives", held and not grid.solid(target), "held without %s, cut with %s" % [held, not grid.solid(target)])
		GameState.items.erase("shovel")

	if has(args, "bramble"):
		var br: Dig.Bramble = first(Dig.Bramble)
		await put(level.BRAMBLE_AT + Vector2(-70, -10))
		p.facing = 1
		br.take_hit(1, 1)
		await frames(100)
		var stood := is_instance_valid(br) and not br.gone
		GameState.learn("sunfire")
		p.sun_charge = 1.0
		p.start_sunfire()
		while Engine.time_scale < 1.0:
			await get_tree().physics_frame
		br.take_hit(1, 1)
		await frames(110)
		var burnt := not is_instance_valid(br)
		var shovel: Node = first(Dig.ShovelPickup)
		var got := false
		if shovel != null:
			p.global_position = (shovel as Node2D).global_position + Vector2(0, -10)
			await frames(10)
			got = GameState.has_item("shovel")
		p.end_sunfire()
		report("bramble: only SUNFIRE burns it; the shovel inside", stood and burnt and got, "stood %s, burnt %s, shovel %s" % [stood, burnt, got])

	if has(args, "wind"):
		var w: Array = level.WINDY_WIND
		var gust := 0.0
		var below := 0.0
		await put(Vector2(level.WINDY_ROCKS[1][0] + 40.0, level.WINDY_ROCKS[1][1] - 10.0))
		for i in 420:
			await frames(1)
			gust = minf(gust, p.wind)
		await put(Vector2(float(w[0]) + 100.0, 590))
		for i in 420:
			await frames(1)
			below = minf(below, p.wind)
		report("wind: gusts up in the sky only", gust < -100.0 and below == 0.0, "up there %.0f, below %.0f" % [gust, below])

	if has(args, "ways"):
		# the root tunnel above the clay leads west into the updraft; it floats him up to the ground
		var gx3: float = level.DIG_GRID[0]
		var gy3: float = level.DIG_GRID[1]
		var row2: int = level.DIG_CLAY[0]
		# (as if he had dug his way there: the blocks by the tunnel are open)
		for y in range(row2 - 3, row2):
			for x in 2:
				var c := Vector2i(x, y)
				if grid.solid(c):
					grid.cells[grid.idx(c)] = Dig.AIR
					(grid._shapes[grid.idx(c)] as Node).queue_free()
					grid._shapes[grid.idx(c)] = null
		await put(Vector2(gx3 + 30.0, gy3 + row2 * Dig.TILE - 2.0))
		p.touch["left"] = true
		var up1 := false
		for i in 360:
			await frames(1)
			if p.global_position.y < 590.0:
				up1 = true
				break
		release()
		for i in 150:
			await frames(1)
			if p.is_on_floor():
				break
		var on_top: bool = up1 and p.is_on_floor() and p.global_position.y < 610.0
		# the far end of the Hollows: the second updraft, up to the creek
		var u2: Array = level.UPDRAFTS[1]
		await put(Vector2((float(u2[0]) + float(u2[1])) * 0.5, float(u2[3]) - 10.0))
		var up2 := false
		for i in 360:
			await frames(1)
			if p.global_position.y < 590.0:
				up2 = true
				break
		await frames(40)
		report("ways: the updrafts float him back up to the ground", on_top and up2, "from the shaft %s (landed %s), from the far end %s" % [up1, on_top, up2])

	if has(args, "den"):
		# into the den: the rocks shut behind him, the Gulper wakes; six hits while it's stuck
		var g: Dig.Gulper = level._gulper
		var den: Rect2 = level.DEN
		await put(Vector2(den.position.x + 120.0, den.end.y - 4.0))
		await frames(10)
		var trapped: bool = level._seal.shut and g.state != "sleep"
		var bit := false
		var hp0 := p.hp
		p.invuln = 0.0
		for i in 1800:
			await frames(1)
			if p.hp < hp0:
				bit = true
			p.hp = maxi(p.hp, 2)
			hp0 = p.hp
			if g.state == "stuck" and g._flinch <= 0.0:
				# run to its head and whack it
				var hx := g._head.x
				p.invuln = 99.0
				p.touch["right"] = p.global_position.x < hx - 50.0
				p.touch["left"] = p.global_position.x > hx + 50.0
				p.facing = 1 if hx > p.global_position.x else -1
				p.touch["attack"] = absf(p.global_position.x - hx) < 70.0 and i % 8 < 3
			else:
				release()
				p.invuln = 0.0
			if g.state == "dead":
				break
		release()
		p.invuln = 99.0
		var beaten := g.state == "dead"
		await frames(150)
		var teeth: Node = first(Dig.TeethPickup)
		var got := false
		print("   teeth %s at %s, p %s" % [teeth != null, (teeth as Node2D).global_position if teeth != null else Vector2.ZERO, p.global_position])
		if teeth != null:
			p.global_position = (teeth as Node2D).global_position + Vector2(0, -6)
			await frames(10)
		got = GameState.has_item("gulper_teeth")
		var free: bool = not level._seal.shut
		report("den: trapped, bitten, six hits, the teeth, the way out", trapped and bit and got and free,
			"trapped %s, bitten %s, beaten %s, teeth %s, open %s" % [trapped, bit, beaten, got, free])

	if has(args, "mystery"):
		GameState.mysteries = {}
		GameState.items.erase("shovel")
		# the clay says no: the mystery opens
		grid.clay_needs_shovel.emit()
		var opened := GameState.mystery("shovel") == "open"
		# the painting on the wall by the clay
		var painted := false
		for c in level.get_children():
			if c is Dig.Painting and absf((c as Node2D).global_position.y - (float(level.DIG_GRID[1]) + level.DIG_CLAY[0] * Dig.TILE)) < 200.0:
				painted = true
		# Moss, woken up, tells where it went
		level._moss_clue = false
		level._meet_moss()
		await get_tree().process_frame
		var told: bool = level._moss_clue and level.get_children().filter(func(c): return c is Dialogue).size() > 0
		quiet()
		# the camp shows it
		level.open_menu()
		await get_tree().process_frame
		var m: CampMenu = get_tree().get_first_node_in_group("camp_menu")
		var menu_ok := m != null
		if m != null:
			m._close()
		await get_tree().process_frame
		# the shovel solves it
		level._got_shovel()
		quiet()
		var solved := GameState.mystery("shovel") == "solved"
		report("mystery: clay, painting, Moss's clue, solved", opened and painted and told and menu_ok and solved,
			"opened %s, painting %s, Moss told %s, menu %s, solved %s" % [opened, painted, told, menu_ok, solved])

	print("%d scenarios, %d failed" % [runs, fails])
	get_tree().quit()
