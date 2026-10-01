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

	func _draw() -> void:
		var b := Batch.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = int(position.x) * 13 + int(position.y)
		b.rect(Rect2(0, 0, w, h), Color("454a5e"))
		b.rect(Rect2(0, 0, 7, h), Color("5a6078"))            # moonlit edges
		b.rect(Rect2(w - 7, 0, 7, h), Color("5a6078"))
		# strata
		var y := 30.0
		while y < h - 10.0:
			b.line(Vector2(4, y), Vector2(w - 4, y + rng.randf_range(-6.0, 6.0)), Color("383c4e"), 2.0)
			y += rng.randf_range(40.0, 70.0)
		# holds on both faces: little ledges, scuffed pale
		var hy := 40.0
		while hy < h - 20.0:
			for side in [0.0, w - 12.0]:
				b.rect(Rect2(side + rng.randf_range(0.0, 2.0), hy + rng.randf_range(-8.0, 8.0), 12, 5), Color("8b90a6"))
			hy += rng.randf_range(55.0, 75.0)
		# scrape marks, where others have climbed
		for i in int(h / 90.0):
			var sx: float = 3.0 if i % 2 == 0 else w - 10.0
			var sy := rng.randf_range(30.0, h - 40.0)
			for k in 3:
				b.line(Vector2(sx + k * 3.0, sy), Vector2(sx + k * 3.0 + 2.0, sy + 16.0), Color("7b8096"), 1.2)
		if grassy:
			b.rect(Rect2(-3, -3, w + 6, 9), Color("2f5a3a"))
			b.rect(Rect2(-3, -3, w + 6, 3), Color("5c9a5e"))
			for i in int(w / 14.0):
				var tx := rng.randf_range(2.0, w - 2.0)
				b.tri(Vector2(tx - 2.0, -2), Vector2(tx + 2.0, -2), Vector2(tx, -rng.randf_range(5.0, 9.0)), Color("4f8a52"))
		else:
			b.rect(Rect2(0, 0, w, 4), Color("8b90a6"))
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

	func _v(x: float, y: float) -> Vector2:
		return Vector2(x * dirn, y) * size

	func _draw() -> void:
		var b := Batch.new()
		var fur := Color("6b4a32")
		var dark := Color("4e3524")
		var rim := Color("8f6e4f")
		var moving := _pause <= 0.0
		# legs, four-beat: far legs first (darker), near legs after the body
		var legs := [[-62.0, 0.0, true], [52.0, 0.25, true], [-74.0, 0.5, false], [40.0, 0.75, false]]
		for l in legs:
			if l[2]:
				_leg(b, l[0], l[1], moving, dark.darkened(0.25))
		# the tail, and the shaggy body
		b.polyline(PackedVector2Array([_v(-118, -128), _v(-128, -112), _v(-126, -96)]), dark, 4.0 * size)
		b.circle(_v(-126, -94), 6.0 * size, dark, 8)
		var body := PackedVector2Array()
		for i in 28:
			var a := TAU * i / 28.0
			var r := Vector2(112, 58)
			var c := Vector2(cos(a) * r.x, sin(a) * r.y)
			if c.y < 0.0 and c.x > 0.0:
				c.y -= sin(a * -1.0) * 14.0          # the shoulder hump
			body.append(_v(c.x - 8.0, c.y - 118.0))
		b.poly(body, fur)
		b.circle(_v(48, -150), 48.0 * size, fur, 18)               # the hump
		b.circle(_v(30, -168), 26.0 * size, rim, 14)
		b.circle(_v(30, -162), 26.0 * size, fur, 14)
		# the fringe of long hair under the belly
		var x := -104.0
		while x < 96.0:
			b.tri(_v(x, -72), _v(x + 14.0, -72), _v(x + 7.0, -52 + sin(_t * 2.0 + x) * 3.0), dark)
			x += 12.0
		for l in legs:
			if not l[2]:
				_leg(b, l[0], l[1], moving, Color("5a3e2a"))
		# the head: a high dome, a small ear, an eye
		b.circle(_v(104, -138), 38.0 * size, fur, 16)
		b.circle(_v(98, -166), 26.0 * size, fur, 14)
		b.circle(_v(96, -176), 16.0 * size, rim, 10)
		b.circle(_v(94, -172), 16.0 * size, fur, 10)
		b.circle(_v(80, -136), 13.0 * size, dark, 10)
		b.circle(_v(116, -148), 3.5 * size, Color("1a120c"), 8)
		b.circle(_v(117, -149), 1.3 * size, Color("fff4dd"), 6)
		# the trunk, swaying
		var sway := sin(_t * 1.3) * 10.0
		var tp := PackedVector2Array()
		for i in 9:
			var k := i / 8.0
			tp.append(_v(128.0 + k * 14.0 + sway * k * k, -128.0 + k * 92.0 - k * k * 8.0))
		for i in tp.size():
			b.circle(tp[i], (11.0 - i * 0.8) * size, fur if i < 7 else dark, 10)
		# the tusks, long and curling up
		var tusk := PackedVector2Array([_v(118, -112), _v(140, -100), _v(166, -102), _v(184, -118), _v(188, -138)])
		b.polyline(tusk, Color("cdbf9f"), 8.0 * size)
		b.polyline(tusk, Color("efe4c8"), 5.0 * size)
		# a moonlit rim along the back
		b.polyline(PackedVector2Array([_v(-110, -150), _v(-60, -172), _v(0, -184), _v(40, -196), _v(80, -192)]), Color(rim, 0.8), 3.0 * size)
		b.draw(self)

	func _leg(b: Batch, x: float, phase: float, moving: bool, col: Color) -> void:
		var ph := (_ph + phase) * TAU
		var swing := sin(ph) if moving else 0.0
		var lift := maxf(0.0, cos(ph)) * 10.0 if moving else 0.0
		var hip := _v(x, -96)
		var foot := _v(x + swing * 16.0, -lift)
		b.poly(PackedVector2Array([hip + Vector2(-15, 0) * size, hip + Vector2(15, 0) * size, foot + Vector2(13, -6) * size, foot + Vector2(-13, -6) * size]), col)
		b.circle(foot + Vector2(0, -6) * size, 14.0 * size, col, 10)
		b.rect(Rect2(foot + Vector2(-15, -6) * size, Vector2(30, 6) * size), col.darkened(0.2))


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
