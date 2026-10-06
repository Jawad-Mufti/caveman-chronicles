## Thunder Canyon: the deep canyon between the Tar Pits (Nutmeg's creek) and
## the great tree.
##   Sky Stones   flying rocks with vines hanging from them — drifting, bobbing,
##                or circling — all keeping one rhythm, so each swings close to
##                the next just when he wants to jump (they never touch)
##   (a rest ledge with a fire)
##   Floating rocks at different heights to hop across — and once he's on his
##   way, bats screech, dive and swoop across at him (pairs, later)
class_name Canyon
extends RefCounted


## ================================================================ CARRY VINE
class CarryVine extends NightWoods.Vine:
	## A vine hanging from something that moves. Its carrier writes how fast it
	## is going into `carry`; letting go, he keeps that speed too (CaveMan._swing).
	var carry := Vector2.ZERO

	func _ready() -> void:
		super._ready()
		# a wider catch than a still vine's: these are moving targets
		var cs := _grab.get_child(0) as CollisionShape2D
		(cs.shape as CircleShape2D).radius = 70.0

	func _draw() -> void:
		var bt := Batch.new()
		var end := Vector2(sin(angle), cos(angle)) * length
		var pts := PackedVector2Array()
		for i in 11:
			var k := i / 10.0
			pts.append(end * k + Vector2(sin(k * PI) * 5.0 * (1.0 - absf(angle)), 0))
		bt.polyline(pts, Pal.VINE.darkened(0.2), 5.0)
		bt.polyline(pts, Pal.VINE, 3.0)
		for i in range(2, 10, 3):
			var p: Vector2 = pts[i]
			bt.poly(PackedVector2Array([p, p + Vector2(9, -4), p + Vector2(12, 2), p + Vector2(3, 4)]), Pal.CANOPY.lightened(0.15))
		bt.circle(end, 6.0, Pal.VINE.darkened(0.3), 10)
		bt.draw(self)


