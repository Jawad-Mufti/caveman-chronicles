## Digging down to the Root Hollows, Terraria-style.
##   DigGrid   a column of earth made of blocks. DOWN + HIT digs the block
##             under him; HIT digs the block in front. Dirt goes in one blow,
##             stones take three, some blocks hide shells; and near the bottom
##             a layer of packed CLAY that only a SHOVEL cuts.
##   SunStone  buried halfway down: a stone with the sun's fire in it. Touch
##             it and SUNFIRE is his.
##   Bramble   up in the windy sky above the Moon Garden: a nest of wet,
##             thorny vines with the SHOVEL inside. Nothing burns it but the
##             fire of SUNFIRE (blows or fireballs while it burns in him).
##   ShovelPickup  the shovel, once the bramble is gone.
class_name Dig
extends RefCounted

const TILE := 40.0
const AIR := 0
const DIRT := 1
const STONE := 2
const CLAY := 3
const HITS := {DIRT: 1, STONE: 3, CLAY: 2}


## ================================================================ GRID
class DigGrid extends Node2D:
	signal dug(kind: int)
	signal clay_needs_shovel
	var cols := 8
	var rows := 40
	var level_id := "level2"
	var cells := PackedInt32Array()
	var hits := PackedInt32Array()
	var loot := {}                ## cell index -> [treasure kind, id]
	var _shapes: Array = []
	var _body: StaticBody2D
	var _chunks: Array = []       ## [pos, vel, life, colour]
	var _t := 0.0
	var _clang := 0.0

	func idx(c: Vector2i) -> int:
		return c.y * cols + c.x

	func inside(c: Vector2i) -> bool:
		return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows

	func solid(c: Vector2i) -> bool:
		return inside(c) and cells[idx(c)] != AIR

	func cell_at(local: Vector2) -> Vector2i:
		return Vector2i(floori(local.x / TILE), floori(local.y / TILE))

	## Build the solid blocks from `cells` (set by the level before adding).
	func _ready() -> void:
		z_index = -1
		add_to_group("glow")
		_body = StaticBody2D.new()
		_body.collision_layer = 1
		_body.collision_mask = 0
		add_child(_body)
		var sh := RectangleShape2D.new()
		sh.size = Vector2(TILE, TILE)
		_shapes.resize(cells.size())
		hits.resize(cells.size())
		for i in cells.size():
			var kind := cells[i]
			hits[i] = Dig.HITS.get(kind, 1)
			if kind == AIR:
				continue
			var cs := CollisionShape2D.new()
			cs.shape = sh
			cs.position = Vector2((i % cols) * TILE + TILE * 0.5, (i / cols) * TILE + TILE * 0.5)
			_body.add_child(cs)
			_shapes[i] = cs
		# one area over all of it: his swing finds it, and we work out which block
		var area := _Hitter.new()
		area.grid = self
		area.collision_layer = 4
		area.collision_mask = 0
		area.monitoring = false
		var acs := CollisionShape2D.new()
		var ash := RectangleShape2D.new()
		ash.size = Vector2(cols * TILE, rows * TILE)
		acs.shape = ash
		acs.position = ash.size * 0.5
		area.add_child(acs)
		add_child(area)

	## Which block a blow lands on: under his feet when he digs down, else the
	## lower of the two in front of him.
	func struck() -> void:
		var p := get_tree().get_first_node_in_group("player") as CaveMan
		if p == null:
			return
		var feet := p.global_position - global_position
		var target := Vector2i(-1, -1)
		if p.digging_down:
			# the block he is standing on: under his middle, or under either foot
			for dx in [0.0, -12.0, 12.0, float(p.facing) * 24.0]:
				var c := cell_at(feet + Vector2(dx, 10))
				if solid(c):
					target = c
					break
		else:
			for dy in [-14.0, -48.0]:
				var c2 := cell_at(feet + Vector2(float(p.facing) * 30.0, dy))
				if solid(c2):
					target = c2
					break
		if target.x >= 0:
			_damage(target)

	func _damage(c: Vector2i) -> void:
		var i := idx(c)
		var kind := cells[i]
		var at := Vector2(c) * TILE + Vector2(TILE, TILE) * 0.5
		if kind == CLAY and not GameState.has_item("shovel"):
			_spark(at, Color("c9b49a"), 4)
			if _clang <= 0.0:
				_clang = 2.0
				var pop := Treasure.FloatText.new()
				pop.text = "CLANG!"
				pop.position = global_position + at + Vector2(-26, -40)
				get_parent().add_child(pop)
				clay_needs_shovel.emit()
			return
		hits[i] -= 1
		if hits[i] > 0:
			_spark(at, Color("cfc7bd") if kind == STONE else Color("a06a44"), 5)
			queue_redraw()
			return
		cells[i] = AIR
		if _shapes[i] != null:
			(_shapes[i] as Node).queue_free()
			_shapes[i] = null
		var col: Color = {DIRT: Color("7a5236"), STONE: Color("8d857a"), CLAY: Color("a2553a")}.get(kind, Color("7a5236"))
		_spark(at, col, 12)
		FX.burst(get_parent(), global_position + at, "dust")
		if loot.has(i):
			var l: Array = loot[i]
			if not GameState.is_taken(level_id, l[1]):
				var pk := Treasure.Pickup.new()
				pk.kind = l[0]
				pk.level_id = level_id
				pk.id = l[1]
				pk.position = global_position + at
				pk.vel = Vector2(randf_range(-60, 60), -320)
				pk.floor_y = global_position.y + rows * TILE
				var lvl := get_parent()
				if lvl.has_method("_on_treasure_popped"):
					lvl._on_treasure_popped(pk)
				lvl.add_child.call_deferred(pk)
		dug.emit(kind)
		queue_redraw()

	func _spark(at: Vector2, col: Color, n: int) -> void:
		for k in n:
			_chunks.append([at, Vector2(randf_range(-160, 160), randf_range(-260, -60)), randf_range(0.35, 0.7), col])

	func _process(delta: float) -> void:
		_t += delta
		_clang = maxf(_clang - delta, 0.0)
		for ch in _chunks:
			ch[1] = (ch[1] as Vector2) + Vector2(0, 900) * delta
			ch[0] = (ch[0] as Vector2) + (ch[1] as Vector2) * delta
			ch[2] = float(ch[2]) - delta
		if not _chunks.is_empty():
			_chunks = _chunks.filter(func(ch): return float(ch[2]) > 0.0)
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var rng := RandomNumberGenerator.new()
		for i in cells.size():
			var kind := cells[i]
			var c := Vector2i(i % cols, i / cols)
			var p := Vector2(c) * TILE
			if kind == AIR:
				b.rect(Rect2(p, Vector2(TILE, TILE)), Color("140e0b"))
				continue
			rng.seed = i * 7919 + 13
			var base: Color = {DIRT: Color("6e4a2f"), STONE: Color("77706a"), CLAY: Color("8f4a33")}.get(kind, Color("6e4a2f"))
			base = base.lerp(base.lightened(0.12), rng.randf())
			b.rect(Rect2(p, Vector2(TILE, TILE)), base)
			b.rect(Rect2(p, Vector2(TILE, 6)), base.lightened(0.12))
			match kind:
				DIRT:
					for k in 3:
						b.circle(p + Vector2(rng.randf_range(6, 34), rng.randf_range(8, 34)), rng.randf_range(1.5, 3.0), base.darkened(0.3), 6)
				STONE:
					b.ellipse(p + Vector2(20, 22), 15, 12, base.darkened(0.25), rng.randf_range(-0.4, 0.4))
					b.ellipse(p + Vector2(17, 18), 9, 6, base.lightened(0.2))
				CLAY:
					for k in 3:
						var y := 10.0 + k * 10.0
						b.line(p + Vector2(2, y), p + Vector2(38, y + rng.randf_range(-3, 3)), base.darkened(0.25), 2.0)
					b.line(p + Vector2(8, 4), p + Vector2(14, 30), Color("3a2414"), 1.5)
			if loot.has(i) and not GameState.is_taken(level_id, (loot[i] as Array)[1]):
				# something pale pokes out of the earth
				b.ellipse(p + Vector2(24, 26), 7, 5, Color("efe3c8"), 0.4)
				b.ellipse(p + Vector2(22, 24), 3, 2, Color.WHITE, 0.4)
			# cracks as it takes blows
			var full: int = Dig.HITS.get(kind, 1)
			if hits.size() > i and hits[i] < full:
				b.line(p + Vector2(8, 6), p + Vector2(22, 24), Color(0, 0, 0, 0.6), 2.0)
				b.line(p + Vector2(22, 24), p + Vector2(32, 18), Color(0, 0, 0, 0.6), 2.0)
			# dark edges where it meets the open: chunky, cartoon blocks
			for n in [[Vector2i(0, -1), Rect2(p, Vector2(TILE, 3))], [Vector2i(0, 1), Rect2(p + Vector2(0, TILE - 3), Vector2(TILE, 3))],
					[Vector2i(-1, 0), Rect2(p, Vector2(3, TILE))], [Vector2i(1, 0), Rect2(p + Vector2(TILE - 3, 0), Vector2(3, TILE))]]:
				var nc: Vector2i = c + (n[0] as Vector2i)
				if inside(nc) and cells[idx(nc)] == AIR:
					b.rect(n[1], Color("1a110c"))
		for ch in _chunks:
			b.rect(Rect2((ch[0] as Vector2) - Vector2(3, 3), Vector2(6, 6)), Color(ch[3] as Color, clampf(float(ch[2]) * 2.0, 0.0, 1.0)))
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var spark := fmod(_t * 0.6, 2.0)
		if spark > 0.4:
			return
		var k := sin(spark / 0.4 * PI)
		for i in loot:
			if cells[i] != AIR and not GameState.is_taken(level_id, (loot[i] as Array)[1]):
				var p := global_position + Vector2(Vector2i(i % cols, i / cols)) * TILE + Vector2(26, 22)
				Treasure.glint(g, p, 7.0 * k, Color(1, 0.95, 0.8, k))


