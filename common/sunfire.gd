class_name Sunfire
extends RefCounted
## SUNFIRE: the fire's spirit in him for 30 seconds. Both fists burn, he
## shines gold, runs faster, jumps higher; his blows burn, THROW hurls
## fireballs as fast as he can tap (hold it for a stream), and hits bounce
## off him in a flare. The sun on the HUD fills as he fights (hits), finds
## shells and sits by fires; when it's full, Q (or SUN) lets it out.
## The player keeps the state (CaveMan.sun_t / sun_charge); this file is the
## effects: the burst when it starts, the fireballs, the hits, the drawing.

const DURATION := 30.0
const SPEED_MUL := 1.55            ## run and air speed (always well over the plain run)
const JUMP_MUL := 1.13
const HIT_BONUS := 2               ## extra damage on every blow
const SHOT_GAP := 0.13             ## fastest he can throw
const STREAM_GAP := 0.2            ## holding THROW
const WARN := 5.0                  ## the last seconds flicker

## What fills the sun.
const GAIN_HIT := 0.07
const GAIN_SHELL := 0.025
const GAIN_FIRE := 0.35            ## per second, standing in a bonfire

const GOLD := Color("ffd25a")
const HOT := Color("ff7a1f")
const WHITE_HOT := Color("fff3c4")
const RED := Color("ff3b1f")


## A flame drawn into a Batch: base at `at`, `h` tall, licking upward (`lean`
## bends it, e.g. trailing behind something moving). Real fire is many tongues,
## not one shape: three deep-red tongues (the middle one tallest), two orange
## inside them, a yellow core, and a white-hot root — each flickering on its own beat.
static func flame(b: Batch, at: Vector2, h: float, t: float, a := 1.0, lean := 0.0) -> void:
	for k in 3:
		var hk := h * (0.66 + 0.34 * float(k == 1)) * (1.0 + 0.2 * sin(t * (13.0 + k * 3.0) + k * 2.0))
		_tongue(b, at + Vector2((k - 1) * h * 0.2, 0), hk, h * 0.25, t * 10.0 + k * 2.1, lean, Color(RED, 0.8 * a))
	for k in 2:
		var hk2 := h * 0.72 * (1.0 + 0.18 * sin(t * 15.0 + k * 3.3))
		_tongue(b, at + Vector2((k - 0.5) * h * 0.18, 0), hk2, h * 0.17, t * 12.0 + k * 1.4, lean, Color(HOT, 0.95 * a))
	_tongue(b, at, h * 0.48 * (1.0 + 0.15 * sin(t * 19.0)), h * 0.11, t * 14.0, lean, Color(GOLD, a))
	b.ellipse(at + Vector2(0, -h * 0.06), h * 0.15, h * 0.09, Color(WHITE_HOT, a), 0.0, 8)


## One tongue of flame: a wiggling spine, widest at the root, tapering to a
## point, rounded at the bottom.
static func _tongue(b: Batch, base: Vector2, h: float, w: float, ph: float, lean: float, col: Color) -> void:
	b.ellipse(base, w, w * 0.6, col, 0.0, 8)
	var pl := base + Vector2(-w, 0)
	var pr := base + Vector2(w, 0)
	for i in range(1, 5):
		var k := i / 4.0
		var c := base + Vector2(sin(ph + k * 2.6) * w * 0.7 * k + lean * h * k * k, -h * k)
		if i == 4:
			b.tri(pl, pr, c, col)
		else:
			var ww := w * (1.0 - k) * (1.0 + 0.2 * sin(ph * 1.3 + k * 4.0))
			var l := c + Vector2(-ww, 0)
			var r := c + Vector2(ww, 0)
			b.quad(pl, pr, r, l, col)
			pl = l
			pr = r


## ================================================================ IGNITE
class Ignite extends Node2D:
	## The moment it starts: a white flash, two gold shock rings racing out,
	## sun-rays turning, and everything close enough is burned or sent running.
	const RADIUS := 260.0
	var t := 0.0

	func _ready() -> void:
		z_index = 6
		add_to_group("light")
		add_to_group("glow")
		var from := global_position
		for c in get_tree().get_nodes_in_group("critters"):
			var cr := c as Critter
			if cr == null or cr.dying > 0.0:
				continue
			var d := (cr.global_position + Vector2(0, -18)).distance_to(from)
			if d < RADIUS:
				cr.burned(4, from)
			elif d < RADIUS * 1.8 and cr.has_method("scare"):
				cr.scare(from)
		for b in get_tree().get_nodes_in_group("bonfire"):
			if (b as Node2D).global_position.distance_to(from) < RADIUS + 40.0 and b.has_method("kindle"):
				b.kindle()

	func _process(delta: float) -> void:
		t += delta
		if t > 1.0:
			queue_free()
			return
		queue_redraw()

	func light() -> Vector4:
		return Vector4(global_position.x, global_position.y, 520.0 * (1.0 - t * 0.6), 1.0)

	func light_strength() -> float:
		return 0.0

	func _draw() -> void:
		var b := Batch.new()
		var k := clampf(t / 0.55, 0.0, 1.0)
		for i in 2:
			var kk := clampf(k - i * 0.18, 0.0, 1.0)
			if kk > 0.0 and kk < 1.0:
				b.arc(Vector2.ZERO, RADIUS * kk, 0.0, TAU, 48, Color(GOLD, 1.0 - kk), 10.0 * (1.0 - kk) + 2.0)
		for i in 12:
			var a := i * TAU / 12.0 + t * 2.0
			var ray := 80.0 + 160.0 * k
			b.line(Vector2.from_angle(a) * 30.0, Vector2.from_angle(a) * ray, Color(WHITE_HOT, 0.6 * (1.0 - k)), 6.0)
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var o := global_position
		var f := clampf(1.0 - t / 0.35, 0.0, 1.0)
		g.draw_circle(o, 140.0 + 200.0 * t, Color(1.0, 0.85, 0.4, 0.45 * f))
		g.draw_circle(o, 60.0, Color(1.0, 0.98, 0.85, 0.8 * f))


