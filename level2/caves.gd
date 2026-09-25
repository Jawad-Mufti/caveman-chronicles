## Level 2's two caves: small dark places off the main path, each with its
## own animals, and one of them holding Old Bongo's lost key (which one is
## decided fresh every time the level starts). The caves are built in the same
## scene, off to the right of the woods; walking into a doorway fades to black
## and moves him there, and the level points the camera at the cave.
class_name Caves
extends RefCounted


## ================================================================ ROCK
class CaveRock extends StaticBody2D:
	## Solid cave rock: floors, roofs and walls.
	var rect := Rect2()
	var kind := "floor"          ## floor, roof or wall

	func _init(r: Rect2, k: String = "floor") -> void:
		rect = r
		kind = k

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		z_index = -1            # built after him, but always behind him
		position = rect.position
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = rect.size
		cs.shape = sh
		cs.position = rect.size * 0.5
		add_child(cs)

	var _bt: Batch

	func _draw() -> void:
		_bt = Batch.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = int(rect.position.x) * 7 + int(rect.position.y)
		var w := rect.size.x
		var h := rect.size.y
		_bt.rect(Rect2(0, 0, w, h), Pal.CAVE_ROCK.darkened(0.3))
		match kind:
			"floor":
				_bt.rect(Rect2(0, 0, w, minf(h, 36.0)), Pal.CAVE_ROCK)
				var top := PackedVector2Array()
				var x := 0.0
				while x <= w:
					top.append(Vector2(x, rng.randf_range(0.0, 3.0)))
					x += rng.randf_range(10.0, 22.0)
				top.append(Vector2(w, 1))
				_bt.polyline(top, Pal.CAVE_ROCK_LIGHT, 4.0)
				for i in int(w / 50.0):
					_bt.circle(Vector2(rng.randf_range(6.0, w - 6.0), -1.5), rng.randf_range(1.5, 3.5), Pal.CAVE_ROCK_LIGHT.darkened(0.2))
			"roof":
				_bt.rect(Rect2(0, maxf(h - 36.0, 0.0), w, minf(h, 36.0)), Pal.CAVE_ROCK)
				# stalactites, short, so they never look like something to stand on
				var x := rng.randf_range(4.0, 20.0)
				while x < w - 8.0:
					var sw := rng.randf_range(8.0, 18.0)
					var len := rng.randf_range(8.0, 24.0)
					_bt.poly(PackedVector2Array([Vector2(x, h - 1.0), Vector2(x + sw, h - 1.0), Vector2(x + sw * 0.5, h + len)]), Pal.CAVE_ROCK)
					if rng.randf() < 0.3:
						_bt.circle(Vector2(x + sw * 0.5, h + len + 3.0), 1.8, Color(Pal.SILK, 0.5))
					x += sw + rng.randf_range(10.0, 40.0)
			_:
				for i in 6:
					var cy := rng.randf_range(20.0, h - 20.0)
					_bt.line(Vector2(rng.randf_range(10.0, w - 10.0), cy), Vector2(rng.randf_range(10.0, w - 10.0), cy + 30.0), Pal.CAVE_DARK, 2.0)
		_bt.draw(self)


class CaveBackdrop extends Node2D:
	## The back wall of a cave, covering the woods and sky behind it.
	var rect := Rect2()

	func _ready() -> void:
		z_index = -2

	var _bt: Batch

	func _draw() -> void:
		_bt = Batch.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = int(rect.position.x)
		_bt.rect(rect.grow(500.0), Pal.CAVE_DARK)
		_bt.rect(rect, Pal.CAVE_BACK)
		for i in 60:
			var c := rect.position + Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y)
			var r := rng.randf_range(20.0, 70.0)
			var pts := PackedVector2Array()
			for k in 9:
				var a := TAU * k / 9.0
				pts.append(c + Vector2(cos(a), sin(a) * 0.6) * r * rng.randf_range(0.7, 1.1))
			_bt.poly(pts, Pal.CAVE_BACK.darkened(rng.randf_range(0.1, 0.3)) if i % 2 == 0 else Pal.CAVE_BACK.lightened(0.05))
		# far stalactites and stalagmites in the gloom
		var x := rect.position.x
		while x < rect.end.x:
			var w := rng.randf_range(20.0, 50.0)
			_bt.poly(PackedVector2Array([Vector2(x, rect.position.y), Vector2(x + w, rect.position.y),
				Vector2(x + w * 0.5, rect.position.y + rng.randf_range(60.0, 180.0))]), Pal.CAVE_DARK)
			_bt.poly(PackedVector2Array([Vector2(x + 30.0, rect.end.y), Vector2(x + 30.0 + w, rect.end.y),
				Vector2(x + 30.0 + w * 0.5, rect.end.y - rng.randf_range(40.0, 140.0))]), Pal.CAVE_DARK)
			x += w + rng.randf_range(40.0, 120.0)
		_bt.draw(self)


