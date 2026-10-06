extends Node
## Test harness (not shipped): Thunder Canyon.
##   stones  - rides the Sky Stones' vines, stone to stone as each swings close,
##             onto the rest ledge
##   rocks   - hops the floating rocks to the far side while the bats dive
##   calm    - no bats while he's still on the first rock
##   stand   - stands still on a rock: a bat drops on him
##   bonk    - clubs a diving bat: it tumbles away
##   door    - the Weeping Cave's mouth is in the last outcrop's far face
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
	print("%-46s %s  %s" % [label, "PASS" if ok else "FAIL", info])

func quiet() -> void:
	for c in level.get_children():
		if is_instance_valid(c) and c is Dialogue:
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

func grip(s: Canyon.SkyStone) -> Vector2:
	var v := s.vine
	return v.global_position + Vector2(sin(v.angle), cos(v.angle)) * v.length

func dives() -> Array:
	return level.get_children().filter(func(c): return is_instance_valid(c) and c is Canyon.DiveBat)

## Rides the Sky Stones like a person: wait at the edge for the first vine to
## come close, jump for it; on each vine, wait until the next one swings close
## (and is getting closer), then jump for it; off the last, jump for the ledge.
func ride(chain: Array, land_x0: float, land_y: float, trace: bool) -> Array:
	var hp0 := p.hp
	var t := 0
	var i := -1
	var hold := 0
	var falls := 0
	var target_x := 0.0
	var last_gap := INF
	while t < 60 * 60:
		await get_tree().physics_frame
		t += 1
		quiet()
		if p.hp < hp0:
			falls += 1
			hp0 = p.hp
			i = -1
			if trace:
				print("   FELL")
		hold -= 1
		p.touch["jump"] = hold > 0
		var pos := p.global_position
		if p.vine != null:
			for k in chain.size():
				if p.vine == (chain[k] as Canyon.SkyStone).vine:
					i = k
			p.touch["right"] = false
			p.touch["left"] = false
			var next_x := land_x0 + 60.0
			var reach := 170.0
			if i + 1 < chain.size():
				next_x = grip(chain[i + 1]).x
				reach = 138.0
			var gap := next_x - grip(chain[i]).x
			var closing := gap < last_gap - 0.05
			var last_gap_prev := last_gap
			last_gap = gap
			# jump as it closes in, or right at the closest moment (when it starts to pull away)
			var at_closest := not closing and last_gap_prev < INF and gap < 158.0
			if gap > 0.0 and ((gap < reach and (closing or i + 1 >= chain.size())) or at_closest) and hold <= 0:
				hold = 14
				p.touch["jump"] = true
				p.touch["right"] = true
				target_x = next_x
				last_gap = INF
				if trace:
					print("   let go of %d: gap %.0f" % [i, gap])
		elif p.is_on_floor():
			if absf(pos.y - land_y) < 3.0 and pos.x > land_x0:
				break
			p.touch["right"] = false
			var first := grip(chain[0])
			var gap0 := first.x - pos.x
			var closing0 := gap0 < last_gap - 0.05
			last_gap = gap0
			if pos.x < 17920.0:
				p.touch["right"] = true          # walk up to the edge
			elif gap0 > 40.0 and gap0 < 165.0 and closing0 and hold <= 0:
				hold = 16
				p.touch["jump"] = true
				p.touch["right"] = true
				target_x = first.x
				last_gap = INF
		else:
			p.touch["right"] = pos.x + p.velocity.x * absf(p.velocity.x) / 1700.0 < target_x
		if trace and t % 20 == 0:
			print("t %d x %.0f y %.0f on %d vine %s" % [t, pos.x, pos.y, i, p.vine != null])
	release()
	return [p.global_position, falls, t]

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var trace := args.has("trace")
	await frames(5)
	p = level.player
	p.give_torch()
	for c in level.get_children():
		if (c is Critter and not c is OldScar) or c is NightBeasts.Monkey:
			c.queue_free()
	for m in level._mouths:
		m._noticed = true
	quiet()
	var stones := level.get_children().filter(func(c): return c is Canyon.SkyStone)
	var rocks := level.get_children().filter(func(c): return c is Canyon.FloatRock)

	if has(args, "stones"):
		await put(Vector2(17860, 590))      # firm ground first, a safe spot to come back to
		await frames(10)
		await put(Vector2(17930, 590))
		var r: Array = await ride(stones, 20200.0, 600.0, trace)
		var g: Vector2 = r[0]
		report("stones: stone to stone, onto the rest ledge", absf(g.y - 600.0) < 3.0 and g.x > 20200.0,
			"at (%.0f, %.0f), falls %d, %.1f s" % [g.x, g.y, r[1], r[2] / 60.0])

	if has(args, "calm"):
		await put(Vector2(20630, 510))
		for i in 240:
			await get_tree().physics_frame
			quiet()
		report("calm: no bats on the first rock", dives().is_empty(), "")

	if has(args, "stand"):
		var r3: Canyon.FloatRock = rocks[3]
		await put(Vector2(r3.global_position.x + 50.0, r3.global_position.y - 10.0))
		var hp0 := p.hp
		var t := 0
		while t < 600 and p.hp == hp0:
			await get_tree().physics_frame
			t += 1
			quiet()
		report("stand: a bat drops on him", p.hp < hp0, "after %.1f s" % (t / 60.0))

	if has(args, "bonk"):
		var r4: Canyon.FloatRock = rocks[4]
		await put(Vector2(r4.global_position.x + 60.0, r4.global_position.y - 10.0))
		p.invuln = 99999.0
		var bonked := false
		for i in 600:
			await get_tree().physics_frame
			quiet()
			for b in dives():
				if b.state == "dive" and b.global_position.y > p.global_position.y - 150.0:
					p.facing = 1 if b.global_position.x > p.global_position.x else -1
					p.touch["attack"] = true
				if b.state == "bonked":
					bonked = true
			if bonked:
				break
			if i % 8 == 7:
				p.touch["attack"] = false
		release()
		report("bonk: a club sends a diving bat flying", bonked, "")

	if has(args, "rocks"):
		await put(Vector2(20420, 590))
		await frames(10)
		var hp1 := p.hp
		var t2 := 0
		var hold := 0
		var dove := 0
		var seen := {}
		var goal := 0
		var falls := 0
		var dbg_hits := 0
		var floor_x := 0.0
		while t2 < 60 * 40 and not (p.is_on_floor() and p.global_position.x > 22640.0 and absf(p.global_position.y - 600.0) < 3.0):
			await get_tree().physics_frame
			t2 += 1
			quiet()
			for b in dives():
				if not seen.has(b):
					seen[b] = true
					dove += 1
			if p.hp < hp1 - dbg_hits and args.has("why"):
				dbg_hits += 1
				var near := []
				for c in level.get_children():
					if (c is Hoards.GuardFly or c is Canyon.DiveBat) and c.global_position.distance_to(p.global_position) < 80.0:
						near.append("%s %s" % ["fly" if c is Hoards.GuardFly else "bat", c.state])
				print("HIT t %d at (%.0f, %.0f) %s" % [t2, p.global_position.x, p.global_position.y, near])
			if p.global_position.y > 900.0:
				falls += 1
			hold -= 1
			p.touch["jump"] = hold > 0
			var pos := p.global_position
			# the next rock (or the ground beyond them all)
			var tx := 22700.0
			var ty := 600.0
			while goal < rocks.size() and (rocks[goal] as Canyon.FloatRock).global_position.x + 20.0 < pos.x:
				goal += 1
			if goal < rocks.size():
				var fr: Canyon.FloatRock = rocks[goal]
				tx = fr.global_position.x + fr.w * 0.5
				ty = fr.global_position.y
			if p.is_on_floor():
				# like a person: keep moving, hop to the next rock from the edge of this one
				p.touch["right"] = true
				var q := PhysicsRayQueryParameters2D.create(pos + Vector2(26, -6), pos + Vector2(26, 30), 1)
				if level.get_world_2d().direct_space_state.intersect_ray(q).is_empty() and hold <= 0:
					hold = 18 if ty < pos.y - 30.0 else 10
					p.touch["jump"] = true
				# a bat swooping in at him: hop it
				for b in dives():
					var bd: Canyon.DiveBat = b
					var gap := (pos.x - bd.global_position.x) * bd.dir
					if bd.state == "swoop" and gap > 0.0 and gap < 150.0 and hold <= 0:
						hold = 14
						p.touch["jump"] = true
				floor_x = pos.x
			elif p.invuln > 0.5:
				# just bowled up by a hit: come back down on the rock he was on
				p.touch["right"] = pos.x < floor_x - 6.0
				p.touch["left"] = pos.x > floor_x + 6.0
			else:
				p.touch["left"] = false
				p.touch["right"] = pos.x + p.velocity.x * absf(p.velocity.x) / 1700.0 < tx
			if trace and t2 % 15 == 0:
				print("t %d x %.0f y %.0f goal %d hp %d bats %d" % [t2, pos.x, pos.y, goal, p.hp, dove])
		release()
		report("rocks: hop across while the bats dive", p.global_position.x > 22640.0 and falls == 0 and dove > 0,
			"at x %.0f, hp %d -> %d, %d bats dove, falls %d, %.1f s" % [p.global_position.x, hp1, p.hp, dove, falls, t2 / 60.0])

	if has(args, "door"):
		var mouth: Node2D = level._mouths[0]
		report("door: the Weeping Cave by the great tree", absf(mouth.global_position.x - 22900.0) < 1.0, "at x %.0f" % mouth.global_position.x)

	print("%d scenarios, %d failed" % [runs, fails])
	get_tree().quit()
