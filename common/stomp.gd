class_name Stomp
extends RefCounted
## METEOR STOMP: a special move. In the air, T (or STOMP): he curls into a
## ball and spins — a ring of light gathering round him — then plunges
## straight down like a meteor and SLAMS the ground: a flash, shock rings
## racing out along the ground, rays, rock shards and sparks, cracks in the
## earth, a word, the screen shaking. Beasts close by are knocked flat;
## pots and logs break; and STOMP SPOTS — caches set into the ground — are
## the only way in to what's buried there.
##   level 1   after one jump (or a fall): cyan and white
##   level 2   after the DOUBLE jump: two spins, a gold-and-rainbow comet,
##             a far bigger blast — MEGA STOMP. Rune seals need this one.
## The player keeps the state (CaveMan.stomp_state / stomp_level); this file
## is the effects and the spots.

const CHARGE := [0.0, 0.2, 0.32]       ## the spin before the drop, by level
const SPEED := [0.0, 1500.0, 2100.0]   ## the plunge
const RADIUS := [0.0, 110.0, 190.0]    ## what the blast reaches
const DAMAGE := [0, 3, 6]
## The METEOR DASH (T + left/right in the air): sideways, after the same spin.
const DASH_SPEED := [0.0, 1500.0, 1900.0]    ## (2026-10-10: faster, a touch shorter: Jawad)
const DASH_TIME := [0.0, 0.135, 0.195]      ## ~200 px, and ~345 px for the gold one (each ~9% shorter than before)
const DASH_CHARGE := [0.0, 0.13, 0.2]       ## a quicker wind-up than the stomp's spin

const ICE := Color("7df9ff")
const BLUE := Color("4a7dff")
const GOLD := Color("ffd25a")
const PINK := Color("ff5fd8")
const WHITE := Color("ffffff")


static func tint(level: int, t: float) -> Color:
	if level >= 2:
		return Color.from_hsv(fmod(t * 0.9, 1.0), 0.55, 1.0).lerp(GOLD, 0.35)
	return ICE


