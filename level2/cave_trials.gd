## The set-pieces that make Level 2's two caves longer: things that fall,
## things that hatch, things that bounce, things that crumble. Every one of
## them says what it is about to do before it does it: a stalactite shakes, a
## sac wobbles, a rat hole rumbles, a rock throws a shadow.
class_name CaveTrials
extends RefCounted


## ================================================================ STALACTITE
class Stalactite extends Node2D:
	## The Weeping Hall's roof. Come close underneath and it shakes (dust
	## trickles, a crack shows), then drops. Keep running and it lands behind
	## him; stop, or turn back, and it lands on him. It shatters on the floor,
	## crushes whatever is crawling there, and grows back a few seconds later.
	var len := 100.0
	var floor_y := 700.0
	var reach := 140.0            ## how close (sideways) sets it off
	var warn := 0.8               ## the shake, before the fall
	var regrow := 7.0
	var state := "hang"           ## hang shake fall gone
	var t := 0.0
	var timer := 0.0
	var vy := 0.0
	var drop := 0.0
	var base_y := 0.0
	var player: CaveMan
	var _shards: Array = []       ## [position, velocity, spin, size], in local coordinates
	var _shard_life := 0.0
	var _grow := 1.0              ## 0..1: it grows back down from the roof

	func _ready() -> void:
		base_y = position.y
		t = randf() * 6.0

	func _physics_process(delta: float) -> void:
		t += delta
		if player == null:
			player = get_tree().get_first_node_in_group("player") as CaveMan
		match state:
			"hang":
				_grow = minf(_grow + delta / 0.9, 1.0)
				if _grow >= 1.0 and player != null and not player.dead:
					var p := player.global_position
					if absf(p.x - global_position.x) < reach and p.y > base_y + len * 0.6 and p.y < floor_y + 30.0:
						state = "shake"
						timer = warn
			"shake":
				timer -= delta
				if timer <= 0.0:
					state = "fall"
					vy = 0.0
			"fall":
				vy += 2300.0 * delta
				drop += vy * delta
				position.y = base_y + drop
				_strike()
				if base_y + drop + len >= floor_y:
					_shatter()
			"gone":
				timer -= delta
				if timer <= 0.0:
					state = "hang"
		if _shard_life > 0.0:
			_shard_life -= delta
			for s in _shards:
				var v: Vector2 = s[1]
				v.y += 1500.0 * delta
				var p2: Vector2 = s[0]
				p2 += v * delta
				if p2.y > floor_y - base_y - 3.0:
					p2.y = floor_y - base_y - 3.0
					v = Vector2.ZERO
				s[0] = p2
				s[1] = v
		if state != "hang" or _shard_life > 0.0 or NightWoods.near_view(self):
			queue_redraw()

	func _strike() -> void:
		var tip_y := global_position.y + len
		if player != null and not player.dead:
			var p := player.global_position
			if absf(p.x - global_position.x) < 26.0 and p.y - 62.0 < tip_y and p.y > global_position.y:
				player.hurt(1, global_position.x)
		for c in get_tree().get_nodes_in_group("critters"):
			var cr := c as Critter
			if cr == null or cr.dying > 0.0:
				continue
			if absf(cr.global_position.x - global_position.x) < 30.0 and cr.global_position.y > global_position.y and cr.global_position.y - 30.0 < tip_y:
				cr.take_hit(99, 0)

	func _shatter() -> void:
		state = "gone"
		timer = regrow
		_grow = 0.0
		drop = 0.0
		position.y = base_y
		FX.burst(get_parent(), Vector2(global_position.x, floor_y), "dust")
		_shards.clear()
		for i in 7:
			_shards.append([Vector2(randf_range(-10.0, 10.0), floor_y - base_y - 8.0),
				Vector2(randf_range(-170.0, 170.0), randf_range(-420.0, -180.0)), randf_range(-9.0, 9.0), randf_range(3.0, 7.0)])
		_shard_life = 1.4
		var level := get_parent()
		if level != null and level.has_method("shake"):
			level.shake(3.0, 0.15)

	func _draw() -> void:
		var bt := Batch.new()
		var w := 15.0
		if state != "gone":
			var o := Vector2.ZERO
			if state == "shake":
				o.x = sin(t * 70.0) * 2.6
			var h := len * maxf(_grow, 0.02)
			bt.poly(PackedVector2Array([o + Vector2(-w, -10), o + Vector2(w, -10), o + Vector2(w * 0.55, h * 0.45), o + Vector2(w * 0.15, h * 0.85),
				o + Vector2(0, h), o + Vector2(-w * 0.2, h * 0.8), o + Vector2(-w * 0.6, h * 0.4)]), Pal.CAVE_ROCK)
			bt.poly(PackedVector2Array([o + Vector2(-w, -10), o + Vector2(-2, -10), o + Vector2(-2, h * 0.7), o + Vector2(-w * 0.2, h * 0.8), o + Vector2(-w * 0.6, h * 0.4)]),
				Pal.CAVE_ROCK_LIGHT.darkened(0.15))
			bt.line(o + Vector2(w * 0.3, 2), o + Vector2(w * 0.1, h * 0.6), Color(Pal.SILK, 0.25), 2.0)
			if state == "shake":
				# the crack at its root, and dust trickling
				bt.line(o + Vector2(-w * 0.9, 4), o + Vector2(w * 0.6, 11), Color(Pal.CAVE_DARK, 0.9), 2.5)
				for i in 5:
					var k := fmod(t * 1.7 + i * 0.37, 1.0)
					bt.circle(o + Vector2(-10.0 + i * 5.0, 2.0 + k * 38.0), 2.0 * (1.0 - k) + 0.6, Color(Pal.DUST, 0.7 * (1.0 - k)), 6)
			elif state == "hang":
				# now and then a drop gathers at the tip and falls: the cave weeps
				var k2 := fmod(t * 0.4 + base_y * 0.013 + global_position.x * 0.007, 1.0)
				if k2 < 0.55:
					var kk := k2 / 0.55
					bt.circle(Vector2(0, h + kk * kk * 90.0), 2.6 * (1.0 - kk * 0.5), Color(Pal.MOONLIT, 0.75 * (1.0 - kk * 0.6)), 8)
		if _shard_life > 0.0:
			var a := clampf(_shard_life / 0.6, 0.0, 1.0)
			for s in _shards:
				var p: Vector2 = s[0]
				var sz: float = s[3]
				bt.poly(PackedVector2Array([p + Vector2(-sz, sz * 0.6), p + Vector2(0, -sz), p + Vector2(sz, sz * 0.5)]), Color(Pal.CAVE_ROCK_LIGHT, a))
		bt.draw(self)


