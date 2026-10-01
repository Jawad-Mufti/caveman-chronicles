## Treasure, Captain Claw style: shells lying along the paths (and hanging
## along jump arcs, showing the way), a few big ones tucked into secret spots,
## and hollow logs and termite mounds to smash open. Shells are the money: the
## trader and the Toolmaker take them for upgrades and skins.
##   shell 1 · conch 5 · amber 25
## Every piece has an id within its level; once taken it never comes back.
class_name Treasure
extends RefCounted

const VALUE := {"shell": 1, "conch": 5, "amber": 25, "bone": 1, "tusk": 5}


## Colours for each kind: [fill, light, dark outline, glow]
const LOOK := {
	"shell": [Color("fbe6cf"), Color("f4b9a5"), Color("6d4a2e"), Color("ffe9c9")],
	"conch": [Color("f2a97e"), Color("ffd9c0"), Color("6a3620"), Color("ffc6a0")],
	"amber": [Color("e08a2c"), Color("ffd173"), Color("5e3210"), Color("ffb347")],
	"bone": [Color("e9dcbc"), Color("fbf4e2"), Color("5e4d34"), Color("fff1d6")],
	"tusk": [Color("f3e6c4"), Color("fffaf0"), Color("6b5530"), Color("fff4d8")],
}


## Bones are building material, not money: counted on their own, and they
## come back on every visit. Everything else here is a shell of some kind.
static func is_bone(kind: String) -> bool:
	return kind == "bone" or kind == "tusk"


## Draws one piece of treasure, centred on `at`, bold enough to read at night.
## A four-point glint for the glow layer, drawn around the origin and moved
## into place: far out (x > 20,000) a hair-thin diamond in world coordinates
## loses too much float precision to triangulate.
static func glint(g, at: Vector2, r: float, col: Color, both := true) -> void:
	g.draw_set_transform(at)
	g.draw_colored_polygon(PackedVector2Array([Vector2(0, -r), Vector2(r * 0.25, 0), Vector2(0, r), Vector2(-r * 0.25, 0)]), col)
	if both:
		g.draw_colored_polygon(PackedVector2Array([Vector2(-r, 0), Vector2(0, r * 0.25), Vector2(r, 0), Vector2(0, -r * 0.25)]), col)
	g.draw_set_transform(Vector2.ZERO)


