## Static pieces of the cave: floor slabs, ceiling, background layers, pickups, triggers.
class_name World
extends RefCounted


class Slab extends StaticBody2D:
	var rect := Rect2()

	func _init(r: Rect2) -> void:
		rect = r

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		position = rect.position
		var cs := CollisionShape2D.new()
		var s := RectangleShape2D.new()
		s.size = rect.size
		cs.shape = s
		cs.position = rect.size * 0.5
		add_child(cs)

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(rect.position.x) * 7 + int(rect.position.y)
		# anything below the surface is bare rock; up top it grows grass
		var underground := rect.position.y > 700.0
		var body := Pal.STONE_DARK if underground else Pal.DIRT
		var cap := Pal.STONE if underground else Pal.GRASS
		# earth gets darker with depth, and the sunlit lip of the cap is brighter:
		# a flat slab of one colour is the most cartoon thing on screen
		# one Batch: every tuft and pebble in a single draw call
		var b := Batch.new()
		b.rect(Rect2(Vector2.ZERO, rect.size), body.darkened(0.30))
		b.rect(Rect2(Vector2.ZERO, Vector2(rect.size.x, minf(52.0, rect.size.y))), body)
		var cap_h := minf(12.0, rect.size.y)
		b.rect(Rect2(Vector2.ZERO, Vector2(rect.size.x, cap_h)), cap.darkened(0.22))
		b.rect(Rect2(Vector2.ZERO, Vector2(rect.size.x, cap_h * 0.45)), cap)
		if not underground:
			b.rect(Rect2(Vector2(0, cap_h - 3.0), Vector2(rect.size.x, 3)), Pal.GRASS_DARK)
			var x := 6.0
			while x < rect.size.x - 6.0:
				var h := rng.randf_range(5.0, 11.0)
				b.tri(Vector2(x - 3, 1), Vector2(x + rng.randf_range(-2.0, 2.0), -h), Vector2(x + 3, 1), Pal.GRASS_DARK)
				x += rng.randf_range(14.0, 34.0)
		var n := int(rect.size.x / 55.0) + 1
		for i in n:
			var p := Vector2(rng.randf_range(4.0, maxf(5.0, rect.size.x - 4.0)),
				rng.randf_range(cap_h + 6.0, maxf(cap_h + 7.0, minf(rect.size.y - 4.0, 140.0))))
			b.circle(p, rng.randf_range(2.0, 5.0), Pal.DIRT_DARK if not underground else Pal.STONE_DARK.darkened(0.2), 10)
		b.draw(self)


class Ceiling extends Node2D:
	var _pen: Batch             ## its picture, collected into one draw call
	var width := 0.0
	var trap_zones: Array = []

	## Outdoors now, so there is no roof: only an overhanging rock shelf above
	## each loose spot, which is what the falling stones come off.
	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for z in trap_zones:
			var x0: float = float(z[0]) - 70.0
			var wd: float = float(z[1]) + 140.0
			_pen.draw_rect(Rect2(x0, -260, wd, 300), Pal.STONE_DARK)
			_pen.draw_rect(Rect2(x0, 30, wd, 10), Pal.STONE)
			var x := x0 + 24.0
			while x < x0 + wd - 20.0:
				var ln := rng.randf_range(34.0, 96.0)
				var hw := rng.randf_range(14.0, 28.0)
				_pen.draw_colored_polygon(PackedVector2Array([
					Vector2(x - hw, 38), Vector2(x + hw, 38), Vector2(x, 38 + ln)]), Pal.STONE_DARK)
				_pen.draw_line(Vector2(x - 5, 40), Vector2(x + 4, 38 + ln * 0.6), Pal.OCHRE, 2.5, true)
				x += rng.randf_range(80.0, 150.0)


class SkyFill extends Node2D:
	var _pen: Batch             ## its picture, collected into one draw call
	## Fixed to the screen, never scrolls: the sky is effectively at infinity.
	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		_pen.draw_polygon(
			PackedVector2Array([Vector2(-60, -60), Vector2(1400, -60), Vector2(1400, 840), Vector2(-60, 840)]),
			PackedColorArray([Pal.SKY_HIGH, Pal.SKY_HIGH, Pal.SKY_LOW, Pal.SKY_LOW]))
		var sun := Vector2(1040, 118)
		for i in 5:
			_pen.draw_circle(sun, 64.0 + i * 26.0, Color(Pal.SUN, 0.10 - i * 0.015))
		_pen.draw_circle(sun, 52.0, Pal.SUN)


class Clouds extends Node2D:
	var _pen: Batch             ## its picture, collected into one draw call
	var width := 3200.0
	var count := 7
	var top := 90.0

	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		for i in count:
			var r := absf(fmod(sin(float(i) * 7.13) * 4371.7, 1.0))
			_puff(Vector2((i + 0.5) * width / count, top + r * 110.0), 0.65 + r * 0.7)

	func _puff(at: Vector2, s: float) -> void:
		var col := Color(1, 1, 1, 0.9)
		for o in [[-40.0, 8.0, 26.0], [-12.0, -12.0, 34.0], [20.0, -4.0, 28.0], [44.0, 10.0, 22.0], [4.0, 14.0, 24.0]]:
			_pen.draw_circle(at + Vector2(o[0] * s, o[1] * s), o[2] * s, col)


class Ridge extends Node2D:
	var _pen: Batch             ## its picture, collected into one draw call
	## One band of hills or mountains. The outline is a sum of sine waves whose
	## wavelengths divide the tile width exactly, so the left and right edges
	## always meet and the band can repeat forever without a visible seam.
	var width := 2560.0
	var base_y := 520.0
	var col := Color.WHITE
	var rim := Color.WHITE
	## each entry: [how many peaks across the tile, height, phase, sharpness]
	var peaks: Array = [[1.0, 200.0, 0.0, 0.8], [3.0, 70.0, 1.7, 0.9], [7.0, 24.0, 0.4, 1.0]]
	var snow_line := -1.0
	var tree_count := 0
	var tree_col := Color.WHITE
	var tree_h := 50.0

	func _height(x: float) -> float:
		var y := base_y
		for p in peaks:
			y -= pow(absf(sin(PI * float(p[0]) * x / width + float(p[2]))), float(p[3])) * float(p[1])
		return y

	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		var crest := PackedVector2Array()
		var x := 0.0
		while x <= width + 0.1:
			crest.append(Vector2(x, _height(x)))
			x += 14.0
		var body := PackedVector2Array(crest)
		body.append(Vector2(width, 1500))
		body.append(Vector2(0, 1500))
		_pen.draw_colored_polygon(body, col)
		_pen.draw_polyline(crest, rim, 5.0, true)
		if snow_line > 0.0:
			var run := PackedVector2Array()
			for p in crest:
				if p.y < snow_line:
					run.append(p)
				else:
					if run.size() > 1:
						_pen.draw_polyline(run, Pal.SNOW, 8.0, true)
					run = PackedVector2Array()
			if run.size() > 1:
				_pen.draw_polyline(run, Pal.SNOW, 8.0, true)
		for i in tree_count:
			var tx := (i + 0.5) * width / float(tree_count)
			var r := absf(fmod(sin(float(i) * 12.9898) * 43758.5453, 1.0))
			_conifer(Vector2(tx, _height(tx) + 3.0), tree_h * (0.7 + r * 0.6))

	func _conifer(at: Vector2, h: float) -> void:
		_pen.draw_line(at, at + Vector2(0, -h * 0.3), tree_col, maxf(2.0, h * 0.1), true)
		for i in 3:
			var top := at.y - h * (0.3 + i * 0.24)
			var sp := h * 0.32 * (1.0 - i * 0.22)
			_pen.draw_colored_polygon(PackedVector2Array([
				Vector2(at.x - sp, top), Vector2(at.x, top - h * 0.34), Vector2(at.x + sp, top)]), tree_col)


