## Thunder Canyon: the deep canyon between the Tar Pits (Nutmeg's creek) and
## the great tree, where the ropes MOVE.
##   Puffball Drift     vines under giant puffball seeds drifting to and fro
##   Pterosaur Express  vines in the claws of pterosaurs flying back and forth:
##                      a ride, and a swap in mid-air to the next one
##   (a rest ledge with a fire)
##   Thunder Cliffs     a storm sends boulders rolling down the steps at him
class_name Canyon
extends RefCounted


## ================================================================ CARRY VINE
class CarryVine extends NightWoods.Vine:
	## A vine hanging from something that moves. Its carrier writes how fast it
	## is going into `carry`; letting go, he keeps that speed too (CaveMan._swing).
	var carry := Vector2.ZERO

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


## A carrier: flies or drifts to and fro between x0 and x1, with a vine below.
class Carrier extends Node2D:
	var x0 := 0.0
	var x1 := 400.0
	var speed := 70.0
	var bob := 16.0              ## up-and-down drift
	var vine_len := 200.0
	var phase := 0.0             ## 0..1: where in its round trip it starts
	var vine: CarryVine
	var _t := 0.0
	var _home_y := 0.0
	var _dir := 1.0

	func _ready() -> void:
		_home_y = position.y
		var span := x1 - x0
		var s := fmod(phase, 1.0) * 2.0 * span
		if s <= span:
			position.x = x0 + s
			_dir = 1.0
		else:
			position.x = x1 - (s - span)
			_dir = -1.0
		_t = phase * 10.0
		vine = CarryVine.new()
		vine.length = vine_len
		vine.position = _hang()
		add_child(vine)

	func _hang() -> Vector2:
		return Vector2(0, 12)

	func _physics_process(delta: float) -> void:
		_t += delta
		var before := global_position
		position.x += _dir * speed * delta
		if position.x >= x1:
			position.x = x1
			_dir = -1.0
		elif position.x <= x0:
			position.x = x0
			_dir = 1.0
		position.y = _home_y + sin(_t * 1.3) * bob
		vine.carry = (global_position - before) / maxf(delta, 0.0001)
		if NightWoods.near_view(self):
			queue_redraw()


## ================================================================ PUFFBALL
class Puffball extends Carrier:
	## A giant puffball seed — a ball of silver fluff the size of a hut —
	## drifting slowly on the wind with a vine trailing from it.
	func _draw() -> void:
		var b := Batch.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = int(x0)
		# the tufts: rays of fluff all round, each with a little seed at the tip
		for k in 22:
			var a := TAU * k / 22.0 + sin(_t * 0.8 + k) * 0.05
			var r := 44.0 + rng.randf_range(-4.0, 6.0)
			b.line(Vector2.ZERO, Vector2.from_angle(a) * r, Color("c9d3e6", 0.55), 2.0)
			b.circle(Vector2.from_angle(a) * r, 5.0, Color("e6ecf7", 0.8), 8)
		b.circle(Vector2.ZERO, 26.0, Color("dfe6f2", 0.85), 16)
		b.circle(Vector2(-8, -8), 10.0, Color.WHITE, 12)
		b.circle(Vector2(0, 14), 6.0, Color("8a7a5e"), 8)        # where the vine is tied
		b.draw(self)

	func _hang() -> Vector2:
		return Vector2(0, 16)


## ================================================================ PTEROSAUR
class Pterosaur extends Carrier:
	## A great pterosaur gliding back and forth across the canyon, a vine
	## clutched in its feet. Faster than the puffballs, and it dips as it flies.
	func _ready() -> void:
		super._ready()
		bob = 22.0

	func _hang() -> Vector2:
		return Vector2(0, 22)

	func _draw() -> void:
		var b := Batch.new()
		var f := _dir                 # facing the way it flies
		var flap := sin(_t * 5.0) * 0.5
		var skin := Color("6e5a4a")
		var wing := Color("8a6e58")
		# the two great wings: leathery triangles, flapping
		for s in [-1.0, 1.0]:
			var tip := Vector2(s * 120.0, -20.0 - flap * 60.0 * s * s)
			b.poly(PackedVector2Array([Vector2(-10 * f, -4), tip, Vector2(s * 70.0, 10), Vector2(12 * f, 6)]), wing)
			b.line(Vector2(0, -2), tip, skin.darkened(0.2), 2.5)
		# the body, the long beak and the crest pointing back
		b.circle(Vector2(0, 2), 13.0, skin, 12)
		b.circle(Vector2(16 * f, -8), 9.0, skin, 10)
		b.tri(Vector2(22 * f, -10), Vector2(62 * f, -4), Vector2(22 * f, -4), Color("c9a77a"))
		b.tri(Vector2(10 * f, -12), Vector2(-26 * f, -26), Vector2(12 * f, -4), skin.darkened(0.15))
		b.circle(Vector2(19 * f, -10), 2.4, Color("ffd36a"), 6)
		# feet, clutching the vine
		b.line(Vector2(-3, 12), Vector2(0, 22), Color("3e2e22"), 2.5)
		b.line(Vector2(4, 12), Vector2(0, 22), Color("3e2e22"), 2.5)
		b.draw(self)


