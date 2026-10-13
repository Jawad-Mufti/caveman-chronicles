extends Node2D
## AMBUSHES: stretches of the level where, the moment he walks in, beasts burst
## out at him — wolves running in from the trees, skeletons rattling up out of
## the ground, rats pouring from holes, bats dropping from the dark. They come
## in a staggered rush (and then take TURNS: Critter.may_attack), and when the
## last is beaten: "AMBUSH CLEARED!" and a burst of Spirit Orbs. Every visit.
## Placed from AMBUSHES in level2_data.gd. Loaded with preload (no class_name).

var x0 := 0.0
var x1 := 0.0
var floor_y := 600.0
var kinds: Array = []
var line := ""
var terrain: Terrain = null        ## inside the mountain: snap to its floors
## ESCALATION: the further into the level, the harder (1..5, from how far along
## it is: `tier_at`). Higher tiers bring more beasts, more WAVES, and ELITES.
var tier := 1
var _fired := false
var _spawned: Array = []
var _queue: Array = []
var _waves: Array = []
var _wave := 0
var _next := 0.0
var _done := false
var _pending := 0                  ## beasts still on their way down from the roof


static func tier_at(x: float, level_w: float) -> int:
	return clampi(1 + int(x / level_w * 5.0), 1, 5)


## The waves for this tier: the first is the table's beasts (one more from
## tier 2); a second wave from tier 3, bigger again at 4; a third at 5.
func _plan() -> Array:
	var out: Array = []
	var w1: Array = kinds.duplicate()
	if tier >= 2:
		w1.append(kinds[0])
	out.append(w1)
	if tier >= 3:
		var w2: Array = kinds.duplicate()
		w2.append(kinds[randi() % kinds.size()])
		if tier >= 4:
			w2.append(kinds[0])
		out.append(w2)
	if tier >= 5:
		var w3: Array = kinds.duplicate()
		w3.append_array(kinds.slice(0, 2))
		out.append(w3)
	return out


func _elite_chance() -> float:
	return [0.0, 0.0, 0.15, 0.3, 0.5][tier - 1]


func _process(delta: float) -> void:
	if _done:
		return
	var p := get_tree().get_first_node_in_group("player") as CaveMan
	if p == null or p.dead:
		return
	if not _fired:
		var at := p.global_position
		if at.x > x0 and at.x < x1 and absf(at.y - floor_y) < 150.0 and not p.talking:
			_fire(p)
		return
	# the rush comes in one after another, not all in the same instant
	if not _queue.is_empty():
		_next -= delta
		if _next <= 0.0:
			_next = maxf(0.3, 0.6 - tier * 0.06)
			_spawn(_queue.pop_front(), p)
		return
	if _pending > 0:
		return
	for c in _spawned:
		if is_instance_valid(c) and (c as Critter).dying <= 0.0:
			return
	if _wave + 1 < _waves.size():
		# the next wave, after a breath
		_wave += 1
		_queue = (_waves[_wave] as Array).duplicate()
		_next = 1.4
		_pop("WAVE %d!" % (_wave + 1), Color("ff9a3a"), p, 34)
		return
	_cleared(p)


func _pop(text: String, col: Color, p: CaveMan, size: int) -> void:
	var w := CaveMan.WordPop.new()
	w.text = text
	w.size = size
	w.color = col
	w.star = Color("2a0a0a", 0.85)
	w.centered = true
	w.life = 1.2
	w.position = p.global_position + Vector2(0, -170)
	get_parent().add_child(w)


func _fire(p: CaveMan) -> void:
	_fired = true
	_waves = _plan()
	_wave = 0
	_queue = (_waves[0] as Array).duplicate()
	_next = 0.6
	if tier >= 3:
		line += "   (DANGER %d: %d waves)" % [tier, _waves.size()]
	var w := CaveMan.WordPop.new()
	w.text = "AMBUSH!" if tier < 4 else ("BIG AMBUSH!" if tier == 4 else "HUGE AMBUSH!!")
	w.size = 40
	w.color = Color("ff6a3a")
	w.star = Color("2a0a0a", 0.85)
	w.centered = true
	w.life = 1.2
	w.position = p.global_position + Vector2(0, -170)
	get_parent().add_child(w)
	var lvl := get_parent()
	if line != "" and "hud" in lvl and lvl.hud != null:
		lvl.hud.say(line, 3.5)
	if lvl.has_method("shake"):
		lvl.shake(5.0, 0.3)


