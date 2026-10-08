extends Node
## Test harness (not shipped): the combo moves and the escalation. CYCLONE (the
## 4th of the chain) hits behind him too; RAM (HIT at a full run) charges;
## LAUNCH (UP + HIT) lifts a beast, JUGGLE keeps it up, SLAM DUNK (DOWN + HIT)
## spikes it down and knocks over the one beside it. Ambushes get harder the
## further along they are (tiers, waves, elites). One PASS/FAIL line each.
##   shots - also save screenshots (run with rendering) to C:/tmp/shots/combos_*
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
	level.cam.zoom = Vector2(1.6, 1.6)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/combos_%s.png" % name)

func check(name: String, ok: bool, info: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name, info])

func release() -> void:
	for k in p.touch.keys():
		p.touch[k] = false

func clear_beasts() -> void:
	for c in level.get_children():
		if c is Critter:
			c.free()

## A tough wolf that stands still (no AI), so the moves can be measured.
func dummy(x: float) -> Critter:
	var w := NightBeasts.Wolf.new()
	w.left_x = x - 300.0
	w.right_x = x + 300.0
	w.position = Vector2(x, 600)
	level.add_child(w)
	w.hp = 200
	w.stompable = false
	w.damage = 0
	w.set_meta("still", true)
	return w

func hold_still(ws: Array) -> void:
	# its AI off, but physics (launch, knock-back) on: freeze its own moves
	for w in ws:
		if is_instance_valid(w):
			w.state = "cower"

func _run() -> void:
	shots = OS.get_cmdline_user_args().has("shots")
	p = level.player
	await frames(5)
	p.pick_up_stick()
	clear_beasts()
	# 1. CYCLONE: hold HIT through the chain; the wolf BEHIND him gets hit too
	level._move_player(Vector2(1200, 590), 1)
	p.facing = 1
	await frames(10)
	var front := dummy(1250.0)
	var back := dummy(1155.0)
	var back0 := back.hp
	var saw := false
	p.touch["attack"] = true
	for i in 120:
		hold_still([front, back])
		p.global_position.x = 1200.0
		p.facing = 1
		await frames(1)
		if p._swing_kind == "cyclone":
			saw = true
			if i % 6 == 0:
				await shot("cyclone")
	release()
	check("cyclone (4th hit) hits behind", saw and back.hp < back0, "cyclone seen %s, back wolf hp %d -> %d" % [saw, back0, back.hp])
	clear_beasts()
	await frames(20)
	# 2. RAM: run flat out, then HIT
	level._move_player(Vector2(1020, 590), 1)
	await frames(10)
	var target := dummy(1330.0)
	var hp0 := target.hp
	p.touch["right"] = true
	await frames(25)
	p.touch["attack"] = true
	var rammed := false
	for i in 30:
		hold_still([target])
		await frames(1)
		rammed = rammed or p._swing_kind == "ram"
	release()
	check("ram (HIT at a run)", rammed and target.hp < hp0, "ram %s, hp %d -> %d" % [rammed, hp0, target.hp])
	clear_beasts()
	await frames(20)
	# 3. LAUNCH, JUGGLE, SLAM DUNK
	level._move_player(Vector2(1200, 590), 1)
	p.facing = 1
	await frames(10)
	var w := dummy(1250.0)
	var side := dummy(1330.0)
	var side0 := side.hp
	p.touch["up"] = true
	p.touch["attack"] = true
	var up := false
	for i in 20:
		hold_still([side])
		await frames(1)
		if w.airborne:
			up = true
			break
	release()
	check("launch (UP + HIT)", up, "airborne %s" % w.airborne)
	await shot("launch")
	# after it: jump, and HIT it up there
	p.touch["jump"] = true
	await frames(10)
	p.touch["attack"] = true
	var juggled := false
	for i in 30:
		hold_still([side])
		await frames(1)
		if p._juggles > 0:
			juggled = true
			break
	p.touch["attack"] = false
	check("juggle (HIT in the air)", juggled, "juggles %d" % p._juggles)
	await shot("juggle")
	# and spike it down: a fresh launch, a jump to get ABOVE it, then DOWN + HIT
	# (a timing move: the test gets three tries, as a player would)
	var dunked := false
	for attempt in 3:
		release()
		await frames(50)
		level._move_player(Vector2(1200, 590), 1)
		p.facing = 1
		w.global_position = Vector2(1240, 600)
		side.global_position = Vector2(1320, 600)
		await frames(5)
		for i in 30:                    # on his feet: UP + HIT in the air is a KICK now, not the launcher
			if p.is_on_floor():
				break
			await frames(1)
		p.touch["up"] = true
		p.touch["attack"] = true
		await frames(8)
		release()
		await frames(4)
		p.touch["jump"] = true          # a double jump, to get up above it
		await frames(12)
		p.touch["jump"] = false
		await frames(2)
		p.touch["jump"] = true
		var slammed := false
		var s0: int = side.hp
		for i in 90:
			hold_still([side])
			await frames(1)
			if w.airborne and p.global_position.y < w.global_position.y - 6.0:
				p.touch["down"] = true
				p.touch["attack"] = true
			for c in level.get_children():
				if c is CaveMan.WordPop and c.text == "SLAM DUNK!!":
					slammed = true
			if slammed and side.hp < s0:
				dunked = true
				break
		if dunked:
			break
	release()
	await shot("slam")
	check("slam dunk knocks the one beside", dunked, "side wolf hp %d -> %d, landed %s" % [side0, side.hp, not w.airborne])
	clear_beasts()
	await frames(20)
	# 4. ESCALATION: deeper ambushes are harder
	var tiers := []
	var deepest: Node = null
	for c in level.get_children():
		if c.get_script() == level.AMBUSH:
			tiers.append(c.tier)
			if deepest == null or c.x0 > deepest.x0:
				deepest = c
	tiers.sort()
	var plan1: Array = deepest._plan()
	var count := 0
	for wv in plan1:
		count += (wv as Array).size()
	check("ambushes escalate", tiers.front() == 1 and tiers.back() == 5 and plan1.size() == 3 and count > 9,
		"tiers %s; the deepest: %d waves, %d beasts, elites %.0f%%" % [tiers, plan1.size(), count, deepest._elite_chance() * 100.0])
	# the deepest one, fought: wave after wave
	level._move_player(Vector2(deepest.x0 + 200.0, 590), 1)
	p.invuln = 99.0
	var waves_seen := 1
	var elites := 0
	for i in 1500:
		await frames(1)
		p.invuln = 99.0
		for c in level.get_children():
			if c is Critter and c.dying <= 0.0 and c.global_position.distance_to(p.global_position) < 900.0 and not c.has_meta("counted") and deepest._spawned.has(c):
				c.set_meta("counted", true)
				if c.elite:
					elites += 1
		# beat each one shortly after it arrives
		if i % 30 == 0:
			for c in deepest._spawned:
				if is_instance_valid(c) and c.dying <= 0.0:
					c.take_hit(999, 0)
					break
		waves_seen = maxi(waves_seen, deepest._wave + 1)
		if i == 300:
			await shot("ambush")
		if deepest._done:
			break
	check("deep ambush: waves, elites, cleared", waves_seen == 3 and deepest._done, "waves %d, elites %d, done %s" % [waves_seen, elites, deepest._done])
	get_tree().quit()