static func shape_into(b: Batch, kind: String, at: Vector2) -> void:
	var look: Array = LOOK[kind]
	var fill: Color = look[0]
	var light: Color = look[1]
	var dark: Color = look[2]
	match kind:
		"shell":
			# a scallop: a fan of ridges from the hinge, pink toward the rim
			var hinge := at + Vector2(0, 8)
			var rim := PackedVector2Array([at + Vector2(-5, 10)])
			for i in 11:
				var a := PI + 0.18 + (PI - 0.36) * i / 10.0
				rim.append(hinge + Vector2.from_angle(a) * 16.0 + Vector2(0, sin(i * PI) * 0.0))
			rim.append(at + Vector2(5, 10))
			var edge := PackedVector2Array()
			for p in rim:
				edge.append(hinge + (p - hinge) * 1.14)
			b.poly(edge, dark)
			b.poly(rim, fill)
			var inner := PackedVector2Array([hinge])
			for i in 9:
				var a := PI + 0.3 + (PI - 0.6) * i / 8.0
				inner.append(hinge + Vector2.from_angle(a) * 14.0)
			b.poly(inner, light)
			b.poly(PackedVector2Array([hinge, hinge + Vector2.from_angle(PI + 0.9) * 9.0, hinge + Vector2.from_angle(PI + 2.2) * 9.0]), fill)
			for i in 5:
				var a := PI + 0.45 + (PI - 0.9) * i / 4.0
				b.line(hinge + Vector2.from_angle(a) * 3.0, hinge + Vector2.from_angle(a) * 15.0, dark.lightened(0.35), 1.5)
			b.rect(Rect2(at + Vector2(-6, 8), Vector2(12, 4)), dark)
			b.rect(Rect2(at + Vector2(-5, 8), Vector2(10, 2.5)), fill)
			b.circle(at + Vector2(-5, -2), 2.4, Color(1, 1, 1, 0.9), 8)
		"conch":
			# a spiral conch with a flared pink lip
			var body := PackedVector2Array([at + Vector2(-15, 6), at + Vector2(-11, -8), at + Vector2(-2, -15), at + Vector2(9, -13),
				at + Vector2(16, -3), at + Vector2(13, 9), at + Vector2(2, 13), at + Vector2(-8, 12)])
			var edge := PackedVector2Array()
			for p in body:
				edge.append(at + (p - at) * 1.13)
			b.poly(edge, dark)
			b.poly(body, fill)
			b.poly(PackedVector2Array([at + Vector2(2, 13), at + Vector2(13, 9), at + Vector2(9, 1), at + Vector2(0, 5)]), light)
			var spiral := PackedVector2Array()
			for i in 14:
				var a := i * 0.55
				spiral.append(at + Vector2(-3, -3) + Vector2.from_angle(a) * (1.5 + i * 0.8))
			b.polyline(spiral, dark.lightened(0.2), 1.8)
			for k in 3:
				b.circle(at + Vector2(-12 + k * 5, 7 - k * 2), 1.6, dark.lightened(0.3), 6)
			b.circle(at + Vector2(-7, -8), 2.6, Color(1, 1, 1, 0.85), 8)
		"bone":
			# a mammoth rib: the stuff Stone Age huts were built from. A long
			# curved rib, knobbly at the joint end, weathered and cracked, with
			# two bands of sinew tied round it
			var outer := PackedVector2Array()
			var inner := PackedVector2Array()
			for i in 11:
				var k := i / 10.0
				var ang := lerpf(-2.5, -0.7, k)
				var w := lerpf(5.5, 2.8, k)
				outer.append(at + Vector2(0, 16) + Vector2.from_angle(ang) * (22.0 + w))
				inner.append(at + Vector2(0, 16) + Vector2.from_angle(ang) * (22.0 - w))
			var rib := PackedVector2Array(outer)
			for i in range(inner.size() - 1, -1, -1):
				rib.append(inner[i])
			var edge := PackedVector2Array()
			var c := at + Vector2(0, 2)
			for p in rib:
				edge.append(c + (p - c) * 1.12)
			b.poly(edge, dark)
			b.poly(rib, fill)
			# the lit upper edge
			var shine := PackedVector2Array()
			for i in range(1, 9):
				shine.append(outer[i] + (inner[i] - outer[i]) * 0.25)
			b.polyline(shine, light, 2.0)
			# the knobbly joint end
			b.circle(outer[0].lerp(inner[0], 0.5) + Vector2(-2, 2), 6.5, dark, 12)
			b.circle(outer[0].lerp(inner[0], 0.5) + Vector2(-2, 2), 5.2, fill, 12)
			b.circle(outer[0].lerp(inner[0], 0.5) + Vector2(-3, 0), 1.8, light, 6)
			# a weathering crack, and the sinew bands
			b.line(outer[5].lerp(inner[5], 0.3), outer[6].lerp(inner[6], 0.6), dark.lightened(0.25), 1.2)
			for i in [3, 7]:
				b.line(outer[i] + (outer[i] - inner[i]).normalized() * 1.5, inner[i] - (outer[i] - inner[i]).normalized() * 1.5, Color("8a5a2c"), 3.0)
		"tusk":
			# a mammoth tusk: a great curve of ivory, thick at the root,
			# ringed with growth lines, tied with a sinew band — worth five bones
			var outer := PackedVector2Array()
			var inner := PackedVector2Array()
			for i in 13:
				var k := i / 12.0
				var ang := lerpf(2.6, 0.6, k)
				var w := lerpf(8.0, 0.8, k)
				var rad := 26.0 - k * 4.0
				outer.append(at + Vector2(2, -14) + Vector2.from_angle(ang) * (rad + w))
				inner.append(at + Vector2(2, -14) + Vector2.from_angle(ang) * (rad - w))
			var tusk := PackedVector2Array(outer)
			for i in range(inner.size() - 1, -1, -1):
				tusk.append(inner[i])
			var edge := PackedVector2Array()
			var c := at + Vector2(0, 4)
			for p in tusk:
				edge.append(c + (p - c) * 1.1)
			b.poly(edge, Color("6b5530"))
			b.poly(tusk, Color("f3e6c4"))
			for i in [2, 4, 6, 8]:
				b.line(outer[i], inner[i], Color("c9b48a"), 1.4)
			var shine := PackedVector2Array()
			for i in range(1, 11):
				shine.append(outer[i] + (inner[i] - outer[i]) * 0.3)
			b.polyline(shine, Color("fffaf0"), 2.0)
			b.line(outer[1] + (outer[1] - inner[1]).normalized() * 2.0, inner[1] - (outer[1] - inner[1]).normalized() * 2.0, Color("8a5a2c"), 4.0)
		"amber":
			# a faceted drop of amber with something caught inside
			var drop := PackedVector2Array([at + Vector2(0, -17), at + Vector2(11, -6), at + Vector2(13, 5), at + Vector2(6, 14),
				at + Vector2(-6, 14), at + Vector2(-13, 5), at + Vector2(-11, -6)])
			var edge := PackedVector2Array()
			for p in drop:
				edge.append(at + (p - at) * 1.14)
			b.poly(edge, dark)
			b.poly(drop, fill)
			b.poly(PackedVector2Array([at + Vector2(0, -17), at + Vector2(11, -6), at + Vector2(3, -3), at + Vector2(-4, -8)]), light)
			b.poly(PackedVector2Array([at + Vector2(-13, 5), at + Vector2(-6, 14), at + Vector2(-3, 6)]), fill.darkened(0.25))
			b.circle(at + Vector2(2, 4), 2.6, Color("4a2a0c"), 8)
			b.line(at + Vector2(0, 2), at + Vector2(-3, 0), Color("4a2a0c"), 1.2)
			b.line(at + Vector2(4, 2), at + Vector2(7, 0), Color("4a2a0c"), 1.2)
			b.circle(at + Vector2(-5, -9), 3.0, Color(1, 1, 1, 0.9), 8)


