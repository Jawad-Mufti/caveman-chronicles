class_name Mountain
extends RefCounted
## Things inside the mountain (its rock is a Terrain: MOUNTAIN_MAP in
## level2_data.gd). The tunnels and caves are furnished in level2.gd
## (`_build_mountain_inside`) with crystals, bones, glow-worms and finds; this
## file holds what only lives here.


## ================================================================ CAVE PAINT
class CavePaint extends Node2D:
	## The Painted Cave's wall: the old ones were here. A herd of mammoths
	## running, hunters with spears, a great fire with people dancing round it,
	## and hand prints, many hands, blown in red. It glows a little when his
	## torch is near, as if the colours were still wet.
	var _t := 0.0
	var _near := 0.0

	func _ready() -> void:
		z_index = -1
		add_to_group("glow")

	func _process(delta: float) -> void:
		_t += delta
		var p := get_tree().get_first_node_in_group("player") as Node2D
		var want := 1.0 if p != null and p.global_position.distance_to(global_position) < 260.0 else 0.0
		_near = move_toward(_near, want, delta * 1.5)
		if LevelBase.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var a := 0.55 + 0.35 * _near
		var ochre := Color("c8553d", a)
		var red := Color("a83a2a", a)
		var dark := Color("2a1a14", a)
		var chalk := Color("e8dcc0", a * 0.9)
		# the herd: three mammoths, running left to right, one small
		for m in [[Vector2(-150, -70), 1.0], [Vector2(-60, -84), 0.85], [Vector2(20, -64), 0.6]]:
			var at: Vector2 = m[0]
			var s: float = m[1]
			b.ellipse(at, 34.0 * s, 20.0 * s, ochre)
			b.circle(at + Vector2(30, -8) * s, 13.0 * s, ochre, 12)
			b.line(at + Vector2(38, 0) * s, at + Vector2(46, 22) * s, ochre, 5.0 * s)              # trunk
			b.line(at + Vector2(34, 6) * s, at + Vector2(52, 2) * s, chalk, 3.0 * s)               # tusk
			for lx in [-22.0, -8.0, 10.0, 22.0]:
				var swing := sin(_t * 1.2 + lx) * 3.0
				b.line(at + Vector2(lx, 14) * s, at + Vector2(lx + swing, 34) * s, ochre, 5.0 * s)
			b.line(at + Vector2(-32, -4) * s, at + Vector2(-42, 6) * s, ochre, 2.5 * s)            # tail
		# the hunters, spears raised, after them
		for h in [Vector2(-230, -60), Vector2(-205, -56)]:
			b.circle(h + Vector2(0, -26), 5.0, dark, 8)
			b.line(h + Vector2(0, -21), h + Vector2(0, -2), dark, 3.0)
			b.line(h + Vector2(0, -2), h + Vector2(-6, 12), dark, 3.0)
			b.line(h + Vector2(0, -2), h + Vector2(6, 12), dark, 3.0)
			b.line(h + Vector2(0, -16), h + Vector2(10, -24), dark, 2.5)
			b.line(h + Vector2(4, -30), h + Vector2(28, -40), dark, 2.0)                          # spear
		# the great fire, and people dancing round it
		var f := Vector2(140, -50)
		for k in 3:
			var hk := 26.0 + 8.0 * sin(_t * 3.0 + k)
			b.tri(f + Vector2(-14 + k * 14, 18), f + Vector2(-4 + k * 14 + sin(_t * 4.0 + k) * 3.0, 18 - hk), f + Vector2(4 + k * 14, 18), red if k != 1 else ochre)
		for d in 4:
			var ang := d * TAU / 4.0 + _t * 0.4
			var dp := f + Vector2(14, 6) + Vector2(cos(ang) * 50.0, sin(ang) * 10.0)
			b.circle(dp + Vector2(0, -22), 4.5, dark, 8)
			b.line(dp + Vector2(0, -18), dp + Vector2(0, -2), dark, 3.0)
			b.line(dp + Vector2(0, -14), dp + Vector2(-8, -24), dark, 2.5)                         # arms up
			b.line(dp + Vector2(0, -14), dp + Vector2(8, -24), dark, 2.5)
			b.line(dp + Vector2(0, -2), dp + Vector2(-5, 10), dark, 2.5)
			b.line(dp + Vector2(0, -2), dp + Vector2(5, 10), dark, 2.5)
		# hands, blown in red around the edge of it all
		for hp in [Vector2(-250, -130), Vector2(-120, -140), Vector2(60, -136), Vector2(220, -120), Vector2(240, -20)]:
			var spray := Color(red, a * 0.35)
			b.circle(hp, 22.0, spray, 14)
			b.ellipse(hp + Vector2(0, 6), 8.0, 10.0, Color(0.13, 0.08, 0.07, a * 0.8))
			for fg in 5:
				var fa := -PI * 0.5 + (fg - 2) * 0.32
				b.line(hp + Vector2(0, -2), hp + Vector2.from_angle(fa) * 16.0, Color(0.13, 0.08, 0.07, a * 0.8), 3.4)
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		if _near > 0.0:
			g.draw_circle(global_position + Vector2(0, -70), 220.0, Color(0.9, 0.45, 0.3, 0.06 * _near))


## ================================================================ KICK FACE
class KickFace extends StaticBody2D:
	## One wall of the Chimney: a kick wall (group "kick_wall", see
	## CaveMan._kick_wall_normal) laid a hair proud of the terrain's own face, so
	## he touches it first. Only here: if all the rock were kickable, any cliff
	## could be climbed by kicking off it again and again. Drawn as scuffed
	## holds on the rock, so it reads as "climb me".
	var top := 0.0
	var bottom := 0.0
	var side := 1.0           ## +1: the wall is on his left (its face looks right), -1: on his right

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		add_to_group("kick_wall")
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(6, bottom - top)
		cs.shape = sh
		cs.position = Vector2(-side * 1.0, (top + bottom) * 0.5)
		add_child(cs)
		z_index = 3

	func _draw() -> void:
		var b := Batch.new()
		var y := top + 30.0
		var i := 0
		while y < bottom - 20.0:
			var dx := side * (3.0 + (i % 3) * 2.0)
			b.line(Vector2(dx, y), Vector2(dx + side * 9.0, y + 3.0), Color(0.85, 0.78, 0.62, 0.55), 3.0)
			b.line(Vector2(dx, y + 4.0), Vector2(dx + side * 9.0, y + 7.0), Color(0.1, 0.07, 0.05, 0.5), 2.0)
			y += 44.0 + (i * 17) % 23
			i += 1
		b.draw(self)