## ================================================================ SHELF
class Shelf extends StaticBody2D:
	## A thin shelf of cave rock standing out in the air: land on it from
	## above, jump up through it from below. Moss glows along its lip.
	var w := 120.0
	var t := 0.0

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(w, 14)
		cs.shape = sh
		cs.position = Vector2(w * 0.5, 7)
		cs.one_way_collision = true
		add_child(cs)
		add_to_group("glow")

	func _draw() -> void:
		var bt := Batch.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = int(position.x) * 5 + int(position.y)
		var under := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 10)])
		var x := w
		while x > 0.0:
			x -= rng.randf_range(12.0, 22.0)
			under.append(Vector2(maxf(x, 0.0), 10.0 + rng.randf_range(4.0, 22.0) * (1.0 - absf(x / w - 0.5))))
		under.append(Vector2(0, 10))
		bt.poly(under, Pal.CAVE_ROCK.darkened(0.2))
		bt.rect(Rect2(0, 0, w, 12), Pal.CAVE_ROCK)
		bt.rect(Rect2(0, 0, w, 4), Pal.CAVE_ROCK_LIGHT)
		bt.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var tt := Time.get_ticks_msec() / 1000.0
		var n := int(w / 22.0)
		for i in n:
			var on := 0.5 + 0.5 * sin(tt * 1.6 + i * 1.7)
			g.draw_circle(global_position + Vector2(10.0 + i * 22.0, -1.5), 2.0, Color("9ff3e6", 0.35 + 0.45 * on))


