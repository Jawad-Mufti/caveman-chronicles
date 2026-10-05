## The Root Hollows: a world under the middle of the level, and the weird
## things that live there.
##   Burrow       a crusted mound in the ground, eyes blinking in its cracks: a
##                MEGA STOMP breaks it, then walk into the hole: the Dig begins
##   GlowWorms    a colony on the roof: glowing, sticky threads hang down; walk
##                into them and they hold on (slow and floaty); a whack snaps one
##   CrystalSnail a slow, gentle snail with a shell of glowing crystal — and a
##                rare find inside. Three whacks crack it open (it doesn't mind)
##   Angler       a cave angler hiding in a crack in the roof: only its lure
##                glows, swaying at head height. Come close and its eyes open...
##                then the jaws come down. A whack on the lure sends it back
class_name Underground
extends RefCounted


static func _player(n: Node) -> CaveMan:
	return n.get_tree().get_first_node_in_group("player") as CaveMan


## ================================================================ BURROW
class Burrow extends Node2D:
	## The mound on top of the Dig's crust. A MEGA STOMP on it breaks the crust
	## open (the level opens the blocks under it); then it is just a broken rim.
	signal opened
	var open := false
	var _t := 0.0
	var _cooldown := 1.0
	var _shards: Array = []

	func _ready() -> void:
		z_index = 2
		add_to_group("stomp_spot")
		add_to_group("glow")

	func stomped(level: int, at: Vector2) -> void:
		if open or absf(at.x - global_position.x) > 70.0 or absf(at.y - global_position.y) > 40.0:
			return
		if level < 2:
			# the crust is baked hard: it takes a MEGA stomp
			var clang := Treasure.FloatText.new()
			clang.text = "THUD!"
			clang.position = global_position + Vector2(-24, -70)
			get_parent().add_child(clang)
			var p := Underground._player(self)
			if p != null:
				p.said.emit("The crust is baked hard. DOUBLE-jump, then T: a MEGA STOMP!")
			return
		open = true
		_cooldown = 0.6
		for i in 14:
			var a := randf_range(PI * 1.1, PI * 1.9)
			_shards.append([Vector2(randf_range(-20, 20), -6), Vector2.from_angle(a) * randf_range(200, 420), 1.0])
		var pop := Treasure.FloatText.new()
		pop.text = "CRUNCH!"
		pop.position = global_position + Vector2(-34, -80)
		get_parent().add_child(pop)
		opened.emit()

	func _physics_process(delta: float) -> void:
		_t += delta
		_cooldown = maxf(_cooldown - delta, 0.0)
		for s in _shards:
			s[1] = (s[1] as Vector2) + Vector2(0, 1400) * delta
			s[0] = (s[0] as Vector2) + (s[1] as Vector2) * delta
			s[2] = float(s[2]) - delta
		_shards = _shards.filter(func(s): return float(s[2]) > 0.0)
		if LevelBase.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		if open:
			# the broken rim of the crust, and roots hanging into the dark
			for s in [-1.0, 1.0]:
				b.tri(Vector2(s * 82.0, 0), Vector2(s * 66.0, -10), Vector2(s * 56.0, 2), Color("9a7048"))
				b.tri(Vector2(s * 70.0, 0), Vector2(s * 58.0, -6), Vector2(s * 44.0, 3), Color("7a5536"))
			for i in 4:
				var x := -60.0 + i * 40.0
				b.line(Vector2(x, 2), Vector2(x + sin(_t + i) * 3.0, 22.0 + (i % 2) * 10.0), Color("3a2617"), 2.0)
		else:
			# a mound of dry earth, crusted and cracked; something looks out
			var mound := PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				mound.append(Vector2(cos(a) * 46.0, sin(a) * 22.0 + 2.0))
			b.poly(mound, Color("1c130d"))
			var top := PackedVector2Array()
			for p in mound:
				top.append(p * 0.92 + Vector2(0, -1))
			b.poly(top, Color("7a5536"))
			b.ellipse(Vector2(-6, -12), 22, 5, Color("9a7048"))
			for c in [[-22.0, -4.0, -8.0, -16.0], [-8.0, -16.0, 6.0, -8.0], [6.0, -8.0, 26.0, -14.0], [-4.0, -4.0, 10.0, 0.0]]:
				b.line(Vector2(c[0], c[1]), Vector2(c[2], c[3]), Color("2a1a10"), 2.5)
			# eyes in the cracks, blinking out of step
			for e in [[-14.0, -9.0, 0.0], [16.0, -11.0, 1.7]]:
				var blink := fmod(_t + float(e[2]), 3.4) < 0.15
				if not blink:
					b.circle(Vector2(e[0], e[1]), 2.2, Color("ffe14a"), 6)
					b.circle(Vector2(e[0] + 4.0, e[1]), 2.2, Color("ffe14a"), 6)
		for s in _shards:
			b.circle(s[0], 3.0, Color("7a5536"), 6)
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var o := global_position
		if open:
			g.draw_circle(o + Vector2(0, 2), 30.0, Color(0.4, 1.0, 0.8, 0.15 + 0.08 * sin(_t * 2.0)))
		else:
			for e in [[-14.0, -9.0, 0.0], [16.0, -11.0, 1.7]]:
				if fmod(_t + float(e[2]), 3.4) >= 0.15:
					g.draw_circle(o + Vector2(float(e[0]) + 2.0, e[1]), 5.0, Color(1.0, 0.9, 0.3, 0.6))


