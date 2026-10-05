## Hanging hoards: a woven basket full of shells, swinging on a rope from a
## bough, a dead snag or a drifting sky stone — and guarded by giant
## dragonflies that dart at him when he comes close. Three whacks break the
## basket (each one swings it harder); the last one is a fountain of shells,
## the rope snaps, and the guards flee.
class_name Hoards
extends RefCounted


## ================================================================ HOARD
class Hoard extends Node2D:
	## position = the rope's anchor. The basket (a Treasure.Breakable of kind
	## "hoard", a sibling in the level so its shells pop into the level) hangs
	## `rope` px below and swings `swing` radians each way.
	var rope := 200.0
	var swing := 0.55
	var period := 2.6
	var prop := "bough"          ## bough, snag, stone
	var drift := 0.0             ## a "stone" drifts side to side this far
	var root_y := 600.0          ## a "snag" grows from here
	var guards := 2
	var box: Treasure.Breakable
	var flies: Array = []
	var level: Node2D
	var _home := Vector2.ZERO
	var _t := 0.0
	var _kick := 0.0             ## extra swing after a whack, dying away
	var anger := 0.0             ## s the guards stay angry after the basket is hit
	var _hits_seen := -1
	var _angle := 0.0
	var _cut := false            ## the rope has snapped
	var _darter: Node = null     ## one guard darts at a time

	func _ready() -> void:
		_home = position
		_t = fmod(position.x * 0.013, period)
		z_index = -1
		add_to_group("glow")
		if box != null:
			_hits_seen = box.hits
			_place_box()
		for i in guards:
			var f := GuardFly.new()
			f.hoard = self
			f.slot = i
			f.palette = (i + int(position.x / 100.0)) % 2
			f.position = basket_centre() + Vector2(-60.0 + 120.0 * i, -20.0)
			level.add_child.call_deferred(f)
			flies.append(f)

	func basket_centre() -> Vector2:
		return global_position + Vector2(sin(_angle), cos(_angle)) * (rope + 25.0)

	## Where guard `slot` patrols at time t: a lazy figure-eight round the basket.
	func guard_spot(slot: int, t: float) -> Vector2:
		var a := t * 1.7 + slot * PI
		return basket_centre() + Vector2(cos(a) * 95.0, sin(a * 2.0) * 38.0 - 20.0)

	func may_dart(f: Node) -> bool:
		if _darter != null and is_instance_valid(_darter) and _darter != f and _darter.state in ["aim", "dart"]:
			return false
		_darter = f
		return true

	func _place_box() -> void:
		var at := global_position + Vector2(sin(_angle), cos(_angle)) * (rope + 50.0)
		box.carry_to(at, -_angle)

	func _physics_process(delta: float) -> void:
		_t += delta
		if prop == "stone" and drift > 0.0:
			position = _home + Vector2(sin(_t * 0.5) * drift, sin(_t * 1.1) * 8.0)
		var alive := box != null and is_instance_valid(box) and box.hits > 0
		if alive:
			if box.hits != _hits_seen:
				_hits_seen = box.hits
				_kick = 0.35
				anger = 6.0
			_kick = maxf(_kick - delta * 0.12, 0.0)
			anger = maxf(anger - delta, 0.0)
			_angle = (swing + _kick) * sin(TAU * _t / period)
			_place_box()
		elif not _cut:
			_cut = true
			for f in flies:
				if is_instance_valid(f):
					f.flee()
		else:
			# the cut rope still sways a little
			_angle = 0.25 * sin(TAU * _t / period) * exp(-_t * 0.02)
		if NightWoods.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		match prop:
			"bough":
				# a thick bough reaching in from the left, leaves on it
				var bark := Color("4a3828")
				b.poly(PackedVector2Array([Vector2(-300, -40), Vector2(-120, -14), Vector2(40, -6), Vector2(46, 4),
					Vector2(-120, 10), Vector2(-300, -8)]), bark)
				b.line(Vector2(-240, -26), Vector2(-60, -6), Color("5d4732"), 3.0)
				b.line(Vector2(-90, -8), Vector2(-60, -44), bark, 6.0)
				for k in 5:
					var c := Vector2(-260.0 + k * 66.0, -40.0 - (k % 2) * 16.0)
					b.circle(c, 30.0, Color("1f3d2a"), 12)
					b.circle(c + Vector2(8, -6), 20.0, Color("2c5236"), 10)
			"snag":
				# a dead tree stuck in the tar, leaning, one bare arm out
				var gray := Color("5a5148")
				var foot := Vector2(-80, root_y - _home.y)
				b.poly(PackedVector2Array([foot + Vector2(-10, 0), Vector2(-74, -18), Vector2(-60, -24), foot + Vector2(10, 0)]), gray)
				b.poly(PackedVector2Array([Vector2(-70, -22), Vector2(10, -8), Vector2(12, 2), Vector2(-66, -8)]), gray)
				b.line(Vector2(-68, -20), Vector2(-96, -70), gray, 6.0)
				b.line(Vector2(-90, -58), Vector2(-112, -64), gray, 4.0)
				b.line(Vector2(-30, -12), Vector2(-20, -40), gray, 4.0)
			"stone":
				# a little drifting sky stone, moss on top
				b.poly(PackedVector2Array([Vector2(-46, -16), Vector2(46, -16), Vector2(40, 0), Vector2(16, 18),
					Vector2(-10, 22), Vector2(-36, 6)]), Color("4b4f63"))
				b.rect(Rect2(-48, -20, 96, 6), Color("2f5a3a"))
				b.rect(Rect2(-48, -20, 96, 2), Color("5c9a5e"))
				b.circle(Vector2(-20, 4), 4.0, Color("5a5e75"), 8)
		# the rope: whole, or snapped and dangling
		var rl := rope if not _cut else rope * 0.45
		var end := Vector2(sin(_angle), cos(_angle)) * rl
		var pts := PackedVector2Array()
		for i in 9:
			var k := i / 8.0
			pts.append(end * k + Vector2(sin(k * PI) * 4.0, 0))
		b.polyline(pts, Color("7a5a32"), 4.0)
		b.polyline(pts, Color("b88a4c"), 2.0)
		b.circle(Vector2.ZERO, 6.0, Color("7a5a32"), 10)
		if _cut:
			b.line(end, end + Vector2(-5, 8), Color("b88a4c"), 2.0)
			b.line(end, end + Vector2(5, 9), Color("b88a4c"), 2.0)
		b.draw(self)

	## The rope's knot and the bough's glow-moss, so the hoard reads in the dark.
	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var o := global_position
		g.draw_circle(o, 4.0, Color("ffd27a", 0.5))
		if prop == "stone":
			g.draw_line(o + Vector2(-44, -19), o + Vector2(44, -19), Color("9fd6a6", 0.5), 3.0)


