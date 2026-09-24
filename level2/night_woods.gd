## Level 2's world: the things of the night woods that are not alive — fire,
## dead trees and their wood, the burst of the fire ability, and the night sky
## and forest behind it all. Terrain itself is still World.Slab.
class_name NightWoods
extends RefCounted


## A teardrop of flame: round at the base, drawn up to a swaying point.
## Shared by the bonfire, the burst, and anything else that burns.
static func flame_pts(base: Vector2, w: float, h: float, sway: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 9:
		var a := PI * (i / 8.0)
		pts.append(base + Vector2(cos(a) * w, sin(a) * w * 0.8))
	pts.append(base + Vector2(-w * 0.8 + sway * 0.3, -h * 0.35))
	pts.append(base + Vector2(sway, -h))
	pts.append(base + Vector2(w * 0.7 + sway * 0.4, -h * 0.4))
	return pts


## ================================================================ BONFIRE
class Bonfire extends Area2D:
	## Light, fuel and safety in one place. Reaching one lights it if it was
	## only embers, fills the torch, and makes it the place he wakes if he dies.
	## Standing in it keeps the torch topped up.
	signal kindled       ## the first time it catches
	signal visited       ## every time he walks into it
	var lit := false
	var radius := 340.0
	var t := 0.0
	var _inside: CaveMan = null

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(90, 110)
		cs.shape = r
		cs.position = Vector2(0, -55)
		add_child(cs)
		body_entered.connect(_on_enter)
		body_exited.connect(_on_exit)
		add_to_group("light")
		add_to_group("glow")
		add_to_group("bonfire")
		t = randf() * 10.0

	func kindle() -> void:
		if lit:
			return
		lit = true
		kindled.emit()

	func _on_enter(b: Node) -> void:
		if not (b is CaveMan):
			return
		_inside = b as CaveMan
		kindle()
		_inside.relight(1.0)
		visited.emit()

	func _on_exit(b: Node) -> void:
		if b == _inside:
			_inside = null

	func _physics_process(_delta: float) -> void:
		if _inside != null and lit:
			_inside.relight(1.0)

	func light() -> Vector4:
		if not lit:
			return Vector4.ZERO
		var r := radius * (1.0 + sin(t * 11.0) * 0.012 + sin(t * 6.1) * 0.02)
		return Vector4(global_position.x, global_position.y - 46.0, r, 1.0)

	func light_strength() -> float:
		return 1.0 if lit else 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		# logs, crossed, charred where they meet
		for s in [-1.0, 1.0]:
			var a := Vector2(-34.0 * s, -4)
			var b := Vector2(26.0 * s, -24)
			draw_line(a, b, Pal.TRUNK_DARK, 13.0, true)
			draw_line(a + Vector2(0, -2), b + Vector2(0, -2), Pal.TRUNK, 6.0, true)
			draw_circle(a, 6.5, Pal.DEADWOOD)
			draw_circle(a, 3.0, Pal.DEADWOOD_DARK)
		# hearth stones ring the fire
		for i in 7:
			var sx := -44.0 + i * 14.7
			var sy := -3.0 + absf(i - 3.0) * -1.2
			var rr := 8.0 + fmod(i * 2.7, 3.0)
			draw_circle(Vector2(sx, sy), rr, Pal.HEARTH_STONE.darkened(0.3))
			draw_circle(Vector2(sx + 1.0, sy - 1.5), rr * 0.8, Pal.HEARTH_STONE)
		if lit:
			for i in 5:
				var bx := -20.0 + i * 10.0
				var h := 46.0 + 30.0 * (1.0 - absf(i - 2.0) / 2.0) + sin(t * (7.0 + i) + i) * 8.0
				var sway := sin(t * 5.0 + i * 1.7) * 6.0
				draw_colored_polygon(NightWoods.flame_pts(Vector2(bx, -16), 12.0, h, sway), Color(Pal.EMBER_GLOW, 0.9))
			for i in 4:
				var bx := -14.0 + i * 9.5
				var h := 34.0 + 22.0 * (1.0 - absf(i - 1.5) / 1.5) + sin(t * (9.0 + i)) * 6.0
				draw_colored_polygon(NightWoods.flame_pts(Vector2(bx, -14), 8.0, h, sin(t * 6.0 + i) * 4.0), Pal.FLAME)
			draw_colored_polygon(NightWoods.flame_pts(Vector2(0, -12), 7.0, 30.0 + sin(t * 13.0) * 5.0, sin(t * 8.0) * 3.0), Pal.FLAME_CORE)
			# sparks going up
			for i in 8:
				var q := fmod(t * 0.7 + i * 0.125, 1.0)
				var p := Vector2(sin(i * 2.1 + q * 5.0) * (10.0 + q * 18.0), -30.0 - q * 130.0)
				draw_circle(p, 2.2 * (1.0 - q) + 0.6, Color(Pal.FLAME_CORE, 1.0 - q))
		else:
			# cold: an ash heap, charred ends
			var ash := PackedVector2Array()
			for i in 13:
				var a := PI + PI * (i / 12.0)
				ash.append(Vector2(cos(a) * 30.0, sin(a) * 14.0 - 4.0))
			draw_colored_polygon(ash, Pal.ASH)

	## Unlit, the embers show through the dark: a beacon to walk toward.
	func draw_glow(g: Node2D) -> void:
		if lit:
			return
		var c := global_position + Vector2(0, -12)
		for i in 5:
			var e := 0.5 + 0.5 * sin(t * (1.6 + i * 0.3) + i * 2.0)
			var p := c + Vector2(-16.0 + i * 8.0, sin(i * 1.3) * 3.0)
			g.draw_circle(p, 6.0, Color(Pal.EMBER_GLOW, 0.10 * e))
			g.draw_circle(p, 2.2, Color(Pal.EMBER_GLOW, 0.35 + 0.5 * e))


## ================================================================ DEAD TREE
class DeadTree extends Area2D:
	## Bare, pale, and dry. The club knocks loose the wood still caught in its
	## forks — one bundle a hit — and that wood is what the fire is made of.
	signal gave_wood
	var wood := 2
	var height := 220.0
	var shake := 0.0
	var t := 0.0

	func _ready() -> void:
		# on the creature layer, so his swing and his rocks find it
		collision_layer = 4
		collision_mask = 0
		monitoring = false
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(46, 170)
		cs.shape = r
		cs.position = Vector2(0, -85)
		add_child(cs)

	func take_hit(_dmg: int, from_dir: int) -> void:
		shake = 0.35
		if wood <= 0:
			return
		wood -= 1
		var w := WoodPickup.new()
		w.position = global_position + Vector2(0, -150)
		w.vel = Vector2(-float(from_dir) * randf_range(90.0, 150.0), -300.0)
		w.ground_y = global_position.y
		get_parent().call_deferred("add_child", w)
		gave_wood.emit()

	func _process(delta: float) -> void:
		t += delta
		shake = maxf(shake - delta, 0.0)
		queue_redraw()

	func _draw() -> void:
		var sway := sin(shake * 60.0) * 5.0 * (shake / 0.35)
		var top := Vector2(6.0 + sway, -height)
		var body := PackedVector2Array([
			Vector2(-30, 0), Vector2(-17, -10), Vector2(-12, -90), Vector2(-8, -height + 30.0),
			top + Vector2(-8, 4), top + Vector2(-2, -14), top + Vector2(4, 2), top + Vector2(9, -8),
			Vector2(12, -height + 40.0), Vector2(14, -80), Vector2(19, -10), Vector2(32, 0)])
		draw_colored_polygon(body, Pal.DEADWOOD_DARK)
		var lit := PackedVector2Array()
		for p in body:
			lit.append(Vector2(p.x * 0.8 + 3.0, p.y * 0.98))
		draw_colored_polygon(lit, Pal.DEADWOOD)
		# bark split along its length
		for k in 3:
			var x := -6.0 + k * 6.0
			draw_line(Vector2(x, -12), Vector2(x + sway * 0.3, -height * (0.55 + k * 0.1)), Pal.DEADWOOD_DARK, 2.0, true)
		# bare branches
		var forks := [[Vector2(0, -130), Vector2(-60, -190), 7.0], [Vector2(4, -160), Vector2(56, -214), 6.0],
			[Vector2(-34, -170), Vector2(-52, -226), 4.0], [Vector2(30, -194), Vector2(44, -244), 3.5]]
		for f in forks:
			var a: Vector2 = f[0]
			var b: Vector2 = f[1]
			draw_line(a + Vector2(sway * 0.6, 0), b + Vector2(sway, 0), Pal.DEADWOOD_DARK, float(f[2]) + 2.0, true)
			draw_line(a + Vector2(sway * 0.6, 0), b + Vector2(sway, 0), Pal.DEADWOOD, float(f[2]), true)
		# the loose wood still caught in the forks, one bundle for each left
		for i in wood:
			var at := Vector2(-6.0 + i * 16.0 + sway, -142.0 - i * 18.0)
			var pulse := 0.5 + 0.5 * sin(t * 2.6 + i)
			draw_arc(at, 18.0 + pulse * 4.0, 0.0, TAU, 20, Color(Pal.OCHRE, 0.15 + pulse * 0.25), 2.0)
			for k in 3:
				var o := Vector2(0, -4.0 + k * 4.0)
				draw_line(at + o + Vector2(-13, 3), at + o + Vector2(13, -3), Pal.DEADWOOD.lightened(0.15), 3.5, true)
			draw_line(at + Vector2(-1, -8), at + Vector2(1, 8), Pal.VINE, 2.5, true)


class WoodPickup extends Area2D:
	## A bundle knocked out of a dead tree. Falls, lands, waits to be taken.
	signal taken
	var vel := Vector2.ZERO
	var ground_y := 600.0
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
		cs.position = Vector2(0, -8)
		add_child(cs)
		body_entered.connect(_on_body)

	func _on_body(b: Node) -> void:
		if gone or not (b is CaveMan):
			return
		if not (b as CaveMan).add_wood():
			return
		gone = true
		taken.emit()
		set_deferred("monitoring", false)
		call_deferred("queue_free")

	func _physics_process(delta: float) -> void:
		t += delta
		if not resting:
			vel.y += 1200.0 * delta
			position += vel * delta
			if position.y >= ground_y:
				position.y = ground_y
				resting = true
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(t * 2.6)
		if resting:
			draw_arc(Vector2(0, -8), 22.0 + pulse * 5.0, 0.0, TAU, 24, Color(Pal.OCHRE, 0.2 + pulse * 0.25), 2.0)
		for k in 3:
			var o := Vector2(0, -12.0 + k * 4.5)
			draw_line(o + Vector2(-16, 3), o + Vector2(16, -3), Pal.DEADWOOD_DARK, 6.0, true)
			draw_line(o + Vector2(-16, 2), o + Vector2(16, -4), Pal.DEADWOOD, 3.5, true)
		draw_line(Vector2(-1, -18), Vector2(1, 0), Pal.VINE, 3.0, true)


## ================================================================ FIRE BURST
class FireBurst extends Node2D:
	## The fire ability. A ring of flame thrown out from where he stands: burns
	## everything inside it, sends what is just outside it running, catches any
	## cold bonfire it reaches — and while it lasts it is the brightest light
	## there is, so it lights the dark for a moment as well.
	const RADIUS := 240.0
	const DAMAGE := 6
	const GROUND := 40.0     ## it is lit at his chest; his feet are this far below
	var t := 0.0

	func _ready() -> void:
		z_index = 5
		add_to_group("light")
		var from := global_position
		for c in get_tree().get_nodes_in_group("critters"):
			var cr := c as Critter
			if cr == null or cr.dying > 0.0:
				continue
			var d := (cr.global_position + Vector2(0, -18)).distance_to(from)
			if d < RADIUS:
				cr.burned(DAMAGE, from)
			elif d < RADIUS * 1.8 and cr.has_method("scare"):
				cr.scare(from)
		for b in get_tree().get_nodes_in_group("bonfire"):
			if (b as Node2D).global_position.distance_to(from) < RADIUS + 40.0:
				b.kindle()
		for m in get_tree().get_nodes_in_group("monkeys"):
			if (m as Node2D).global_position.distance_to(from) < RADIUS * 1.8:
				m.scare(from)

	func light() -> Vector4:
		var grow := clampf(t / 0.18, 0.0, 1.0)
		var fade := 1.0 - clampf((t - 0.35) / 0.9, 0.0, 1.0)
		return Vector4(global_position.x, global_position.y, (120.0 + RADIUS * 1.25 * grow) * fade, 1.0)

	func light_strength() -> float:
		return 1.0 if t < 0.7 else 0.0

	func _process(delta: float) -> void:
		t += delta
		if t > 1.3:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var grow := 1.0 - pow(1.0 - clampf(t / 0.25, 0.0, 1.0), 3.0)
		var fade := 1.0 - clampf((t - 0.3) / 0.9, 0.0, 1.0)
		var r := RADIUS * grow
		# A dome of fire standing on the ground, not a ring through it. The
		# burst starts at his chest, GROUND px above his feet.
		_dome(r, Color(Pal.FLAME, 0.22 * fade))
		_dome(r * 0.55, Color(Pal.FLAME_CORE, 0.25 * fade))
		# tongues pointing outward (skipped once they have burned down, since
		# a flat triangle is a polygon the renderer cannot fill)
		if fade < 0.06:
			return
		for i in 22:
			var a := TAU * i / 22.0 + t * 0.6
			var d := Vector2.from_angle(a)
			var base := d * r * 0.9
			if base.y > GROUND - 6.0:
				continue
			var n := Vector2(-d.y, d.x)
			var len := maxf((34.0 + 18.0 * sin(i * 2.3 + t * 20.0)) * fade, 4.0)
			draw_colored_polygon(PackedVector2Array([base + n * 11.0, base + d * len, base - n * 11.0]), Color(Pal.EMBER_GLOW, 0.9 * fade))
			draw_colored_polygon(PackedVector2Array([base + n * 6.0, base + d * len * 0.65, base - n * 6.0]), Color(Pal.FLAME, fade))
		# and a line of flame racing out along the ground under it
		for i in 12:
			var gx := lerpf(-r * 0.95, r * 0.95, i / 11.0)
			var h := (26.0 + 22.0 * sin(i * 1.9 + t * 18.0)) * fade * (1.0 - absf(gx) / maxf(r, 1.0) * 0.5)
			draw_colored_polygon(NightWoods.flame_pts(Vector2(gx, GROUND - 4.0), 9.0, maxf(h, 8.0), sin(t * 9.0 + i) * 4.0), Color(Pal.EMBER_GLOW, 0.85 * fade))
		for i in 18:
			var a := TAU * i / 18.0 + i * 0.4
			var p := Vector2.from_angle(a) * (r * 0.5 + t * 160.0) + Vector2(0, -t * t * 80.0)
			if p.y < GROUND:
				draw_circle(p, 3.0 * fade + 0.5, Color(Pal.FLAME_CORE, fade))

	## The part of a circle above the ground line: an arc and its chord.
	func _dome(r: float, col: Color) -> void:
		if r < 2.0:
			return
		var pts := PackedVector2Array()
		var a0 := 0.0
		var a1 := TAU
		if r > GROUND:
			var c := asin(GROUND / r)
			a0 = PI - c
			a1 = TAU + c
		var n := 28
		for i in n + 1:
			pts.append(Vector2.from_angle(lerpf(a0, a1, float(i) / n)) * r)
		if r <= GROUND:
			pts.remove_at(pts.size() - 1)
		draw_colored_polygon(pts, col)


## ================================================================ MOUNTAIN
class Crag extends StaticBody2D:
	## Mountain rock. Solid like World.Slab, but drawn as stone with a pale
	## moonlit lip, so the climb reads as rock and not as more ground.
	var rect := Rect2()

	func _init(r: Rect2) -> void:
		rect = r

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		position = rect.position
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = rect.size
		cs.shape = sh
		cs.position = rect.size * 0.5
		add_child(cs)

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(rect.position.x) * 13 + int(rect.position.y)
		var w := rect.size.x
		var h := rect.size.y
		var thin := h < 40.0
		if thin:
			# a ledge sticking out of the face: ragged underneath
			var under := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h)])
			var x := w
			while x > 0.0:
				x -= rng.randf_range(12.0, 22.0)
				under.append(Vector2(maxf(x, 0.0), h + rng.randf_range(4.0, 20.0) * (1.0 - absf(x / w - 0.5))))
			under.append(Vector2(0, h))
			draw_colored_polygon(under, Pal.CRAG_DARK)
		else:
			draw_rect(Rect2(0, 0, w, h), Pal.CRAG_DARK.darkened(0.35))
			draw_rect(Rect2(0, 0, w, minf(h, 150.0)), Pal.CRAG_DARK)
		draw_rect(Rect2(0, 0, w, minf(h, 26.0 if thin else 60.0)), Pal.CRAG)
		draw_rect(Rect2(0, 0, w, 5), Pal.CRAG_LIGHT)
		# strata and cracks
		var n := int(w / 45.0) + 1
		for i in n:
			var cx := rng.randf_range(6.0, maxf(7.0, w - 6.0))
			var cy := rng.randf_range(10.0, minf(h, 120.0))
			draw_line(Vector2(cx, cy), Vector2(cx + rng.randf_range(-10.0, 10.0), cy + rng.randf_range(10.0, 30.0)), Pal.CRAG_DARK.darkened(0.2), 2.0, true)
		# loose stones on the lip
		for i in int(w / 60.0):
			draw_circle(Vector2(rng.randf_range(8.0, w - 8.0), -2.0), rng.randf_range(2.0, 4.0), Pal.CRAG_LIGHT.darkened(0.15))