## ================================================================ SKY STONE
class SkyStone extends Node2D:
	## A flying rock with a vine hanging from it. Each one is a little world:
	## a mossy top with a tiny tree, a crystal or a ring of standing stones,
	## roots trailing underneath, a trickle of water falling off its lip, and
	## runes that glow faintly in the dark.
	## It moves in its own space only:
	##   "drift"  side to side       "bob"  up and down
	##   "orbit"  round in a loop, carrying the vine round with it
	## All the stones share one beat (period) so their closest moments come in a
	## wave along the line; `beat` is where in the beat this one starts.
	var kind := "drift"
	var amp := 60.0
	var period := 6.0
	var beat := 0.0              ## radians at t = 0
	var vine_len := 200.0
	var look := 0                ## which little world is on top
	var vine: CarryVine
	var _home := Vector2.ZERO
	var _t := 0.0
	var _drops: Array = []
	var _body := PackedVector2Array()

	func _ready() -> void:
		_home = position
		position = _home + _offset(0.0)
		vine = CarryVine.new()
		vine.length = vine_len
		vine.position = Vector2(0, 34)
		add_child(vine)
		add_to_group("glow")
		for i in 4:
			_drops.append(randf())
		# the body, painted like the mountain (common/art): rock, a band of earth, the grass cap
		var rng := RandomNumberGenerator.new()
		rng.seed = int(_home.x)
		_body = PackedVector2Array([Vector2(-52, -10), Vector2(52, -10)])
		for k in range(8, -1, -1):
			var q := k / 8.0
			var d := 34.0 * (1.0 - pow(absf(q - 0.5) * 2.0, 1.4)) * rng.randf_range(0.8, 1.0)
			_body.append(Vector2(-52.0 + 104.0 * q, -6.0 + d))
		var band := PackedVector2Array([Vector2(-52, -10), Vector2(52, -10)])
		for k in range(8, -1, -1):
			var q2 := k / 8.0
			band.append(Vector2(-52.0 + 104.0 * q2, -8.0 + 12.0 * (1.0 - pow(absf(q2 - 0.5) * 2.0, 1.6))))
		Terrain.paint_poly(self, _body, Terrain.ROCK_TEX, Terrain.NIGHT_ROCK.lightened(0.2), _home)
		Terrain.paint_poly(self, band, Terrain.EARTH_TEX, Terrain.NIGHT_EARTH, _home)
		Terrain.paint_poly(self, PackedVector2Array([Vector2(-56, -15), Vector2(56, -15), Vector2(54, -7), Vector2(20, -5), Vector2(-20, -6), Vector2(-54, -7)]),
			Terrain.GRASS_TEX, Terrain.NIGHT_GRASS.lightened(0.12), _home)

	func _offset(t: float) -> Vector2:
		var a := TAU * t / period + beat
		match kind:
			"bob":
				return Vector2(0, sin(a) * amp)
			"orbit":
				return Vector2(cos(a), sin(a)) * amp
		return Vector2(sin(a) * amp, sin(a * 2.0) * 5.0)

	func _physics_process(delta: float) -> void:
		_t += delta
		var before := global_position
		position = _home + _offset(_t)
		vine.carry = (global_position - before) / maxf(delta, 0.0001)
		for i in _drops.size():
			_drops[i] = fmod(float(_drops[i]) + delta * 0.9, 1.0)
		if NightWoods.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		# (the body is painted: meshes under this) shade its underside, and outline it
		for i in range(2, _body.size() - 1):
			var p0: Vector2 = _body[i]
			var p1: Vector2 = _body[i + 1]
			b.quad(Vector2(p0.x, -2), Vector2(p1.x, -2), p1, p0, Color.BLACK, PackedColorArray([Color(0.04, 0.03, 0.06, 0.0), Color(0.04, 0.03, 0.06, 0.0),
				Color(0.04, 0.03, 0.06, 0.6), Color(0.04, 0.03, 0.06, 0.6)]))
		var ring := _body.duplicate()
		ring.append(_body[0])
		b.polyline(ring, Color("1d1712"), 3.0)
		# roots trailing, and the tie-point of the vine
		for s in [-1.0, 1.0]:
			b.polyline(PackedVector2Array([Vector2(s * 26.0, 14), Vector2(s * 30.0, 30), Vector2(s * 24.0, 44)]), Color("3b2f26"), 2.0)
		b.circle(Vector2(0, 30), 6.0, Color("3b2f26"), 10)
		# grass tufts on the cap
		for k in 9:
			var gx := -48.0 + k * 12.0
			b.tri(Vector2(gx - 2.5, -14), Vector2(gx + 2.5, -14), Vector2(gx + sin(k * 2.3) * 3.0, -21.0 - (k % 3) * 2.0), Color("5f9a42") if k % 2 == 0 else Color("7fb85a"))
			b.tri(Vector2(gx - 3.0, -7), Vector2(gx + 3.0, -7), Vector2(gx + 1.0, -1.0 + (k % 2) * 3.0), Color("3e6b2c"))
		# the little world on top
		match look % 3:
			0:      # a tiny twisted tree
				b.line(Vector2(-14, -14), Vector2(-10, -40), Color("4a3828"), 4.0)
				b.circle(Vector2(-12, -44), 13.0, Color("2c5236"), 12)
				b.circle(Vector2(-4, -48), 9.0, Color("3f7a48"), 10)
			1:      # a glowing crystal cluster
				b.tri(Vector2(6, -14), Vector2(12, -44), Vector2(18, -14), Color("6fd3e8"))
				b.tri(Vector2(14, -14), Vector2(24, -34), Vector2(28, -14), Color("a6ecf7"))
				b.tri(Vector2(-2, -14), Vector2(2, -28), Vector2(8, -14), Color("4fb4cf"))
			2:      # a ring of standing stones, like a tiny shrine
				for k in 3:
					b.rect(Rect2(-24.0 + k * 18.0, -30, 8, 16), Color("9a8f80"))
					b.rect(Rect2(-24.0 + k * 18.0, -30, 2, 16), Color("b8ad9c"))
				b.rect(Rect2(-26, -34, 52, 5), Color("9a8f80"))
				b.polyline(PackedVector2Array([Vector2(-26, -29), Vector2(-26, -34), Vector2(26, -34), Vector2(26, -29)]), Color("1d1712"), 1.5)
		# water trickling off the lip, in drops
		for i in _drops.size():
			var q3: float = _drops[i]
			b.circle(Vector2(44, -6 + q3 * 90.0), 2.2 * (1.0 - q3 * 0.6), Color("9cc3e0", 0.8 * (1.0 - q3)), 6)
		b.draw(self)

	## The runes glow faintly through the dark, so the stones read at night.
	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var o := global_position
		var pulse := 0.5 + 0.5 * sin(_t * 2.0 + _home.x)
		# moonlight on the stone itself, over the dark (as the sky islands have)
		g.draw_set_transform(o)
		g.draw_colored_polygon(_body, Color("b0a497", 0.22))
		g.draw_set_transform(Vector2.ZERO)
		g.draw_line(o + Vector2(-50, -13), o + Vector2(50, -13), Color("9fd6a6", 0.55), 3.0)
		for k in 5:
			var x := -36.0 + k * 18.0
			g.draw_circle(o + Vector2(x, 6), 2.0, Color("8fe3ff", 0.35 + 0.4 * pulse))
		if look % 3 == 1:
			g.draw_circle(o + Vector2(14, -26), 18.0, Color("6fd3e8", 0.12 + 0.08 * pulse))