## ================================================================ DOORWAYS
class CaveMouth extends Area2D:
	## A way into the dark, in a rock face. He goes in by walking into it.
	## What lies at the door is the mystery hint: webs or a shed skin say what
	## lives inside; a banana peel and small hand-prints say a monkey went in.
	signal entered
	signal noticed               ## the first time he comes close enough to look
	var side := -1               ## the way he walks to go in (-1 = into rock on his left)
	var kind := "webs"           ## "webs": the spider cave; "skin": the snake cave
	var monkey_went_in := false
	var player: CaveMan
	var _hold := 0.0
	var _noticed := false

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(56, 100)
		cs.shape = sh
		cs.position = Vector2(-side * 28.0, -50)
		add_child(cs)

	func _physics_process(delta: float) -> void:
		if player == null or player.talking:
			return
		if not _noticed and player.is_on_floor() and player.global_position.distance_to(global_position) < 230.0:
			_noticed = true
			noticed.emit()
			return
		if overlaps_body(player) and player.is_on_floor() and player.facing == side:
			_hold += delta
			if _hold > 0.4:
				_hold = 0.0
				entered.emit()
		else:
			_hold = 0.0

	func _draw() -> void:
		var s := float(-side)          # the open ground is on this side
		var r := -s                     # the rock is on this side
		# the opening, going back into the rock
		var hole := PackedVector2Array([Vector2(0, 0), Vector2(r * 40, 0), Vector2(r * 60, -30), Vector2(r * 58, -70), Vector2(r * 40, -92),
			Vector2(r * 10, -96), Vector2(0, -94)])
		draw_colored_polygon(hole, Pal.CAVE_DARK)
		draw_polyline(PackedVector2Array([Vector2(0, -94), Vector2(r * 10, -96), Vector2(r * 40, -92), Vector2(r * 58, -70), Vector2(r * 60, -30)]),
			Pal.CRAG_LIGHT, 3.0, true)
		if kind == "webs":
			# webs over the opening; torn wide if something pushed through
			var torn := monkey_went_in
			for k in 6:
				var y := -90.0 + k * 11.0
				if torn and k > 1 and k < 5:
					draw_line(Vector2(0, y), Vector2(r * 14.0, y + 6.0), Color(Pal.SILK, 0.6), 1.5, true)
					draw_line(Vector2(r * 44.0, y + 4.0), Vector2(r * 58.0, y), Color(Pal.SILK, 0.6), 1.5, true)
				else:
					draw_line(Vector2(0, y), Vector2(r * 58.0, y + 4.0), Color(Pal.SILK, 0.6), 1.5, true)
			for k in 5:
				draw_line(Vector2(r * (6.0 + k * 12.0), -94), Vector2(r * (8.0 + k * 11.0), -30), Color(Pal.SILK, 0.45), 1.2, true)
			if torn:
				MonkeyBits.peel(self, Vector2(r * 26.0, -62), 0.9)
		else:
			# a shed snake skin in the dirt at the door
			var skin := PackedVector2Array()
			for k in 12:
				skin.append(Vector2(s * (14.0 + k * 7.0), -3.0 + sin(k * 1.1) * 4.0))
			draw_polyline(skin, Color(Pal.SNAKE_BELLY, 0.85), 5.0, true)
			draw_polyline(skin, Color(Pal.BONE, 0.5), 2.0, true)
			if monkey_went_in:
				MonkeyBits.peel(self, Vector2(s * 58.0, -6), 1.0)
		if monkey_went_in:
			# small hand-prints, going in
			for k in 4:
				var p := Vector2(s * (70.0 - k * 18.0), -2.0)
				for f in 4:
					draw_circle(p + Vector2(f * 2.4 - 3.6, -3.0 - absf(f - 1.5)), 1.1, Pal.CAVE_DARK)
				draw_circle(p, 2.2, Pal.CAVE_DARK)