## ================================================================ GLOWCAP
class GlowCap extends World.SpringBush:
	## A giant cave mushroom that glows in the dark. Land on it and it squashes
	## and throws him up — not quite as far as a Moonpuff, so a cave's roof
	## stays clear. It lights itself, so a chasm full of them is a trail.
	var tint := Color("46d9c7")
	var _spores := 0.0
	var _phase := 0.0

	func _ready() -> void:
		super._ready()
		launch = -1000.0
		_phase = randf() * 6.0
		add_to_group("glow")
		add_to_group("light")
		sprung.connect(func() -> void: _spores = 1.0)

	func light() -> Vector4:
		return Vector4(global_position.x, global_position.y - 34.0, 125.0, 0.0)

	func light_strength() -> float:
		return 0.0

	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		_spores = maxf(_spores - delta * 1.1, 0.0)

	func _draw() -> void:
		var c := 1.0 - squash * 0.5
		var sq := Vector2(1.0 + squash * 0.4, c)
		var b := Batch.new()
		for s in [-1.0, 1.0]:
			b.poly(PackedVector2Array([Vector2(0, 0), Vector2(s * 32.0, -4.0), Vector2(s * 38.0, 2.0), Vector2(s * 18.0, 4.0)]), Color("2c5a52"))
		b.quad(Vector2(-8, 0), Vector2(-5, -30.0 * c), Vector2(5, -30.0 * c), Vector2(8, 0), Color("8fbcb0"))
		var centre := Vector2(0, -34.0 * c)
		var rim := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in 21:
			var a := PI + PI * i / 20.0
			rim.append(centre + Vector2(cos(a) * 38.0 * sq.x, sin(a) * 27.0 * c))
			inner.append(centre + Vector2(cos(a) * 33.0 * sq.x - 2.0, sin(a) * 23.0 * c - 1.5))
		b.poly(rim, tint.darkened(0.55))
		b.poly(inner, tint.darkened(0.12))
		for i in 6:
			var px := (-24.0 + i * 9.6) * sq.x
			b.circle(centre + Vector2(px, -4.0 - (i % 3) * 7.0 * c), 3.2 - (i % 2) * 0.8, Color(tint.lightened(0.6), 0.9), 8)
		for i in 7:
			var gx := (-28.0 + i * 9.3) * sq.x
			b.line(centre + Vector2(gx, 0), centre + Vector2(gx * 0.7, 6.0 * c), tint.darkened(0.6), 1.5)
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var c := 1.0 - squash * 0.5
		var pulse := 0.5 + 0.5 * sin(t * 1.8 + _phase)
		var at := global_position + Vector2(0, -36.0 * c)
		g.draw_circle(at, 54.0 + pulse * 7.0, Color(tint, 0.09 + 0.05 * pulse))
		g.draw_circle(at, 28.0, Color(tint, 0.12 + 0.05 * pulse))
		if _spores > 0.0:
			var k := 1.0 - _spores
			for i in 14:
				var ang := -PI * 0.5 + (i - 6.5) * 0.12
				var p := global_position + Vector2(0, -40) + Vector2.from_angle(ang) * (20.0 + k * 200.0) + Vector2(sin(i * 3.7) * 20.0 * k, 0)
				g.draw_circle(p, 3.0 * _spores + 1.0, Color(tint.lightened(0.5), _spores))