class Boulder extends StaticBody2D:
	## A rock big enough to crouch behind: in its lee the wind cannot reach
	## him, and it cannot reach his torch. Solid, and low enough to jump.
	const W := 62.0
	const H := 68.0

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(W - 10.0, H)
		cs.shape = sh
		cs.position = Vector2(0, -H * 0.5)
		add_child(cs)

	func _draw() -> void:
		var pts := PackedVector2Array([Vector2(-W * 0.5, 0), Vector2(-W * 0.52, -H * 0.5), Vector2(-W * 0.3, -H * 0.92),
			Vector2(0, -H), Vector2(W * 0.35, -H * 0.88), Vector2(W * 0.52, -H * 0.45), Vector2(W * 0.5, 0)])
		draw_colored_polygon(pts, Pal.CRAG_DARK)
		var hi := PackedVector2Array()
		for p in pts:
			hi.append(Vector2(p.x * 0.82 - 3.0, p.y * 0.9 - 2.0))
		draw_colored_polygon(hi, Pal.CRAG)
		draw_polyline(PackedVector2Array([pts[2], pts[3], pts[4]]), Pal.CRAG_LIGHT, 3.0, true)
		draw_line(Vector2(-6, -H * 0.6), Vector2(4, -H * 0.3), Pal.CRAG_DARK, 2.0, true)