## ================================================================ GLOW WORMS
class GlowWorms extends Area2D:
	## position = on the roof. `width` across; threads hang to `reach`.
	const REGROW := 6.0
	var width := 300.0
	var reach := 330.0
	var _threads: Array = []      ## [x, length, phase, cut time left]
	var _t := 0.0
	var _stuck := 0.0

	func _ready() -> void:
		collision_layer = 4          # his swing finds it: a whack snaps a thread
		collision_mask = 0
		monitoring = false
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(width, reach)
		cs.shape = sh
		cs.position = Vector2(width * 0.5, reach * 0.5)
		add_child(cs)
		add_to_group("glow")
		add_to_group("light")
		var rng := RandomNumberGenerator.new()
		rng.seed = int(position.x)
		var x := 10.0
		while x < width - 10.0:
			_threads.append([x, rng.randf_range(reach * 0.72, reach), rng.randf() * TAU, 0.0])
			x += rng.randf_range(22.0, 40.0)

	func light() -> Vector4:
		return Vector4(global_position.x + width * 0.5, global_position.y + reach * 0.4, width * 0.8, 0.2)

	func light_strength() -> float:
		return 0.0

	func _thread_x(th: Array) -> float:
		return float(th[0]) + sin(_t * 1.1 + float(th[2])) * 6.0

	func take_hit(_dmg: int, _from_dir: int) -> void:
		var p := Underground._player(self)
		if p == null:
			return
		var lx := p.global_position.x - global_position.x
		var best := -1
		for i in _threads.size():
			if float(_threads[i][3]) <= 0.0 and (best < 0 or absf(_thread_x(_threads[i]) - lx) < absf(_thread_x(_threads[best]) - lx)):
				best = i
		if best >= 0 and absf(_thread_x(_threads[best]) - lx) < 70.0:
			_threads[best][3] = REGROW
			var pop := Treasure.FloatText.new()
			pop.text = "snip!"
			pop.position = global_position + Vector2(_thread_x(_threads[best]), 60)
			get_parent().add_child(pop)

	func _physics_process(delta: float) -> void:
		_t += delta
		for th in _threads:
			th[3] = maxf(float(th[3]) - delta, 0.0)
		var p := Underground._player(self)
		_stuck = maxf(_stuck - delta, 0.0)
		if p != null and not p.dead:
			var lp := p.global_position - global_position
			for th in _threads:
				if float(th[3]) > 0.0:
					continue
				var tx := _thread_x(th)
				# his body (feet to head) against the hanging thread
				if absf(lp.x - tx) < 14.0 and lp.y - 64.0 < float(th[1]) and lp.y > 0.0:
					# sticky: it holds him — slow across, floating down
					p.velocity.x *= 0.7
					p.velocity.y = minf(p.velocity.y, 70.0)
					if _stuck <= 0.0:
						var pop := Treasure.FloatText.new()
						pop.text = "sticky!"
						pop.position = p.global_position + Vector2(-20, -100)
						get_parent().add_child(pop)
					_stuck = 0.6
					break
		if LevelBase.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		b.rect(Rect2(0, -6, width, 10), Color("1a1622"))
		for th in _threads:
			var tx := _thread_x(th)
			var tl: float = th[1]
			if float(th[3]) > 0.0:
				tl *= clampf(1.0 - float(th[3]) / REGROW, 0.08, 1.0)
			b.line(Vector2(float(th[0]), 0), Vector2(tx, tl), Color("9fe8ff", 0.35), 1.2)
			for j in 6:
				var q := (j + 1) / 7.0
				b.circle(Vector2(lerpf(float(th[0]), tx, q), tl * q), 2.2, Color("9ff3ff", 0.75), 6)
			b.circle(Vector2(float(th[0]), 2), 4.0, Color("3dd8c8"), 8)
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var o := global_position
		for th in _threads:
			var tx := _thread_x(th)
			var tl: float = th[1]
			if float(th[3]) > 0.0:
				tl *= clampf(1.0 - float(th[3]) / REGROW, 0.08, 1.0)
			var tw := 0.6 + 0.4 * sin(_t * 2.0 + float(th[2]))
			for j in 6:
				var q := (j + 1) / 7.0
				g.draw_circle(o + Vector2(lerpf(float(th[0]), tx, q), tl * q), 4.5, Color(0.55, 1.0, 1.0, 0.35 * tw))
			g.draw_circle(o + Vector2(float(th[0]), 2), 7.0, Color(0.3, 1.0, 0.85, 0.5 * tw))


