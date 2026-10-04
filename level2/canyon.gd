## Thunder Canyon: the deep canyon between the Tar Pits (Nutmeg's creek) and
## the great tree.
##   Sky Stones   flying rocks with vines hanging from them — drifting, bobbing,
##                or circling — all keeping one rhythm, so each swings close to
##                the next just when he wants to jump (they never touch)
##   (a rest ledge with a fire)
##   Floating rocks at different heights to hop across — and once he's on his
##   way, bats dive straight down at him from the sky
class_name Canyon
extends RefCounted


## ================================================================ CARRY VINE
class CarryVine extends NightWoods.Vine:
	## A vine hanging from something that moves. Its carrier writes how fast it
	## is going into `carry`; letting go, he keeps that speed too (CaveMan._swing).
	var carry := Vector2.ZERO

	func _ready() -> void:
		super._ready()
		# a wider catch than a still vine's: these are moving targets
		var cs := _grab.get_child(0) as CollisionShape2D
		(cs.shape as CircleShape2D).radius = 70.0

	func _draw() -> void:
		var bt := Batch.new()
		var end := Vector2(sin(angle), cos(angle)) * length
		var pts := PackedVector2Array()
		for i in 11:
			var k := i / 10.0
			pts.append(end * k + Vector2(sin(k * PI) * 5.0 * (1.0 - absf(angle)), 0))
		bt.polyline(pts, Pal.VINE.darkened(0.2), 5.0)
		bt.polyline(pts, Pal.VINE, 3.0)
		for i in range(2, 10, 3):
			var p: Vector2 = pts[i]
			bt.poly(PackedVector2Array([p, p + Vector2(9, -4), p + Vector2(12, 2), p + Vector2(3, 4)]), Pal.CANOPY.lightened(0.15))
		bt.circle(end, 6.0, Pal.VINE.darkened(0.3), 10)
		bt.draw(self)


## ================================================================ SKY STONE
class SkyStone extends Node2D:
	## A flying rock with a vine hanging from it. Each one is a little world:
	## a mossy top with a tiny tree, a crystal or a ring of standing stones,
	## roots trailing underneath, a trickle of water falling off its lip, and
	## runes that glow faintly in the dark.
	## It moves in its own space only:
	##   "drift"  side to side       "bob"  up and down
	##   "orbit"  round in a loop, carrying the vine round with it
	## All the stones share one beat (period) so their closest moments come in a
	## wave along the line; `beat` is where in the beat this one starts.
	var kind := "drift"
	var amp := 60.0
	var period := 6.0
	var beat := 0.0              ## radians at t = 0
	var vine_len := 200.0
	var look := 0                ## which little world is on top
	var vine: CarryVine
	var _home := Vector2.ZERO
	var _t := 0.0
	var _drops: Array = []

	func _ready() -> void:
		_home = position
		position = _home + _offset(0.0)
		vine = CarryVine.new()
		vine.length = vine_len
		vine.position = Vector2(0, 34)
		add_child(vine)
		add_to_group("glow")
		for i in 4:
			_drops.append(randf())

	func _offset(t: float) -> Vector2:
		var a := TAU * t / period + beat
		match kind:
			"bob":
				return Vector2(0, sin(a) * amp)
			"orbit":
				return Vector2(cos(a), sin(a)) * amp
		return Vector2(sin(a) * amp, sin(a * 2.0) * 5.0)

	func _physics_process(delta: float) -> void:
		_t += delta
		var before := global_position
		position = _home + _offset(_t)
		vine.carry = (global_position - before) / maxf(delta, 0.0001)
		for i in _drops.size():
			_drops[i] = fmod(float(_drops[i]) + delta * 0.9, 1.0)
		if NightWoods.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = int(_home.x)
		# the rock: a flat-topped chunk, jagged underneath, darker below
		var body := PackedVector2Array([Vector2(-52, -10), Vector2(52, -10)])
		for k in range(8, -1, -1):
			var q := k / 8.0
			var d := 34.0 * (1.0 - pow(absf(q - 0.5) * 2.0, 1.4)) * rng.randf_range(0.8, 1.0)
			body.append(Vector2(-52.0 + 104.0 * q, -6.0 + d))
		b.poly(body, Color("4b4f63"))
		var lit := PackedVector2Array([Vector2(-52, -10), Vector2(52, -10)])
		for k in range(8, -1, -1):
			var q2 := k / 8.0
			lit.append(Vector2(-52.0 + 104.0 * q2, -8.0 + 14.0 * (1.0 - pow(absf(q2 - 0.5) * 2.0, 1.6))))
		b.poly(lit, Color("676c86"))
		# strata and a few pebbles
		b.line(Vector2(-40, 6), Vector2(36, 9), Color("3c3f51"), 2.0)
		b.circle(Vector2(-20, 14), 4.0, Color("5a5e75"), 8)
		b.circle(Vector2(18, 18), 3.0, Color("5a5e75"), 8)
		# roots trailing, and the tie-point of the vine
		for s in [-1.0, 1.0]:
			b.polyline(PackedVector2Array([Vector2(s * 26.0, 14), Vector2(s * 30.0, 30), Vector2(s * 24.0, 44)]), Color("3b2f26"), 2.0)
		b.circle(Vector2(0, 30), 6.0, Color("3b2f26"), 10)
		# the mossy top
		b.rect(Rect2(-54, -14, 108, 7), Color("2f5a3a"))
		b.rect(Rect2(-54, -14, 108, 3), Color("5c9a5e"))
		# the little world on top
		match look % 3:
			0:      # a tiny twisted tree
				b.line(Vector2(-14, -14), Vector2(-10, -40), Color("4a3828"), 4.0)
				b.circle(Vector2(-12, -44), 13.0, Color("2c5236"), 12)
				b.circle(Vector2(-4, -48), 9.0, Color("3f7a48"), 10)
			1:      # a glowing crystal cluster
				b.tri(Vector2(6, -14), Vector2(12, -44), Vector2(18, -14), Color("6fd3e8"))
				b.tri(Vector2(14, -14), Vector2(24, -34), Vector2(28, -14), Color("a6ecf7"))
				b.tri(Vector2(-2, -14), Vector2(2, -28), Vector2(8, -14), Color("4fb4cf"))
			2:      # a ring of standing stones, like a tiny shrine
				for k in 3:
					b.rect(Rect2(-24.0 + k * 18.0, -30, 8, 16), Color("8a8fa6"))
				b.rect(Rect2(-26, -34, 52, 5), Color("8a8fa6"))
		# water trickling off the lip, in drops
		for i in _drops.size():
			var q3: float = _drops[i]
			b.circle(Vector2(44, -6 + q3 * 90.0), 2.2 * (1.0 - q3 * 0.6), Color("9cc3e0", 0.8 * (1.0 - q3)), 6)
		b.draw(self)

	## The runes glow faintly through the dark, so the stones read at night.
	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var o := global_position
		var pulse := 0.5 + 0.5 * sin(_t * 2.0 + _home.x)
		g.draw_line(o + Vector2(-50, -13), o + Vector2(50, -13), Color("9fd6a6", 0.55), 3.0)
		for k in 5:
			var x := -36.0 + k * 18.0
			g.draw_circle(o + Vector2(x, 6), 2.0, Color("8fe3ff", 0.35 + 0.4 * pulse))
		if look % 3 == 1:
			g.draw_circle(o + Vector2(14, -26), 18.0, Color("6fd3e8", 0.12 + 0.08 * pulse))