## ================================================================ EGG SAC + SPIDERLING
class EggSac extends Area2D:
	## A silk sac on the nursery floor. Something inside is moving. Walk up and
	## it wobbles, then bursts into spiderlings. But a club or a thrown rock
	## pops it from a distance — harmlessly, and there is a shell inside.
	signal popped(sac: EggSac)
	var brood := 2
	var left_x := 0.0
	var right_x := 0.0
	var state := "sleep"          ## sleep wobble open
	var t := 0.0
	var timer := 0.0
	var player: CaveMan
	var _goo := 0.0

	func _ready() -> void:
		collision_layer = 4
		collision_mask = 0
		monitoring = false
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(46, 40)
		cs.shape = sh
		cs.position = Vector2(0, -20)
		add_child(cs)
		add_to_group("glow")
		t = randf() * 5.0

	func take_hit(_dmg: int, _from_dir: int) -> void:
		if state == "open":
			return
		_open(true)

	func _physics_process(delta: float) -> void:
		t += delta
		_goo = maxf(_goo - delta, 0.0)
		if player == null:
			player = get_tree().get_first_node_in_group("player") as CaveMan
		if state == "sleep" and player != null and not player.dead:
			if absf(player.global_position.x - global_position.x) < 120.0 and absf(player.global_position.y - global_position.y) < 90.0:
				state = "wobble"
				timer = 0.6
		elif state == "wobble":
			timer -= delta
			if timer <= 0.0:
				_open(false)
		if state != "sleep" or NightWoods.near_view(self):
			queue_redraw()

	func _open(harmless: bool) -> void:
		state = "open"
		_goo = 0.8
		set_deferred("monitorable", false)
		FX.burst(get_parent(), global_position + Vector2(0, -16), "dust")
		if harmless:
			popped.emit(self)
			return
		for i in brood:
			var s := Spiderling.new()
			s.left_x = left_x
			s.right_x = right_x
			s.position = global_position + Vector2((i - (brood - 1) * 0.5) * 18.0, -14.0)
			get_parent().add_child.call_deferred(s)

	func _draw() -> void:
		var b := Batch.new()
		if state == "open":
			b.poly(PackedVector2Array([Vector2(-26, 0), Vector2(-18, -10), Vector2(-6, -4), Vector2(2, -12), Vector2(14, -5), Vector2(26, 0)]), Color(Pal.SILK, 0.75).darkened(0.1))
			b.line(Vector2(-30, -1), Vector2(-10, -14), Color(Pal.SILK, 0.6), 1.5)
			b.line(Vector2(30, -1), Vector2(12, -15), Color(Pal.SILK, 0.6), 1.5)
			b.draw(self)
			return
		var wob := 0.0
		var swell := 1.0 + 0.04 * sin(t * 2.4)
		if state == "wobble":
			wob = sin(timer * 60.0) * 3.0
			swell = 1.0 + (0.6 - timer) * 0.35
		var body := PackedVector2Array()
		for i in 14:
			var a := TAU * i / 14.0
			var r := 1.0 + 0.08 * sin(a * 3.0 + 1.0)
			body.append(Vector2(wob + cos(a) * 22.0 * swell * r, -20.0 + sin(a) * 19.0 * swell * r))
		b.poly(body, Pal.SILK.darkened(0.25))
		var lit := PackedVector2Array()
		for p in body:
			lit.append(Vector2((p.x - wob) * 0.8 + wob - 2.0, (p.y + 20.0) * 0.8 - 22.0))
		b.poly(lit, Pal.SILK)
		for k in 4:
			b.line(Vector2(wob - 14.0 + k * 9.0, -34.0 + (k % 2) * 4.0), Vector2(wob - 10.0 + k * 9.0, -6.0), Color(Pal.SILK.darkened(0.4), 0.7), 1.3)
		# silk guy-lines, to the floor
		b.line(Vector2(-22, -6), Vector2(-40, 0), Color(Pal.SILK, 0.5), 1.3)
		b.line(Vector2(22, -6), Vector2(40, 0), Color(Pal.SILK, 0.5), 1.3)
		if state == "wobble":
			# dark shapes inside, pressing against the silk
			b.circle(Vector2(wob - 6.0, -20.0), 5.0, Color(Pal.SPIDER, 0.75), 8)
			b.circle(Vector2(wob + 7.0, -15.0), 4.0, Color(Pal.SPIDER, 0.75), 8)
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		if state == "open":
			return
		var pulse := 0.5 + 0.5 * sin(t * (9.0 if state == "wobble" else 1.6))
		g.draw_circle(global_position + Vector2(0, -20), 22.0 + pulse * 4.0, Color("ff9bb8", 0.05 + 0.08 * pulse))


