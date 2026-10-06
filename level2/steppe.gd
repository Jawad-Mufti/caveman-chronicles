## The Mammoth Steppe: the open ground between the mountain's foot and the
## great tree. A split rock to climb by jumping from wall to wall, a herd of
## mammoths on the path (mind the feet; ride the backs), a river only the old
## bull wades, and a mammoth graveyard under the tree.
class_name Steppe
extends RefCounted


## ================================================================ KICK WALL
class KickWall extends StaticBody2D:
	## A face of rock he can jump from, to the wall opposite. Its face is
	## scuffed with old hand- and footholds, so it reads as "climb me".
	## With a top (the cliff), it is also ground to stand on.
	var w := 60.0
	var h := 380.0
	var grassy := false

	func _init(rect: Rect2 = Rect2(0, 0, 60, 380), top_grass: bool = false) -> void:
		position = rect.position
		w = rect.size.x
		h = rect.size.y
		grassy = top_grass

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		add_to_group("kick_wall")
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(w, h)
		cs.shape = sh
		cs.position = Vector2(w * 0.5, h * 0.5)
		add_child(cs)
		# painted layered stone (common/art), like the mountain's rock
		Terrain.paint_poly(self, PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			"res://common/art/rock_layers.png", Color(0.7, 0.64, 0.6), position)

	func _draw() -> void:
		var b := Batch.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = int(position.x) * 13 + int(position.y)
		# (painted underneath) moonlit edges, darker toward the foot, an outline
		b.rect(Rect2(0, 0, 6, h), Color(1.0, 0.95, 0.85, 0.12))
		b.rect(Rect2(w - 6, 0, 6, h), Color(1.0, 0.95, 0.85, 0.12))
		b.quad(Vector2(0, h * 0.4), Vector2(w, h * 0.4), Vector2(w, h), Vector2(0, h), Color.BLACK,
			PackedColorArray([Color(0.04, 0.03, 0.06, 0.0), Color(0.04, 0.03, 0.06, 0.0), Color(0.04, 0.03, 0.06, 0.5), Color(0.04, 0.03, 0.06, 0.5)]))
		b.polyline(PackedVector2Array([Vector2(0, h), Vector2(0, 0), Vector2(w, 0), Vector2(w, h)]), Color("1d1712"), 3.0)
		# strata
		var y := 30.0
		while y < h - 10.0:
			b.line(Vector2(4, y), Vector2(w - 4, y + rng.randf_range(-6.0, 6.0)), Color(0.15, 0.11, 0.09, 0.45), 2.0)
			y += rng.randf_range(40.0, 70.0)
		# holds on both faces: little ledges, scuffed pale
		var hy := 40.0
		while hy < h - 20.0:
			for side in [0.0, w - 12.0]:
				b.rect(Rect2(side + rng.randf_range(0.0, 2.0), hy + rng.randf_range(-8.0, 8.0), 12, 5), Color("c2b29a"))
			hy += rng.randf_range(55.0, 75.0)
		# scrape marks, where others have climbed
		for i in int(h / 90.0):
			var sx: float = 3.0 if i % 2 == 0 else w - 10.0
			var sy := rng.randf_range(30.0, h - 40.0)
			for k in 3:
				b.line(Vector2(sx + k * 3.0, sy), Vector2(sx + k * 3.0 + 2.0, sy + 16.0), Color("b3a38c"), 1.2)
		if grassy:
			b.rect(Rect2(-3, -3, w + 6, 9), Color("3e6b2c"))
			b.rect(Rect2(-3, -3, w + 6, 3), Color("7fb85a"))
			for i in int(w / 14.0):
				var tx := rng.randf_range(2.0, w - 2.0)
				b.tri(Vector2(tx - 2.0, -2), Vector2(tx + 2.0, -2), Vector2(tx, -rng.randf_range(5.0, 9.0)), Color("4f8a52"))
		else:
			b.rect(Rect2(0, 0, w, 4), Color("c2b29a"))
		b.draw(self)