class MountainFace extends Node2D:
	## The mountain behind the climb: scenery only, so it reads as a backdrop
	## (cooler and darker than the rock you can stand on).
	var outline := PackedVector2Array()

	func _draw() -> void:
		draw_colored_polygon(outline, Pal.MOUNTAIN_FACE)
		var rim := PackedVector2Array()
		for i in range(1, outline.size() - 1):
			rim.append(outline[i])
		draw_polyline(rim, Color(Pal.MOONLIT, 0.35), 3.0, true)
		# gullies down the face, so it never reads as a slope you could walk
		var x0 := outline[0].x
		var x1 := outline[outline.size() - 1].x
		var gx := x0 + 60.0
		var gi := 0
		while gx < x1 - 60.0:
			var y := _surface(gx) + 30.0
			draw_line(Vector2(gx, y), Vector2(gx + sin(gi * 1.7) * 20.0, y + 260.0 + fmod(gi * 53.0, 200.0)), Color(Pal.CHARCOAL, 0.35), 5.0, true)
			gx += 70.0 + fmod(gi * 37.0, 60.0)
			gi += 1
		# strata running across the face
		for k in 7:
			var y := -300.0 + k * 130.0
			var line := PackedVector2Array()
			for i in 12:
				var x := outline[0].x + (outline[outline.size() - 1].x - outline[0].x) * i / 11.0
				line.append(Vector2(x, y + sin(x * 0.004 + k) * 26.0))
			draw_polyline(line, Color(Pal.NIGHT_NEAR, 0.45), 2.0, true)


	func _surface(x: float) -> float:
		for i in range(1, outline.size()):
			var a := outline[i - 1]
			var b := outline[i]
			if x >= a.x and x <= b.x:
				return lerpf(a.y, b.y, (x - a.x) / maxf(b.x - a.x, 1.0))
		return 0.0