class Spiderling extends Critter:
	## Quick and small, and they hatch together. One stomp or one swing each.
	func death_style() -> String:
		return "curl"

	func death_floor() -> float:
		return floor_y

	var left_x := 0.0
	var right_x := 0.0
	var dir := 1
	var t := 0.0
	var vy := -320.0
	var floor_y := 0.0
	var _walk := 0.0

	func _setup() -> void:
		hp = 1
		damage = 1
		stomp_top = -13.0
		add_rect_shape(Vector2(26, 15), Vector2(0, -8))
		floor_y = position.y + 14.0
		t = randf() * 5.0
		dir = 1 if randf() < 0.5 else -1
		add_to_group("glow")

	func _tick(delta: float) -> void:
		t += delta
		if vy != 0.0 or position.y < floor_y:
			vy += 1500.0 * delta
			position.y = minf(position.y + vy * delta, floor_y)
			if position.y >= floor_y:
				vy = 0.0
				position.y = floor_y
			return
		var goal := position.x + dir * 40.0
		if player != null and not player.dead and absf(player.global_position.y - floor_y) < 90.0 and absf(player.global_position.x - position.x) < 460.0:
			goal = player.global_position.x
		var step := clampf(goal - position.x, -185.0 * delta, 185.0 * delta)
		position.x = clampf(position.x + step, left_x, right_x)
		_walk += absf(step)
		if absf(step) > 0.1:
			dir = 1 if step > 0.0 else -1
		elif position.x <= left_x + 1.0 or position.x >= right_x - 1.0:
			dir = -dir

	func _paint() -> void:
		var f := float(dir)
		var body := Vector2(0, -9)
		for side in [-1.0, 1.0]:
			var sd: float = side
			for k in 3:
				var hip := body + Vector2(sd * (1.5 + k * 2.0), -1.0)
				var step := sin(_walk * 0.45 + k * 1.4 + sd) * 2.5
				var foot := Vector2(sd * (9.0 + k * 3.0) + step, 0.0)
				var knee := Vector2((hip.x + foot.x) * 0.5 + sd * 2.0, -15.0 - k)
				_pl(PackedVector2Array([hip, knee, foot]), Pal.SPIDER.darkened(0.15 if sd < 0.0 else 0.0), 1.8, true)
		_oval(Vector2(-f * 4.0, -10), 8.0, 6.5, Pal.SPIDER)
		_oval(Vector2(f * 6.0, -8), 4.6, 4.0, Pal.SPIDER)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		if dying > 0.0:
			return
		var f := float(dir)
		var c := global_position + Vector2(f * 7.0, -9.0)
		g.draw_circle(c + Vector2(0, -1), 1.1, Color(Pal.EMBER_GLOW, 0.95))
		g.draw_circle(c + Vector2(f * 2.4, 0), 1.1, Color(Pal.EMBER_GLOW, 0.95))


## ================================================================ BONE BRIDGE
class BoneSlab extends NightWoods.CrumbleRock:
	## A mammoth rib laid across the pit. It holds a moment after he steps on
	## it, shakes, and drops; it is back a few seconds later.
	func _draw() -> void:
		var o := Vector2(0, drop)
		if state == "shaking":
			o.x = sin(timer * 80.0) * 2.5
		var a := 1.0 if state != "falling" else clampf(1.0 - drop / 400.0, 0.0, 1.0)
		if a <= 0.0:
			return
		var bt := Batch.new()
		var light := Pal.KEY_BONE
		var dark := Pal.KEY_BONE.darkened(0.42)
		bt.poly(PackedVector2Array([o + Vector2(10, 0), o + Vector2(w - 10, 0), o + Vector2(w - 8, 13), o + Vector2(w * 0.5, 19), o + Vector2(8, 13)]), Color(dark, a))
		bt.rect(Rect2(o + Vector2(10, 0), Vector2(w - 20, 6)), Color(light, a))
		for kx in [9.0, w - 9.0]:
			bt.circle(o + Vector2(kx, 8), 11.0, Color(dark, a), 12)
			bt.circle(o + Vector2(kx - 1.0, 6), 8.0, Color(light, a), 12)
		bt.line(o + Vector2(w * 0.35, 1), o + Vector2(w * 0.45, 13), Color(Pal.CHARCOAL, a * 0.8), 2.0)
		if state == "shaking":
			bt.line(o + Vector2(w * 0.6, 1), o + Vector2(w * 0.52, 12), Color(Pal.CHARCOAL, a), 2.5)
		bt.draw(self)


## ================================================================ RAT STAMPEDE
class StampedeRat extends Caves.Rat:
	## A rat out of the burrow at full tilt: straight across the alley, no
	## patrol, no pause. One hit, or one stomp.
	var kill_x := 0.0
	var speed := 260.0

	func _setup() -> void:
		super._setup()
		dir = -1

	func _tick(delta: float) -> void:
		t += delta
		position.x += dir * speed * delta
		_run += speed * delta
		if position.x < kill_x:
			queue_free()