class CollectPop extends Node2D:
	## A burst of sparkles where treasure was picked up.
	var tint := Color("ffe9c9")
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		if t > 0.45:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := t / 0.45
		var a := 1.0 - k
		draw_circle(Vector2.ZERO, 6.0 + k * 22.0, Color(tint, 0.35 * a))
		for i in 8:
			var p := Vector2.from_angle(TAU * i / 8.0 + 0.3) * (6.0 + k * 30.0)
			var r := 4.0 * a + 1.0
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.3, 0), p + Vector2(0, r), p + Vector2(-r * 0.3, 0)]), Color(1, 1, 1, a))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-r, 0), p + Vector2(0, r * 0.3), p + Vector2(r, 0), p + Vector2(0, -r * 0.3)]), Color(1, 1, 1, a))


class Pickup extends Area2D:
	## One piece of treasure. Bobs gently where it lies. One popped out of
	## something flies with real collisions: it bounces off walls, is knocked
	## down by ceilings, passes up through thin ledges and branches but lands
	## on them from above, and settles on the first solid ground it meets —
	## always somewhere he can reach. If it ever drops out of reach, it pops
	## back up beside the spot it came from.
	signal collected(kind: String, value: int)
	var kind := "shell"
	var level_id := ""
	var id := ""
	var vel := Vector2.ZERO        ## for pieces popped out of something
	var floor_y := INF             ## the ground where it came from (its safety net)
	var t := 0.0
	var _base_y := 0.0
	var _gone := false
	var _home := Vector2.ZERO      ## where it came from
	var _flight := 0.0
	var _bounced := false

	func _ready() -> void:
		if GameState.is_taken(level_id, id):
			queue_free()
			return
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 22.0 if kind == "shell" else 26.0
		cs.shape = c
		add_child(cs)
		body_entered.connect(_on_body)
		t = randf() * TAU
		_base_y = position.y
		_home = position
		add_to_group("glow")

	func _on_body(b: Node) -> void:
		if _gone or not (b is CaveMan) or vel != Vector2.ZERO:
			return
		_gone = true
		var v: int = VALUE[kind]
		if Treasure.is_bone(kind):
			# bones aren't remembered: they'll be back next visit
			GameState.bones += v
		else:
			GameState.take(level_id, id, v)
		collected.emit(kind, v)
		var pop := FloatText.new()
		pop.text = "+%d" % v
		pop.position = global_position + Vector2(-8, -18)
		get_parent().call_deferred("add_child", pop)
		var burst := CollectPop.new()
		burst.tint = (LOOK[kind] as Array)[3]
		burst.position = global_position
		get_parent().call_deferred("add_child", burst)
		set_deferred("monitoring", false)
		call_deferred("queue_free")

	func _process(delta: float) -> void:
		t += delta
		if vel != Vector2.ZERO:
			_fly(delta)
			return
		if LevelBase.near_view(self):
			# moved and turned, not redrawn: the shape itself is drawn once.
			# It turns like a spinning coin, and bobs.
			position.y = _base_y + sin(t * 2.2) * 3.0
			scale.x = maxf(0.2, absf(cos(t * 2.0)))

	## One step of flight, checked against the world (layer 1: ground, rock,
	## walls, ledges, branches) with a ray from where it was to where it's going.
	func _fly(delta: float) -> void:
		_flight += delta
		vel.y = minf(vel.y + 1400.0 * delta, 1100.0)
		var from := global_position
		var to := from + vel * delta
		var q := PhysicsRayQueryParameters2D.create(from, to, 1)
		q.hit_from_inside = false
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			global_position = to
		else:
			var n: Vector2 = hit["normal"]
			var one_way := _is_one_way(hit)
			if n.y < -0.5 and vel.y > 0.0:
				# ground (or a ledge, or a branch) from above: settle on it
				global_position = (hit["position"] as Vector2) + Vector2(0, -12)
				if not _bounced and vel.y > 260.0:
					# one little hop first
					_bounced = true
					vel = Vector2(vel.x * 0.35, -vel.y * 0.28)
				else:
					_land()
				return
			elif one_way:
				# thin ledges and branches: it passes up (or sideways) through them
				global_position = to
			elif absf(n.x) > 0.5:
				# a wall: bounce back off it
				global_position = (hit["position"] as Vector2) + n * 8.0
				vel.x = -vel.x * 0.45
			else:
				# a ceiling: knocked back down
				global_position = (hit["position"] as Vector2) + n * 6.0
				vel.y = absf(vel.y) * 0.2
		# the safety net: fallen out of reach, or flying far too long
		if global_position.y > floor_y + 420.0 or _flight > 3.0:
			global_position = _home + Vector2(0, -40)
			vel = Vector2(randf_range(-60, 60), -320.0)
			_flight = 0.0
			_bounced = true

	func _is_one_way(hit: Dictionary) -> bool:
		var col = hit.get("collider")
		if col is CollisionObject2D:
			var co := col as CollisionObject2D
			var owner_id := co.shape_find_owner(int(hit.get("shape", 0)))
			return co.is_shape_owner_one_way_collision_enabled(owner_id)
		return false

	func _land() -> void:
		vel = Vector2.ZERO
		_base_y = position.y
		for body in get_overlapping_bodies():
			_on_body(body)

	func _draw() -> void:
		var b := Batch.new()
		Treasure.shape_into(b, kind, Vector2.ZERO)
		b.draw(self)

	## A soft glow so it reads in the dark, and now and then a sparkle.
	func draw_glow(g) -> void:   # g: the glow layer's Batch
		if _gone:
			return
		var glow: Color = (LOOK[kind] as Array)[3]
		var big := 1.5 if kind == "amber" else (1.2 if kind == "conch" else 1.0)
		var s := 0.5 + 0.5 * sin(t * 1.7)
		g.draw_circle(global_position, (14.0 + s * 4.0) * big, Color(glow, 0.10 + 0.06 * s))
		var spark := fmod(t * 0.7, 2.0)
		if spark < 0.35:
			var k := sin(spark / 0.35 * PI)
			var c := global_position + Vector2(8, -10) * big
			var r := 8.0 * k * big
			if r < 1.5:
				return
			Treasure.glint(g, c, r, Color(1, 1, 1, k))