class CaveWall extends Node2D:
	var _pen: Batch             ## its picture, collected into one draw call
	var variant := 0

	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 100 + variant
		var tone := Color(Pal.CAVE_BOTTOM, 0.35) if variant == 0 else Color(Pal.CAVE_TOP, 0.55)
		for i in 40:
			var p := Vector2(rng.randf_range(0.0, 2560.0), rng.randf_range(80.0, 640.0))
			_pen.draw_set_transform(p, rng.randf_range(0.0, PI), Vector2(rng.randf_range(1.2, 2.8), 1.0))
			_pen.draw_circle(Vector2.ZERO, rng.randf_range(30.0, 90.0), tone)
		_pen.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if variant == 1:
			# two ochre handprints, a hint of the level 3 cave paintings
			for h in [Vector2(640, 300), Vector2(1900, 260)]:
				_hand(h, Color(Pal.OCHRE, 0.55))

	func _hand(at: Vector2, col: Color) -> void:
		_pen.draw_circle(at, 22.0, col)
		for i in 5:
			var a := -PI * 0.5 + (i - 2) * 0.42
			var tip := at + Vector2(cos(a), sin(a)) * 40.0
			_pen.draw_line(at, tip, col, 11.0)
			_pen.draw_circle(tip, 5.5, col)


class RockPickup extends Area2D:
	var _pen: Batch             ## its picture, collected into one draw call
	signal taken
	var t := 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 24.0
		cs.shape = c
		cs.position = Vector2(0, -10)
		add_child(cs)
		body_entered.connect(_on_body)

	func _on_body(body: Node) -> void:
		if body is CaveMan:
			if not (body as CaveMan).add_rock(2):
				return
			taken.emit()
			set_deferred("monitoring", false)
			call_deferred("queue_free")

	func _process(delta: float) -> void:
		t += delta
		if LevelBase.near_view(self):
			queue_redraw()

	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		var pulse := 0.5 + 0.5 * sin(t * 3.0)
		_pen.draw_arc(Vector2(0, -10), 22.0 + pulse * 6.0, 0.0, TAU, 32, Color(Pal.OCHRE, 0.25 + pulse * 0.35), 2.0)
		var pts := PackedVector2Array([Vector2(-13, -2), Vector2(-9, -16), Vector2(4, -19), Vector2(13, -8), Vector2(10, 0), Vector2(-6, 1)])
		_pen.draw_polygon(pts, PackedColorArray([Pal.STONE]))
		_pen.draw_polygon(PackedVector2Array([pts[0], pts[1], Vector2(-2, -6)]), PackedColorArray([Pal.STONE_DARK]))


class Trigger extends Area2D:
	signal tripped
	var fired := false
	var rect := Rect2()

	func _init(r: Rect2) -> void:
		rect = r

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		position = rect.position
		var cs := CollisionShape2D.new()
		var s := RectangleShape2D.new()
		s.size = rect.size
		cs.shape = s
		cs.position = rect.size * 0.5
		add_child(cs)
		body_entered.connect(_on_body)

	func _on_body(body: Node) -> void:
		if fired or not (body is CaveMan):
			return
		fired = true
		# defer so listeners can add physics nodes safely
		call_deferred("emit_signal", "tripped")


class Exit extends Area2D:
	var _pen: Batch             ## its picture, collected into one draw call
	signal reached
	var t := 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var s := RectangleShape2D.new()
		s.size = Vector2(60, 120)
		cs.shape = s
		cs.position = Vector2(0, -60)
		add_child(cs)
		body_entered.connect(func(b: Node) -> void:
			if b is CaveMan:
				call_deferred("emit_signal", "reached")
		)

	func _process(delta: float) -> void:
		t += delta
		if LevelBase.near_view(self):
			queue_redraw()

	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		var glow := 0.6 + 0.4 * sin(t * 2.0)
		_pen.draw_polygon(PackedVector2Array([Vector2(-36, 0), Vector2(-30, -110), Vector2(0, -140), Vector2(30, -110), Vector2(36, 0)]), PackedColorArray([Color(Pal.OCHRE, 0.25 * glow)]))
		_pen.draw_polygon(PackedVector2Array([Vector2(-22, 0), Vector2(-18, -90), Vector2(0, -112), Vector2(18, -90), Vector2(22, 0)]), PackedColorArray([Color(Pal.BONE, 0.85 * glow)]))


