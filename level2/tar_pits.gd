## The Tar Pits: black, sticky, bubbling pools between the mammoth graveyard
## and the great tree. Logs float on the tar until he stands on one, and then
## it slowly goes under — so he keeps moving. In the tar he is stuck: the level
## hauls him out on the near bank, a heart lighter.
class_name TarPits
extends RefCounted

const SURFACE := 608.0          ## the tar's top, just under the ground's


## ================================================================ POOL
class Pool extends Node2D:
	## One pool, from its left bank (x = 0) to w. Drawn over the logs' lower
	## halves, so whatever sinks goes INTO the tar.
	signal stuck
	var w := 300.0
	var _t := 0.0
	var _area: Area2D
	var _bubbles: Array = []        ## [x, phase, size]

	func _ready() -> void:
		z_index = 1
		add_to_group("glow")
		_area = Area2D.new()
		_area.collision_layer = 0
		_area.collision_mask = 2
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(w, 400)
		cs.shape = sh
		cs.position = Vector2(w * 0.5, SURFACE + 26.0 + 200.0)
		_area.add_child(cs)
		add_child(_area)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(position.x)
		for i in int(w / 45.0) + 2:
			_bubbles.append([rng.randf_range(12.0, w - 12.0), rng.randf() * 3.0, rng.randf_range(5.0, 12.0)])

	func _physics_process(delta: float) -> void:
		_t += delta
		var p := get_tree().get_first_node_in_group("player") as CaveMan
		if p != null and not p.dead and _area.overlaps_body(p):
			stuck.emit()
		if NightWoods.near_view(self):
			queue_redraw()

	## Moonlight on the tar, over the dark: a glossy line along the top, and the
	## bubbles catching the light, so a pool reads as TAR, not as a hole.
	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var o := global_position
		var s := SURFACE
		g.draw_line(o + Vector2(2, s + 1), o + Vector2(w - 2, s + 1), Color("8d84b0", 0.55), 2.0)
		for k in int(w / 60.0) + 1:
			var x := fmod(k * 61.0 + _t * 9.0, w - 30.0)
			g.draw_line(o + Vector2(x, s + 4), o + Vector2(x + 26.0, s + 4), Color("b9b0dc", 0.35), 2.0)
		for bb in _bubbles:
			var q := fmod(_t * 0.55 + float(bb[1]), 1.0)
			if q < 0.85:
				var r: float = float(bb[2]) * sin(minf(q / 0.85, 1.0) * PI * 0.5)
				var bx: float = bb[0]
				g.draw_circle(o + Vector2(bx - r * 0.35, s - r * 0.9 + 2.0), maxf(r * 0.3, 1.0), Color("d6ccff", 0.55))
				g.draw_circle(o + Vector2(bx, s - r * 0.55 + 2.0), r + 2.0, Color("6a5f8f", 0.18))

	func _draw() -> void:
		var b := Batch.new()
		var s := SURFACE
		# the tar: near-black, with a sheen of moonlight along its top
		b.rect(Rect2(0, s, w, 420), Color("0e0c0d"))
		b.rect(Rect2(0, s, w, 6), Color("2a2730"))
		for k in int(w / 60.0) + 1:
			var x := fmod(k * 61.0 + _t * 9.0, w - 30.0)
			b.line(Vector2(x, s + 2), Vector2(x + 26.0, s + 2), Color("6a6680", 0.55), 2.0)
		# old bones poking out: it has caught bigger things than him
		b.line(Vector2(w * 0.3, s + 4), Vector2(w * 0.3 + 18.0, s - 26.0), Color("b9ae94"), 6.0)
		b.circle(Vector2(w * 0.3 + 18.0, s - 26.0), 5.0, Color("b9ae94"), 8)
		b.line(Vector2(w * 0.72, s + 4), Vector2(w * 0.72 - 10.0, s - 14.0), Color("8a806b"), 5.0)
		# bubbles: swell up, wobble... and pop, with a little splash
		for bb in _bubbles:
			var q := fmod(_t * 0.55 + float(bb[1]), 1.0)
			var bx: float = bb[0]
			var r: float = float(bb[2]) * sin(minf(q / 0.85, 1.0) * PI * 0.5)
			if q < 0.85:
				b.circle(Vector2(bx, s - r * 0.55 + 2.0), r, Color("1c1a20"), 12)
				b.circle(Vector2(bx - r * 0.35, s - r * 0.9 + 2.0), r * 0.28, Color("8a86a0", 0.6), 6)
			else:
				var k2 := (q - 0.85) / 0.15
				for j in 4:
					var a := -PI * (0.2 + 0.2 * j)
					b.circle(Vector2(bx, s) + Vector2.from_angle(a) * (6.0 + k2 * 18.0), 2.5 * (1.0 - k2), Color("1c1a20"), 6)
		b.draw(self)


