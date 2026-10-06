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


## ================================================================ CAVE WORM
class CaveWorm extends Critter:
	## A fat, pale cave worm inching along the tunnel floor, now and then
	## ducking into the ground and coming up again further on. Harmless.
	## One bonk and it drops a ROASTED GRUB: food, like fruit (health now, or
	## the pouch). Follows the mountain's floor (`terrain`).
	var terrain: Terrain
	var left_x := 0.0
	var right_x := 0.0
	var dir := 1
	var t := 0.0
	var _under := 0.0              ## > 0: down in its hole
	var _next_dive := 4.0

	func death_style() -> String:
		return "curl"

	func _setup() -> void:
		hp = 1
		damage = 0
		stomp_top = -14.0
		add_rect_shape(Vector2(46, 18), Vector2(0, -9))
		t = randf() * 5.0
		dir = 1 if randf() < 0.5 else -1
		_next_dive = randf_range(3.0, 6.0)

	func _tick(delta: float) -> void:
		t += delta
		if _under > 0.0:
			_under -= delta
			if _under <= 0.0:
				# up again, a little way along
				position.x = clampf(position.x + dir * randf_range(60.0, 140.0), left_x, right_x)
				_snap()
			return
		_next_dive -= delta
		if _next_dive <= 0.0:
			_next_dive = randf_range(4.0, 7.0)
			_under = 1.4
			return
		# inching: the body bunches up, then stretches forward
		var push := maxf(0.0, sin(t * 4.0))
		position.x += dir * 34.0 * push * delta
		if position.x < left_x:
			position.x = left_x
			dir = 1
		elif position.x > right_x:
			position.x = right_x
			dir = -1
		_snap()

	func _snap() -> void:
		if terrain != null:
			var g := terrain.ground_y(global_position.x, global_position.y - 40.0)
			if g < INF and absf(g - global_position.y) < 80.0:
				global_position.y = g

	func take_hit(dmg: int, from_dir: int) -> void:
		if _under > 0.0:
			return                    # down its hole: missed
		super.take_hit(dmg, from_dir)

	func _on_die() -> void:
		var grub := GrubPickup.new()
		grub.position = position
		get_parent().add_child.call_deferred(grub)

	func _paint() -> void:
		var body := Color("e9b8b0")
		var ring := Color("c98d86")
		var s := float(dir)
		_oval(Vector2(0, -2), 22.0, 5.0, Color("3a2a1e"), 0.0)             # its hole / shadow
		if _under > 0.0:
			# down the hole: just the tip of its tail, wiggling
			_cc(Vector2(sin(t * 9.0) * 3.0, -5), 4.0, body)
			return
		# the segments: a hump when it bunches up, flat when it stretches
		var bunch := maxf(0.0, sin(t * 4.0 + PI * 0.5))
		var n := 7
		for i in n:
			var q := float(i) / (n - 1)
			var x := s * (-20.0 + q * 40.0 * (1.0 - 0.25 * bunch))
			var hump := sin(q * PI) * 10.0 * bunch
			_dot(Vector2(x, -7.0 - hump), 6.5 + sin(q * PI) * 1.5, body if i % 2 == 0 else ring, 1.6)
		# the head: two little dark eyes, a pink snout
		var hx := s * (20.0 * (1.0 - 0.25 * bunch))
		_dot(Vector2(hx, -8), 7.5, body, 1.8)
		_cc(Vector2(hx + s * 2.5, -11), 1.6, Color("1a120c"))
		_cc(Vector2(hx + s * 6.5, -7), 1.8, Color("e07a86"))


## A roasted grub, dropped by a cave worm: food. Health now, or into the pouch.
class GrubPickup extends Area2D:
	var t := 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 22.0
		cs.shape = c
		cs.position = Vector2(0, -10)
		add_child(cs)
		body_entered.connect(_on_body)

	func _on_body(b: Node) -> void:
		if b is CaveMan and (b as CaveMan).add_berry():
			set_deferred("monitoring", false)
			call_deferred("queue_free")

	func _process(delta: float) -> void:
		t += delta
		if NightWoods.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var bob := sin(t * 2.6) * 3.0
		var pulse := 0.5 + 0.5 * sin(t * 2.4)
		draw_arc(Vector2(0, -12 + bob), 18.0 + pulse * 4.0, 0.0, TAU, 24, Color(1.0, 0.75, 0.4, 0.15 + pulse * 0.25), 2.0)
		# a plump curled grub, toasted golden, a wisp of steam
		for i in 5:
			var a := PI * 0.9 + i * 0.32
			var p := Vector2(0, -10 + bob) + Vector2.from_angle(a) * 8.0
			draw_circle(p, 5.2 - i * 0.4, Color("8a4f1c"))
			draw_circle(p + Vector2(-0.5, -0.8), 4.2 - i * 0.4, Color("d9963e"))
		draw_circle(Vector2(-7, -18 + bob), 1.4, Color(1, 1, 1, 0.7))
		var st := fmod(t * 0.8, 1.0)
		draw_line(Vector2(2, -22 + bob - st * 12.0), Vector2(5, -30 + bob - st * 12.0), Color(1, 1, 1, 0.5 * (1.0 - st)), 2.0)