## ================================================================ FLOAT ROCK
class FloatRock extends AnimatableBody2D:
	## A flat flying rock to stand on (one-way: jump up through it). Some bob
	## gently, carrying him with them.
	var w := 120.0
	var bob := 0.0
	var _home := Vector2.ZERO
	var _t := 0.0
	var _body := PackedVector2Array()

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		sync_to_physics = true
		_home = position
		_t = randf() * 6.0
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(w, 14)
		cs.shape = sh
		cs.position = Vector2(w * 0.5, 7)
		cs.one_way_collision = true
		add_child(cs)
		add_to_group("glow")
		# painted like the mountain: rock, with a grass cap
		var rng := RandomNumberGenerator.new()
		rng.seed = int(_home.x)
		_body = PackedVector2Array([Vector2(0, 0), Vector2(w, 0)])
		var n := maxi(int(w / 18.0), 4)
		for k in range(n, -1, -1):
			var q := float(k) / n
			_body.append(Vector2(w * q, 10.0 + 30.0 * (1.0 - pow(absf(q - 0.5) * 2.0, 1.3)) * rng.randf_range(0.75, 1.0)))
		Terrain.paint_poly(self, _body, Terrain.ROCK_TEX, Terrain.NIGHT_ROCK.lightened(0.2), _home)
		Terrain.paint_poly(self, PackedVector2Array([Vector2(-3, -3), Vector2(w + 3, -3), Vector2(w + 1, 6), Vector2(w * 0.5, 8), Vector2(-1, 6)]),
			Terrain.GRASS_TEX, Terrain.NIGHT_GRASS.lightened(0.12), _home)

	func _physics_process(delta: float) -> void:
		_t += delta
		position = _home + Vector2(0, sin(_t * 1.2) * bob)
		if NightWoods.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		# (painted underneath) shade the underside, outline it, tufts on the cap
		for i in range(2, _body.size() - 1):
			var p0: Vector2 = _body[i]
			var p1: Vector2 = _body[i + 1]
			b.quad(Vector2(p0.x, 6), Vector2(p1.x, 6), p1, p0, Color.BLACK, PackedColorArray([Color(0.04, 0.03, 0.06, 0.0), Color(0.04, 0.03, 0.06, 0.0),
				Color(0.04, 0.03, 0.06, 0.6), Color(0.04, 0.03, 0.06, 0.6)]))
		var ring := _body.duplicate()
		ring.append(_body[0])
		b.polyline(ring, Color("1d1712"), 3.0)
		for k in int(w / 14.0):
			var gx := 6.0 + k * 14.0
			b.tri(Vector2(gx - 2.5, -2), Vector2(gx + 2.5, -2), Vector2(gx + sin(k * 1.7) * 3.0, -8.0 - (k % 3) * 2.0), Color("5f9a42") if k % 2 == 0 else Color("7fb85a"))
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var o := global_position
		g.draw_set_transform(o)
		g.draw_colored_polygon(_body, Color("b0a497", 0.22))
		g.draw_set_transform(Vector2.ZERO)
		g.draw_line(o + Vector2(3, 0.5), o + Vector2(w - 3, 0.5), Color("c9d6ff", 0.5), 2.0)