class RatMound extends Node2D:
	## The burrow the stampede pours out of, in the face of a rock mound.
	## Step into the alley and it rumbles (the tell), then a wave of rats comes
	## out; a few waves, and the burrow is empty.
	signal rumbled(wave: int)
	var waves: Array = [2, 2, 3, 3, 2]
	var warn := 1.0
	var gap := 1.5
	var zone_x0 := 0.0            ## the alley: the burrow wakes when he steps into it
	var kill_x := 0.0             ## where the rats are gone
	var state := "idle"           ## idle rumble gap spent
	var timer := 0.0
	var wave := 0
	var t := 0.0
	var player: CaveMan

	func _ready() -> void:
		add_to_group("glow")

	func _physics_process(delta: float) -> void:
		t += delta
		if player == null:
			player = get_tree().get_first_node_in_group("player") as CaveMan
			return
		match state:
			"idle":
				var p := player.global_position
				if not player.dead and p.x > zone_x0 and p.x < global_position.x - 60.0 and absf(p.y - global_position.y) < 120.0:
					state = "rumble"
					timer = warn + 0.4
					rumbled.emit(wave)
			"rumble":
				timer -= delta
				if timer <= 0.0:
					_release()
			"gap":
				timer -= delta
				if timer <= 0.0:
					state = "rumble"
					timer = warn
					rumbled.emit(wave)
		if state == "rumble" or NightWoods.near_view(self):
			queue_redraw()

	func _release() -> void:
		var n: int = waves[wave]
		for i in n:
			var rat := StampedeRat.new()
			rat.kill_x = kill_x
			rat.left_x = kill_x
			rat.right_x = global_position.x + 100.0
			rat.speed = 240.0 + (i % 2) * 30.0
			rat.position = global_position + Vector2(-30.0 - i * 58.0, 0)
			get_parent().add_child.call_deferred(rat)
		wave += 1
		if wave >= waves.size():
			state = "spent"
		else:
			state = "gap"
			timer = gap

	func _draw() -> void:
		var b := Batch.new()
		var shake := sin(t * 60.0) * 2.0 if state == "rumble" else 0.0
		# the burrow: a dark mouth at the foot of the face, rimmed with gnawed bone
		b.poly(PackedVector2Array([Vector2(0, 0), Vector2(-46 + shake, 0), Vector2(-52 + shake, -20), Vector2(-40 + shake, -38), Vector2(-14, -44), Vector2(0, -44)]), Pal.CAVE_DARK)
		b.polyline(PackedVector2Array([Vector2(0, -44), Vector2(-14, -44), Vector2(-40 + shake, -38), Vector2(-52 + shake, -20), Vector2(-46 + shake, 0)]), Pal.KEY_BONE.darkened(0.3), 3.0)
		for k in 3:
			b.line(Vector2(-58, -6 - k * 9.0), Vector2(-74, -2 - k * 9.0), Color(Pal.CAVE_DARK, 0.8), 1.5)
		if state == "rumble":
			for k in 3:
				var kk := fmod(t * 2.3 + k * 0.33, 1.0)
				b.circle(Vector2(-60.0 - kk * 40.0, -6.0 - kk * 18.0), 4.0 * (1.0 - kk) + 1.0, Color(Pal.DUST, 0.55 * (1.0 - kk)), 8)
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		if state == "spent":
			return
		var blink := 0.6 + 0.4 * sin(t * 7.0)
		for k in 4:
			var e := global_position + Vector2(-16.0 - (k % 2) * 14.0, -20.0 - (k / 2) * 8.0)
			g.draw_circle(e, 1.3, Color(Pal.EMBER_GLOW, (0.9 if state == "rumble" else 0.35) * blink))


## ================================================================ ROCKFALL
class CaveRockfall extends NightWoods.FallingRock:
	## One rock off the cave roof: a shadow first (the tell), then the rock.
	var start_y := 200.0

	func _ready() -> void:
		super._ready()
		position.y = start_y


