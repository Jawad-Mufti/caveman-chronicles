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
		draw_rect(Rect2(Vector2.ZERO, rect.size), Pal.OCHRE_DARK)
		draw_rect(Rect2(Vector2.ZERO, Vector2(rect.size.x, 7)), Pal.OCHRE)
		# a few darker flecks so the floor reads as rock, not a bar
		var rng := RandomNumberGenerator.new()
		rng.seed = int(rect.position.x) * 7 + int(rect.position.y)
		var n := int(rect.size.x / 60.0) + 1
		for i in n:
			var p := Vector2(rng.randf_range(4.0, rect.size.x - 4.0), rng.randf_range(14.0, minf(rect.size.y - 4.0, 120.0)))
			draw_circle(p, rng.randf_range(2.0, 5.0), Pal.OCHRE_DEEP)


class Ceiling extends Node2D:
	var width := 0.0
	var trap_zones: Array = []

	func _draw() -> void:
		draw_rect(Rect2(0, -200, width, 250), Pal.CAVE_TOP)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var x := 20.0
		while x < width:
			var cracked := false
			for z in trap_zones:
				if x > z[0] and x < z[0] + z[1]:
					cracked = true
			var len := rng.randf_range(30.0, 90.0)
			var w := rng.randf_range(14.0, 30.0)
			if cracked:
				len += 40.0
			draw_polygon(PackedVector2Array([Vector2(x - w, 50), Vector2(x + w, 50), Vector2(x, 50 + len)]), PackedColorArray([Pal.CAVE_TOP]))
			if cracked:
				draw_line(Vector2(x - 4, 52), Vector2(x + 3, 50 + len * 0.6), Pal.OCHRE, 2.0)
			x += rng.randf_range(90.0, 170.0)


class SkyFill extends Node2D:
	func _draw() -> void:
		draw_polygon(
			PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 720), Vector2(0, 720)]),
			PackedColorArray([Pal.CAVE_TOP, Pal.CAVE_TOP, Pal.CAVE_BOTTOM, Pal.CAVE_BOTTOM])
		)


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
			(body as CaveMan).pick_up_rock()
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
	## Tuskar, seen grazing far off long before the arena. Pure foreshadowing.
	var t := 0.0

	func _ready() -> void:
		z_index = -5
		scale = Vector2(0.6, 0.6)
		modulate = Color(1, 1, 1, 0.3)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var c := Pal.CAVE_TOP
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