## ================================================================ FIREBALL
class Fireball extends Area2D:
	## Flies straight and fast with a comet tail. Hits anything that can be hit
	## (beasts, breakables, bats, dragonflies), lights cold fires it passes,
	## and bursts on the first wall.
	var vel := Vector2.ZERO
	var life := 1.1
	var dmg := 3
	var _t := 0.0
	var _trail: Array = []

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 4
		monitoring = true
		z_index = 5
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 14.0
		cs.shape = c
		add_child(cs)
		add_to_group("light")
		add_to_group("glow")

	func light() -> Vector4:
		return Vector4(global_position.x, global_position.y, 150.0, 1.0)

	func light_strength() -> float:
		return 0.0

	func _physics_process(delta: float) -> void:
		_t += delta
		life -= delta
		var from := global_position
		var to := from + vel * delta
		# a wall stops it
		var q := PhysicsRayQueryParameters2D.create(from, to, 1)
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			_burst(hit["position"])
			return
		global_position = to
		_trail.push_front(global_position)
		if _trail.size() > 9:
			_trail.pop_back()
		for a in get_overlapping_areas():
			if a.has_method("take_hit"):
				if a is Critter:
					(a as Critter).burned(dmg, global_position - vel.normalized() * 30.0)
				else:
					a.take_hit(dmg, signi(int(vel.x)))
				_burst(global_position)
				return
		for b in get_tree().get_nodes_in_group("bonfire"):
			if (b as Node2D).global_position.distance_to(global_position) < 60.0 and b.has_method("kindle"):
				b.kindle()
		if life <= 0.0:
			_burst(global_position)
			return
		queue_redraw()

	func _burst(at: Vector2) -> void:
		var pop := Impact.new()
		pop.position = at
		get_parent().add_child(pop)
		queue_free()

	func _draw() -> void:
		var b := Batch.new()
		# the comet tail, in world space behind it
		for i in _trail.size():
			var q: float = 1.0 - float(i) / 9.0
			var p: Vector2 = (_trail[i] as Vector2) - global_position
			b.circle(p, 13.0 * q, Color(RED, 0.5 * q), 10)
			b.circle(p, 8.0 * q, Color(HOT, 0.6 * q), 8)
		var wob := 1.0 + 0.12 * sin(_t * 40.0)
		b.circle(Vector2.ZERO, 15.0 * wob, Color(RED, 0.9), 16)
		b.circle(Vector2.ZERO, 11.0 * wob, HOT, 14)
		b.circle(Vector2(signf(vel.x) * 3.0, -2), 6.0, WHITE_HOT, 12)
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var o := global_position
		g.draw_circle(o, 30.0, Color(1.0, 0.55, 0.15, 0.35))
		g.draw_circle(o, 9.0, Color(1.0, 0.95, 0.7, 0.9))


## ================================================================ IMPACT
class Impact extends Node2D:
	## Where a fireball (or a burning blow) lands: a pop of fire and sparks.
	var t := 0.0
	var size := 1.0
	var _sparks: Array = []

	func _ready() -> void:
		z_index = 6
		add_to_group("glow")
		for i in 9:
			var a := randf() * TAU
			_sparks.append([Vector2.ZERO, Vector2.from_angle(a) * randf_range(140, 320) * size])

	func _process(delta: float) -> void:
		t += delta
		for s in _sparks:
			s[1] = (s[1] as Vector2) + Vector2(0, 600) * delta
			s[0] = (s[0] as Vector2) + (s[1] as Vector2) * delta
		if t > 0.45:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var k := t / 0.45
		b.circle(Vector2.ZERO, (14.0 + 30.0 * k) * size, Color(RED, 0.7 * (1.0 - k)), 18)
		b.circle(Vector2.ZERO, (10.0 + 18.0 * k) * size, Color(HOT, 0.8 * (1.0 - k)), 16)
		b.circle(Vector2.ZERO, 8.0 * (1.0 - k) * size, WHITE_HOT, 12)
		for s in _sparks:
			b.circle(s[0], 3.0 * (1.0 - k), GOLD, 6)
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var o := global_position
		var k := t / 0.45
		g.draw_circle(o, 50.0 * size, Color(1.0, 0.6, 0.2, 0.5 * (1.0 - k)))
		for s in _sparks:
			g.draw_circle(o + (s[0] as Vector2), 2.5, Color(1.0, 0.85, 0.4, 1.0 - k))


## ================================================================ WORD
class Word extends Node2D:
	## "SUNFIRE!" — big, gold, wobbling, rising off him.
	var text := "SUNFIRE!"
	var size := 46
	var t := 0.0

	func _ready() -> void:
		z_index = 20

	func _process(delta: float) -> void:
		t += delta
		position.y -= 30.0 * delta
		if t > 1.4:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var pop := minf(t / 0.12, 1.0)
		var s := (0.6 + 0.6 * pop - 0.2 * minf(t / 0.3, 1.0)) * (1.0 + 0.04 * sin(t * 30.0))
		var a := clampf((1.4 - t) / 0.4, 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, sin(t * 9.0) * 0.05, Vector2(s, s))
		var f := ThemeDB.fallback_font
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		for o in [Vector2(-3, 3), Vector2(3, 3), Vector2(0, 4)]:
			draw_string(f, Vector2(-w * 0.5, 0) + o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.45, 0.08, 0.0, a))
		draw_string(f, Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(GOLD, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
