extends Node
## Test harness (not shipped): the Tar Pits.
##   sink   - standing still on a log: it goes under, he is stuck, hauled out on the bank (1 heart)
##   cross  - a hopping bot: lands on each log and jumps straight on to the next; gets across
##   geyser snap snapbonk - a vent blows him up; the croc chomps; a whack sends it under
##   skip   - a full running double jump can't clear the widest pool
## args: any of the above (default all), "trace"
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

func report(label: String, ok: bool, info: String) -> void:
	runs += 1
	if not ok:
		fails += 1
	print("%-42s %s  %s" % [label, "PASS" if ok else "FAIL", info])

func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	p.talking = false

func release() -> void:
	for k in ["left", "right", "jump", "attack"]:
		p.touch[k] = false

func put(at: Vector2) -> void:
	release()
	p.global_position = at
	p.velocity = Vector2.ZERO
	p.hp = 5
	p.invuln = 0.0
	await frames(6)

func has(args: Array, n: String) -> bool:
	return args.is_empty() or args.has(n) or (args.size() == 1 and args[0] == "trace")

## Where he can stand, left to right: [centre x, top y] of every log, islet and rock.
func stops() -> Array:
	var out := []
	for lg in level.TAR_LOGS:
		out.append([float(lg[0]), 600.0])
	for r in level.TAR_ROCKS:
		out.append([float(r[0]) + float(r[2]) * 0.5, float(r[1])])
	out.append([16350.0, 600.0])          # islet 1
	out.append([16900.0, 600.0])          # islet 2
	out.append([17560.0, 600.0])          # the far bank
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	await frames(5)
	p = level.player
	p.give_torch()
	for c in level.get_children():
		if c is Critter or c is NightBeasts.Monkey:
			c.queue_free()
	for m in level._mouths:
		m._noticed = true
	quiet()
	await frames(3)

	if has(args, "sink"):
		await put(Vector2(16180, 590))
		var t := 0
		while t < 240 and p.global_position.x > 16120.0:
			await get_tree().physics_frame
			t += 1
			quiet()
		var g := p.global_position
		report("sink: standing on a log, he's stuck in the end", g.x < 16080.0 and p.hp == 4, "after %.1f s at (%.0f, %.0f), hp %d/5" % [t / 60.0, g.x, g.y, p.hp])

	if has(args, "cross"):
		await put(Vector2(16000, 590))
		var path := stops()
		var goal := 0
		var t2 := 0
		var stuck := 0
		var hp0 := p.hp
		var aloft := false
		var waited := 0
		var hits := 0
		var tarred := [0]
		for c in level.get_children():
			if c is TarPits.Pool:
				c.stuck.connect(func() -> void: tarred[0] += 1)
		while t2 < 1800 and p.global_position.x < 17500.0:
			await get_tree().physics_frame
			t2 += 1
			quiet()
			if p.hp < hp0:
				if args.has("why"):
					var near := []
					for c in level.get_children():
						if (c is Hoards.GuardFly or c is TarPits.Snapper or c is TarPits.Geyser) and absf(c.global_position.x - p.global_position.x) < 120.0:
							near.append("%s:%s" % [c.get_script().get_global_name() if false else c.get_class(), c.state])
					print("HIT t %d at (%.0f, %.0f) tar %d near %s" % [t2, p.global_position.x, p.global_position.y, tarred[0], near])
				hp0 = p.hp
				if tarred[0] > stuck:
					stuck = tarred[0]
					goal = 0
				else:
					hits += 1          # a geyser or the snapper: tossed up, not stuck
				p.hp = 5
				hp0 = 5
			var x := p.global_position.x
			# the first stop still ahead of him (chosen only on the ground: in the air
			# he steers for the one he jumped at)
			if p.is_on_floor():
				while goal < path.size() and float(path[goal][0]) < x + 30.0:
					goal += 1
			var tx: float = path[mini(goal, path.size() - 1)][0]
			if p.is_on_floor():
				aloft = false
				p.touch["right"] = true
				# at the edge of solid ground, or on anything floating: jump for the next stop
				var on_log := false
				for c in level.get_children():
					if c is TarPits.Log and absf(c.global_position.x - x) < c.w * 0.5 + 12.0 and absf(c.global_position.y - p.global_position.y) < 5.0:
						on_log = true
				var edge := false
				for tp in level.TAR_POOLS:
					if x > float(tp[0]) - 40.0 and x < float(tp[0]):
						edge = true
				var rock := x > 16640.0 and x < 16680.0 and p.global_position.y < 560.0
				# like a person: on firm ground, wait while the next geyser is about to blow
				var wait := false
				if (edge or rock) and not on_log:
					for c in level.get_children():
						if c is TarPits.Geyser and c.global_position.x > x and c.global_position.x < x + 230.0:
							var k := fmod(c._t, c.cycle())
							wait = k > c.quiet - 0.55
				if wait:
					p.touch["right"] = false
					waited += 1
				elif on_log or edge or rock:
					p.touch["jump"] = true
			else:
				aloft = true
				if p.velocity.y > -60.0:
					p.touch["jump"] = false
				# ease off early enough to stop over it (air drag stops him in v²/1700 px)
				p.touch["right"] = x + p.velocity.x * absf(p.velocity.x) / 1700.0 < tx
			if args.has("trace") and t2 % 6 == 0:
				print("t %d x %.0f y %.0f goal %d (%.0f) floor %s" % [t2, x, p.global_position.y, goal, tx, p.is_on_floor()])
		release()
		report("cross: hops the logs to the far bank", p.global_position.x >= 17500.0 and stuck == 0,
			"at x %.0f, stuck %d times, hit %d times, waited %.1f s, %.1f s" % [p.global_position.x, stuck, hits, waited / 60.0, t2 / 60.0])

	if has(args, "geyser"):
		# stands on the islet's edge right by a vent: it rumbles, then blows him sky-high
		var gy: TarPits.Geyser = level.get_children().filter(func(c): return c is TarPits.Geyser)[1]
		for c in level.get_children():
			if c is Hoards.GuardFly:
				c.queue_free()          # just the vent
		while gy.state != "quiet":
			await get_tree().physics_frame
		await put(Vector2(16848, 590))
		var hp2 := p.hp
		var rumbled := false
		var top := 999.0
		var t4 := 0
		while t4 < 360 and p.hp == hp2:
			await get_tree().physics_frame
			t4 += 1
			quiet()
			rumbled = rumbled or gy.state == "rumble"
		for i in 30:
			await get_tree().physics_frame
			top = minf(top, p.global_position.y)
			if args.has("trace") and i % 3 == 0:
				print("g %s  p (%.0f, %.0f) v (%.0f, %.0f) floor %s" % [gy.state, p.global_position.x, p.global_position.y, p.velocity.x, p.velocity.y, p.is_on_floor()])
		report("geyser: rumbles, then tosses him up", rumbled and p.hp < hp2 and top < 450.0,
			"after %.1f s, hp %d -> %d, flew up to y %.0f" % [t4 / 60.0, hp2, p.hp, top])

	if has(args, "snap"):
		# stands still on a log in the snapper's pool: CHOMP
		var sn: TarPits.Snapper = level.get_children().filter(func(c): return c is TarPits.Snapper)[0]
		await put(Vector2(17180, 590))
		var hp3 := p.hp
		var t5 := 0
		var warned := false
		while t5 < 240 and p.hp == hp3:
			await get_tree().physics_frame
			t5 += 1
			quiet()
			warned = warned or sn.state == "warn"
		report("snap: the croc chomps him off a log", warned and p.hp < hp3, "after %.1f s, hp %d -> %d" % [t5 / 60.0, hp3, p.hp])

	if has(args, "snapbonk"):
		var sn2: TarPits.Snapper = level.get_children().filter(func(c): return c is TarPits.Snapper)[0]
		await put(Vector2(17300, 590))
		p.invuln = 99999.0
		var bonked := false
		for i in 300:
			await get_tree().physics_frame
			quiet()
			for c in level.get_children():
				if c is TarPits.Log:
					c.sunk = 0.0        # it won't sink: time to fight
			# swing as the jaws come up (the club is live a moment after the press)
			p.touch["attack"] = (sn2.state == "warn" and sn2._st > 0.42) or (sn2.state == "snap" and sn2._st > 0.12 and sn2._st < 0.2)
			if args.has("trace") and i % 3 == 0:
				print("%d snap %s x %.0f  p (%.0f, %.0f) atk %.2f" % [i, sn2.state, sn2.position.x, p.global_position.x, p.global_position.y, p.attacking])
			if sn2.state == "dizzy":
				bonked = true
				break
		p.touch["attack"] = false
		p.invuln = 0.0
		report("snapbonk: a whack on the snout sends it under", bonked, "")

	if has(args, "skip"):
		# a running double jump off the near bank of the widest pool
		await put(Vector2(16840, 590))
		p.touch["right"] = true
		var t3 := 0
		var pressed := 0
		var hp1 := p.hp
		var landed_far := false
		while t3 < 240:
			await get_tree().physics_frame
			t3 += 1
			quiet()
			for c in level.get_children():
				if c is TarPits.Log:
					c.process_mode = Node.PROCESS_MODE_DISABLED   # no logs: just the jump
					c.position.y = 2000.0
			if pressed == 0 and p.global_position.x > 16940.0:
				p.touch["jump"] = true
				pressed = 1
			elif pressed == 1 and p.velocity.y > -60.0:
				p.touch["jump"] = false
				pressed = 2
			elif pressed == 2:
				p.touch["jump"] = true
				pressed = 3
			if p.hp < hp1:
				break
			if p.is_on_floor() and p.global_position.x > 17480.0:
				landed_far = true
				break
		release()
		report("skip: too wide to double-jump", not landed_far, "at (%.0f, %.0f), hp %d/5" % [p.global_position.x, p.global_position.y, p.hp])

	print("%d scenarios, %d failed" % [runs, fails])
	get_tree().quit()
