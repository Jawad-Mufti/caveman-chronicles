extends Node
## Test harness (not shipped): the exploring update.
##   lanes   - every hop in the new sky lanes is a jump he can make
##   jelly   - landing on a drift jelly bounces him high; its tentacles sting from below
##   ray     - standing on a sky ray, it carries him across
##   relic   - touching a rare find keeps it (GameState.relics) and it doesn't come back
##   burrow  - an opened burrow is a hole in the ground: he walks in and drops into the shaft, same level, no door
##   worms   - the glow-worm threads slow him; a whack snips one
##   snail   - three whacks crack the crystal snail and its find comes out
##   angler  - near the lure it snaps (a hit); a whack on the lure sends it back
## args: any of the above (default all)
var level: Node
var p: CaveMan
var runs := 0
var fails := 0

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	GameState.learn("sunfire")
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
	for k in ["left", "right", "jump", "attack", "stomp"]:
		p.touch[k] = false

func put(at: Vector2) -> void:
	release()
	while Engine.time_scale < 1.0:          # a hit-stop runs on real time: let it end
		await get_tree().physics_frame
	level._move_player(at, 1)
	p.velocity = Vector2.ZERO
	p.hp = 5
	p.invuln = 0.0
	await frames(6)

func has(args: Array, n: String) -> bool:
	return args.is_empty() or args.has(n)

