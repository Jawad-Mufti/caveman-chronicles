extends Node
## Test harness (not shipped): THE SOAK. A bot plays Level 2 end to end the way
## a kid does: runs right, jumps, mashes HIT, swaps hotbar slots, throws,
## stomps, fights whatever comes. Every frame it checks for things that should
## never happen (stuck states, slow-motion that never ends, a lost axe, falling
## out of the world, runaway nodes) and prints each kind ONCE with where it was.
##   from=<x> to=<x>   the stretch to play (default the whole level)
##   seed=<n>          the bot's dice
## Ends with one SOAK line: problems found, stuck spots, deaths, worst frames.
var level: Node
var p: CaveMan
var rng := RandomNumberGenerator.new()
var from_x := 200.0
var to_x := 33400.0
var problems := {}
var stuck_spots: Array = []
var deaths := 0
var worst: Array = []          ## [ms, x, what] — the slowest script frames
var t := {}                    ## how long each watched state has lasted (s)
var slow_since := -1
var nodes0 := 0
var _last_us := 0
var _frame_n := 0
var _prev_att := 0.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("from="): from_x = float(a.substr(5))
		elif a.begins_with("to="): to_x = float(a.substr(3))
		elif a.begins_with("seed="): rng.seed = int(a.substr(5))
	GameState.reset()
	GameState.seen["level2"] = true
	GameState.weapons.append("axe")
	GameState.give_item("shovel")
	GameState.learn("sunfire")
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func problem(kind: String, info: String = "") -> void:
	if problems.has(kind):
		problems[kind] += 1
		return
	problems[kind] = 1
	print("PROBLEM %-28s at x %.0f y %.0f  %s" % [kind, p.global_position.x, p.global_position.y, info])

func lasted(key: String, on: bool, limit: float, info: String = "") -> void:
	t[key] = (float(t.get(key, 0.0)) + 1.0 / 60.0) if on else 0.0
	if float(t[key]) > limit:
		problem(key, info)
		t[key] = -1000.0                    # (once per stretch)

func ground_below(x: float) -> float:
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, -1400), Vector2(x, 2600), 1)
	var hit: Dictionary = level.get_world_2d().direct_space_state.intersect_ray(q)
	return float(hit.position.y) if hit else 590.0

func watch() -> void:
	var now_us := Time.get_ticks_usec()
	var ms := (now_us - _last_us) / 1000.0       # the whole frame, wall clock (headless: scripts + physics)
	_last_us = now_us
	_frame_n += 1
	var pos := p.global_position
	if _frame_n >= 60:                           # (timed every frame, dead or alive)
		if ms > 500.0:
			problem("freeze (a frame over 0.5 s)", "%.0f ms, time_scale %.2f" % [ms, Engine.time_scale])
		worst.append([ms, pos.x, "nodes %d" % get_tree().get_node_count()])
		if worst.size() > 40:
			worst.sort_custom(func(a, b): return a[0] > b[0])
			worst.resize(8)
	if not pos.is_finite() or absf(pos.x) > 1e6 or absf(pos.y) > 1e6:
		problem("position not finite", str(pos))
	if p.velocity.length() > 4000.0:
		problem("velocity runaway", "%.0f px/s" % p.velocity.length())
	if p.carrying != null and not is_instance_valid(p.carrying):
		problem("carrying a freed beast")
	if Critter._attackers.size() > Critter.MAX_ATTACKERS:
		problem("too many attackers", str(Critter._attackers.size()))
	if Engine.time_scale < 0.99:
		if slow_since < 0:
			slow_since = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - slow_since > 3000:
			problem("slow-motion never ends", "time_scale %.2f" % Engine.time_scale)
			slow_since = Time.get_ticks_msec()
	else:
		slow_since = -1
	if p.dead:
		lasted("dead too long", true, 8.0)
		return
	t["dead too long"] = 0.0
	lasted("charge stuck", p.slam_charge >= 0.0, 4.0, "slam_charge %.1f" % p.slam_charge)
	lasted("swing stuck", p.attacking > 0.0 and p.attacking >= _prev_att, 0.75, "%s %.2f" % [p._swing_kind, p.attacking])
	_prev_att = p.attacking
	lasted("axe never came back", p.axe_out, 6.0)
	lasted("knock-back stuck", p.knock > 0.0, 3.0)
	lasted("stomp stuck", p.stomp_state != "", 4.0, p.stomp_state)
	lasted("get-up stuck", p.getup >= 0.0, 5.0)
	lasted("climbing stuck", p.climbing, 8.0)
	lasted("throwing stuck", p.throwing > 0.0, 3.0)
	var below := pos.y > float(level.fall_y) + 400.0
	lasted("fell out of the world", below, 3.0, "fall_y %.0f" % level.fall_y)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		for c in level.get_children():
			if c is Dialogue:
				c.queue_free()
		p.talking = false
		if p.dead:
			pass
		elif p.hp <= 1:
			p.hp = p.max_hp                 # a kid would eat a fig; keep the run going
		watch()

