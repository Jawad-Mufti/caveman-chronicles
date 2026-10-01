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
	## A slab of pale stone hanging in the air. Land on it from above, jump up
	## through it from below. It glows along its lip, so it reads even in the
	## Long Dark — and a lamp rock is also a real light there.
	var w := 120.0
	var lamp := false
	var has_pad := false
	var tint := Color("bcd8ff")
	var t := 0.0

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
		# the body: a chunk of rock, ragged underneath, deeper in the middle
		var deep := clampf(w * 0.42, 34.0, 62.0)
		var body := PackedVector2Array([Vector2(0, 0), Vector2(w, 0)])
		var n := maxi(int(w / 20.0), 3)
		for i in range(n, -1, -1):
			var k := float(i) / n
			var d := deep * (1.0 - pow(absf(k - 0.5) * 2.0, 1.8)) * rng.randf_range(0.78, 1.0)
			body.append(Vector2(w * k, 10.0 + d))
		bt.poly(body, Color("4c5675"))
		var lit := PackedVector2Array([Vector2(0, 0), Vector2(w, 0)])
		for i in range(n, -1, -1):
			var k2 := float(i) / n
			lit.append(Vector2(w * k2, 6.0 + (deep * 0.55) * (1.0 - pow(absf(k2 - 0.5) * 2.0, 1.6))))
		bt.poly(lit, Color("66729a"))
		bt.rect(Rect2(0, 0, w, 9), Color("8b98b8"))
		bt.rect(Rect2(0, 0, w, 4), Color("d6e4f7"))
		# cracks, and a carved star on the face
		for i in int(w / 45.0) + 1:
			var cx := rng.randf_range(10.0, maxf(11.0, w - 10.0))
			bt.line(Vector2(cx, 10), Vector2(cx + rng.randf_range(-7.0, 7.0), 10.0 + rng.randf_range(12.0, deep * 0.6)), Color("3a4260"), 1.6)
		var sc := Vector2(w * 0.5, 14.0 + deep * 0.3)
		bt.poly(PackedVector2Array([sc + Vector2(0, -7), sc + Vector2(2, -2), sc + Vector2(7, 0), sc + Vector2(2, 2), sc + Vector2(0, 7), sc + Vector2(-2, 2), sc + Vector2(-7, 0), sc + Vector2(-2, -2)]), Color("cfe0ff", 0.55))
		# roots trailing down from the underside, with a small crystal at the end
		for i in 2:
			var rx := w * (0.28 + 0.44 * i) + rng.randf_range(-6.0, 6.0)
			var ry := 12.0 + deep * 0.75
			var rl := rng.randf_range(16.0, 30.0)
			bt.polyline(PackedVector2Array([Vector2(rx, ry), Vector2(rx + 3.0, ry + rl * 0.5), Vector2(rx - 2.0, ry + rl)]), Color("3b4a52"), 2.0)
			bt.poly(PackedVector2Array([Vector2(rx - 3.0 - 2.0, ry + rl), Vector2(rx - 2.0, ry + rl + 9.0), Vector2(rx + 1.0, ry + rl)]), Color("9fe6ff", 0.9))
		bt.draw(self)

	func draw_glow(g: Node2D) -> void:
		var tt := Time.get_ticks_msec() / 1000.0 + t
		var o := global_position
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
				g.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.25, 0), c + Vector2(0, r), c + Vector2(-r * 0.25, 0)]), Color(1, 1, 1, k))
				g.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(0, r * 0.25), c + Vector2(r, 0), c + Vector2(0, -r * 0.25)]), Color(1, 1, 1, k))


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

	func draw_glow(g: Node2D) -> void:
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

	func draw_glow(g: Node2D) -> void:
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

	func draw_glow(g: Node2D) -> void:
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