## ================================================================ TRAIL
class Trail extends Node2D:
	## Rides with him from the press to the impact: while he spins, sparks
	## rush IN to him and a ring tightens; while he drops, a comet tail of
	## light streams up behind him.
	## THE DASH has its own: a shock ring BANGS out behind him as he launches,
	## a tapered blade of light (white-hot core, coloured edge) streams flat
	## behind him, after-images of the ball, sparks flung back, speed lines
	## above and below, and a puff where it ends.
	var player: CaveMan
	var level := 1
	var dir := 0                   ## 0: the drop; -1/+1: the dash
	var _t := 0.0
	var _tail: Array = []          ## recent positions while dropping / dashing
	var _sparks: Array = []        ## [offset, life]: the charge's sparks rushing in
	var _flung: Array = []         ## [global pos, vel, life, life0]: the dash's sparks flung back
	var _bang := -1.0              ## >= 0: the launch ring, growing
	var _bang_at := Vector2.ZERO
	var _was := ""
	var _ghost_in := 0.0
	var _ghosts: Array = []        ## [global pos, life]

	func _ready() -> void:
		z_index = 4
		add_to_group("glow")
		for i in (14 if level == 1 else 26):
			var a := randf() * TAU
			_sparks.append([Vector2.from_angle(a) * randf_range(70, 130), randf_range(0.0, 0.25)])

	func _process(delta: float) -> void:
		_t += delta
		var alive := player != null and is_instance_valid(player) and player.stomp_state != ""
		if alive:
			global_position = player.global_position + Vector2(0, -38)
			var st := player.stomp_state
			if st == "dash" and _was != "dash":
				# LAUNCH: a ring bangs out behind him, a burst of sparks
				_bang = 0.0
				_bang_at = global_position
				for i in (14 if level == 1 else 22):
					var a := randf_range(-0.9, 0.9) + (PI if dir > 0 else 0.0)
					_flung.append([global_position, Vector2.from_angle(a) * randf_range(250, 600), 0.4, 0.4])
			_was = st
			if st == "dive" or st == "dash":
				_tail.push_front(global_position)
				if _tail.size() > (16 if dir != 0 else 12):
					_tail.pop_back()
			if st == "dash":
				# sparks flung back off him, and after-images of the ball
				for k in (2 if level == 1 else 3):
					_flung.append([global_position + Vector2(0, randf_range(-14, 14)),
						Vector2(-dir * randf_range(200, 520), randf_range(-140, 140)), 0.35, 0.35])
				_ghost_in -= delta
				if _ghost_in <= 0.0:
					_ghost_in = 0.025
					_ghosts.append([global_position, 0.22])
		for s in _sparks:
			s[0] = (s[0] as Vector2) * pow(0.0008, delta)     # rushing in
		for f in _flung:
			f[0] = (f[0] as Vector2) + (f[1] as Vector2) * delta
			f[1] = (f[1] as Vector2) * pow(0.02, delta)
			f[2] = float(f[2]) - delta
		_flung = _flung.filter(func(f): return float(f[2]) > 0.0)
		for g in _ghosts:
			g[1] = float(g[1]) - delta
		_ghosts = _ghosts.filter(func(g): return float(g[1]) > 0.0)
		if _bang >= 0.0:
			_bang += delta
			if _bang > 0.35:
				_bang = -1.0
		if not alive:
			# the tail drains away, then the trail goes
			if not _tail.is_empty():
				_tail.pop_back()
			if _tail.is_empty() and _flung.is_empty() and _ghosts.is_empty() and _bang < 0.0:
				if dir != 0 and _was == "dash":
					FX.burst(get_parent(), global_position, "ring")       # the puff where it ends
				queue_free()
				return
		queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var col := Stomp.tint(level, _t)
		var st := player.stomp_state if player != null and is_instance_valid(player) else ""
		if st == "charge":
			var ch: float = Stomp.CHARGE[level] if dir == 0 else Stomp.DASH_CHARGE[level]
			var k := clampf(_t / ch, 0.0, 1.0)
			b.arc(Vector2.ZERO, 80.0 * (1.0 - k) + 24.0, 0.0, TAU, 40, Color(col, 0.4 + 0.6 * k), 3.0 + 4.0 * k)
			for s in _sparks:
				var p: Vector2 = s[0]
				b.line(p, p * 0.7, Color(Stomp.tint(level, _t + p.x * 0.01), 0.9), 3.0)
		elif dir == 0:
			# the drop's comet: streaks of light up behind him, widest at his back
			for i in _tail.size():
				var q := 1.0 - float(i) / 12.0
				var p2: Vector2 = (_tail[i] as Vector2) - global_position
				var c2 := Stomp.tint(level, _t - i * 0.05)
				b.circle(p2, (16.0 if level == 1 else 24.0) * q, Color(c2, 0.35 * q), 12)
			for j in 5:
				var x := (-20.0 + j * 10.0) * (1.0 if level == 1 else 1.6)
				b.line(Vector2(x, -30), Vector2(x * 0.6, -110.0 - 30.0 * level), Color(col, 0.55), 2.0)
		else:
			_draw_dash(b, col)
		b.draw(self)

	func _draw_dash(b: Batch, col: Color) -> void:
		var o := global_position
		var w0 := 26.0 if level == 1 else 36.0
		# the blade of light: a tapered band along the tail, coloured edge, white core
		var n := _tail.size()
		for layer in 2:
			var w := w0 * (1.0 if layer == 0 else 0.45)
			for i in n - 1:
				var q0 := 1.0 - float(i) / n
				var q1 := 1.0 - float(i + 1) / n
				var p0: Vector2 = (_tail[i] as Vector2) - o
				var p1: Vector2 = (_tail[i + 1] as Vector2) - o
				var c0 := Stomp.tint(level, _t - i * 0.04) if layer == 0 else Color(1, 1, 1)
				var a := (0.55 if layer == 0 else 0.85) * q0
				b.quad(p0 + Vector2(0, -w * q0 * 0.5), p1 + Vector2(0, -w * q1 * 0.5), p1 + Vector2(0, w * q1 * 0.5), p0 + Vector2(0, w * q0 * 0.5),
					Color(c0, a), PackedColorArray([Color(c0, a), Color(c0, a * q1), Color(c0, a * q1), Color(c0, a)]))
		# after-images of the ball
		for g in _ghosts:
			var k := float(g[1]) / 0.22
			b.circle((g[0] as Vector2) - o, 26.0 * (0.6 + 0.4 * k), Color(col, 0.28 * k), 16)
		# speed lines above and below, rushing back
		for j in 6:
			var y := (-42.0 + j * 16.8) * (1.0 if level == 1 else 1.3)
			var off := fmod(_t * 900.0 + j * 137.0, 160.0)
			var x0 := -dir * (30.0 + off)
			b.line(Vector2(x0, y), Vector2(x0 - dir * (60.0 + 30.0 * level), y), Color(1, 1, 1, 0.5 * (1.0 - off / 160.0)), 2.0)
		# a hot nose cone in front of him
		b.circle(Vector2(dir * 24.0, 0), 14.0 + 4.0 * level, Color(1, 1, 1, 0.35), 14)
		_draw_flung_and_bang(b, col)

	func _draw_flung_and_bang(b: Batch, col: Color) -> void:
		var o := global_position
		for f in _flung:
			var k := float(f[2]) / float(f[3])
			var p: Vector2 = (f[0] as Vector2) - o
			var v: Vector2 = f[1]
			b.line(p, p - v * 0.03, Color(Stomp.tint(level, _t + p.x * 0.01), 0.95 * k), 3.0)
			b.circle(p, 2.2, Color(1, 1, 0.9, k), 6)
		if _bang >= 0.0:
			var k2 := _bang / 0.35
			var c := _bang_at - o
			b.arc(c, 20.0 + 110.0 * k2, 0.0, TAU, 32, Color(col, 0.8 * (1.0 - k2)), 6.0 * (1.0 - k2) + 1.0)
			b.arc(c, 10.0 + 70.0 * k2, 0.0, TAU, 24, Color(1, 1, 1, 0.7 * (1.0 - k2)), 3.0)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var o := global_position
		var col := Stomp.tint(level, _t)
		if player != null and is_instance_valid(player) and player.stomp_state != "":
			g.draw_circle(o, 34.0 + 12.0 * level, Color(col, 0.25))
		for i in _tail.size():
			var q := 1.0 - float(i) / _tail.size()
			g.draw_circle(_tail[i], 12.0 * q * level, Color(Stomp.tint(level, _t - i * 0.05), 0.3 * q))
		for f in _flung:
			g.draw_circle(f[0], 4.0, Color(col, 0.5 * float(f[2]) / float(f[3])))


