extends Node
## Test harness (not shipped): THE HOTBAR. The slots are what he has; the
## number keys pick one; HIT uses it: rocks thrown, figs eaten, the shovel
## digs where he aims (down, and down-across at 45 degrees), weapons swap.
## One PASS/FAIL line each.   shots - screenshots to C:/tmp/shots/hotbar/*
var level: Node
var p: CaveMan
var shots := false

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		for c in level.get_children():
			if c is Dialogue:
				c.queue_free()
		p.talking = false
		p.invuln = 1.0

func shot(name: String) -> void:
	if not shots:
		return
	DirAccess.make_dir_recursive_absolute("C:/tmp/shots/hotbar")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/hotbar/%s.png" % name)

func check(name: String, ok: bool, info: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name, info])

func release() -> void:
	for k in p.touch.keys():
		p.touch[k] = false

func key(code: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await frames(2)
	var u := InputEventKey.new()
	u.physical_keycode = code
	u.pressed = false
	Input.parse_input_event(u)
	await frames(2)

func hit() -> void:
	p.touch["attack"] = true
	await frames(3)
	p.touch["attack"] = false
	await frames(20)

func solid_at(world: Vector2) -> bool:
	var t: Terrain = level.mountain
	var l := (world - t.position) / Terrain.CELL
	return t._is_solid_code(t._code(floori(l.x), floori(l.y)))

func _run() -> void:
	shots = OS.get_cmdline_user_args().has("shots")
	p = level.player
	await frames(5)
	p.pick_up_stick()
	for c in level.get_children():
		if c is Critter:
			c.free()
	level._move_player(Vector2(1100, 590), 1)
	await frames(10)
	# 1. the slots are what he has
	var plain := p.hotbar()
	GameState.weapons.append("axe")
	GameState.give_item("shovel")
	var full := p.hotbar()
	check("slots", plain == ["club", "rocks", "figs"] and full == ["club", "axe", "shovel", "rocks", "figs"], "%s -> %s" % [plain, full])
	await frames(5)
	await shot("bar")
	# 2. the number keys pick, and a weapon slot swaps the weapon
	await key(KEY_2)
	var picked_axe := p.hotbar_selected() == "axe" and p.axe
	await key(KEY_1)
	check("number keys pick (axe, then club)", picked_axe and p.hotbar_selected() == "club" and not p.axe, "axe %s" % picked_axe)
	# 3. rocks: HIT throws one
	p.rocks = 3
	await key(KEY_4)
	await hit()
	var thrown := false
	for c in level.get_children():
		if c is World.ThrownRock:
			thrown = true
	check("rocks: HIT throws", p.hotbar_selected() == "rocks" and p.rocks == 2 and thrown, "rocks left %d" % p.rocks)
	# 4. figs: HIT eats one
	GameState.figs = 2
	p.hp = 2
	await key(KEY_5)
	await hit()
	check("figs: HIT eats", GameState.figs == 1 and p.hp > 2, "figs %d, hp %d" % [GameState.figs, p.hp])
	# 5. the shovel digs where he aims: down, then up and across at 45 degrees
	await key(KEY_3)
	level._move_player(Vector2(6800, -50), 1)
	await frames(20)
	var y0 := p.global_position.y
	p.touch["down"] = true
	for i in 6:
		await hit()
		p.touch["down"] = true
	release()
	await frames(20)
	var went := p.global_position.y - y0
	p.facing = 1
	# into solid rock, down and across at 45 degrees: the rock down-right of him shrinks
	var here := p.global_position
	var count_rock := func() -> int:
		var k := 0
		for dx in range(20, 140, 20):
			for dy in range(-20, 100, 20):
				if solid_at(here + Vector2(dx, dy)):
					k += 1
		return k
	var before: int = count_rock.call()
	for i in 6:
		p.touch["down"] = true
		p.touch["right"] = true
		await frames(1)
		p.touch["right"] = false
		p.touch["attack"] = true
		await frames(3)
		p.touch["attack"] = false
		await frames(20)
	release()
	await shot("shovel")
	check("shovel digs down", p.hotbar_selected() == "shovel" and went > 60.0, "went down %.0f px" % went)
	var after: int = count_rock.call()
	check("shovel digs down-across at 45 degrees", after < before, "rock cells down-right: %d -> %d" % [before, after])
	get_tree().quit()
