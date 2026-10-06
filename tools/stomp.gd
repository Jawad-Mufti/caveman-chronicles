extends Node
## Test harness (not shipped): the METEOR STOMP and the stomp spots.
##   ground  - T on the ground does nothing
##   crack   - jump, T: spin, drop, STOMP — the cracked slab breaks and its shells come out
##   seal    - a plain stomp bounces off a rune seal (CLANG); a double jump + T breaks it
##   beast   - the blast knocks a wolf next to the landing
##   tough   - nothing hurts him while he drops
## args: any of the above (default all), "trace"
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
	level._move_player(at, 1)
	p.velocity = Vector2.ZERO
	p.hp = 5
	p.invuln = 0.0
	await frames(8)

func has(args: Array, n: String) -> bool:
	return args.is_empty() or args.has(n)

func spot(i: int) -> Stomp.Spot:
	for c in level.get_children():
		if c is Stomp.Spot and c.id == "g%d" % i:
			return c
	return null

## Jump (twice, for a mega), press T near the top, and wait for the landing.
## Returns [level it stomped at, the top of the jump, frames].
func stomp(double: bool) -> Array:
	for i in 120:
		if p.is_on_floor() and i > 4:
			break
		await frames(1)
	p.touch["jump"] = true
	var t := 0
	var pressed := false
	var jumped2 := not double
	var top := p.global_position.y
	var lvl := 0
	var was := ""
	while t < 240:
		await frames(1)
		t += 1
		top = minf(top, p.global_position.y)
		if not jumped2 and p.velocity.y > -150.0 and not p.is_on_floor():
			# the second jump: let go, press again
			p.touch["jump"] = false
			await frames(1)
			p.touch["jump"] = true
			jumped2 = true
			continue
		if jumped2 and not pressed and p.velocity.y > -120.0 and not p.is_on_floor():
			p.touch["stomp"] = true
			pressed = true
			continue
		if pressed:
			p.touch["stomp"] = false
			if p.stomp_state != "":
				lvl = p.stomp_level
			if was == "dive" and p.stomp_state == "":
				break
			was = p.stomp_state
	release()
	return [lvl, top, t]

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	p = level.player
	await frames(5)
	p.give_torch()
	for m in level._mouths:
		m._noticed = true
	quiet()

	if has(args, "ground"):
		await put(Vector2(900, 590))
		p.touch["stomp"] = true
		await frames(4)
		release()
		report("ground: T on the ground does nothing", p.stomp_state == "", "state '%s'" % p.stomp_state)

	if has(args, "crack"):
		var s := spot(0)
		await put(Vector2(s.global_position.x, 590))
		var r := await stomp(false)
		var broke := s.broken
		# walk about the hole to pick it all up
		for goal in [s.global_position.x - 90.0, s.global_position.x + 90.0, s.global_position.x]:
			for i in 90:
				var dx: float = goal - p.global_position.x
				p.touch["right"] = dx > 6.0
				p.touch["left"] = dx < -6.0
				await frames(1)
				if absf(dx) <= 6.0:
					break
		if args.has("trace"):
			for c in level.get_children():
				if c is Treasure.Pickup and absf(c.global_position.x - s.global_position.x) < 400.0:
					print("     left: %s %s at (%.0f, %.0f) vel %s; he is at %.0f" % [c.kind, c.id, c.global_position.x, c.global_position.y, c.vel, p.global_position.x])
		release()
		var got := 0
		for k in s.contents.size():
			if GameState.is_taken("level2", "g0_%d" % k):
				got += 1
		report("crack: STOMP breaks the slab, shells come out", r[0] == 1 and broke and got == s.contents.size(),
			"stomp level %d, broke %s, picked up %d/%d, %.1f s" % [r[0], broke, got, s.contents.size(), r[2] / 60.0])

	if has(args, "seal"):
		var s2 := spot(2)
		for c in level.get_children():
			if c is Critter and not c is OldScar and absf(c.global_position.x - s2.global_position.x) < 1200.0:
				c.queue_free()           # just him and the seal
		await put(Vector2(s2.global_position.x, 590))
		var r1 := await stomp(false)
		var held: bool = not s2.broken
		await frames(40)
		while not p.is_on_floor():
			await frames(1)
		await frames(10)
		var r2 := await stomp(true)
		report("seal: plain stomp CLANGs, MEGA stomp breaks it", r1[0] == 1 and held and r2[0] == 2 and s2.broken,
			"first level %d held %s, then level %d broke %s" % [r1[0], held, r2[0], s2.broken])

	if has(args, "beast"):
		await put(Vector2(3500, 590))
		var w: Critter = null
		for c in level.get_children():
			if c is NightBeasts.Wolf and c.dying <= 0.0:
				w = c
				break
		var ok := false
		var info := "no wolf"
		if w != null:
			w.set_physics_process(false)
			w.global_position = p.global_position + Vector2(70, 0)
			var hp0 := w.hp
			p.invuln = 99.0
			await stomp(false)
			await frames(2)
			ok = not is_instance_valid(w) or w.hp < hp0 or w.dying > 0.0
			info = "wolf hp %d -> %d" % [hp0, w.hp if is_instance_valid(w) else -1]
		report("beast: the blast knocks a wolf beside him", ok, info)

	if has(args, "tough"):
		await put(Vector2(900, 590))
		p.touch["jump"] = true
		var hurt_in_dive := false
		var pressed := false
		for i in 120:
			await frames(1)
			if not pressed and p.velocity.y > -120.0 and not p.is_on_floor():
				p.touch["stomp"] = true
				pressed = true
			elif pressed:
				p.touch["stomp"] = false
			if p.stomp_state == "dive":
				var hp0 := p.hp
				p.invuln = 0.0
				p.hurt(1, p.global_position.x + 20.0)
				hurt_in_dive = hurt_in_dive or p.hp < hp0
			if pressed and p.stomp_state == "" and p.is_on_floor():
				break
		release()
		report("tough: nothing hurts him while he drops", pressed and not hurt_in_dive, "")

	print("%d scenarios, %d failed" % [runs, fails])
	get_tree().quit()