## ================================================================ BLAST
class Blast extends Node2D:
	## The impact, on the ground where he lands.
	var level := 1
	var t := 0.0
	var _shards: Array = []        ## [pos, vel, spin, size, colour]
	var _cracks: Array = []        ## [angle, length]

	func _ready() -> void:
		z_index = 5
		add_to_group("glow")
		add_to_group("light")
		var n := 10 if level == 1 else 22
		for i in n:
			var a := randf_range(PI * 1.08, PI * 1.92)
			var col: Color = Color("8d857a") if randf() < 0.55 else Stomp.tint(level, randf())
			_shards.append([Vector2(randf_range(-20, 20), -4), Vector2.from_angle(a) * randf_range(260, 520) * (1.0 + 0.3 * (level - 1)), randf_range(-12, 12), randf_range(3.0, 7.0), col])
		for i in 7 + 4 * level:
			var a2 := randf_range(-0.35, 0.35) + (0.0 if i % 2 == 0 else PI)
			_cracks.append([a2, randf_range(40, 90) * level])
		_hit_things()
		var lvl := get_parent()
		if lvl.has_method("shake"):
			lvl.shake(8.0 if level == 1 else 16.0, 0.35 if level == 1 else 0.6)
		Critter.slow_time(get_tree(), 0.08 if level == 1 else 0.16, 0.25)
		var w := Sunfire.Word.new()
		w.text = "STOMP!" if level == 1 else "MEGA STOMP!!"
		w.size = 40 if level == 1 else 54
		w.position = global_position + Vector2(0, -130)
		lvl.add_child.call_deferred(w)

	## Everything the blast reaches: beasts knocked flat, pots and logs
	## broken, and stomp spots.
	func _hit_things() -> void:
		var o := global_position
		var r: float = Stomp.RADIUS[level]
		for c in get_tree().get_nodes_in_group("critters"):
			var cr := c as Critter
			if cr == null or cr.dying > 0.0:
				continue
			var d := cr.global_position - o
			if absf(d.x) < r and absf(d.y) < 90.0:
				cr.take_hit(Stomp.DAMAGE[level], 1 if d.x >= 0.0 else -1)
		for n in get_parent().get_children():
			if n is Treasure.Breakable and absf((n as Node2D).global_position.x - o.x) < r * 0.7 and absf((n as Node2D).global_position.y - o.y) < 60.0:
				n.take_hit(2, 1)
		for s in get_tree().get_nodes_in_group("stomp_spot"):
			if s.has_method("stomped"):
				s.stomped(level, o)

	func light() -> Vector4:
		return Vector4(global_position.x, global_position.y - 30.0, (260.0 + 140.0 * level) * maxf(0.0, 1.0 - t * 1.4), 0.6)

	func light_strength() -> float:
		return 0.0

	func _process(delta: float) -> void:
		t += delta
		for s in _shards:
			s[1] = (s[1] as Vector2) + Vector2(0, 1500.0) * delta
			s[0] = (s[0] as Vector2) + (s[1] as Vector2) * delta
		if t > 1.0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var r: float = Stomp.RADIUS[level]
		var col := Stomp.tint(level, t)
		# the flash
		if t < 0.12:
			b.circle(Vector2(0, -20), (40.0 + 300.0 * t) * level, Color(1, 1, 1, 0.8 * (1.0 - t / 0.12)), 28)
		# rays
		if t < 0.4:
			var k := t / 0.4
			for i in 9 + 5 * level:
				var a := PI + PI * (i + 0.5) / (9 + 5 * level)
				b.tri(Vector2.from_angle(a + 0.05) * 20.0, Vector2.from_angle(a) * (r * 0.9 + 80.0 * k), Vector2.from_angle(a - 0.05) * 20.0,
					Color(Stomp.tint(level, t + i * 0.07), 0.55 * (1.0 - k)))
		# shock rings racing along the ground (flattened)
		for j in level + 1:
			var kk := clampf((t - j * 0.08) / 0.5, 0.0, 1.0)
			if kk > 0.0 and kk < 1.0:
				var pts := PackedVector2Array()
				for i in 33:
					var a2 := PI + PI * i / 32.0
					pts.append(Vector2(cos(a2) * r * 1.6 * kk, sin(a2) * r * 0.45 * kk))
				b.polyline(pts, Color(Stomp.tint(level, t + j * 0.3), 1.0 - kk), 8.0 * (1.0 - kk) + 2.0)
		# cracks in the ground, glowing then fading
		var ca := clampf(1.0 - (t - 0.3) / 0.7, 0.0, 1.0)
		for c in _cracks:
			var dirx := cos(float(c[0]))
			var cl := float(c[1]) * minf(t / 0.08, 1.0)
			var p0 := Vector2(0, 2)
			var p1 := p0 + Vector2(dirx * cl * 0.5, 3)
			var p2 := p1 + Vector2(dirx * cl * 0.5, -2)
			b.polyline(PackedVector2Array([p0, p1, p2]), Color(0.1, 0.06, 0.04, ca), 4.0)
			b.polyline(PackedVector2Array([p0, p1, p2]), Color(col, ca * 0.8), 1.5)
		# shards and sparks
		for s in _shards:
			var p: Vector2 = s[0]
			var sz: float = s[3]
			var sc: Color = s[4]
			var rot := float(s[2]) * t
			b.poly(PackedVector2Array([p + Vector2(-sz, 0).rotated(rot), p + Vector2(0, -sz).rotated(rot), p + Vector2(sz, sz * 0.4).rotated(rot)]), Color(sc, clampf(1.2 - t, 0.0, 1.0)))
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var o := global_position
		var f := clampf(1.0 - t / 0.5, 0.0, 1.0)
		g.draw_circle(o + Vector2(0, -20), (70.0 + 60.0 * level) * (0.6 + t), Color(Stomp.tint(level, t), 0.35 * f))
		for s in _shards:
			if (s[4] as Color) != Color("8d857a"):
				g.draw_circle(o + (s[0] as Vector2), 4.0, Color(s[4] as Color, clampf(1.0 - t, 0.0, 1.0)))