class FloatText extends Node2D:
	## "+5" rising off a pickup.
	var text := ""
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		position.y -= 40.0 * delta
		modulate.a = clampf(1.0 - t / 0.8, 0.0, 1.0)
		if t > 0.8:
			queue_free()

	func _draw() -> void:
		draw_string(ThemeDB.fallback_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f3d08a"))


class Breakable extends Area2D:
	## Something to smash for what is inside. It pays out on every hit, not
	## just the last one:
	##   log    — two hits
	##   mound  — three hits (a termite mound)
	##   pot    — one hit, a few shells
	##   stash  — a monkey's hidden stash, a log marked with a red X: two hits,
	##            and then a FOUNTAIN of shells
	var kind := "log"
	var contents: Array = []        ## kinds of treasure inside
	var level_id := ""
	var id := ""
	var hits := 2
	var _given := 0
	var _shake := 0.0
	var _base := Vector2.ZERO
	var _t := 0.0

	func _ready() -> void:
		collision_layer = 4          # his swing and his rocks find it
		collision_mask = 0
		monitoring = false
		hits = {"log": 2, "mound": 3, "pot": 1, "stash": 2}.get(kind, 2)
		add_to_group("glow")
		_t = randf() * 5.0
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = {"log": Vector2(70, 36), "mound": Vector2(50, 70), "pot": Vector2(34, 40), "stash": Vector2(74, 40)}.get(kind, Vector2(60, 40))
		cs.shape = sh
		cs.position = Vector2(0, -sh.size.y * 0.5)
		add_child(cs)
		_base = position

	func take_hit(_dmg: int, from_dir: int) -> void:
		if hits <= 0:
			return
		hits -= 1
		_shake = 0.25
		# out comes a share of what's inside with every hit — the rest at the end
		var total_hits: int = {"log": 2, "mound": 3, "pot": 1, "stash": 2}.get(kind, 2)
		var share: int = contents.size() - _given if hits == 0 else maxi(1, contents.size() / (total_hits + 1))
		if kind == "stash" and hits > 0:
			share = 1
		for n in share:
			if _given >= contents.size():
				break
			_pop(_given, from_dir, kind == "stash" and hits == 0)
			_given += 1
		var dust := Critter.DeathPop.new()
		dust.dust = true
		dust.position = global_position
		get_parent().add_child.call_deferred(dust)
		if hits > 0:
			return
		var burst := Critter.DeathPop.new()
		burst.position = global_position + Vector2(0, -20)
		get_parent().add_child.call_deferred(burst)
		set_deferred("monitorable", false)
		call_deferred("queue_free")

	func _pop(i: int, from_dir: int, fountain: bool) -> void:
		var tid := "%s_%d" % [id, i]
		if GameState.is_taken(level_id, tid):
			return
		var p := Pickup.new()
		p.kind = contents[i]
		p.level_id = level_id
		p.id = tid
		p.position = global_position + Vector2(0, -30)
		if fountain:
			# a fountain: high, and spreading out both ways
			p.vel = Vector2(randf_range(-150, 150), randf_range(-700, -520))
		else:
			p.vel = Vector2(randf_range(-110, 110) - from_dir * 30.0, randf_range(-440, -320))
		p.floor_y = global_position.y
		var level := get_parent()
		if level.has_method("_on_treasure_popped"):
			level._on_treasure_popped(p)
		level.call_deferred("add_child", p)

	## Now and then something inside glints, so he looks twice.
	func draw_glow(g) -> void:   # g: the glow layer's Batch
		if hits <= 0:
			return
		var spark := fmod(_t * 0.5, 2.5)
		if spark < 0.4:
			var k := sin(spark / 0.4 * PI)
			var off: Vector2 = {"log": Vector2(34, -18), "mound": Vector2(4, -40), "pot": Vector2(0, -34), "stash": Vector2(0, -30)}.get(kind, Vector2(0, -20))
			var c := global_position + off
			var r := 9.0 * k
			if r < 1.5:
				return
			Treasure.glint(g, c, r, Color(1, 0.95, 0.75, k))

	func _process(delta: float) -> void:
		_t += delta
		if _shake > 0.0:
			_shake = maxf(_shake - delta, 0.0)
			position = _base + Vector2(sin(_shake * 90.0) * 4.0 * (_shake / 0.25), 0)

	func _draw() -> void:
		var b := Batch.new()
		match kind:
			"log", "stash":
				b.quad(Vector2(-36, -2), Vector2(-32, -34), Vector2(34, -32), Vector2(36, 0), Pal.BARK)
				b.line(Vector2(-30, -26), Vector2(30, -25), Pal.BARK_DARK, 3.0)
				b.line(Vector2(-30, -12), Vector2(30, -10), Pal.BARK_DARK, 3.0)
				b.circle(Vector2(34, -16), 16.0, Pal.DEADWOOD, 16)
				b.circle(Vector2(34, -16), 11.0, Pal.CAVE_DARK, 14)
				b.circle(Vector2(34, -16), 5.0, Color("f3d08a", 0.4), 8)
				if kind == "stash":
					# a monkey's mark: a red X, a banana peel on top
					b.line(Vector2(-18, -28), Vector2(6, -6), Color("c0392b"), 5.0)
					b.line(Vector2(6, -28), Vector2(-18, -6), Color("c0392b"), 5.0)
					for k in 3:
						b.line(Vector2(-6, -36), Vector2(-14 + k * 8, -30), Pal.BANANA_DARK, 3.0)
					b.circle(Vector2(-6, -37), 3.0, Pal.BANANA, 8)
			"mound":
				var pts := PackedVector2Array([Vector2(-26, 0), Vector2(-18, -30), Vector2(-10, -52), Vector2(-2, -70),
					Vector2(6, -58), Vector2(12, -40), Vector2(20, -22), Vector2(28, 0)])
				b.poly(pts, Color("9a7852"))
				b.poly(PackedVector2Array([Vector2(-18, 0), Vector2(-10, -40), Vector2(-2, -66), Vector2(4, -44), Vector2(10, 0)]), Color("b18d63"))
				for k in 6:
					b.circle(Vector2(-12 + k * 5, -8 - (k % 3) * 14), 2.2, Color("6c5236"), 8)
			"pot":
				# a clay pot with a lid and a zig-zag band
				var body := PackedVector2Array([Vector2(-10, 0), Vector2(-17, -10), Vector2(-18, -22), Vector2(-12, -32), Vector2(-9, -36),
					Vector2(9, -36), Vector2(12, -32), Vector2(18, -22), Vector2(17, -10), Vector2(10, 0)])
				b.poly(body, Color("a4623a"))
				b.poly(PackedVector2Array([Vector2(-8, -2), Vector2(-14, -12), Vector2(-14, -22), Vector2(-8, -30), Vector2(-4, -30), Vector2(-8, -18)]), Color("c0794b"))
				var zig := PackedVector2Array()
				for i in 9:
					zig.append(Vector2(-16 + i * 4, -20 + (4 if i % 2 == 0 else -2)))
				b.polyline(zig, Color("5b3018"), 2.0)
				b.rect(Rect2(-11, -40, 22, 5), Color("7a4526"))
				b.circle(Vector2(0, -42), 3.0, Color("7a4526"), 8)
		b.draw(self)


class ShellTotem extends Area2D:
	## A carved stone face in the dark with glowing eyes. Every hit, it spits
	## shells out of its mouth — until the light in its eyes goes out.
	var level_id := ""
	var id := ""
	var hits := 6
	var t := 0.0
	var _shake := 0.0
	var _given := 0

	func _ready() -> void:
		collision_layer = 4
		collision_mask = 0
		monitoring = false
		add_to_group("glow")
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(56, 110)
		cs.shape = sh
		cs.position = Vector2(0, -55)
		add_child(cs)

	func take_hit(_dmg: int, _from_dir: int) -> void:
		if hits <= 0:
			return
		hits -= 1
		_shake = 0.2
		for n in 2:
			var tid := "%s_%d" % [id, _given]
			_given += 1
			if GameState.is_taken(level_id, tid):
				continue
			var p := Pickup.new()
			p.kind = "conch" if _given == 12 else ("shell" if _given % 2 == 0 else "bone")
			p.level_id = level_id
			p.id = tid
			p.position = global_position + Vector2(0, -44)
			p.vel = Vector2(randf_range(-120, 120), randf_range(-500, -380))
			p.floor_y = global_position.y
			var level := get_parent()
			if level.has_method("_on_treasure_popped"):
				level._on_treasure_popped(p)
			level.call_deferred("add_child", p)
		if hits <= 0:
			var puff := Critter.DeathPop.new()
			puff.dust = true
			puff.big = true
			puff.position = global_position + Vector2(0, -60)
			get_parent().add_child.call_deferred(puff)
		queue_redraw()

	func _process(delta: float) -> void:
		t += delta
		_shake = maxf(_shake - delta, 0.0)
		if _shake > 0.0 or LevelBase.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var o := Vector2(sin(_shake * 80.0) * 3.0 * (_shake / 0.2), 0)
		var b := Batch.new()
		b.poly(PackedVector2Array([o + Vector2(-30, 0), o + Vector2(-26, -96), o + Vector2(-14, -112), o + Vector2(14, -112),
			o + Vector2(26, -96), o + Vector2(30, 0)]), Pal.CRAG_DARK)
		b.poly(PackedVector2Array([o + Vector2(-24, 0), o + Vector2(-20, -92), o + Vector2(-10, -104), o + Vector2(10, -104),
			o + Vector2(20, -92), o + Vector2(22, 0)]), Pal.CRAG)
		# brow, eyes, nose and a round open mouth
		b.rect(Rect2(o + Vector2(-20, -84), Vector2(40, 6)), Pal.CRAG_DARK)
		b.circle(o + Vector2(-10, -72), 6.0, Pal.CAVE_DARK, 10)
		b.circle(o + Vector2(10, -72), 6.0, Pal.CAVE_DARK, 10)
		b.poly(PackedVector2Array([o + Vector2(-4, -64), o + Vector2(4, -64), o + Vector2(6, -52), o + Vector2(-6, -52)]), Pal.CRAG_DARK)
		b.circle(o + Vector2(0, -38), 10.0, Pal.CAVE_DARK, 14)
		# carved bands below
		for k in 3:
			b.line(o + Vector2(-20, -20 + k * 7), o + Vector2(20, -20 + k * 7), Pal.CRAG_DARK, 2.0)
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		if hits <= 0:
			return
		var e := 0.6 + 0.4 * sin(t * 3.0)
		for sx in [-10.0, 10.0]:
			g.draw_circle(global_position + Vector2(sx, -72), 7.0, Color("ffcf6b", 0.25 * e))
			g.draw_circle(global_position + Vector2(sx, -72), 3.0, Color("ffe29a", 0.9 * e))
		g.draw_circle(global_position + Vector2(0, -38), 6.0, Color("ffcf6b", 0.2 * e))


class GoldenHare extends Critter:
	## A hare with a golden coat that glows in the dark. It bolts when he comes
	## near and zig-zags along its stretch of ground; corner it or catch it, and
	## it bursts into a shower of treasure — a reward for the chase.
	var left_x := 0.0
	var right_x := 0.0
	var level_id := ""
	var id := ""
	var dir := 1
	var t := 0.0
	var hop := 0.0
	var _stride := 0.0
	var _moving := 0.0

	func _setup() -> void:
		hp = 1
		damage = 0
		stompable = true
		stomp_top = -18.0
		add_rect_shape(Vector2(34, 26), Vector2(0, -13))
		t = randf() * 5.0
		add_to_group("glow")

	func death_style() -> String:
		return "hare"

	func _begin_death(from_dir: int) -> void:
		super._begin_death(from_dir)
		dying = 0.01
		# a shower of treasure where it was
		var kinds := ["conch", "shell", "shell", "shell", "bone", "bone", "bone", "tusk"]
		for i in kinds.size():
			var tid := "%s_%d" % [id, i]
			if GameState.is_taken(level_id, tid):
				continue
			var p := Pickup.new()
			p.kind = kinds[i]
			p.level_id = level_id
			p.id = tid
			p.position = global_position + Vector2(0, -20)
			p.vel = Vector2(randf_range(-150, 150), randf_range(-560, -420))
			p.floor_y = global_position.y
			var level := get_parent()
			if level.has_method("_on_treasure_popped"):
				level._on_treasure_popped(p)
			level.call_deferred("add_child", p)
		var burst := Critter.DeathPop.new()
		burst.big = true
		burst.position = global_position + Vector2(0, -16)
		get_parent().add_child.call_deferred(burst)
		visible = false

	func _tick(delta: float) -> void:
		t += delta
		_moving = 0.0
		if player == null:
			return
		var dx := player.global_position.x - position.x
		var near := absf(dx) < 280.0 and absf(player.global_position.y - position.y) < 90.0
		# caught: he only has to touch it
		if absf(dx) < 26.0 and absf(player.global_position.y - position.y) < 50.0:
			take_hit(1, 1 if dx < 0.0 else -1)
			return
		if near:
			# away from him, zig-zagging in little hops
			dir = -1 if dx > 0.0 else 1
			var speed := 250.0
			var nx := clampf(position.x + dir * speed * delta, left_x, right_x)
			_moving = absf(nx - position.x) / maxf(delta, 0.001)
			position.x = nx
			_stride += _moving * delta
		hop = absf(sin(_stride / 26.0)) * (14.0 if _moving > 10.0 else 0.0)

	func _paint() -> void:
		_st(Vector2(0, -hop), 0.0, Vector2(dir, 1))
		var gold := Color("e0b64a")
		var dark := Color("a67c22")
		_oval(Vector2(-2, -12), 15.0, 10.0, gold, 2.0)
		_oval(Vector2(12, -20), 8.0, 7.0, gold, 2.0)
		_fill(PackedVector2Array([Vector2(8, -26), Vector2(4, -46), Vector2(10, -44), Vector2(13, -26)]), dark)
		_fill(PackedVector2Array([Vector2(13, -26), Vector2(12, -46), Vector2(18, -42), Vector2(17, -25)]), gold)
		_cc(Vector2(16, -21), 1.8, Pal.OUTLINE)
		_cc(Vector2(-16, -14), 4.5, Color("fff3c4"))
		var k := sin(_stride / 13.0)
		_limb(Vector2(-8, -6), Vector2(-14 - k * 6.0, 0), 5.0, dark)
		_limb(Vector2(8, -6), Vector2(12 + k * 5.0, 0), 4.0, dark)
		_st(Vector2.ZERO, 0.0, Vector2.ONE)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		if not visible or dying > 0.0:
			return
		var c := global_position + Vector2(0, -16 - hop)
		g.draw_circle(c, 22.0, Color("ffd76a", 0.14 + 0.06 * sin(t * 3.0)))
		if fmod(t, 1.4) < 0.25:
			var r := 8.0
			var p := c + Vector2(10, -20)
			Treasure.glint(g, p, r, Color(1, 1, 1, 0.9), false)