## The area's script: hands the blow to the grid.
class _Hitter extends Area2D:
	var grid: DigGrid

	func take_hit(_dmg: int, _from_dir: int) -> void:
		grid.struck()


## ================================================================ SUN STONE
class SunStone extends Area2D:
	## A stone with the sun's fire in it, buried deep. It hums, it glows, its
	## rays turn. Touch it and the fire goes into him: SUNFIRE.
	signal taken
	var spent := false
	var _t := 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 30.0
		cs.shape = c
		cs.position = Vector2(0, -24)
		add_child(cs)
		add_to_group("glow")
		add_to_group("light")
		body_entered.connect(func(b: Node) -> void:
			if b is CaveMan and not spent:
				spent = true
				taken.emit())

	func light() -> Vector4:
		return Vector4(global_position.x, global_position.y - 24.0, 60.0 if spent else 260.0, 1.0)

	func light_strength() -> float:
		return 0.0

	func _process(delta: float) -> void:
		_t += delta
		if LevelBase.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var c := Vector2(0, -24)
		if not spent:
			for i in 12:
				var a := i * TAU / 12.0 + _t * 0.6
				b.tri(c + Vector2.from_angle(a + 0.12) * 20.0, c + Vector2.from_angle(a) * (52.0 + 6.0 * sin(_t * 3.0 + i)), c + Vector2.from_angle(a - 0.12) * 20.0, Color(Sunfire.GOLD, 0.45))
		b.ellipse(c + Vector2(0, 14), 26, 10, Color("2a2018"))
		b.ellipse(c, 22, 20, Color("5d4a3a") if spent else Color("8a5a2a"))
		b.ellipse(c, 16, 14, Color("6a5a4c") if spent else Sunfire.HOT)
		if not spent:
			b.ellipse(c, 9, 8, Sunfire.WHITE_HOT)
			for i in 4:
				Sunfire.flame(b, c + Vector2(-12.0 + i * 8.0, -12), 12.0 + 4.0 * sin(_t * 4.0 + i), _t * 1.3 + i)
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		if spent:
			return
		var o := global_position + Vector2(0, -24)
		g.draw_circle(o, 56.0 + 8.0 * sin(_t * 3.0), Color(1.0, 0.7, 0.25, 0.35))
		g.draw_circle(o, 14.0, Color(1.0, 0.95, 0.7, 0.9))


