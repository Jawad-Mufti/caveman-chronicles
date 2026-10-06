extends Node
## Test harness (not shipped): SUNFIRE and the Camp Menu.
##   unlock  - a cold fire teaches nothing now; the Sun Stone in the Dig teaches SUNFIRE, sun full
##   power   - Q: 30 s of it — faster run, higher jump, hits bounce off, fireballs
##             burn a beast, it ends by itself
##   charge  - hitting beasts and sitting by a fire fill the sun
##   menu    - Esc opens the camp (game paused); ABILITIES shows SUNFIRE carried,
##             TUTORIAL shows SPEAR locked; SAVE saves; closing un-pauses
##   slots   - only the two carried powers work; putting one down and back
##             in the menu; the fire ring works carried
## args: any of the above (default all)
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
		if is_instance_valid(c) and (c is Dialogue or c is ItemGet):
			c.queue_free()
	p.talking = false

func release() -> void:
	for k in ["left", "right", "jump", "attack", "throw", "sun"]:
		p.touch[k] = false

func put(at: Vector2) -> void:
	release()
	p.global_position = at
	p.velocity = Vector2.ZERO
	p.hp = 5
	p.invuln = 0.0
	await frames(6)

func has(args: Array, n: String) -> bool:
	return args.is_empty() or args.has(n)