class Wind extends Node2D:
	## Gusts on the mountain, on a rhythm the player can learn: a breath of a
	## warning (streaks thicken, leaves fly), then a full gust, then calm.
	## In the air it carries him; on the ground he can brace by walking into
	## it; behind rock (anything solid just upwind of him) he is out of it.
	## Every full gust that catches him eats at the torch, down to embers.
	signal first_gust
	const PERIOD := 6.0
	const TELL := 1.0
	const GUST := 1.5
	var x0 := 0.0
	var x1 := 0.0
	var strength := -230.0     ## px/s; negative blows toward -x, down the climb
	const LEE := 90.0          ## rock this close upwind of him keeps it off
	var player: CaveMan
	var t := 0.0
	var k := 0.0               ## 0 calm .. 1 full gust
	var sheltered := false
	var _applied := false
	var _told := false

	func _ready() -> void:
		add_to_group("glow")

	func _physics_process(delta: float) -> void:
		t += delta
		var ph := fmod(t, PERIOD)
		if ph < TELL:
			k = ph / TELL * 0.25
		elif ph < TELL + GUST:
			k = 1.0
		elif ph < TELL + GUST + 0.4:
			k = 1.0 - (ph - TELL - GUST) / 0.4
		else:
			k = 0.0
		if player == null:
			return
		var p := player.global_position
		position.x = p.x
		if p.x < x0 or p.x > x1 or player.dead:
			if _applied:
				player.wind = 0.0
				_applied = false
			return
		_applied = true
		sheltered = _lee(p)
		player.wind = 0.0 if sheltered else strength * k
		if k >= 0.99 and not sheltered:
			if player.has_torch and player.torch_fuel > 0.06:
				player.torch_fuel = maxf(player.torch_fuel - 0.26 * delta, 0.06)
			if not _told:
				_told = true
				first_gust.emit()

	## Solid rock just upwind at chest height: a boulder, or the next wall of the climb.
	func _lee(p: Vector2) -> bool:
		var up := -signf(strength)
		var q := PhysicsRayQueryParameters2D.create(p + Vector2(0, -40), p + Vector2(up * LEE, -40), 1)
		return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()

	func draw_glow(g: Node2D) -> void:
		if k <= 0.01 or player == null:
			return
		var px := player.global_position.x
		if px < x0 - 300.0 or px > x1 + 300.0:
			return
		var cam := get_viewport().get_camera_2d()
		var c := cam.get_screen_center_position() if cam != null else player.global_position
		var dirx := signf(strength)
		for i in 36:
			var y := c.y - 350.0 + fmod(i * 97.0, 700.0)
			var x := c.x - dirx * 700.0 + dirx * fmod(t * 1150.0 + i * 173.0, 1400.0)
			var len := 40.0 + fmod(i * 37.0, 80.0)
			g.draw_line(Vector2(x, y), Vector2(x - dirx * len, y + 2.0), Color(Pal.WIND, 0.26 * k), 1.6, true)
		for i in 9:
			var y := c.y - 250.0 + fmod(i * 131.0, 520.0) + sin(t * 5.0 + i) * 24.0
			var x := c.x - dirx * 700.0 + dirx * fmod(t * 820.0 + i * 211.0, 1400.0)
			var a := t * 9.0 + i
			var leaf := PackedVector2Array([Vector2(x, y) + Vector2.from_angle(a) * 6.0, Vector2(x, y) + Vector2.from_angle(a + 1.6) * 2.5,
				Vector2(x, y) - Vector2.from_angle(a) * 6.0, Vector2(x, y) - Vector2.from_angle(a + 1.6) * 2.5])
			g.draw_colored_polygon(leaf, Color(Pal.DEADWOOD if i % 2 == 0 else Pal.CANOPY.lightened(0.3), 0.8 * k))