## ================================================================ RISEN SKELETON
class RisenSkeleton extends Critter:
	## An old hunter who never left the mountain: a heap of bones on the floor,
	## until Ugu comes near. Then it RATTLES back together, part by part, eyes
	## glowing, and shambles after him swinging a bone club. Knocked down, it
	## falls back into a heap... and gets up ONE more time. The second time (or
	## a stomp) it is down for good.
	var terrain: Terrain
	var left_x := 0.0
	var right_x := 0.0
	var dir := -1
	var state := "heap"            ## heap, rise, walk, swing, down
	var rise := 0.0                ## 0 = a heap, 1 = standing
	var revives := 1
	var t := 0.0
	var _tst := 0.0                ## time in this state
	var _swung := false
	const HP := 4
	const WAKE := 260.0
	const SPEED := 70.0
	const EYE := Color("7dffcf")

	func death_style() -> String:
		return "limp"

	func _setup() -> void:
		hp = HP
		damage = 0
		stomp_top = -70.0
		add_rect_shape(Vector2(34, 80), Vector2(0, -40))
		add_to_group("glow")
		t = randf() * 5.0

	func _go(s: String) -> void:
		state = s
		_tst = 0.0

	func _tick(delta: float) -> void:
		t += delta
		_tst += delta
		var dx := 0.0
		var near := false
		if player != null and not player.dead:
			dx = player.global_position.x - global_position.x
			near = absf(dx) < WAKE and absf(player.global_position.y - global_position.y) < 120.0
		match state:
			"heap":
				damage = 0
				rise = 0.0
				if near:
					_go("rise")
					_word("RATTLE RATTLE...")
			"rise":
				damage = 0
				rise = clampf(_tst / 1.3, 0.0, 1.0)
				if rise >= 1.0:
					_go("walk")
			"walk":
				damage = 1
				if dx != 0.0:
					dir = 1 if dx > 0.0 else -1
				if absf(dx) < 70.0 and near:
					_go("swing")
					_swung = false
				else:
					var sp := SPEED * (1.0 if near else 0.4)
					position.x = clampf(position.x + dir * sp * delta, left_x, right_x)
					_snap()
			"swing":
				# raised... and down: the blow lands at 0.45 s
				if not _swung and _tst > 0.45:
					_swung = true
					if player != null and absf(dx) < 85.0 and absf(player.global_position.y - global_position.y) < 90.0:
						player.hurt(1, global_position.x)
				if _tst > 0.9:
					_go("walk")
			"down":
				damage = 0
				rise = 1.0 - clampf(_tst / 0.4, 0.0, 1.0)
				if _tst > 3.0:
					hp = HP
					_go("rise")
					_word("...IT'S GETTING UP!")

	func _snap() -> void:
		if terrain != null:
			var g := terrain.ground_y(global_position.x, global_position.y - 40.0)
			if g < INF and absf(g - global_position.y) < 80.0:
				global_position.y = g

	func take_hit(dmg: int, from_dir: int) -> void:
		if dying > 0.0 or state in ["heap", "down"]:
			return                    # a heap of bones: nothing to hit (yet)
		if from_dir == 0:
			dmg = 99                  # a stomp smashes it for good
		elif hp - dmg <= 0 and revives > 0:
			# down... but not out
			revives -= 1
			hp = 0
			flash = 0.15
			_go("down")
			var pop := Critter.DeathPop.new()
			pop.dust = true
			pop.position = global_position + Vector2(0, -30)
			get_parent().add_child.call_deferred(pop)
			return
		super.take_hit(dmg, from_dir)

	func _word(text: String) -> void:
		var w := CaveMan.WordPop.new()
		w.text = text
		w.size = 20
		w.color = Color("cfeee0")
		w.centered = true
		w.life = 1.1
		w.position = global_position + Vector2(0, -120)
		get_parent().add_child(w)

	## Its glowing eyes, through the dark.
	func draw_glow(g) -> void:
		if rise < 0.6 or dying > 0.0 or state == "down":
			return
		g.draw_circle(global_position + Vector2(dir * 4.0, -76.0 * rise), 18.0, Color(EYE, 0.22))

	## One bone, from where it lies in the heap (ha, hb) to where it stands (a, b), by k.
	func _bone(a: Vector2, b: Vector2, ha: Vector2, hb: Vector2, w: float, k: float, col: Color) -> void:
		var pa := ha.lerp(a, k)
		var pb := hb.lerp(b, k)
		_ln(pa, pb, Color("3a3226"), w + 3.0)
		_ln(pa, pb, col, w)
		_cc(pa, w * 0.75, col)
		_cc(pb, w * 0.75, col)

	## Each part comes up in turn as it rises: legs, hips, spine, ribs, arms, the skull last.
	func _part(i: int) -> float:
		return clampf((rise - i * 0.09) / 0.45, 0.0, 1.0)

	func _paint() -> void:
		var bone := Color("e6dcc4")
		var walk := sin(t * 5.0) if state == "walk" else 0.0
		var shake := Vector2(sin(t * 47.0), cos(t * 39.0)) * 1.5 if state == "rise" else Vector2.ZERO
		_st(shake, 0.0, Vector2(float(dir), 1.0))
		_oval(Vector2(0, -2), 26.0, 5.0, Color(0, 0, 0, 0.35), 0.0)
		# legs
		_bone(Vector2(-6, -40), Vector2(-8 - walk * 8.0, -20), Vector2(-26, -4), Vector2(-10, -3), 4.0, _part(0), bone)
		_bone(Vector2(-8 - walk * 8.0, -20), Vector2(-6 - walk * 10.0, -2), Vector2(-10, -3), Vector2(4, -4), 4.0, _part(0), bone)
		_bone(Vector2(6, -40), Vector2(8 + walk * 8.0, -20), Vector2(12, -5), Vector2(28, -3), 4.0, _part(1), bone)
		_bone(Vector2(8 + walk * 8.0, -20), Vector2(10 + walk * 10.0, -2), Vector2(28, -3), Vector2(38, -6), 4.0, _part(1), bone)
		# hips and spine
		_bone(Vector2(-9, -42), Vector2(9, -42), Vector2(-4, -6), Vector2(12, -8), 5.0, _part(2), bone)
		_bone(Vector2(0, -42), Vector2(2, -66), Vector2(16, -6), Vector2(34, -10), 3.5, _part(3), bone)
		# ribs
		for i in 3:
			var y := -62.0 + i * 6.0
			var ha := Vector2(-18 + i * 9, -8 - i * 2)
			_bone(Vector2(-8, y), Vector2(10, y), ha, ha + Vector2(14, -2), 2.6, _part(4), bone)
		# the club arm: carried forward; in a swing raised up over the skull, then brought DOWN
		var sh := Vector2(4, -64)
		var rest := Vector2(16, 10)
		var up := Vector2(-6, -24)
		var down := Vector2(24, 12)
		var hand := sh + rest
		if state == "swing":
			if _tst < 0.45:
				hand = sh + rest.lerp(up, clampf(_tst / 0.35, 0.0, 1.0))
			else:
				hand = sh + up.lerp(down, clampf((_tst - 0.45) / 0.1, 0.0, 1.0))
		_bone(sh, hand, Vector2(-30, -6), Vector2(-16, -6), 3.2, _part(5), bone)
		var club_tip := hand + (hand - sh).normalized().rotated(-0.5) * 34.0
		_bone(hand, club_tip, Vector2(-40, -4), Vector2(-14, -4), 6.0, _part(5), Color("cbbf9e"))
		# the other arm, dangling
		_bone(Vector2(-2, -64), Vector2(-10 + walk * 4.0, -44), Vector2(36, -4), Vector2(46, -6), 3.0, _part(6), bone)
		# the skull: rolls up last, jaw chattering, eyes lit
		var kh := _part(7)
		var head := Vector2(42, -9).lerp(Vector2(4, -76), kh)
		_dot(head, 10.0, bone, 2.0)
		var jaw := absf(sin(t * 14.0)) * 3.0 if state != "heap" else 0.0
		_rc(Rect2(head.x - 6, head.y + 6 + jaw * 0.4, 12, 4), bone)
		for e in [-4.0, 4.0]:
			_cc(head + Vector2(e + 1.5, -1), 3.4, Color("1a120c"))
			if kh > 0.6 and state != "down":
				_cc(head + Vector2(e + 1.5, -1), 1.8, EYE)
		_cc(head + Vector2(1.5, 4), 1.4, Color("1a120c"))
		_st()