func wolf_near(x: float) -> Critter:
	var best: Critter = null
	for c in level.get_children():
		if c is NightBeasts.Wolf and c.dying <= 0.0 and (best == null or absf(c.global_position.x - x) < absf(best.global_position.x - x)):
			best = c
	return best

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	await frames(5)
	p = level.player
	p.give_torch()
	for m in level._mouths:
		m._noticed = true
	quiet()

	if has(args, "unlock"):
		for i in 40:
			await get_tree().physics_frame
			quiet()
		# a cold fire no longer teaches it: the Sun Stone, deep in the Dig, does
		var lit_nothing := false
		level._move_player(Vector2(1640, 590), 1)
		await put(Vector2(1640, 590))
		p.touch["right"] = true
		for i in 60:
			await get_tree().physics_frame
			quiet()
		release()
		lit_nothing = not GameState.abilities.has("sunfire")
		var stone: Node2D = null
		for c in level.get_children():
			if c is Dig.SunStone:
				stone = c
		level._move_player(stone.global_position + Vector2(-60, -6), 1)
		await put(stone.global_position + Vector2(-60, -6))
		p.touch["right"] = true
		var card := false
		for i in 90:
			await get_tree().physics_frame
			card = card or level.get_children().filter(func(c): return c is ItemGet).size() > 0
			if not card:
				quiet()
		release()
		quiet()
		report("unlock: the Sun Stone teaches SUNFIRE (not a fire)", lit_nothing and GameState.abilities.has("sunfire") and p.sun_charge >= 1.0 and card,
			"learned %s, sun %.2f, card %s" % [GameState.abilities.has("sunfire"), p.sun_charge, card])

	if has(args, "power"):
		GameState.learn("sunfire")
		level._move_player(Vector2(25300, 590), 1)     # the long flat ground before the Boulder Run
		await put(Vector2(25300, 590))
		p.sun_charge = 1.0
		p.touch["sun"] = true
		await frames(2)
		p.touch["sun"] = false
		var on := p.sun_t > 29.0
		# let the slow-motion burst play out (it runs on real time), and land
		while Engine.time_scale < 1.0 or not p.is_on_floor():
			await get_tree().physics_frame
			quiet()
		# runs faster
		p.touch["right"] = true
		var vx := 0.0
		for i in 16:
			await get_tree().physics_frame
			quiet()
			vx = maxf(vx, p.velocity.x)         # top speed (there may be a rock ahead)
		if args.has("trace"):
			print("   run: at (%.0f, %.0f) v (%.0f, %.0f) floor %s wall %s talking %s knock %.2f" % [p.global_position.x, p.global_position.y, p.velocity.x, p.velocity.y, p.is_on_floor(), p.is_on_wall(), p.talking, p.knock])
		p.touch["right"] = false
		await frames(20)
		# jumps higher
		var y0 := p.global_position.y
		var top := y0
		p.touch["jump"] = true
		for i in 50:
			await get_tree().physics_frame
			top = minf(top, p.global_position.y)
		p.touch["jump"] = false
		await frames(40)
		# hits bounce off
		var hp0 := p.hp
		p.invuln = 0.0
		p.hurt(1, p.global_position.x + 30.0)
		var shrug := p.hp == hp0
		# fireballs: one tap, one more after the gap
		var w := wolf_near(p.global_position.x + 300.0)
		var whp := -1
		var wx := 0.0
		var balls := 0
		if w != null:
			w.global_position = p.global_position + Vector2(260, 0)
			w.set_physics_process(false)
			whp = w.hp
			wx = w.global_position.x
			p.facing = 1
			for i in 40:
				p.touch["throw"] = i % 10 < 4
				await get_tree().physics_frame
				balls = maxi(balls, level.get_children().filter(func(c): return c is Sunfire.Fireball).size())
			p.touch["throw"] = false
		var burned := w != null and (not is_instance_valid(w) or w.hp < whp or w.dying > 0.0)
		if args.has("trace"):
			print("   wolf %s at %.0f (he at %.0f, %.0f), hp %d -> %d" % [w != null, wx, p.global_position.x, p.global_position.y, whp, w.hp if w != null and is_instance_valid(w) else -9])
		# and it ends by itself
		p.sun_t = 0.2
		for i in 240:
			await get_tree().physics_frame
			if p.sun_t <= 0.0:
				break
		await frames(2)
		var ended := p.sun_t <= 0.0 and not p.is_in_group("glow")
		report("power: SUNFIRE — faster, higher, tough, fireballs", on and vx > 380.0 and y0 - top > 150.0 and shrug and burned and ended,
			"on %s, run %.0f px/s, jump %.0f px, shrugged %s, fireballs %d, wolf burned %s, ended %s" % [on, vx, y0 - top, shrug, balls, burned, ended])

	if has(args, "charge"):
		GameState.learn("sunfire")
		await put(Vector2(3300, 590))
		p.sun_t = 0.0
		p.sun_charge = 0.0
		var w2 := wolf_near(3400.0)
		var after_hit := 0.0
		if w2 != null:
			w2.global_position = p.global_position + Vector2(40, 0)
			w2.set_physics_process(false)
			p.facing = 1
			p.invuln = 99.0
			for i in 30:
				p.touch["attack"] = i % 10 < 3
				await get_tree().physics_frame
			release()
			after_hit = p.sun_charge
		# sit in the bonfire at 3560
		await put(Vector2(3560, 590))
		p.invuln = 99.0
		await frames(120)
		report("charge: blows and fires fill the sun", after_hit > 0.0 and p.sun_charge > after_hit + 0.3,
			"after blows %.2f, after 2 s by the fire %.2f" % [after_hit, p.sun_charge])

	if has(args, "menu"):
		GameState.learn("sunfire")
		await put(Vector2(2600, 590))
		var esc := InputEventKey.new()
		esc.physical_keycode = KEY_ESCAPE
		esc.pressed = true
		get_viewport().push_input(esc)
		await get_tree().process_frame
		await get_tree().process_frame
		var m: CampMenu = get_tree().get_first_node_in_group("camp_menu")
		var opened := m != null and get_tree().paused
		var sun_ok := false
		var spear_locked := false
		var saved := false
		if m != null:
			m._choose(2)                      # ABILITIES: his powers
			for i in Abilities.POWERS.size():
				m._pick = i
				m._show_ability()
				if Abilities.POWERS[i][0] == "sunfire":
					sun_ok = m._status.text.contains("CARRIED") and m._name.text == "SUNFIRE"
			m._go("main")
			m._choose(3)                      # TUTORIAL: the special moves
			for i in Abilities.MOVES.size():
				m._pick = i
				m._show_ability()
				if Abilities.MOVES[i][0] == "spear":
					spear_locked = m._status.text == "LOCKED"
			m._go("main")
			m._choose(0)                      # SAVE
			saved = m._saved_t >= 0.0 and FileAccess.file_exists(GameState.PATH)
			m._close()
		await get_tree().process_frame
		report("menu: camp, abilities, save, and back", opened and sun_ok and spear_locked and saved and not get_tree().paused,
			"opened %s, sunfire shown %s, spear locked %s, saved %s, paused after %s" % [opened, sun_ok, spear_locked, saved, get_tree().paused])

	if has(args, "slots"):
		# only the two carried powers work; the menu swaps them
		GameState.learn("sunfire")
		await put(Vector2(2600, 590))
		quiet()
		var both := Abilities.slots(p) == ["sunfire", "firering"]
		var bar_on: bool = level.hud._bar.visible
		quiet()
		Abilities.toggle("sunfire", p)          # put SUNFIRE down
		p.sun_charge = 1.0
		p.touch["sun"] = true
		await frames(2)
		p.touch["sun"] = false
		await frames(2)
		var blocked := p.sun_t <= 0.0
		Abilities.toggle("sunfire", p)          # and carry it again
		var back := Abilities.slots(p).has("sunfire")
		quiet()
		p.touch["sun"] = true
		await frames(2)
		p.touch["sun"] = false
		var works := p.sun_t > 0.0
		p.end_sunfire()
		# the fire ring, carried, with wood
		p.wood = 2
		p.touch["fire"] = true
		await frames(2)
		p.touch["fire"] = false
		var ring := p.fury >= 0.0
		report("slots: two carried powers, swapped in the menu", both and bar_on and blocked and back and works and ring,
			"both %s, circles %s, down-blocked %s, carried again %s, works %s, fire ring %s" % [both, bar_on, blocked, back, works, ring])

	print("%d scenarios, %d failed" % [runs, fails])
	get_tree().quit()
