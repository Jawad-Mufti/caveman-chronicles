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
		draw_rect(Rect2(Vector2.ZERO, rect.size), body)
		var cap_h := minf(12.0, rect.size.y)
		draw_rect(Rect2(Vector2.ZERO, Vector2(rect.size.x, cap_h)), cap)
		if not underground:
			draw_rect(Rect2(Vector2(0, cap_h - 3.0), Vector2(rect.size.x, 3)), Pal.GRASS_DARK)
			var x := 6.0
			while x < rect.size.x - 6.0:
				var h := rng.randf_range(5.0, 11.0)
				draw_colored_polygon(PackedVector2Array([
					Vector2(x - 3, 1), Vector2(x + rng.randf_range(-2.0, 2.0), -h), Vector2(x + 3, 1)]), Pal.GRASS_DARK)
				x += rng.randf_range(14.0, 34.0)
		var n := int(rect.size.x / 55.0) + 1
		for i in n:
			var p := Vector2(rng.randf_range(4.0, maxf(5.0, rect.size.x - 4.0)),
				rng.randf_range(cap_h + 6.0, maxf(cap_h + 7.0, minf(rect.size.y - 4.0, 140.0))))
			draw_circle(p, rng.randf_range(2.0, 5.0), Pal.DIRT_DARK if not underground else Pal.STONE_DARK.darkened(0.2))


class Ceiling extends Node2D:
	var width := 0.0
	var trap_zones: Array = []

	## Outdoors now, so there is no roof: only an overhanging rock shelf above
	## each loose spot, which is what the falling stones come off.
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for z in trap_zones:
			var x0: float = float(z[0]) - 70.0
			var wd: float = float(z[1]) + 140.0
			draw_rect(Rect2(x0, -260, wd, 300), Pal.STONE_DARK)
			draw_rect(Rect2(x0, 30, wd, 10), Pal.STONE)
			var x := x0 + 24.0
			while x < x0 + wd - 20.0:
				var ln := rng.randf_range(34.0, 96.0)
				var hw := rng.randf_range(14.0, 28.0)
				draw_colored_polygon(PackedVector2Array([
					Vector2(x - hw, 38), Vector2(x + hw, 38), Vector2(x, 38 + ln)]), Pal.STONE_DARK)
				draw_line(Vector2(x - 5, 40), Vector2(x + 4, 38 + ln * 0.6), Pal.OCHRE, 2.5, true)
				x += rng.randf_range(80.0, 150.0)


class SkyFill extends Node2D:
	## Fixed to the screen, never scrolls: the sky is effectively at infinity.
	func _draw() -> void:
		draw_polygon(
			PackedVector2Array([Vector2(-60, -60), Vector2(1400, -60), Vector2(1400, 840), Vector2(-60, 840)]),
			PackedColorArray([Pal.SKY_HIGH, Pal.SKY_HIGH, Pal.SKY_LOW, Pal.SKY_LOW]))
		var sun := Vector2(1040, 118)
		for i in 5:
			draw_circle(sun, 64.0 + i * 26.0, Color(Pal.SUN, 0.10 - i * 0.015))
		draw_circle(sun, 52.0, Pal.SUN)


class Clouds extends Node2D:
	var width := 3200.0
	var count := 7
	var top := 90.0

	func _draw() -> void:
		for i in count:
			var r := absf(fmod(sin(float(i) * 7.13) * 4371.7, 1.0))
			_puff(Vector2((i + 0.5) * width / count, top + r * 110.0), 0.65 + r * 0.7)

	func _puff(at: Vector2, s: float) -> void:
		var col := Color(1, 1, 1, 0.9)
		for o in [[-40.0, 8.0, 26.0], [-12.0, -12.0, 34.0], [20.0, -4.0, 28.0], [44.0, 10.0, 22.0], [4.0, 14.0, 24.0]]:
			draw_circle(at + Vector2(o[0] * s, o[1] * s), o[2] * s, col)