func _floor_at(x: float) -> float:
	if terrain != null:
		var g := terrain.ground_y(x, floor_y - 80.0)
		if g < INF:
			return g
	return floor_y


## Each one arrives its own way.
func _spawn(kind: String, p: CaveMan) -> void:
	var side := -1.0 if _spawned.size() % 2 == 0 else 1.0
	var view := LevelBase.view_half(self).x
	var c: Critter = null
	match kind:
		"wolf":
			# running in from the trees, off the edge of the view
			var wolf := NightBeasts.Wolf.new()
			wolf.left_x = x0 - 60.0
			wolf.right_x = x1 + 60.0
			var x := clampf(p.global_position.x + side * (view + 40.0), wolf.left_x, wolf.right_x)
			wolf.position = Vector2(x, _floor_at(x))
			wolf.state = "stalk"
			c = wolf
		"skeleton":
			# rattling up out of the ground, not far from him
			var sk := Mountain.RisenSkeleton.new()
			sk.terrain = terrain
			sk.left_x = x0 - 100.0
			sk.right_x = x1 + 100.0
			var xs := clampf(p.global_position.x + side * randf_range(170.0, 260.0), sk.left_x, sk.right_x)
			sk.position = Vector2(xs, _floor_at(xs))
			c = sk
		"rat":
			# out of a hole in the ground beside him
			var rat := Caves.Rat.new()
			rat.left_x = x0
			rat.right_x = x1
			var xr := clampf(p.global_position.x + side * randf_range(200.0, 320.0), x0, x1)
			rat.position = Vector2(xr, _floor_at(xr))
			FX.burst(get_parent(), rat.position, "dust", -side)
			c = rat
		"bat":
			# dropping out of the dark above
			var bat := NightBeasts.Bat.new()
			var xb := p.global_position.x + side * randf_range(140.0, 240.0)
			bat.ground_y = _floor_at(xb)
			bat.position = Vector2(xb, bat.ground_y - 260.0)
			c = bat
		"skel_drop", "spider_drop":
			# from the ROOF: a crack, a tell... and down it comes, close to him
			var xd := clampf(p.global_position.x + side * randf_range(60.0, 190.0), x0, x1)
			var g := _floor_at(xd)
			var rf := terrain.roof_y(xd, g - 40.0) if terrain != null else -INF
			if rf == -INF or g - rf > 520.0 or g - rf < 110.0:
				rf = g - 320.0
			var d := RoofDrop.new()
			d.kind = kind
			d.position = Vector2(xd, rf)
			d.roof = rf
			d.ground = g
			d.terrain = terrain
			d.left_x = x0 - 100.0
			d.right_x = x1 + 100.0
			d.on_land = _dropped
			_pending += 1
			get_parent().add_child(d)
			return
	if c == null:
		return
	get_parent().add_child(c)
	_spawned.append(c)
	if randf() < _elite_chance():
		c.make_elite()
		c.tell("ELITE!", Color("ff5a3a"))


## A beast from the roof is down: counted like the rest.
func _dropped(c: Critter) -> void:
	_pending = maxi(_pending - 1, 0)
	_spawned.append(c)
	if randf() < _elite_chance():
		c.make_elite()
		c.tell("ELITE!", Color("ff5a3a"))


func _cleared(p: CaveMan) -> void:
	_done = true
	if _spawned.is_empty():
		return
	var w := CaveMan.WordPop.new()
	w.text = "AMBUSH CLEARED!"
	w.size = 32
	w.color = Color("ffe066")
	w.star = Color("c0392b", 0.85)
	w.centered = true
	w.life = 1.4
	w.position = p.global_position + Vector2(0, -170)
	get_parent().add_child(w)
	# a reward: a big burst of Spirit Orbs streaming in
	var orbs := Critter.ORBS.new()
	orbs.count = 6 + 3 * _spawned.size() + 5 * tier         # deeper, bigger: a bigger reward
	orbs.target = p
	orbs.origin = p.global_position + Vector2(0, -140)
	get_parent().add_child(orbs)