## ================================================================ FLOAT ROCK
class FloatRock extends AnimatableBody2D:
	## A flat flying rock to stand on (one-way: jump up through it). Some bob
	## gently, carrying him with them.
	var w := 120.0
	var bob := 0.0
	var _home := Vector2.ZERO
	var _t := 0.0

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		sync_to_physics = true
		_home = position
		_t = randf() * 6.0
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(w, 14)
		cs.shape = sh
		cs.position = Vector2(w * 0.5, 7)
		cs.one_way_collision = true
		add_child(cs)
		add_to_group("glow")

	func _physics_process(delta: float) -> void:
		_t += delta
		position = _home + Vector2(0, sin(_t * 1.2) * bob)
		if NightWoods.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = int(_home.x)
		var body := PackedVector2Array([Vector2(0, 0), Vector2(w, 0)])
		var n := maxi(int(w / 18.0), 4)
		for k in range(n, -1, -1):
			var q := float(k) / n
			body.append(Vector2(w * q, 10.0 + 30.0 * (1.0 - pow(absf(q - 0.5) * 2.0, 1.3)) * rng.randf_range(0.75, 1.0)))
		b.poly(body, Color("4b4f63"))
		b.rect(Rect2(0, 0, w, 8), Color("6a6f88"))
		b.rect(Rect2(0, 0, w, 3), Color("a3a9c4"))
		b.line(Vector2(w * 0.2, 12), Vector2(w * 0.45, 20), Color("3c3f51"), 2.0)
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var o := global_position
		g.draw_line(o + Vector2(3, 0.5), o + Vector2(w - 3, 0.5), Color("c9d6ff", 0.5), 2.0)


