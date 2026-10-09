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
		if _skin.scale.x != dirn:               # it turned: the still layers turn with it
			_coat.queue_redraw()
			_front.queue_redraw()
		_skin.scale.x = dirn

	func _v(x: float, y: float) -> Vector2:
		return Vector2(x * dirn, y) * size

	## Its silhouette, facing right, at its size: a real woolly mammoth's — the
	## high domed head, the shoulder hump right behind it, the back sloping down
	## to low hips. Painted with real fur once (common/art/fur.png), turned with it.
	## (The back stays a flat one-way platform at BACK: he rides the hump.)
	const FUR := "res://common/art/fur.png"
	const FUR_TINT := Color(1.0, 0.82, 0.66)           ## a warm russet coat
	const SHAPE := [Vector2(-128, -128), Vector2(-122, -152), Vector2(-100, -166), Vector2(-60, -174), Vector2(-14, -184),
		Vector2(30, -198), Vector2(58, -200), Vector2(76, -192), Vector2(92, -212), Vector2(112, -218), Vector2(130, -204),
		Vector2(142, -176), Vector2(146, -146), Vector2(132, -120), Vector2(108, -104), Vector2(70, -86), Vector2(10, -78),
		Vector2(-60, -80), Vector2(-104, -92), Vector2(-124, -108)]
	const COAT_DARK := Color("3a2416")
	const COAT_MID := Color("6e4428")
	const COAT_LIGHT := Color("c49064")
	const OUTLINE := Color("1d1712")
	var _sil := PackedVector2Array()
	var _skin: Node2D
	var _far: Node2D
	var _fur: Texture2D
	var _coat: Node2D           ## the still coat, drawn once per turn
	var _front: Node2D          ## the tusks, drawn once per turn
	var _strokes: Array = []      ## [from, bend, to, light?]: hair strokes over the coat, laid once

	func _build_skin() -> void:
		var sil := PackedVector2Array(SHAPE)
		for i in 3:
			sil = _chaikin(sil)
		for i in sil.size():
			sil[i] = sil[i] * size
		_sil = sil
		_fur = load(FUR) as Texture2D
		# hair strokes combed down and back over the coat (seeded: the same every visit)
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		for i in 70:
			var p := Vector2(rng.randf_range(-112, 128), rng.randf_range(-196, -96))
			if not Geometry2D.is_point_in_polygon(p, PackedVector2Array(SHAPE)):
				continue
			var l := rng.randf_range(12.0, 22.0)
			_strokes.append([p, p + Vector2(-l * 0.25, l * 0.5), p + Vector2(-l * 0.35, l), rng.randf() < 0.4])
		# far legs behind the body, then the painted body, then (in _draw) the rest
		_far = Node2D.new()
		_far.show_behind_parent = true
		_far.z_index = -1
		_far.draw.connect(func() -> void:
			for l in [[-58.0, 0.0], [80.0, 0.25]]:
				_leg_tex(_far, l[0], l[1], _pause <= 0.0, Color(0.5, 0.4, 0.38)))
		add_child(_far)
		_skin = Node2D.new()
		_skin.show_behind_parent = true
		add_child(_skin)
		Terrain.paint_poly(_skin, _sil, FUR, FUR_TINT, Vector2(randf() * 300.0, 0))
		_coat = Node2D.new()
		_coat.show_behind_parent = true          # over the painted skin, under the legs and the skirt
		_coat.draw.connect(func() -> void: _draw_coat(_coat))
		add_child(_coat)
		_front = Node2D.new()                    # the tusks: over the trunk
		_front.draw.connect(func() -> void: _draw_tusks(_front))
		add_child(_front)

	## Rounds a closed outline (corner cutting): bumps become curves.
	func _chaikin(pts: PackedVector2Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for i in pts.size():
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			out.append(a.lerp(b, 0.25))
			out.append(a.lerp(b, 0.75))
		return out

	## Every frame: only what MOVES (the legs, the swinging skirt, the swaying trunk). The
	## still coat and the tusks are drawn once on their own layers (_coat, _front) and
	## again only when it turns round: three mammoths drawn whole each frame cost 30 ms.
	func _draw() -> void:
		var b := Batch.new()
		var moving := _pause <= 0.0
		var sw := sin(_t * 2.0)
		# the near legs, in fur, under the skirt
		for l in [[-78.0, 0.5], [62.0, 0.75]]:
			_leg_tex(self, l[0], l[1], moving, Color(0.85, 0.7, 0.62))
		# the long woolly SKIRT hanging from the flanks over the legs' tops: soft strands,
		# swinging as it walks
		var x := -122.0
		var k := 0
		while x < 120.0:
			var top := _belly_y(x) - 6.0
			var len := 36.0 + 9.0 * sin(x * 0.37) + (7.0 if k % 3 == 0 else 0.0)
			var swing := sw * 3.0 + (sin(_t * 2.6 + x * 0.1) * 2.5 if moving else 0.0)
			var col: Color = COAT_MID if k % 2 == 0 else COAT_DARK
			_strand(b, Vector2(x, top), len, swing, 4.5, col)
			x += 8.0
			k += 1
		# the trunk: one tapering shape, thick at the face, down to the ground, a curl at the tip;
		# wrinkle rings across it
		var sway := sin(_t * 1.3) * 9.0
		var tp := PackedVector2Array()
		for i in 13:
			var q := i / 12.0
			tp.append(_v(140.0 + q * 18.0 + sway * q * q - 16.0 * q * q * q, -150.0 + q * 130.0 - (q * q * q * q) * 10.0))
		var half: Array = []
		for i in tp.size():
			half.append((14.0 - i * 0.75) * size)
		b.circle(tp[0], float(half[0]) + 2.0 * size, OUTLINE, 14)          # a round root, under the eye: no flat cut
		b.circle(tp[0], float(half[0]), COAT_MID, 14)
		_tube(b, tp, half, 2.0 * size, OUTLINE, OUTLINE)
		_tube(b, tp, half, 0.0, COAT_MID, COAT_DARK)
		for i in range(1, tp.size() - 1):
			var d: Vector2 = (tp[i + 1] - tp[i - 1]).normalized()
			var n := Vector2(-d.y, d.x) * float(half[i]) * 0.85
			b.line(tp[i] - n, tp[i] + n + d * 2.0 * size, Color(0.06, 0.04, 0.02, 0.55), 1.4 * size)
		b.circle(tp[tp.size() - 1], float(half[half.size() - 1]) + 1.5 * size, OUTLINE, 10)
		b.circle(tp[tp.size() - 1], float(half[half.size() - 1]), COAT_DARK, 10)
		b.draw(self)

	## The still coat (once per turn): the tail, shading, hair strokes, the outline, the
	## ear and eye, the fur along the back, the moonlit rim.
	func _draw_coat(ci: CanvasItem) -> void:
		var b := Batch.new()
		var f := dirn
		# the tail: short, with a tuft
		b.polyline(PackedVector2Array([_v(-124, -136), _v(-136, -118), _v(-134, -100)]), COAT_DARK, 5.0 * size)
		b.ellipse(_v(-134, -96), 5.0 * size, 9.0 * size, COAT_DARK)
		# shading over the painted coat: dark toward the belly and the rump, a fan from the hump
		var mid := Vector2(40, -160) * size
		for i in _sil.size():
			var a: Vector2 = _sil[i]
			var c: Vector2 = _sil[(i + 1) % _sil.size()]
			var ka := clampf((a.y / size + 165.0) / 85.0, 0.0, 1.0)
			var kc := clampf((c.y / size + 165.0) / 85.0, 0.0, 1.0)
			b.tri_cols(Vector2(mid.x * f, mid.y), Vector2(a.x * f, a.y), Vector2(c.x * f, c.y),
				Color(0.04, 0.02, 0.01, 0.0), Color(0.04, 0.02, 0.01, 0.45 * ka), Color(0.04, 0.02, 0.01, 0.45 * kc))
		# hair strokes, combed down and back
		for s in _strokes:
			var col: Color = Color(COAT_LIGHT, 0.45) if s[3] else Color(COAT_DARK, 0.55)
			b.polyline(PackedVector2Array([_v(s[0].x, s[0].y), _v(s[1].x, s[1].y), _v(s[2].x, s[2].y)]), col, 2.0 * size)
		# the outline round the whole coat
		var ring := PackedVector2Array()
		for p in _sil:
			ring.append(Vector2(p.x * f, p.y))
		ring.append(ring[0])
		b.polyline(ring, OUTLINE, 4.0 * size)
		# the ear, small, half in the hair; the eye under a heavy brow
		b.ellipse(_v(96, -176), 10.0 * size, 14.0 * size, Color(0.08, 0.04, 0.02, 0.55))
		b.circle(_v(124, -172), 4.2 * size, Color("1a120c"), 10)
		b.circle(_v(125, -173), 1.5 * size, Color("fff4dd"), 6)
		b.polyline(PackedVector2Array([_v(114, -178), _v(124, -182), _v(134, -178)]), OUTLINE, 2.5 * size)
		# shaggy fur standing up along the dome, the hump and the back
		var ridge := [Vector2(-118, -150), Vector2(-90, -168), Vector2(-50, -177), Vector2(-10, -186), Vector2(28, -200),
			Vector2(56, -203), Vector2(78, -196), Vector2(96, -214), Vector2(114, -220)]
		for i in ridge.size() - 1:
			for j in 3:
				var q2: Vector2 = (ridge[i] as Vector2).lerp(ridge[i + 1], j / 3.0)
				var l2 := 10.0 + sin(i * 2.7 + j) * 4.0
				b.tri(_v(q2.x - 5.0, q2.y + 5.0), _v(q2.x + 5.0, q2.y + 5.0), _v(q2.x - 5.0, q2.y - l2), COAT_DARK)
		# moonlight along the dome, the hump and the back
		b.polyline(PackedVector2Array([_v(-112, -156), _v(-60, -176), _v(-10, -187), _v(30, -201), _v(58, -203)]), Color(COAT_LIGHT, 0.6), 3.0 * size)
		b.polyline(PackedVector2Array([_v(92, -213), _v(112, -219), _v(128, -208)]), Color(COAT_LIGHT, 0.6), 3.0 * size)
		b.draw(ci)

	## The TUSKS (once per turn, over the trunk): a real mammoth's, out of the jaw, down and
	## forward, then sweeping round and UP, the tips turning in in front of its face.
	func _draw_tusks(ci: CanvasItem) -> void:
		var b := Batch.new()
		var ctrl := PackedVector2Array([Vector2(132, -126), Vector2(150, -98), Vector2(178, -86), Vector2(204, -100),
			Vector2(214, -128), Vector2(206, -152)])
		for i in 2:
			var sm := PackedVector2Array([ctrl[0]])
			for j in ctrl.size() - 1:
				sm.append(ctrl[j].lerp(ctrl[j + 1], 0.25))
				sm.append(ctrl[j].lerp(ctrl[j + 1], 0.75))
			sm.append(ctrl[ctrl.size() - 1])
			ctrl = sm
		var tusk := PackedVector2Array()
		var tw: Array = []
		for i in ctrl.size():
			tusk.append(_v(ctrl[i].x, ctrl[i].y))
			tw.append(lerpf(7.5, 2.0, float(i) / (ctrl.size() - 1)) * size)
		_tube(b, tusk, tw, 2.0 * size, OUTLINE, OUTLINE)
		_tube(b, tusk, tw, 0.0, Color("d6c7a4"), Color("f8f1df"))
		for i in range(2, tusk.size() - 2):                          # a shine along it
			b.line(tusk[i] + Vector2(0, -float(tw[i]) * 0.45), tusk[i + 1] + Vector2(0, -float(tw[i + 1]) * 0.45), Color(1, 1, 1, 0.4), 1.5 * size)
		b.draw(ci)

	## `half` the half-width at each point (+ `grow` for an outline), coloured from
	## `c0` at the root to `c1` at the tip.
	func _tube(b: Batch, pts: PackedVector2Array, half: Array, grow: float, c0: Color, c1: Color) -> void:
		var sides: Array = []
		for i in pts.size():
			var d: Vector2 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
			sides.append(Vector2(-d.y, d.x) * (float(half[i]) + grow))
		for i in pts.size() - 1:
			var col := c0.lerp(c1, float(i) / (pts.size() - 2))
			var sa: Vector2 = sides[i]
			var sb: Vector2 = sides[i + 1]
			b.quad(pts[i] - sa, pts[i + 1] - sb, pts[i + 1] + sb, pts[i] + sa, col)
			b.circle(pts[i + 1], float(half[i + 1]) + grow, col, 8)       # round joints: no notches where it bends

	## One strand of the woolly skirt: from `top` (facing right, unscaled), `len` long,
	## its tip swung by `swing`; outlined.
	func _strand(b: Batch, top: Vector2, len: float, swing: float, w: float, col: Color) -> void:
		var mid := top + Vector2(swing * 0.4 - 1.0, len * 0.55)
		var tip := top + Vector2(swing - 3.0, len)
		for o in [[w + 1.6, OUTLINE], [w, col]]:
			var ww: float = o[0]
			b.quad(_v(top.x - ww, top.y), _v(mid.x - ww * 0.6, mid.y), _v(mid.x + ww * 0.6, mid.y), _v(top.x + ww, top.y), o[1])
			b.tri(_v(mid.x - ww * 0.6, mid.y), _v(tip.x, tip.y + (1.5 if ww > w else 0.0)), _v(mid.x + ww * 0.6, mid.y), o[1])
		b.line(_v(top.x, top.y + 3.0), _v(mid.x, mid.y), Color(COAT_LIGHT, 0.35), 1.2 * size)
	## The bottom of the coat at x (facing right, unscaled): where the skirt hangs from.
	func _belly_y(x: float) -> float:
		var lo := -78.0
		if x > 70.0:
			lo = lerpf(-86.0, -104.0, (x - 70.0) / 40.0)
		elif x < -60.0:
			lo = lerpf(-80.0, -108.0, (-60.0 - x) / 64.0)
		return lo

	## One leg, in the fur: a tapering column and a round foot (drawn on `ci`).
	func _leg_tex(ci: CanvasItem, x: float, phase: float, moving: bool, tint: Color) -> void:
		var ph := (_ph + phase) * TAU
		var swing := sin(ph) if moving else 0.0
		var lift := maxf(0.0, cos(ph)) * 10.0 if moving else 0.0
		var hip := _v(x, -100)
		var foot := _v(x + swing * 16.0, -lift)
		# a pillar leg: wide at the top, a knee bulge, narrowing to the foot
		var knee := hip.lerp(foot, 0.55) + _v(swing * 4.0, 0) - Vector2(0, 0)
		var col := PackedVector2Array([hip + Vector2(-24, -6) * size, hip + Vector2(24, -6) * size, knee + Vector2(20, 0) * size,
			foot + Vector2(17, -8) * size, foot + Vector2(-17, -8) * size, knee + Vector2(-20, 0) * size])
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
		ci.draw_colored_polygon(_pad(foot + Vector2(0, -6) * size, 22.0 * size, 11.0 * size), Color("1d1712"))     # a wide flat pad, not a ball
		ci.draw_colored_polygon(_pad(foot + Vector2(0, -7) * size, 20.0 * size, 9.0 * size), Color("4a3426"))
		# toenails
		for k in 3:
			ci.draw_circle(foot + Vector2(-11.0 + k * 11.0, -1.0) * size, 3.0 * size, Color("cdbf9f"))

	## A foot pad: a flat oval.
	func _pad(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		return pts


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