## ================================================================ GREAT TREE
class Branch extends StaticBody2D:
	## One bough of the great tree: stand on it, jump up through it from below.
	var rect := Rect2()
	var root_left := true      ## which end grows out of the trunk

	func _init(r: Rect2, from_left: bool) -> void:
		rect = r
		root_left = from_left

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		position = rect.position
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(rect.size.x, 14)
		cs.shape = sh
		cs.position = Vector2(rect.size.x * 0.5, 7)
		cs.one_way_collision = true
		add_child(cs)

	func _draw() -> void:
		var w := rect.size.x
		var root := 0.0 if root_left else w
		var tip := w - root
		var d := 1.0 if root_left else -1.0
		var body := PackedVector2Array([Vector2(root - d * 12.0, -3), Vector2(tip, 0), Vector2(tip + d * 14.0, 4),
			Vector2(tip, 9), Vector2(root + (tip - root) * 0.5, 14), Vector2(root - d * 12.0, 24)])
		draw_colored_polygon(body, Pal.BARK_DARK)
		draw_colored_polygon(PackedVector2Array([Vector2(root - d * 12.0, -3), Vector2(tip, 0), Vector2(tip, 5), Vector2(root - d * 12.0, 8)]), Pal.BARK)
		draw_line(Vector2(root, -2), Vector2(tip, 0), Color(Pal.MOONLIT, 0.35), 2.0, true)
		# twigs and leaf clusters, mostly toward the tip
		var rng := RandomNumberGenerator.new()
		rng.seed = int(rect.position.x) * 3 + int(rect.position.y)
		var n := int(w / 110.0) + 1
		for i in n:
			var x := root + (tip - root) * (0.35 + 0.65 * (i + 1.0) / n)
			var up := rng.randf() < 0.4
			var end := Vector2(x + d * rng.randf_range(10.0, 30.0), -28.0 if up else 30.0)
			draw_line(Vector2(x, 4), end, Pal.BARK_DARK, 3.0, true)
			_leaves(end, rng.randf_range(12.0, 20.0), rng)
		_leaves(Vector2(tip + d * 18.0, 2), 22.0, rng)

	func _leaves(c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
		for k in 5:
			var o := Vector2(rng.randf_range(-r, r), rng.randf_range(-r * 0.6, r * 0.6))
			draw_circle(c + o, r * rng.randf_range(0.45, 0.7), Pal.CANOPY_DARK if k % 2 == 0 else Pal.CANOPY)


class GreatTree extends Node2D:
	## The oldest tree in the woods: a trunk wider than a mammoth, roots like
	## walls, a crown above everything. Scenery only — its branches are the
	## Branch platforms placed over it.
	var top := -1360.0         ## local y of the top of the trunk
	var half := 72.0           ## half the trunk's width at the base

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		# the crown, behind everything: masses of leaf up the trunk and out over the bough
		for c in [[Vector2(-160, -560), 170.0], [Vector2(170, -700), 190.0], [Vector2(-150, -900), 190.0],
				[Vector2(120, -1060), 210.0], [Vector2(-40, -1250), 230.0], [Vector2(420, -660), 150.0],
				[Vector2(640, -690), 130.0], [Vector2(860, -660), 120.0]]:
			_blob(c[0], c[1], Pal.CANOPY_DARK, rng)
			_blob((c[0] as Vector2) + Vector2(24, -30), float(c[1]) * 0.7, Pal.CANOPY, rng)
		# roots, flaring out like walls
		for s in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([Vector2(s * half * 0.6, -150), Vector2(s * (half + 150.0), 4),
				Vector2(s * (half + 60.0), 6), Vector2(s * half * 0.4, -40)]), Pal.BARK_DARK)
		var trunk := PackedVector2Array([Vector2(-half, 4), Vector2(-half * 0.92, -300), Vector2(-half * 0.8, -700),
			Vector2(-half * 0.62, top), Vector2(half * 0.62, top), Vector2(half * 0.8, -700), Vector2(half * 0.92, -300), Vector2(half, 4)])
		draw_colored_polygon(trunk, Pal.BARK_DARK)
		draw_colored_polygon(PackedVector2Array([Vector2(-half * 0.55, 4), Vector2(-half * 0.5, -700), Vector2(-half * 0.3, top),
			Vector2(half * 0.45, top), Vector2(half * 0.62, -700), Vector2(half * 0.7, 4)]), Pal.BARK)
		draw_line(Vector2(half * 0.9, -20), Vector2(half * 0.6, top), Color(Pal.MOONLIT, 0.3), 3.0, true)
		# bark grooves
		for i in 9:
			var x := -half * 0.7 + i * half * 0.17
			var pts := PackedVector2Array()
			for k in 14:
				var y := -k * (-top / 13.0)
				pts.append(Vector2(x * (1.0 - k * 0.025) + sin(k * 1.3 + i) * 4.0, y))
			draw_polyline(pts, Pal.BARK_DARK, 2.5, true)
		# a knot-hole, dark as a cave
		draw_circle(Vector2(-12, -820), 22.0, Pal.BARK_DARK.darkened(0.4))
		draw_circle(Vector2(-12, -822), 15.0, Pal.CHARCOAL)
		# the top of the crown closes over the trunk
		_blob(Vector2(10, top + 20.0), 150.0, Pal.CANOPY_DARK, rng)
		_blob(Vector2(-20, top - 10.0), 110.0, Pal.CANOPY, rng)

	func _blob(c: Vector2, r: float, col: Color, rng: RandomNumberGenerator) -> void:
		var pts := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			var rr := r * (0.85 + 0.2 * sin(a * 5.0 + c.x * 0.01) + rng.randf_range(-0.05, 0.05))
			pts.append(c + Vector2(cos(a) * rr, sin(a) * rr * 0.62))
		draw_colored_polygon(pts, col)