class BerryBush extends Area2D:
	var _pen: Batch             ## its picture, collected into one draw call
	## Health fruit: a grape vine. Touch it and he eats the grapes (or keeps
	## them, if he isn't hurt, and eats them himself when he is).
	signal taken
	var t := 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 26.0
		cs.shape = c
		cs.position = Vector2(0, -18)
		add_child(cs)
		body_entered.connect(_on_body)

	func _on_body(body: Node) -> void:
		if body is CaveMan:
			if not (body as CaveMan).add_berry():
				return
			taken.emit()
			set_deferred("monitoring", false)
			call_deferred("queue_free")

	func _process(delta: float) -> void:
		t += delta
		if LevelBase.near_view(self):
			queue_redraw()

	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	## A wild grape vine: a curling stem with two lobed leaves, and a heavy
	## bunch of glossy purple grapes hanging from it, swaying a little, with
	## a soft glow and now and then a glint so it's easy to spot.
	func _paint() -> void:
		var pulse := 0.5 + 0.5 * sin(t * 2.4)
		var sway := sin(t * 1.6) * 2.0
		_pen.draw_circle(Vector2(0, -24), 30.0 + pulse * 4.0, Color("b07ad8", 0.10 + 0.08 * pulse))
		# the stem, curling up from the ground
		var stem := PackedVector2Array()
		for i in 9:
			var k := i / 8.0
			stem.append(Vector2(-14.0 + sin(k * 4.0) * 6.0 + k * 20.0, -k * 52.0))
		_pen.draw_polyline(stem, Color("5a3d22"), 4.0)
		# a tendril curl
		var curl := PackedVector2Array()
		for i in 10:
			var a := i * 0.7
			curl.append(Vector2(8, -50) + Vector2(cos(a), sin(a)) * (7.0 - i * 0.6))
		_pen.draw_polyline(curl, Color("7a9a3a"), 1.8)
		# two vine leaves: five lobes each
		for lf in [[Vector2(-18, -40), 1.0], [Vector2(12, -56), -1.0]]:
			var c: Vector2 = lf[0]
			var fl: float = lf[1]
			var leaf := PackedVector2Array()
			for i in 11:
				var ang := -PI * 0.5 + (i - 5) * 0.55
				var r := 13.0 if i % 2 == 0 else 8.0
				leaf.append(c + Vector2(cos(ang) * r * fl, sin(ang) * r) + Vector2(0, 6))
			leaf.append(c + Vector2(0, 8))
			_pen.draw_colored_polygon(leaf, Color("4f7d34"))
			_pen.draw_line(c + Vector2(0, 7), c + Vector2(0, -4), Color("3a5e26"), 1.5)
		# the bunch: rows of grapes, wide at the top, to a point at the bottom
		var top := Vector2(6 + sway, -46)
		_pen.draw_line(Vector2(6, -52), top, Color("5a3d22"), 3.0)
		var rows := [4, 4, 3, 2, 1]
		for r in rows.size():
			var n: int = rows[r]
			for i in n:
				var g := top + Vector2((i - (n - 1) * 0.5) * 8.5, 6.0 + r * 7.5)
				_pen.draw_circle(g, 5.4, Color("3e1a52"))
				_pen.draw_circle(g, 4.6, Color("7b3aa0").lerp(Color("5b2a7a"), r / 5.0))
				_pen.draw_circle(g + Vector2(-1.6, -1.8), 1.5, Color("e6ccf5"))
		# a glint now and then
		var glint := fmod(t * 0.6, 2.2)
		if glint < 0.3:
			var k := sin(glint / 0.3 * PI)
			var c := top + Vector2(10, 4)
			var r := 7.0 * k
			if r > 1.5:
				_pen.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.25, 0), c + Vector2(0, r), c + Vector2(-r * 0.25, 0)]), Color(1, 1, 1, k))
				_pen.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(0, r * 0.25), c + Vector2(r, 0), c + Vector2(0, -r * 0.25)]), Color(1, 1, 1, k))


class DistantBoar extends Node2D:
	var _pen: Batch             ## its picture, collected into one draw call
	## Tuskar, grazing on a far hillside long before the arena. He rides the
	## hills' parallax band, so he drifts past like real scenery instead of
	## hanging in the air over the level.
	var t := 0.0

	func _ready() -> void:
		scale = Vector2(0.62, 0.62)
		modulate = Color(1, 1, 1, 0.55)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		var c := Pal.TREE_DARK
		var graze := sin(t * 0.7) * 4.0
		for i in 4:
			var lx := -34.0 + i * 22.0
			_pen.draw_line(Vector2(lx, -22), Vector2(lx, 0), c, 8.0)
		_pen.draw_set_transform(Vector2(0, -36), 0.0, Vector2(1.75, 1.0))
		_pen.draw_circle(Vector2.ZERO, 30.0, c)
		_pen.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_pen.draw_circle(Vector2(-48, -30 + graze), 19.0, c)
		_pen.draw_line(Vector2(-58, -18 + graze), Vector2(-72, -34 + graze), c, 4.0)
		_pen.draw_polygon(PackedVector2Array([
			Vector2(-22, -62), Vector2(-12, -76), Vector2(0, -62), Vector2(12, -74), Vector2(24, -62)
		]), PackedColorArray([c]))


class Bamboo extends AnimatableBody2D:
	var _pen: Batch             ## its picture, collected into one draw call
	## A cut bamboo pole that slides or bobs on a loop. AnimatableBody2D with
	## sync_to_physics is what lets it carry the caveman while it moves.
	var size := Vector2(110, 18)
	var axis := Vector2(0, 1)     ## direction of travel: (0,1) bobs, (1,0) slides
	var span := 60.0              ## how far from home, each way
	var period := 2.6
	var phase := 0.0
	var _home := Vector2.ZERO
	var _t := 0.0

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		sync_to_physics = true
		_home = position
		var cs := CollisionShape2D.new()
		var s := RectangleShape2D.new()
		s.size = size
		cs.shape = s
		add_child(cs)

	func _physics_process(delta: float) -> void:
		_t += delta
		position = _home + axis * span * sin((_t / period + phase) * TAU)
		queue_redraw()

	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		var half := size * 0.5
		_pen.draw_rect(Rect2(-half, size), Pal.OCHRE_DARK)
		_pen.draw_rect(Rect2(-half, Vector2(size.x, 5)), Pal.OCHRE)
		var n := int(size.x / 26.0)
		for i in range(1, n):
			var x := -half.x + i * 26.0
			_pen.draw_line(Vector2(x, -half.y), Vector2(x, half.y), Pal.OCHRE_DEEP, 3.0)