## ================================================================ MAMMOTH
class Mammoth extends AnimatableBody2D:
	## A woolly mammoth walking to and fro on a beat. Its back is a broad
	## one-way platform that carries him; its feet stomp (1 heart, a shove).
	## A wading one walks deeper, through the river, with its feet underwater.
	var x0 := 0.0
	var x1 := 300.0
	var speed := 70.0
	var size := 1.0
	var dirn := 1.0
	var rest := 1.4
	var _pause := 0.0
	var _ph := 0.0
	var _t := 0.0
	var _feet: Area2D
	const BACK := 175.0        ## height of the back, at size 1

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		sync_to_physics = true
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(150.0 * size, 12.0)
		cs.shape = sh
		cs.position = Vector2(0, -BACK * size + 6.0)
		cs.one_way_collision = true
		add_child(cs)
		_feet = Area2D.new()
		_feet.collision_layer = 0
		_feet.collision_mask = 2
		var fs := CollisionShape2D.new()
		var fsh := RectangleShape2D.new()
		fsh.size = Vector2(190.0 * size, 80.0 * size)
		fs.shape = fsh
		fs.position = Vector2(0, -40.0 * size)
		_feet.add_child(fs)
		add_child(_feet)
		_t = randf() * 4.0
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS     # painted fur: smooth, not blocky
		_build_skin()

	func _physics_process(delta: float) -> void:
		_t += delta
		if _pause > 0.0:
			_pause -= delta
		else:
			position.x += dirn * speed * delta
			_ph += delta * speed / (95.0 * size)
			if dirn > 0.0 and position.x >= x1:
				position.x = x1
				dirn = -1.0
				_pause = rest
			elif dirn < 0.0 and position.x <= x0:
				position.x = x0
				dirn = 1.0
				_pause = rest
		var p := get_tree().get_first_node_in_group("player") as CaveMan
		if p != null and not p.dead and _feet.overlaps_body(p):
			# riding on its back is safe; it's the feet that stomp
			if p.global_position.y > global_position.y - BACK * size * 0.6:
				p.hurt(1, global_position.x)
		if NightWoods.near_view(self):
			queue_redraw()
			_far.queue_redraw()
		_skin.scale.x = dirn

	func _v(x: float, y: float) -> Vector2:
		return Vector2(x * dirn, y) * size

	## Its silhouette (body, hump, head, ear as one shape), facing right, at its
	## size: painted with real fur once (common/art/fur.png), turned with it.
	const FUR := "res://common/art/fur.png"
	const FUR_TINT := Color(0.86, 0.78, 0.78)
	var _sil := PackedVector2Array()
	var _skin: Node2D
	var _far: Node2D
	var _fur: Texture2D

	func _build_skin() -> void:
		var parts := [_oval_pts(Vector2(-8, -118), Vector2(112, 58), 30)]
		for c in [[Vector2(48, -150), 48.0], [Vector2(30, -164), 28.0], [Vector2(104, -138), 38.0], [Vector2(98, -166), 26.0], [Vector2(94, -174), 17.0]]:
			parts.append(_oval_pts(c[0], Vector2(c[1], c[1]), 18))
		var sil: PackedVector2Array = parts[0]
		for i in range(1, parts.size()):
			var merged := Geometry2D.merge_polygons(sil, parts[i])
			for m in merged:
				if not Geometry2D.is_polygon_clockwise(m) or merged.size() == 1:
					sil = m
					break
		for i in sil.size():
			sil[i] = sil[i] * size
		_sil = sil
		_fur = load(FUR) as Texture2D
		# far legs behind the body, then the painted body, then (in _draw) the rest
		_far = Node2D.new()
		_far.show_behind_parent = true
		_far.z_index = -1
		_far.draw.connect(func() -> void:
			for l in [[-62.0, 0.0], [52.0, 0.25]]:
				_leg_tex(_far, l[0], l[1], _pause <= 0.0, Color(0.55, 0.48, 0.5)))
		add_child(_far)
		_skin = Node2D.new()
		_skin.show_behind_parent = true
		add_child(_skin)
		Terrain.paint_poly(_skin, _sil, FUR, FUR_TINT, Vector2(randf() * 300.0, 0))

	func _oval_pts(c: Vector2, r: Vector2, n: int) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in n:
			var a := TAU * i / n
			var p := Vector2(cos(a) * r.x, sin(a) * r.y)
			if r.x > 100.0 and p.y < 0.0 and p.x > 0.0:
				p.y -= sin(-a) * 14.0          # the shoulder hump
			pts.append(c + p)
		return pts

	func _draw() -> void:
		var b := Batch.new()
		var dark := Color("3e2a1c")
		var rim := Color("b08a62")
		var moving := _pause <= 0.0
		var f := dirn
		# the tail
		b.polyline(PackedVector2Array([_v(-118, -128), _v(-128, -112), _v(-126, -96)]), dark, 4.0 * size)
		b.circle(_v(-126, -94), 6.0 * size, dark, 8)
		# shading over the painted coat: dark toward the belly, a fan from its middle
		var mid := Vector2(0, -130) * size
		for i in _sil.size():
			var a: Vector2 = _sil[i]
			var c: Vector2 = _sil[(i + 1) % _sil.size()]
			var ka := clampf((a.y / size + 150.0) / 90.0, 0.0, 1.0)
			var kc := clampf((c.y / size + 150.0) / 90.0, 0.0, 1.0)
			b.tri_cols(Vector2(mid.x * f, mid.y), Vector2(a.x * f, a.y), Vector2(c.x * f, c.y),
				Color(0.05, 0.03, 0.02, 0.0), Color(0.05, 0.03, 0.02, 0.55 * ka), Color(0.05, 0.03, 0.02, 0.55 * kc))
		# the cheek in shadow, and the outline round the whole coat
		b.ellipse(_v(80, -134), 15.0 * size, 12.0 * size, Color(0.08, 0.05, 0.03, 0.4))
		var ring := PackedVector2Array()
		for p in _sil:
			ring.append(Vector2(p.x * f, p.y))
		ring.append(ring[0])
		b.polyline(ring, Color("1d1712"), 3.5 * size)
		# the fringe of long hair under the belly, swinging
		var x := -104.0
		while x < 96.0:
			b.tri(_v(x, -74), _v(x + 14.0, -74), _v(x + 7.0, -52 + sin(_t * 2.0 + x) * 3.0), dark)
			b.line(_v(x + 4.0, -72), _v(x + 6.0, -58 + sin(_t * 2.0 + x) * 3.0), Color(rim, 0.5), 1.5 * size)
			x += 12.0
		# the ear's inside, an eye
		b.ellipse(_v(95, -173), 9.0 * size, 11.0 * size, Color(0.1, 0.06, 0.04, 0.45))
		b.circle(_v(116, -148), 3.8 * size, Color("1a120c"), 8)
		b.circle(_v(117, -149), 1.4 * size, Color("fff4dd"), 6)
		b.line(_v(110, -154), _v(122, -156), Color("1d1712"), 2.0 * size)
		# the trunk, swaying: shaggy brown, darker at the tip
		var sway := sin(_t * 1.3) * 10.0
		var tp := PackedVector2Array()
		for i in 9:
			var k := i / 8.0
			tp.append(_v(128.0 + k * 14.0 + sway * k * k, -128.0 + k * 92.0 - k * k * 8.0))
		for i in tp.size():
			b.circle(tp[i], (12.5 - i * 0.8) * size, Color("1d1712"), 10)
		for i in tp.size():
			b.circle(tp[i], (11.0 - i * 0.8) * size, Color("6b4a32").lerp(dark, i / 9.0), 10)
		# wrinkle rings across it
		for i in range(1, tp.size() - 1):
			var d: Vector2 = (tp[i + 1] - tp[i - 1]).normalized()
			var n := Vector2(-d.y, d.x) * (9.0 - i * 0.7) * size
			b.line(tp[i] - n, tp[i] + n, Color(0.1, 0.06, 0.04, 0.55), 1.5 * size)
		# the tusks, long and curling up
		var tusk := PackedVector2Array([_v(118, -112), _v(140, -100), _v(166, -102), _v(184, -118), _v(188, -138)])
		b.polyline(tusk, Color("1d1712"), 11.0 * size)
		b.polyline(tusk, Color("cdbf9f"), 8.0 * size)
		b.polyline(tusk, Color("efe4c8"), 4.0 * size)
		# shaggy fur standing up along the back and hump
		var sp := [Vector2(-104, -150), Vector2(-70, -168), Vector2(-30, -178), Vector2(10, -190), Vector2(40, -198), Vector2(70, -196), Vector2(96, -188)]
		for i in sp.size() - 1:
			for k in 4:
				var q: Vector2 = (sp[i] as Vector2).lerp(sp[i + 1], k / 4.0)
				var l := 9.0 + sin(i * 3.1 + k) * 3.0
				b.tri(_v(q.x - 4.0, q.y + 4.0), _v(q.x + 4.0, q.y + 4.0), _v(q.x - 3.0 + sin(_t * 1.5 + q.x) * 1.5, q.y - l), Color("5a3d28"))
		# a moonlit rim along the back
		b.polyline(PackedVector2Array([_v(-110, -150), _v(-60, -172), _v(0, -184), _v(40, -196), _v(80, -192)]), Color(rim, 0.55), 3.0 * size)
		# the near legs, in fur, over the coat's lower edge
		for l in [[-74.0, 0.5], [40.0, 0.75]]:
			_leg_tex(self, l[0], l[1], moving, Color(0.8, 0.72, 0.72))
		b.draw(self)

	## One leg, in the fur: a tapering column and a round foot (drawn on `ci`).
	func _leg_tex(ci: CanvasItem, x: float, phase: float, moving: bool, tint: Color) -> void:
		var ph := (_ph + phase) * TAU
		var swing := sin(ph) if moving else 0.0
		var lift := maxf(0.0, cos(ph)) * 10.0 if moving else 0.0
		var hip := _v(x, -100)
		var foot := _v(x + swing * 16.0, -lift)
		# a pillar leg: wide at the top, a knee bulge, narrowing to the foot
		var knee := hip.lerp(foot, 0.55) + _v(swing * 4.0, 0) - Vector2(0, 0)
		var col := PackedVector2Array([hip + Vector2(-19, -6) * size, hip + Vector2(19, -6) * size, knee + Vector2(15, 0) * size,
			foot + Vector2(13, -8) * size, foot + Vector2(-13, -8) * size, knee + Vector2(-15, 0) * size])
		var tsz := _fur.get_size() * Terrain.TEXEL
		var uv := PackedVector2Array()
		for p in col:
			uv.append(p / tsz)
		ci.draw_colored_polygon(col, tint, uv, _fur)
		ci.draw_polyline(PackedVector2Array([col[1], col[2], col[3]]), Color("1d1712"), 2.5 * size)
		ci.draw_polyline(PackedVector2Array([col[0], col[5], col[4]]), Color("1d1712"), 2.5 * size)
		# shaggy hair hanging over the knee
		for k in 4:
			var hx := -12.0 + k * 8.0
			ci.draw_line(knee + Vector2(hx, -10) * size, knee + Vector2(hx + 1.0, 6) * size, Color(0.15, 0.09, 0.05, 0.6), 2.0 * size)
		ci.draw_circle(foot + Vector2(0, -6) * size, 15.5 * size, Color("1d1712"))
		ci.draw_circle(foot + Vector2(0, -6) * size, 13.5 * size, Color("4a3426"))
		# toenails
		for k in 3:
			ci.draw_circle(foot + Vector2(-7.0 + k * 7.0, -2.0) * size, 2.6 * size, Color("cdbf9f"))