func release() -> void:
	for k in p.touch.keys():
		p.touch[k] = false
	p.touch["down"] = false

## One beat of play: mostly running right with jumps and HIT, now and then
## something else a kid would press.
func beat() -> void:
	var r := rng.randf()
	release()
	p.touch["right"] = true
	if r < 0.30:
		p.touch["jump"] = true
		await frames(rng.randi_range(6, 24))
		p.touch["jump"] = false
		await frames(4)
		if rng.randf() < 0.5:
			p.touch["jump"] = true            # the double jump
			await frames(14)
	elif r < 0.55:
		for i in rng.randi_range(2, 6):     # mash HIT (the combos)
			p.touch["attack"] = true
			await frames(2)
			p.touch["attack"] = false
			await frames(rng.randi_range(4, 14))
	elif r < 0.62:
		p.touch["attack"] = true             # hold HIT (auto-swing / the axe throw)
		await frames(rng.randi_range(20, 70))
	elif r < 0.68:
		p.touch["special"] = true            # a charged special
		await frames(rng.randi_range(30, 75))
	elif r < 0.73:
		p.select_slot(rng.randi_range(0, p.hotbar().size() - 1))
		await frames(2)
	elif r < 0.78:
		p.touch["up"] = true                 # aim up (and climb into rock)
		p.touch["attack"] = rng.randf() < 0.5
		await frames(rng.randi_range(10, 40))
	elif r < 0.82:
		p.touch["down"] = true               # DOWN + HIT (dig) or a stomp in the air
		p.touch["attack"] = true
		await frames(rng.randi_range(4, 20))
	elif r < 0.85:
		p.touch["jump"] = true
		await frames(18)
		p.touch["jump"] = false
		p.touch["throw"] = true              # T-ish: the throw key, mid-air
		await frames(3)
	elif r < 0.88:
		p.touch["left"] = true               # turn around to fight what's behind
		p.touch["right"] = false
		for i in 4:
			p.touch["attack"] = true
			await frames(2)
			p.touch["attack"] = false
			await frames(8)
	else:
		await frames(rng.randi_range(10, 30))
	release()

func _run() -> void:
	p = level.player
	await frames(5)
	p.pick_up_stick()
	nodes0 = get_tree().get_node_count()
	var x := from_x
	level._move_player(Vector2(x, ground_below(x) - 40.0), 1)
	await frames(30)
	var best := x
	var since_best := 0
	var mark := x
	var t0 := Time.get_ticks_msec()
	var was_dead := false
	while p.global_position.x < to_x and Time.get_ticks_msec() - t0 < 1500000:
		await beat()
		if p.dead and not was_dead:
			deaths += 1
		was_dead = p.dead
		var px := p.global_position.x
		if px > best + 30.0:
			best = px
			since_best = 0
		else:
			since_best += 1
		if px > mark + 1000.0:
			mark = px
			print("... x %.0f  nodes %d  critters %d  orbs %d" % [px, get_tree().get_node_count(),
				get_tree().get_nodes_in_group("critters").size(), GameState.orbs])
		if since_best > 40 and not p.dead:
			# no progress for a while: note the spot and hop past it
			stuck_spots.append(int(best))
			var nx := best + 300.0
			level._move_player(Vector2(nx, ground_below(nx) - 40.0), 1)
			await frames(20)
			best = p.global_position.x
			since_best = 0
	release()
	await frames(120)
	worst.sort_custom(func(a, b): return a[0] > b[0])
	var w := []
	for i in mini(5, worst.size()):
		w.append("%.1f ms @%d (%s)" % [worst[i][0], int(worst[i][1]), worst[i][2]])
	print("worst script frames: %s" % ", ".join(w))
	print("stuck spots (hopped): %s" % str(stuck_spots))
	print("SOAK %s  problems %d kinds %s, deaths %d, nodes %d -> %d, reached x %.0f" % [
		"PASS" if problems.is_empty() else "FAIL", problems.size(), str(problems), deaths, nodes0,
		get_tree().get_node_count(), p.global_position.x])
	get_tree().quit()