## ================================================================ BACKGROUND
class NightSky extends Node2D:
	## Fixed to the screen. Dusk at the start of the level, full night by the
	## first dark stretch: the level sets `dusk` from how far he has walked.
	var dusk := 1.0
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var hi := Pal.NIGHT_SKY_HIGH.lerp(Pal.DUSK_HIGH, dusk)
		var lo := Pal.NIGHT_SKY_LOW.lerp(Pal.DUSK_LOW, dusk)
		draw_polygon(
			PackedVector2Array([Vector2(-60, -60), Vector2(1400, -60), Vector2(1400, 840), Vector2(-60, 840)]),
			PackedColorArray([hi, hi, lo, lo]))
		var starlight := 1.0 - dusk
		if starlight > 0.02:
			for i in 110:
				var p := Vector2(fmod(i * 197.3, 1340.0) - 30.0, fmod(i * 83.7 + i * i * 0.37, 470.0))
				var tw := 0.55 + 0.45 * sin(t * (0.8 + fmod(i * 0.37, 1.3)) + i)
				draw_circle(p, 0.9 + fmod(i * 0.61, 1.1), Color(Pal.STAR, starlight * tw * (0.35 + fmod(i * 0.29, 0.5))))
		var m := Vector2(1010, 104)
		for i in 4:
			draw_circle(m, 58.0 + i * 24.0, Color(Pal.MOON, 0.07 - i * 0.015))
		draw_circle(m, 42.0, Pal.MOON)
		for c in [[Vector2(-12, -8), 9.0], [Vector2(10, 6), 7.0], [Vector2(4, -16), 4.5], [Vector2(-8, 16), 5.0]]:
			draw_circle(m + (c[0] as Vector2), float(c[1]), Pal.MOON_SHADE)