## ================================================================ RIVER
class River extends Node2D:
	## Cold, deep and fast. Fall in and the current throws him back out on the
	## near bank (it costs a heart, like any fall). Drawn over the mammoth's
	## legs, so the wading bull's feet are under the water.
	signal swept
	var w := 500.0
	var top := 612.0
	var _t := 0.0
	var _area: Area2D

	func _ready() -> void:
		z_index = 1
		_area = Area2D.new()
		_area.collision_layer = 0
		_area.collision_mask = 2
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(w, 400)
		cs.shape = sh
		cs.position = Vector2(w * 0.5, top + 40.0 + 200.0)
		_area.add_child(cs)
		add_child(_area)

	func _physics_process(delta: float) -> void:
		_t += delta
		var p := get_tree().get_first_node_in_group("player") as CaveMan
		if p != null and not p.dead and _area.overlaps_body(p):
			swept.emit()
		if NightWoods.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		b.rect(Rect2(0, top, w, 420), Color("17293f"))
		b.rect(Rect2(0, top, w, 10), Color("2c4c6e"))
		b.rect(Rect2(0, top, w, 3), Color("7fa6c9"))
		# the current: streaks running downstream (to the right)
		for i in int(w / 40.0):
			var x := fmod(i * 47.0 + _t * 140.0, w)
			var y := top + 18.0 + float((i * 37) % 70)
			b.line(Vector2(x, y), Vector2(minf(x + 26.0, w), y), Color("4d7aa3", 0.6), 2.0)
		# foam at both banks
		for side in [0.0, w]:
			for k in 4:
				b.circle(Vector2(side + (6.0 if side == 0.0 else -6.0) * (k + 1), top + 4.0 + sin(_t * 3.0 + k) * 2.0), 5.0 - k, Color("cfe3f2", 0.7), 8)
		b.draw(self)