class CaveExit extends Area2D:
	## The way back out: a spill of pale night at the cave's first wall.
	## Walk into it to leave. It lights the doorway a little, too.
	signal left
	var side := -1               ## the way he walks to leave
	var player: CaveMan
	var _hold := 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(60, 110)
		cs.shape = sh
		cs.position = Vector2(-side * 30.0, -55)
		add_child(cs)
		add_to_group("light")
		z_index = -1

	func light() -> Vector4:
		return Vector4(global_position.x - side * 20.0, global_position.y - 60.0, 170.0, 0.0)

	func light_strength() -> float:
		return 0.0

	func _physics_process(delta: float) -> void:
		if player == null or player.talking:
			return
		if overlaps_body(player) and player.is_on_floor() and player.facing == side:
			_hold += delta
			if _hold > 0.25:
				_hold = 0.0
				left.emit()
		else:
			_hold = 0.0

	func _draw() -> void:
		var r := float(side)
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(r * 26, -10), Vector2(r * 30, -60), Vector2(r * 18, -100), Vector2(0, -104)]),
			Color(Pal.MOONLIT, 0.55))
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(-r * 70, 0), Vector2(-r * 40, -4), Vector2(0, -30)]), Color(Pal.MOONLIT, 0.12))


class MonkeyBits extends RefCounted:
	static func peel(c: CanvasItem, at: Vector2, k: float) -> void:
		for i in 3:
			var a := -PI * 0.5 + (i - 1) * 0.8
			c.draw_line(at, at + Vector2.from_angle(a + PI) * 10.0 * k, Pal.BANANA_DARK, 3.0, true)
		c.draw_circle(at, 3.0 * k, Pal.BANANA)


## ================================================================ OBSTACLES
class Web extends StaticBody2D:
	## A curtain of old web across the way. A club only bounces off it, but it
	## goes up in a flash at a touch of flame: his torch, or a fire burst.
	## With the torch out he is stuck behind it — so the cave has wood.
	signal blocked
	var h := 180.0
	var burning := -1.0
	var player: CaveMan
	var _cs: CollisionShape2D
	var _told := false

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		_cs = CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(18, h)
		_cs.shape = sh
		_cs.position = Vector2(0, -h * 0.5)
		add_child(_cs)
		add_to_group("webs")

	func burn() -> void:
		if burning >= 0.0:
			return
		burning = 0.0
		_cs.set_deferred("disabled", true)

	func _physics_process(delta: float) -> void:
		if burning >= 0.0:
			burning += delta
			queue_redraw()
			if burning > 0.8:
				queue_free()
			return
		if player == null:
			return
		var p := player.global_position
		if absf(p.x - global_position.x) < 44.0 and p.y <= global_position.y + 4.0 and p.y > global_position.y - h:
			if player.has_torch and player.torch_fuel > 0.0:
				burn()
			elif not _told:
				_told = true
				blocked.emit()

	func _draw() -> void:
		var k := 0.0 if burning < 0.0 else clampf(burning / 0.8, 0.0, 1.0)
		var col := Color(Pal.SILK, 0.55) if burning < 0.0 else Color(Pal.FLAME, 1.0 - k)
		for i in 5:
			var x := -8.0 + i * 4.0
			var pts := PackedVector2Array()
			for j in 9:
				var y := -h * (j / 8.0)
				pts.append(Vector2(x + sin(j * 1.7 + i) * 5.0, y * (1.0 - k * 0.5)))
			draw_polyline(pts, col, 1.4, true)
		for j in 10:
			var y := -h * (j + 0.5) / 10.0 * (1.0 - k * 0.5)
			draw_line(Vector2(-11, y), Vector2(11, y + 6.0), col, 1.2, true)
		if burning >= 0.0:
			for i in 10:
				draw_circle(Vector2(sin(i * 2.3) * 12.0, -h * (i / 10.0) * (1.0 - k)), 2.5 * (1.0 - k) + 0.5, Color(Pal.EMBER_GLOW, 1.0 - k))