class Ridge extends Node2D:
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
		var crest := PackedVector2Array()
		var x := 0.0
		while x <= width + 0.1:
			crest.append(Vector2(x, _height(x)))
			x += 14.0
		var body := PackedVector2Array(crest)
		body.append(Vector2(width, 1500))
		body.append(Vector2(0, 1500))
		draw_colored_polygon(body, col)
		draw_polyline(crest, rim, 5.0, true)
		if snow_line > 0.0:
			var run := PackedVector2Array()
			for p in crest:
				if p.y < snow_line:
					run.append(p)
				else:
					if run.size() > 1:
						draw_polyline(run, Pal.SNOW, 8.0, true)
					run = PackedVector2Array()
			if run.size() > 1:
				draw_polyline(run, Pal.SNOW, 8.0, true)
		for i in tree_count:
			var tx := (i + 0.5) * width / float(tree_count)
			var r := absf(fmod(sin(float(i) * 12.9898) * 43758.5453, 1.0))
			_conifer(Vector2(tx, _height(tx) + 3.0), tree_h * (0.7 + r * 0.6))

	func _conifer(at: Vector2, h: float) -> void:
		draw_line(at, at + Vector2(0, -h * 0.3), tree_col, maxf(2.0, h * 0.1), true)
		for i in 3:
			var top := at.y - h * (0.3 + i * 0.24)
			var sp := h * 0.32 * (1.0 - i * 0.22)
			draw_colored_polygon(PackedVector2Array([
				Vector2(at.x - sp, top), Vector2(at.x, top - h * 0.34), Vector2(at.x + sp, top)]), tree_col)


class CaveWall extends Node2D:
	var variant := 0

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 100 + variant
		var tone := Color(Pal.CAVE_BOTTOM, 0.35) if variant == 0 else Color(Pal.CAVE_TOP, 0.55)
		for i in 40:
			var p := Vector2(rng.randf_range(0.0, 2560.0), rng.randf_range(80.0, 640.0))
			draw_set_transform(p, rng.randf_range(0.0, PI), Vector2(rng.randf_range(1.2, 2.8), 1.0))
			draw_circle(Vector2.ZERO, rng.randf_range(30.0, 90.0), tone)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if variant == 1:
			# two ochre handprints, a hint of the level 3 cave paintings
			for h in [Vector2(640, 300), Vector2(1900, 260)]:
				_hand(h, Color(Pal.OCHRE, 0.55))

	func _hand(at: Vector2, col: Color) -> void:
		draw_circle(at, 22.0, col)
		for i in 5:
			var a := -PI * 0.5 + (i - 2) * 0.42
			var tip := at + Vector2(cos(a), sin(a)) * 40.0
			draw_line(at, tip, col, 11.0)
			draw_circle(tip, 5.5, col)


class RockPickup extends Area2D:
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
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(t * 3.0)
		draw_arc(Vector2(0, -10), 22.0 + pulse * 6.0, 0.0, TAU, 32, Color(Pal.OCHRE, 0.25 + pulse * 0.35), 2.0)
		var pts := PackedVector2Array([Vector2(-13, -2), Vector2(-9, -16), Vector2(4, -19), Vector2(13, -8), Vector2(10, 0), Vector2(-6, 1)])
		draw_polygon(pts, PackedColorArray([Pal.STONE]))
		draw_polygon(PackedVector2Array([pts[0], pts[1], Vector2(-2, -6)]), PackedColorArray([Pal.STONE_DARK]))


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
		queue_redraw()

	func _draw() -> void:
		var glow := 0.6 + 0.4 * sin(t * 2.0)
		draw_polygon(PackedVector2Array([Vector2(-36, 0), Vector2(-30, -110), Vector2(0, -140), Vector2(30, -110), Vector2(36, 0)]), PackedColorArray([Color(Pal.OCHRE, 0.25 * glow)]))
		draw_polygon(PackedVector2Array([Vector2(-22, 0), Vector2(-18, -90), Vector2(0, -112), Vector2(18, -90), Vector2(22, 0)]), PackedColorArray([Color(Pal.BONE, 0.85 * glow)]))


class BerryBush extends Area2D:
	## Gather -> craft -> ability. Berries become the poultice that heals him.
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
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(t * 2.4)
		draw_arc(Vector2(0, -18), 24.0 + pulse * 5.0, 0.0, TAU, 28, Color(Pal.EMBER, 0.18 + pulse * 0.28), 2.0)
		draw_circle(Vector2(-11, -12), 13.0, Pal.OCHRE_DEEP)
		draw_circle(Vector2(11, -14), 12.0, Pal.OCHRE_DEEP)
		draw_circle(Vector2(0, -23), 14.0, Pal.OCHRE_DARK)
		for p in [Vector2(-9, -21), Vector2(6, -25), Vector2(13, -12), Vector2(-15, -8), Vector2(2, -11)]:
			draw_circle(p, 4.0, Pal.EMBER)