## ================================================================ SPOT
class Spot extends Node2D:
	## A cache set into the ground, only opened by a stomp right on it.
	##   "crack"  a cracked flagstone with a glint under it: any stomp
	##   "seal"   a round rune-stone with gold veins: only a MEGA stomp; a
	##            plain one bounces off it — CLANG — and it tells him so
	## Inside: treasure that fountains out onto the ground beside the hole.
	signal opened
	var kind := "crack"
	var contents: Array = []
	var level_id := ""
	var id := ""
	var broken := false
	var _t := 0.0
	var _shake := 0.0
	var _dents := 0

	func need() -> int:
		return 2 if kind == "seal" else 1

	func _ready() -> void:
		z_index = 2
		add_to_group("stomp_spot")
		add_to_group("glow")
		_t = randf() * 5.0
		broken = true
		for i in contents.size():
			if not GameState.is_taken(level_id, "%s_%d" % [id, i]) and not Treasure.is_bone(contents[i]):
				broken = false
		if contents.all(func(k): return Treasure.is_bone(k)):
			broken = false

	func stomped(level: int, at: Vector2) -> void:
		if broken or absf(at.x - global_position.x) > 70.0 or absf(at.y - global_position.y) > 40.0:
			return
		if level < need():
			_shake = 0.4
			_dents += 1
			var pop := Treasure.FloatText.new()
			pop.text = "CLANG!"
			pop.position = global_position + Vector2(-26, -70)
			get_parent().add_child(pop)
			var p := get_tree().get_first_node_in_group("player") as CaveMan
			if p != null:
				p.velocity.y = -520.0           # bounced right off it
				p.said.emit("Too hard for a plain stomp! DOUBLE-jump first, then T: MEGA STOMP!")
			return
		broken = true
		opened.emit()
		var lvl := get_parent()
		for i in contents.size():
			var tid := "%s_%d" % [id, i]
			if GameState.is_taken(level_id, tid):
				continue
			var pk := Treasure.Pickup.new()
			pk.kind = contents[i]
			pk.level_id = level_id
			pk.id = tid
			pk.position = global_position + Vector2(0, -16)
			# a fountain that comes down on the grass either side of the hole
			var side := -1.0 if i % 2 == 0 else 1.0
			# a low hop: never up onto a ledge overhead
			pk.aim_at(global_position + Vector2(side * randf_range(36, 80), -14), randf_range(0.45, 0.55), global_position.y)
			if lvl.has_method("_on_treasure_popped"):
				lvl._on_treasure_popped(pk)
			lvl.add_child.call_deferred(pk)
		var pop2 := Treasure.FloatText.new()
		pop2.text = "FOUND IT!"
		pop2.position = global_position + Vector2(-40, -90)
		lvl.add_child(pop2)
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		_shake = maxf(_shake - delta, 0.0)
		if LevelBase.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var sh := Vector2(sin(_shake * 80.0) * 3.0 * (_shake / 0.4), 0)
		if broken:
			# the hole where it was, broken bits round its rim
			b.ellipse(Vector2(0, 4), 34, 9, Color("120b08"))
			b.ellipse(Vector2(0, 2), 30, 6, Color("2a1a12"))
			for i in 5:
				var x := -30.0 + i * 15.0
				b.tri(Vector2(x - 5, 0), Vector2(x, -5 - (i % 2) * 3.0), Vector2(x + 6, 0), Color("6f675e"))
			b.draw(self)
			return
		if kind == "crack":
			# a flagstone set into the turf, cracked across, a glint beneath
			var slab := PackedVector2Array([Vector2(-36, -2), Vector2(-28, -8), Vector2(26, -9), Vector2(37, -1), Vector2(30, 8), Vector2(-30, 8)])
			for i in slab.size():
				slab[i] = slab[i] + sh
			b.poly(slab, Color("1c130d"))
			var top := PackedVector2Array()
			for p in slab:
				top.append(p * 0.92 + Vector2(0, -1))
			b.poly(top, Color("8a8378"))
			b.rect(Rect2(Vector2(-26, -7) + sh, Vector2(50, 3)), Color("aaa397"))
			b.polyline(PackedVector2Array([Vector2(-20, -6) + sh, Vector2(-6, 0) + sh, Vector2(2, -5) + sh, Vector2(14, 3) + sh, Vector2(22, -4) + sh]), Color("2a2420"), 2.0)
			b.line(Vector2(-6, 0) + sh, Vector2(-10, 6) + sh, Color("2a2420"), 1.5)
			b.line(Vector2(14, 3) + sh, Vector2(18, 7) + sh, Color("2a2420"), 1.5)
		else:
			# a round rune-seal: gold veins and a spiral, breathing light
			var pulse := 0.5 + 0.5 * sin(_t * 2.2)
			b.ellipse(Vector2(0, 0) + sh, 46, 13, Color("1c130d"))
			b.ellipse(Vector2(0, -2) + sh, 43, 11, Color("5d5866"))
			b.ellipse(Vector2(0, -4) + sh, 38, 8, Color("7a7486"))
			var vein := Color(GOLD, 0.6 + 0.4 * pulse)
			for i in 6:
				var a := i * TAU / 6.0 + 0.3
				b.line(Vector2(cos(a) * 8.0, sin(a) * 2.5 - 4.0) + sh, Vector2(cos(a) * 34.0, sin(a) * 7.0 - 4.0) + sh, vein, 2.0)
			var sp := PackedVector2Array()
			for i in 18:
				var q := i / 17.0
				sp.append(Vector2.from_angle(q * TAU * 1.6) * Vector2(4.0 + 10.0 * q, (4.0 + 10.0 * q) * 0.3) + Vector2(0, -4) + sh)
			b.polyline(sp, Color(GOLD.lightened(0.3), 0.9), 2.0)
			for i in _dents:
				var dx := -24.0 + (i * 17) % 48
				b.line(Vector2(dx, -6) + sh, Vector2(dx + 6, -1) + sh, Color("2a2430"), 2.0)
		b.draw(self)

	## A glint now and then (a crack), or the seal's veins glowing.
	func draw_glow(g) -> void:   # g: the glow layer's Batch
		if broken:
			return
		var o := global_position
		if kind == "seal":
			var pulse := 0.5 + 0.5 * sin(_t * 2.2)
			g.draw_circle(o + Vector2(0, -4), 30.0 + 8.0 * pulse, Color(GOLD, 0.12 + 0.12 * pulse))
		var spark := fmod(_t * 0.7, 2.2)
		if spark < 0.4:
			var k := sin(spark / 0.4 * PI)
			Treasure.glint(g, o + Vector2(10, -8), 9.0 * k, Color(1, 0.95, 0.75, k))
