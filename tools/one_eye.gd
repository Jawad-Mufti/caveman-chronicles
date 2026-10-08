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
var vuln := false

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		if not vuln:
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
	level._move_player(Vector2(15470, 2100), 1)
	await frames(20)
	check("first meeting", w.met and GameState.mystery("one_eye") == "open" and w.state == "move", "state %s" % w.state)
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
	var hunted := await wait_state("tell", 300)
	check("it hunts him", hunted and w.fight)
	await wait_state("move", 200)
	await frames(20)
	var hp0 := w.hp
	w.take_hit(6, 1)
	check("too tough", w.hp == hp0)
	# it follows him all over the Root Hollows now, not just its hall
	level._move_player(Vector2(16700, 2060), 1)
	var followed := false
	for i in 300:
		await frames(1)
		if w.fight and (w.state == "tell" or w.state == "move") and absf(w.a.x - p.global_position.x) < 420.0:
			followed = true
			break
	check("follows him through the hollows", followed, "state %s a %.0f him %.0f" % [w.state, w.a.x, p.global_position.x])
	check("mystery hint", level.hud._hint_text.contains("GLARE TRAP"), level.hud._hint_text)
	level._move_player(Vector2(15550, 2100), 1)
	# its moves: several kinds, two hearts a bite
	vuln = true
	p.max_hp = 60
	p.hp = 60
	var seen := {}
	var bites: Array = []
	var last_hp := p.hp
	for i in 840:
		await frames(1)
		if w.state == "move" or w.state == "tell":
			seen[w.move] = true
		if p.hp < last_hp:
			bites.append(last_hp - p.hp)
		last_hp = p.hp
		p.invuln = 0.0 if p.invuln > 0.6 else p.invuln
		if p.global_position.x < 15420.0 or p.global_position.x > 16180.0:
			level._move_player(Vector2(15550, 2100), 1)
	vuln = false
	check("many moves", seen.size() >= 3, str(seen.keys()))
	check("two hearts a bite (a stalactite: one)", bites.has(2) and bites.all(func(x): return x == 2 or x == 1), str(bites))
	check("it gets sneakier", OneEye.PHASES[2][0].has("fake") and OneEye.PHASES[1][0].has("spit") and float(OneEye.PHASES[2][1]) < float(OneEye.PHASES[0][1]))
	# badly hurt, it uses its sneaky moves too (the spit's globs bite for two)
	w.hp = 15
	await frames(40)
	await shot("roar")
	vuln = true
	var late := {}
	var globs := 0
	for i in 1500:
		await frames(1)
		if w.state == "tell" or w.state == "move":
			late[w._last] = true
		for c in level.get_children():
			if c is OneEye.Glob:
				globs += 1
		p.invuln = 0.0 if p.invuln > 0.6 else p.invuln
		p.hp = maxi(p.hp, 20)
		if p.global_position.x < 15420.0 or p.global_position.x > 16180.0:
			level._move_player(Vector2(15550, 2100), 1)
	vuln = false
	check("sneaky moves", late.has("spit") or late.has("fake") or late.has("double"), str(late.keys()) + " globs seen %d" % globs)
	var stal := 0
	for c in level.get_children():
		if c is OneEye.Stalactite:
			stal += 1
	check("roared and the roof came down", w._phase_shown == 2 and w._rage > 0.3, "phase %d rage %.2f" % [w._phase_shown, w._rage])
	w.hp = OneEye.HP
	p.max_hp = 5
	p.hp = 5
	await shot("hunt")
	# 3. out of the Root Hollows (back up top): it gives up
	level._move_player(Vector2(14100, 590), -1)
	await frames(150)
	check("it gives up", not w.fight and w.state == "sleep", "state %s fight %s" % [w.state, w.fight])
	# 4. the trap: the recipe is known now; make it
	check("the trap is a job in the bag (no recipe given)", Bag.job.get("title", "") == "A GLARE TRAP" and Bag.recipe("trap").is_empty(), str(Bag.job.get("title", "")))
	p.berries = 1
	GameState.bag["clay"] = 1
	check("start the job", Bag.start_job() and Bag.mixer != null)
	var m := Bag.mixer
	for k in ["berries", "quartz", "clay"]:
		m.put(k)
	m.mixed.emit(m.mix.duplicate())
	check("a wrong mix: a nudge", Bag.count(p, "trap") == 0 and m.note.contains("SPARK"), m.note)
	m.put("pyrite")
	m.mixed.emit(m.mix.duplicate())
	await frames(3)
	check("worked out the trap", Bag.count(p, "trap") == 1 and Bag.mixer == null and Bag.count(p, "quartz") == 0, "traps %d" % Bag.count(p, "trap"))
	# 5. back in, set it down: up it comes under it, blinded
	level._move_player(Vector2(15560, 2100), 1)
	await frames(10)
	p.select_slot(p.hotbar().find("trap"))
	await frames(2)
	p.touch["attack"] = true
	await frames(3)
	p.touch["attack"] = false
	var traps := get_tree().get_nodes_in_group("worm_trap")
	check("trap set", traps.size() == 1)
	level._move_player(Vector2(15450, 2100), -1)       # (step back from it)
	var stunned := await wait_state("stunned", 400)
	check("blinded by the trap", stunned and traps.size() > 0 and is_instance_valid(traps[0]) and traps[0].charges == 2, "state %s" % w.state)
	await frames(10)
	await shot("stunned")
	w.take_hit(30, 1)
	check("hurt while blinded", w.hp == 30, "hp %d" % w.hp)
	# 6. the second stun beats it
	stunned = await wait_state("dive", 400)
	stunned = await wait_state("stunned", 1200)
	check("blinded again (after one at him)", stunned)
	w.take_hit(30, 1)
	check("beaten", w.state == "dead")
	await frames(330)
	check("rewards", GameState.mystery("one_eye") == "solved" and Bag.count(p, "obsidian") == 2 and GameState.orbs >= 25 and not is_instance_valid(w),
		"obsidian %d orbs %d" % [Bag.count(p, "obsidian"), GameState.orbs])
	print("DONE")
	get_tree().quit()