## ================================================================ BRAMBLE
class Bramble extends Area2D:
	## A tangle of wet, thorny vines high in the windy sky, something wedged in
	## its heart. Thorns prick (a little toss); blows and plain fire do nothing —
	## the cloud-dew keeps it wet. Only SUNFIRE's heat burns it away.
	signal burned
	signal tried
	var gone := false
	var _burn := -1.0
	var _t := 0.0
	var _prick := 0.0
	var _said := 0.0

	func _ready() -> void:
		collision_layer = 4
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 44.0
		cs.shape = c
		cs.position = Vector2(0, -40)
		add_child(cs)
		add_to_group("glow")
		if gone:
			queue_free()

	func take_hit(_dmg: int, _from_dir: int) -> void:
		if _burn >= 0.0:
			return
		var p := get_tree().get_first_node_in_group("player") as CaveMan
		if p != null and p.sun_t > 0.0:
			_burn = 0.0
			var pop := Treasure.FloatText.new()
			pop.text = "FWOOOSH!"
			pop.position = global_position + Vector2(-40, -110)
			get_parent().add_child(pop)
		elif _said <= 0.0:
			_said = 3.0
			tried.emit()

	func _physics_process(delta: float) -> void:
		_t += delta
		_prick = maxf(_prick - delta, 0.0)
		_said = maxf(_said - delta, 0.0)
		if _burn >= 0.0:
			_burn += delta
			if fmod(_burn, 0.12) < delta:
				FX.burst(get_parent(), global_position + Vector2(randf_range(-36, 36), randf_range(-70, -10)), "embers")
			if _burn > 1.4:
				gone = true
				burned.emit()
				queue_free()
				return
		else:
			var p := get_tree().get_first_node_in_group("player") as CaveMan
			if p != null and not p.dead and _prick <= 0.0 and overlaps_body(p):
				_prick = 1.0
				var side := 1.0 if p.global_position.x >= global_position.x else -1.0
				p.hurt_toss(1, global_position.x, Vector2(side * 260.0, -280.0))
				if _said <= 0.0:
					_said = 3.0
					tried.emit()
		if LevelBase.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var k := clampf(_burn / 1.4, 0.0, 1.0) if _burn >= 0.0 else 0.0
		var c := Vector2(0, -40)
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		# the thing inside, glimpsed through the tangle: a flat stone on a stick
		b.line(c + Vector2(-16, 14), c + Vector2(10, -16), Color("8a6a48"), 4.0)
		b.ellipse(c + Vector2(-16, 18), 10, 7, Color("c9c2b6"), 0.7)        # pale: it shows through the thorns
		# loops of thorny vine, wet and dark — blackening, then gone, as it burns
		for i in 9:
			var a0 := rng.randf() * TAU
			var r := rng.randf_range(24, 46)
			var pts := PackedVector2Array()
			for j in 10:
				var a := a0 + j * 0.55
				pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.8) + Vector2(sin(_t * 1.3 + i) * 1.5, 0))
			var vine := Color("2f5a3a").lerp(Color("1a1410"), k)
			b.polyline(pts, Color(vine, 1.0 - k * 0.8), 4.0)
			for j in range(1, 10, 3):
				var tp: Vector2 = pts[j]
				b.tri(tp, tp + (tp - c).normalized() * 7.0, tp + Vector2(2, 2), Color(Color("c9d6b8"), 1.0 - k))
		if _burn < 0.0:
			# cloud-dew drops on it, glinting
			for i in 6:
				var a2 := i * TAU / 6.0 + 0.3
				b.circle(c + Vector2.from_angle(a2) * 38.0, 2.6, Color("bfe8ff", 0.9), 6)
		else:
			for i in 6:
				Sunfire.flame(b, c + Vector2(-40.0 + i * 16.0, 30.0 - 20.0 * k), 30.0 + 20.0 * sin(_t * 9.0 + i), _t * 1.4 + i)
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var o := global_position + Vector2(0, -40)
		if _burn >= 0.0:
			g.draw_circle(o, 80.0, Color(1.0, 0.6, 0.2, 0.45))
		else:
			# something in there catches the light now and then: the shovel's stone
			var spark := fmod(_t * 0.9, 2.2)
			if spark < 0.45:
				var k := sin(spark / 0.45 * PI)
				Treasure.glint(g, o + Vector2(-16, 18), 12.0 * k, Color(1, 1, 0.9, k))
			for i in 6:
				var a2 := i * TAU / 6.0 + 0.3
				g.draw_circle(o + Vector2.from_angle(a2) * 38.0, 4.0, Color(0.75, 0.9, 1.0, 0.5 + 0.3 * sin(_t * 2.0 + i)))


