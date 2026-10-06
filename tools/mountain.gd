extends Node
## Test harness (not shipped): the mountain (a Terrain) can be travelled.
## A waypoint bot walks, hops walls and gaps, and double-jumps when it must.
##   climb   - outside: the foot, over the summit (across the root mat), down to the ground
##   inside  - crevice floor -> Echo Tunnel -> Crystal Grotto -> Bone Hall -> up the shaft, out on the summit
##   paint   - from the grotto down into the Painted Cave
##   hollow  - in at the east foot, into the Glow Hollow
##   rooms   - each room's title card shows once
##   dark    - inside it is dark; no wind in there
## args: any of the above (default all), trace
var level: Node
var p: CaveMan
var _hold := 0
var _armed := false

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	p.talking = false
	p.torch_fuel = 1.0
	p.hp = 5

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		quiet()

func release() -> void:
	for k in p.touch.keys():
		p.touch[k] = false

func put(at: Vector2) -> void:
	release()
	level._move_player(at + Vector2(0, -4), 1)
	p.velocity = Vector2.ZERO
	p.invuln = 9999.0
	await frames(10)

func has(args: Array, n: String) -> bool:
	var named := ["climb", "inside", "paint", "hollow", "east", "rooms", "dark", "dig"]
	for a in args:
		if a in named:
			return args.has(n)
	return true

func report(name: String, ok: bool, info: String) -> void:
	print("%-52s %s  %s" % [name, "PASS" if ok else "FAIL", info])

