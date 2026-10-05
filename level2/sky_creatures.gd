## Weird things that live up in the sky lanes.
##   DriftJelly  a glowing jellyfish floating in the air: land on its bell and
##               it squashes and BOUNCES him high; touch the trailing
##               tentacles from below and they sting
##   SkyRay      a giant gliding manta: it sails slowly back and forth across
##               a gap, and he can stand on its back and ride it over
class_name SkyCreatures
extends RefCounted

const JELLY_LOOKS := [
	[Color("6fe8ff"), Color("b9f6ff")],     # sky blue
	[Color("ff7ad9"), Color("ffc4ee")],     # pink
	[Color("b18cff"), Color("ddd0ff")],     # violet
]


## ================================================================ JELLY
class DriftJelly extends Area2D:
	const BOUNCE := -1050.0
	var look := 0
	var bob := 22.0
	var drift := 0.0              ## side to side, px
	var _home := Vector2.ZERO
	var _t := 0.0
	var _squash := 0.0
	var _sting := 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var bell := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 28.0
		bell.shape = c
		add_child(bell)
		var legs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(34, 40)
		legs.shape = r
		legs.position = Vector2(0, 40)
		add_child(legs)
		add_to_group("glow")
		_home = position
		_t = randf() * 6.0
		z_index = 2

	func _physics_process(delta: float) -> void:
		_t += delta
		_squash = maxf(_squash - delta * 3.0, 0.0)
		_sting = maxf(_sting - delta, 0.0)
		position = _home + Vector2(sin(_t * 0.5) * drift, sin(_t * 1.9) * bob)
		var p := get_tree().get_first_node_in_group("player") as CaveMan
		if p != null and not p.dead and overlaps_body(p):
			var feet := p.global_position.y
			if feet < global_position.y + 4.0 and p.velocity.y > -60.0:
				# on the bell: squash, and away he goes
				p.launch(BOUNCE)
				_squash = 1.0
				FX.burst(get_parent(), global_position + Vector2(0, -20), "sparks")
			elif feet > global_position.y + 4.0 and _sting <= 0.0:
				# up into the tentacles: a sting
				_sting = 0.8
				var side := 1.0 if p.global_position.x >= global_position.x else -1.0
				p.hurt_toss(1, global_position.x, Vector2(side * 180.0, 120.0))
		if LevelBase.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var look_c: Array = SkyCreatures.JELLY_LOOKS[look]
		var col: Color = look_c[0]
		var light: Color = look_c[1]
		var sq := 1.0 - 0.35 * _squash
		var wide := 1.0 + 0.3 * _squash
		var pulse := 1.0 + 0.06 * sin(_t * 3.0)
		# tentacles: wavy ribbons trailing under the bell
		for i in 5:
			var x0 := (-16.0 + i * 8.0) * wide
			var pts := PackedVector2Array()
			for j in 8:
				var q := j / 7.0
				pts.append(Vector2(x0 + sin(_t * 3.0 + i + q * 4.0) * 5.0 * q, 6.0 + q * (46.0 + (i % 2) * 14.0)))
			b.polyline(pts, Color(col, 0.55 if i % 2 == 0 else 0.4), 3.0 - (i % 2))
		# the bell: a dome, see-through, with a lighter rim and a glowing heart
		var bell := PackedVector2Array()
		for j in 17:
			var a := PI + PI * j / 16.0
			bell.append(Vector2(cos(a) * 30.0 * wide * pulse, sin(a) * 26.0 * sq * pulse))
		for j in 7:
			var q2 := j / 6.0
			bell.append(Vector2(lerpf(30.0, -30.0, q2) * wide * pulse, 4.0 + sin(q2 * PI * 3.0 + _t * 4.0) * 3.0))
		b.poly(bell, Color(col, 0.55))
		b.ellipse(Vector2(0, -10 * sq), 18.0 * wide, 11.0 * sq, Color(light, 0.45))
		b.ellipse(Vector2(0, -8 * sq), 7.0, 6.0 * sq, Color(1, 1, 1, 0.75))
		b.ellipse(Vector2(-12, -16 * sq) * wide, 5.0, 3.0, Color(1, 1, 1, 0.6))
		# two little eyes: it's alive
		b.circle(Vector2(-7, -2) * Vector2(wide, sq), 2.2, Color("102030"), 6)
		b.circle(Vector2(7, -2) * Vector2(wide, sq), 2.2, Color("102030"), 6)
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var look_c: Array = SkyCreatures.JELLY_LOOKS[look]
		var o := global_position
		g.draw_circle(o + Vector2(0, -6), 40.0 + 6.0 * sin(_t * 3.0), Color(look_c[0], 0.2 + 0.25 * _squash))
		g.draw_circle(o + Vector2(0, -8), 8.0, Color(1, 1, 1, 0.6))
		for i in 3:
			g.draw_circle(o + Vector2(-10.0 + i * 10.0, 30.0 + sin(_t * 2.0 + i) * 8.0), 3.0, Color(look_c[1], 0.7))