## ================================================================ DIVE BATS
class DiveBat extends Area2D:
	## A bat that drops straight down out of the sky onto a rock — a shadow on
	## the rock and a screech mark above are the warning — then flaps back up.
	## A bonk with the club sends it tumbling away.
	signal done
	var x := 0.0
	var top := -260.0            ## where it falls from (above the screen)
	var bottom := 820.0          ## and to
	var warn := 0.7
	var mark_y := 600.0          ## where the shadow shows (the rock under it)
	var state := "warn"          ## warn, dive, climb, bonked
	var _t := 0.0
	var _vel := Vector2.ZERO

	func _ready() -> void:
		collision_layer = 4          # his swing finds it
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(34, 40)
		cs.shape = sh
		add_child(cs)
		position = Vector2(x, top)
		add_to_group("glow")

	func take_hit(_dmg: int, from_dir: int) -> void:
		if state == "bonked" or state == "warn":
			return
		state = "bonked"
		_vel = Vector2(from_dir * 420.0, -380.0)
		var pop := Treasure.FloatText.new()
		pop.text = "BONK!"
		pop.position = global_position + Vector2(-18, -30)
		get_parent().add_child(pop)

	func _physics_process(delta: float) -> void:
		_t += delta
		match state:
			"warn":
				if _t >= warn:
					state = "dive"
			"dive":
				position.y += 1050.0 * delta
				if position.y >= bottom:
					state = "climb"
			"climb":
				position.y -= 520.0 * delta
				position.x += sin(_t * 9.0) * 2.0
				if position.y <= top:
					done.emit()
					queue_free()
					return
			"bonked":
				_vel.y += 900.0 * delta
				position += _vel * delta
				rotation += 12.0 * delta
				if _t > 3.0 or position.y > bottom + 200.0:
					done.emit()
					queue_free()
					return
		if state in ["dive", "climb"]:
			var p := get_tree().get_first_node_in_group("player") as CaveMan
			if p != null and not p.dead and overlaps_body(p):
				p.hurt(1, global_position.x)
		queue_redraw()

	func _draw() -> void:
		if state == "warn":
			return
		var b := Batch.new()
		var flap := sin(_t * 30.0) * 0.6 if state != "dive" else 0.0
		var col := Color("3a2f3a")
		# wings folded tight when diving, beating when climbing
		for s in [-1.0, 1.0]:
			var tip := Vector2(s * (14.0 if state == "dive" else 30.0), -14.0 - flap * 14.0 * s * s)
			b.tri(Vector2(s * 4.0, -4), tip, Vector2(s * 10.0, 8), col)
		b.circle(Vector2(0, 0), 9.0, col, 10)
		b.tri(Vector2(-6, -6), Vector2(-4, -15), Vector2(-1, -7), col)
		b.tri(Vector2(6, -6), Vector2(4, -15), Vector2(1, -7), col)
		b.draw(self)

	## The warning, drawn over the dark: a growing shadow on the rock, a screech
	## mark high above; then the bat's red eyes as it comes.
	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var o := global_position
		if state == "warn" or (state == "dive" and o.y < mark_y - 40.0):
			var k := clampf(_t / warn, 0.0, 1.0)
			g.draw_circle(Vector2(x, mark_y - 2.0), 10.0 + 14.0 * k, Color(0.1, 0.0, 0.1, 0.55))
			if state == "warn":
				g.draw_string(ThemeDB.fallback_font, Vector2(x - 6, mark_y - 150.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 0.5, 0.4, 0.4 + 0.6 * k))
		if state != "warn":
			g.draw_circle(o + Vector2(-3, -2), 1.8, Color("ff6a5a"))
			g.draw_circle(o + Vector2(3, -2), 1.8, Color("ff6a5a"))


class BatSky extends Node:
	## Over the floating rocks: once he has hopped onto a rock past the first,
	## bats start dropping on him — one at a time, every few seconds, onto the
	## rock he stands on (or toward where he's heading). Moving on is the defence.
	var x0 := 0.0
	var x1 := 0.0
	var every := 1.7
	var rocks: Array = []        ## the FloatRocks, left to right
	var player: CaveMan
	var level: Node2D
	var started := false
	var _next := 0.6
	var _bat: DiveBat = null

	func _rock_under(x: float) -> FloatRock:
		for r in rocks:
			var fr: FloatRock = r
			if x >= fr.global_position.x - 10.0 and x <= fr.global_position.x + fr.w + 10.0:
				return fr
		return null

	func _physics_process(delta: float) -> void:
		if player == null or player.dead or player.talking:
			return
		var px := player.global_position.x
		if px < x0 or px > x1:
			return
		if not started:
			# "when things get easy": he has made it onto the second rock
			if rocks.size() > 1 and player.is_on_floor() and px > (rocks[1] as FloatRock).global_position.x - 10.0:
				started = true
				if level.has_method("_bats_begin"):
					level._bats_begin()
			return
		if _bat != null and is_instance_valid(_bat):
			return
		_next -= delta
		if _next > 0.0:
			return
		_next = every
		# aim at where he'll be a moment from now, on the rock under that
		var aim := px + player.velocity.x * 0.5
		var r := _rock_under(aim)
		var bat := DiveBat.new()
		bat.x = clampf(aim, x0, x1)
		bat.mark_y = r.global_position.y if r != null else player.global_position.y
		bat.top = player.global_position.y - 520.0
		bat.bottom = player.global_position.y + 260.0
		level.add_child(bat)
		_bat = bat