class NightRidges extends World.Panorama:
	## Far mountains, their crests picked out by the moon.
	func _draw() -> void:
		var keep := seedn
		_crest(372.0, 92.0, 20.0, Pal.NIGHT_FAR, Pal.NIGHT_FAR_RIM)
		seedn = keep + 4
		_crest(452.0, 58.0, 18.0, Pal.NIGHT_MID, Pal.NIGHT_FAR)
		seedn = keep

	func _crest(base: float, a: float, step: float, body: Color, rim: Color) -> void:
		strip(base, a, step, body)
		var top := PackedVector2Array()
		var x := -20.0
		while x <= length + 20.0:
			top.append(Vector2(x, line(x, base, a)))
			x += step
		draw_polyline(top, rim, 2.5, true)


class PineBand extends World.Panorama:
	## A far wall of pines. Each tier catches a line of moonlight on the right.
	func _draw() -> void:
		var x := -40.0
		var i := 0
		while x < length + 40.0:
			var base := line(x, 548.0, 24.0)
			var h := 110.0 + rnd(i) * 130.0
			_pine(Vector2(x, base), h, 20.0 + rnd(i + 3) * 16.0, Pal.PINE_DARK if i % 3 == 0 else Pal.PINE)
			x += 24.0 + rnd(i + 7) * 46.0
			i += 1
		strip(552.0, 16.0, 30.0, Pal.PINE_DARK)

	func _pine(at: Vector2, h: float, w: float, col: Color) -> void:
		draw_line(at, at + Vector2(0, -h * 0.3), Pal.TRUNK_DARK, 4.0)
		for k in 4:
			var y0 := at.y - h * (0.16 + k * 0.2)
			var ww := w * (1.0 - k * 0.2)
			var tip := Vector2(at.x, y0 - h * 0.34)
			draw_colored_polygon(PackedVector2Array([
				Vector2(at.x - ww, y0), tip, Vector2(at.x + ww, y0), Vector2(at.x, y0 - h * 0.05)]), col)
			draw_line(tip, Vector2(at.x + ww, y0), Color(Pal.MOONLIT, 0.28), 1.5, true)