## ================================================================ DIVE BATS
class DiveBat extends Area2D:
	## A big red-and-violet bat. It shows up high above him and SCREECHES
	## (rings of sound; a dashed line glows where it will strike), then dives
	## at a slant, hooks at the bottom and swoops flat across at his chest
	## height, then climbs away. Jump over the swoop, or bonk it with the club.
	signal done
	var x := 0.0                 ## the spot it strikes at (his x a moment from now)
	var y := 600.0               ## his feet there
	var dir := 1.0               ## which way it swoops
	var warn := 0.75
	var state := "warn"          ## warn, dive, swoop, climb, bonked
	var _t := 0.0
	var _st := 0.0
	var _vel := Vector2.ZERO
	var _start := Vector2.ZERO
	var _pivot := Vector2.ZERO
	var _trail: Array = []

	const DIVE := 1150.0
	const SWOOP := 900.0
	const SWOOP_TIME := 0.42
	const CHEST := 40.0          ## swoop line: this far above his feet

	func _ready() -> void:
		collision_layer = 4          # his swing finds it
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(40, 34)
		cs.shape = sh
		add_child(cs)
		_pivot = Vector2(x - dir * 110.0, y - CHEST)
		_start = Vector2(x - dir * 280.0, y - 330.0)
		position = _start
		z_index = 4
		add_to_group("glow")

	func take_hit(_dmg: int, from_dir: int) -> void:
		if state == "bonked" or state == "warn":
			return
		state = "bonked"
		_st = 0.0
		_vel = Vector2(from_dir * 420.0, -380.0)
		var pop := Treasure.FloatText.new()
		pop.text = "BONK!"
		pop.position = global_position + Vector2(-18, -30)
		get_parent().add_child(pop)
		FX.burst(get_parent(), global_position, "sparks")

	func _physics_process(delta: float) -> void:
		_t += delta
		_st += delta
		match state:
			"warn":
				position = _start + Vector2(sin(_t * 9.0) * 6.0, sin(_t * 13.0) * 3.0)
				if _st >= warn:
					state = "dive"
					_st = 0.0
			"dive":
				var to := _pivot - position
				var step := DIVE * delta
				if to.length() <= step:
					position = _pivot
					state = "swoop"
					_st = 0.0
				else:
					position += to.normalized() * step
			"swoop":
				# flat across his chest, a little dip in the middle
				position = Vector2(_pivot.x + dir * SWOOP * _st, _pivot.y + sin(_st / SWOOP_TIME * PI) * 10.0)
				if _st >= SWOOP_TIME:
					state = "climb"
					_st = 0.0
			"climb":
				position += Vector2(dir * 520.0, -560.0) * delta
				if _st > 1.0:
					done.emit()
					queue_free()
					return
			"bonked":
				_vel.y += 900.0 * delta
				position += _vel * delta
				rotation += 12.0 * delta
				if _st > 2.0:
					done.emit()
					queue_free()
					return
		if state in ["dive", "swoop", "climb"]:
			_trail.push_front(position)
			if _trail.size() > 7:
				_trail.pop_back()
			var p := get_tree().get_first_node_in_group("player") as CaveMan
			if p != null and not p.dead and overlaps_body(p):
				p.hurt_toss(1, global_position.x - dir * 30.0, Vector2(dir * 90.0, -420.0))     # bowled up, not off the rock
		elif _trail.size() > 0:
			_trail.pop_back()
		queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var body := Color("5a1f4a")
		var wing := Color("c2307a")
		var f := dir
		var tuck := state == "dive"
		var glide := state == "swoop"
		var flap := 0.0 if tuck else sin(_t * (34.0 if state == "warn" else 26.0))
		# wings: swept back in the dive, spread flat in the swoop, beating otherwise
		for s in [-1.0, 1.0]:
			var tip: Vector2
			var mid: Vector2
			if tuck:
				tip = Vector2(-f * 34.0, s * 10.0 - 4.0)
				mid = Vector2(-f * 16.0, s * 14.0)
			elif glide:
				tip = Vector2(s * 46.0 - f * 8.0, -6.0)      # spread wide, gliding flat out
				mid = Vector2(s * 26.0 - f * 4.0, 2.0)
			else:
				tip = Vector2(s * 40.0, -18.0 - flap * 16.0)
				mid = Vector2(s * 22.0, -4.0 - flap * 8.0)
			b.poly(PackedVector2Array([Vector2(s * 4.0, -6), tip, mid + Vector2(0, 8), Vector2(s * 6.0, 8)]), wing)
			b.line(Vector2(s * 4.0, -6), tip, body, 2.0)
			b.line(mid, mid + Vector2(0, 8), body, 1.5)
		b.circle(Vector2.ZERO, 11.0, body, 12)
		b.circle(Vector2(0, 4), 7.0, Color("7a2d62"), 10)
		b.tri(Vector2(-7, -7), Vector2(-6, -19), Vector2(-1, -9), body)
		b.tri(Vector2(7, -7), Vector2(6, -19), Vector2(1, -9), body)
		b.circle(Vector2(-4, -2), 2.6, Color("ffe14a"), 6)
		b.circle(Vector2(4, -2), 2.6, Color("ffe14a"), 6)
		if state == "warn":
			# mouth wide open: SCREEEE
			b.circle(Vector2(0, 5), 4.0, Color("2a0a1e"), 8)
			b.tri(Vector2(-3, 2), Vector2(-1, 6), Vector2(-2, 2), Color.WHITE)
			b.tri(Vector2(3, 2), Vector2(1, 6), Vector2(2, 2), Color.WHITE)
		b.draw(self)

	## Through the dark: the screech rings and the glowing strike line before it
	## comes; the yellow eyes, and a streak of magenta behind it as it strikes.
	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var o := global_position
		if state == "warn":
			var k := clampf(_st / warn, 0.0, 1.0)
			for i in 3:
				var q := fmod(_t * 2.2 + i / 3.0, 1.0)
				var r := 16.0 + q * 60.0
				var a := Color(1.0, 0.4, 0.8, 0.6 * (1.0 - q))
				var prev := o + Vector2(r, 0)
				for j in range(1, 13):
					var nxt := o + Vector2.from_angle(j * TAU / 12.0) * r
					g.draw_line(prev, nxt, a, 2.0)
					prev = nxt
			# where it will strike: down to the hook, then flat across his chest
			var c := Color(1.0, 0.3, 0.45, 0.2 + 0.6 * k)
			var end := _pivot + Vector2(dir * SWOOP * SWOOP_TIME, 0)
			for i in 9:
				var a2 := _pivot.lerp(end, i / 9.0)
				g.draw_line(a2, a2 + Vector2(dir * 18.0, 0), c, 4.0)
			g.draw_string(ThemeDB.fallback_font, Vector2(x - 6.0, y - CHEST - 50.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 0.5, 0.6, 0.4 + 0.6 * k))
		for i in _trail.size():
			var q2: float = 1.0 - float(i) / 7.0
			g.draw_circle(_trail[i], 12.0 * q2, Color(0.9, 0.2, 0.6, 0.4 * q2))
		g.draw_circle(o + Vector2(-4, -2), 2.4, Color("fff36a"))
		g.draw_circle(o + Vector2(4, -2), 2.4, Color("fff36a"))


