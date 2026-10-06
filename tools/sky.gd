extends Node
## Test harness (not shipped): flies each sky lane with a bot that plays like
## a person — walks to an edge and jumps (holding the key while rising), steers
## over the next stone in the air, takes the second jump only when it would
## fall short, and lets the blooms do their work.
## args: lane index (0, 1, 2), "margin=N" (take off N px before the edge),
##       "critters" (leave the creatures in), "trace"
var level: Node
var p: CaveMan
var _hold := false
var _airjumped := false

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _ready() -> void:
	_run.call_deferred()

func predict_land(top: float) -> float:
	# seconds until his feet come down through `top`, or INF
	var y := p.global_position.y
	var vy := p.velocity.y
	var t := 0.0
	if y > top and vy >= 0.0:
		return INF
	while t < 3.0:
		vy += (CaveMan.GRAVITY_UP if vy < 0.0 else CaveMan.GRAVITY_DOWN) / 60.0
		y += vy / 60.0
		t += 1.0 / 60.0
		if vy > 0.0 and y >= top:
			return t
	return INF

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var lane_i := 0
	var margin := 0.0
	for a in args:
		if a.is_valid_int(): lane_i = int(a)
		if a.begins_with("margin="): margin = float(a.split("=")[1])
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	await frames(4)
	p = level.player
	p.give_torch()
	p.torch_burn = 24299.0
	for c in level.get_children():
		if c is Dialogue: c.queue_free()
		if not args.has("critters") and (c is Critter or c is NightBeasts.Monkey):
			c.queue_free()
	await frames(3)
	p.talking = false
	level._snuffed = true
	level._panicked = true
	var lane: Dictionary = level.SKY_LANES[lane_i]
	var pad: Array = lane["pad"]
	var rocks: Array = lane["rocks"]
	level._move_player(Vector2(float(pad[0]) - 150.0, float(pad[1])), 1)
	p.hp = 5
	await frames(10)
	var value0: int = GameState.found_value("level2")
	var goal := 0
	var t := 0
	var falls := 0
	var hp_lost := 0
	var last_hp := p.hp
	var done := false
	var w_under := 0
	var w_leaps := 0
	var w_was := {}
	var w_states := {}
	while t < 60 * 60 and not done:
		await get_tree().physics_frame
		t += 1
		if args.has("wolfwatch"):
			# wolves: leaps at him, and time spent right under him while he is high up
			for c in level.get_children():
				if c is NightBeasts.Wolf and c.dying <= 0.0:
					if p.global_position.y < c.floor_y - 105.0 and absf(c.global_position.x - p.global_position.x) < 90.0:
						w_under += 1
						w_states[c.state] = int(w_states.get(c.state, 0)) + 1
					var lg: bool = c.state == "lunge"
					if lg and not w_was.get(c, false):
						w_leaps += 1
					w_was[c] = lg
		if p.talking:
			for c in level.get_children():
				if c is Dialogue: c.queue_free()
			p.talking = false
		if p.hp < last_hp:
			hp_lost += last_hp - p.hp
		last_hp = p.hp
		var pos := p.global_position
		if pos.y > 900.0:
			falls += 1
		# where is he standing?
		var cur := -2
		if p.is_on_floor():
			_airjumped = false
			if absf(pos.y - 600.0) < 3.0 or absf(pos.y - float(pad[1])) < 3.0:
				cur = -1
			for j in rocks.size():
				var r: Array = rocks[j]
				if absf(pos.y - float(r[1])) < 3.0 and pos.x >= float(r[0]) - 14.0 and pos.x <= float(r[0]) + float(r[2]) + 14.0:
					cur = j
			if cur == -1 and goal > 0:
				falls += 1
				break       # fell back to the ground: lane failed from here
			if cur >= goal:
				goal = cur + 1
				if goal >= rocks.size():
					done = true
					break
		var g: Array = rocks[goal]
		var gx0: float = g[0]
		var gx1: float = gx0 + float(g[2])
		var gtop: float = g[1]
		var cx := (gx0 + gx1) * 0.5
		var dir := 0
		var jump := _hold
		if _hold and p.velocity.y >= -20.0:
			_hold = false
			jump = false
		if p.is_on_floor() and not _hold:
			if cur == -1:
				dir = 1 if pos.x < float(pad[0]) else 0
			elif cur >= 0 and (int(rocks[cur][3]) & 1) != 0:
				var px := float(rocks[cur][0]) + float(rocks[cur][2]) * 0.5
				dir = 1 if pos.x < px - 4.0 else (-1 if pos.x > px + 4.0 else 0)
			elif cur >= 0:
				var r2: Array = rocks[cur]
				dir = 1 if cx > pos.x else -1
				var edge: float = float(r2[0]) + float(r2[2]) if dir > 0 else float(r2[0])
				if (edge - pos.x) * dir <= margin + 6.0:
					_hold = true
					jump = true
		elif not p.is_on_floor():
			dir = 0
			if absf(cx - pos.x) > 10.0:
				dir = 1 if cx > pos.x else -1
			var tl := predict_land(gtop)
			var reach := 300.0 * tl
			var short := tl == INF or (dir > 0 and pos.x + reach < gx0 + 12.0) or (dir < 0 and pos.x - reach > gx1 - 12.0)
			if short and not _airjumped and p.velocity.y > 30.0 and not _hold:
				_hold = true
				_airjumped = true
				jump = true
				if p.touch["jump"]:
					jump = false   # let go for a frame, so the press registers
					_hold = false
					_airjumped = false
		p.touch["right"] = dir > 0
		p.touch["left"] = dir < 0
		p.touch["jump"] = jump
		if args.has("trace") and t % 10 == 0:
			print("t %d x %.0f y %.0f vy %.0f floor %s cur %d goal %d" % [t, pos.x, pos.y, p.velocity.y, p.is_on_floor(), cur, goal])
	p.touch["right"] = false
	p.touch["left"] = false
	p.touch["jump"] = false
	if args.has("wolfwatch"):
		print("wolves: %d leaps, %.1f s spent right under him while he was up high %s" % [w_leaps, w_under / 60.0, w_states])
	var got: int = GameState.found_value("level2") - value0
	print("lane %d %-14s margin %2.0f  %s  reached rock %d/%d  falls %d  hp lost %d  shells %d  %.1f s" % [lane_i, lane["name"], margin,
		"PASS" if done and falls == 0 else "FAIL", goal, rocks.size(), falls, hp_lost, got, t / 60.0])
	# the cache: break it and see where its treasure lands
	if done:
		var cache: SkyLanes.SkyCache = null
		for c in level.get_children():
			if c is SkyLanes.SkyCache and c.id == "sc%d" % lane_i: cache = c
		var top: float = cache.global_position.y
		var ncont: int = cache.contents.size()
		cache.take_hit(3, 1)
		await frames(30)
		cache.take_hit(3, 1)
		await frames(200)
		var on_rock := 0
		var below := 0
		for c in level.get_children():
			if c is Treasure.Pickup and c.id.begins_with("sc%d_" % lane_i):
				if absf(c.global_position.y - (top - 12.0)) < 8.0: on_rock += 1
				else: below += 1
		var taken := 0
		for i in ncont:
			if GameState.is_taken("level2", "sc%d_%d" % [lane_i, i]): taken += 1
		print("   cache: %d pieces on the rock (or already picked up: %d), %d elsewhere" % [on_rock, taken, below])
	get_tree().quit()
