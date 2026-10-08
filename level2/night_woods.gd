## Level 2's world: the things of the night woods that are not alive — fire,
## dead trees and their wood, the burst of the fire ability, and the night sky
## and forest behind it all. Terrain itself is still World.Slab.
class_name NightWoods
extends RefCounted


## Is this node near what the camera can see? Things that animate only need
## redrawing then; off screen they would be redrawn for nobody.
static func near_view(n: Node2D, margin: float = 800.0) -> bool:
	return LevelBase.near_view(n, margin)      # one rule for both levels


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
		Sleeper.enrol(self)          # far from the camera it sleeps (common/sleeper.gd)
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

	## Stand IN the flames of a campfire for three seconds and he gets his
	## backside scorched (see CaveMan.scorched): smoke curls up from his feet
	## as a warning first. Harmless — and funny. Not the braziers on pillars.
	var can_scorch := true
	var _scorch := 0.0
	var _smoke_in := 0.0

	func _scorch_check(delta: float) -> void:
		if not lit or not can_scorch:
			return
		var man = get_tree().get_first_node_in_group("player")
		if man == null or man.dead:
			return
		var d: Vector2 = (man as Node2D).global_position - global_position
		var in_flames: bool = absf(d.x) < 34.0 and absf(d.y) < 30.0 and man.is_on_floor()
		if not in_flames:
			_scorch = minf(_scorch, 0.0)
			_scorch = move_toward(_scorch, 0.0, delta)
			return
		_scorch += delta
		if _scorch > 1.4:
			_smoke_in -= delta
			if _smoke_in <= 0.0:
				_smoke_in = 0.18
				FX.burst(get_parent(), (man as Node2D).global_position + Vector2(0, -6), "smoke")
		if _scorch >= 3.0:
			_scorch = -2.5
			man.scorched(global_position.x)

	var _embers: CPUParticles2D
	var _haze: ColorRect

	## Embers and heat haze: made once, shown only while lit and on screen.
	func _fx_update() -> void:
		var want := lit and NightWoods.near_view(self)
		if want and _embers == null:
			_embers = FX.embers(22.0 * radius / 340.0, 20, 1.0)
			_embers.position = Vector2(0, -34)
			add_child(_embers)
			_haze = FX.shimmer(90.0 * radius / 340.0, 150.0)
			_haze.position += Vector2(0, -40)
			add_child(_haze)
		if _embers != null:
			_embers.emitting = want
			_haze.visible = want

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
		_scorch_check(delta)
		t += delta
		if NightWoods.near_view(self):
			queue_redraw()
		_fx_update()

	## Rebuilt every frame (it flickers), but as one Batch: one draw call, not ~30.
	func _draw() -> void:
		var bt := Batch.new()
		# logs, crossed, charred where they meet
		for s in [-1.0, 1.0]:
			var a := Vector2(-34.0 * s, -4)
			var b := Vector2(26.0 * s, -24)
			bt.line(a, b, Pal.TRUNK_DARK, 13.0)
			bt.line(a + Vector2(0, -2), b + Vector2(0, -2), Pal.TRUNK, 6.0)
			bt.circle(a, 6.5, Pal.DEADWOOD, 10)
			bt.circle(a, 3.0, Pal.DEADWOOD_DARK, 8)
		# hearth stones ring the fire
		for i in 7:
			var sx := -44.0 + i * 14.7
			var sy := -3.0 + absf(i - 3.0) * -1.2
			var rr := 8.0 + fmod(i * 2.7, 3.0)
			bt.circle(Vector2(sx, sy), rr, Pal.HEARTH_STONE.darkened(0.3), 10)
			bt.circle(Vector2(sx + 1.0, sy - 1.5), rr * 0.8, Pal.HEARTH_STONE, 10)
		if lit:
			for i in 5:
				var bx := -20.0 + i * 10.0
				var h := 46.0 + 30.0 * (1.0 - absf(i - 2.0) / 2.0) + sin(t * (7.0 + i) + i) * 8.0
				var sway := sin(t * 5.0 + i * 1.7) * 6.0
				bt.poly(NightWoods.flame_pts(Vector2(bx, -16), 12.0, h, sway), Color(Pal.EMBER_GLOW, 0.9))
			for i in 4:
				var bx := -14.0 + i * 9.5
				var h := 34.0 + 22.0 * (1.0 - absf(i - 1.5) / 1.5) + sin(t * (9.0 + i)) * 6.0
				bt.poly(NightWoods.flame_pts(Vector2(bx, -14), 8.0, h, sin(t * 6.0 + i) * 4.0), Pal.FLAME)
			bt.poly(NightWoods.flame_pts(Vector2(0, -12), 7.0, 30.0 + sin(t * 13.0) * 5.0, sin(t * 8.0) * 3.0), Pal.FLAME_CORE)
			# sparks going up
			for i in 8:
				var q := fmod(t * 0.7 + i * 0.125, 1.0)
				var p := Vector2(sin(i * 2.1 + q * 5.0) * (10.0 + q * 18.0), -30.0 - q * 130.0)
				bt.circle(p, 2.2 * (1.0 - q) + 0.6, Color(Pal.FLAME_CORE, 1.0 - q), 6)
		else:
			# cold: an ash heap, charred ends
			var ash := PackedVector2Array()
			for i in 13:
				var a := PI + PI * (i / 12.0)
				ash.append(Vector2(cos(a) * 30.0, sin(a) * 14.0 - 4.0))
			bt.poly(ash, Pal.ASH)
		bt.draw(self)

	## Unlit, the embers show through the dark: a beacon to walk toward.
	func draw_glow(g) -> void:   # g: the glow layer's Batch
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
		Sleeper.enrol(self)          # far from the camera it sleeps (common/sleeper.gd)
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
		if NightWoods.near_view(self):
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
		if NightWoods.near_view(self):
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
	## The show (2026-10-08, "premium"): a white-hot FLASH and a beat of
	## hit-stop with a shake; a SHOCKWAVE ring racing out ahead of the fire; the
	## dome of fire in layers (ember, flame, white core) with flickering tongues;
	## a wall of flame running along the ground; SPARKS flung out that arc and
	## fall; SMOKE rolling up after; and a SCORCH on the ground, its cracks
	## glowing, that cools and fades.
	const RADIUS := 240.0
	const DAMAGE := 6
	const GROUND := 40.0     ## it is lit at his chest; his feet are this far below
	const LIFE := 2.6        ## the fire is done at 1.3 s; smoke and the scorch linger
	var t := 0.0
	var _sparks: Array = []  ## [pos, vel, size, life]
	var _smoke: Array = []   ## [pos, vel, radius, delay]
	var _cracks: Array = []  ## [where, length, bend]

	func _ready() -> void:
		z_index = 5
		add_to_group("light")
		add_to_group("glow")
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
			var dm := (m as Node2D).global_position.distance_to(from)
			if dm < RADIUS:
				m.burn()
			elif dm < RADIUS * 1.8:
				m.scare(from)
		for w in get_tree().get_nodes_in_group("webs"):
			if absf((w as Node2D).global_position.x - from.x) < RADIUS:
				w.burn()
		# the moment it goes off: a beat of hit-stop and a shake
		Critter.slow_time(get_tree(), 0.07, 0.08)
		var lvl := get_parent()
		if lvl != null and lvl.has_method("shake"):
			lvl.shake(9.0, 0.35)
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in 46:
			var a := rng.randf_range(PI * 1.03, TAU * 0.985)                 # up and out, not into the ground
			var sp := rng.randf_range(260.0, 720.0)
			_sparks.append([Vector2(0, rng.randf_range(-6, 6)), Vector2.from_angle(a) * sp, rng.randf_range(2.0, 4.6), rng.randf_range(0.6, 1.4)])
		for i in 9:
			var x := rng.randf_range(-RADIUS * 0.8, RADIUS * 0.8)
			_smoke.append([Vector2(x, GROUND - 20.0), Vector2(rng.randf_range(-14, 14), rng.randf_range(-70, -40)), rng.randf_range(18, 34), rng.randf_range(0.35, 0.8)])
		for i in 9:
			_cracks.append([rng.randf_range(-1.0, 1.0), rng.randf_range(0.35, 0.95), rng.randf_range(-0.3, 0.3)])

	func light() -> Vector4:
		var grow := clampf(t / 0.18, 0.0, 1.0)
		var fade := 1.0 - clampf((t - 0.35) / 0.9, 0.0, 1.0)
		return Vector4(global_position.x, global_position.y, (120.0 + RADIUS * 1.25 * grow) * fade, 1.0)

	func light_strength() -> float:
		return 1.0 if t < 0.7 else 0.0

	func _process(delta: float) -> void:
		t += delta
		if t > LIFE:
			queue_free()
			return
		for s in _sparks:
			if float(s[3]) <= 0.0:
				continue
			s[1] = (s[1] as Vector2) * (1.0 - 1.6 * delta) + Vector2(0, 900.0 * delta)
			s[0] = (s[0] as Vector2) + (s[1] as Vector2) * delta
			s[3] = float(s[3]) - delta
			if (s[0] as Vector2).y > GROUND:                                      # hit the ground: out
				s[3] = 0.0
		for m in _smoke:
			if t > float(m[3]):
				m[0] = (m[0] as Vector2) + (m[1] as Vector2) * delta
				m[2] = float(m[2]) + 26.0 * delta
		if LevelBase.near_view(self):
			queue_redraw()

	## One Batch a frame: the whole burst in one draw call.
	func _draw() -> void:
		var bt := Batch.new()
		var grow := 1.0 - pow(1.0 - clampf(t / 0.25, 0.0, 1.0), 3.0)
		var fade := 1.0 - clampf((t - 0.3) / 0.9, 0.0, 1.0)
		var r := RADIUS * grow
		_scorch(bt)
		_smoke_puffs(bt)
		if fade > 0.0:
			# the dome of fire in layers: ember red outside, flame, a white-hot heart
			_dome(bt, r, Color(Pal.EMBER, 0.20 * fade))
			_dome(bt, r * 0.82, Color(Pal.FLAME, 0.22 * fade))
			_dome(bt, r * 0.5, Color(Pal.FLAME_CORE, 0.28 * fade))
			_dome(bt, r * 0.22 * (1.0 + 0.3 * sin(t * 30.0)), Color(1, 1, 0.92, 0.5 * fade))
			# tongues licking outward from its rim, each flickering on its own
			for i in 30:
				var a := TAU * i / 30.0 + t * 0.7
				var d := Vector2.from_angle(a)
				var base := d * r * 0.88
				if base.y > GROUND - 6.0:
					continue
				var n := Vector2(-d.y, d.x)
				var len := maxf((40.0 + 26.0 * sin(i * 2.3 + t * 22.0)) * fade, 4.0)
				var curl := n * sin(t * 14.0 + i) * 8.0
				bt.tri(base + n * 12.0, base + d * len + curl, base - n * 12.0, Color(Pal.EMBER_GLOW, 0.85 * fade))
				bt.tri(base + n * 7.0, base + d * len * 0.7 + curl * 0.7, base - n * 7.0, Color(Pal.FLAME, fade))
				bt.tri(base + n * 3.0, base + d * len * 0.4 + curl * 0.4, base - n * 3.0, Color(Pal.FLAME_CORE, fade))
			# a wall of flame running out along the ground under it
			for i in 16:
				var gx := lerpf(-r, r, i / 15.0)
				var h := (30.0 + 26.0 * sin(i * 1.9 + t * 18.0)) * fade * (1.0 - absf(gx) / maxf(r, 1.0) * 0.45)
				var sw := sin(t * 9.0 + i) * 5.0
				var b0 := Vector2(gx, GROUND - 2.0)
				bt.tri(b0 + Vector2(-11, 0), b0 + Vector2(sw, -maxf(h, 8.0)), b0 + Vector2(11, 0), Color(Pal.EMBER_GLOW, 0.85 * fade))
				bt.tri(b0 + Vector2(-6, 0), b0 + Vector2(sw * 0.6, -maxf(h, 8.0) * 0.62), b0 + Vector2(6, 0), Color(Pal.FLAME_CORE, 0.9 * fade))
		# the SHOCKWAVE: a thin bright ring racing out ahead of the fire
		var sk := clampf(t / 0.42, 0.0, 1.0)
		if sk < 1.0:
			var sr := RADIUS * 1.55 * (1.0 - pow(1.0 - sk, 2.0))
			var sa := 1.0 - sk
			_ring(bt, sr, 9.0 * sa + 2.0, Color(1.0, 0.75, 0.4, 0.35 * sa))
			_ring(bt, sr, 3.0, Color(1, 1, 0.95, 0.8 * sa))
		# sparks: streaks along their flight
		for s in _sparks:
			var life: float = s[3]
			if life <= 0.0:
				continue
			var p: Vector2 = s[0]
			var v: Vector2 = s[1]
			var k := clampf(life / 0.5, 0.0, 1.0)
			var col := Color(1.0, 0.9, 0.5, k) if life > 0.4 else Color(Pal.EMBER_GLOW, k)
			bt.line(p, p - v * 0.045, col, float(s[2]) + 1.0)
		# the FLASH: white-hot, gone in a blink
		if t < 0.16:
			var fk := 1.0 - t / 0.16
			bt.circle(Vector2.ZERO, 60.0 + 140.0 * (1.0 - fk), Color(1, 1, 0.9, 0.55 * fk), 24)
			bt.circle(Vector2.ZERO, 30.0 + 40.0 * (1.0 - fk), Color(1, 1, 1, 0.9 * fk), 18)
		bt.draw(self)

	## Burnt ground under the burst: a dark patch with glowing cracks, cooling.
	func _scorch(bt: Batch) -> void:
		var k := clampf(t / 0.3, 0.0, 1.0) * (1.0 - clampf((t - 1.4) / 1.2, 0.0, 1.0))
		if k <= 0.0:
			return
		bt.ellipse(Vector2(0, GROUND), RADIUS * 0.85, 12.0, Color(0.08, 0.04, 0.02, 0.55 * k))
		bt.ellipse(Vector2(0, GROUND), RADIUS * 0.5, 7.0, Color(0.05, 0.02, 0.01, 0.6 * k))
		var heat := 1.0 - clampf((t - 0.5) / 1.6, 0.0, 1.0)            # the cracks cool: yellow, red, out
		for c in _cracks:
			var x0 := float(c[0]) * RADIUS * 0.2
			var x1 := x0 + signf(float(c[0]) + 0.01) * float(c[1]) * RADIUS * 0.7
			var mid := Vector2((x0 + x1) * 0.5, GROUND + float(c[2]) * 8.0)
			var col := Color(1.0, 0.55 + 0.4 * heat, 0.2, k * heat)
			bt.line(Vector2(x0, GROUND), mid, col, 2.0)
			bt.line(mid, Vector2(x1, GROUND + float(c[2]) * 3.0), col, 1.5)

	## Smoke rolling up once the flames die down.
	func _smoke_puffs(bt: Batch) -> void:
		for m in _smoke:
			var age := t - float(m[3])
			if age <= 0.0:
				continue
			var a := clampf(age / 0.4, 0.0, 1.0) * (1.0 - clampf((age - 0.6) / 1.2, 0.0, 1.0))
			if a <= 0.0:
				continue
			var pos: Vector2 = m[0]
			var rr: float = m[2]
			bt.circle(pos, rr * 1.2, Color(0.22, 0.2, 0.2, 0.45 * a), 14)
			bt.circle(pos + Vector2(-rr * 0.3, -rr * 0.3), rr * 0.6, Color(0.35, 0.32, 0.3, 0.25 * a), 12)

	## A ring, as quads round it (above the ground line only).
	func _ring(bt: Batch, r: float, w: float, col: Color) -> void:
		if r < 4.0:
			return
		var n := 40
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var p0 := Vector2.from_angle(a0) * r
			var p1 := Vector2.from_angle(a1) * r
			if p0.y > GROUND and p1.y > GROUND:
				continue
			var q0 := Vector2.from_angle(a0) * (r - w)
			var q1 := Vector2.from_angle(a1) * (r - w)
			bt.quad(q0, p0, p1, q1, col)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		# the sparks shine through the dark (every 2nd one: plenty, and cheaper)
		for i in range(0, _sparks.size(), 2):
			var s: Array = _sparks[i]
			if float(s[3]) > 0.0:
				g.draw_circle(global_position + (s[0] as Vector2), float(s[2]) * 1.6, Color(1.0, 0.7, 0.3, 0.5 * clampf(float(s[3]) / 0.5, 0.0, 1.0)))
		var fade := 1.0 - clampf((t - 0.3) / 0.9, 0.0, 1.0)
		if fade <= 0.0:
			return
		var r := RADIUS * (1.0 - pow(1.0 - clampf(t / 0.25, 0.0, 1.0), 3.0))
		g.draw_circle(global_position, r * 0.9, Color(1.0, 0.45, 0.15, 0.16 * fade))
		g.draw_circle(global_position, r * 0.45, Color(1.0, 0.75, 0.35, 0.22 * fade))

	## The part of a circle above the ground line: a fan of triangles from the
	## middle (tri, not poly: it is drawn every frame).
	func _dome(bt: Batch, r: float, col: Color) -> void:
		if r < 2.0:
			return
		var a0 := 0.0
		var a1 := TAU
		if r > GROUND:
			var c := asin(GROUND / r)
			a0 = PI - c
			a1 = TAU + c
		var n := 28
		var prev := Vector2.from_angle(a0) * r
		var mid := Vector2(0, minf(GROUND, r) * 0.5 - r * 0.25)
		for i in range(1, n + 1):
			var p := Vector2.from_angle(lerpf(a0, a1, float(i) / n)) * r
			bt.tri(mid, prev, p, col)
			prev = p


