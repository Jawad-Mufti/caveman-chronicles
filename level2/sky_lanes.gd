## The sky lanes: optional roads of floating stone, high above the ground road.
## A springy bloom on the ground throws him up to the first rock; from there it
## is hopping and bouncing from stone to stone, with shells strung along the
## way and a cache at the top. The ground always catches him if he falls (a
## lane is only dangerous where the road below is a pit), and every lane steps
## back down to the ground at its end.
class_name SkyLanes
extends RefCounted


## ================================================================ SKY ROCK
class SkyRock extends StaticBody2D:
	## A little floating island: a grassy top over soil and rock that tapers to a
	## point, roots hanging out underneath. Land on it from above, jump up
	## through it from below. It glows along its lip, so it reads even in the
	## Long Dark — and a lamp island (crystals at its tip) is a real light there.
	var w := 120.0
	var lamp := false
	var has_pad := false
	var tint := Color("bcd8ff")
	var t := 0.0
	## Its outline, kept from _draw: the glow layer draws a moonlit copy of it
	## over the dark, so a lane reads at night without his torch.
	var _outline := PackedVector2Array()

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(w, 14)
		cs.shape = sh
		cs.position = Vector2(w * 0.5, 7)
		cs.one_way_collision = true
		add_child(cs)
		add_to_group("glow")
		if lamp:
			add_to_group("light")
		t = randf() * 6.0

	func light() -> Vector4:
		return Vector4(global_position.x + w * 0.5, global_position.y - 26.0, 150.0, 0.0)

	func light_strength() -> float:
		return 0.0

	func _draw() -> void:
		var bt := Batch.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = int(position.x) * 7 + int(position.y) * 3
		# a little floating island: a grassy cap, then soil and rock tapering to a
		# ragged point underneath, with roots hanging out of it
		var deep := clampf(w * 0.75, 50.0, 110.0)
		var n := maxi(int(w / 16.0), 4)
		var depth := PackedFloat32Array()
		for i in n + 1:
			var k := float(i) / n
			depth.append(deep * pow(1.0 - absf(k - 0.5) * 2.0, 0.75) * rng.randf_range(0.82, 1.0))
		var tip_x := w * 0.5
		var tip_d := 0.0
		for i in n + 1:
			if depth[i] > tip_d:
				tip_d = depth[i]
				tip_x = w * float(i) / n
		var rock := PackedVector2Array([Vector2(-3, 4), Vector2(w + 3, 4)])
		var soil := PackedVector2Array([Vector2(-3, 4), Vector2(w + 3, 4)])
		for i in range(n, -1, -1):
			var x := w * float(i) / n
			rock.append(Vector2(x, 6.0 + depth[i]))
			soil.append(Vector2(x, 6.0 + depth[i] * 0.42))
		bt.poly(rock, Color("3e4660"))
		_outline = rock
		bt.poly(soil, Color("4f3d2f"))
		bt.polyline(soil.slice(2), Color("3a2c22"), 2.0)
		# stones set in the rock, and in the soil
		for i in int(w / 30.0) + 1:
			var k := rng.randf_range(0.2, 0.8)
			var sx := w * k
			var sd := depth[int(round(k * n))]
			bt.circle(Vector2(sx, 6.0 + sd * rng.randf_range(0.5, 0.75)), rng.randf_range(3.0, 5.5), Color("566079"), 8)
			bt.circle(Vector2(w * rng.randf_range(0.1, 0.9), 6.0 + rng.randf_range(4.0, 9.0)), rng.randf_range(1.5, 2.5), Color("6b5643"), 6)
		# roots hanging from the underside
		for i in 3:
			var k := 0.3 + 0.2 * i + rng.randf_range(-0.05, 0.05)
			var rx := w * k
			var ry := 4.0 + depth[int(round(k * n))]
			var rl := rng.randf_range(16.0, 38.0)
			bt.polyline(PackedVector2Array([Vector2(rx, ry), Vector2(rx + 4.0, ry + rl * 0.45), Vector2(rx - 2.0, ry + rl)]), Color("3b2f26"), 2.0)
			bt.line(Vector2(rx + 3.0, ry + rl * 0.4), Vector2(rx + 9.0, ry + rl * 0.6), Color("3b2f26"), 1.2)
		if lamp:
			# a cluster of crystals at the tip: it lights the way
			var c := Vector2(tip_x, 2.0 + tip_d)
			bt.tri(c + Vector2(-7, 0), c + Vector2(-3, 18), c + Vector2(1, 0), Color("9fe6ff", 0.95))
			bt.tri(c + Vector2(-1, 0), c + Vector2(4, 13), c + Vector2(8, 0), Color("c9f6ff", 0.95))
		else:
			# a few pebbles drifting under the point
			bt.circle(Vector2(tip_x - 6.0, 14.0 + tip_d), 3.0, Color("4c5675"), 8)
			bt.circle(Vector2(tip_x + 7.0, 24.0 + tip_d), 2.0, Color("4c5675"), 6)
		# a vine trailing over the edge of the wider ones
		if w >= 140.0:
			var vx := w * 0.82
			var vl := rng.randf_range(40.0, 64.0)
			bt.polyline(PackedVector2Array([Vector2(vx, 4), Vector2(vx + 4.0, 4.0 + vl * 0.5), Vector2(vx, 4.0 + vl)]), Color("2c5236"), 2.0)
			for j in 4:
				var ly := 12.0 + j * vl / 4.5
				bt.circle(Vector2(vx + (3.0 if j % 2 == 0 else -2.0), ly), 3.2, Color("3f7a48"), 6)
		# the grass cap, curling over the edges
		bt.rect(Rect2(-4, -2, w + 8, 9), Color("2f5a3a"))
		bt.rect(Rect2(-4, -2, w + 8, 3), Color("5c9a5e"))
		for i in int(w / 20.0) + 2:
			var gx := -2.0 + rng.randf_range(0.0, w + 4.0)
			bt.tri(Vector2(gx - 3.0, 6), Vector2(gx + 3.0, 6), Vector2(gx, 6.0 + rng.randf_range(4.0, 10.0)), Color("2f5a3a"))
		for i in int(w / 13.0):
			var tx := rng.randf_range(2.0, w - 2.0)
			bt.tri(Vector2(tx - 2.0, -1), Vector2(tx + 2.0, -1), Vector2(tx + rng.randf_range(-2.0, 2.0), -rng.randf_range(4.0, 8.0)), Color("4f8a52"))
		# a bush on the broad ones, out at one end
		if w >= 160.0:
			var bx := w * 0.12
			bt.circle(Vector2(bx, -6), 9.0, Color("2c5236"), 10)
			bt.circle(Vector2(bx + 10.0, -9), 8.0, Color("2c5236"), 10)
			bt.circle(Vector2(bx + 3.0, -10), 4.0, Color("4a7d4f"), 8)
		bt.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var tt := Time.get_ticks_msec() / 1000.0 + t
		var o := global_position
		# moonlight on the island itself, over the dark: a pale silhouette, its
		# grassy top silvered, so the way across shows even without the torch
		if _outline.size() > 2:
			g.draw_set_transform(o)
			g.draw_colored_polygon(_outline, Color("b0a497", 0.27))
			g.draw_set_transform(Vector2.ZERO)
		g.draw_line(o + Vector2(-4, 1), o + Vector2(w + 4, 1), Color("9fd6a6", 0.75), 4.0)
		# a soft halo, and a bright lip
		g.draw_circle(o + Vector2(w * 0.5, 14.0), w * 0.55 + 10.0, Color(tint, 0.05 + (0.03 if lamp else 0.0)))
		g.draw_line(o + Vector2(3, 0.5), o + Vector2(w - 3, 0.5), Color(tint, 0.6), 2.0)
		g.draw_line(o + Vector2(6, 3.0), o + Vector2(w - 6, 3.0), Color(tint, 0.18), 3.0)
		# moss lights along the lip
		var cnt := int(w / 26.0)
		for i in cnt:
			var on := 0.5 + 0.5 * sin(tt * 1.7 + i * 1.9)
			g.draw_circle(o + Vector2(10.0 + i * (w - 20.0) / maxf(cnt - 1, 1), -1.5), 1.8 + on * 0.8, Color("c9fff4", 0.3 + 0.5 * on))
		# now and then a glint
		var spark := fmod(tt * 0.45, 2.6)
		if spark < 0.4:
			var k := sin(spark / 0.4 * PI)
			var c := o + Vector2(w * (0.25 + 0.5 * fmod(absf(sin(t * 7.0)), 1.0)), -5.0)
			var r := 7.0 * k
			if r > 1.5:
				Treasure.glint(g, c, r, Color(1, 1, 1, k))


