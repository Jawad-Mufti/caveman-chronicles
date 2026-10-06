extends Node
## Test harness (not shipped): the longer caves, room by room.
## Each scenario runs on a fresh level. Args: a scenario name to run only that one.
var level: Node
var p: CaveMan
var results: Array = []

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func fresh(keep_critters: bool = false) -> void:
	if level != null:
		level.queue_free()
		await get_tree().process_frame
	GameState.reset()
	GameState.seen["level2"] = true
	GameState.learn("sunfire")          # so a cold hearth lit on the way shows no card
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	await frames(4)
	p = level.player
	p.give_torch()
	p.torch_fuel = 1.0
	p.torch_burn = 24299.0
	for c in level.get_children():
		if c is Dialogue: c.queue_free()
		if not keep_critters and (c is Critter or c is NightBeasts.Monkey or c is NightWoods.Wind):
			c.queue_free()
	for m in level._mouths:
		m._noticed = true
	await frames(3)
	p.talking = false

func put(at: Vector2, facing: int = 1) -> void:
	_hold = false
	level._move_player(at, facing)
	p.hp = 5
	p.invuln = 0.0
	p.dead = false
	await frames(6)

func report(name: String, ok: bool, note: String) -> void:
	results.append([name, ok])
	print("%-34s %s  %s" % [name, "PASS" if ok else "FAIL", note])

func release() -> void:
	p.touch["left"] = false
	p.touch["right"] = false
	p.touch["jump"] = false

func count(n: String) -> int:
	var k := 0
	for c in level.get_children():
		if n == "Spiderling" and c is CaveTrials.Spiderling: k += 1
		elif n == "StampedeRat" and c is CaveTrials.StampedeRat: k += 1
	return k