## ================================================================ SNAIL
class CrystalSnail extends Area2D:
	## Slow and gentle; a shell of glowing crystal with a rare find inside.
	signal cracked(at: Vector2)
	var x0 := 0.0
	var x1 := 300.0
	var holding := true          ## false once its find is out (or was taken before)
	var hits := 0
	var _dir := 1.0
	var _hide := 0.0
	var _roll := 0.0
	var _t := 0.0

	func _ready() -> void:
		collision_layer = 4
		collision_mask = 0
		monitoring = false
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(70, 56)
		cs.shape = sh
		cs.position = Vector2(0, -28)
		add_child(cs)
		add_to_group("glow")
		add_to_group("light")
		_t = randf() * 4.0

	func light() -> Vector4:
		return Vector4(global_position.x, global_position.y - 34.0, 150.0 if holding else 90.0, 0.1)

	func light_strength() -> float:
		return 0.0

	func take_hit(_dmg: int, from_dir: int) -> void:
		if _hide > 0.4:
			return
		_hide = 2.6
		_roll = float(from_dir) * 120.0
		var pop := Treasure.FloatText.new()
		pop.position = global_position + Vector2(-20, -80)
		if holding:
			hits += 1
			pop.text = "tink!" if hits < 3 else "CRACK!"
			if hits >= 3:
				holding = false
				cracked.emit(global_position + Vector2(0, -60))
		else:
			pop.text = "...hmph"
		get_parent().add_child(pop)

	func _physics_process(delta: float) -> void:
		_t += delta
		_hide = maxf(_hide - delta, 0.0)
		if absf(_roll) > 1.0:
			position.x += _roll * delta
			_roll = move_toward(_roll, 0.0, 260.0 * delta)
		elif _hide <= 0.0:
			position.x += _dir * 14.0 * delta
		if position.x < x0:
			position.x = x0
			_dir = 1.0
		elif position.x > x1:
			position.x = x1
			_dir = -1.0
		if LevelBase.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var f := _dir
		var tuck := clampf(_hide / 0.3, 0.0, 1.0)
		# the soft body, slowly rippling (gone inside when it hides)
		if tuck < 1.0:
			var stretch := 1.0 - tuck
			b.ellipse(Vector2(f * 16.0 * stretch, -8), 30.0 * stretch + 6.0, 9.0, Color("c9b7d9"))
			for s in [-1.0, 1.0]:
				var stalk := Vector2(f * (34.0 + 2.0 * s) * stretch, -8)
				var tip := stalk + Vector2(f * 6.0, -22.0 - 3.0 * sin(_t * 3.0 + s)) * stretch
				b.line(stalk, tip, Color("c9b7d9"), 3.0)
				b.circle(tip, 3.5, Color("2a2236"), 6)
		# the shell: a cluster of crystal facets in a spiral
		var shell_c := Vector2(-f * 4.0, -32)
		var col := Color("6dffd8") if holding else Color("8d93a8")
		b.ellipse(shell_c, 30, 26, col.darkened(0.55))
		for i in 7:
			var a := i * TAU / 7.0 + 0.4
			var p := shell_c + Vector2.from_angle(a) * 14.0
			b.tri(p + Vector2.from_angle(a + 1.6) * 8.0, p + Vector2.from_angle(a) * 14.0, p + Vector2.from_angle(a - 1.6) * 8.0, col.darkened(0.15 * (i % 3)))
		b.circle(shell_c, 8.0, col.lightened(0.3), 10)
		for i in hits:
			b.line(shell_c + Vector2(-12 + i * 9, -18), shell_c + Vector2(-6 + i * 9, -4), Color("1a2b2a"), 2.0)
		if holding:
			b.circle(shell_c + Vector2(0, -2), 4.0, Color(1, 1, 1, 0.8 + 0.2 * sin(_t * 4.0)), 8)
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var o := global_position + Vector2(-_dir * 4.0, -32)
		var col := Color("6dffd8") if holding else Color("8d93a8")
		g.draw_circle(o, 36.0 + 4.0 * sin(_t * 2.0), Color(col, 0.25 if holding else 0.1))
		if holding:
			g.draw_circle(o, 6.0, Color(1, 1, 1, 0.8))