class BatSky extends Node:
	## Over the floating rocks: once he has hopped onto a rock past the first,
	## the bats come — one at a time at first, then in pairs from both sides.
	## Each strikes at where he'll be a moment from now. Keep moving, jump the
	## swoops, bonk the slow ones.
	var x0 := 0.0
	var x1 := 0.0
	var every := 1.6
	var rocks: Array = []        ## the FloatRocks, left to right
	var player: CaveMan
	var level: Node2D
	var started := false
	var sent := 0
	var _next := 0.6
	var _bats: Array = []

	func _rock_under(x: float) -> FloatRock:
		for r in rocks:
			var fr: FloatRock = r
			if x >= fr.global_position.x - 10.0 and x <= fr.global_position.x + fr.w + 10.0:
				return fr
		return null

	func _send(aim: float, dir: float, warn: float) -> void:
		var r := _rock_under(aim)
		var bat := DiveBat.new()
		bat.x = clampf(aim, x0, x1)
		bat.y = r.global_position.y if r != null and player.is_on_floor() else player.global_position.y
		bat.dir = dir
		bat.warn = warn
		level.add_child(bat)
		_bats.append(bat)
		sent += 1

	func _physics_process(delta: float) -> void:
		if player == null or player.dead or player.talking:
			return
		var px := player.global_position.x
		if px < x0 or px > x1:
			return
		if not started:
			# "when things get easy": he has made it onto the second rock
			if rocks.size() > 1 and player.is_on_floor() and px > (rocks[1] as FloatRock).global_position.x - 10.0:
				started = true
				if level.has_method("_bats_begin"):
					level._bats_begin()
			return
		_bats = _bats.filter(func(b): return is_instance_valid(b))
		if not _bats.is_empty():
			return
		_next -= delta
		if _next > 0.0:
			return
		_next = every
		var aim := px + player.velocity.x * 0.55
		var dir := 1.0 if sent % 2 == 0 else -1.0
		_send(aim, dir, 0.75)
		if sent >= 4 and sent % 3 != 0:
			# a second one, from the other side, a beat later
			_send(aim + player.velocity.x * 0.35, -dir, 1.1)