func first(cls) -> Node:
	for c in level.get_children():
		if is_instance_of(c, cls):
			return c
	return null

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	p = level.player
	await frames(5)
	p.give_torch()
	for m in level._mouths:
		m._noticed = true
	quiet()

	if has(args, "lanes"):
		# from each rock to the next: across and up must be inside a double jump
		# (~385 across, ~230 up); a jelly or a ray in between carries him instead
		var bad := []
		for lane in level.SKY_LANES_2:
			var rocks: Array = lane["rocks"]
			var prev: Array = [lane["start"][0] - 60.0, lane["start"][1], 60.0]
			for r in rocks:
				if lane.has("pad") and prev[2] == 60.0 and r == rocks[0]:
					prev = r          # off the bloom: it launches him
					continue
				var gap: float = float(r[0]) - (float(prev[0]) + float(prev[2]))
				var rise: float = float(prev[1]) - float(r[1])
				var helped := false
				for j in lane["jellies"]:
					if float(j[0]) > float(prev[0]) and float(j[0]) < float(r[0]) + 40.0:
						helped = true
				for ry in lane["rays"]:
					if float(ry[0]) - 130.0 <= float(prev[0]) + float(prev[2]) and float(ry[1]) + 130.0 >= float(r[0]):
						helped = true
				if not helped and (gap > 300.0 or rise > 200.0):
					bad.append("%s: %.0f across, %.0f up to x %.0f" % [lane["name"], gap, rise, r[0]])
				prev = r
		report("lanes: every hop is a jump he can make", bad.is_empty(), str(bad))

	if has(args, "jelly"):
		var j: SkyCreatures.DriftJelly = first(SkyCreatures.DriftJelly)
		await put(j.global_position + Vector2(0, -90))
		var top := 0.0
		for i in 40:
			await frames(1)
			top = minf(top, p.velocity.y)
		var bounced := top < -900.0
		# now from underneath, into the tentacles
		await frames(60)
		j._sting = 0.0
		p.global_position = j.global_position + Vector2(0, 110)
		p.velocity = Vector2(0, -400)
		p.invuln = 0.0
		var hp0 := p.hp
		for i in 20:
			await frames(1)
			if p.hp < hp0:
				break
		report("jelly: bounce on top, sting from below", bounced and p.hp < hp0, "launch %.0f, hp %d -> %d" % [top, hp0, p.hp])
		await put(Vector2(1300, 590))       # away from it, so it lets go of him

	if has(args, "ray"):
		var ray: SkyCreatures.SkyRay = first(SkyCreatures.SkyRay)
		while Engine.time_scale < 1.0:
			await get_tree().physics_frame
		ray._t = 0.6           # early in a sweep, so it is on its way somewhere
		await get_tree().physics_frame          # it moves there on its next step
		await put(ray.global_position + Vector2(0, -20))     # put waits: overlaps settle after a teleport
		p.invuln = 99.0
		var x0 := p.global_position.x
		var on := 0
		for i in 150:
			await frames(1)
			if p.is_on_floor():
				on += 1
			if args.has("trace") and i % 15 == 0:
				print("   ray %.0f,%.0f  p %.0f,%.0f floor %s dead %s" % [ray.global_position.x, ray.global_position.y, p.global_position.x, p.global_position.y, p.is_on_floor(), p.dead])
		var moved := absf(p.global_position.x - x0)
		report("ray: it carries him along", moved > 120.0 and on > 100, "moved %.0f px, on its back %d frames" % [moved, on])

	if has(args, "relic"):
		var r := level.DEEP_RELICS[0] as Array
		await put(Vector2(r[0], float(r[1]) + 30.0))
		await frames(20)
		var kept := int(GameState.relics.get(r[2], 0)) == 1 and GameState.is_taken("level2", r[3])
		var gone := level.get_children().filter(func(c): return c is Relics.Relic and c.id == r[3]).is_empty()
		report("relic: a rare find is kept, and gone", kept and gone, "relics %s" % str(GameState.relics))

	if has(args, "burrow"):
		# (the MEGA stomp that opens it is tested in `dig`)
		var b: Underground.Burrow = level._burrow
		b.open = true
		b.opened.emit()
		await put(Vector2(b.global_position.x - 120.0, 590))
		p.touch["right"] = true
		for i in 60:
			await frames(1)
			if absf(p.global_position.x - b.global_position.x) < 10.0:
				p.touch["right"] = false
		release()
		var opened := b.open
		await frames(60)
		var under: bool = level._region == 0 and p.global_position.y > float(level.DIG_GRID[1]) + 20.0
		report("burrow: a hole in the ground, he drops into the shaft", opened and under, "opened %s, below the ground %s (y %.0f)" % [opened, under, p.global_position.y])

	if has(args, "worms"):
		var w: Underground.GlowWorms = null
		for c in level.get_children():
			if c is Underground.GlowWorms and c.reach > 300.0:
				w = c
		await put(Vector2(w.global_position.x + 10.0, 2128.0))
		p.invuln = 99.0
		p.touch["right"] = true
		var slow := 0
		for i in 120:
			await frames(1)
			if p.is_on_floor() and absf(p.velocity.x) < 200.0 and p.global_position.x > w.global_position.x:
				slow += 1
		release()
		# a whack snips the nearest thread
		var cut0 := w._threads.filter(func(th): return float(th[3]) > 0.0).size()
		w.take_hit(1, 1)
		var cut1 := w._threads.filter(func(th): return float(th[3]) > 0.0).size()
		report("worms: sticky threads slow him; a whack snips", slow > 10 and cut1 > cut0, "slowed %d frames, cut %d -> %d" % [slow, cut0, cut1])

	if has(args, "snail"):
		var s: Underground.CrystalSnail = first(Underground.CrystalSnail)
		var had := int(GameState.relics.get("glow_crystal", 0))
		for i in 3:
			s._hide = 0.0
			s.take_hit(1, 1)
		await frames(10)
		var relic: Node = null
		for c in level.get_children():
			if c is Relics.Relic and c.id == "r3":
				relic = c
		var out := relic != null
		if relic != null:
			p.global_position = relic.global_position + Vector2(0, 20)
			await frames(10)
		report("snail: three whacks, its find comes out", out and int(GameState.relics.get("glow_crystal", 0)) == had + 1, "find out %s" % out)

	if has(args, "angler"):
		var a: Underground.Angler = first(Underground.Angler)
		var lure := a.global_position + a.lure_at()
		await put(Vector2(lure.x - 30.0, 2088.0))
		var hp0 := p.hp
		var tense := false
		for i in 90:
			await frames(1)
			tense = tense or a.state == "tense"
			if p.hp < hp0:
				break
		var bit := p.hp < hp0
		await frames(120)
		a.state = "lurk"
		a._cool = 0.0
		a.take_hit(1, 1)
		report("angler: it snaps near the lure; a whack scares it", tense and bit and a.state == "scared", "tense %s, bit %s, now %s" % [tense, bit, a.state])

	print("%d scenarios, %d failed" % [runs, fails])
	get_tree().quit()
