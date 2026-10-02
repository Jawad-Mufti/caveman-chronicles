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