## FROM THE ROOF (inside the mountain): a beast comes down on him from above.
## First the TELL (TELL s): the roof cracks, dust trickles and pebbles patter
## down, eyes glint in the crack, a ring marks the floor where it will land.
## Then the roof BURSTS (stone chips, a shake) and it falls: a skeleton as a
## tumbling heap of bones that lands with a CRASH and rattles up; a spider
## dropping on its silk.
class RoofDrop extends Node2D:
	const TELL := 0.8
	const GRAVITY := 1500.0
	var kind := "skel_drop"
	var roof := 0.0                ## world y of the roof here
	var ground := 0.0              ## world y of the floor here
	var terrain: Terrain = null
	var left_x := 0.0
	var right_x := 0.0
	var on_land: Callable          ## (beast: Critter) -> void: the ambush counts it
	var t := 0.0
	var _y := 0.0                  ## the falling heap (skeleton), world y
	var _vy := 0.0
	var _spin := 0.0
	var _burst := false
	var _pebbles: Array = []       ## [x offset, y, vy]

	func _ready() -> void:
		add_to_group("glow")
		z_index = 2
		global_position = Vector2(global_position.x, roof)
		_y = roof

	func _process(delta: float) -> void:
		t += delta
		# pebbles pattering down from the crack through the tell
		if not _burst and randf() < delta * 14.0:
			_pebbles.append([randf_range(-14.0, 14.0), 0.0, randf_range(0.0, 80.0)])
		for pb in _pebbles:
			pb[2] += GRAVITY * 0.7 * delta
			pb[1] += float(pb[2]) * delta
		_pebbles = _pebbles.filter(func(pb): return float(pb[1]) < ground - roof)
		if not _burst and t >= TELL:
			_open()
		if _burst and kind == "skel_drop":
			_vy += GRAVITY * delta
			_y += _vy * delta
			_spin += delta * 9.0
			if _y >= ground:
				_land()
				return
		if _burst and kind != "skel_drop" and _pebbles.is_empty() and t > TELL + 1.2:
			queue_free()
		queue_redraw()

	## The roof bursts open.
	func _open() -> void:
		_burst = true
		var lvl := get_parent()
		FX.shards(lvl, Vector2(global_position.x, roof + 6.0), Vector2.DOWN, true)
		FX.burst(lvl, Vector2(global_position.x, roof + 10.0), "dust")
		if lvl.has_method("shake"):
			lvl.shake(4.0, 0.2)
		if kind == "spider_drop":
			var sp := Caves.Spider.new()
			sp.position = Vector2(global_position.x, ground)
			sp.roof_y = roof - 60.0                 # it starts just under the roof, its silk up into the crack
			sp.left_x = left_x
			sp.right_x = right_x
			sp.state = "drop"
			lvl.add_child(sp)
			sp.tell("!", Color("ff9a3a"))
			on_land.call(sp)

	## The heap of bones hits the floor: CRASH, and it rattles up.
	func _land() -> void:
		var lvl := get_parent()
		var x := global_position.x
		FX.burst(lvl, Vector2(x, ground), "dust", -1.0)
		FX.burst(lvl, Vector2(x, ground), "dust", 1.0)
		FX.shards(lvl, Vector2(x, ground - 4.0), Vector2.UP, false)
		if lvl.has_method("shake"):
			lvl.shake(7.0, 0.25)
		var w := CaveMan.WordPop.new()
		w.text = "CRASH!"
		w.size = 30
		w.color = Color("e8dcc0")
		w.star = Color("2a0a0a", 0.85)
		w.centered = true
		w.life = 0.9
		w.position = Vector2(x, ground - 110.0)
		lvl.add_child(w)
		var sk := Mountain.RisenSkeleton.new()
		sk.terrain = terrain
		sk.left_x = left_x
		sk.right_x = right_x
		sk.position = Vector2(x, ground)
		sk.state = "rise"                       # straight up out of the heap it landed in
		lvl.add_child(sk)
		on_land.call(sk)
		queue_free()

	func _draw() -> void:
		var k := clampf(t / TELL, 0.0, 1.0)
		var rock := Color("3a2c22")
		# the crack spreading across the roof
		if not _burst:
			var reach := 12.0 + 46.0 * k
			for a in [-1.0, 1.0]:
				var pts := PackedVector2Array([Vector2.ZERO])
				for s in 4:
					var q := float(s + 1) / 4.0
					pts.append(Vector2(a * reach * q, 3.0 + sin(q * 9.0 + a) * 4.0 * q))
				draw_polyline(pts, Color("b9a58a", 0.7), 5.5)      # the broken edge catching the light
				draw_polyline(pts, rock.darkened(0.5), 3.0)
			# the hole opening in the middle, dark
			draw_circle(Vector2(0, 3), 7.0 + 9.0 * k, Color("b9a58a", 0.6))
			draw_circle(Vector2(0, 3), 5.0 + 8.0 * k, Color("120c0a"))
		else:
			draw_circle(Vector2(0, 4), 14.0, Color("120c0a"))
		# a trickle of dust out of the crack
		if not _burst:
			for i in 6:
				var q := fmod(t * 1.8 + i * 0.17, 1.0)
				draw_circle(Vector2(sin(i * 2.1) * 6.0, 8.0 + q * 120.0), 2.2 - q * 1.2, Color(0.8, 0.72, 0.6, 0.55 * (1.0 - q)))
		for pb in _pebbles:
			draw_circle(Vector2(float(pb[0]), float(pb[1])), 2.6, Color("8a7a68"))
		# the falling heap of bones, tumbling
		if _burst and kind == "skel_drop":
			draw_set_transform(Vector2(0, _y - roof), _spin, Vector2.ONE)
			var bone := Color("e3d8bc")
			# two long bones crossed behind the skull, knobbed at both ends
			for b in [[Vector2(-24, -18), Vector2(24, 18)], [Vector2(-24, 18), Vector2(24, -18)]]:
				var a: Vector2 = b[0]
				var e: Vector2 = b[1]
				draw_line(a, e, bone.darkened(0.35), 8.0)
				draw_line(a, e, bone, 5.0)
				var n := (e - a).normalized().orthogonal() * 3.5
				for q in [a, e]:
					draw_circle(q + n, 4.5, bone.darkened(0.3))
					draw_circle(q - n, 4.5, bone.darkened(0.3))
					draw_circle(q + n, 3.4, bone)
					draw_circle(q - n, 3.4, bone)
			# the skull: a dome, a jaw, dark sockets
			draw_circle(Vector2(0, -3), 13.0, bone.darkened(0.3))
			draw_circle(Vector2(0, -3), 11.5, bone)
			draw_rect(Rect2(-6.5, 6, 13, 7), bone.darkened(0.1))
			draw_circle(Vector2(-4.5, -3), 3.6, Color("1a1410"))
			draw_circle(Vector2(4.5, -3), 3.6, Color("1a1410"))
			draw_circle(Vector2(0, 4), 1.6, Color("1a1410"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## Eyes glinting in the crack; the warning ring on the floor below.
	func draw_glow(g) -> void:
		var c := global_position
		if not _burst:
			var k := clampf(t / TELL, 0.0, 1.0)
			var eye := Color("7dffcf") if kind == "skel_drop" else Pal.EMBER_GLOW
			if k > 0.3:
				for s in [-1.0, 1.0]:
					g.draw_circle(c + Vector2(s * 4.0, 4.0), 2.2, Color(eye, minf(1.0, (k - 0.3) * 3.0)))
			var pulse := 0.5 + 0.5 * sin(t * 18.0)
			var r := 34.0 - 14.0 * k
			var pts := PackedVector2Array()
			for i in 17:
				var a := TAU * i / 16.0
				pts.append(Vector2(c.x + cos(a) * r, ground - 2.0 + sin(a) * r * 0.25))
			for i in 16:
				g.draw_line(pts[i], pts[i + 1], Color(1.0, 0.45, 0.2, (0.35 + 0.4 * pulse) * k), 2.0)
		elif kind == "skel_drop":
			for s in [-4.5, 4.5]:
				g.draw_circle(Vector2(c.x, _y) + Vector2(s, -3.0).rotated(_spin), 2.0, Color("7dffcf"))      # its eyes, lit in the sockets