## ================================================================ LOG
class Log extends AnimatableBody2D:
	## A log floating on the tar: a one-way platform. While he stands on it,
	## it sinks (and tips toward him); left alone it bobs back up.
	const SINK := 40.0              ## px/s while he stands on it: under in ~0.85 s
	const RISE := 40.0
	var w := 100.0
	var sunk := 0.0
	var _t := 0.0
	var _home := Vector2.ZERO

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		sync_to_physics = true
		z_index = 2                 # over the tar: what is under its top is blacked out below
		_home = position + Vector2(0, -6)    # floats a little proud of the ground
		_t = randf() * 6.0
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(w, 12)
		cs.shape = sh
		cs.position = Vector2(0, 6)
		cs.one_way_collision = true
		add_child(cs)

	func _physics_process(delta: float) -> void:
		_t += delta
		var p := get_tree().get_first_node_in_group("player") as CaveMan
		var on := p != null and p.is_on_floor() and absf(p.global_position.y - global_position.y) < 5.0 \
			and absf(p.global_position.x - global_position.x) < w * 0.5 + 12.0
		sunk = clampf(sunk + (SINK if on else -RISE) * delta, 0.0, 70.0)
		position = _home + Vector2(0, sunk + sin(_t * 1.6) * 1.5)
		if NightWoods.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var bark := Color("94704a")
		var dark := Color("5e452f")
		b.rect(Rect2(-w * 0.5, 0, w, 16), bark)
		b.rect(Rect2(-w * 0.5, 12, w, 4), dark)
		for k in int(w / 22.0):
			var x := -w * 0.5 + 10.0 + k * 22.0
			b.line(Vector2(x, 3), Vector2(x + 12.0, 5), dark, 1.5)
		# the cut ends, with rings
		for e in [-1.0, 1.0]:
			b.circle(Vector2(e * w * 0.5, 8), 8.0, Color("c9a06e"), 10)
			b.circle(Vector2(e * w * 0.5, 8), 4.0, Color("8a6a48"), 8)
		# a stub of branch, and tar clinging along the waterline
		b.line(Vector2(w * 0.15, 0), Vector2(w * 0.25, -12), bark, 4.0)
		# whatever is under the tar's top is under the tar
		var under := SURFACE - global_position.y
		if under < 18.0:
			b.rect(Rect2(-w * 0.5 - 10.0, maxf(under, -14.0), w + 20.0, 34.0 - maxf(under, -14.0)), Color("0e0c0d"))
			b.rect(Rect2(-w * 0.5 - 10.0, maxf(under, -14.0), w + 20.0, 2.0), Color("2a2730"))
		b.draw(self)


