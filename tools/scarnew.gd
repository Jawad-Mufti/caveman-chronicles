extends Node
## Test (headless): OLD SCAR'S NEW FIGHT (level2/old_scar.gd, scar_arena.gd),
## each piece set up and checked: a PARRY on his raised paw (staggered, open),
## a rock to the BROKEN FANG from afar (triple damage), a CLOSE ONE (a pounce
## slipped at the last moment: he stumbles), THE CLOUDS over the moon (darker,
## he favours the dark), THE DEAD TREE falling into a log (it stops his
## charge: dazed), PHASE 4 RAGE (the roar, burning branches, faster), a
## burning branch hurting the man and stopping a pounce with its fire, and
## the reset when the man falls.
##   <godot> --headless --fixed-fps 60 --path . res://tools/scarnew.tscn
var level: Node
var p: CaveMan
var sc: OldScar
var ar: Node
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


func check(label: String, ok: bool, info: String = "") -> void:
	if not ok:
		fails += 1
	print("%s %s  %s" % ["PASS" if ok else "FAIL", label, info])


## Him at x, facing the man; the man at x + gap, on the ground.
func stage(x: float, gap: float, st := "prowl") -> void:
	sc.position = Vector2(x, sc.floor_y)
	sc.cur_floor = sc.floor_y
	sc.vel = Vector2.ZERO
	sc.vx = 0.0
	sc.state = st
	sc.timer = 1.0
	sc.cd = 9.0
	sc.dir = 1 if gap > 0.0 else -1
	p.global_position = Vector2(x + gap, sc.floor_y - 2.0)
	p.velocity = Vector2.ZERO
	p.hp = p.max_hp


func _run() -> void:
	await frames(5)
	p = level.player
	for c in level.get_children():
		if c is Dialogue or c is Shop:
			c.queue_free()
	p.talking = false
	p.give_torch()
	level._snuffed = true
	level._panicked = true
	level._met_toolmaker = true
	sc = level.scar
	ar = level.scar_arena
	check("the clearing knows its arena", ar != null and sc.arena == ar)
	p.global_position = Vector2(32600, 590)
	var n := 0
	while sc.state in ["wait", "lurk_in", "emerge", "intro"] and n < 900:
		await frames(1)
		n += 1
	check("the fight starts", sc.state == "prowl", sc.state)
	var kinds: Array = []
	sc.countered.connect(func(k: String) -> void: kinds.append(k))
	var mid := (sc.arena_l + sc.arena_r) * 0.5
	# ---- PARRY: his paw raised for a swipe, a blow from in front
	stage(mid, 120.0, "swipe")
	sc.timer = 0.5
	var hp0 := sc.hp
	sc.take_hit(2, -1)
	check("PARRY: a blow on his raised paw: he staggers, open", sc.state == "staggered" and kinds.has("parry") and sc.hp == hp0 - 2, sc.state)
	await frames(5)
	hp0 = sc.hp
	sc.take_hit(2, -1)
	check("staggered: hits land double", sc.hp == hp0 - 4, "%d -> %d" % [hp0, sc.hp])
	# ---- THE BROKEN FANG: a rock from afar, square in his face
	stage(mid, 420.0, "prowl")
	sc._fang_cd = 0.0
	hp0 = sc.hp
	sc.take_hit(1, -1)
	check("a rock to the broken fang: triple damage, he flinches", sc.hp == hp0 - 3 and sc.state == "flinch" and kinds.has("fang"), "%d -> %d" % [hp0, sc.hp])
	hp0 = sc.hp
	stage(mid, 420.0, "prowl")
	sc.take_hit(1, -1)
	check("not again at once (it takes a while)", sc.hp == hp0 - 1)
	# ---- CLOSE ONE: a pounce slipped at the last moment
	stage(mid, 300.0, "prowl")
	sc._launch(Vector2(mid + 300.0, sc.floor_y), 0.62)
	sc.state = "pounce"
	sc.resolved = false
	p.global_position = Vector2(mid + 460.0, sc.floor_y - 2.0)
	n = 0
	while sc.state == "pounce" and n < 120:
		await frames(1)
		p.global_position = Vector2(mid + 460.0, sc.floor_y - 2.0)
		n += 1
	check("a pounce slipped at the last moment: he stumbles, open", sc.state == "stumble" and kinds.has("dodge"), sc.state)
	# ---- THE CLOUDS
	ar.clouds_on()
	var darkest := 0.0
	var extra0: float = level.night.extra
	level._fight = true
	for i in 60 * 10:
		await get_tree().process_frame
		darkest = maxf(darkest, ar.dark)
		if ar.is_dark():
			break
	check("clouds over the moon: the clearing goes dark", ar.is_dark() and level.night.extra > extra0 + 0.05, "dark %.2f" % darkest)
	# ---- THE DEAD TREE, the log, his charge into it
	ar.fell_tree()
	await frames(120)
	check("the dead tree falls: a log across the clearing", ar._log != null)
	var log_x: float = ar._log.position.x
	stage(log_x - 260.0, -200.0, "charge")
	sc.dir = 1
	sc.vx = 400.0
	n = 0
	while sc.state == "charge" and n < 200:
		await frames(1)
		n += 1
	check("his blind charge: WHAM into the log, dazed", sc.state == "dazed" and sc.position.x < log_x and kinds.has("log"), "%s at %.0f (log at %.0f)" % [sc.state, sc.position.x, log_x])
	# ---- PHASE 4: RAGE
	stage(mid, 200.0, "prowl")
	sc.phase = 3
	sc._siege = 4
	sc.hp = 16
	var ph := []
	sc.phase_changed.connect(func(x: int) -> void: ph.append(x))
	sc.take_hit(2, -1)
	check("below 12%: PHASE 4, the rage roar", sc.phase == 4 and sc.state == "rage_roar" and ph.has(4), sc.state)
	await frames(60)
	var fires: int = ar._branches.filter(func(b): return is_instance_valid(b)).size()
	check("the rage roar: burning branches crash down", fires >= 3, "%d" % fires)
	check("in his rage: red eyes, faster tells", [0.75, 0.55, 0.4, 0.32][sc.phase - 1] < 0.4)
	# a burning branch: it hurts the man on it, and its fire stops a pounce
	await frames(40)
	var br = ar._branches[0]
	p.global_position = br.global_position + Vector2(0, -2)
	p.hp = p.max_hp
	p.invuln = 0.0
	await frames(10)
	check("a burning branch hurts the man on it", p.hp < p.max_hp, "%d / %d" % [p.hp, p.max_hp])
	await frames(10)
	check("and it is fire: his pounce won't go through it", sc._meets_fire())
	# ---- he beats the man: all back as it was
	ar.reset()
	await frames(2)
	check("reset: no log, no fire, the moon back", ar._log == null and ar._branches.is_empty() and absf(level.night.moon_r - 70.0) < 0.1)
	print("scarnew: %d failed" % fails)
	get_tree().quit()