class DistantBoar extends Node2D:
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
		var c := Pal.TREE_DARK
		var graze := sin(t * 0.7) * 4.0
		for i in 4:
			var lx := -34.0 + i * 22.0
			draw_line(Vector2(lx, -22), Vector2(lx, 0), c, 8.0)
		draw_set_transform(Vector2(0, -36), 0.0, Vector2(1.75, 1.0))
		draw_circle(Vector2.ZERO, 30.0, c)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(Vector2(-48, -30 + graze), 19.0, c)
		draw_line(Vector2(-58, -18 + graze), Vector2(-72, -34 + graze), c, 4.0)
		draw_polygon(PackedVector2Array([
			Vector2(-22, -62), Vector2(-12, -76), Vector2(0, -62), Vector2(12, -74), Vector2(24, -62)
		]), PackedColorArray([c]))


class Bamboo extends AnimatableBody2D:
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
		var half := size * 0.5
		draw_rect(Rect2(-half, size), Pal.OCHRE_DARK)
		draw_rect(Rect2(-half, Vector2(size.x, 5)), Pal.OCHRE)
		var n := int(size.x / 26.0)
		for i in range(1, n):
			var x := -half.x + i * 26.0
			draw_line(Vector2(x, -half.y), Vector2(x, half.y), Pal.OCHRE_DEEP, 3.0)


class SpringBush extends Area2D:
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
		# A springy shrub: woody stems at the base, overlapping leafy masses with
		# scalloped edges, and loose leaves breaking the silhouette. Perfect
		# circles are what made it read as a cartoon blob rather than a plant.
		var c := 1.0 - squash * 0.55          # 1 at rest, flattened as it fires
		var sq := Vector2(1.0 + squash * 0.35, c)
		var breeze := sin(t * 1.4) * 0.035

		# woody stems
		for stem in [[-9.0, -15.0], [3.0, -18.0], [13.0, -12.0]]:
			var top := Vector2(stem[0], stem[1]) * sq
			draw_line(Vector2(0, -1), top, Pal.OUTLINE, 7.0, true)
			draw_line(Vector2(0, -1), top, Pal.VINE, 4.0, true)

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
			draw_arc(Vector2(0, -16), 30.0 + (1.0 - squash) * 30.0, 0.0, TAU, 20, Color(Pal.GRASS, squash * 0.55), 3.0)

	## A rounded mass with a bumpy rim, so the edge reads as clustered leaves.
	func _scallop(at: Vector2, r: float, sq: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 11:
			var a := TAU * i / 11.0
			var rr := r * (1.0 + 0.14 * sin(a * 5.0 + at.x * 0.3))
			pts.append(at + Vector2(cos(a) * rr * sq.x, sin(a) * rr * sq.y))
		draw_colored_polygon(pts, col)

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
		draw_colored_polygon(pts, Pal.GRASS)
		draw_line(at, tip, Pal.TRAP_DARK, 1.2, true)

class ThrownRock extends Area2D:
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
		draw_set_transform(Vector2.ZERO, spin, Vector2.ONE)
		draw_circle(Vector2.ZERO, 8.0, Pal.STONE)
		draw_circle(Vector2(-3, -3), 3.0, Pal.STONE_DARK)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class StickPickup extends Area2D:
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
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(t * 2.6)
		draw_arc(Vector2(0, -16), 22.0 + pulse * 5.0, 0.0, TAU, 24, Color(Pal.OCHRE, 0.2 + pulse * 0.25), 2.0)
		var lift := sin(t * 1.8) * 2.0
		draw_line(Vector2(-20, -10 + lift), Vector2(18, -22 + lift), Pal.OCHRE_DEEP, 7.0)
		draw_circle(Vector2(20, -23 + lift), 7.0, Pal.OCHRE_DARK)
		draw_circle(Vector2(18, -26 + lift), 2.5, Pal.OCHRE)