class SpringBush extends Area2D:
	var _pen: Batch             ## its picture, collected into one draw call
	## A springy bush. Land on it and it throws him far higher than a jump.
	## Stone age has no metal springs, so the shrub does the work.
	signal sprung
	var launch := -1050.0
	var squash := 0.0
	var t := 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		monitoring = true
		var cs := CollisionShape2D.new()
		var s := RectangleShape2D.new()
		s.size = Vector2(58, 28)
		cs.shape = s
		cs.position = Vector2(0, -14)
		add_child(cs)

	func _physics_process(delta: float) -> void:
		t += delta
		squash = maxf(squash - delta * 3.0, 0.0)
		var near := true
		var p := get_tree().get_first_node_in_group("player")
		if p != null:
			var man := p as CaveMan
			# only fires when he is coming down onto it, never on the way up
			if not man.dead and man.velocity.y > -50.0 and overlaps_body(man):
				man.launch(launch)
				squash = 1.0
				sprung.emit()
			near = absf(man.global_position.x - global_position.x) < 820.0
		if near:
			queue_redraw()

	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		# A springy shrub: woody stems at the base, overlapping leafy masses with
		# scalloped edges, and loose leaves breaking the silhouette. Perfect
		# circles are what made it read as a cartoon blob rather than a plant.
		var c := 1.0 - squash * 0.55          # 1 at rest, flattened as it fires
		var sq := Vector2(1.0 + squash * 0.35, c)
		var breeze := sin(t * 1.4) * 0.035

		# woody stems
		for stem in [[-9.0, -15.0], [3.0, -18.0], [13.0, -12.0]]:
			var top := Vector2(stem[0], stem[1]) * sq
			_pen.draw_line(Vector2(0, -1), top, Pal.OUTLINE, 7.0, true)
			_pen.draw_line(Vector2(0, -1), top, Pal.VINE, 4.0, true)

		# leafy masses, back ones darker so the bush has depth
		var masses := [
			[-22.0, -18.0, 15.0, 0], [21.0, -20.0, 14.0, 0],
			[-11.0, -30.0, 16.0, 1], [11.0, -26.0, 16.0, 1], [0.0, -19.0, 15.0, 1],
		]
		for mm in masses:
			var at := Vector2(mm[0], mm[1]) * sq
			var rr: float = mm[2]
			var front: bool = mm[3] == 1
			_scallop(at, rr + 2.5, sq, Pal.TRAP_DARK if front else Pal.TREE_DARK)
			if front:
				_scallop(at, rr, sq, Pal.TRAP_GREEN)

		# loose leaves poking out of the silhouette
		for i in 5:
			var a := -2.9 + i * 0.62 + breeze
			var at2 := Vector2(cos(a) * 26.0, -26.0 + sin(a) * 15.0) * sq
			_leaflet(at2, a, 9.0 + (i % 3) * 2.0, sq)

		if squash > 0.0:
			_pen.draw_arc(Vector2(0, -16), 30.0 + (1.0 - squash) * 30.0, 0.0, TAU, 20, Color(Pal.GRASS, squash * 0.55), 3.0)

	## A rounded mass with a bumpy rim, so the edge reads as clustered leaves.
	func _scallop(at: Vector2, r: float, sq: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 11:
			var a := TAU * i / 11.0
			var rr := r * (1.0 + 0.14 * sin(a * 5.0 + at.x * 0.3))
			pts.append(at + Vector2(cos(a) * rr * sq.x, sin(a) * rr * sq.y))
		_pen.draw_colored_polygon(pts, col)

	func _leaflet(at: Vector2, ang: float, ln: float, sq: Vector2) -> void:
		var d := Vector2(cos(ang), sin(ang) * sq.y)
		var n := Vector2(-d.y, d.x)
		var tip := at + d * ln
		var mid := at + d * ln * 0.45
		var pts := PackedVector2Array([at])
		for i in range(1, 6):
			var u := i / 5.0
			pts.append(at.lerp(mid + n * ln * 0.34, u).lerp((mid + n * ln * 0.34).lerp(tip, u), u))
		for i in range(1, 5):
			var u2 := i / 5.0
			pts.append(tip.lerp(mid - n * ln * 0.34, u2).lerp((mid - n * ln * 0.34).lerp(at, u2), u2))
		_pen.draw_colored_polygon(pts, Pal.GRASS)
		_pen.draw_line(at, tip, Pal.TRAP_DARK, 1.2, true)

class ThrownRock extends Area2D:
	var _pen: Batch             ## its picture, collected into one draw call
	## A rock in flight. Hits critters only, arcs under gravity, dies on contact.
	var vel := Vector2.ZERO
	var life := 2.2
	var spin := 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 4          ## critters
		monitoring = true
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 9.0
		cs.shape = c
		add_child(cs)

	func _physics_process(delta: float) -> void:
		life -= delta
		vel.y += 900.0 * delta
		position += vel * delta
		spin += delta * 14.0
		for a in get_overlapping_areas():
			if a.has_method("take_hit"):
				a.take_hit(3, signi(int(vel.x)))
				queue_free()
				return
		if life <= 0.0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		_pen.draw_set_transform(Vector2.ZERO, spin, Vector2.ONE)
		_pen.draw_circle(Vector2.ZERO, 8.0, Pal.STONE)
		_pen.draw_circle(Vector2(-3, -3), 3.0, Pal.STONE_DARK)
		_pen.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class StickPickup extends Area2D:
	var _pen: Batch             ## its picture, collected into one draw call
	## The first weapon. Deliberately out of the way: it sits up on a ledge,
	## so the player has to climb for the reach upgrade rather than walk into it.
	signal taken
	var t := 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 26.0
		cs.shape = c
		cs.position = Vector2(0, -16)
		add_child(cs)
		body_entered.connect(_on_body)

	func _on_body(body: Node) -> void:
		if body is CaveMan:
			(body as CaveMan).pick_up_stick()
			taken.emit()
			set_deferred("monitoring", false)
			call_deferred("queue_free")

	func _process(delta: float) -> void:
		t += delta
		if LevelBase.near_view(self):
			queue_redraw()

	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		var pulse := 0.5 + 0.5 * sin(t * 2.6)
		_pen.draw_arc(Vector2(0, -16), 22.0 + pulse * 5.0, 0.0, TAU, 24, Color(Pal.OCHRE, 0.2 + pulse * 0.25), 2.0)
		var lift := sin(t * 1.8) * 2.0
		_pen.draw_line(Vector2(-20, -10 + lift), Vector2(18, -22 + lift), Pal.OCHRE_DEEP, 7.0)
		_pen.draw_circle(Vector2(20, -23 + lift), 7.0, Pal.OCHRE_DARK)
		_pen.draw_circle(Vector2(18, -26 + lift), 2.5, Pal.OCHRE)


class Canopy extends Node2D:
	var _pen: Batch             ## its picture, collected into one draw call
	## Distant treetops seen over the jungle: rounded crowns on a rolling line,
	## washed out by the haze between here and there.
	var width := 2400.0
	var base_y := 470.0
	var col := Pal.JUNGLE_FAR

	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		var crowns := 16
		for i in crowns:
			var x := (i + 0.5) * width / float(crowns)
			var r := absf(fmod(sin(float(i) * 9.71) * 5123.3, 1.0))
			var top := base_y - 40.0 - r * 46.0 - sin(TAU * x / width) * 22.0
			var rad := 46.0 + r * 26.0
			var pts := PackedVector2Array()
			for k in 13:
				var a := PI + PI * k / 12.0
				var rr := rad * (1.0 + 0.16 * sin(a * 6.0 + i))
				pts.append(Vector2(x + cos(a) * rr, top + sin(a) * rr * 0.7))
			pts.append(Vector2(x + rad, base_y + 60.0))
			pts.append(Vector2(x - rad, base_y + 60.0))
			_pen.draw_colored_polygon(pts, col)
		_pen.draw_rect(Rect2(0, base_y + 10.0, width, 200), col)
		_pen.draw_rect(Rect2(0, base_y + 10.0, width, 26), Color(Pal.MIST, 0.5))


class JungleCliff extends Node2D:
	var _pen: Batch             ## its picture, collected into one draw call
	## A weathered rock wall behind the trees, pocked with cave mouths and
	## marked with hand prints — the stone age lives here, not just the player.
	var width := 2000.0
	var top_y := 360.0

	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		var face := PackedVector2Array()
		var x := 0.0
		while x <= width + 0.1:
			face.append(Vector2(x, top_y - 34.0 * absf(sin(PI * x / width + 0.4))
				- 16.0 * absf(sin(3.0 * PI * x / width)) ))
			x += 26.0
		var body := PackedVector2Array(face)
		body.append(Vector2(width, 1400))
		body.append(Vector2(0, 1400))
		_pen.draw_colored_polygon(body, Pal.CLIFF)
		_pen.draw_polyline(face, Pal.CLIFF_DARK, 5.0, false)
		# strata
		for i in 4:
			var y := top_y + 40.0 + i * 34.0
			_pen.draw_line(Vector2(0, y), Vector2(width, y + 6.0), Pal.CLIFF_DARK, 2.5, false)
		# cave mouths
		for cx in [width * 0.22, width * 0.68]:
			var mouth := PackedVector2Array()
			for k in 15:
				var a := PI + PI * k / 14.0
				mouth.append(Vector2(cx + cos(a) * 54.0, top_y + 96.0 + sin(a) * 62.0))
			mouth.append(Vector2(cx + 54.0, top_y + 96.0))
			_pen.draw_colored_polygon(mouth, Pal.CAVE_MOUTH)
			_pen.draw_polyline(mouth, Pal.CLIFF_DARK, 4.0, false)
			# hand prints pressed beside the entrance
			for h in 3:
				_hand(Vector2(cx + 72.0 + h * 26.0, top_y + 54.0 + (h % 2) * 22.0), 0.8 + (h % 2) * 0.2)
		# a standing stone on the clifftop
		var sx := width * 0.45
		_pen.draw_colored_polygon(PackedVector2Array([
			Vector2(sx - 13, top_y - 46), Vector2(sx - 9, top_y - 104), Vector2(sx + 8, top_y - 110),
			Vector2(sx + 14, top_y - 44)]), Pal.CLIFF_DARK)

	func _hand(at: Vector2, s: float) -> void:
		_pen.draw_circle(at, 7.0 * s, Pal.PAINT)
		for i in 5:
			var a := -2.5 + i * 0.5
			_pen.draw_line(at, at + Vector2(cos(a), sin(a)) * 11.0 * s, Pal.PAINT, 2.6 * s, false)


class JungleWall extends Node2D:
	var _pen: Batch             ## its picture, collected into one draw call
	## The near jungle: trunks, big fronds and hanging vines. Dark and dense, so
	## the lit playfield in front of it reads clearly.
	var width := 1600.0
	var floor_y := 620.0

	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		_pen.draw_rect(Rect2(0, floor_y - 40.0, width, 240), Pal.JUNGLE_NEAR)
		for i in 5:
			var x := (i + 0.5) * width / 5.0
			var r := absf(fmod(sin(float(i) * 3.77) * 2931.1, 1.0))
			var h := 210.0 + r * 90.0
			var lean := (r - 0.5) * 16.0
			# trunk
			_pen.draw_colored_polygon(PackedVector2Array([
				Vector2(x - 13, floor_y), Vector2(x - 9 + lean, floor_y - h),
				Vector2(x + 9 + lean, floor_y - h), Vector2(x + 13, floor_y)]), Pal.TRUNK)
			_pen.draw_line(Vector2(x - 4, floor_y - 10), Vector2(x - 2 + lean, floor_y - h + 10), Pal.TRUNK_DARK, 3.0, false)
			# crown of fronds
			for k in 7:
				var a := -2.95 + k * 0.49
				_frond(Vector2(x + lean, floor_y - h + 8.0), a, 74.0 + r * 26.0,
					Pal.FROND_LIGHT if k % 2 == 0 else Pal.FROND)
			# a vine hanging from the crown
			var vx := x + lean + 22.0
			var vine := PackedVector2Array()
			for k in 9:
				var u := k / 8.0
				vine.append(Vector2(vx + sin(u * 4.0) * 9.0, floor_y - h + 20.0 + u * (h * 0.72)))
			_pen.draw_polyline(vine, Pal.FROND, 3.0, false)
		# ferns along the bottom
		for i in 14:
			var fx := (i + 0.5) * width / 14.0
			for k in 5:
				var a := -2.7 + k * 0.6
				_frond(Vector2(fx, floor_y + 20.0), a, 34.0, Pal.FROND)

	func _frond(at: Vector2, ang: float, ln: float, col: Color) -> void:
		var d := Vector2(cos(ang), sin(ang))
		var n := Vector2(-d.y, d.x)
		var pts := PackedVector2Array([at])
		for i in range(1, 7):
			var u := i / 6.0
			pts.append(at + d * ln * u + n * sin(u * PI) * ln * 0.19)
		for i in range(1, 7):
			var u2 := 1.0 - i / 6.0
			pts.append(at + d * ln * u2 - n * sin(u2 * PI) * ln * 0.19)
		_pen.draw_colored_polygon(pts, col)
		_pen.draw_line(at, at + d * ln, col.darkened(0.3), 1.6, false)


class Gem extends Area2D:
	var _pen: Batch             ## its picture, collected into one draw call
	## The level's one hidden gem. Tucked somewhere only a player who goes
	## looking will reach.
	signal found
	var t := 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 22.0
		cs.shape = c
		cs.position = Vector2(0, -16)
		add_child(cs)
		body_entered.connect(_on_body)

	func _on_body(body: Node) -> void:
		if body is CaveMan:
			found.emit()
			set_deferred("monitoring", false)
			call_deferred("queue_free")

	func _process(delta: float) -> void:
		t += delta
		if LevelBase.near_view(self):
			queue_redraw()

	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		var at := Vector2(0, -20 + sin(t * 1.6) * 4.0)
		var pulse := 0.5 + 0.5 * sin(t * 2.4)
		_pen.draw_circle(at, 26.0 + pulse * 7.0, Color(Pal.GEM_LIGHT, 0.14 + pulse * 0.12))
		# a brilliant cut: flat table, a crown of facets, a deep pavilion to a point
		var w := 13.0
		var girdle_l := at + Vector2(-w, -2)
		var girdle_r := at + Vector2(w, -2)
		var point := at + Vector2(0, 17)
		_pen.draw_colored_polygon(PackedVector2Array([girdle_l, girdle_r, point]), Pal.GEM)
		_pen.draw_colored_polygon(PackedVector2Array([girdle_l, at + Vector2(-2, -2), point]), Pal.GEM_DEEP)
		_pen.draw_colored_polygon(PackedVector2Array([
			girdle_l, at + Vector2(-w * 0.55, -11), at + Vector2(w * 0.55, -11), girdle_r]), Pal.GEM_LIGHT)
		_pen.draw_colored_polygon(PackedVector2Array([
			at + Vector2(-w * 0.55, -11), at + Vector2(-w * 0.2, -11), at + Vector2(-w * 0.35, -2), girdle_l]), Pal.GEM)
		for fx in [-0.55, 0.0, 0.55]:
			_pen.draw_line(at + Vector2(w * fx, -2), point, Pal.GEM_DEEP, 1.2, false)
		_pen.draw_line(girdle_l, girdle_r, Pal.GEM_DEEP, 1.6, false)
		var s := absf(sin(t * 1.1))
		if s > 0.82:
			var k := (s - 0.82) / 0.18
			for a in [0.0, PI * 0.5, PI, PI * 1.5]:
				_pen.draw_line(at + Vector2(cos(a), sin(a)) * 6.0,
					at + Vector2(cos(a), sin(a)) * (10.0 + k * 9.0), Color.WHITE, 2.0, false)

## ================================================================ PANORAMA
## The background is not tiled. Each depth band is one long strip authored for
## the whole level, so nothing repeats. Set pieces are placed with at(), which
## converts "where the player is in the world" into "where this band must draw
## it" — parallax means those two differ, and more so the further back a band is.
class Panorama extends Node2D:
	var _pen: Batch             ## its picture, collected into one draw call
	var length := 3000.0
	var s := 0.4               ## this band's horizontal parallax speed
	var seedn := 1

	## Band x that sits centre-screen when the player reaches world_x.
	func at(world_x: float) -> float:
		return world_x * s + 640.0 * (1.0 - s)

	func rnd(i: int) -> float:
		return absf(fmod(sin(float(i) * 12.9898 + float(seedn) * 78.233) * 43758.5453, 1.0))

	## A skyline that never comes round again: three waves whose lengths share
	## no common multiple inside the level.
	func line(x: float, base: float, a: float) -> float:
		return base - a * (0.55 * sin(x * 0.0021 + seedn) + 0.3 * sin(x * 0.0057 + seedn * 2.1)
			+ 0.15 * sin(x * 0.0133 + seedn * 0.7))

	func strip(base: float, a: float, step: float, col: Color) -> void:
		_pen.draw_colored_polygon(strip_pts(base, a, step), col)

	## The strip's outline, for bands that draw through a Batch.
	func strip_pts(base: float, a: float, step: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var x := -20.0
		while x <= length + 20.0:
			pts.append(Vector2(x, line(x, base, a)))
			x += step
		pts.append(Vector2(length + 20.0, 1600))
		pts.append(Vector2(-20.0, 1600))
		return pts

	func blob(c: Vector2, r: float, flat: float, col: Color, k: int) -> void:
		_pen.draw_colored_polygon(blob_pts(c, r, flat, k), col)

	func blob_pts(c: Vector2, r: float, flat: float, k: int) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 14:
			var a := TAU * i / 14.0
			var rr := r * (1.0 + 0.15 * sin(a * 5.0 + float(k)))
			pts.append(c + Vector2(cos(a) * rr, sin(a) * rr * flat))
		return pts


class FarHighlands extends Panorama:
	## Tepuis: sheer table mountains rising out of the forest, the landscape of
	## the Amazon highlands.
	## This band moves at a tenth of the player's speed, so across the entire
	## level it slides only ~800 px: distant things never leave the view. So the
	## tepuis are composed as one skyline across the band, spaced so they never
	## touch, rather than placed per stretch like the nearer set pieces.
	## [band x, base, top, width, seed, has a waterfall]
	const TEPUIS := [
		[300.0, 470.0, 186.0, 380.0, 3, true],
		[1060.0, 474.0, 262.0, 250.0, 7, false],
		[1760.0, 470.0, 214.0, 330.0, 11, true],
	]

	## Where the waterfalls go, worked out from the same data the drawing uses.
	## The level needs these at build time, before anything has been drawn.
	func waterfalls() -> Array:
		var out := []
		for tp in TEPUIS:
			if tp[5]:
				var cx := float(tp[0])
				out.append([Vector2(cx + float(tp[3]) * 0.16, float(tp[2]) + 6.0), float(tp[1]) - float(tp[2]) - 10.0])
		return out

	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		strip(478.0, 64.0, 24.0, Pal.MIST)
		for tp in TEPUIS:
			_tepui(float(tp[0]), float(tp[1]), float(tp[2]), float(tp[3]), int(tp[4]))
		strip(498.0, 26.0, 20.0, Pal.TEPUI_SHADE.lerp(Pal.MIST, 0.6))

	func _tepui(cx: float, base: float, top: float, w: float, k: int) -> void:
		var pts := PackedVector2Array([Vector2(cx - w * 0.64, base), Vector2(cx - w * 0.5, top + 34.0)])
		for i in 10:
			pts.append(Vector2(cx - w * 0.5 + w * i / 9.0, top + rnd(i + k * 13) * 12.0))
		pts.append(Vector2(cx + w * 0.5, top + 28.0))
		pts.append(Vector2(cx + w * 0.66, base))
		_pen.draw_colored_polygon(pts, Pal.TEPUI)
		# light comes from the upper right, so the left walls sit in shade
		_pen.draw_colored_polygon(PackedVector2Array([
			Vector2(cx - w * 0.64, base), Vector2(cx - w * 0.5, top + 34.0),
			Vector2(cx - w * 0.2, top + 40.0), Vector2(cx - w * 0.3, base)]), Pal.TEPUI_SHADE)
		for i in 7:
			var sx := cx - w * 0.42 + w * i / 7.0 + rnd(i + k) * 14.0
			_pen.draw_line(Vector2(sx, top + 20.0), Vector2(sx - 6.0, base - 10.0), Pal.TEPUI_SHADE, 2.0, false)
		# a crown of forest along the rim
		for i in 8:
			blob(Vector2(cx - w * 0.45 + w * i / 7.4, top + 2.0), 16.0 + rnd(i + k * 3) * 8.0, 0.55, Pal.CANOPY_FAR, i)


class Waterfall extends Node2D:
	var _pen: Batch             ## its picture, collected into one draw call
	## Animated: streaks run down the cliff and mist boils at the foot.
	var height := 260.0
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		_pen.draw_rect(Rect2(-9, 0, 18, height), Color(Pal.WATER, 0.55))
		for i in 6:
			var y := fmod(t * 120.0 + i * height / 6.0, height)
			_pen.draw_line(Vector2(-6 + i * 2.4, y), Vector2(-6 + i * 2.4, minf(height, y + 30.0)), Color(Pal.WATER, 0.9), 2.0, false)
		for i in 5:
			var ph := fmod(t * 0.6 + i * 0.2, 1.0)
			_pen.draw_circle(Vector2((i - 2) * 9.0, height - 4.0 - ph * 16.0), 8.0 + ph * 10.0, Color(Pal.WATER, 0.35 * (1.0 - ph)))


class CanopyBand extends Panorama:
	## The forest roof at mid distance, with giant emergent trees punching up
	## through it — the kapok-like giants that tower over a real rainforest.
	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		strip(508.0, 30.0, 20.0, Pal.CANOPY_FAR)
		var x := 0.0
		var i := 0
		while x < length:
			var r := rnd(i)
			blob(Vector2(x, line(x, 508.0, 30.0) - 16.0 - r * 26.0), 30.0 + r * 30.0, 0.6, Pal.CANOPY_FAR.darkened(0.06 + r * 0.08), i)
			x += 44.0 + rnd(i + 50) * 60.0
			i += 1
		for wx in [700.0, 2400.0, 3900.0, 5700.0, 8200.0]:
			_giant(at(wx), int(wx))
		_pen.draw_rect(Rect2(-20, 500, length + 40, 30), Color(Pal.MIST, 0.4))

	func _giant(cx: float, k: int) -> void:
		var base := line(cx, 508.0, 30.0)
		var h := 210.0 + rnd(k) * 70.0
		_pen.draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 9, base), Vector2(cx - 5, base - h), Vector2(cx + 5, base - h), Vector2(cx + 9, base)]), Pal.TRUNK.lerp(Pal.MIST, 0.45))
		for j in 5:
			blob(Vector2(cx - 48.0 + j * 24.0, base - h - 6.0 + absf(j - 2.0) * 8.0), 30.0, 0.42, Pal.EMERGENT, j + k)


