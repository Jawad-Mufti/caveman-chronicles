## Level 2's ground: LIVING TURF. The earth is shown as a cartoon cut-away —
## wavy bands of soil, pebbles, roots, worm tunnels, fossils (he lives in the
## Stone Age: the ground is full of older things) and a few little crystals
## that glow in the dark — under a fat, scalloped lip of moss, with roots
## dangling off every cliff edge.
## On top, the grass is alive:
##   - every blade sways in the night wind
##   - it parts around his legs as he walks through, and springs back wobbling
##   - a hard landing sends a ripple out through it both ways
##   - running kicks up bits of grass and dew (embers, in SUNFIRE)
##   - glowing mushrooms puff spores when he steps on them; night flowers
##     open and glow as he comes near and close again behind him
##   - fireflies lift out of the grass as he runs through it
## The cut-away is drawn once; only the grass on screen moves and redraws.
class_name Turf
extends RefCounted

const SOIL := [Color("5a3a24"), Color("7a4f2c"), Color("9a683b"), Color("6b442a"), Color("4a3020")]
const OUTLINE := Color("1c130d")
const MOSS := Color("2e6b3c")
const MOSS_LIGHT := Color("4f9a4c")
const MOSS_HI := Color("9ad86c")
const GREENS := [Color("3f8a45"), Color("57a64f"), Color("2f7a4a"), Color("6fb85a"), Color("3a9a6a"), Color("7cc45e")]
const PEBBLES := [Color("8a7b6a"), Color("a08c74"), Color("6f6a66"), Color("9a8f86")]
const CRYSTALS := [Color("b18cff"), Color("5fe6ff"), Color("ff7ad9")]
const SHROOMS := [Color("5ff0ff"), Color("ff5fd2"), Color("9dff6a")]
const PETALS := [Color("ffd84a"), Color("b07cff"), Color("ff7a6b"), Color("6ad8ff")]


## How far either side of the camera centre the grass must be alive: what
## the view shows (wider when it is pulled back), and a little more.
static func reach(n: Node2D) -> float:
	return LevelBase.view_half(n).x + 120.0


static func _cam_x(n: Node) -> float:
	var cam := n.get_viewport().get_camera_2d()
	return cam.get_screen_center_position().x if cam != null else 0.0


