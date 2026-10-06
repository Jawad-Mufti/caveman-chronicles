extends Node
## Test harness (not shipped): fights Old Scar with a simple policy.
var level: Node
var p: CaveMan
var fire := false
var smart := OS.get_cmdline_user_args().has("smart")
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "fire":
			fire = true
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue or c is Shop:
			c.queue_free()
	p.talking = false
func _run() -> void:
	for i in 5: await get_tree().physics_frame
	p = level.player
	quiet()
	p.give_torch()
	p.hammer = fire
	level._snuffed = true
	level._panicked = true
	level._met_toolmaker = true
	p.global_position = Vector2(32600, 590)
	var sc: OldScar = level.scar
	var states := {}
	var roars := 0
	sc.roared.connect(func() -> void: roars += 1)
	var hp_lost := 0
	var hp_prev := p.hp
	var frames := 0
	var deaths := 0
	var phase_seen := 1
	var waves_seen := {}
	var last_state := ""
	var last_hp := 0
	var last_near := ""
	while frames < 60 * 200 and not level._scar_beaten:
		await get_tree().physics_frame
		frames += 1
		quiet()
		if p.dead:
			if OS.get_cmdline_user_args().has("why"):
				print("  just before death: scar %s, man hp %d at (%d,%d) invuln %.2f, knock %.2f | %s" % [last_state, last_hp, p.global_position.x, p.global_position.y, p.invuln, p.knock, last_near])
			deaths += 1
			if OS.get_cmdline_user_args().has("why"):
				print("  DIED at %.1f s: man (%d, %d), scar %s at (%d, %d), hp was %d" % [frames / 60.0, p.global_position.x, p.global_position.y, sc.state, sc.global_position.x, sc.global_position.y, hp_prev])
			p.revive(Vector2(32600, 590))
			await get_tree().physics_frame
			if not level._fight:
				p.global_position = Vector2(32600, 590)
		if p.hp < hp_prev:
			hp_lost += hp_prev - p.hp
		if p.hp < hp_prev and OS.get_cmdline_user_args().has("why"):
			print("  hurt at %.1f s by %s (phase %d) | torch %.2f | man x %d, scar x %d y %d | lit bowls %d" % [frames / 60.0, sc.state, sc.phase, p.torch_fuel,
				p.global_position.x, sc.global_position.x, sc.global_position.y,
				level.get_children().filter(func(c): return c is NightWoods.Brazier and c.lit and c.global_position.x > 32300.0).size()])
		hp_prev = p.hp  # hurt_by
		last_state = sc.state
		last_hp = p.hp
		var near_list := []
		for c in level._wave:
			if is_instance_valid(c) and absf(c.global_position.x - p.global_position.x) < 160.0:
				near_list.append("%s %s d%d" % ["wolf" if c is NightBeasts.Wolf else "bat", c.state, absf(c.global_position.x - p.global_position.x)])
		last_near = str(near_list)
		states[sc.state] = true
		phase_seen = maxi(phase_seen, sc.phase)
		if OS.get_cmdline_user_args().has("trace") and sc.phase >= 2 and frames % 20 == 0 and frames > 60 * 8 and frames < 60 * 30:
			print("t%.1f %s scar(%d,%d) floor %d hp %d | man(%d,%d) torch %.2f face %d" % [frames / 60.0, sc.state, sc.global_position.x, sc.global_position.y, sc.cur_floor, sc.hp, p.global_position.x, p.global_position.y, p.torch_fuel, p.facing])
		# relight at a bowl when the torch is out (walk to the nearer one)
		p.touch["left"] = false
		p.touch["right"] = false
		p.touch["attack"] = false
		p.touch["jump"] = false
		var dx := sc.global_position.x - p.global_position.x
		if p.torch_fuel < 0.5 and not p.hammer and sc.state not in ["cower", "dazed"]:
			var bowl := 32420.0 if p.global_position.x < 32840.0 else 33260.0
			var lit_bowls := level.get_children().filter(func(c): return c is NightWoods.Brazier and c.lit and c.global_position.x > 32300.0)
			if lit_bowls.size() > 0:
				lit_bowls.sort_custom(func(a, b): return absf(a.global_position.x - p.global_position.x) < absf(b.global_position.x - p.global_position.x))
				bowl = lit_bowls[0].global_position.x
			p.touch["left" if bowl < p.global_position.x else "right"] = true
			continue
		# the siege: fight the wolves and bats he calls, nearest first
		var foes: Array = level._wave.filter(func(c): return is_instance_valid(c) and c.dying <= 0.0)
		if level._wave_n >= 1 and level._wave_n <= 3 and not foes.is_empty():
			waves_seen[level._wave_n] = true
			foes.sort_custom(func(a, b): return absf(a.global_position.x - p.global_position.x) < absf(b.global_position.x - p.global_position.x))
			var foe: Node2D = foes[0]
			var fdx := foe.global_position.x - p.global_position.x
			p.facing = 1 if fdx > 0.0 else -1
			var high := foe.global_position.y < p.global_position.y - 95.0
			if absf(fdx) > 55.0:
				p.touch["right" if fdx > 0.0 else "left"] = true
			var near := foes.filter(func(c): return absf(c.global_position.x - p.global_position.x) < 330.0 and c.global_position.y > p.global_position.y - 90.0).size()
			if p.hammer and p.slam_cd <= 0.0 and (near >= 2 or p.slam_charge >= 0.0):
				# a smart player with the hammer: FIRE SLAM the pack
				p.touch["left"] = false
				p.touch["right"] = false
				p.touch["attack"] = p.slam_charge < p._charge_ready()
				continue
			if absf(fdx) < 95.0:
				p.touch["attack"] = frames % 6 < 3
				if high:
					p.touch["jump"] = frames % 40 < 8
			continue
		# face him; strike when he's open
		p.facing = 1 if dx > 0.0 else -1
		var open := sc.state in ["cower", "dazed", "distracted", "flinch"]
		if open and sc.timer < 0.3 and sc.state != "distracted":
			# the opening is about to end: step back out of his reach
			p.touch["left" if dx > 0.0 else "right"] = true
		elif sc.state == "swipe" and absf(dx) < 200.0:
			# the paw is up: get away from it
			p.touch["left" if dx > 0.0 else "right"] = true
		elif open:
			if absf(dx) > 70.0 and p.slam_charge < 0.0:
				p.touch["right" if dx > 0.0 else "left"] = true
			var close := absf(dx) < 110.0 and absf(sc.global_position.y - p.global_position.y) < 90.0
			# a smart player with the club saves a long opening for a HOME RUN
			var long_open := sc.state == "dazed" and sc.timer > 0.9
			if smart and not p.hammer and close and (long_open or p.slam_charge >= 0.0):
				p.touch["attack"] = p.slam_charge < p._charge_ready()
			elif close:
				p.touch["attack"] = frames % 6 < 3
		elif sc.state == "charge" and absf(dx) < 260.0:
			p.touch["jump"] = true
	print("%s: beaten %s in %d s | hp lost %d, deaths %d | phase %d, scar hp left %d | siege waves fought %s\n   moves seen: %s" % [
		"FIRE CLUB" if fire else "plain club", level._scar_beaten, frames / 60, hp_lost, deaths, phase_seen, sc.hp, waves_seen.keys(), states.keys()])
	# the fang and the ending
	for c in level.get_children():
		if c is Caves.KeyItem and not c.gone:
			for k in 60:
				await get_tree().physics_frame
			p.global_position = c.global_position + Vector2(0, -6)
	for k in 30:
		await get_tree().physics_frame
	var talk := level.get_children().filter(func(c): return c is Dialogue)
	print("fang taken: %s, dawn talk showing: %s" % ["sabre_fang" in GameState.trophies, talk.size() > 0])
	for d in talk:
		while is_instance_valid(d) and d._i < d.lines.size():
			d._next()
	for k in 10:
		await get_tree().physics_frame
	var scroll := level.get_children().filter(func(c): return c is LevelEnd)
	if scroll.size() > 0:
		var lines := []
		for l in scroll[0].lines:
			lines.append("%s: %s" % [l[0], l[1]])
		print("scroll: ", " | ".join(lines))
	get_tree().quit()