## ================================================================ THE LONG DARK
class FallenGiant extends Node2D:
	## A giant tree that fell across the gorge long ago: a huge mossy trunk
	## spanning it high up, its roots torn out of one cliff and its crown lost
	## on the other, with old vines hanging down from it.
	## A METEOR STOMP on top of it: the whole tree shudders (and things shake loose).
	signal stomped_on(level: int, at: Vector2)
	var w := 1500.0
	var _quake := 0.0
	var _body: StaticBody2D
	var _base := Vector2.ZERO

	func _ready() -> void:
		z_index = -1
		_base = position
		add_to_group("stomp_spot")
		# he can walk along the top of it (one-way: jump up through it from a vine)
		_body = StaticBody2D.new()
		var body := _body
		body.collision_layer = 1
		body.collision_mask = 0
		add_child(body)
		for i in 24:
			var cs := CollisionShape2D.new()
			var seg := SegmentShape2D.new()
			seg.a = _top(i / 24.0)
			seg.b = _top((i + 1) / 24.0)
			cs.shape = seg
			cs.one_way_collision = true
			body.add_child(cs)

	## The top of the trunk at k (0 = the root end, 1 = the crown end), where he walks.
	func _top(k: float) -> Vector2:
		return Vector2(k * w, sin(k * PI) * 18.0 - lerpf(34.0, 20.0, k) + 3.0)

	## Called by every stomp's Blast (group "stomp_spot"): only one that lands ON the trunk counts.
	func stomped(level: int, at: Vector2) -> void:
		var lx := at.x - _base.x
		if lx < 0.0 or lx > w:
			return
		var top := _base.y + _top(lx / w).y
		if absf(at.y - top) > 40.0:
			return
		_quake = 0.9 if level == 1 else 1.4
		# bark and leaves shaken off it
		for i in 4 + 3 * level:
			var dust := Critter.DeathPop.new()
			dust.dust = true
			dust.position = Vector2(at.x + randf_range(-260, 260), top + randf_range(0, 30))
			get_parent().add_child.call_deferred(dust)
		stomped_on.emit(level, at)

	func _process(delta: float) -> void:
		if _quake > 0.0:
			_quake = maxf(_quake - delta, 0.0)
			position = _base + Vector2(sin(_quake * 70.0) * 2.0, sin(_quake * 55.0) * 4.0) * minf(_quake, 1.0)
			_body.position = _base - position       # only the picture shakes: what he stands on stays put

	func _draw() -> void:
		var b := Batch.new()
		# the trunk, thick at the root end and tapering, a gentle sag
		var top := PackedVector2Array()
		var bot := PackedVector2Array()
		for i in 25:
			var k := i / 24.0
			var x := k * w
			var sag := sin(k * PI) * 18.0
			var r := lerpf(34.0, 20.0, k)
			top.append(Vector2(x, sag - r))
			bot.append(Vector2(x, sag + r))
		var trunk := PackedVector2Array(top)
		for i in range(bot.size() - 1, -1, -1):
			trunk.append(bot[i])
		b.poly(trunk, Pal.BARK_DARK)
		var lit := PackedVector2Array()
		for i in 25:
			lit.append(top[i] + Vector2(0, 5))
		for i in range(24, -1, -1):
			lit.append((top[i] + bot[i]) * 0.5 + Vector2(0, 4))
		b.poly(lit, Pal.BARK)
		# bark lines, and moss along the top
		for i in 14:
			var x := 40.0 + i * (w - 80.0) / 13.0
			var k := x / w
			var sag := sin(k * PI) * 18.0
			b.line(Vector2(x, sag - 14.0), Vector2(x + 30.0, sag - 10.0), Pal.BARK_DARK, 2.5)
			b.circle(Vector2(x + 12.0, sag - lerpf(34.0, 20.0, k) + 2.0), 7.0, Pal.CANOPY.lightened(0.1), 10)
		# the torn roots at the near end, reaching down the cliff
		for i in 6:
			var a := PI * 0.55 + i * 0.22
			var pts := PackedVector2Array([Vector2(0, 0)])
			for j in 5:
				pts.append(Vector2.from_angle(a + sin(j * 1.3 + i) * 0.2) * (18.0 + j * 16.0) + Vector2(-6, 0))
			b.polyline(pts, Pal.BARK_DARK, 6.0 - i * 0.5)
		b.circle(Vector2(0, 0), 36.0, Pal.BARK_DARK, 18)
		b.circle(Vector2(0, 0), 26.0, Pal.BARK, 16)
		for r in [8.0, 15.0, 21.0]:
			b.arc(Vector2(0, 0), r, 0.0, TAU, 16, Pal.BARK_DARK, 1.5)
		# broken branches at the far end
		b.line(Vector2(w - 10.0, -10.0), Vector2(w + 70.0, -60.0), Pal.BARK_DARK, 9.0)
		b.line(Vector2(w + 30.0, -30.0), Vector2(w + 60.0, -90.0), Pal.BARK_DARK, 6.0)
		b.draw(self)