class LightShafts extends Node2D:
	var _pen: Batch             ## its picture, collected into one draw call
	## Slanting beams through the canopy. Barely there, but they make the air
	## look thick and warm.
	var length := 1800.0

	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		for i in 5:
			var x := 180.0 + i * 330.0 + sin(float(i) * 2.3) * 60.0
			var w := 46.0 + (i % 3) * 22.0
			_pen.draw_colored_polygon(PackedVector2Array([
				Vector2(x, -40), Vector2(x + w, -40), Vector2(x - 170.0 + w * 1.6, 560), Vector2(x - 170.0, 560)]),
				Color(Pal.RAY, 0.07 + (i % 2) * 0.03))


class Birds extends Node2D:
	var _pen: Batch             ## its picture, collected into one draw call
	## A few birds wheeling far off. Life in the sky costs almost nothing.
	var t := 0.0
	var width := 2400.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		for i in 6:
			var x := fmod(t * (22.0 + i * 3.0) + i * 410.0, width)
			var y := 120.0 + sin(t * 0.5 + i) * 26.0 + (i % 3) * 34.0
			var f := sin(t * 7.0 + i) * 4.0
			_pen.draw_polyline(PackedVector2Array([Vector2(x - 8, y - f), Vector2(x, y), Vector2(x + 8, y - f)]),
				Color(Pal.TREE_DARK, 0.55), 1.8, false)