## ================================================================ GUARD FLY
class GuardFly extends Area2D:
	## A giant dragonfly guarding a hoard. It patrols round the basket; when he
	## comes close it hovers, takes aim (a buzzing, a line of light toward him)
	## and darts — fast and straight — then flies back. A whack sends it
	## spinning down dizzy for a while; then it comes back to its post.
	const RANGE := 320.0         ## how near he must be to be chased, once the basket has been hit
	const CLOSE := 170.0         ## ...and before: only right under it, or jumping at it
	const AIM := 0.5
	const DART := 980.0
	var hoard: Hoard
	var slot := 0
	var palette := 0
	var state := "patrol"        ## patrol, aim, dart, back, dizzy, flee
	var _t := 0.0
	var _st := 0.0
	var _cool := 0.8
	var _target := Vector2.ZERO
	var _vel := Vector2.ZERO
	var _face := 1.0
	var _trail: Array = []       ## recent positions while darting

	const LOOKS := [
		[Color("2ad1c9"), Color("1b7fd6"), Color("ff4f7b"), Color("9ff3ff")],   # teal and blue, red eyes
		[Color("ffb347"), Color("e8452c"), Color("7dff6a"), Color("ffe08a")],   # ember: orange and red, green eyes
	]

	func _ready() -> void:
		collision_layer = 4          # his swing and his rocks find it
		collision_mask = 2
		z_index = 3
		var cs := CollisionShape2D.new()
		var sh := CircleShape2D.new()
		sh.radius = 18.0
		cs.shape = sh
		add_child(cs)
		add_to_group("glow")
		_t = slot * 1.3

	func flee() -> void:
		state = "flee"
		_st = 0.0
		_vel = Vector2(_face * 200.0, -420.0)

	func take_hit(_dmg: int, from_dir: int) -> void:
		if state in ["dizzy", "flee"]:
			return
		state = "dizzy"
		_st = 0.0
		_vel = Vector2(from_dir * 260.0, -160.0)
		_trail.clear()
		var pop := Treasure.FloatText.new()
		pop.text = "BZZT!"
		pop.position = global_position + Vector2(-18, -30)
		get_parent().add_child(pop)
		FX.burst(get_parent(), global_position, "sparks")

	func _player() -> CaveMan:
		return get_tree().get_first_node_in_group("player") as CaveMan

	func _physics_process(delta: float) -> void:
		_t += delta
		_st += delta
		_cool = maxf(_cool - delta, 0.0)
		var p := _player()
		var home := hoard.guard_spot(slot, _t) if is_instance_valid(hoard) else global_position
		match state:
			"patrol":
				var to := home - global_position
				global_position += to * minf(delta * 6.0, 1.0)
				if absf(to.x) > 1.0:
					_face = signf(to.x)
				if p != null and not p.dead and not p.talking and _cool <= 0.0 \
						and (p.global_position + Vector2(0, -34)).distance_to(hoard.basket_centre()) < (RANGE if hoard.anger > 0.0 else CLOSE) and hoard.may_dart(self):
					state = "aim"
					_st = 0.0
			"aim":
				# hover, rear back a little, track him... and lock on
				if p != null and _st < AIM * 0.7:
					_target = p.global_position + Vector2(0, -34)
				var back := (global_position - _target).normalized()
				global_position += back * 40.0 * delta + Vector2(0, sin(_t * 40.0) * 0.8)
				_face = signf(_target.x - global_position.x) if absf(_target.x - global_position.x) > 1.0 else _face
				if _st >= AIM:
					state = "dart"
					_st = 0.0
					_vel = (_target - global_position).normalized() * DART
			"dart":
				global_position += _vel * delta
				_trail.push_front(global_position)
				if _trail.size() > 6:
					_trail.pop_back()
				var past := (_target - global_position).dot(_vel) < -60.0 * DART / 980.0
				if past or _st > 0.6:
					state = "back"
					_st = 0.0
			"back":
				var to2 := home - global_position
				var step := minf(to2.length(), 420.0 * delta)
				global_position += to2.normalized() * step
				if absf(to2.x) > 1.0:
					_face = signf(to2.x)
				if _trail.size() > 0:
					_trail.pop_back()
				if to2.length() < 12.0:
					state = "patrol"
					_cool = 1.1 + randf() * 0.6
			"dizzy":
				_vel.y = minf(_vel.y + 500.0 * delta, 160.0)
				_vel.x *= 1.0 - minf(delta * 2.0, 1.0)
				global_position += _vel * delta
				rotation += 9.0 * delta
				if _st > 2.6:
					rotation = 0.0
					state = "back"
					_st = 0.0
			"flee":
				global_position += _vel * delta
				_vel.y -= 200.0 * delta
				if _st > 2.5:
					queue_free()
					return
		if state in ["patrol", "aim", "dart", "back"] and p != null and not p.dead and overlaps_body(p):
			var away := 1.0 if p.global_position.x >= global_position.x else -1.0
			p.hurt_toss(1, global_position.x, Vector2(away * 90.0, -420.0))     # bumped up, not off his perch
		if NightWoods.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var look: Array = LOOKS[palette]
		var c0: Color = look[0]
		var c1: Color = look[1]
		var f := _face
		var tilt := 0.0
		if state == "aim":
			tilt = clampf((_target.y - global_position.y) / 300.0, -0.5, 0.5) * f
		elif state == "dart":
			tilt = atan2(_vel.y, absf(_vel.x)) * f
		var r := Transform2D(tilt, Vector2.ZERO)
		# four long, glassy wings off the thorax, sweeping up and down so fast
		# they blur: drawn at the two ends of the beat
		var beat := sin(_t * 48.0)
		for k in 2:
			var root := Vector2((-1.0 - k * 7.0) * f, -5)
			for ph in [beat, -beat * 0.6]:
				var a := -PI * 0.5 - f * (0.25 + k * 0.2) + float(ph) * 0.75
				var along := Vector2.from_angle(a)
				var side := along.orthogonal()
				var wing := PackedVector2Array()
				for j in 10:
					var q := j / 9.0 * TAU
					wing.append(r * (root + along * (19.0 + cos(q) * 19.0) * (1.0 - k * 0.12) + side * sin(q) * 5.5))
				var alpha := 0.42 if ph == beat else 0.2
				b.poly(wing, Color(0.82, 0.96, 1.0, alpha))
				b.polyline(wing, Color(look[3], alpha + 0.2), 1.2)
		# the long abdomen: a tapering rod, banded, fading from one colour into the other
		var tail := PackedVector2Array()
		for i in 9:
			tail.append(r * Vector2((-6.0 - i * 5.5) * f, sin(i * 0.5) * 0.8))
		b.polyline(tail, c1.darkened(0.25), 7.0)
		for i in 9:
			var k2 := i / 8.0
			b.circle(tail[i], 3.8 - k2 * 1.6, c0.lerp(c1, k2), 8)
		b.circle(tail[8] + r * Vector2(-3.0 * f, 0), 2.4, c1, 6)
		# thorax and the big round eyes
		b.circle(r * Vector2(0, 0), 8.0, c1, 12)
		b.circle(r * Vector2(2.0 * f, -2), 5.5, c0, 10)
		b.circle(r * Vector2(10.0 * f, -3), 6.5, look[2], 12)
		b.circle(r * Vector2(11.5 * f, -5.5), 2.2, Color(1, 1, 1, 0.85), 6)
		# little legs held under, ready to grab
		for j2 in 3:
			var lx := (2.0 - j2 * 4.0) * f
			b.line(r * Vector2(lx, 6), r * Vector2(lx + 3.0 * f, 13), Color("2a2a30"), 1.5)
		if state == "dizzy":
			for k3 in 3:
				var a := _t * 6.0 + k3 * TAU / 3.0
				b.circle(Vector2(cos(a) * 14.0, -22.0 + sin(a) * 4.0), 3.0, Color("ffe066"), 6)
		b.draw(self)

	## Eyes and wing-shimmer through the dark; the aim line before a dart, and
	## a streak of colour behind it.
	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var o := global_position
		var look: Array = LOOKS[palette]
		g.draw_circle(o + Vector2(9.0 * _face, -3), 4.0, Color(look[2], 0.9))
		g.draw_circle(o, 16.0, Color(look[0], 0.12))
		if state == "aim":
			var k := clampf(_st / AIM, 0.0, 1.0)
			var dir := (_target - o).normalized()
			for i in 6:
				var a := o + dir * (24.0 + i * 34.0)
				g.draw_line(a, a + dir * 16.0, Color(1.0, 0.35, 0.3, 0.25 + 0.6 * k), 3.0)
		for i in _trail.size():
			var q: float = 1.0 - float(i) / 6.0
			g.draw_circle(_trail[i], 9.0 * q, Color(look[0], 0.45 * q))