class RollingBoulder extends Node2D:
	## The Boulder Run's boulder: a huge ball of granite resting on a crumbling
	## ledge. Once it breaks loose it drops onto the path and rolls after him,
	## faster and faster (never quite as fast as he can run flat out), smashing
	## the fallen logs, rumbling the ground — until it plunges into the ravine.
	signal crashed
	const R := 64.0
	const TOP_SPEED := 285.0
	var state := "wait"            ## wait -> drop -> roll -> plunge -> gone
	var vel := Vector2.ZERO
	var spin := 0.0
	var home := Vector2.ZERO
	var road_y := 600.0            ## the path it rolls on
	var ravine_x := 0.0            ## where the path ends and it falls
	var _dust_in := 0.0

	func _ready() -> void:
		home = position
		z_index = 2

	func reset() -> void:
		state = "wait"
		position = home
		vel = Vector2.ZERO
		visible = true
		queue_redraw()

	func release() -> void:
		if state == "wait":
			state = "drop"
			vel = Vector2(90.0, -120.0)

	func _process(delta: float) -> void:
		match state:
			"drop":
				vel.y += 1500.0 * delta
				position += vel * delta
				spin += vel.x * delta / R
				if position.y >= road_y - R:
					position.y = road_y - R
					vel = Vector2(120.0, 0.0)
					state = "roll"
					_puff(1.6)
			"roll":
				vel.x = move_toward(vel.x, TOP_SPEED, 180.0 * delta)
				position.x += vel.x * delta
				spin += vel.x * delta / R
				# a little bounce as it goes, bigger over the joins in the path
				position.y = road_y - R - absf(sin(position.x / 90.0)) * 4.0
				_dust_in -= delta
				if _dust_in <= 0.0:
					_dust_in = 0.07
					_puff(0.8)
				if position.x > ravine_x + R * 0.6:
					state = "plunge"
					vel = Vector2(vel.x * 0.6, -80.0)
			"plunge":
				vel.y += 1500.0 * delta
				position += vel * delta
				spin += vel.x * delta / R
				if position.y > road_y + 420.0:
					state = "gone"
					visible = false
					crashed.emit()
		if state != "wait" and state != "gone":
			queue_redraw()

	func _puff(amount: float) -> void:
		var d := Critter.DeathPop.new()
		d.dust = true
		d.big = amount > 1.0
		d.position = Vector2(position.x - R * 0.6, road_y)
		get_parent().add_child(d)

	func _draw() -> void:
		var b := Batch.new()
		b.circle(Vector2.ZERO, R + 3.0, Color("3e3a35"), 28)
		b.circle(Vector2.ZERO, R, Color("7b7064"), 28)
		b.set_xf(Transform2D(spin, Vector2.ZERO))
		# facets and a lit side, cracks and a patch of moss, all turning with it
		b.poly(PackedVector2Array([Vector2(-40, -44), Vector2(8, -58), Vector2(40, -34), Vector2(10, -14), Vector2(-26, -18)]), Color("8d8275"))
		b.poly(PackedVector2Array([Vector2(12, 8), Vector2(50, 0), Vector2(44, 34), Vector2(10, 44)]), Color("6a6056"))
		b.poly(PackedVector2Array([Vector2(-54, 4), Vector2(-24, 14), Vector2(-30, 46), Vector2(-50, 30)]), Color("857a6e"))
		b.polyline(PackedVector2Array([Vector2(-10, -60), Vector2(-4, -30), Vector2(-18, -4), Vector2(-8, 24)]), Color("4a443e"), 3.0)
		b.polyline(PackedVector2Array([Vector2(26, 20), Vector2(40, 48)]), Color("4a443e"), 2.5)
		b.circle(Vector2(-30, -30), 12.0, Color("5f7a45"), 12)
		b.circle(Vector2(-20, -36), 8.0, Color("6f8c52"), 10)
		b.set_xf(Transform2D.IDENTITY)
		b.arc(Vector2.ZERO, R - 6.0, -2.6, -1.2, 10, Color(1, 1, 1, 0.12), 6.0)
		b.draw(self)


class FallenLog extends StaticBody2D:
	## A fallen log across the path: he has to jump it. The boulder smashes it
	## to splinters.
	var smashed := false
	var _cs: CollisionShape2D
	var _t := -1.0

	func _ready() -> void:
		add_to_group("unsafe_ground")   # it can break, burn or fall: never a place to set him down
		collision_layer = 1
		collision_mask = 0
		_cs = CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(84, 44)
		_cs.shape = sh
		_cs.position = Vector2(0, -22)
		add_child(_cs)

	func smash() -> void:
		if smashed:
			return
		smashed = true
		_t = 0.0
		_cs.set_deferred("disabled", true)

	func restore() -> void:
		smashed = false
		_t = -1.0
		_cs.set_deferred("disabled", false)
		queue_redraw()

	func _process(delta: float) -> void:
		if _t >= 0.0 and _t < 1.0:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		if not smashed:
			b.quad(Vector2(-42, 0), Vector2(-40, -42), Vector2(40, -44), Vector2(42, 0), Pal.BARK)
			b.line(Vector2(-36, -30), Vector2(36, -31), Pal.BARK_DARK, 3.0)
			b.line(Vector2(-36, -14), Vector2(36, -13), Pal.BARK_DARK, 3.0)
			b.circle(Vector2(40, -22), 21.0, Pal.DEADWOOD, 16)
			for r in [7.0, 13.0, 18.0]:
				b.arc(Vector2(40, -22), r, 0.0, TAU, 14, Pal.BARK_DARK, 1.4)
		elif _t < 1.0:
			# splinters flying
			for i in 9:
				var a := -PI * 0.5 + (i - 4) * 0.3
				var p := Vector2(0, -22) + Vector2.from_angle(a) * _t * 320.0 + Vector2(0, _t * _t * 700.0)
				var tip := p + Vector2.from_angle(a + _t * 9.0) * 14.0
				b.line(p, tip, Color(Pal.BARK, 1.0 - _t), 4.0)
		b.draw(self)


class BoulderLedge extends Node2D:
	## The crumbling ledge the boulder waits on, above the start of the pass.
	func _ready() -> void:
		z_index = -1

	func _draw() -> void:
		var b := Batch.new()
		b.poly(PackedVector2Array([Vector2(-140, 0), Vector2(-120, -60), Vector2(-40, -80), Vector2(70, -70), Vector2(90, -10),
			Vector2(60, 180), Vector2(-150, 180)]), Pal.CRAG_DARK)
		b.poly(PackedVector2Array([Vector2(-120, -60), Vector2(-40, -80), Vector2(70, -70), Vector2(60, -54), Vector2(-100, -46)]), Pal.CRAG)
		for c in [[Vector2(-60, -20), Vector2(-40, 30)], [Vector2(20, -40), Vector2(34, 10)], [Vector2(-100, 20), Vector2(-80, 70)]]:
			b.line(c[0], c[1], Color("2f2b27"), 2.5)
		b.draw(self)