## ================================================================ ANGLER
class Angler extends Area2D:
	## position = the crack in the roof it hides in; `drop` = how far its lure
	## hangs below (head height). Only the lure is a target.
	const WARN := 0.55
	var drop := 230.0
	var state := "lurk"           ## lurk, tense, snap, back, scared
	var _t := 0.0
	var _st := 0.0
	var _cool := 0.0
	var _shape: CollisionShape2D

	func _ready() -> void:
		collision_layer = 4          # a whack on the lure
		collision_mask = 2
		_shape = CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 16.0
		_shape.shape = c
		add_child(_shape)
		add_to_group("glow")
		add_to_group("light")
		z_index = 2

	func lure_at() -> Vector2:
		var up := 0.0
		if state == "scared":
			up = drop * 0.8
		return Vector2(sin(_t * 1.3) * 18.0, drop - up + sin(_t * 2.1) * 6.0)

	func light() -> Vector4:
		var l := global_position + lure_at()
		var dim := 0.4 if state == "tense" else (0.0 if state == "scared" else 1.0)
		return Vector4(l.x, l.y, 130.0 * dim + 20.0, 0.3)

	func light_strength() -> float:
		return 0.0

	func take_hit(_dmg: int, _from_dir: int) -> void:
		if state in ["lurk", "tense"]:
			state = "scared"
			_st = 0.0
			var pop := Treasure.FloatText.new()
			pop.text = "BONK!"
			pop.position = global_position + lure_at() + Vector2(-20, -30)
			get_parent().add_child(pop)

	func _physics_process(delta: float) -> void:
		_t += delta
		_st += delta
		_cool = maxf(_cool - delta, 0.0)
		_shape.position = lure_at()
		var p := Underground._player(self)
		var lure := global_position + lure_at()
		var near := p != null and not p.dead and absf(p.global_position.x - lure.x) < 80.0 and absf(p.global_position.y - 30.0 - lure.y) < 120.0
		match state:
			"lurk":
				if near and _cool <= 0.0:
					state = "tense"
					_st = 0.0
			"tense":
				if _st >= WARN:
					state = "snap"
					_st = 0.0
			"snap":
				# the jaws come down over the lure
				if p != null and not p.dead and _st > 0.08 and _st < 0.35 and absf(p.global_position.x - lure.x) < 60.0 \
						and p.global_position.y > lure.y - 20.0 and p.global_position.y - 64.0 < lure.y + 60.0:
					var side := 1.0 if p.global_position.x >= lure.x else -1.0
					p.hurt_toss(1, lure.x, Vector2(side * 320.0, -300.0))
				if _st > 0.5:
					state = "back"
					_st = 0.0
			"back":
				if _st > 0.4:
					state = "lurk"
					_cool = 1.6
			"scared":
				if _st > 5.0:
					state = "lurk"
					_cool = 0.8
		if LevelBase.near_view(self):
			queue_redraw()

	func _jaw() -> float:
		match state:
			"snap":
				return clampf(_st / 0.1, 0.0, 1.0)
			"back":
				return clampf(1.0 - _st / 0.4, 0.0, 1.0)
		return 0.0

	func _draw() -> void:
		var b := Batch.new()
		var lure := lure_at()
		var j := _jaw()
		# the crack it lives in
		b.ellipse(Vector2(0, 4), 46, 16, Color("07060a"))
		# the stalk down to the lure
		var stalk := PackedVector2Array()
		for i in 9:
			var q := i / 8.0
			stalk.append(Vector2(lure.x * q + sin(q * PI) * 10.0, lure.y * q))
		b.polyline(stalk, Color("3a3346"), 3.0)
		b.circle(lure, 8.0 if state != "tense" else 6.0, Color("fff3a0") if state != "scared" else Color("6a6070"), 10)
		if j > 0.0:
			# the head: out of the dark, mouth gaping over the lure
			var head := lure * Vector2(1.0, 0.25 + 0.75 * j) + Vector2(0, -30)
			var w := 70.0
			b.ellipse(head + Vector2(0, -20), w, 44.0, Color("24202e"))
			b.poly(PackedVector2Array([head + Vector2(-w * 0.9, 0), head + Vector2(w * 0.9, 0), head + Vector2(w * 0.6, 44.0 * j), head + Vector2(-w * 0.6, 44.0 * j)]), Color("5a1f2a"))
			for i in 9:
				var tx := -w * 0.8 + i * w * 0.2
				b.tri(head + Vector2(tx - 5, 0), head + Vector2(tx, 16), head + Vector2(tx + 5, 0), Color("ece6d0"))
				b.tri(head + Vector2(tx - 5, 44.0 * j), head + Vector2(tx, 44.0 * j - 14), head + Vector2(tx + 5, 44.0 * j), Color("ece6d0"))
			for s in [-1.0, 1.0]:
				b.circle(head + Vector2(s * 38.0, -34), 11.0, Color("e8e2a0"), 12)
				b.circle(head + Vector2(s * 38.0, -34), 5.0, Color.BLACK, 8)
		elif state == "tense":
			for s in [-1.0, 1.0]:
				b.circle(Vector2(s * 20.0, 10), 6.0, Color("e8e2a0"), 10)
				b.circle(Vector2(s * 20.0, 10), 3.0, Color.BLACK, 6)
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var o := global_position
		var l := o + lure_at()
		if state != "scared":
			var flick := 0.4 if state == "tense" else 1.0
			g.draw_circle(l, 26.0 * flick + 6.0, Color(1.0, 0.95, 0.5, 0.35 * flick))
			g.draw_circle(l, 5.0, Color(1, 1, 0.85, 0.9))
		if state == "lurk":
			for s in [-1.0, 1.0]:
				if fmod(_t * 0.7 + s, 3.0) > 0.2:
					g.draw_circle(o + Vector2(s * 20.0, 10), 3.0, Color(1, 0.95, 0.6, 0.35))