class StoryBand extends Panorama:
	## The band that changes with the journey: ancient trees, then bamboo, then
	## the painted caves, then the stone circle where Tuskar lives.
	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		strip(532.0, 22.0, 22.0, Pal.JUNGLE_MID)
		_ancient_tree(at(900.0), 0)
		_ancient_tree(at(2500.0), 1)
		_bamboo_grove(at(3200.0), at(4800.0))
		_painted_cliff(at(5000.0), at(7700.0))
		_stone_circle(at(8850.0))

	func _ancient_tree(cx: float, k: int) -> void:
		var base := line(cx, 532.0, 22.0)
		var h := 250.0 + k * 30.0
		var col := Pal.TRUNK.lerp(Pal.MIST, 0.28)
		# buttress roots flaring into the ground
		_pen.draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 62, base), Vector2(cx - 18, base - 70), Vector2(cx - 15, base - h),
			Vector2(cx + 15, base - h), Vector2(cx + 18, base - 70), Vector2(cx + 66, base)]), col)
		_pen.draw_line(Vector2(cx - 4, base - 60), Vector2(cx - 2, base - h + 20), col.darkened(0.2), 3.0, false)
		for j in 6:
			blob(Vector2(cx - 80.0 + j * 32.0, base - h - 10.0 + absf(j - 2.5) * 12.0), 44.0, 0.55, Pal.JUNGLE_MID.lerp(Pal.MIST, 0.15), j + k * 9)
		for j in 3:
			var vx := cx - 40.0 + j * 40.0
			var vine := PackedVector2Array()
			for m in 8:
				vine.append(Vector2(vx + sin(m * 0.8 + j) * 6.0, base - h + 20.0 + m * (h * 0.09)))
			_pen.draw_polyline(vine, Pal.FROND.lerp(Pal.MIST, 0.2), 2.5, false)

	func _bamboo_grove(x0: float, x1: float) -> void:
		var i := 0
		var x := x0
		while x < x1:
			var h := 190.0 + rnd(i + 300) * 120.0
			var base := line(x, 532.0, 22.0)
			var lean := (rnd(i + 400) - 0.5) * 18.0
			var col := Pal.BAMBOO if i % 2 == 0 else Pal.BAMBOO_DARK
			_pen.draw_line(Vector2(x, base), Vector2(x + lean, base - h), col, 7.0, false)
			var seg := 34.0
			var y := seg
			while y < h:
				var u := y / h
				_pen.draw_line(Vector2(x + lean * u - 5, base - y), Vector2(x + lean * u + 5, base - y), col.darkened(0.3), 2.0, false)
				y += seg
			for j in 3:
				var a := -1.2 - j * 0.5
				_pen.draw_line(Vector2(x + lean, base - h + j * 16.0),
					Vector2(x + lean + cos(a) * 26.0, base - h + j * 16.0 + sin(a) * -10.0), Pal.BAMBOO_DARK, 3.0, false)
			x += 18.0 + rnd(i) * 26.0
			i += 1

	func _painted_cliff(x0: float, x1: float) -> void:
		var top := 340.0
		var pts := PackedVector2Array()
		var x := x0 - 40.0
		pts.append(Vector2(x0 - 80.0, 560))
		while x <= x1 + 40.0:
			pts.append(Vector2(x, top + 30.0 * sin(x * 0.011) + 12.0 * sin(x * 0.031)))
			x += 28.0
		pts.append(Vector2(x1 + 80.0, 560))
		_pen.draw_colored_polygon(pts, Pal.CLIFF)
		for i in 5:
			var y := top + 60.0 + i * 30.0
			_pen.draw_line(Vector2(x0, y), Vector2(x1, y + 8.0), Pal.CLIFF_DARK, 2.5, false)
		var span := x1 - x0
		# two caves. Someone lives in the second: there is firelight inside
		_cave(x0 + span * 0.18, top + 120.0, false)
		_cave(x0 + span * 0.74, top + 118.0, true)
		# the mural: hunters with spears closing on a giant boar
		_mural(Vector2(x0 + span * 0.46, top + 92.0))

	func _cave(cx: float, cy: float, lit: bool) -> void:
		var mouth := PackedVector2Array()
		for k in 15:
			var a := PI + PI * k / 14.0
			mouth.append(Vector2(cx + cos(a) * 50.0, cy + sin(a) * 58.0))
		mouth.append(Vector2(cx + 50.0, cy + 34.0))
		mouth.append(Vector2(cx - 50.0, cy + 34.0))
		_pen.draw_colored_polygon(mouth, Pal.CAVE_MOUTH)
		if lit:
			for k in 4:
				_pen.draw_circle(Vector2(cx, cy + 18.0), 36.0 - k * 8.0, Color(Pal.FIRE, 0.14 + k * 0.1))

	func _mural(c: Vector2) -> void:
		var paint := Pal.PAINT
		# the boar: body, tusks, legs
		var body := PackedVector2Array()
		for k in 16:
			var a := TAU * k / 16.0
			body.append(c + Vector2(cos(a) * 46.0, sin(a) * 22.0))
		_pen.draw_colored_polygon(body, Color(paint, 0.85))
		_pen.draw_line(c + Vector2(44, -4), c + Vector2(64, -16), paint, 5.0, false)
		_pen.draw_line(c + Vector2(60, -6), c + Vector2(72, -22), Pal.SKULL, 3.0, false)
		for k in 4:
			_pen.draw_line(c + Vector2(-30.0 + k * 20.0, 18), c + Vector2(-32.0 + k * 20.0, 38), paint, 4.0, false)
		for k in 5:
			_pen.draw_line(c + Vector2(-34.0 + k * 14.0, -20), c + Vector2(-32.0 + k * 14.0, -32), paint, 2.5, false)
		# hunters closing in from both sides
		for side in [-1.0, 1.0]:
			for k in 2:
				var hx: float = c.x + float(side) * (78.0 + k * 30.0)
				var hy: float = c.y + 8.0 - k * 4.0
				_pen.draw_circle(Vector2(hx, hy - 24), 5.0, paint)
				_pen.draw_line(Vector2(hx, hy - 19), Vector2(hx, hy + 2), paint, 3.0, false)
				_pen.draw_line(Vector2(hx, hy + 2), Vector2(hx - 6, hy + 16), paint, 3.0, false)
				_pen.draw_line(Vector2(hx, hy + 2), Vector2(hx + 6, hy + 16), paint, 3.0, false)
				_pen.draw_line(Vector2(hx, hy - 12), Vector2(hx - float(side) * 34.0, hy - 22), paint, 2.2, false)
		for k in 4:
			var hp := c + Vector2(-120.0 + k * 22.0, -52.0 + (k % 2) * 10.0)
			_pen.draw_circle(hp, 5.0, paint)
			for f in 5:
				var a2 := -2.5 + f * 0.5
				_pen.draw_line(hp, hp + Vector2(cos(a2), sin(a2)) * 8.5, paint, 2.0, false)

	func _stone_circle(cx: float) -> void:
		var base := line(cx, 532.0, 22.0)
		for i in 7:
			var sx := cx - 180.0 + i * 60.0
			var h := 70.0 + rnd(i + 700) * 50.0
			var back := i % 2 == 1
			var col := Pal.CLIFF_DARK if back else Pal.CLIFF
			var lift := -14.0 if back else 0.0
			_pen.draw_colored_polygon(PackedVector2Array([
				Vector2(sx - 15, base + lift), Vector2(sx - 11, base + lift - h), Vector2(sx + 10, base + lift - h - 6),
				Vector2(sx + 15, base + lift)]), col)
		# a boar skull the size of a boulder, set on a flat rock in the middle
		var sk := Vector2(cx, base - 30.0)
		_pen.draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 44, base), Vector2(cx - 40, base - 16), Vector2(cx + 46, base - 16), Vector2(cx + 42, base)]), Pal.CLIFF_DARK)
		var skull := PackedVector2Array()
		for k in 14:
			var a := TAU * k / 14.0
			skull.append(sk + Vector2(cos(a) * 34.0 * (1.0 + 0.35 * maxf(0.0, cos(a))), sin(a) * 18.0))
		_pen.draw_colored_polygon(skull, Pal.SKULL)
		_pen.draw_circle(sk + Vector2(-6, -4), 6.0, Pal.CAVE_MOUTH)
		_pen.draw_line(sk + Vector2(36, 4), sk + Vector2(58, -22), Pal.SKULL, 5.0, false)
		_pen.draw_line(sk + Vector2(30, 8), sk + Vector2(48, -12), Pal.SKULL, 4.0, false)