## ================================================================ GEYSER
class Geyser extends Node2D:
	## A vent in the tar. Quiet, then it rumbles (bubbles swell, a hot orange
	## glow wells up under the surface), then a jet of boiling tar shoots up —
	## a hit tosses him into the air. Wait on firm ground for it to pass.
	const WIDTH := 26.0            ## half the jet's width
	var height := 280.0
	var quiet := 1.7
	var rumble := 0.9
	var blast := 0.75
	var offset := 0.0              ## where in its cycle it starts
	var state := "quiet"           ## quiet, rumble, blast
	var _t := 0.0
	var _blobs: Array = []         ## [x, y, vx, vy]

	func _ready() -> void:
		z_index = 3
		add_to_group("glow")
		_t = offset

	func cycle() -> float:
		return quiet + rumble + blast

	## The top of the jet (world y); the tar's surface when it isn't blowing.
	func jet_top() -> float:
		if state != "blast":
			return SURFACE
		var k := fmod(_t, cycle()) - quiet - rumble
		var rise := clampf(k / 0.12, 0.0, 1.0)
		var fall := clampf((blast - k) / 0.18, 0.0, 1.0)
		return SURFACE - height * minf(rise, fall)

	func _physics_process(delta: float) -> void:
		_t += delta
		var k := fmod(_t, cycle())
		var was := state
		state = "quiet" if k < quiet else ("rumble" if k < quiet + rumble else "blast")
		if state == "blast" and was != "blast":
			for i in 10:
				_blobs.append([randf_range(-10, 10), SURFACE - height * randf_range(0.5, 1.0), randf_range(-160, 160), randf_range(-260, -60)])
		for bb in _blobs:
			bb[3] += 900.0 * delta
			bb[0] += bb[2] * delta
			bb[1] += bb[3] * delta
		_blobs = _blobs.filter(func(bb): return bb[1] < SURFACE + 10.0)
		if state == "blast":
			var p := get_tree().get_first_node_in_group("player") as CaveMan
			if p != null and not p.dead:
				var d := p.global_position - global_position
				var side := 1.0 if d.x >= 0.0 else -1.0
				if absf(d.x) < WIDTH + 13.0 and p.global_position.y > jet_top() and p.global_position.y - 64.0 < SURFACE:
					p.hurt_toss(1, global_position.x - side * 40.0, Vector2(side * 70.0, -760.0))      # tossed sky-high (he can steer back down)
		if NightWoods.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var s := SURFACE
		var k := fmod(_t, cycle())
		# the vent: a crusted ring on the tar
		b.circle(Vector2(0, s + 3), 18.0, Color("2a1d18"), 12)
		b.circle(Vector2(0, s + 3), 10.0, Color("12090a"), 10)
		if state == "rumble":
			var q := (k - quiet) / rumble
			var r := 8.0 + 14.0 * q
			b.circle(Vector2(sin(_t * 50.0) * 2.0 * q, s - r * 0.5), r, Color("1c1418"), 14)
			b.circle(Vector2(-r * 0.3, s - r * 0.8), r * 0.25, Color("ff9a3c", 0.7), 8)
			for j in 3:
				var a := _t * 6.0 + j * 2.1
				b.circle(Vector2(cos(a) * (18.0 + 6.0 * q), s - 4.0 - absf(sin(a * 1.7)) * 10.0 * q), 3.0, Color("1c1418"), 6)
		elif state == "blast":
			var top := jet_top()
			var w := WIDTH
			var col := PackedVector2Array()
			var n := 8
			for i in n + 1:
				var y := lerpf(s, top, float(i) / n)
				col.append(Vector2(-w * (1.0 - 0.35 * float(i) / n) + sin(_t * 30.0 + i) * 3.0, y))
			for i in range(n, -1, -1):
				var y2 := lerpf(s, top, float(i) / n)
				col.append(Vector2(w * (1.0 - 0.35 * float(i) / n) + sin(_t * 33.0 + i * 1.3) * 3.0, y2))
			b.poly(col, Color("1a1216"))
			# the hot core, and a crown of tar on top
			if s - top > 20.0:
				b.rect(Rect2(-7, top + 10, 14, s - top - 10), Color("ff7a2a", 0.85))
				b.rect(Rect2(-3, top + 14, 6, s - top - 14), Color("ffd27a", 0.9))
			for j in 5:
				b.circle(Vector2(-w + j * w * 0.5, top + sin(_t * 20.0 + j) * 4.0), 11.0, Color("1a1216"), 10)
		for bb in _blobs:
			b.circle(Vector2(bb[0], bb[1]), 6.0, Color("1a1216"), 8)
			b.circle(Vector2(bb[0] - 1.5, bb[1] - 1.5), 2.0, Color("ff9a3c"), 6)
		b.draw(self)

	## The warning glow (orange, swelling) and the burning core of the jet.
	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var o := global_position
		var k := fmod(_t, cycle())
		if state == "rumble":
			var q := (k - quiet) / rumble
			g.draw_circle(o + Vector2(0, SURFACE + 2.0), 14.0 + 26.0 * q, Color(1.0, 0.45, 0.1, 0.18 + 0.35 * q))
			g.draw_circle(o + Vector2(0, SURFACE - 6.0), 6.0 + 6.0 * q, Color(1.0, 0.75, 0.3, 0.5 * q))
		elif state == "blast":
			var top := jet_top()
			if SURFACE - top > 20.0:
				g.draw_line(o + Vector2(0, SURFACE), Vector2(o.x, top + 10.0), Color(1.0, 0.6, 0.2, 0.55), 18.0)
				g.draw_line(o + Vector2(0, SURFACE), Vector2(o.x, top + 14.0), Color(1.0, 0.85, 0.5, 0.8), 6.0)
		for bb in _blobs:
			g.draw_circle(o + Vector2(bb[0], bb[1]), 3.0, Color(1.0, 0.6, 0.25, 0.7))