## ================================================================ UPDRAFT
class Updraft extends Node2D:
	## A chimney of warm air rising out of the deep: step into it and he floats
	## up, all the way to the ground above (through the root mat over its
	## mouth), steering left and right as he goes. Motes and glow show it.
	const LIFT := -620.0
	var x0 := 0.0
	var x1 := 100.0
	var top := 0.0
	var bottom := 1000.0
	var _t := 0.0
	var _motes: Array = []

	func _ready() -> void:
		position = Vector2(x0, top)        # (it works in world space; drawing subtracts this)
		z_index = 1
		add_to_group("glow")
		for i in 26:
			_motes.append([randf_range(x0, x1), randf_range(top, bottom), randf_range(80, 160)])

	func _physics_process(delta: float) -> void:
		_t += delta
		var p := Underground._player(self)
		if p != null and not p.dead:
			var at := p.global_position
			if at.x > x0 and at.x < x1 and at.y > top and at.y < bottom + 4.0:
				p.velocity.y = move_toward(p.velocity.y, LIFT, 2600.0 * delta)
				p.launch(p.velocity.y)            # keeps his jumps fresh, no tumbling
		for m in _motes:
			m[1] = float(m[1]) - float(m[2]) * delta
			if float(m[1]) < top:
				m[1] = bottom
				m[0] = randf_range(x0, x1)
		if LevelBase.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var w := x1 - x0
		for i in 3:
			var sx := x0 + w * (0.25 + 0.25 * i)
			var pts := PackedVector2Array()
			for j in 12:
				var y := lerpf(bottom, top, j / 11.0)
				pts.append(Vector2(sx + sin(_t * 2.0 + j * 0.8 + i) * 10.0, y) - position)
			b.polyline(pts, Color(1.0, 0.85, 0.6, 0.12), 6.0)
		for m in _motes:
			b.circle(Vector2(m[0], m[1]) - position, 2.0, Color(1.0, 0.85, 0.55, 0.7), 6)
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		for m in _motes:
			var p := Vector2(m[0], m[1])
			if absf(p.x - global_position.x) < 2000.0:
				g.draw_circle(p, 4.0, Color(1.0, 0.8, 0.45, 0.45))


## ================================================================ LID
class Lid extends StaticBody2D:
	## A mat of roots over an updraft's mouth, on the ground: he walks on it;
	## from below, the rising air carries him up through it.
	var w := 120.0

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(w, 12)
		cs.shape = sh
		cs.position = Vector2(w * 0.5, 6)
		cs.one_way_collision = true
		add_child(cs)
		add_to_group("unsafe_ground")

	func _draw() -> void:
		var b := Batch.new()
		b.rect(Rect2(0, 0, w, 10), Color("2a1c12"))
		for i in int(w / 14.0):
			var x := 6.0 + i * 14.0
			b.line(Vector2(x, 0), Vector2(x + 10.0, 10), Color("5e452f"), 3.0)
			b.line(Vector2(x + 10.0, 0), Vector2(x, 10), Color("4a3220"), 2.0)
		b.rect(Rect2(0, -2, w, 3), Color("4f9a4c"))
		b.draw(self)