class Undergrowth extends Panorama:
	## The near layer: LOW growth only. Ferns, broad leaves and mossy stones,
	## none taller than a man's waist, so nothing ever stands between the player
	## and what he is doing.
	## Built as one Batch: the whole band, end to end, is a single draw call.
	## A shader sways it in the wind: roots still, tips moving.
	func _enter_tree() -> void:
		if material == null:
			material = FX.sway_material(566.0, 4.5)

	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		var b := Batch.new()
		var x := 0.0
		var i := 0
		while x < length:
			var base := line(x, 566.0, 8.0)
			match int(rnd(i) * 4.0):
				0:
					_fern(b, Vector2(x, base), 40.0 + rnd(i + 5) * 24.0, i)
				1:
					_broadleaf(b, Vector2(x, base), 46.0 + rnd(i + 6) * 20.0, i)
				2:
					b.poly(blob_pts(Vector2(x, base - 10.0), 18.0 + rnd(i + 7) * 16.0, 0.6, i), Pal.CLIFF_DARK)
					b.poly(blob_pts(Vector2(x - 4, base - 20.0), 12.0, 0.4, i + 1), Pal.FROND)
				_:
					_fern(b, Vector2(x, base), 30.0, i)
			x += 70.0 + rnd(i + 99) * 150.0
			i += 1
		b.draw(self)

	func _fern(b: Batch, at: Vector2, h: float, _k: int) -> void:
		for j in 7:
			var a := -2.85 + j * 0.45
			var tip := at + Vector2(cos(a), sin(a)) * h
			b.line(at, tip, Pal.FROND if j % 2 == 0 else Pal.FROND_LIGHT, 3.0)
			for m in 4:
				var u := 0.3 + m * 0.18
				var p := at.lerp(tip, u)
				b.line(p, p + Vector2(cos(a - 0.8), sin(a - 0.8)) * 7.0, Pal.FROND, 1.8)

	func _broadleaf(b: Batch, at: Vector2, h: float, _k: int) -> void:
		for j in 4:
			var a := -2.4 + j * 0.55
			var d := Vector2(cos(a), sin(a))
			var n := Vector2(-d.y, d.x)
			var pts := PackedVector2Array([at])
			for m in range(1, 6):
				var u := m / 5.0
				pts.append(at + d * h * u + n * sin(u * PI) * h * 0.28)
			for m in range(1, 5):
				var u2 := 1.0 - m / 5.0
				pts.append(at + d * h * u2 - n * sin(u2 * PI) * h * 0.28)
			b.poly(pts, Pal.FROND_LIGHT if j % 2 == 0 else Pal.FROND)
			b.line(at, at + d * h * 0.9, Pal.FROND.darkened(0.3), 1.6)


class Motes extends Node2D:
	var _pen: Batch             ## its picture, collected into one draw call
	## Pollen drifting in the warm air.
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		for i in 26:
			var bx := fmod(float(i) * 173.0 + t * (6.0 + (i % 4) * 3.0), 1400.0)
			var by := 120.0 + fmod(float(i) * 97.0, 420.0) + sin(t * 0.9 + i) * 14.0
			_pen.draw_circle(Vector2(bx, by), 1.6 + (i % 3) * 0.6, Color(Pal.RAY, 0.45))