## ================================================================ HIDING SPOTS
class Cocoon extends Area2D:
	## A silk bundle hanging from the roof: something the spiders caught and
	## kept. Knock it down — a jump and a swing, or a thrown rock — and it
	## splits open on the floor. It holds the key, or a bone that isn't one.
	signal revealed(item: KeyItem)
	var holds_key := false
	var roof_y := 0.0
	var floor_y := 0.0
	var state := "hang"          ## hang fall open
	var vy := 0.0
	var t := 0.0

	func _ready() -> void:
		collision_layer = 4
		collision_mask = 0
		monitoring = false
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(30, 48)
		cs.shape = sh
		add_child(cs)
		add_to_group("glow")

	func take_hit(_dmg: int, _from_dir: int) -> void:
		if state == "hang":
			state = "fall"
			set_deferred("monitorable", false)

	func _physics_process(delta: float) -> void:
		t += delta
		if state == "fall":
			vy += 1400.0 * delta
			position.y += vy * delta
			if position.y + 24.0 >= floor_y:
				position.y = floor_y - 24.0
				state = "open"
				var k := KeyItem.new()
				k.real = holds_key
				k.position = Vector2(position.x, floor_y)
				get_parent().call_deferred("add_child", k)
				revealed.emit(k)
		if NightWoods.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var sway := sin(t * 1.4) * 0.06 if state == "hang" else 0.0
		if state == "hang":
			draw_line(Vector2(0, -24), Vector2(0, roof_y - position.y), Color(Pal.SILK, 0.7), 1.5)
		if state == "open":
			for i in 4:
				var a := -0.6 + i * 0.4
				draw_colored_polygon(PackedVector2Array([Vector2(-4 + i * 3, 24), Vector2(-20 + i * 12, 16 + absf(a) * 8.0),
					Vector2(-10 + i * 10, 24)]), Color(Pal.SILK, 0.8))
			return
		draw_set_transform(Vector2.ZERO, sway, Vector2.ONE)
		var pts := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			pts.append(Vector2(cos(a) * 14.0, sin(a) * 24.0))
		draw_colored_polygon(pts, Pal.SILK.darkened(0.15))
		for k in 6:
			var y := -18.0 + k * 7.0
			draw_line(Vector2(-13, y), Vector2(13, y + 5.0), Pal.SILK, 1.5, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## Something inside catches the light, just enough to make him look.
	func draw_glow(g: Node2D) -> void:
		if state != "hang":
			return
		var s := absf(sin(t * 0.9))
		g.draw_circle(global_position + Vector2(3, 2), 3.0 + s * 3.0, Color(Pal.BONE, 0.25 * s))


class Nest extends Area2D:
	## The rats' hoard: bones, twigs, peel and one thing that glints. Two good
	## hits scatter it. It holds the key, or a bone that isn't one.
	signal revealed(item: KeyItem)
	var holds_key := false
	var hits := 2
	var shake := 0.0
	var open := false
	var t := 0.0
	var _bits: Array = []        ## [position, velocity, spin, colour] for the scatter

	func _ready() -> void:
		collision_layer = 4
		collision_mask = 0
		monitoring = false
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(80, 44)
		cs.shape = sh
		cs.position = Vector2(0, -22)
		add_child(cs)
		add_to_group("glow")

	func take_hit(_dmg: int, from_dir: int) -> void:
		if open:
			return
		hits -= 1
		shake = 0.3
		if hits > 0:
			return
		open = true
		set_deferred("monitorable", false)
		for i in 10:
			var col := Pal.KEY_BONE if i % 3 == 0 else (Pal.DEADWOOD if i % 3 == 1 else Pal.BANANA_DARK)
			_bits.append([Vector2(randf_range(-20, 20), -20), Vector2(from_dir * randf_range(40, 200), randf_range(-420, -200)), randf_range(-8, 8), col])
		var k := KeyItem.new()
		k.real = holds_key
		k.position = global_position + Vector2(-from_dir * 20.0, 0)
		get_parent().call_deferred("add_child", k)
		revealed.emit(k)

	func _process(delta: float) -> void:
		t += delta
		shake = maxf(shake - delta, 0.0)
		for b in _bits:
			b[1] = (b[1] as Vector2) + Vector2(0, 1400.0 * delta)
			b[0] = (b[0] as Vector2) + (b[1] as Vector2) * delta
		if NightWoods.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var o := Vector2(sin(shake * 70.0) * 3.0 * (shake / 0.3), 0)
		if not open:
			var heap := PackedVector2Array([Vector2(-40, 0), Vector2(-30, -26), Vector2(-8, -42), Vector2(14, -38), Vector2(34, -22), Vector2(42, 0)])
			for i in heap.size():
				heap[i] = heap[i] + o
			draw_colored_polygon(heap, Pal.CAVE_ROCK_LIGHT.darkened(0.3))
			for i in 9:
				var a := Vector2(-32 + i * 8, -8 - (i % 4) * 7) + o
				draw_line(a, a + Vector2(14, -6 + (i % 3) * 5), Pal.DEADWOOD if i % 2 == 0 else Pal.KEY_BONE, 3.0, true)
			MonkeyBits.peel(self, Vector2(16, -30) + o, 0.8)
		else:
			draw_colored_polygon(PackedVector2Array([Vector2(-44, 0), Vector2(-20, -8), Vector2(22, -7), Vector2(46, 0)]), Pal.CAVE_ROCK_LIGHT.darkened(0.3))
		for b in _bits:
			var p: Vector2 = b[0]
			if p.y < 40.0:
				draw_line(p, p + Vector2.from_angle(float(b[2]) * t) * 10.0, b[3], 3.0, true)

	func draw_glow(g: Node2D) -> void:
		if open:
			return
		var s := absf(sin(t * 0.9))
		g.draw_circle(global_position + Vector2(4, -30), 3.0 + s * 3.0, Color(Pal.BONE, 0.25 * s))


class KeyItem extends Area2D:
	## What was hidden. The real one is a carved bone key with a banana for a
	## handle. The other is just a bone, shaped a bit like a key.
	signal taken(real: bool)
	var real := true
	var floor_y := 0.0
	var vy := -320.0
	var t := 0.0
	var resting := false
	var gone := false

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 22.0
		cs.shape = c
		cs.position = Vector2(0, -10)
		add_child(cs)
		body_entered.connect(_on_body)
		floor_y = position.y
		add_to_group("glow")

	func _on_body(b: Node) -> void:
		if gone or not resting or not (b is CaveMan):
			return
		gone = true
		taken.emit(real)
		set_deferred("monitoring", false)
		call_deferred("queue_free")

	func _physics_process(delta: float) -> void:
		t += delta
		if not resting:
			vy += 1300.0 * delta
			position.y += vy * delta
			if position.y >= floor_y and vy > 0.0:
				position.y = floor_y
				resting = true
				for b in get_overlapping_bodies():
					_on_body(b)
		if NightWoods.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var bob := Vector2(0, -12 + sin(t * 2.2) * 2.0) if resting else Vector2(0, -12)
		draw_set_transform(bob, sin(t * 1.3) * 0.1, Vector2.ONE)
		# shaft
		draw_line(Vector2(-8, 0), Vector2(18, 0), Pal.KEY_BONE.darkened(0.3), 7.0, true)
		draw_line(Vector2(-8, -1), Vector2(18, -1), Pal.KEY_BONE, 4.0, true)
		if real:
			# teeth, and a banana for a handle
			draw_rect(Rect2(10, 2, 4, 7), Pal.KEY_BONE)
			draw_rect(Rect2(16, 2, 3, 5), Pal.KEY_BONE)
			MonkeyArt_banana(self, Vector2(-20, -10))
		else:
			draw_circle(Vector2(-10, -3), 5.0, Pal.KEY_BONE)
			draw_circle(Vector2(-10, 3), 5.0, Pal.KEY_BONE)
			draw_circle(Vector2(20, -3), 4.5, Pal.KEY_BONE)
			draw_circle(Vector2(20, 3), 4.5, Pal.KEY_BONE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	static func MonkeyArt_banana(c: CanvasItem, at: Vector2) -> void:
		var pts := PackedVector2Array()
		for i in 7:
			pts.append(at + Vector2(10, 12) + Vector2.from_angle(-PI * 0.5 - 0.6 + 1.2 * i / 6.0) * 13.0)
		for i in 7:
			pts.append(at + Vector2(10, 12) + Vector2.from_angle(-PI * 0.5 + 0.6 - 1.2 * i / 6.0) * 8.0)
		c.draw_colored_polygon(pts, Pal.BANANA)

	func draw_glow(g: Node2D) -> void:
		var s := absf(sin(t * 1.5))
		var c := global_position + Vector2(0, -14)
		g.draw_circle(c, 12.0 + s * 5.0, Color(Pal.BANANA if real else Pal.BONE, 0.10 + 0.10 * s))
		if real and s > 0.75:
			var k := (s - 0.75) / 0.25
			for a in [0.0, PI * 0.5, PI, PI * 1.5]:
				g.draw_line(c + Vector2.from_angle(a) * 4.0, c + Vector2.from_angle(a) * (8.0 + k * 10.0), Color(1, 1, 1, k), 2.0, true)


## ================================================================ CAVE ANIMALS
class Spider extends Critter:
	## Hangs from the roof on a thread, eyes glowing, until he walks beneath.
	## Then it drops. On the floor it scuttles at him and pounces.
	var roof_y := 0.0
	var floor_y := 0.0
	var left_x := 0.0
	var right_x := 0.0
	var state := "hang"          ## hang drop crawl pounce
	var t := 0.0
	var vy := 0.0
	var vx := 0.0
	var dir := -1
	var cd := 1.0
	var _walk := 0.0

	func _setup() -> void:
		hp = 3
		damage = 0
		stomp_top = -26.0
		add_rect_shape(Vector2(40, 26), Vector2(0, -14))
		floor_y = position.y
		position.y = roof_y + 70.0
		t = randf() * 5.0
		add_to_group("glow")

	func _tick(delta: float) -> void:
		t += delta
		cd -= delta
		if player == null:
			return
		var dx := player.global_position.x - position.x
		var level := absf(player.global_position.y - floor_y) < 70.0
		match state:
			"hang":
				damage = 0
				position.y = roof_y + 70.0 + sin(t * 1.6) * 5.0
				if absf(dx) < 110.0 and level:
					state = "drop"
					vy = 0.0
			"drop":
				damage = 1
				vy += 1500.0 * delta
				position.y += vy * delta
				if position.y >= floor_y:
					position.y = floor_y
					state = "crawl"
					cd = 0.6
			"crawl":
				damage = 1
				var goal := player.global_position.x if level else (right_x if dir > 0 else left_x)
				if not level and absf(position.x - goal) < 4.0:
					dir = -dir
				var step := clampf(goal - position.x, -110.0 * delta, 110.0 * delta)
				position.x = clampf(position.x + step, left_x, right_x)
				_walk += absf(step)
				if absf(step) > 0.1:
					dir = 1 if step > 0.0 else -1
				if level and absf(dx) < 170.0 and cd <= 0.0:
					state = "pounce"
					vx = signf(dx) * 320.0
					vy = -380.0
			"pounce":
				damage = 1
				vy += 1500.0 * delta
				position += Vector2(vx, vy) * delta
				position.x = clampf(position.x, left_x, right_x)
				_walk += 6.0
				if position.y >= floor_y and vy > 0.0:
					position.y = floor_y
					state = "crawl"
					cd = 1.6

	func _draw() -> void:
		var f := float(dir)
		var tuck := 1.0 if state == "hang" else 0.0
		if state == "hang" or state == "drop":
			draw_line(Vector2(0, -26), Vector2(0, roof_y - position.y), Color(Pal.SILK, 0.7), 1.5)
		var body := Vector2(0, -14)
		for side in [-1.0, 1.0]:
			var sd: float = side
			for k in 4:
				var hip := body + Vector2(sd * (2.0 + k * 2.0), -2.0)
				var reach := 14.0 + k * 5.0
				var step := sin(_walk * 0.25 + k * 1.3 + sd) * 4.0
				var foot := Vector2(sd * reach + step, 0.0).lerp(Vector2(sd * 8.0, -8.0), tuck)
				var knee := Vector2((hip.x + foot.x) * 0.5 + sd * 4.0, -24.0 - k * 1.5)
				draw_polyline(PackedVector2Array([hip, knee, foot]), Pal.SPIDER.darkened(0.2 if sd < 0.0 else 0.0), 2.4, true)
		_oval(Vector2(-f * 7.0, -16), 13.0, 11.0, Pal.SPIDER)
		_fill(PackedVector2Array([Vector2(-f * 7.0, -22), Vector2(-f * 4.0, -16), Vector2(-f * 7.0, -10), Vector2(-f * 10.0, -16)]), Pal.SPIDER_MARK)
		_oval(Vector2(f * 8.0, -13), 7.5, 6.5, Pal.SPIDER)
		draw_line(Vector2(f * 13.0, -10), Vector2(f * 15.0, -5), Pal.BONE, 1.5, true)
		if flash > 0.0:
			draw_circle(Vector2(0, -14), 20.0, Color(1, 1, 1, 0.5))

	func draw_glow(g: Node2D) -> void:
		if dying > 0.0:
			return
		var f := float(dir)
		var c := global_position + Vector2(f * 10.0, -15.0)
		g.draw_circle(c, 6.0, Color(Pal.EMBER_GLOW, 0.12))
		for k in 4:
			g.draw_circle(c + Vector2(f * (k % 2) * 3.0, -2.0 + (k / 2) * 3.0), 1.1, Color(Pal.EMBER_GLOW, 0.95))


class Rat extends Critter:
	## Quick, twitchy, and never alone. Scurries its stretch of floor, rushes
	## him when he comes close, and one hit is the end of it.
	var left_x := 0.0
	var right_x := 0.0
	var dir := 1
	var t := 0.0
	var pause := 0.0
	var _run := 0.0

	func _setup() -> void:
		hp = 1
		damage = 1
		stomp_top = -14.0
		add_rect_shape(Vector2(30, 16), Vector2(0, -8))
		t = randf() * 5.0
		dir = 1 if randf() < 0.5 else -1
		add_to_group("glow")

	func _tick(delta: float) -> void:
		t += delta
		if pause > 0.0:
			pause -= delta
			return
		var chasing := false
		if player != null:
			var dx := player.global_position.x - position.x
			chasing = absf(player.global_position.y - position.y) < 60.0 and absf(dx) < 240.0
			# commits to a rush: only turns once it is well past him
			if chasing and absf(dx) > 60.0:
				dir = 1 if dx > 0.0 else -1
		var speed := 240.0 if chasing else 150.0
		position.x += dir * speed * delta
		_run += speed * delta
		if position.x < left_x:
			position.x = left_x
			dir = 1
			if not chasing:
				pause = randf_range(0.3, 1.0)
		elif position.x > right_x:
			position.x = right_x
			dir = -1
			if not chasing:
				pause = randf_range(0.3, 1.0)
		elif not chasing and randf() < 0.006:
			pause = randf_range(0.3, 0.9)

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(dir, 1))
		var bob := absf(sin(_run * 0.2)) * 2.0
		draw_polyline(PackedVector2Array([Vector2(-12, -6), Vector2(-24, -4), Vector2(-32, -8 + sin(t * 6.0) * 2.0), Vector2(-38, -6)]), Pal.RAT_TAIL, 2.0, true)
		_oval(Vector2(-2, -8 - bob), 13.0, 7.0, Pal.RAT)
		_fill(PackedVector2Array([Vector2(8, -13 - bob), Vector2(19, -7 - bob), Vector2(8, -4 - bob)]), Pal.RAT)
		draw_circle(Vector2(19, -7 - bob), 1.6, Pal.RAT_TAIL)
		draw_circle(Vector2(6, -14 - bob), 3.2, Pal.RAT_TAIL)
		for k in 2:
			var fx := -6.0 + k * 12.0 + sin(_run * 0.3 + k * PI) * 3.0
			draw_line(Vector2(fx, -4 - bob), Vector2(fx, 0), Pal.RAT.darkened(0.3), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if flash > 0.0:
			draw_circle(Vector2(0, -8), 14.0, Color(1, 1, 1, 0.5))

	func draw_glow(g: Node2D) -> void:
		if dying > 0.0:
			return
		g.draw_circle(global_position + Vector2(dir * 12.0, -11.0), 1.4, Color(Pal.EMBER_GLOW, 0.9))


class Snake extends Critter:
	## Lives in a hole in the rock. Only its eyes show until he comes close;
	## then it rears in its hole with a hiss (the tell) and strikes out along
	## the floor. The strike is low: jump it. It can only be hit while it is out.
	const REACH := 130.0
	var dir := -1                ## which way the hole faces
	var state := "hide"          ## hide rear strike back
	var ext := 0.0               ## how far out it is, 0..1
	var t := 0.0
	var timer := 0.0
	var _cs: CollisionShape2D

	func _setup() -> void:
		hp = 3
		damage = 0
		stompable = false
		_cs = CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(36, 22)
		_cs.shape = r
		_cs.disabled = true
		add_child(_cs)
		add_to_group("glow")

	func _on_hit(_from_dir: int) -> void:
		state = "back"
		timer = 0.0

	func _tick(delta: float) -> void:
		t += delta
		timer -= delta
		if player == null:
			return
		var ahead := (player.global_position.x - position.x) * dir
		var level := absf((player.global_position.y - 20.0) - position.y) < 50.0
		match state:
			"hide":
				damage = 0
				ext = move_toward(ext, 0.0, delta * 3.0)
				if timer <= 0.0 and level and ahead > 0.0 and ahead < REACH + 60.0:
					state = "rear"
					timer = 0.45
			"rear":
				ext = move_toward(ext, 0.2, delta * 3.0)
				if timer <= 0.0:
					state = "strike"
					timer = 0.3
			"strike":
				damage = 1
				ext = move_toward(ext, 1.0, delta * 9.0)
				if timer <= 0.0:
					state = "back"
			"back":
				damage = 0
				ext = move_toward(ext, 0.0, delta * 1.5)
				if ext <= 0.0:
					state = "hide"
					timer = 1.2
		_cs.position = Vector2(dir * (ext * REACH + 8.0), 0)
		var out := ext > 0.25
		if _cs.disabled == out:
			_cs.set_deferred("disabled", not out)

	func _draw() -> void:
		var d := float(dir)
		_oval(Vector2(d * 2.0, 0), 11.0, 13.0, Pal.CAVE_DARK)
		if ext > 0.02:
			var head := Vector2(d * ext * REACH, 0)
			var pts := PackedVector2Array()
			for i in 10:
				var k := i / 9.0
				pts.append(Vector2(head.x * k, sin(k * 9.0 + t * 8.0) * 5.0 * (1.0 - k) * ext))
			draw_polyline(pts, Pal.SNAKE_DARK, 11.0, true)
			draw_polyline(pts, Pal.SNAKE, 7.0, true)
			var open := 1.0 if state == "rear" or state == "strike" else 0.2
			_fill(PackedVector2Array([head + Vector2(-d * 4, -6), head + Vector2(d * 14, -4 - open * 4.0), head + Vector2(d * 10, 0)]), Pal.SNAKE)
			_fill(PackedVector2Array([head + Vector2(-d * 4, 5), head + Vector2(d * 14, 3 + open * 4.0), head + Vector2(d * 10, 0)]), Pal.SNAKE_BELLY)
			if open > 0.5:
				draw_line(head + Vector2(d * 12, -3), head + Vector2(d * 12, 1), Pal.TOOTH, 1.5)
				draw_line(head + Vector2(d * 10, 0), head + Vector2(d * (18.0 + sin(t * 30.0) * 3.0), 0), Pal.MAW.lightened(0.3), 1.2)
		if state == "rear":
			draw_string(ThemeDB.fallback_font, Vector2(d * 8.0 - 12.0, -24), "sss", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Pal.BONE)
		if flash > 0.0:
			draw_circle(Vector2(d * ext * REACH, 0), 16.0, Color(1, 1, 1, 0.5))

	func draw_glow(g: Node2D) -> void:
		if dying > 0.0:
			return
		var d := float(dir)
		var head := global_position + Vector2(d * (ext * REACH + 4.0), -3.0)
		var a := 1.0 if state != "hide" else 0.7
		g.draw_circle(head, 1.5, Color(Pal.WOLF_EYE, a))
		g.draw_circle(head + Vector2(d * 4.0, 0), 1.5, Color(Pal.WOLF_EYE, a))