class FireWave extends Node2D:
	## The Firestone Hammer's slam: two walls of flame roll out along the ground
	## from where it struck. Everything on that ground they pass through burns
	## (once); cold bonfires and stone bowls they reach catch; webs go up; a
	## charging sabre-tooth is tripped flat.
	const SPEED := 760.0
	const REACH := 400.0
	const DAMAGE := 6
	var player: CaveMan
	var t := 0.0
	var _hit := {}

	func _ready() -> void:
		z_index = 5
		add_to_group("light")
		# the strike itself: a flash and a burst where the hammer hit
		var pop := Critter.DeathPop.new()
		pop.big = true
		pop.position = global_position + Vector2(0, -10)
		get_parent().add_child.call_deferred(pop)

	func light() -> Vector4:
		var fade := 1.0 - clampf((t - REACH / SPEED) / 0.5, 0.0, 1.0)
		return Vector4(global_position.x, global_position.y - 40.0, (180.0 + minf(t * SPEED, REACH) * 0.8) * fade, 1.0)

	func light_strength() -> float:
		return 1.0 if t < REACH / SPEED else 0.0

	func _process(delta: float) -> void:
		t += delta
		var reach := minf(t * SPEED, REACH)
		if t * SPEED <= REACH + 20.0:
			for side in [-1.0, 1.0]:
				_burn_at(global_position.x + float(side) * reach)
		if t > REACH / SPEED + 0.6:
			queue_free()
			return
		_ember_in -= delta
		if _ember_in <= 0.0 and t * SPEED <= REACH:
			_ember_in = 0.07
			for side in [-1.0, 1.0]:
				FX.burst(get_parent(), global_position + Vector2(float(side) * reach, -20.0), "embers", float(side))
		queue_redraw()

	var _ember_in := 0.0

	func _burn_at(fx: float) -> void:
		var y := global_position.y
		for c in get_tree().get_nodes_in_group("critters"):
			var cr := c as Critter
			if cr == null or cr.dying > 0.0 or _hit.has(cr.get_instance_id()):
				continue
			if absf(cr.global_position.x - fx) < 46.0 and absf(cr.global_position.y - y) < 80.0:
				_hit[cr.get_instance_id()] = true
				if cr.has_method("fire_wave"):
					cr.fire_wave(DAMAGE, global_position)
				else:
					cr.burned(DAMAGE, global_position)
		for m in get_tree().get_nodes_in_group("monkeys"):
			if absf((m as Node2D).global_position.x - fx) < 46.0 and absf((m as Node2D).global_position.y - y) < 80.0:
				m.burn()
		for b in get_tree().get_nodes_in_group("bonfire"):
			if absf((b as Node2D).global_position.x - fx) < 50.0 and absf((b as Node2D).global_position.y - y) < 90.0:
				b.kindle()
		for w in get_tree().get_nodes_in_group("webs"):
			if absf((w as Node2D).global_position.x - fx) < 40.0 and absf((w as Node2D).global_position.y - y) < 60.0:
				w.burn()
		for r in get_tree().get_nodes_in_group("cracked"):
			if absf((r as Node2D).global_position.x - fx) < 60.0 and absf((r as Node2D).global_position.y - y) < 60.0 and not _hit.has(r.get_instance_id()):
				_hit[r.get_instance_id()] = true
				r.take_hit(DAMAGE, 1 if (r as Node2D).global_position.x > global_position.x else -1)

	func _draw() -> void:
		var reach := minf(t * SPEED, REACH)
		var fade := 1.0 - clampf((t - REACH / SPEED) / 0.6, 0.0, 1.0)
		var b := Batch.new()
		# a scorch along the ground it has passed over
		b.rect(Rect2(-reach, -4, reach * 2.0, 5), Color(Pal.EMBER_GLOW, 0.35 * fade))
		for side in [-1.0, 1.0]:
			var s: float = side
			var fx := s * reach
			# the wall at the front, tall and bright
			for k in 5:
				var x := fx - s * k * 9.0
				var h := (70.0 - k * 10.0 + sin(t * 30.0 + k) * 8.0) * fade
				if h > 8.0:
					b.poly(NightWoods.flame_pts(Vector2(x, -2), 12.0, h, s * 6.0), Color(Pal.EMBER_GLOW, 0.9 * fade))
					b.poly(NightWoods.flame_pts(Vector2(x, -2), 7.0, h * 0.7, s * 4.0), Color(Pal.FLAME, fade))
			# and a trail of low flames dying down behind it
			var n := int(reach / 32.0)
			for i in n:
				var x := s * (i * 32.0 + 16.0)
				var age := (reach - absf(x)) / REACH
				var h := (34.0 * (1.0 - age) + sin(t * 20.0 + i) * 5.0) * fade
				if h > 6.0:
					b.poly(NightWoods.flame_pts(Vector2(x, -2), 8.0, h, sin(t * 9.0 + i) * 3.0), Color(Pal.EMBER_GLOW, 0.75 * fade * (1.0 - age)))
		b.draw(self)


class CrackedRock extends StaticBody2D:
	## A boulder split through with old cracks, blocking the way. Hit it hard
	## enough and it bursts: the hammer takes two blows (or one slam), the club
	## three. The cracks glow a little more with every hit.
	signal broken
	var hp := 9
	var _shake := 0.0
	var _gone := 0.0
	var _cs: CollisionShape2D
	var _hitbox: Area2D

	func _ready() -> void:
		add_to_group("unsafe_ground")   # it can break, burn or fall: never a place to set him down
		collision_layer = 1
		collision_mask = 0
		add_to_group("cracked")
		_cs = CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(90, 150)
		_cs.shape = sh
		_cs.position = Vector2(0, -75)
		add_child(_cs)
		# his swing looks for areas on the creature layer: give it one
		_hitbox = RockHitbox.new()
		(_hitbox as RockHitbox).rock = self
		_hitbox.collision_layer = 4
		_hitbox.collision_mask = 0
		_hitbox.monitoring = false
		var hcs := CollisionShape2D.new()
		var hsh := RectangleShape2D.new()
		hsh.size = Vector2(110, 150)
		hcs.shape = hsh
		hcs.position = Vector2(0, -75)
		_hitbox.add_child(hcs)
		add_child(_hitbox)

	func take_hit(dmg: int, _from_dir: int) -> void:
		if hp <= 0:
			return
		hp -= dmg
		_shake = 0.25
		var spark := Critter.DeathPop.new()
		spark.dust = true
		spark.position = global_position + Vector2(0, -60)
		get_parent().add_child(spark)
		if hp <= 0:
			_gone = 0.001
			_cs.set_deferred("disabled", true)
			_hitbox.set_deferred("monitorable", false)
			var burst := Critter.DeathPop.new()
			burst.big = true
			burst.position = global_position + Vector2(0, -70)
			get_parent().add_child(burst)
			broken.emit()

	func _process(delta: float) -> void:
		_shake = maxf(_shake - delta, 0.0)
		if _gone > 0.0:
			_gone += delta
			if _gone > 0.8:
				queue_free()
		queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		if _gone > 0.0:
			# flying chunks
			for i in 8:
				var a := -PI * 0.5 + (i - 3.5) * 0.35
				var p := Vector2(0, -70) + Vector2.from_angle(a) * _gone * 420.0 + Vector2(0, _gone * _gone * 900.0)
				b.poly(PackedVector2Array([p + Vector2(-10, -6), p + Vector2(8, -9), p + Vector2(11, 6), p + Vector2(-7, 9)]), Color(Pal.CRAG, 1.0 - _gone))
			b.draw(self)
			return
		var o := Vector2(sin(_shake * 90.0) * 4.0 * (_shake / 0.25), 0)
		var body := PackedVector2Array([o + Vector2(-48, 0), o + Vector2(-52, -70), o + Vector2(-34, -140), o + Vector2(6, -154),
			o + Vector2(42, -132), o + Vector2(50, -60), o + Vector2(46, 0)])
		b.poly(body, Pal.CRAG_DARK)
		var lit := PackedVector2Array()
		for p in body:
			lit.append(Vector2(p.x * 0.85 - 4.0, p.y * 0.95))
		b.poly(lit, Pal.CRAG)
		# the cracks, glowing hotter the closer it is to bursting
		var heat := clampf(1.0 - hp / 9.0, 0.0, 1.0)
		var crack := Color(Pal.CHARCOAL).lerp(Pal.EMBER_GLOW, heat)
		b.polyline(PackedVector2Array([o + Vector2(-6, -150), o + Vector2(4, -110), o + Vector2(-10, -70), o + Vector2(6, -30), o + Vector2(0, 0)]), crack, 3.0)
		b.polyline(PackedVector2Array([o + Vector2(4, -110), o + Vector2(30, -96), o + Vector2(44, -70)]), crack, 2.5)
		b.polyline(PackedVector2Array([o + Vector2(-10, -70), o + Vector2(-36, -52)]), crack, 2.5)
		b.draw(self)


## The part of a cracked rock his swing (and his thrown rocks) can find.
class RockHitbox extends Area2D:
	var rock: Node

	func take_hit(dmg: int, from_dir: int) -> void:
		rock.take_hit(dmg, from_dir)


