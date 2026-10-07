extends Node
## Test harness (not shipped): the errands (level2/errands.gd): PIP's goat
## (bone ladder), TAKA's foot (healing salve), OOMA's fire (spark kit). For each:
## the talk opens the slab; a wrong mix hints and costs nothing; the right one
## is spent, 2 s of work, solved, the reward lands. One PASS/FAIL line each.
##   shots - screenshots to C:/tmp/shots/errands/*
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
		p.invuln = 1.0
		for c in level.get_children():
			if c is Critter:
				c.queue_free()

func shot(name: String) -> void:
	if not shots:
		return
	DirAccess.make_dir_recursive_absolute("C:/tmp/shots/errands")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/errands/%s.png" % name)

func check(name: String, ok: bool, info: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name, info])

func dialogue() -> Dialogue:
	for c in level.get_children():
		if c is Dialogue and not c.is_queued_for_deletion():
			return c
	return null

func talk_through() -> void:
	for i in 40:
		var d := dialogue()
		if d == null:
			return
		d._next()
		await frames(2)

## Talk, mix a wrong thing in, then the right recipe: returns false if it stalls.
func errand(e: Node, wrong: String) -> bool:
	level._move_player(e.global_position + Vector2(e.stand_x, -10), 1)
	await frames(30)
	await shot(e.id + "_before")
	e.meet()
	await frames(3)
	await talk_through()
	await frames(5)
	var m := Bag.mixer
	check(e.id + ": slab opens", m != null and p.talking)
	if m == null:
		return false
	m.put(wrong)
	for k in e.recipe:
		for i in int(e.recipe[k]):
			m.put(k)
	var had := GameState.bag.duplicate()
	m.mixed.emit(m.mix.duplicate())
	check(e.id + ": wrong mix hints", Bag.mixer == m and m.note.begins_with(e.who) and GameState.bag == had, m.note)
	m.take(wrong)
	await shot(e.id + "_slab")
	m.mixed.emit(m.mix.duplicate())
	await frames(3)
	check(e.id + ": right mix spent", Bag.mixer == null and e.build_t >= 0.0)
	await frames(60)
	await shot(e.id + "_working")
	await frames(80)
	return true

func _run() -> void:
	shots = OS.get_cmdline_user_args().has("shots")
	p = level.player
	await frames(5)
	p.pick_up_stick()
	var e: Array = level.errands
	check("three errands", e.size() == 3 and e[0].who == "PIP" and e[1].who == "TAKA" and e[2].who == "OOMA")
	# PIP: 4 bones + 1 wood, then up the ladder for the goat
	GameState.bones = 6
	p.wood = 2
	GameState.bag = {"clay": 1, "flint": 1, "pyrite": 1}
	if await errand(e[0], "clay"):
		check("pip: ladder up, bones spent", e[0]._ladder != null and GameState.bones == 2 and p.wood == 1 and GameState.mystery("pip") == "built")
		await talk_through()
		var goat: Vector2 = e[0].global_position + e[0]._goat_at()
		p.global_position = goat + Vector2(-30, -30)
		p.velocity = Vector2.ZERO
		await frames(10)
		check("pip: Baa saved", e[0].rescued, "")
		await frames(60)
		await talk_through()
		await frames(150)
		check("pip: solved, two quartz", GameState.mystery("pip") == "solved" and Bag.count(p, "quartz") == 2, "quartz %d" % Bag.count(p, "quartz"))
		await shot("pip_after")
	# hints: Taka says what is missing; the clay says more each CLANG
	var keep_bag := GameState.bag.duplicate()
	p.berries = 0
	var h1: String = e[1].nag()
	p.berries = 1
	GameState.bag["clay"] = 0
	var h2: String = e[1].nag()
	GameState.bag = keep_bag
	check("taka hints", h1.contains("GRAPE VINES") and h2.contains("mud bank"), "%s / %s" % [h1, h2])
	level._grid.clay_needs_shovel.emit()
	level._grid.clay_needs_shovel.emit()
	check("shovel hints grow", level.hud._msg.text == level.SHOVEL_HINTS[1], level.hud._msg.text)
	# TAKA: 1 clay + 1 berry
	p.berries = 1
	if await errand(e[1], "rocks" if p.rocks > 0 else "flint"):
		await talk_through()
		await frames(150)
		check("taka: healed, three tips", e[1].healed and GameState.mystery("taka") == "solved" and Bag.count(p, "tips") == 3 and p.berries == 0,
			"tips %d" % Bag.count(p, "tips"))
		await shot("taka_after")
	# OOMA: 1 flint + 1 fire-gold
	GameState.figs = 0
	GameState.bag["quartz"] = 2
	if await errand(e[2], "quartz"):
		await talk_through()
		await frames(150)
		check("ooma: lit, figs and obsidian", e[2].lit and e[2].light().z > 0.0 and GameState.figs == 2 and Bag.count(p, "obsidian") == 1,
			"figs %d obsidian %d" % [GameState.figs, Bag.count(p, "obsidian")])
		await shot("ooma_after")
	# again: a short line, no slab
	e[1].meet()
	await frames(3)
	check("after: no slab", Bag.mixer == null and dialogue() == null)
	print("DONE")
	get_tree().quit()
