extends Node
## Test harness (not shipped): the hanging hoards (Hoards.Hoard + GuardFly).
##   guard  - standing under the Tar Pits hoard: the dragonflies take aim and dart at him
##   swat   - a whack sends a darting dragonfly spinning down, dizzy
##   break  - for every hoard: a bot jumps and swings as the basket swings over
##            him; three whacks break it, every shell lands where he can get it,
##            and the guards flee
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

func hoards() -> Array:
	return level.get_children().filter(func(c): return c is Hoards.Hoard)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var trace := args.has("trace")
	await frames(5)
	p = level.player
	p.give_torch()
	for c in level.get_children():
		if (c is Critter and not c is OldScar) or c is NightBeasts.Monkey or c is TarPits.Snapper or c is TarPits.Geyser:
			c.queue_free()
	for m in level._mouths:
		m._noticed = true
	quiet()
	await frames(3)
	var hs := hoards()

	if has(args, "guard"):
		var h: Hoards.Hoard = hs.filter(func(x): return x.box.id == "h0")[0]
		await put(Vector2(h.box.land.x, h.box.land.y - 10.0))
		var hp0 := p.hp
		var aimed := false
		var t := 0
		while t < 480 and p.hp == hp0:
			await get_tree().physics_frame
			t += 1
			quiet()
			for f in h.flies:
				if is_instance_valid(f) and f.state == "aim":
					aimed = true
		report("guard: the dragonflies aim and dart at him", aimed and p.hp < hp0, "after %.1f s, hp %d -> %d" % [t / 60.0, hp0, p.hp])

	if has(args, "swat"):
		var h2: Hoards.Hoard = hs.filter(func(x): return x.box.id == "x0")[0]
		await put(Vector2(h2.box.land.x - 20.0, h2.box.land.y - 10.0))
		p.invuln = 99999.0
		h2.anger = 99.0            # as if he had just hit the basket
		var dizzy := false
		for i in 600:
			await get_tree().physics_frame
			quiet()
			p.touch["attack"] = false
			for f in h2.flies:
				if not is_instance_valid(f):
					continue
				var d: Vector2 = f.global_position - p.global_position
				if f.state in ["aim", "dart", "back"] and d.length() < 100.0:
					p.facing = 1 if d.x > 0.0 else -1
					p.touch["attack"] = i % 6 < 3
				if f.state == "dizzy":
					dizzy = true
			if dizzy:
				break
		release()
		p.invuln = 0.0
		report("swat: a whack sends a dragonfly spinning", dizzy, "")

	if has(args, "break"):
		for h3 in hs:
			var hd: Hoards.Hoard = h3
			var box: Treasure.Breakable = hd.box
			var id: String = box.id
			var land: Vector2 = box.land
			await put(Vector2(land.x, land.y - 10.0))
			p.invuln = 99999.0
			var t2 := 0
			var hold := 0
			var swings := 0
			while t2 < 60 * 30 and is_instance_valid(box) and box.hits > 0:
				await get_tree().physics_frame
				t2 += 1
				quiet()
				p.invuln = 99999.0
				hold -= 1
				p.touch["jump"] = hold > 0
				p.touch["attack"] = false
				var bx: Vector2 = hd.basket_centre()
				var px := p.global_position.x
				if p.is_on_floor():
					# stay under the basket's middle, and jump when it swings over him
					p.touch["left"] = px > land.x + 20.0
					p.touch["right"] = px < land.x - 20.0
					var coming := absf(bx.x - px) < 70.0
					if coming and hold <= -10:
						hold = 16
						p.touch["jump"] = true
						p.facing = 1 if bx.x > px else -1
				else:
					p.touch["left"] = false
					p.touch["right"] = false
					if absf(bx.x - px) < 90.0 and p.velocity.y > -260.0 and p.attacking <= 0.0:
						p.facing = 1 if bx.x > px else -1
						p.touch["attack"] = true
						swings += 1
				if trace and t2 % 15 == 0:
					print("%s t %d p (%.0f, %.0f) basket (%.0f, %.0f) hits %d" % [id, t2, px, p.global_position.y, bx.x, bx.y, box.hits if is_instance_valid(box) else 0])
			release()
			var broke := not is_instance_valid(box) or box.hits <= 0
			# pick it all up: wander about the spot it fell on
			for i in 300:
				await get_tree().physics_frame
				quiet()
				var px2 := p.global_position.x
				var to := land.x + sin(i / 25.0) * 40.0
				p.touch["left"] = px2 > to + 6.0
				p.touch["right"] = px2 < to - 6.0
			release()
			p.invuln = 0.0
			if trace:
				for c in level.get_children():
					if c is Treasure.Pickup and c.global_position.distance_to(land) < 600.0:
						print("   left: %s %s at (%.0f, %.0f) vel %s" % [c.kind, c.id, c.global_position.x, c.global_position.y, c.vel])
			var stuff: Array = level.STASH if id.begins_with("x") else level.HOARD
			var got := 0
			var want := 0
			for k in stuff.size():
				if Treasure.is_bone(stuff[k]):
					continue
				want += 1
				if GameState.is_taken("level2", "%s_%d" % [id, k]):
					got += 1
			var guards := hd.flies.filter(func(f): return is_instance_valid(f)).size()
			report("break %s: three whacks, the shells, the guards flee" % id, broke and got == want and guards == 0,
				"%.1f s, %d swings, %d/%d picked up, %d guards left" % [t2 / 60.0, swings, got, want, guards])

	print("%d scenarios, %d failed" % [runs, fails])
	get_tree().quit()