class PalisadeGate extends StaticBody2D:
	## A wall of old sharpened stakes across the path to Old Scar's clearing,
	## put up long ago to keep him in. It burns when the Three Fires are lit.
	var burning := -1.0
	var _cs: CollisionShape2D

	func _ready() -> void:
		add_to_group("unsafe_ground")   # it can break, burn or fall: never a place to set him down
		collision_layer = 1
		collision_mask = 0
		_cs = CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(40, 260)
		_cs.shape = sh
		_cs.position = Vector2(0, -130)
		add_child(_cs)

	func burn() -> void:
		if burning >= 0.0:
			return
		burning = 0.0
		add_to_group("light")

	func light() -> Vector4:
		if burning < 0.0 or burning > 2.2:
			return Vector4.ZERO
		return Vector4(global_position.x, global_position.y - 100.0, 260.0 * (1.0 - clampf((burning - 1.4) / 0.8, 0.0, 1.0)), 1.0)

	func light_strength() -> float:
		return 0.0

	func _process(delta: float) -> void:
		if burning >= 0.0:
			burning += delta
			if burning > 1.2 and not _cs.disabled:
				_cs.set_deferred("disabled", true)
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var char_k := clampf(burning / 1.2, 0.0, 1.0) if burning >= 0.0 else 0.0
		for i in 5:
			var x := -24.0 + i * 12.0
			var h := 240.0 - (i % 2) * 22.0
			if burning > 1.2:
				h = 30.0 + (i % 3) * 12.0          # burnt down to stumps
			var wood := Pal.TRUNK.lerp(Pal.CHARCOAL, char_k)
			b.poly(PackedVector2Array([Vector2(x - 6, 0), Vector2(x - 6, -h), Vector2(x, -h - 16.0), Vector2(x + 6, -h), Vector2(x + 6, 0)]), wood)
		if burning < 0.0:
			for y in [-60.0, -170.0]:
				b.line(Vector2(-32, y), Vector2(32, y + 6.0), Pal.VINE, 5.0)
		if burning >= 0.0 and burning < 2.0:
			for i in 6:
				var x := -26.0 + i * 11.0
				var fh := (60.0 + sin(burning * 20.0 + i) * 16.0) * (1.0 - clampf((burning - 1.4) / 0.6, 0.0, 1.0))
				if fh > 8.0:
					b.poly(NightWoods.flame_pts(Vector2(x, -40.0 - (i % 3) * 60.0), 12.0, fh, sin(burning * 8.0 + i) * 6.0), Color(Pal.EMBER_GLOW, 0.9))
					b.poly(NightWoods.flame_pts(Vector2(x, -40.0 - (i % 3) * 60.0), 7.0, fh * 0.65, 0.0), Pal.FLAME)
		b.draw(self)


class ToolmakerCamp extends Node2D:
	## The Toolmaker's home: a hollow under an overhang of rock at the edge of
	## the Long Dark. His forge hearth and anvil stone, his tools hung on the
	## rock wall, hides drying on a line, and his heap of trade shells.
	func _ready() -> void:
		z_index = -1

	func _draw() -> void:
		var b := Batch.new()
		# the back wall of the hollow, and the overhang above
		b.poly(PackedVector2Array([Vector2(-220, 0), Vector2(-230, -210), Vector2(-150, -300), Vector2(260, -320), Vector2(330, -250),
			Vector2(320, 0)]), Pal.CAVE_BACK.lightened(0.1))
		b.poly(PackedVector2Array([Vector2(-250, -230), Vector2(-120, -300), Vector2(280, -330), Vector2(360, -260), Vector2(300, -236),
			Vector2(80, -250), Vector2(-160, -222)]), Pal.CRAG_DARK)
		b.polyline(PackedVector2Array([Vector2(-250, -230), Vector2(-120, -300), Vector2(280, -330), Vector2(360, -260)]), Color(Pal.MOONLIT, 0.35), 3.0)
		# tools on the wall: a spear, an axe, a stone hammer, a digging stick
		b.line(Vector2(-120, -60), Vector2(-100, -210), Pal.TRUNK, 5.0)
		b.poly(PackedVector2Array([Vector2(-102, -210), Vector2(-92, -236), Vector2(-94, -206)]), Pal.CRAG_LIGHT)
		b.line(Vector2(-60, -90), Vector2(-60, -190), Pal.TRUNK, 5.0)
		b.poly(PackedVector2Array([Vector2(-62, -190), Vector2(-34, -196), Vector2(-30, -170), Vector2(-62, -174)]), Pal.CRAG)
		b.line(Vector2(-10, -100), Vector2(-10, -185), Pal.TRUNK, 5.0)
		b.rect(Rect2(-26, -198, 32, 18), Pal.CRAG_DARK.lightened(0.15))
		b.line(Vector2(30, -80), Vector2(44, -200), Pal.TRUNK_DARK, 4.0)
		# a line of drying hides
		b.line(Vector2(90, -210), Vector2(250, -226), Pal.VINE, 2.5)
		for i in 3:
			var x := 110.0 + i * 50.0
			var y := -210.0 - i * 5.0
			b.poly(PackedVector2Array([Vector2(x - 18, y), Vector2(x + 18, y - 2), Vector2(x + 22, y + 44), Vector2(x, y + 54), Vector2(x - 20, y + 42)]),
				Pal.HIDE if i % 2 == 0 else Pal.WOLF)
		# the heap of trade shells
		for i in 14:
			var p := Vector2(210.0 + (i % 5) * 12.0 - (i / 5) * 6.0, -8.0 - (i / 5) * 10.0)
			b.circle(p, 7.0, Color("f2dcc0") if i % 2 == 0 else Color("e8c79c"), 8)
		# a sleeping mat
		b.rect(Rect2(-200, -10, 90, 10), Pal.HIDE_DARK)
		b.draw(self)


class Vine extends Node2D:
	## A vine hanging over a pit. Fly into its end and he grabs on (see
	## CaveMan.grab_vine); left/right pumps the swing; jump lets go and carries
	## the swing's speed. Captain Claw's ropes, in the Stone Age.
	var length := 200.0
	var angle := 0.0
	var held := false
	var t := 0.0
	var _grab: Area2D

	func _ready() -> void:
		_grab = Area2D.new()
		_grab.collision_layer = 0
		_grab.collision_mask = 2
		var cs := CollisionShape2D.new()
		# generous: anywhere around the lower end of the vine catches him
		var c := CircleShape2D.new()
		c.radius = 50.0
		cs.shape = c
		cs.position = Vector2(0, -20)
		_grab.add_child(cs)
		add_child(_grab)
		t = randf() * 5.0

	func let_go() -> void:
		held = false

	func _physics_process(delta: float) -> void:
		t += delta
		if not held:
			# settle back to a gentle sway after he lets go
			angle = move_toward(angle, sin(t * 1.1) * 0.05, delta * 1.2)
			for b in _grab.get_overlapping_bodies():
				if b is CaveMan and (b as CaveMan).grab_vine(self):
					held = true
		_grab.position = Vector2(sin(angle), cos(angle)) * length
		if NightWoods.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var bt := Batch.new()
		# the bough it hangs from
		bt.quad(Vector2(-70, -14), Vector2(60, -18), Vector2(64, -4), Vector2(-66, 4), Pal.BARK_DARK)
		bt.line(Vector2(-60, -14), Vector2(56, -16), Color(Pal.MOONLIT, 0.25), 2.0)
		var end := Vector2(sin(angle), cos(angle)) * length
		var pts := PackedVector2Array()
		for i in 13:
			var k := i / 12.0
			var sag := sin(k * PI) * 6.0 * (1.0 - absf(angle))
			pts.append(end * k + Vector2(sag, 0))
		bt.polyline(pts, Pal.VINE.darkened(0.2), 5.0)
		bt.polyline(pts, Pal.VINE, 3.0)
		for i in range(2, 12, 3):
			var p: Vector2 = pts[i]
			bt.poly(PackedVector2Array([p, p + Vector2(10, -4), p + Vector2(14, 2), p + Vector2(4, 4)]), Pal.CANOPY.lightened(0.15))
		bt.circle(end, 6.0, Pal.VINE.darkened(0.3), 10)
		bt.draw(self)


class MoonPuff extends World.SpringBush:
	## A night bloom that grows on the mountain's steps: fat, springy puffballs
	## speckled with faint glowing spots. Land on one and it squashes and flings
	## him high into the air, and a burst of glowing spores goes up with him.
	var _spores := 0.0

	func _ready() -> void:
		super._ready()
		launch = -1100.0
		add_to_group("glow")
		sprung.connect(func() -> void: _spores = 1.0)

	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		_spores = maxf(_spores - delta * 1.1, 0.0)

	func _draw() -> void:
		var c := 1.0 - squash * 0.5
		var sq := Vector2(1.0 + squash * 0.4, c)
		var b := Batch.new()
		# leaves at the foot
		for s in [-1.0, 1.0]:
			b.poly(PackedVector2Array([Vector2(0, 0), Vector2(s * 34.0, -6.0), Vector2(s * 40.0, 2.0), Vector2(s * 20.0, 4.0)]), Pal.CANOPY.lightened(0.1))
		# three puffballs on short stalks: two behind, one big in front
		var puffs := [[Vector2(-17, -24), 15.0, 0.25], [Vector2(18, -26), 16.0, 0.25], [Vector2(0, -22), 21.0, 0.0]]
		for pf in puffs:
			var at: Vector2 = (pf[0] as Vector2) * sq
			var r: float = pf[1]
			var shade: float = pf[2]
			b.line(Vector2(at.x * 0.6, 0), at + Vector2(0, r * 0.6), Color("7d8c6a"), 5.0)
			var body := Color("b9c3ea").darkened(shade)
			var rim := PackedVector2Array()
			for i in 18:
				var a := TAU * i / 18.0
				rim.append(at + Vector2(cos(a) * r * sq.x * 1.1, sin(a) * r * c))
			b.poly(rim, Color("5d6690").darkened(shade))
			var inner := PackedVector2Array()
			for i in 18:
				var a := TAU * i / 18.0
				inner.append(at + Vector2(cos(a) * r * sq.x, sin(a) * r * c * 0.92))
			b.poly(inner, body)
			b.circle(at + Vector2(-r * 0.35, -r * 0.4 * c), r * 0.35, Color("e4e9ff").darkened(shade), 12)
		b.draw(self)

	## The glowing specks, and the spores that go up when it fires.
	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var c := 1.0 - squash * 0.5
		for i in 7:
			var p := global_position + Vector2(-24.0 + i * 8.0, (-30.0 + sin(i * 2.1) * 10.0) * c)
			var on := 0.5 + 0.5 * sin(t * 2.0 + i * 1.3)
			g.draw_circle(p, 2.0, Color("dff3ff", 0.35 + 0.5 * on))
		if _spores > 0.0:
			var k := 1.0 - _spores
			for i in 14:
				var ang := -PI * 0.5 + (i - 6.5) * 0.12
				var p := global_position + Vector2(0, -30) + Vector2.from_angle(ang) * (20.0 + k * 220.0) + Vector2(sin(i * 3.7) * 20.0 * k, 0)
				g.draw_circle(p, 3.0 * _spores + 1.0, Color("e8f6ff", _spores))