## ================================================================ CACHE
class SkyCache extends Treasure.Breakable:
	## A cairn of pale stones with a star on top, at the top of a lane. Two hits,
	## and a fountain of shells — thrown gently, so they land on the rock.
	func _init() -> void:
		kind = "stash"

	func _pop(i: int, from_dir: int, fountain: bool) -> void:
		var tid := "%s_%d" % [id, i]
		if GameState.is_taken(level_id, tid):
			return
		var p := Treasure.Pickup.new()
		p.kind = contents[i]
		p.level_id = level_id
		p.id = tid
		p.position = global_position + Vector2(0, -30)
		if fountain:
			p.vel = Vector2(randf_range(-60, 60), randf_range(-640, -520))
		else:
			p.vel = Vector2(randf_range(-50, 50) - from_dir * 20.0, randf_range(-440, -340))
		p.floor_y = global_position.y
		var level := get_parent()
		if level.has_method("_on_treasure_popped"):
			level._on_treasure_popped(p)
		level.call_deferred("add_child", p)

	func _draw() -> void:
		var b := Batch.new()
		var stones := [[Vector2(-22, -10), 13.0], [Vector2(2, -9), 15.0], [Vector2(24, -9), 12.0], [Vector2(-9, -26), 12.0], [Vector2(13, -25), 11.0]]
		for s in stones:
			var at: Vector2 = s[0]
			var r: float = s[1]
			b.circle(at, r, Color("4c5675"), 12)
			b.circle(at + Vector2(-2, -2), r * 0.82, Color("7f8db0"), 12)
			b.circle(at + Vector2(-r * 0.3, -r * 0.35), r * 0.3, Color("d6e4f7"), 8)
		# the star on top
		var sc := Vector2(2, -46)
		b.poly(PackedVector2Array([sc + Vector2(0, -12), sc + Vector2(3, -3), sc + Vector2(12, 0), sc + Vector2(3, 3), sc + Vector2(0, 12), sc + Vector2(-3, 3), sc + Vector2(-12, 0), sc + Vector2(-3, -3)]), Color("fff3c4"))
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		if hits <= 0:
			return
		var tt := Time.get_ticks_msec() / 1000.0 + _t
		var pulse := 0.5 + 0.5 * sin(tt * 2.2)
		var c := global_position + Vector2(2, -46)
		g.draw_circle(c, 34.0 + pulse * 6.0, Color("fff3c4", 0.10 + 0.05 * pulse))
		g.draw_circle(c, 15.0, Color("fff3c4", 0.22))
		for i in 4:
			var a := tt * 0.9 + i * TAU / 4.0
			g.draw_circle(c + Vector2(cos(a), sin(a) * 0.5) * (22.0 + pulse * 4.0), 1.6, Color(1, 1, 1, 0.7))