## ================================================================ GROUND
class Ground extends World.Slab:
	var crystals: Array = []        ## [local pos, size, colour index]
	var back: Blades
	var front: Blades

	func _init(r: Rect2) -> void:
		super(r)
		fill_below = 260.0          # soil drawn below the solid part: a pulled-back view never sees its bottom

	func _ready() -> void:
		super._ready()
		# the earth under the grass: painted, like the mountain's (smooth, night-tinted)
		Terrain.paint_rect(self, Vector2(rect.size.x, rect.size.y + fill_below), Terrain.EARTH_TEX, Terrain.NIGHT_EARTH)
		back = Blades.new()
		back.ground = self
		back.front = false
		add_child(back)
		front = Blades.new()
		front.ground = self
		front.front = true
		add_child(front)
		var gp := GlowProxy.new()
		gp.ground = self
		add_child(gp)

	## No grass from x0 to x1 (local): rock stands on the turf there, and its
	## blades would draw across the rock's face.
	func bare(x0: float, x1: float) -> void:
		back.bare(x0, x1)
		front.bare(x0, x1)

	## Is the camera over this stretch of ground (or near it)?
	func in_view() -> bool:
		var cx := Turf._cam_x(self)
		var reach := Turf.reach(self) + 40.0
		return cx > rect.position.x - reach and cx < rect.end.x + reach

	func _draw() -> void:
		var w := rect.size.x
		var h := rect.size.y + fill_below
		var rng := RandomNumberGenerator.new()
		rng.seed = int(rect.position.x) * 13 + 5
		var sd := rng.randf() * 10.0
		var b := Batch.new()
		# the earth itself is painted (Terrain.paint_rect in _ready, behind this); over it,
		# drawn once: what lives in the soil. No bands (they read as pixels): things IN it.
		crystals.clear()
		# warm light soaking in under the grass, the earth going dark with depth
		var lit := Color(1.0, 0.75, 0.45, 0.10)
		var clear := Color(1.0, 0.75, 0.45, 0.0)
		b.quad(Vector2(0, 0), Vector2(w, 0), Vector2(w, 40), Vector2(0, 40), lit, PackedColorArray([lit, lit, clear, clear]))
		var dk := Color(0.05, 0.03, 0.02, 0.0)
		var deep := Color(0.05, 0.03, 0.02, 0.78)
		b.quad(Vector2(0, 26), Vector2(w, 26), Vector2(w, h), Vector2(0, h), dk, PackedColorArray([dk, dk, deep, deep]))
		# roots, from the grass down into the soil: a main root and a fork or two
		var rx := rng.randf_range(4.0, 20.0)
		while rx < w - 4.0:
			var ln := rng.randf_range(18.0, 54.0)
			var root := PackedVector2Array()
			for q in 6:
				var k3 := q / 5.0
				root.append(Vector2(rx + sin(k3 * 4.0 + rx) * 4.0 * k3, 6.0 + ln * k3))
			b.polyline(root, Color(0.16, 0.1, 0.06, 0.75), 2.6 - 0.8 * float(int(ln) % 2))
			if ln > 30.0:
				var fork: Vector2 = root[3]
				b.polyline(PackedVector2Array([fork, fork + Vector2(rng.randf_range(-12, 12), 10), fork + Vector2(rng.randf_range(-16, 16), 18)]), Color(0.16, 0.1, 0.06, 0.6), 1.4)
			rx += rng.randf_range(16.0, 38.0)
		# stones IN the earth: lots of small pebbles near the top, fewer and bigger deeper down;
		# each outlined, shaded below, lit on top, darker the deeper it sits
		var n := int(w / 16.0)
		for i in n:
			var py := 22.0 + pow(rng.randf(), 1.8) * minf(h - 40.0, 300.0)
			var big := rng.randf() < 0.12 + py / 1400.0
			var r := rng.randf_range(9.0, 16.0) if big else rng.randf_range(2.5, 6.0)
			var p := Vector2(rng.randf_range(r, w - r), py)
			var depth := clampf(py / 260.0, 0.0, 1.0)
			var col: Color = (PEBBLES[rng.randi() % PEBBLES.size()] as Color).darkened(0.15 + 0.55 * depth)
			var rot := rng.randf_range(-0.6, 0.6)
			var ry := r * rng.randf_range(0.6, 0.85)
			b.ellipse(p, r + 1.6, ry + 1.6, Color(OUTLINE, 0.85 - 0.4 * depth), rot, 14)
			b.ellipse(p, r, ry, col, rot, 14)
			b.ellipse(p + Vector2(0, ry * 0.35), r * 0.8, ry * 0.5, Color(0, 0, 0, 0.22), rot, 12)
			b.ellipse(p + Vector2(-r * 0.25, -ry * 0.35), r * 0.45, ry * 0.3, Color(1, 1, 1, 0.22 * (1.0 - depth)), rot, 10)
			if big and rng.randf() < 0.5:
				b.line(p + Vector2(-r * 0.4, -ry * 0.2), p + Vector2(r * 0.1, ry * 0.3), Color(OUTLINE, 0.5), 1.2)
		# now and then a FOSSIL: a curled shell, or a little bone (he lives in the Stone Age:
		# the ground is full of older things)
		var fx := rng.randf_range(120.0, 420.0)
		while fx < w - 40.0:
			var fp := Vector2(fx, rng.randf_range(70.0, minf(h - 40.0, 200.0)))
			var fcol := Color("cdbf9f").darkened(0.35 + 0.3 * clampf(fp.y / 260.0, 0.0, 1.0))
			if rng.randf() < 0.55:
				var sp := PackedVector2Array()
				for q in 22:
					var ka := q / 21.0
					sp.append(fp + Vector2.from_angle(ka * TAU * 1.6) * (1.0 + ka * 9.0))
				b.ellipse(fp, 11.0, 10.0, Color(OUTLINE, 0.55), 0.0, 14)
				b.ellipse(fp, 9.5, 8.6, fcol, 0.0, 14)
				b.polyline(sp, fcol.darkened(0.45), 1.6)
			else:
				var ang := rng.randf_range(-0.5, 0.5)
				var d := Vector2.from_angle(ang) * 12.0
				b.line(fp - d, fp + d, Color(OUTLINE, 0.6), 6.0)
				b.line(fp - d, fp + d, fcol, 3.6)
				for e in [fp - d, fp + d]:
					b.circle(e + Vector2(0, -2.5), 3.4, fcol, 8)
					b.circle(e + Vector2(0, 2.5), 3.4, fcol, 8)
			fx += rng.randf_range(380.0, 760.0)
		# a few little crystals deep in the soil (they glow in the dark: draw_turf_glow)
		var cx2 := rng.randf_range(200.0, 600.0)
		while cx2 < w - 30.0:
			var cp := Vector2(cx2, rng.randf_range(90.0, minf(h - 30.0, 220.0)))
			var ci := rng.randi() % CRYSTALS.size()
			var ccol: Color = CRYSTALS[ci]
			for j in 3:
				var tilt := (j - 1) * 0.45
				var tip := cp + Vector2.from_angle(-PI * 0.5 + tilt) * (12.0 - absf(j - 1) * 4.0)
				b.tri(cp + Vector2(-3.0, 0).rotated(tilt), tip, cp + Vector2(3.0, 0).rotated(tilt), ccol.darkened(0.25))
				b.line(cp, tip, ccol.lightened(0.35), 1.0)
			crystals.append([cp, ci])
			cx2 += rng.randf_range(500.0, 900.0)
		# a soft shadow tucked under the lip of moss, so the grass stands out
		var sh0 := Color(0.03, 0.02, 0.01, 0.55)
		var sh1 := Color(0.03, 0.02, 0.01, 0.0)
		b.quad(Vector2(0, 6), Vector2(w, 6), Vector2(w, 20), Vector2(0, 20), sh0, PackedColorArray([sh0, sh0, sh1, sh1]))
		# the cliff faces at both ends, with roots dangling off them
		for side in [0.0, w]:
			var s := -1.0 if side == 0.0 else 1.0
			b.rect(Rect2(side - (0.0 if s < 0.0 else 7.0), 4, 7, h), Color(OUTLINE, 0.55))
			for j in 3:
				var top := Vector2(side, 14.0 + j * 18.0)
				var dangle := PackedVector2Array()
				for q in 6:
					var k2 := q / 5.0
					dangle.append(top + Vector2(s * (4.0 + 8.0 * k2), 26.0 * k2 * (1.0 + j * 0.4)) + Vector2(sin(k2 * 5.0 + j) * 2.0, 0))
				b.polyline(dangle, Color("2a1c12"), 2.5)
		# the lip of moss: a fat band along the top, scalloped underneath
		var lip := PackedVector2Array()
		var lx := -10.0
		while lx <= w + 10.0:
			lip.append(Vector2(lx, -3.0 + sin(lx * 0.07 + sd) * 1.2))
			lx += 12.0
		var under := PackedVector2Array()
		var sx := w + 10.0
		while sx >= -10.0:
			for j in 5:
				var a2 := PI * j / 4.0
				under.append(Vector2(sx - 9.0 + cos(a2) * 9.0, 9.0 + sin(a2) * (5.0 + 2.0 * sin(sx * 0.3))))
			sx -= 18.0
		var lip_poly := lip.duplicate()
		lip_poly.append_array(under)
		b.poly(lip_poly, OUTLINE)
		var lip_in := PackedVector2Array()
		for p in lip_poly:
			lip_in.append(p + Vector2(0, -1.5))
		b.poly(lip_in, MOSS)
		b.rect(Rect2(-10, -3, w + 20, 5), MOSS_LIGHT)
		b.polyline(lip, MOSS_HI, 2.0)
		# the lip curls over the cliff edges
		for side2 in [-6.0, w + 6.0]:
			b.circle(Vector2(side2, 4), 9.0, OUTLINE, 14)
			b.circle(Vector2(side2, 3), 7.5, MOSS, 14)
			b.circle(Vector2(side2 - 1.5, 0), 3.5, MOSS_LIGHT, 10)
		b.draw(self)

	## Through the dark: crystals, flowers, mushrooms, fireflies, spores.
	func draw_turf_glow(g, cam_x: float) -> void:
		var o := global_position
		for cr in crystals:
			var p: Vector2 = o + (cr[0] as Vector2)
			if absf(p.x - cam_x) > Turf.reach(self):
				continue
			var col: Color = CRYSTALS[cr[1]]
			var pulse := 0.5 + 0.5 * sin(front.t * 1.6 + p.x)
			g.draw_circle(p + Vector2(0, -4), 16.0 + 4.0 * pulse, Color(col, 0.16 + 0.1 * pulse))
			g.draw_circle(p + Vector2(0, -6), 4.0, Color(col.lightened(0.4), 0.7))
		front.draw_flora_glow(g, cam_x)