## ================================================================ BONES
class Skeleton extends Node2D:
	## An old mammoth, long dead: arched ribs, a spine, a skull with its tusks.
	## Scenery, behind everything.
	var size := 1.0

	func _ready() -> void:
		z_index = -1

	func _draw() -> void:
		var b := Batch.new()
		var bone := Color("b9ae94")
		var shade := Color("8a806b")
		var s := size
		# the spine, sagging, and the ribs hanging from it
		var spine := PackedVector2Array()
		for i in 9:
			var k := i / 8.0
			spine.append(Vector2(-110.0 + k * 210.0, -150.0 + sin(k * PI) * -18.0) * s)
		b.polyline(spine, bone, 9.0 * s)
		for i in 7:
			var k := (i + 1) / 8.0
			var top := Vector2(-110.0 + k * 210.0, -150.0 - sin(k * PI) * 18.0) * s
			var rib := PackedVector2Array([top, top + Vector2(-18, 50) * s, top + Vector2(-8, 110) * s, top + Vector2(12, 146) * s])
			b.polyline(rib, shade if i % 2 == 0 else bone, 7.0 * s)
		# the skull, and its tusks
		var sk := Vector2(130, -70) * s
		b.circle(sk, 34.0 * s, bone, 14)
		b.circle(sk + Vector2(-8, -24) * s, 22.0 * s, bone, 12)
		b.circle(sk + Vector2(10, -6) * s, 8.0 * s, Color("2a2420"), 8)
		var tusk := PackedVector2Array([sk + Vector2(14, 18) * s, sk + Vector2(50, 30) * s, sk + Vector2(86, 16) * s, sk + Vector2(100, -16) * s])
		b.polyline(tusk, Color("e6dcc3"), 9.0 * s)
		# scattered leg bones
		b.line(Vector2(-70, -4) * s, Vector2(-20, -10) * s, shade, 8.0 * s)
		b.line(Vector2(20, -6) * s, Vector2(64, -2) * s, bone, 8.0 * s)
		b.draw(self)