class CrumbleRock extends StaticBody2D:
	## A slab of rotten rock across a pit: it holds for a moment after he steps
	## on, shakes, and drops. It grows back a few seconds later.
	var w := 80.0
	var player: CaveMan
	var state := "solid"         ## solid shaking falling
	var timer := 0.0
	var drop := 0.0
	var _cs: CollisionShape2D

	func _ready() -> void:
		add_to_group("unsafe_ground")   # it can break, burn or fall: never a place to set him down
		collision_layer = 1
		collision_mask = 0
		_cs = CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(w, 18)
		_cs.shape = sh
		_cs.position = Vector2(w * 0.5, 9)
		add_child(_cs)

	func _physics_process(delta: float) -> void:
		match state:
			"solid":
				if player != null and player.is_on_floor() and absf(player.global_position.y - global_position.y) < 6.0 \
						and player.global_position.x > global_position.x - 10.0 and player.global_position.x < global_position.x + w + 10.0:
					state = "shaking"
					timer = 0.55
			"shaking":
				timer -= delta
				if timer <= 0.0:
					state = "falling"
					timer = 3.5
					drop = 0.0
					_cs.set_deferred("disabled", true)
			"falling":
				timer -= delta
				drop += (200.0 + drop * 3.0) * delta
				if timer <= 0.0:
					state = "solid"
					drop = 0.0
					_cs.set_deferred("disabled", false)
		if state != "solid" or NightWoods.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var o := Vector2(0, drop)
		if state == "shaking":
			o.x = sin(timer * 80.0) * 2.5
		var a := 1.0 if state != "falling" else clampf(1.0 - drop / 400.0, 0.0, 1.0)
		if a <= 0.0:
			return
		var bt := Batch.new()
		bt.poly(PackedVector2Array([o + Vector2(0, 0), o + Vector2(w, 0), o + Vector2(w - 6, 16), o + Vector2(w * 0.6, 24),
			o + Vector2(w * 0.3, 20), o + Vector2(6, 16)]), Color(Pal.CRAG_DARK, a))
		bt.rect(Rect2(o, Vector2(w, 5)), Color(Pal.CRAG, a))
		bt.line(o + Vector2(w * 0.3, 2), o + Vector2(w * 0.45, 14), Color(Pal.CHARCOAL, a), 2.0)
		bt.line(o + Vector2(w * 0.65, 2), o + Vector2(w * 0.55, 12), Color(Pal.CHARCOAL, a), 2.0)
		bt.draw(self)


class FireflySwarm extends Node2D:
	## A drift of fireflies in the Long Dark: a small, moving, cool light to go
	## by when the torch is out. It lights the way but protects nothing.
	var t := 0.0

	func _ready() -> void:
		Sleeper.enrol(self)          # far from the camera it sleeps (common/sleeper.gd)
		t = randf() * 10.0
		add_to_group("light")
		add_to_group("glow")

	func _process(delta: float) -> void:
		t += delta

	func light() -> Vector4:
		var c := global_position + Vector2(sin(t * 0.7) * 24.0, cos(t * 0.9) * 12.0)
		return Vector4(c.x, c.y, 95.0 + 25.0 * sin(t * 1.3), 0.0)

	func light_strength() -> float:
		return 0.0

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var c := global_position + Vector2(sin(t * 0.7) * 24.0, cos(t * 0.9) * 12.0)
		for i in 9:
			var a := t * (0.8 + i * 0.07) + i * 0.7
			var p := c + Vector2(cos(a) * (14.0 + i * 3.0), sin(a * 1.3) * (8.0 + i * 2.0))
			var on := 0.5 + 0.5 * sin(t * 3.0 + i * 1.9)
			g.draw_circle(p, 4.0, Color("d9f07a", 0.15 * on))
			g.draw_circle(p, 1.6, Color("eefaa8", 0.4 + 0.6 * on))


class Watcher extends Node2D:
	## A pair of big eyes in the dark, watching him. They sink back into the
	## trees as he comes near. Old Scar, following.
	var player: CaveMan
	var t := 0.0
	var seen := 1.0

	func _ready() -> void:
		t = randf() * 10.0
		add_to_group("glow")

	func _process(delta: float) -> void:
		t += delta
		if player != null:
			var near := player.global_position.distance_to(global_position) < 360.0
			seen = move_toward(seen, 0.0 if near else 1.0, delta * (2.5 if near else 0.3))

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		if seen <= 0.02:
			return
		var blink := 0.15 if fmod(t, 5.0) < 0.15 else 1.0
		var c := global_position + Vector2(sin(t * 0.3) * 10.0, 0)
		for sx in [-18.0, 18.0]:
			var e := c + Vector2(sx, 0)
			g.draw_circle(e, 14.0, Color(Pal.WOLF_EYE, 0.10 * seen))
			g.draw_colored_polygon(PackedVector2Array([e + Vector2(-7, 0), e + Vector2(0, -4 * blink), e + Vector2(7, 0), e + Vector2(0, 4 * blink)]),
				Color(Pal.WOLF_EYE, 0.9 * seen))


class ClawMarks extends Node2D:
	## Three deep gouges in a tree, higher than a man can reach.
	func _draw() -> void:
		var bt := Batch.new()
		for i in 3:
			var x := i * 12.0
			bt.poly(PackedVector2Array([Vector2(x, 0), Vector2(x + 5, -2), Vector2(x + 18, 70), Vector2(x + 13, 72)]), Pal.DEADWOOD)
			bt.line(Vector2(x + 2, 2), Vector2(x + 14, 68), Pal.DEADWOOD_DARK, 1.5)
		bt.draw(self)


class Brazier extends Bonfire:
	## An ancient stone bowl on a pillar in Old Scar's clearing. A touch of
	## the torch lights it for good; standing by it relights his torch; and a
	## lit bowl pushes the dark (and the beast) back.
	func _ready() -> void:
		super._ready()
		can_scorch = false
		radius = 280.0

	func light() -> Vector4:
		if not lit:
			return Vector4.ZERO
		var r := radius * (1.0 + sin(t * 9.0) * 0.015)
		return Vector4(global_position.x, global_position.y - 110.0, r, 1.0)

	func _draw() -> void:
		var bt := Batch.new()
		bt.quad(Vector2(-18, 0), Vector2(-14, -86), Vector2(14, -86), Vector2(18, 0), Pal.HEARTH_STONE.darkened(0.25))
		bt.line(Vector2(-8, -80), Vector2(-8, -6), Pal.HEARTH_STONE.darkened(0.45), 2.0)
		bt.poly(PackedVector2Array([Vector2(-40, -92), Vector2(40, -92), Vector2(28, -76), Vector2(-28, -76)]), Pal.HEARTH_STONE)
		bt.rect(Rect2(-42, -96, 84, 6), Pal.HEARTH_STONE.lightened(0.1))
		if lit:
			for i in 4:
				var bx := -18.0 + i * 12.0
				var h := 40.0 + 20.0 * (1.0 - absf(i - 1.5) / 1.5) + sin(t * (8.0 + i)) * 7.0
				bt.poly(NightWoods.flame_pts(Vector2(bx, -98), 11.0, h, sin(t * 5.0 + i) * 5.0), Color(Pal.EMBER_GLOW, 0.9))
			bt.poly(NightWoods.flame_pts(Vector2(0, -98), 9.0, 34.0 + sin(t * 12.0) * 5.0, sin(t * 7.0) * 3.0), Pal.FLAME)
			bt.poly(NightWoods.flame_pts(Vector2(0, -97), 5.0, 18.0, 0.0), Pal.FLAME_CORE)
		else:
			bt.poly(PackedVector2Array([Vector2(-24, -96), Vector2(0, -104), Vector2(24, -96)]), Pal.ASH)
		bt.draw(self)