## ================================================================ BLADES
class Blades extends Node2D:
	## One row of living grass along the top: the back row (taller, darker,
	## behind him) or the front row (short, brighter, over his feet) — which
	## also carries the flowers, mushrooms, and everything that flies up.
	var ground: Ground
	var front := false
	var t := 0.0
	var _step := 6.0
	var _x: PackedFloat32Array
	var _h: PackedFloat32Array
	var _col: PackedInt32Array
	var _bend: PackedFloat32Array
	var _vel: PackedFloat32Array
	var _flora: Array = []           ## [x, kind ("shroom"/"flower"), colour index, open, hold, squash]
	var _bits: Array = []            ## [pos (local), vel, life, colour, glows]
	var _was_floor := true
	var _vy := 0.0
	var _wave_x := 0.0
	var _wave_t := -1.0
	var _wave_amp := 0.0
	var _bit_in := 0.0

	func _ready() -> void:
		z_index = 1 if front else 0
		_step = 9.0 if front else 6.0
		var w := ground.rect.size.x
		var rng := RandomNumberGenerator.new()
		rng.seed = int(ground.rect.position.x) * (3 if front else 7) + 1
		var n := int(w / _step)
		_x.resize(n)
		_h.resize(n)
		_col.resize(n)
		_bend.resize(n)
		_vel.resize(n)
		for i in n:
			_x[i] = i * _step + rng.randf_range(0, _step * 0.8)
			_h[i] = rng.randf_range(5.0, 10.0) if front else rng.randf_range(10.0, 19.0)
			_col[i] = rng.randi() % GREENS.size()
		if front:
			var fx := rng.randf_range(40, 160)
			while fx < w - 30.0:
				var shroom := rng.randf() < 0.45
				_flora.append([fx, "shroom" if shroom else "flower", rng.randi() % (SHROOMS.size() if shroom else PETALS.size()), 0.0, 0.0, 0.0])
				fx += rng.randf_range(110, 280)
		t = rng.randf() * 10.0

	## Clear the blades (and the flowers) from x0 to x1: rock stands there.
	func bare(x0: float, x1: float) -> void:
		for i in _x.size():
			if _x[i] > x0 - 3.0 and _x[i] < x1 + 3.0:
				_h[i] = 0.0
		_flora = _flora.filter(func(fl) -> bool: return float(fl[0]) < x0 - 12.0 or float(fl[0]) > x1 + 12.0)
		queue_redraw()

	func _player() -> CaveMan:
		return get_tree().get_first_node_in_group("player") as CaveMan

	func _physics_process(delta: float) -> void:
		if not ground.in_view():
			return
		t += delta
		var gx := ground.global_position.x
		var top := ground.global_position.y
		var cx := Turf._cam_x(self) - gx
		var i0 := clampi(int((cx - Turf.reach(self)) / _step), 0, _x.size())
		var i1 := clampi(int((cx + Turf.reach(self)) / _step) + 1, 0, _x.size())
		var p := _player()
		var px := -99999.0
		var near := 0.0                 # 1 when his feet are in the grass
		var running := 0.0
		if p != null and not p.dead:
			px = p.global_position.x - gx
			var above := top - p.global_position.y
			if px > -40.0 and px < ground.rect.size.x + 40.0 and above > -12.0 and above < 60.0:
				near = 1.0 - clampf(above / 60.0, 0.0, 1.0)
				running = clampf(absf(p.velocity.x) / 280.0, 0.0, 1.5) if p.is_on_floor() else 0.0
			# a hard landing on this ground: a ripple out through the grass
			var on := p.is_on_floor() and near > 0.6
			if on and not _was_floor and _vy > 420.0:
				_wave_x = px
				_wave_t = 0.0
				_wave_amp = clampf(_vy / 900.0, 0.5, 1.4)
				if front:
					_burst(Vector2(px, -2), 14, p)
			_was_floor = p.is_on_floor()
			_vy = p.velocity.y
		var wave_r0 := -1.0
		var wave_r1 := -1.0
		if _wave_t >= 0.0:
			wave_r0 = _wave_t * 420.0
			_wave_t += delta
			wave_r1 = _wave_t * 420.0
			if _wave_t > 0.7:
				_wave_t = -1.0
		var wave_k := clampf(1.0 - _wave_t / 0.7, 0.0, 1.0) * _wave_amp
		var damp := exp(-7.0 * delta)
		for i in range(i0, i1):
			var bx := _x[i]
			var wind := sin(t * 1.7 + bx * 0.045) * 0.1 + sin(t * 0.6 + bx * 0.011) * 0.07
			var target := wind
			var dx := bx - px
			if near > 0.0 and absf(dx) < 34.0:
				# pushed aside by his legs, and flattened the faster he goes
				target += signf(dx) * (1.0 - absf(dx) / 34.0) * (0.9 + 0.4 * running) * near
			if wave_r0 >= 0.0:
				var ad := absf(bx - _wave_x)
				if ad >= wave_r0 and ad < wave_r1:
					_vel[i] += signf(bx - _wave_x) * 14.0 * wave_k
			# a spring, so it overshoots and wobbles back
			_vel[i] += (target - _bend[i]) * 160.0 * delta
			_vel[i] *= damp
			_bend[i] += _vel[i] * delta
		if front:
			_update_flora(delta, px, near, running, p)
			_update_bits(delta)
			if p != null and near > 0.6 and running > 0.4:
				_bit_in -= delta
				if _bit_in <= 0.0:
					_bit_in = 0.07
					_kick(Vector2(px, -2), p)
		queue_redraw()

	func _kick(at: Vector2, p: CaveMan) -> void:
		var burning := p.sun_t > 0.0
		for k in 2:
			var col: Color = (Sunfire.HOT if randf() < 0.6 else Sunfire.GOLD) if burning else GREENS[randi() % GREENS.size()]
			_bits.append([at + Vector2(randf_range(-6, 6), 0), Vector2(-p.velocity.x * 0.25 + randf_range(-40, 40), randf_range(-210, -110)), randf_range(0.35, 0.6), col, burning])
		if randf() < 0.25:
			_bits.append([at + Vector2(randf_range(-8, 8), -4), Vector2(randf_range(-30, 30), randf_range(-160, -90)), 0.5, Color("d8f4ff"), true])
		# now and then a firefly lifts out of the grass he runs through
		if randf() < 0.09:
			_bits.append([at + Vector2(randf_range(-20, 20), -6), Vector2(randf_range(-20, 20), randf_range(-60, -35)), randf_range(2.5, 4.0), Color("d8ff6a") if randf() < 0.6 else Color("7dffc0"), true, "fly"])

	func _burst(at: Vector2, n: int, p: CaveMan) -> void:
		for k in n:
			var a := randf_range(PI * 1.05, PI * 1.95)
			var col: Color = GREENS[randi() % GREENS.size()] if p.sun_t <= 0.0 else Sunfire.HOT
			_bits.append([at, Vector2.from_angle(a) * randf_range(120, 260), randf_range(0.4, 0.7), col, p.sun_t > 0.0])
		for k in 5:
			_bits.append([at + Vector2(randf_range(-20, 20), -3), Vector2(randf_range(-60, 60), randf_range(-200, -120)), 0.6, Color("d8f4ff"), true])

	func _update_bits(delta: float) -> void:
		for bit in _bits:
			bit[2] = float(bit[2]) - delta
			if bit.size() > 5:
				# fireflies: a lazy, wobbling climb
				bit[1] = Vector2(sin(t * 3.0 + float(bit[2]) * 5.0) * 26.0, minf((bit[1] as Vector2).y + 4.0 * delta, -18.0))
			else:
				bit[1] = (bit[1] as Vector2) + Vector2(0, 520.0) * delta
			bit[0] = (bit[0] as Vector2) + (bit[1] as Vector2) * delta
		_bits = _bits.filter(func(bit): return float(bit[2]) > 0.0)

	func _update_flora(delta: float, px: float, near: float, running: float, p: CaveMan) -> void:
		for f in _flora:
			var dx: float = absf(float(f[0]) - px)
			# open as he comes close, stay open a while after he passes
			if dx < 110.0 and near > 0.0:
				f[4] = 3.5
			f[4] = maxf(float(f[4]) - delta, 0.0)
			f[3] = move_toward(float(f[3]), 1.0 if float(f[4]) > 0.0 else 0.0, delta * (2.5 if float(f[4]) > 0.0 else 0.6))
			f[5] = maxf(float(f[5]) - delta * 3.0, 0.0)
			if f[1] == "shroom" and dx < 14.0 and near > 0.8 and float(f[5]) <= 0.0 and p.is_on_floor():
				# stepped on: it squashes and puffs a cloud of glowing spores
				f[5] = 1.0
				var col: Color = SHROOMS[f[2]]
				for k in 9:
					_bits.append([Vector2(float(f[0]), -10), Vector2(randf_range(-70, 70), randf_range(-160, -60)), randf_range(0.8, 1.4), col, true, "spore"])

	func _draw() -> void:
		if not ground.in_view():
			return
		var b := Batch.new()
		var cx := Turf._cam_x(self) - ground.global_position.x
		var i0 := clampi(int((cx - Turf.reach(self)) / _step), 0, _x.size())
		var i1 := clampi(int((cx + Turf.reach(self)) / _step) + 1, 0, _x.size())
		var shade := 0.0 if front else 0.18
		for i in range(i0, i1):
			if _h[i] <= 0.0:
				continue                    # bare: rock stands here (Ground.bare)
			var a := _bend[i]
			var hgt := _h[i] * (1.0 - 0.35 * minf(absf(a), 1.2))
			var base := Vector2(_x[i], 2.0)
			var mid := base + Vector2(sin(a * 0.5), -cos(a * 0.5)) * hgt * 0.55
			var tip := mid + Vector2(sin(a), -cos(a)) * hgt * 0.45
			var col: Color = GREENS[_col[i]]
			col = col.darkened(shade)
			# a quad up to the bend and a triangle to the tip: no triangulating needed
			b.quad(base + Vector2(-2.4, 0), mid + Vector2(-1.4, 0), mid + Vector2(1.4, 0), base + Vector2(2.4, 0), col)
			b.tri(mid + Vector2(-1.4, 0), tip, mid + Vector2(1.4, 0), col)
			if front and i % 3 == 0:
				b.line(base + Vector2(0.6, -1), mid, col.lightened(0.25), 1.0)
		if front:
			_draw_flora(b, cx)
			for bit in _bits:
				var q: float = clampf(float(bit[2]) / 0.6, 0.0, 1.0)
				var col2: Color = bit[3]
				var r := 1.6 if bit.size() > 5 else 2.2
				b.circle(bit[0], r * (0.6 + 0.4 * q) + 0.5, Color(col2, 0.95 if bit.size() > 5 else q), 6)
		b.draw(self)

	func _draw_flora(b: Batch, cx: float) -> void:
		for f in _flora:
			var x: float = f[0]
			if absf(x - cx) > Turf.reach(self):
				continue
			var open: float = f[3]
			var sway := sin(t * 1.5 + x) * 1.5
			if f[1] == "shroom":
				var sq: float = f[5]
				var col: Color = SHROOMS[f[2]]
				var sy := 1.0 - 0.45 * sq
				var stem_top := Vector2(x + sway * 0.3, -9.0 * sy)
				b.line(Vector2(x, 2), stem_top, Color("e8e0cc"), 3.5)
				var cap := PackedVector2Array()
				for j in 9:
					var a := PI + PI * j / 8.0
					cap.append(stem_top + Vector2(cos(a) * 8.0 * (1.0 + 0.3 * sq), sin(a) * 6.0 * sy))
				b.poly(cap, col.darkened(0.45 - 0.35 * open))
				b.circle(stem_top + Vector2(-3, -3 * sy), 1.4, Color(1, 1, 1, 0.7), 6)
				b.circle(stem_top + Vector2(2, -4 * sy), 1.1, Color(1, 1, 1, 0.6), 6)
			else:
				var col3: Color = PETALS[f[2]]
				var head := Vector2(x + sway, -16.0 - 3.0 * open)
				b.line(Vector2(x, 2), head, Color("3f7a3a"), 2.0)
				b.tri(Vector2(x, -4), Vector2(x - 7, -8), Vector2(x - 1, -9), Color("4f9a4c"))
				if open < 0.15:
					# a closed bud
					b.circle(head, 3.2, col3.darkened(0.5), 8)
				else:
					for j in 5:
						var a2 := j * TAU / 5.0 + t * 0.4 * open
						b.circle(head + Vector2.from_angle(a2) * 4.5 * open, 3.4 * open + 0.6, col3.darkened(0.25 * (1.0 - open)), 8)
					b.circle(head, 2.6, Color("fff3b0"), 8)

	## The glowing bits: open flowers, mushroom caps, spores, fireflies, dew.
	func draw_flora_glow(g, cam_x: float) -> void:
		var o := global_position
		for f in _flora:
			var p := o + Vector2(float(f[0]), 0)
			if absf(p.x - cam_x) > Turf.reach(self):
				continue
			var open: float = f[3]
			if f[1] == "shroom":
				var col: Color = SHROOMS[f[2]]
				g.draw_circle(p + Vector2(0, -12), 9.0 + 7.0 * open, Color(col, 0.12 + 0.25 * open + 0.3 * float(f[5])))
			elif open > 0.1:
				var col3: Color = PETALS[f[2]]
				g.draw_circle(p + Vector2(0, -18), 6.0 + 10.0 * open, Color(col3, 0.3 * open))
				g.draw_circle(p + Vector2(0, -18), 2.5, Color(1, 0.95, 0.7, 0.8 * open))
		for bit in _bits:
			if bit.size() < 5 or not bit[4]:
				continue
			var q: float = clampf(float(bit[2]) / 0.8, 0.0, 1.0)
			var col2: Color = bit[3]
			var pulse := 1.0
			if bit.size() > 5 and bit[5] == "fly":
				pulse = 0.55 + 0.45 * sin(t * 9.0 + float(bit[2]) * 7.0)
			g.draw_circle(o + (bit[0] as Vector2), 7.0 * pulse, Color(col2, 0.35 * q))
			g.draw_circle(o + (bit[0] as Vector2), 2.0, Color(col2.lightened(0.4), 0.9 * q))


## ================================================================ GLOW PROXY
class GlowProxy extends Node2D:
	## The glow layer skips things whose position is far from the camera — and
	## a long stretch of ground starts far to the left. So this little node
	## rides along under the camera and draws the ground's glow for it.
	var ground: Ground

	func _ready() -> void:
		add_to_group("glow")

	func _process(_delta: float) -> void:
		if ground.in_view():
			global_position = Vector2(Turf._cam_x(self), ground.global_position.y)
		else:
			position = Vector2(-99999.0, 0)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		if ground.in_view():
			ground.draw_turf_glow(g, Turf._cam_x(self))
