extends Node
## Test harness (not shipped): OLD ONE-EYE (level2/one_eye.gd). The first
## meeting (it bursts out, title card, the tutorial pages, two stones knocked
## loose); it can't be hurt; leaving the hollow calms it; the GLARE TRAP recipe
## opens; set the trap and it comes up under it, blinded; hit it while it lies
## there; two stuns beat it; the rewards. One PASS/FAIL line each.
##   shots - screenshots to C:/tmp/shots/one_eye/*
var level: Node
var p: CaveMan
var shots := false
var w: OneEye.Worm

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
			if c is Dialogue:
				p.talking = false
				c.queue_free()
			if c is Critter:
				c.queue_free()

func shot(name: String) -> void:
	if not shots:
		return
	DirAccess.make_dir_recursive_absolute("C:/tmp/shots/one_eye")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/one_eye/%s.png" % name)

func check(name: String, ok: bool, info: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name, info])

func guide() -> Guide:
	for c in level.get_children():
		if c is Guide and not c.is_queued_for_deletion():
			return c
	return null

func wait_state(s: String, max_frames: int) -> bool:
	for i in max_frames:
		if w.state == s:
			return true
		await frames(1)
	return false

func _run() -> void:
	shots = OS.get_cmdline_user_args().has("shots")
	p = level.player
	await frames(5)
	p.pick_up_stick()
	w = level.one_eye
	check("worm waits", w != null and not w.met and w.state == "sleep")
	# 1. into the hollow: it bursts out in front of him
	level._move_player(Vector2(11330, 630), 1)
	await frames(20)
	check("first meeting", w.met and GameState.mystery("one_eye") == "open" and w.state == "breach", "state %s" % w.state)
	await frames(30)
	await shot("breach")
	await frames(90)
	var g := guide()
	check("tutorial page", g != null and g.pages.size() == 2)
	await shot("page")
	await frames(120)
	check("stones knocked loose", Bag.count(p, "quartz") == 1 and Bag.count(p, "pyrite") == 1, "quartz %d fire-gold %d" % [Bag.count(p, "quartz"), Bag.count(p, "pyrite")])
	if g != null:
		g._finish()
	# 2. it hunts him, and a club does nothing
	var hunted := await wait_state("rumble", 240)
	check("it hunts him", hunted and w.fight)
	await wait_state("breach", 120)
	await frames(20)
	var hp0 := w.hp
	w.take_hit(6, 1)
	check("too tough", w.hp == hp0)
	await shot("hunt")
	# 3. out of the hollow: it gives up
	level._move_player(Vector2(11000, 600), -1)
	await frames(150)
	check("it gives up", not w.fight and w.state == "sleep", "state %s fight %s" % [w.state, w.fight])
	# 4. the trap: the recipe is known now; make it
	check("recipe open", Bag.recipe_open("trap") and Bag.known_recipes().size() == Bag.RECIPES.size())
	p.berries = 1
	GameState.bag["clay"] = 1
	check("craft the trap", Bag.craft(p, "trap") and Bag.count(p, "trap") == 1)
	# 5. back in, set it down: up it comes under it, blinded
	level._move_player(Vector2(11420, 630), 1)
	await frames(10)
	p.select_slot(p.hotbar().find("trap"))
	await frames(2)
	p.touch["attack"] = true
	await frames(3)
	p.touch["attack"] = false
	var traps := get_tree().get_nodes_in_group("worm_trap")
	check("trap set", traps.size() == 1)
	level._move_player(Vector2(11300, 630), -1)       # (step back from it)
	var stunned := await wait_state("stunned", 400)
	check("blinded by the trap", stunned and traps.size() > 0 and is_instance_valid(traps[0]) and traps[0].charges == 2, "state %s" % w.state)
	await frames(10)
	await shot("stunned")
	w.take_hit(30, 1)
	check("hurt while blinded", w.hp == 30, "hp %d" % w.hp)
	# 6. the second stun beats it
	stunned = await wait_state("dive", 400)
	stunned = await wait_state("stunned", 600)
	check("blinded again", stunned)
	w.take_hit(30, 1)
	check("beaten", w.state == "dead")
	await frames(330)
	check("rewards", GameState.mystery("one_eye") == "solved" and Bag.count(p, "obsidian") == 2 and GameState.orbs >= 25 and not is_instance_valid(w),
		"obsidian %d orbs %d" % [Bag.count(p, "obsidian"), GameState.orbs])
	print("DONE")
	get_tree().quit()