## ================================================================ SNAPPER
class Snapper extends Area2D:
	## The Tar Snapper: a croc that lives in the big pool. Only its glowing eyes
	## show, gliding along the top. When he is over the pool, it glides under
	## him; bubbles ring the spot... and its jaws burst out of the tar — CHOMP —
	## tossing him up. Keep hopping and it snaps at empty logs. A whack on the
	## snout while its jaws are up sends it under, dizzy, for a while.
	const GLIDE := 250.0
	const WARN := 0.5
	var x0 := 0.0                  ## the pool's banks
	var x1 := 0.0
	var state := "lurk"            ## lurk, warn, snap, sink, dizzy
	var _t := 0.0
	var _st := 0.0
	var _cool := 0.3
	var _face := 1.0
	var _shape: CollisionShape2D

	func _ready() -> void:
		collision_layer = 4          # his swing finds it (when the jaws are up)
		collision_mask = 2
		z_index = 3
		_shape = CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(70, 120)
		_shape.shape = sh
		_shape.position = Vector2(0, SURFACE - 60.0)
		_shape.disabled = true
		add_child(_shape)
		add_to_group("glow")
		position.x = (x0 + x1) * 0.5

	func take_hit(_dmg: int, _from_dir: int) -> void:
		if state != "snap":
			return
		state = "dizzy"
		_st = 0.0
		_shape.set_deferred("disabled", true)
		var pop := Treasure.FloatText.new()
		pop.text = "BONK!"
		pop.position = Vector2(position.x - 18, SURFACE - 140)
		get_parent().add_child(pop)

	## How far out of the tar the jaws are, 0..1.
	func jaw_up() -> float:
		match state:
			"snap":
				return clampf(_st / 0.1, 0.0, 1.0)
			"sink":
				return clampf(1.0 - _st / 0.35, 0.0, 1.0)
		return 0.0

	func _physics_process(delta: float) -> void:
		_t += delta
		_st += delta
		_cool = maxf(_cool - delta, 0.0)
		var p := get_tree().get_first_node_in_group("player") as CaveMan
		var over := p != null and not p.dead and p.global_position.x > x0 and p.global_position.x < x1
		match state:
			"lurk":
				# under him — or, while he is in the air, under where he will come down
				var lead := 0.0 if p == null or p.is_on_floor() else p.velocity.x * 0.35
				var goal := p.global_position.x + lead if over else (x0 + x1) * 0.5 + sin(_t * 0.4) * (x1 - x0) * 0.35
				var d := goal - position.x
				position.x += clampf(d, -GLIDE * delta, GLIDE * delta)
				if absf(d) > 2.0:
					_face = signf(d)
				if over and p.is_on_floor() and absf(d) < 26.0 and _cool <= 0.0:
					state = "warn"
					_st = 0.0
			"warn":
				if p != null and absf(p.global_position.x - position.x) > 2.0:
					_face = signf(p.global_position.x - position.x)     # the bottom jaw toward him
				if not over:
					state = "lurk"
				elif _st >= WARN:
					state = "snap"
					_st = 0.0
					_shape.set_deferred("disabled", false)
			"snap":
				if over and p.global_position.y > SURFACE - 70.0 and absf(p.global_position.x - position.x) < 48.0 and _st > 0.04:
					p.hurt_toss(1, position.x - float(p.facing) * 30.0, Vector2(float(p.facing) * 80.0, -800.0))    # CHOMP — and up he goes
				if _st > 0.45:
					state = "sink"
					_st = 0.0
					_shape.set_deferred("disabled", true)
			"sink":
				if _st > 0.35:
					state = "lurk"
					_cool = 1.4
			"dizzy":
				if _st > 4.0:
					state = "lurk"
					_cool = 1.0
		position.x = clampf(position.x, x0 + 30.0, x1 - 30.0)
		if NightWoods.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var s := SURFACE
		var f := _face
		if state == "warn":
			# the tar bulges and boils where it will come up
			var q := _st / WARN
			b.circle(Vector2(0, s + 2), 20.0 + 18.0 * q, Color("1c1a20"), 16)
			for j in 6:
				var a := _t * 5.0 + j * TAU / 6.0
				b.circle(Vector2(cos(a) * (30.0 + 10.0 * q), s - 3.0 - absf(sin(a * 2.0)) * 6.0), 3.5, Color("1c1a20"), 6)
		var up := jaw_up()
		if up > 0.0:
			# the croc lunges straight up out of the tar: a scaly neck, and long
			# jaws gaping open — the top jaw (with the eye) thrown back, the
			# bottom one toward him
			var h := 130.0 * up
			var green := Color("3d5a2a")
			var dark := Color("2b4220")
			var pv := Vector2(0, s - h * 0.45)
			b.poly(PackedVector2Array([Vector2(-24, s + 4), Vector2(-17, pv.y + 4), Vector2(17, pv.y + 4), Vector2(24, s + 4)]), green)
			b.poly(PackedVector2Array([Vector2(f * 6.0, s + 4), Vector2(f * 6.0, pv.y + 8), Vector2(f * 16.0, pv.y + 8), Vector2(f * 22.0, s + 4)]), Color("8a9a5a"))
			for j in 4:
				var ry := lerpf(s - 4.0, pv.y + 10.0, j / 3.0)
				b.tri(Vector2(-f * 18.0, ry), Vector2(-f * 27.0, ry - 6.0), Vector2(-f * 17.0, ry - 12.0), dark)
			var tip_u := pv + Vector2(-f * 16.0, -h * 0.62)
			var tip_l := pv + Vector2(f * 34.0, -h * 0.42)
			# the mouth between them
			b.poly(PackedVector2Array([pv, tip_u + Vector2(f * 5.0, 6), tip_l + Vector2(-4.0 * f, 5)]), Color("b8404f"))
			b.poly(PackedVector2Array([pv + Vector2(0, -4), tip_u.lerp(pv, 0.35) + Vector2(f * 6.0, 0), tip_l.lerp(pv, 0.35)]), Color("8c2f3a"))
			for jaw in [[tip_u, 30.0, 12.0, tip_l], [tip_l, 20.0, 7.0, tip_u]]:
				var tip: Vector2 = jaw[0]
				var along := (tip - pv).normalized()
				var side := along.orthogonal()
				var wb: float = jaw[1]
				var wt: float = jaw[2]
				b.poly(PackedVector2Array([pv + side * wb * 0.5, tip + side * wt * 0.5 + along * 4.0, tip - side * wt * 0.5 + along * 4.0, pv - side * wb * 0.5]), green)
				# teeth along the inner edge, pointing into the mouth
				var other: Vector2 = jaw[3]
				var inner := side if side.dot(other - pv) > 0.0 else -side
				for k in 5:
					var q := 0.3 + k * 0.15
					var at := pv.lerp(tip, q) + inner * lerpf(wb, wt, q) * 0.5
					b.tri(at - along * 3.0, at + along * 3.0, at + inner * 7.0, Color("f2ead2"))
			# nostrils on the snout's tip; the eye bulging on top of the head
			b.circle(tip_u + Vector2(-f * 3.0, -2), 2.5, dark, 6)
			var eye := pv.lerp(tip_u, 0.28) + Vector2(-f * 14.0, 0)
			b.circle(eye, 8.0, green, 10)
			b.circle(eye, 5.5, Color("e8d64a"), 10)
			b.rect(Rect2(eye.x - 1.2, eye.y - 4.5, 2.4, 9), Color.BLACK)
			# tar dripping off it
			for j2 in 3:
				var dx := -14.0 + j2 * 14.0
				b.circle(Vector2(dx, s - 6.0 - fmod(_t * 60.0 + j2 * 13.0, 30.0)), 3.0, Color("1c1a20"), 6)
		elif state != "dizzy":
			# just the bumps of its eyes and snout on the tar
			var y := s - 3.0 + sin(_t * 2.0) * 1.5
			b.circle(Vector2(-8.0 * f, y), 7.0, Color("27331f"), 10)
			b.circle(Vector2(6.0 * f, y), 7.0, Color("27331f"), 10)
			b.rect(Rect2(f * 24.0 - 6.0, y + 1.0, 12, 3), Color("27331f"))
			# ripples behind it as it glides
			for j in 3:
				var q2 := fmod(_t * 1.5 + j / 3.0, 1.0)
				b.line(Vector2(-f * (20.0 + q2 * 50.0), s + 1.0), Vector2(-f * (8.0 + q2 * 40.0), s + 1.0), Color("6a6680", 0.5 * (1.0 - q2)), 2.0)
		b.draw(self)

	## Its eyes glow yellow on the dark tar — that's how he sees it coming.
	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var o := Vector2(global_position.x, SURFACE)
		var up := jaw_up()
		if up > 0.0:
			var h := 130.0 * up
			g.draw_circle(o + Vector2(-_face * 18.5, -h * 0.62), 5.0, Color("fff36a"))   # the eye on its head
		elif state != "dizzy":
			var y := -5.0 + sin(_t * 2.0) * 1.5
			g.draw_circle(o + Vector2(-8.0 * _face, y), 3.0, Color("e8ff5a", 0.95))
			g.draw_circle(o + Vector2(6.0 * _face, y), 3.0, Color("e8ff5a", 0.95))
			if state == "warn":
				var q := _st / WARN
				g.draw_circle(o + Vector2(0, 2), 30.0 + 20.0 * q, Color(0.9, 1.0, 0.3, 0.12 + 0.25 * q))
		else:
			for j in 3:
				var a := _t * 4.0 + j * TAU / 3.0
				g.draw_circle(o + Vector2(cos(a) * 16.0, -14.0 + sin(a) * 4.0), 3.0, Color("ffe066", 0.8))