## ================================================================ THE STORM
class Boulder extends Area2D:
	## A boulder shaken loose by thunder, rolling left down the cliff steps.
	## It hurts what it hits. On the flat, jump it; off each step's edge it
	## leaps, so hugging the wall under a step is safe too.
	const R := 30.0
	var speed := 230.0
	var steps: Array = []        ## [x, top, w] of the cliff steps
	var ground := 600.0
	var end_x := 0.0
	var _vy := 0.0
	var _spin := 0.0
	var _was_floor := -1.0      ## the floor under it last frame: a drop means it left a step's edge

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = R - 4.0
		cs.shape = c
		add_child(cs)

	## The top of the ground under x: a cliff step, or the canyon road.
	func _floor_at(x: float) -> float:
		var top := ground
		for s in steps:
			if x >= float(s[0]) and x <= float(s[0]) + float(s[2]):
				top = minf(top, float(s[1]))
		return top

	func _physics_process(delta: float) -> void:
		position.x -= speed * delta
		_spin -= speed * delta / R
		# off a step's edge it LEAPS: it sails over anyone hugging the wall below
		var under := _floor_at(position.x)
		if _was_floor >= 0.0 and under > _was_floor + 20.0 and _vy >= 0.0:
			_vy = -260.0
		_was_floor = under
		_vy += 1500.0 * delta
		position.y += _vy * delta
		var fl := _floor_at(position.x) - R
		if position.y >= fl:
			position.y = fl
			_vy = -absf(_vy) * 0.35 if absf(_vy) > 200.0 else 0.0    # a bounce off each step
		var p := get_tree().get_first_node_in_group("player") as CaveMan
		if p != null and not p.dead and overlaps_body(p):
			p.hurt(1, position.x + 40.0)
		if position.x < end_x:
			var dust := Critter.DeathPop.new()
			dust.dust = true
			dust.position = Vector2(position.x, _floor_at(position.x))
			get_parent().add_child(dust)
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		b.set_xf(Transform2D(_spin, Vector2.ZERO))
		b.circle(Vector2.ZERO, R, Color("5b5650"), 18)
		b.circle(Vector2(-6, -6), R * 0.7, Color("6f6a62"), 14)
		b.line(Vector2(-14, -4), Vector2(8, 10), Color("3e3a35"), 2.5)
		b.line(Vector2(4, -16), Vector2(12, -2), Color("3e3a35"), 2.0)
		b.draw(self)


class Storm extends Node:
	## Thunder over the cliffs: while he is on them, every few seconds the sky
	## flashes, there's a BOOM, and a boulder comes rolling down from the top.
	var x0 := 0.0                ## the stretch where the storm is felt
	var x1 := 0.0
	var spawn := Vector2.ZERO
	var end_x := 0.0
	var every := 2.6
	var steps: Array = []
	var player: CaveMan
	var _next := 1.2
	var _flash: ColorRect
	var _flash_t := 0.0

	func _ready() -> void:
		var layer := CanvasLayer.new()
		layer.layer = 5
		add_child(layer)
		_flash = ColorRect.new()
		_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		_flash.color = Color(0.85, 0.9, 1.0, 0.0)
		_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_flash)

	func _physics_process(delta: float) -> void:
		_flash_t = maxf(_flash_t - delta, 0.0)
		_flash.color.a = 0.45 * _flash_t / 0.25
		if player == null or player.dead or player.talking:
			return
		var x := player.global_position.x
		if x < x0 or x > x1:
			_next = 1.2
			return
		_next -= delta
		if _next <= 0.0:
			_next = every
			_flash_t = 0.25
			var boom := Treasure.FloatText.new()
			boom.text = "BOOM!"
			boom.position = spawn + Vector2(-20, -90)
			get_parent().add_child(boom)
			var rock := Boulder.new()
			rock.position = spawn
			rock.steps = steps
			rock.end_x = end_x
			get_parent().add_child(rock)