class Lair extends Node2D:
	## Old Scar's lair: a black mouth in a wall of rock at the end of the
	## clearing, with the bones of his suppers scattered in front of it.
	func _ready() -> void:
		z_index = -1

	func _draw() -> void:
		var b := Batch.new()
		# the rock he lives in
		b.poly(PackedVector2Array([Vector2(-120, 0), Vector2(-104, -150), Vector2(-60, -250), Vector2(10, -300), Vector2(140, -320),
			Vector2(140, 0)]), Pal.CRAG_DARK)
		b.polyline(PackedVector2Array([Vector2(-104, -150), Vector2(-60, -250), Vector2(10, -300), Vector2(140, -320)]), Color(Pal.MOONLIT, 0.35), 3.0)
		# the mouth
		b.poly(PackedVector2Array([Vector2(-80, 0), Vector2(-72, -90), Vector2(-40, -150), Vector2(10, -170), Vector2(60, -140),
			Vector2(80, -60), Vector2(84, 0)]), Pal.CAVE_DARK)
		b.poly(PackedVector2Array([Vector2(-50, 0), Vector2(-44, -80), Vector2(-10, -126), Vector2(30, -120), Vector2(56, -60),
			Vector2(60, 0)]), Color(0, 0, 0, 0.85))
		# bones in front: a rib cage, a skull, scattered long bones
		for i in 4:
			var x := -150.0 + i * 12.0
			b.polyline(PackedVector2Array([Vector2(x, -2), Vector2(x + 4, -22), Vector2(x + 12, -26)]), Pal.KEY_BONE, 3.0)
		b.line(Vector2(-152, -18), Vector2(-104, -20), Pal.KEY_BONE, 3.0)
		b.circle(Vector2(-200, -10), 11.0, Pal.KEY_BONE, 12)
		b.circle(Vector2(-204, -12), 3.0, Pal.CAVE_DARK, 8)
		b.circle(Vector2(-195, -12), 3.0, Pal.CAVE_DARK, 8)
		for k in 3:
			var a := Vector2(-280.0 + k * 34.0, -3.0)
			b.line(a, a + Vector2(26, -4 + k * 3), Pal.KEY_BONE, 4.0)
			b.circle(a, 3.5, Pal.KEY_BONE, 8)
			b.circle(a + Vector2(26, -4 + k * 3), 3.5, Pal.KEY_BONE, 8)
		b.draw(self)