class Rockfall extends Node2D:
	## The Rattling Cave's run. The roof lets go along a stretch of floor: each
	## spot throws a shadow when he comes within `lead`, then the rock drops
	## `delay` later and takes half a second to fall — timed so that it lands
	## where a man running straight on would be. So this is the opposite of the Weeping Hall: don't run, read
	## the floor, let them land, then go. A rock that has landed is a rock he can
	## pick up and throw back. It re-arms on the way back, too.
	signal rattled
	var xs: Array = []
	var lead := 380.0
	var delay := 0.7
	var floor_y := 600.0
	var start_y := 220.0
	var player: CaveMan
	var _cool: Array = []
	var _told := false

	func _ready() -> void:
		for i in xs.size():
			_cool.append(0.0)

	func _physics_process(delta: float) -> void:
		if player == null:
			player = get_tree().get_first_node_in_group("player") as CaveMan
			return
		if player.dead:
			return
		var p := player.global_position
		# on this floor, or in the air above it (a jump must not dodge the tell)
		if p.y < floor_y - 280.0 or p.y > floor_y + 80.0:
			return
		for i in xs.size():
			_cool[i] = maxf(float(_cool[i]) - delta, 0.0)
			var x: float = xs[i]
			if float(_cool[i]) <= 0.0 and absf(p.x - x) < lead:
				_cool[i] = 9.0
				_drop(x)
				if not _told:
					_told = true
					rattled.emit()

	func _drop(x: float) -> void:
		var r := CaveRockfall.new()
		r.floor_y = floor_y
		r.start_y = start_y
		r.delay = delay
		r.position = Vector2(x, floor_y - 560.0)
		get_parent().add_child(r)
		FX.burst(get_parent(), Vector2(x, start_y), "dust")


## ================================================================ CRYSTALS
class Crystals extends Node2D:
	## A cluster of glowing crystal: floor-standing, or hanging from the roof.
	## They only glow; the cave around them stays dark. A landmark, and a
	## colour that tells him he is somewhere new.
	var tint := Color("5ee0d0")
	var hanging := false
	var n := 4
	var spread := 52.0
	var t := 0.0
	var _spec: Array = []         ## [x, height, width, lean]

	func _ready() -> void:
		Sleeper.enrol(self)          # far from the camera it sleeps (common/sleeper.gd)
		z_index = -1
		var rng := RandomNumberGenerator.new()
		rng.seed = int(position.x) * 3 + int(position.y)
		for i in n:
			_spec.append([(i - (n - 1) * 0.5) * spread / n * 1.6 + rng.randf_range(-5.0, 5.0), rng.randf_range(22.0, 58.0),
				rng.randf_range(8.0, 15.0), rng.randf_range(-0.35, 0.35)])
		t = rng.randf() * 6.0
		add_to_group("glow")

	func _process(delta: float) -> void:
		t += delta
		if NightWoods.near_view(self):
			queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var dirn := 1.0 if hanging else -1.0
		for s in _spec:
			var x: float = s[0]
			var h: float = s[1] * dirn
			var w: float = s[2]
			var lean: float = s[3]
			var tip := Vector2(x + lean * absf(h), h)
			b.poly(PackedVector2Array([Vector2(x - w * 0.5, 0), Vector2(x + w * 0.5, 0), tip]), tint.darkened(0.5))
			b.poly(PackedVector2Array([Vector2(x - w * 0.5, 0), Vector2(x + w * 0.05, 0), tip]), tint.darkened(0.1))
			b.line(Vector2(x - w * 0.2, h * 0.2), tip + Vector2(0, -h * 0.1), Color(tint.lightened(0.6), 0.6), 1.3)
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var pulse := 0.5 + 0.5 * sin(t * 1.3)
		var dirn := 1.0 if hanging else -1.0
		var c := global_position + Vector2(0, 26.0 * dirn)
		g.draw_circle(c, 46.0 + pulse * 6.0, Color(tint, 0.07 + 0.04 * pulse))
		g.draw_circle(c, 22.0, Color(tint, 0.09 + 0.04 * pulse))
		var spark := fmod(t * 0.6, 2.4)
		if spark < 0.4 and not _spec.is_empty():
			var k := sin(spark / 0.4 * PI)
			var s0: Array = _spec[0]
			var at := global_position + Vector2(float(s0[0]), float(s0[1]) * dirn)
			var r := 8.0 * k
			if r > 1.5:
				Treasure.glint(g, at, r, Color(1, 1, 1, k))
