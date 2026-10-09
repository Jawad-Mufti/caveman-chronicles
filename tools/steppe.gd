extends Node
## Test harness (not shipped): the Mammoth Steppe. Plays each challenge like a
## person would and reports PASS/FAIL.
##   chimney  - climbs the split rock wall to wall, onto the clifftop
##   nokick   - a plain wall (the mountain) gives no wall jump
##   herd     - standing in the herd's path gets him stomped; a back is safe and carries him
##   river    - too wide to jump; the current throws him back (1 heart)
##   ferry    - waits for the old bull, rides him across, hops off on the far bank
## args: any of the above (default: all), "trace"
var level: Node
var p: CaveMan
var fails := 0
var runs := 0

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
	print("%-40s %s  %s" % [label, "PASS" if ok else "FAIL", info])

func release() -> void:
	for k in ["left", "right", "jump"]:
		p.touch[k] = false

func put(at: Vector2) -> void:
	release()
	p.global_position = at
	p.velocity = Vector2.ZERO
	p.hp = 5
	p.invuln = 0.0
	p.knock = 0.0
	p.talking = false
	await frames(6)

func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	p.talking = false

func has(args: Array, n: String) -> bool:
	return args.is_empty() or args.has(n) or (args.size() == 1 and args[0] == "trace")