## ================================================================ SKY RAY
class SkyRay extends AnimatableBody2D:
	## A manta the size of a hut, gliding in long, slow sweeps between x0 and
	## x1. Its back is a one-way platform: jump up onto it and ride.
	var x0 := 0.0
	var x1 := 400.0
	var crossing := 6.0          ## seconds for one sweep across
	var _t := 0.0
	var _base_y := 0.0
	var _face := 1.0

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		sync_to_physics = true
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(170, 12)
		cs.shape = sh
		cs.position = Vector2(0, 6)
		cs.one_way_collision = true
		add_child(cs)
		add_to_group("glow")
		_base_y = position.y
		position.x = x0
		z_index = 1

	func _physics_process(delta: float) -> void:
		_t += delta
		var ph := _t / crossing * PI
		var k := 0.5 - 0.5 * cos(ph)               # eases into each turn
		var was := position.x
		position = Vector2(lerpf(x0, x1, k), _base_y + sin(ph * 2.0) * 16.0)
		if absf(position.x - was) > 0.01:
			_face = signf(position.x - was)
		if LevelBase.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var f := _face
		var flap := sin(_t * 1.6) * 10.0
		var body := Color("3f3c86")
		var belly := Color("7d86d0")
		# the wings: wide, swept back, tips curling up and down with the flap
		var wing := PackedVector2Array([Vector2(f * 70, 2), Vector2(f * 30, -6), Vector2(-f * 10, -4), Vector2(-f * 70, 0),
			Vector2(-f * 118, -10 - flap), Vector2(-f * 100, 8), Vector2(-f * 40, 22), Vector2(f * 20, 22), Vector2(f * 100, 8),
			Vector2(f * 118, -10 + flap)])
		b.poly(wing, body)
		var rim := wing.duplicate()
		rim.append(wing[0])
		b.polyline(rim, Color("a9b8ff", 0.55), 2.0)          # a pale rim: it reads against the night
		b.poly(PackedVector2Array([Vector2(-f * 60, 8), Vector2(f * 60, 8), Vector2(f * 30, 20), Vector2(-f * 30, 20)]), belly)
		# its head: two curling fins and eyes, at the front
		for s in [-1.0, 1.0]:
			b.line(Vector2(f * 66, 4.0 * s), Vector2(f * 86, 10.0 * s + 4.0), body, 6.0)
		b.circle(Vector2(f * 58, -2), 3.0, Color("ffe14a"), 6)
		# the tail, long and whippy
		var tail := PackedVector2Array()
		for j in 8:
			var q := j / 7.0
			tail.append(Vector2(-f * (70.0 + q * 90.0), 8.0 + sin(_t * 2.0 + q * 3.0) * 8.0 * q))
		b.polyline(tail, body, 3.0)
		# glowing spots along the wings
		for j in 6:
			var sx := -f * 90.0 + f * j * 36.0
			b.circle(Vector2(sx, 2.0 + (j % 2) * 4.0), 3.5, Color("6fe8ff", 0.8), 8)
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var o := global_position
		var f := _face
		for j in 6:
			g.draw_circle(o + Vector2(-f * 90.0 + f * j * 36.0, 2.0 + (j % 2) * 4.0), 6.0, Color("6fe8ff", 0.45))
		g.draw_line(o + Vector2(-80, -3), o + Vector2(80, -3), Color("b9c8ff", 0.35), 2.0)