func solid_at(pos: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = pos
	q.collision_mask = 1
	return not level.get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()

## One frame of a simple runner: hold a direction, jump at an edge or a wall,
## keep the key down while rising (letting go early cuts the jump short, as it
## does for a person), and take the second jump when falling with nothing below.
var _hold := false
func bot_step(dir: int) -> void:
	p.touch["right"] = dir > 0
	p.touch["left"] = dir < 0
	var pos := p.global_position
	if _hold:
		if p.velocity.y >= -20.0 or p.is_on_floor() and p.velocity.y >= 0.0:
			_hold = false
	elif p.is_on_floor():
		var floor_ahead := solid_at(pos + Vector2(dir * 40, 6)) or solid_at(pos + Vector2(dir * 40, 26))
		var wall := solid_at(pos + Vector2(dir * 30, -18))
		if (not floor_ahead) or wall:
			_hold = true
	elif p.velocity.y > 60.0:
		var below := false
		var under := false
		var past := false
		for dy in [30.0, 70.0, 120.0, 170.0]:
			if solid_at(pos + Vector2(dir * 14, dy)):
				below = true
		for dy in [30.0, 70.0, 120.0, 170.0, 230.0, 290.0]:
			if solid_at(pos + Vector2(0, dy)):
				under = true
			if solid_at(pos + Vector2(dir * 130, dy)):
				past = true
		if not below:
			_hold = true
		# over footing that ends within stopping distance (a pillar): stop pushing and drop onto it
		if under and not past:
			p.touch["right"] = false
			p.touch["left"] = false
	p.touch["jump"] = _hold

func has(args: Array, n: String) -> bool:
	return args.is_empty() or args.has(n)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	await frames(2)

	if has(args, "hall"):
		# a runner goes through the Weeping Hall at full speed; a dawdler stands under it
		await fresh()
		await put(Vector2(35990, 700))
		p.touch["right"] = true
		await frames(int(60.0 * 450.0 / 300.0))
		release()
		report("hall: runner unhurt", p.hp == 5, "hp %d" % p.hp)
		await fresh()
		await put(Vector2(36240, 700))
		await frames(150)
		report("hall: dawdler is hit", p.hp < 5, "hp %d" % p.hp)
		await fresh()
		await put(Vector2(36430, 700), -1)
		p.touch["left"] = true
		await frames(int(60.0 * 450.0 / 300.0))
		release()
		report("hall: runner coming back unhurt", p.hp == 5, "hp %d, at x %.0f" % [p.hp, p.global_position.x])

	if has(args, "nursery"):
		await fresh()
		var sacs: Array = []
		for c in level.get_children():
			if c is CaveTrials.EggSac: sacs.append(c)
		await put(Vector2(36400, 700))
		sacs[0].take_hit(3, 1)
		await frames(40)
		report("nursery: popped from afar", count("Spiderling") == 0 and sacs[0].state == "open", "spiderlings %d" % count("Spiderling"))
		await fresh()
		await put(Vector2(36490, 700))
		p.invuln = 99.0
		await frames(90)
		var n := count("Spiderling")
		report("nursery: walking in hatches them", n >= 2, "spiderlings %d" % n)
		var killed := false
		for c in level.get_children():
			if c is CaveTrials.Spiderling:
				c.take_hit(1, 1)
				killed = c.dying > 0.0
				break
		report("nursery: a spiderling dies in one hit", killed, "")

	if has(args, "chasm"):
		# forward: from the nursery edge, onto the pillar, bounce, land on the far side
		for variant in ["far", "shelf"]:
			await fresh()
			await put(Vector2(36685, 700))
			p.touch["right"] = true
			p.touch["jump"] = true
			var bounced := false
			var stop_x := 37340.0 if variant == "far" else 37195.0
			var landed_at := Vector2.ZERO
			var released := false
			var aloft := false
			for i in 360:
				await get_tree().physics_frame
				if i == 14:
					p.touch["jump"] = true
				elif i == 3:
					p.touch["jump"] = false
				if p.velocity.y < -900.0:
					bounced = true
				if bounced and p.global_position.y < 660.0:
					aloft = true
				if bounced and p.global_position.x > stop_x and not released:
					p.touch["right"] = false
					released = true
				if aloft and p.is_on_floor():
					landed_at = p.global_position
					break
			release()
			var ok := false
			if variant == "far":
				ok = bounced and absf(landed_at.y - 700.0) < 3.0 and landed_at.x >= 37310.0 and landed_at.x <= 37650.0
			else:
				ok = bounced and absf(landed_at.y - 470.0) < 3.0 and landed_at.x >= 37130.0 and landed_at.x <= 37280.0
			report("chasm: forward, " + variant, ok, "bounced %s, landed (%.0f, %.0f), hp %d" % [bounced, landed_at.x, landed_at.y, p.hp])
		# back: from the far side, over the pillar, to the nursery, with the same runner bot
		await fresh()
		await put(Vector2(37325, 700), -1)
		var bounced2 := false
		var fell3 := false
		var tb := 0
		while tb < 900 and p.global_position.x > 36730.0:
			await get_tree().physics_frame
			tb += 1
			bot_step(-1)
			if p.velocity.y < -900.0:
				bounced2 = true
			if args.has("trace") and tb % 6 == 0:
				print("t %d  x %.0f y %.0f vy %.0f floor %s" % [tb, p.global_position.x, p.global_position.y, p.velocity.y, p.is_on_floor()])
			if p.global_position.y > 900.0:
				fell3 = true
				break
		release()
		report("chasm: back across", not fell3 and p.global_position.x <= 36730.0, "bounced %s, at (%.0f, %.0f), hp %d" % [bounced2, p.global_position.x, p.global_position.y, p.hp])

	if has(args, "stampede"):
		# a bot that jumps the nearest rat; then one that stands still
		for bot in ["hopper", "swinger", "standing"]:
			await fresh()
			await put(Vector2(39420, 600))
			var hp0 := p.hp
			var t := 0
			var mound: CaveTrials.RatMound = null
			for c in level.get_children():
				if c is CaveTrials.RatMound: mound = c
			var max_rats := 0
			while t < 60 * 16 and (mound.state != "spent" or count("StampedeRat") > 0):
				await get_tree().physics_frame
				t += 1
				if bot == "swinger":
					# stands his ground and swings whenever a rat is almost in reach
					p.touch["attack"] = false
					for c in level.get_children():
						if c is CaveTrials.StampedeRat and c.dying <= 0.0:
							var dd: float = c.global_position.x - p.global_position.x
							if dd > 0.0 and dd < 70.0:
								p.touch["attack"] = true
				if bot == "hopper":
					p.touch["jump"] = false
					for c in level.get_children():
						if c is CaveTrials.StampedeRat and c.dying <= 0.0:
							var dx: float = c.global_position.x - p.global_position.x
							if dx > -20.0 and dx < 150.0 and p.is_on_floor():
								p.touch["jump"] = true
				max_rats = maxi(max_rats, count("StampedeRat"))
				if p.dead:
					break
			release()
			var spent: bool = mound.state == "spent"
			if bot == "hopper":
				report("stampede: a hopper gets through", spent and p.hp >= 3, "hp %d/5, most rats at once %d, took %.1f s" % [p.hp, max_rats, t / 60.0])
			elif bot == "swinger":
				report("stampede: a club-swinger holds the line", spent and p.hp >= 2, "hp %d/5" % p.hp)
			else:
				report("stampede: standing still costs hp", p.hp < hp0, "hp %d/5" % p.hp)

	if has(args, "pit"):
		# onto the mound, across the ribs to the pillar, over to the far floor; and back
		for waitsnake in [true, false]:
			await fresh(true)
			for c in level.get_children():
				if c is Critter and not (c is Caves.Snake): c.queue_free()
			await frames(3)
			await put(Vector2(39730, 540))
			var snake: Caves.Snake = null
			for c in level.get_children():
				if c is Caves.Snake and absf(c.position.x - 39900.0) < 5.0: snake = c
			if waitsnake:
				var waited := 0
				while waited < 900 and not (snake.ext > 0.9):
					await get_tree().physics_frame
					waited += 1
				while waited < 1500 and not (snake.state != "strike" and snake.ext < 0.55):
					await get_tree().physics_frame
					waited += 1
			p.invuln = 0.0
			p.hp = 5
			var fell := false
			var t := 0
			while t < 900 and p.global_position.x < 40180.0:
				await get_tree().physics_frame
				t += 1
				bot_step(1)
				if args.has("trace") and t % 6 == 0:
					print("t %d  x %.0f y %.0f  snake %s %.2f  hp %d" % [t, p.global_position.x, p.global_position.y, snake.state, snake.ext, p.hp])
				if p.global_position.y > 900.0:
					fell = true
					break
			release()
			var label := "careful (waits for the strike)" if waitsnake else "rushing in"
			report("pit: " + label, not fell and p.global_position.x >= 40180.0, "at (%.0f, %.0f), hp %d, %.1f s" % [p.global_position.x, p.global_position.y, p.hp, t / 60.0])
		# and back: far floor -> pillar -> mound
		await fresh(true)
		await put(Vector2(40160, 600), -1)
		var t2 := 0
		var fell2 := false
		while t2 < 900 and p.global_position.x > 39740.0:
			await get_tree().physics_frame
			t2 += 1
			bot_step(-1)
			if p.global_position.y > 900.0:
				fell2 = true
				break
		release()
		report("pit: and back", not fell2 and p.global_position.x <= 39740.0, "at (%.0f, %.0f), hp %d" % [p.global_position.x, p.global_position.y, p.hp])

	if has(args, "rockfall"):
		# the run is meant to be READ: a straight runner is hit, one who waits for the
		# rocks to land walks through untouched, and one who keeps stopping is fine too
		for bot in ["runner", "reader"]:
			await fresh()
			await put(Vector2(39940, 510))
			var hp1 := p.hp
			var t := 0
			if bot == "runner":
				while t < 60 * 6 and p.global_position.x < 40630.0:
					await get_tree().physics_frame
					t += 1
					bot_step(1)
					if args.has("trace") and t % 6 == 0:
						var rs := ""
						for c in level.get_children():
							if c is CaveTrials.CaveRockfall:
								rs += " [%.0f y%.0f t%.2f %s]" % [c.position.x, c.position.y, c.t, c.falling]
						print("t %d x %.0f y %.0f hp %d%s" % [t, p.global_position.x, p.global_position.y, p.hp, rs])
				release()
				report("rockfall: a straight runner is hit", p.hp < hp1 and p.hp >= 3, "hp %d/5 at x %.0f" % [p.hp, p.global_position.x])
			else:
				# walks, but stops whenever an unlanded rock is within reach ahead
				while t < 60 * 14 and p.global_position.x < 40630.0:
					await get_tree().physics_frame
					t += 1
					var danger := false
					for c in level.get_children():
						if c is CaveTrials.CaveRockfall:
							var dx: float = c.position.x - p.global_position.x
							if dx > -40.0 and dx < 210.0:
								danger = true
					if danger:
						release()
					else:
						bot_step(1)
				release()
				report("rockfall: a reader is untouched", p.hp == hp1 and p.global_position.x >= 40630.0, "hp %d/5 at x %.0f, %.1f s" % [p.hp, p.global_position.x, t / 60.0])
		# and back the other way: the rocks re-arm
		await fresh()
		await put(Vector2(40630, 600), -1)
		var hp2 := p.hp
		var t3 := 0
		while t3 < 60 * 14 and p.global_position.x > 40145.0:
			await get_tree().physics_frame
			t3 += 1
			var danger2 := false
			for c in level.get_children():
				if c is CaveTrials.CaveRockfall:
					var dx2: float = p.global_position.x - c.position.x
					if dx2 > -40.0 and dx2 < 210.0:
						danger2 = true
			if danger2:
				release()
			else:
				bot_step(-1)
		release()
		report("rockfall: a reader, coming back", p.hp == hp2 and p.global_position.x <= 40145.0, "hp %d/5 at x %.0f, %.1f s" % [p.hp, p.global_position.x, t3 / 60.0])

	print("---")
	var bad := 0
	for r in results:
		if not r[1]: bad += 1
	print("%d scenarios, %d failed" % [results.size(), bad])
	get_tree().quit()