class FallingRock extends Area2D:
	## Shaken loose from the trees by Old Scar's roar: a shadow on the ground
	## first (the tell), then the rock. It lands as a rock he can throw back.
	var floor_y := 600.0
	var delay := 0.8
	var t := 0.0
	var vy := 0.0
	var falling := false

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 16.0
		cs.shape = c
		add_child(cs)
		position.y = floor_y - 560.0
		body_entered.connect(_on_body)

	func _on_body(b: Node) -> void:
		if falling and b is CaveMan:
			(b as CaveMan).hurt(1, global_position.x)

	func _physics_process(delta: float) -> void:
		t += delta
		if not falling:
			if t >= delay:
				falling = true
		else:
			vy += 2600.0 * delta
			position.y += vy * delta
			if position.y >= floor_y - 14.0:
				var r := World.RockPickup.new()
				r.position = Vector2(position.x, floor_y)
				get_parent().call_deferred("add_child", r)
				call_deferred("queue_free")
		queue_redraw()

	func _draw() -> void:
		var shadow_y := floor_y - position.y
		var k := clampf(t / delay, 0.0, 1.0)
		var bt := Batch.new()
		var pts := PackedVector2Array()
		for i in 12:
			var a := TAU * i / 12.0
			pts.append(Vector2(cos(a) * 20.0 * k, shadow_y - 2.0 + sin(a) * 5.0 * k))
		if k > 0.05:
			bt.poly(pts, Color(0, 0, 0, 0.45 * k))
		if falling or t > delay * 0.5:
			bt.poly(PackedVector2Array([Vector2(-14, -4), Vector2(-8, -14), Vector2(6, -15), Vector2(15, -3), Vector2(8, 11), Vector2(-9, 10)]), Pal.STONE)
			bt.line(Vector2(-8, -8), Vector2(6, -10), Pal.STONE_DARK, 2.0)
		bt.draw(self)


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
		if rect.size.y >= 40.0:
			# the body of the rock, in painted stone like the mountain (common/art)
			Terrain.paint_rect(self, rect.size, "#", Color(0.62, 0.6, 0.72))

	var _bt: Batch

	func _draw() -> void:
		_bt = Batch.new()
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
			_bt.poly(under, Pal.CRAG_DARK)
		else:
			# (the painted stone is a mesh under this): shade it toward the bottom, outline it
			_bt.quad(Vector2(0, minf(h, 60.0)), Vector2(w, minf(h, 60.0)), Vector2(w, h), Vector2(0, h), Color.BLACK,
				PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0.03, 0.02, 0.05, 0.55), Color(0.03, 0.02, 0.05, 0.55)]))
			_bt.polyline(PackedVector2Array([Vector2(0, h), Vector2(0, 0), Vector2(w, 0), Vector2(w, h)]), Color("1d1712"), 5.0)
		if thin:
			_bt.rect(Rect2(0, 0, w, minf(h, 26.0)), Pal.CRAG)
		# moss on top, like the mountain's
		_bt.rect(Rect2(0, -3, w, 7), Color(0.33, 0.47, 0.3))
		_bt.rect(Rect2(0, -3, w, 2), Color(0.5, 0.68, 0.45))
		# strata and cracks
		var n := int(w / 45.0) + 1
		for i in n:
			var cx := rng.randf_range(6.0, maxf(7.0, w - 6.0))
			var cy := rng.randf_range(10.0, minf(h, 120.0))
			_bt.line(Vector2(cx, cy), Vector2(cx + rng.randf_range(-10.0, 10.0), cy + rng.randf_range(10.0, 30.0)), Pal.CRAG_DARK.darkened(0.2), 2.0)
		# loose stones on the lip
		for i in int(w / 60.0):
			_bt.circle(Vector2(rng.randf_range(8.0, w - 8.0), -2.0), rng.randf_range(2.0, 4.0), Pal.CRAG_LIGHT.darkened(0.15))
		_bt.draw(self)


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

	var _bt: Batch

	func _draw() -> void:
		_bt = Batch.new()
		var pts := PackedVector2Array([Vector2(-W * 0.5, 0), Vector2(-W * 0.52, -H * 0.5), Vector2(-W * 0.3, -H * 0.92),
			Vector2(0, -H), Vector2(W * 0.35, -H * 0.88), Vector2(W * 0.52, -H * 0.45), Vector2(W * 0.5, 0)])
		_bt.poly(pts, Pal.CRAG_DARK)
		var hi := PackedVector2Array()
		for p in pts:
			hi.append(Vector2(p.x * 0.82 - 3.0, p.y * 0.9 - 2.0))
		_bt.poly(hi, Pal.CRAG)
		_bt.polyline(PackedVector2Array([pts[2], pts[3], pts[4]]), Pal.CRAG_LIGHT, 3.0)
		_bt.line(Vector2(-6, -H * 0.6), Vector2(4, -H * 0.3), Pal.CRAG_DARK, 2.0)
		_bt.draw(self)


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
	var y0 := -INF             ## it blows only between these heights (a gust zone up in the sky)
	var y1 := INF
	const LEE := 90.0          ## rock this close upwind of him keeps it off
	var shelter: Node = null   ## a Terrain: inside its tunnels and caves there is no wind
	var _indoors := false
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
		_indoors = shelter != null and shelter.is_inside(p + Vector2(0, -40))
		if p.x < x0 or p.x > x1 or p.y < y0 or p.y > y1 or player.dead or _indoors:
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

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		if k <= 0.01 or player == null or _indoors:
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

	var _bt: Batch

	func _draw() -> void:
		_bt = Batch.new()
		var w := rect.size.x
		var root := 0.0 if root_left else w
		var tip := w - root
		var d := 1.0 if root_left else -1.0
		var body := PackedVector2Array([Vector2(root - d * 12.0, -3), Vector2(tip, 0), Vector2(tip + d * 14.0, 4),
			Vector2(tip, 9), Vector2(root + (tip - root) * 0.5, 14), Vector2(root - d * 12.0, 24)])
		_bt.poly(body, Pal.BARK_DARK)
		_bt.poly(PackedVector2Array([Vector2(root - d * 12.0, -3), Vector2(tip, 0), Vector2(tip, 5), Vector2(root - d * 12.0, 8)]), Pal.BARK)
		_bt.line(Vector2(root, -2), Vector2(tip, 0), Color(Pal.MOONLIT, 0.35), 2.0)
		# twigs and leaf clusters, mostly toward the tip
		var rng := RandomNumberGenerator.new()
		rng.seed = int(rect.position.x) * 3 + int(rect.position.y)
		var n := int(w / 110.0) + 1
		for i in n:
			var x := root + (tip - root) * (0.35 + 0.65 * (i + 1.0) / n)
			var up := rng.randf() < 0.4
			var end := Vector2(x + d * rng.randf_range(10.0, 30.0), -28.0 if up else 30.0)
			_bt.line(Vector2(x, 4), end, Pal.BARK_DARK, 3.0)
			_leaves(end, rng.randf_range(12.0, 20.0), rng)
		_leaves(Vector2(tip + d * 18.0, 2), 22.0, rng)
		_bt.draw(self)

	func _leaves(c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
		for k in 5:
			var o := Vector2(rng.randf_range(-r, r), rng.randf_range(-r * 0.6, r * 0.6))
			_bt.circle(c + o, r * rng.randf_range(0.45, 0.7), Pal.CANOPY_DARK if k % 2 == 0 else Pal.CANOPY)


class Snag extends Node2D:
	## A tall dead tree on the far side of the chasm. Its branches (Branch
	## platforms placed over it) are the way back up to the bough.
	var height := 640.0

	var _bt: Batch

	func _draw() -> void:
		_bt = Batch.new()
		var h := height
		var body := PackedVector2Array([Vector2(-34, 4), Vector2(-16, -30), Vector2(-12, -h * 0.6), Vector2(-7, -h),
			Vector2(-1, -h - 22.0), Vector2(5, -h + 6.0), Vector2(10, -h * 0.6), Vector2(15, -30), Vector2(36, 4)])
		_bt.poly(body, Pal.DEADWOOD_DARK)
		var lit := PackedVector2Array()
		for p in body:
			lit.append(Vector2(p.x * 0.7 + 3.0, p.y))
		_bt.poly(lit, Pal.DEADWOOD)
		for k in 4:
			var x := -5.0 + k * 4.0
			_bt.line(Vector2(x, -20), Vector2(x * 0.6, -h * (0.5 + k * 0.1)), Pal.DEADWOOD_DARK, 2.0)
		_bt.draw(self)


class GreatTree extends Node2D:
	## The oldest tree in the woods: a trunk wider than a mammoth, roots like
	## walls, a crown above everything. Scenery only — its branches are the
	## Branch platforms placed over it.
	var top := -1360.0         ## local y of the top of the trunk
	var half := 72.0           ## half the trunk's width at the base

	var _bt: Batch

	func _draw() -> void:
		_bt = Batch.new()
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
			_bt.poly(PackedVector2Array([Vector2(s * half * 0.6, -150), Vector2(s * (half + 150.0), 4),
				Vector2(s * (half + 60.0), 6), Vector2(s * half * 0.4, -40)]), Pal.BARK_DARK)
		var trunk := PackedVector2Array([Vector2(-half, 4), Vector2(-half * 0.92, -300), Vector2(-half * 0.8, -700),
			Vector2(-half * 0.62, top), Vector2(half * 0.62, top), Vector2(half * 0.8, -700), Vector2(half * 0.92, -300), Vector2(half, 4)])
		_bt.poly(trunk, Pal.BARK_DARK)
		_bt.poly(PackedVector2Array([Vector2(-half * 0.55, 4), Vector2(-half * 0.5, -700), Vector2(-half * 0.3, top),
			Vector2(half * 0.45, top), Vector2(half * 0.62, -700), Vector2(half * 0.7, 4)]), Pal.BARK)
		_bt.line(Vector2(half * 0.9, -20), Vector2(half * 0.6, top), Color(Pal.MOONLIT, 0.3), 3.0)
		# bark grooves
		for i in 9:
			var x := -half * 0.7 + i * half * 0.17
			var pts := PackedVector2Array()
			for k in 14:
				var y := -k * (-top / 13.0)
				pts.append(Vector2(x * (1.0 - k * 0.025) + sin(k * 1.3 + i) * 4.0, y))
			_bt.polyline(pts, Pal.BARK_DARK, 2.5)
		# a knot-hole, dark as a cave
		_bt.circle(Vector2(-12, -820), 22.0, Pal.BARK_DARK.darkened(0.4))
		_bt.circle(Vector2(-12, -822), 15.0, Pal.CHARCOAL)
		# the top of the crown closes over the trunk
		_blob(Vector2(10, top + 20.0), 150.0, Pal.CANOPY_DARK, rng)
		_blob(Vector2(-20, top - 10.0), 110.0, Pal.CANOPY, rng)
		_bt.draw(self)

	func _blob(c: Vector2, r: float, col: Color, rng: RandomNumberGenerator) -> void:
		var pts := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			var rr := r * (0.85 + 0.2 * sin(a * 5.0 + c.x * 0.01) + rng.randf_range(-0.05, 0.05))
			pts.append(c + Vector2(cos(a) * rr, sin(a) * rr * 0.62))
		_bt.poly(pts, col)


## ================================================================ BACKGROUND
class NightSky extends Node2D:
	## Fixed to the screen. Dusk at the start of the level, full night by the
	## first dark stretch: the level sets `dusk` from how far he has walked.
	var dusk := 1.0
	var t := 0.0
	## The region's night sky (the colour script, PALETTE): dusk still lerps on top of it.
	var night_high := Pal.NIGHT_SKY_HIGH
	var night_low := Pal.NIGHT_SKY_LOW
	var accent := Pal.MOON              ## the region's accent: tints the moon's halo

	var _redraw_in := 0.0

	func _process(delta: float) -> void:
		t += delta
		_redraw_in -= delta
		if _redraw_in <= 0.0:
			_redraw_in = 1.0 / 15.0
			queue_redraw()

	var _bt: Batch

	func _draw() -> void:
		_bt = Batch.new()
		var hi := night_high.lerp(Pal.DUSK_HIGH, dusk)
		var lo := night_low.lerp(Pal.DUSK_LOW, dusk)
		_bt.quad(Vector2(-60, -60), Vector2(1400, -60), Vector2(1400, 840), Vector2(-60, 840), hi, PackedColorArray([hi, hi, lo, lo]))
		var starlight := 1.0 - dusk
		if starlight > 0.02:
			for i in 110:
				var p := Vector2(fmod(i * 197.3, 1340.0) - 30.0, fmod(i * 83.7 + i * i * 0.37, 470.0))
				var tw := 0.55 + 0.45 * sin(t * (0.8 + fmod(i * 0.37, 1.3)) + i)
				_bt.circle(p, 0.9 + fmod(i * 0.61, 1.1), Color(Pal.STAR, starlight * tw * (0.35 + fmod(i * 0.29, 0.5))), 6)
		var m := Vector2(1010, 104)
		var halo := Pal.MOON.lerp(accent, 0.6)
		for i in 4:
			_bt.circle(m, 58.0 + i * 24.0, Color(halo, 0.07 - i * 0.015))
		_bt.circle(m, 42.0, Pal.MOON)
		for c in [[Vector2(-12, -8), 9.0], [Vector2(10, 6), 7.0], [Vector2(4, -16), 4.5], [Vector2(-8, 16), 5.0]]:
			_bt.circle(m + (c[0] as Vector2), float(c[1]), Pal.MOON_SHADE)
		_bt.draw(self)


class NightRidges extends World.Panorama:
	## Far mountains, their crests picked out by the moon.
	var _bt: Batch

	func _draw() -> void:
		_bt = Batch.new()
		var keep := seedn
		_crest(372.0, 92.0, 20.0, Pal.NIGHT_FAR, Pal.NIGHT_FAR_RIM)
		seedn = keep + 4
		_crest(452.0, 58.0, 18.0, Pal.NIGHT_MID, Pal.NIGHT_FAR)
		seedn = keep
		_bt.draw(self)

	func _crest(base: float, a: float, step: float, body: Color, rim: Color) -> void:
		_bt.poly(strip_pts(base, a, step), body)
		var top := PackedVector2Array()
		var x := -20.0
		while x <= length + 20.0:
			top.append(Vector2(x, line(x, base, a)))
			x += step
		_bt.polyline(top, rim, 2.5)


class PineBand extends World.Panorama:
	## A far wall of pines. Each tier catches a line of moonlight on the right.
	var _bt: Batch

	func _draw() -> void:
		_bt = Batch.new()
		var x := -40.0
		var i := 0
		while x < length + 40.0:
			var base := line(x, 548.0, 24.0)
			var h := 110.0 + rnd(i) * 130.0
			_pine(Vector2(x, base), h, 20.0 + rnd(i + 3) * 16.0, Pal.PINE_DARK if i % 3 == 0 else Pal.PINE)
			x += 24.0 + rnd(i + 7) * 46.0
			i += 1
		_bt.poly(strip_pts(552.0, 16.0, 30.0), Pal.PINE_DARK)
		_bt.draw(self)

	func _pine(at: Vector2, h: float, w: float, col: Color) -> void:
		_bt.line(at, at + Vector2(0, -h * 0.3), Pal.TRUNK_DARK, 4.0)
		for k in 4:
			var y0 := at.y - h * (0.16 + k * 0.2)
			var ww := w * (1.0 - k * 0.2)
			var tip := Vector2(at.x, y0 - h * 0.34)
			_bt.poly(PackedVector2Array([
				Vector2(at.x - ww, y0), tip, Vector2(at.x + ww, y0), Vector2(at.x, y0 - h * 0.05)]), col)
			_bt.line(tip, Vector2(at.x + ww, y0), Color(Pal.MOONLIT, 0.28), 1.5)


class WoodsBand extends World.Panorama:
	## The near forest: tall trunks that run up out of the frame, and the odd
	## dead snag. Nothing here is lit but the moon's edge down their right sides.
	var _bt: Batch

	func _draw() -> void:
		_bt = Batch.new()
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
		_bt.poly(strip_pts(578.0, 8.0, 30.0), Pal.NIGHT_NEAR)
		_bt.draw(self)

	func _trunk(at: Vector2, w: float, k: int) -> void:
		var lean := (rnd(k + 20) - 0.5) * 40.0
		var top := at + Vector2(lean, -1100.0)
		var pts := PackedVector2Array([
			at + Vector2(-w * 1.5, 4), at + Vector2(-w * 0.6, -30), top + Vector2(-w * 0.35, 0),
			top + Vector2(w * 0.35, 0), at + Vector2(w * 0.6, -30), at + Vector2(w * 1.5, 4)])
		_bt.poly(pts, Pal.NIGHT_NEAR)
		_bt.line(at + Vector2(w * 0.55, -30), top + Vector2(w * 0.33, 0), Color(Pal.MOONLIT, 0.30), 2.0)
		for b in 2:
			var y := -260.0 - rnd(k + b * 7) * 260.0
			var s := -1.0 if (k + b) % 2 == 0 else 1.0
			var root := at + Vector2(lean * (-y / 1100.0), y)
			_bt.line(root, root + Vector2(s * (60.0 + rnd(k + b) * 50.0), -50.0 - rnd(k + 3 + b) * 40.0), Pal.NIGHT_NEAR, 6.0)

	func _snag(at: Vector2, h: float, k: int) -> void:
		var w := 20.0 + rnd(k + 4) * 10.0
		var pts := PackedVector2Array([
			at + Vector2(-w, 4), at + Vector2(-w * 0.5, -h * 0.9), at + Vector2(-w * 0.2, -h),
			at + Vector2(w * 0.1, -h * 0.86), at + Vector2(w * 0.4, -h * 0.97), at + Vector2(w * 0.55, -h * 0.8),
			at + Vector2(w, 4)])
		_bt.poly(pts, Pal.NIGHT_NEAR)
		_bt.line(at + Vector2(w * 0.55, -h * 0.8), at + Vector2(w, 4), Color(Pal.MOONLIT, 0.30), 2.0)