## ================================================================ SHOVEL
class ShovelPickup extends Area2D:
	signal picked
	var _t := 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 26.0
		cs.shape = c
		cs.position = Vector2(0, -30)
		add_child(cs)
		add_to_group("glow")
		body_entered.connect(func(b: Node) -> void:
			if b is CaveMan:
				picked.emit()
				queue_free())

	func _process(delta: float) -> void:
		_t += delta
		if LevelBase.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		b.draw_set_transform(Vector2(0, -30 + sin(_t * 2.0) * 4.0), -0.5, Vector2.ONE)
		Dig.draw_shovel(b, Vector2.ZERO, 1.0)
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		g.draw_circle(global_position + Vector2(0, -30), 30.0, Color(1.0, 0.95, 0.75, 0.25))


## The shovel: a flat stone lashed to a stick (also drawn on its item card).
static func draw_shovel(b: Batch, c: Vector2, s: float) -> void:
	b.line(c + Vector2(0, -38) * s, c + Vector2(0, 14) * s, Color("5e452f"), 7.0 * s)
	b.line(c + Vector2(0, -38) * s, c + Vector2(0, 14) * s, Color("8a6a48"), 4.0 * s)
	b.line(c + Vector2(-9, -38) * s, c + Vector2(9, -38) * s, Color("8a6a48"), 5.0 * s)
	b.ellipse(c + Vector2(0, 28) * s, 15.0 * s, 19.0 * s, Color("5f5850"))
	b.ellipse(c + Vector2(-2, 24) * s, 11.0 * s, 13.0 * s, Color("9a948c"))
	for i in 3:
		b.line(c + Vector2(-8, 8 + i * 4) * s, c + Vector2(8, 10 + i * 4) * s, Color("c9a06e"), 2.0 * s)