## ================================================================ MOTES
class StarMotes extends Node2D:
	## Pale specks drifting in the air around a lane — so the sky up there is
	## not empty, and so the road can be seen from far below.
	var width := 700.0
	var height := 380.0
	var n := 16
	var tint := Color("d9ecff")
	var _seed: Array = []        ## [x, y, phase, speed, size]

	func _ready() -> void:
		add_to_group("glow")
		var rng := RandomNumberGenerator.new()
		rng.seed = int(position.x) * 11 + 3
		for i in n:
			_seed.append([rng.randf_range(-width * 0.5, width * 0.5), rng.randf_range(-height * 0.5, height * 0.5),
				rng.randf_range(0.0, TAU), rng.randf_range(0.25, 0.7), rng.randf_range(1.2, 2.6)])

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var tt := Time.get_ticks_msec() / 1000.0
		for s in _seed:
			var ph: float = s[2]
			var sp: float = s[3]
			var x: float = float(s[0]) + sin(tt * sp + ph) * 22.0
			var y: float = float(s[1]) + cos(tt * sp * 0.8 + ph) * 16.0 - fmod(tt * 4.0 + ph * 10.0, 40.0) * 0.0
			var a := 0.25 + 0.55 * (0.5 + 0.5 * sin(tt * 1.3 + ph * 2.0))
			g.draw_circle(global_position + Vector2(x, y), float(s[4]), Color(tint, a))


## ================================================================ BEACON
class Beacon extends Node2D:
	## Above the launch bloom: a slow column of sparks rising toward the first
	## stone, so that from the ground he can see where the road begins.
	var height := 340.0
	var tint := Color("d6ecff")

	func _ready() -> void:
		add_to_group("glow")

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var tt := Time.get_ticks_msec() / 1000.0
		for i in 7:
			var k := fmod(tt * 0.22 + i / 7.0, 1.0)
			var y := -36.0 - k * height
			var x := sin(tt * 1.4 + i * 2.3) * 9.0
			var a := sin(k * PI)
			g.draw_circle(global_position + Vector2(x, y), 2.2 + 1.6 * a, Color(tint, 0.65 * a))
		var pulse := 0.5 + 0.5 * sin(tt * 2.0)
		g.draw_circle(global_position + Vector2(0, -28), 40.0 + pulse * 6.0, Color(tint, 0.06 + 0.04 * pulse))


## ================================================================ LOOT
## The shells strung along a lane, worked out from its rocks. Each rock has a
## shell over it; each gap has one in the arc of the jump; each bounce bloom
## has a column going up; the first bloom (on the ground) does too.
## rocks: [x, top y, width, flags] (flags: 1 = bloom on it, 2 = lamp)
## returns [[x, y, kind], ...]
static func loot_for(ground_pad: Array, rocks: Array) -> Array:
	var out: Array = []
	var gx: float = ground_pad[0]
	var gy: float = ground_pad[1]
	for k in 3:
		out.append([gx, gy - 90.0 - k * 75.0, "shell"])
	for i in rocks.size():
		var r: Array = rocks[i]
		var cx: float = float(r[0]) + float(r[2]) * 0.5
		var top: float = r[1]
		var has_pad: bool = (int(r[3]) & 1) != 0
		if has_pad:
			for k in 3:
				out.append([cx, top - 90.0 - k * 75.0, "shell"])
		else:
			out.append([cx, top - 30.0, "bone" if i % 3 == 2 else "shell"])
		if i + 1 < rocks.size():
			var n: Array = rocks[i + 1]
			var gap := float(n[0]) - (float(r[0]) + float(r[2]))
			if gap > 45.0:
				out.append([float(r[0]) + float(r[2]) + gap * 0.5, minf(top, float(n[1])) - 64.0, "shell"])
	return out