func solid_at(at: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = at
	q.collision_mask = 1
	return not level.get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()

## Walk/jump to `to`; true once standing within reach of it.
func go(to: Vector2, limit := 600) -> bool:
	_hold = 0
	_armed = false
	var trace := OS.get_cmdline_user_args().has("trace")
	for i in limit:
		await get_tree().physics_frame
		quiet()
		var pos := p.global_position
		var dx := to.x - pos.x
		if absf(dx) < 26.0 and absf(to.y - pos.y) < 50.0 and p.is_on_floor():
			release()
			return true
		var dir := 0.0 if absf(dx) < 10.0 else signf(dx)
		p.touch["right"] = dir > 0.0
		p.touch["left"] = dir < 0.0
		if _hold > 0:
			_hold -= 1
			p.touch["jump"] = _hold > 0
		elif p.is_on_floor():
			_armed = false
			var wall := dir != 0.0 and (solid_at(pos + Vector2(dir * 24.0, -24.0)) or solid_at(pos + Vector2(dir * 24.0, -56.0)))
			var gap := dir != 0.0 and not solid_at(pos + Vector2(dir * 26.0, 12.0)) and not solid_at(pos + Vector2(dir * 26.0, 60.0))
			var up := to.y < pos.y - 40.0 and absf(dx) < 230.0
			if wall or (gap and to.y < pos.y + 30.0) or up:
				_hold = 20
				_armed = true
				p.touch["jump"] = true
		elif _armed and p.velocity.y > -80.0:
			var wall2 := dir != 0.0 and (solid_at(pos + Vector2(dir * 24.0, -24.0)) or solid_at(pos + Vector2(dir * 24.0, 8.0)))
			if wall2 or to.y < pos.y - 30.0:
				_armed = false
				_hold = 16
				p.touch["jump"] = true
		if trace and i % 15 == 0:
			print("    -> (%.0f, %.0f)  at (%.0f, %.0f) vy %.0f floor %s" % [to.x, to.y, pos.x, pos.y, p.velocity.y, p.is_on_floor()])
	release()
	return false

## Follow the waypoints; returns how many were reached in a row.
func route(pts: Array) -> int:
	var n := 0
	for w in pts:
		if not await go(w):
			print("    stuck going to %s, at (%.0f, %.0f)" % [str(w), p.global_position.x, p.global_position.y])
			return n
		n += 1
	return n

## Up THE CHIMNEY by wall kicks: a fresh press each time he meets a wall, steering
## toward the wall ahead; over the top, up through the root mat onto the summit.
func chimney(exit_y := -280.0) -> bool:
	var held := 0
	var t := 0
	p.touch["jump"] = p.velocity.y > -300.0     # (already flying up, from a glowcap: no press, or letting go would cut it)
	while t < 900:
		await get_tree().physics_frame
		quiet()
		t += 1
		var pos := p.global_position
		if p.is_on_floor() and pos.y < exit_y + 30.0:
			release()
			return true
		if held > 0:
			held -= 1
			if held == 0:
				p.touch["jump"] = false
		elif p.is_on_floor():
			p.touch["jump"] = true
			held = 12
		elif p._wall_t > 0.0 and p.velocity.y > -150.0:
			p.touch["jump"] = true
			held = 12
		var to_right := p.velocity.x > 20.0 or (absf(p.velocity.x) <= 20.0 and p.facing > 0)
		if pos.y < exit_y - 20.0:
			to_right = true                  # out on top: onto the summit
		p.touch["right"] = to_right
		p.touch["left"] = not to_right
		if OS.get_cmdline_user_args().has("trace") and t % 8 == 0:
			print("    chimney t %d (%.0f, %.0f) vy %.0f wall %.2f" % [t, pos.x, pos.y, p.velocity.y, p._wall_t])
	release()
	return false

func blow(down: bool) -> void:
	p.touch["down"] = down
	p.touch["attack"] = true
	await frames(2)
	p.touch["attack"] = false
	await frames(26)
	p.touch["down"] = false

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	p = level.player
	await frames(5)
	p.give_torch()

	if has(args, "climb"):
		await put(Vector2(5700, 540))
		var pts := [Vector2(5800, 480), Vector2(5960, 413), Vector2(6200, 280), Vector2(6390, 150), Vector2(6560, 70),
			Vector2(6760, -40), Vector2(7080, -160), Vector2(7300, -270), Vector2(7500, -280),
			Vector2(7800, -160), Vector2(8000, -40), Vector2(8140, 80), Vector2(8400, 160), Vector2(8800, 160), Vector2(9020, 40),
			Vector2(9180, -80), Vector2(9340, -200), Vector2(9500, -320), Vector2(9700, -440), Vector2(10000, -440), Vector2(10220, -320),
			Vector2(10380, -200), Vector2(10640, -80), Vector2(10800, 40), Vector2(11060, 160), Vector2(11260, 280), Vector2(11560, 400),
			Vector2(11720, 480), Vector2(12150, 600)]
		var n := await route(pts)
		report("climb: over the mountain, outside", n == pts.size(), "%d of %d waypoints" % [n, pts.size()])

	if has(args, "inside"):
		await put(Vector2(5960, 717))
		var pts2 := [Vector2(6060, 755), Vector2(6200, 780), Vector2(6400, 800), Vector2(6600, 766), Vector2(6800, 720),
			Vector2(7000, 640), Vector2(7340, 593)]
		var n2 := await route(pts2)
		var top := await chimney()
		report("inside: tunnel, grotto, hall, up the Chimney", n2 == pts2.size() and top, "%d of %d waypoints, out on top %s (%.0f, %.0f)" % [n2, pts2.size(), top, p.global_position.x, p.global_position.y])

	if has(args, "paint"):
		await put(Vector2(6400, 800))
		var pts3 := [Vector2(6500, 880), Vector2(6650, 922), Vector2(6880, 1000), Vector2(6650, 922), Vector2(6400, 800)]
		var n3 := await route(pts3)
		report("paint: down to the Painted Cave and back", n3 == pts3.size(), "%d of %d waypoints" % [n3, pts3.size()])

	if has(args, "hollow"):
		await put(Vector2(12150, 600))
		var pts4 := [Vector2(11980, 635), Vector2(11800, 671), Vector2(11560, 680), Vector2(11400, 680)]
		var n4 := await route(pts4)
		report("hollow: in from the east foot", n4 == pts4.size(), "%d of %d waypoints" % [n4, pts4.size()])

	if has(args, "east"):
		# into the saddle's cave mouth, down to the Great Cavern, east to the Bat Roost, up the Eagle Shaft
		await put(Vector2(8420, 160))
		var pts5 := [Vector2(8560, 840), Vector2(8800, 791), Vector2(9000, 720), Vector2(9200, 640), Vector2(9400, 488), Vector2(9600, 511), Vector2(9740, 530)]
		var n5 := await route(pts5)
		# onto the glowcap under the shaft: it bounces him up into it
		release()
		p.global_position = Vector2(9820, 420)
		p.velocity = Vector2.ZERO
		var bounced := false
		for i in 90:
			await frames(1)
			if p.velocity.y < -800.0:
				bounced = true
				break
		print("    glowcap bounce: ", bounced)
		var top2 := bounced and await chimney(-440.0)
		report("east: saddle mouth, Great Cavern, Bat Roost, up the Eagle Shaft", n5 == pts5.size() and top2, "%d of %d waypoints, on the High Peak %s (%.0f, %.0f)" % [n5, pts5.size(), top2, p.global_position.x, p.global_position.y])

	if has(args, "rooms"):
		level._mt_seen.clear()
		for spot in [Vector2(6420, 800), Vector2(7000, 640), Vector2(6880, 1000), Vector2(11500, 680), Vector2(7340, 593),
				Vector2(8600, 830), Vector2(8520, 1080), Vector2(9500, 505), Vector2(9820, 280)]:
			await put(spot)
			await frames(5)
		print("    rooms seen: ", level._mt_seen.keys())
		report("rooms: each room is announced", level._mt_seen.size() == level.MT_ROOMS.size(), "seen %d of %d" % [level._mt_seen.size(), level.MT_ROOMS.size()])

	if has(args, "dark"):
		await put(Vector2(6200, 280))
		await frames(120)
		var outside: float = level.night.ambient
		await put(Vector2(7000, 640))
		await frames(120)
		var inside: float = level.night.ambient
		var wind := 0.0
		for i in 400:
			await frames(1)
			wind = maxf(wind, absf(p.wind))
		report("dark: dark inside, and no wind in there", inside > outside + 0.15 and wind == 0.0, "ambient out %.2f in %.2f, wind inside %.0f" % [outside, inside, wind])
	if has(args, "dig"):
		# down through the shelf, then sideways; a buried find pops out; and how long a blow takes
		var t: Terrain = level.mountain
		await put(Vector2(6800, -40))
		var y0 := p.global_position.y
		for i in 8:
			await blow(true)
		var down := p.global_position.y - y0
		var x0 := p.global_position.x
		p.facing = 1
		for i in 10:
			await blow(false)
			p.touch["right"] = true
			await frames(12)
			release()
		var side := p.global_position.x - x0
		# a find buried right under him
		var l := (p.global_position + Vector2(0, 26) - t.position) / Terrain.CELL
		var idx := (floori(l.y) + 1) * t._w + floori(l.x)
		t.loot[idx] = ["conch", "mtest"]
		var before := GameState.is_taken("level2", "mtest")
		for i in 4:
			await blow(true)
		await frames(60)
		var popped := not t.loot.has(idx)
		var worst := 0
		var timed := 0
		var tx := 6500.0
		while timed < 6 and tx < 11500.0:
			tx += 97.0
			var at := Vector2(tx, 300.0)
			if not t.is_solid(at):
				continue
			for k in 3:           # the third blow breaks even grey stone: a rebuild
				var u := Time.get_ticks_usec()
				t.dig_at(at)
				worst = maxi(worst, Time.get_ticks_usec() - u)
			timed += 1
		report("dig: down, sideways, a buried find, fast enough", down > 150.0 and side > 120.0 and popped and not before and worst < 28300,
			"down %.0f px, sideways %.0f px, find out %s, worst blow %.1f ms" % [down, side, popped, worst / 1000.0])
	get_tree().quit()