func mammoths() -> Array:
	var out := []
	for c in level.get_children():
		if c is Steppe.Mammoth:
			out.append(c)
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

	if has(args, "chimney"):
		# walk in under the slab, then: jump, and every time he meets a wall,
		# a fresh press; between kicks, steer toward the wall ahead
		await put(Vector2(12380, 590))
		p.touch["right"] = true
		var t := 0
		var kicks := 0
		var held := 0
		var top := 600.0
		while t < 900:
			await get_tree().physics_frame
			t += 1
			quiet()
			top = minf(top, p.global_position.y)
			if p.is_on_floor() and p.global_position.y < 120.0:
				break
			if p.is_on_floor() and p.global_position.x > 12540.0:
				p.touch["jump"] = true          # at the foot of the cliff: up
				held = 0
			elif held > 0:
				held -= 1
				if held == 0:
					p.touch["jump"] = false
			elif p._wall_t > 0.0 and p.velocity.y > -150.0 and not (p._wall_dir > 0 and p.global_position.y < CLIFF_TOP() + 30.0):
				# (right at the top of the cliff face: no kick back out — push on over the edge)
				p.touch["jump"] = true          # a fresh press off the wall
				held = 12
				kicks += 1
			# steer toward the wall he is flying at (after the lock, this makes him cling)
			var to_right := p.velocity.x > 20.0 or (absf(p.velocity.x) <= 20.0 and p.facing > 0)
			if p.global_position.y < CLIFF_TOP() - 5.0:
				to_right = true                  # over the top: onto the clifftop
			p.touch["right"] = to_right
			p.touch["left"] = not to_right
			if args.has("trace") and t % 6 == 0:
				print("t %d x %.0f y %.0f vy %.0f wall %.2f kicks %d" % [t, p.global_position.x, p.global_position.y, p.velocity.y, p._wall_t, kicks])
		release()
		p.touch["right"] = true          # a few steps in from the edge
		await frames(15)
		release()
		await frames(5)
		var g := p.global_position
		report("chimney: wall to wall, onto the clifftop", p.is_on_floor() and g.y < 120.0 and g.x > 12600.0, "at (%.0f, %.0f), %d kicks, %.1f s" % [g.x, g.y, kicks, t / 60.0])

	if has(args, "nokick"):
		# the mountain's first step is a plain wall: jumping at it and pressing again
		# gives only the air jump, never a kick
		await put(Vector2(5640, 590))
		p.touch["right"] = true
		p.touch["jump"] = true
		var kicked := false
		for i in 50:
			await get_tree().physics_frame
			if i == 14:
				p.touch["jump"] = false
			if i == 16:
				p.touch["jump"] = true
			if p._kick_lock > 0.0:
				kicked = true
		release()
		report("nokick: a plain wall gives no wall jump", not kicked, "")

	if has(args, "herd"):
		# stand in the herd's path: the feet find him
		var ms := mammoths()
		await put(Vector2(13400, 590))
		var hp0 := p.hp
		for i in 480:
			await get_tree().physics_frame
			quiet()
			p.global_position.x = 13400.0     # stubbornly stays put
			if p.hp < hp0:
				break
		report("herd: standing in the way gets him stomped", p.hp < hp0, "hp %d/5" % p.hp)
		# on the bull's back: carried, and safe
		var bull: Steppe.Mammoth = ms[0]
		await put(bull.global_position + Vector2(0, -bull.BACK * bull.size - 30.0))
		for i in 30:                     # (dropped on from above: measure from when he has landed)
			if p.is_on_floor():
				break
			await get_tree().physics_frame
		var x_rel0 := p.global_position.x - bull.global_position.x
		var bx := bull.global_position.x
		var moved := 0.0
		var hp1 := p.hp
		for i in 240:
			await get_tree().physics_frame
			quiet()
			moved += absf(bull.global_position.x - bx)
			bx = bull.global_position.x
		var drift := absf((p.global_position.x - bull.global_position.x) - x_rel0)
		report("herd: riding a back is safe, and carries him", p.hp == hp1 and p.is_on_floor() and drift < 12.0 and moved > 60.0,
			"hp %d/5, bull moved %.0f, he slid %.0f on its back" % [p.hp, moved, drift])

	if has(args, "river"):
		# a full running double jump from the bank falls short of the far side
		await put(Vector2(13500, 590))
		for m in mammoths():
			m.process_mode = Node.PROCESS_MODE_DISABLED   # out of the way
		p.touch["right"] = true
		var t2 := 0
		var swept := false
		var hp2 := p.hp
		var pressed := 0
		while t2 < 300:
			await get_tree().physics_frame
			t2 += 1
			quiet()
			if pressed == 0 and p.global_position.x > 13780.0:
				p.touch["jump"] = true
				pressed = 1
			elif pressed == 1 and p.velocity.y > -60.0:
				p.touch["jump"] = false
				pressed = 2
			elif pressed == 2:
				p.touch["jump"] = true
				pressed = 3
			if p.hp < hp2 and p.global_position.x < 13800.0:
				swept = true
				break
			if p.is_on_floor() and p.global_position.x > 14300.0:
				break
		release()
		for m in mammoths():
			m.process_mode = Node.PROCESS_MODE_INHERIT
		report("river: too wide to jump; thrown back", swept, "at (%.0f, %.0f), hp %d/5" % [p.global_position.x, p.global_position.y, p.hp])

	if has(args, "ferry"):
		var bull2: Steppe.Mammoth = null
		for m in mammoths():
			if m.global_position.y > 640.0:
				bull2 = m
		await put(Vector2(13770, 590))
		# wait for him at the near bank
		var w := 0
		while w < 1200 and not (bull2.global_position.x <= bull2.x0 + 2.0 and bull2._pause > 0.5):
			await get_tree().physics_frame
			w += 1
			quiet()
		# hop on
		p.touch["right"] = true
		p.touch["jump"] = true
		var t3 := 0
		var on := false
		while t3 < 90:
			await get_tree().physics_frame
			t3 += 1
			if p.global_position.x > bull2.global_position.x - 50.0:
				p.touch["right"] = false
			if t3 > 10 and p.is_on_floor():
				on = true
				break
		p.touch["jump"] = false
		# ride to the far bank, then hop off to the right
		var ride := 0
		var hp3 := p.hp
		while ride < 1200 and not (bull2.global_position.x >= bull2.x1 - 2.0):
			await get_tree().physics_frame
			ride += 1
			quiet()
		await frames(10)
		p.touch["right"] = true
		p.touch["jump"] = true
		var t4 := 0
		while t4 < 120:
			await get_tree().physics_frame
			t4 += 1
			if t4 > 10 and p.is_on_floor():
				break
		release()
		await frames(5)
		var g2 := p.global_position
		report("ferry: rides the old bull across", on and g2.x > 14300.0 and absf(g2.y - 600.0) < 3.0 and p.hp == hp3,
			"got on %s, landed (%.0f, %.0f), hp %d/5, waited %.1f s, rode %.1f s" % [on, g2.x, g2.y, p.hp, w / 60.0, ride / 60.0])

	print("%d scenarios, %d failed" % [runs, fails])
	get_tree().quit()

func CLIFF_TOP() -> float:
	return 100.0