## ================================================================ PAINTING
class Painting extends Node2D:
	## An old cave painting on the shaft wall, by the clay: someone who came
	## this way before. A little hunter holding a SHOVEL... and above, the wind
	## (swirls), the moon rocks, and a ball of thorns high in the sky — with the
	## same shovel drawn inside it. The clue to where the shovel went.
	var _t := 0.0

	func _ready() -> void:
		z_index = 0
		add_to_group("glow")

	func _process(delta: float) -> void:
		_t += delta
		if LevelBase.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var ochre := Color("c8553d", 0.85)
		var red := Color("a83a2a", 0.85)
		var chalk := Color("e8dcc0", 0.75)
		# the hunter, with the shovel over his shoulder, looking up
		var feet := Vector2(10, 120)
		b.circle(feet + Vector2(0, -58), 7.0, ochre, 10)
		b.line(feet + Vector2(0, -50), feet + Vector2(0, -22), ochre, 4.0)
		b.line(feet + Vector2(0, -22), feet + Vector2(-8, 0), ochre, 3.5)
		b.line(feet + Vector2(0, -22), feet + Vector2(8, 0), ochre, 3.5)
		b.line(feet + Vector2(0, -44), feet + Vector2(12, -54), ochre, 3.0)
		b.line(feet + Vector2(12, -54), feet + Vector2(26, -82), ochre, 3.0)      # the handle
		b.ellipse(feet + Vector2(29, -88), 6.0, 8.0, red, 0.5)                   # the blade
		# an arrow of dots, up and to the left: "up there"
		for i in 6:
			b.circle(feet + Vector2(-10.0 - i * 16.0, -80.0 - i * 18.0), 2.5, chalk, 6)
		# the wind: swirls
		for s in 3:
			var c := Vector2(-150.0 + s * 34.0, -60.0 - s * 12.0)
			var sw := PackedVector2Array()
			for j in 12:
				var a := j * 0.5
				sw.append(c + Vector2.from_angle(a) * (2.0 + j * 1.3))
			b.polyline(sw, ochre, 2.5)
		# floating rocks and the moon
		for r in [Vector2(-120, -10), Vector2(-60, -30)]:
			b.tri(r + Vector2(-16, 0), r + Vector2(16, 0), r + Vector2(0, 14), ochre)
			b.line(r + Vector2(-16, 0), r + Vector2(16, 0), ochre, 3.0)
		b.circle(Vector2(40, -120), 10.0, chalk, 14)
		# the ball of thorns, high up, with the shovel drawn in it
		var th := Vector2(-110, -120)
		for i in 10:
			var a2 := i * TAU / 10.0
			b.line(th + Vector2.from_angle(a2) * 12.0, th + Vector2.from_angle(a2) * 24.0, red, 2.5)
		b.arc(th, 16.0, 0.0, TAU, 16, red, 3.0)
		b.line(th + Vector2(-6, 8), th + Vector2(6, -8), ochre, 3.0)
		b.ellipse(th + Vector2(-8, 10), 4.0, 5.0, ochre, 0.5)
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		# old paint catches the torchlight faintly; the thorn-ball a little more
		var pulse := 0.5 + 0.5 * sin(_t * 1.5)
		g.draw_circle(global_position + Vector2(-110, -120), 30.0, Color(1.0, 0.5, 0.35, 0.10 + 0.08 * pulse))
		g.draw_circle(global_position + Vector2(10, 60), 50.0, Color(1.0, 0.6, 0.4, 0.06))