class WoodsBand extends World.Panorama:
	## The near forest: tall trunks that run up out of the frame, and the odd
	## dead snag. Nothing here is lit but the moon's edge down their right sides.
	func _draw() -> void:
		var x := 60.0
		var i := 0
		while x < length:
			var base := line(x, 572.0, 10.0)
			if rnd(i + 11) < 0.22:
				_snag(Vector2(x, base), 150.0 + rnd(i) * 110.0, i)
			else:
				_trunk(Vector2(x, base), 26.0 + rnd(i + 2) * 24.0, i)
			x += 190.0 + rnd(i + 5) * 260.0
			i += 1
		strip(578.0, 8.0, 30.0, Pal.NIGHT_NEAR)

	func _trunk(at: Vector2, w: float, k: int) -> void:
		var lean := (rnd(k + 20) - 0.5) * 40.0
		var top := at + Vector2(lean, -1100.0)
		var pts := PackedVector2Array([
			at + Vector2(-w * 1.5, 4), at + Vector2(-w * 0.6, -30), top + Vector2(-w * 0.35, 0),
			top + Vector2(w * 0.35, 0), at + Vector2(w * 0.6, -30), at + Vector2(w * 1.5, 4)])
		draw_colored_polygon(pts, Pal.NIGHT_NEAR)
		draw_line(at + Vector2(w * 0.55, -30), top + Vector2(w * 0.33, 0), Color(Pal.MOONLIT, 0.30), 2.0, true)
		for b in 2:
			var y := -260.0 - rnd(k + b * 7) * 260.0
			var s := -1.0 if (k + b) % 2 == 0 else 1.0
			var root := at + Vector2(lean * (-y / 1100.0), y)
			draw_line(root, root + Vector2(s * (60.0 + rnd(k + b) * 50.0), -50.0 - rnd(k + 3 + b) * 40.0), Pal.NIGHT_NEAR, 6.0, true)

	func _snag(at: Vector2, h: float, k: int) -> void:
		var w := 20.0 + rnd(k + 4) * 10.0
		var pts := PackedVector2Array([
			at + Vector2(-w, 4), at + Vector2(-w * 0.5, -h * 0.9), at + Vector2(-w * 0.2, -h),
			at + Vector2(w * 0.1, -h * 0.86), at + Vector2(w * 0.4, -h * 0.97), at + Vector2(w * 0.55, -h * 0.8),
			at + Vector2(w, 4)])
		draw_colored_polygon(pts, Pal.NIGHT_NEAR)
		draw_line(at + Vector2(w * 0.55, -h * 0.8), at + Vector2(w, 4), Color(Pal.MOONLIT, 0.30), 2.0, true)
