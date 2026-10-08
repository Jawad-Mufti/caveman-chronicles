class_name OneEye
extends RefCounted
## SEMI-BOSS: OLD ONE-EYE, the worm that eats mountains. It lives in the rock
## round THE WORM'S HALL: the first cave of the Root Hollows to the right of the
## Dig's shaft, reached only by cutting the packed clay with the SHOVEL. It
## swims through the rock like a whale through the sea.
##
## FIVE ATTACKS, every one 2 hearts, and it gets worse as it gets hurt:
##   BREACH   up out of the floor, an arc through the hall, back in
##   DROP     down out of the roof onto him (dust trickles from the roof first)
##   CHARGE   a mound races under the floor at him... and it erupts straight up
##   SPIT     it peeks up far off, eye glowing, and lobs three globs of acid
##   FAKE     (hurt badly) a big rumble over THERE... it comes up HERE (a little puff)
## It never does the same thing twice running, does less of what he keeps
## dodging, and below 2/3 and 1/3 of its life it adds moves, tells faster, rests
## less (DOUBLE breaches, the spit, the fake). Every attack is told, though.
##
## The first time he comes in: it bursts out, the title card, two TUTORIAL
## pages (too big to fight: RUN; make a GLARE TRAP: berry + quartz + fire-gold
## + clay), and the crash knocks a quartz and a fire-gold loose. Clubs go TINK.
## Out of the hall, it waits. A GLARE TRAP set down in the hall lures it up
## under it: FLASH, blinded, only then it can be hurt. After each stun it comes
## for HIM once or twice before it goes for the bait again. Two stuns beat it.
## Kept: GameState.mysteries["one_eye"].

const ID := "one_eye"
const ZONE := Rect2(15400, 1660, 800, 480)    ## THE WORM'S HALL (Root Hollows, right of the Dig): floor 2130, roof 1660
const HP := 60
const DMG := 2                                ## every attack: two hearts
const STUN := 5.0
const SEGS := 12
const SKIN := Color("b98fb5")
const SKIN_DARK := Color("7a557a")
const BELLY := Color("e6c9da")
## Per phase (life left > 2/3, > 1/3, the rest): [moves, tell seconds, rest min, rest max, speed]
const PHASES := [
	[["breach", "drop", "charge"], 0.9, 0.9, 1.5, 1.0],
	[["breach", "drop", "charge", "spit", "double"], 0.72, 0.6, 1.1, 1.18],
	[["breach", "drop", "charge", "spit", "double", "fake"], 0.56, 0.35, 0.8, 1.35],
]


static func build(level: Node) -> Worm:
	if GameState.mystery(ID) == "solved":
		return null
	var w := Worm.new()
	w.level = level
	w.position = ZONE.get_center()          # (near_view and drawing work from here)
	level.add_child(w)
	return w


## The tutorial pages (the Guide) that open when he first meets it.
static func pages() -> Array:
	return [
		{"title": "OLD ONE-EYE!", "tag": "The worm that eats mountains", "accent": Color("b48ad8"), "items": [
			[func(c: CanvasItem, at: Vector2) -> void: OneEye.portrait(c, at, false), "TOO BIG TO FIGHT!", "Your club just bounces off. It bites for TWO hearts, from the floor, the roof, anywhere. RUN! Get out of its hall."],
			["trap", "MAKE A GLARE TRAP", "Its ONE EYE hates bright light, and it LOVES sweet things. Bag (I), CRAFT: 1 berry + 1 quartz + 1 fire-gold + 1 clay."],
			["quartz", "THE STONES", "Its crash knocked a QUARTZ and a FIRE-GOLD loose: grab them! Clay: dig the dirt in the Dig. Berries: the grape vines."],
		]},
		{"title": "THE TRAP", "tag": "Come back and set it", "accent": Color("f0b44a"), "items": [
			["trap", "SET IT DOWN", "Back in its hall, pick the trap in your bag and HIT: down it goes, in front of you."],
			[func(c: CanvasItem, at: Vector2) -> void: OneEye.portrait(c, at, true), "FLASH!", "It comes up to eat the berry... and the quartz BLINDS it. It flops down, eye shut, for a few seconds. BONK THE EYE!"],
			["tricks", "WATCH ITS TRICKS", "Cracks in the floor, dust from the roof, a mound racing at you, a glowing eye far off: each means something. It gets sneakier as it gets hurt!"],
		]},
	]


## Its head, for the tutorial pages: big, one eye (shut, with stars, if `stunned`).
static func portrait(c: CanvasItem, at: Vector2, stunned: bool) -> void:
	var b := Batch.new()
	OneEye.head(b, at + Vector2(0, 4), Vector2.UP.rotated(0.4), 0.9, stunned, Vector2.ZERO, 0.4, 0.0)
	b.draw(c)


## The head, centred on h, facing `dir` (the mouth end), scale k.
static func head(b: Batch, h: Vector2, dir: Vector2, k: float, stunned: bool, look: Vector2, open: float, t: float, glow := 0.0) -> void:
	var n := Vector2(-dir.y, dir.x)
	if n.y > 0.0:
		n = -n                                   # "up" on the head: the side the eye is on
	b.ellipse(h, 46.0 * k, 40.0 * k, SKIN_DARK, dir.angle())
	b.ellipse(h - n * 2.0 * k, 43.0 * k, 37.0 * k, SKIN, dir.angle())
	b.ellipse(h - n * 14.0 * k + dir * 6.0 * k, 30.0 * k, 16.0 * k, BELLY, dir.angle())
	for i in 4:
		b.circle(h + n * 26.0 * k - dir * (18.0 - i * 12.0) * k, 3.0 * k, Color("7ff0ff", 0.85), 8)
	# the mouth at the front: a dark ring of teeth, open as it lunges
	var m := h + dir * 34.0 * k
	var mo := (8.0 + 16.0 * open) * k
	b.ellipse(m, mo * 0.7, mo, Color("2a0f1a"), dir.angle())
	for i in 8:
		var a := TAU * i / 8.0
		var p := m + (dir * cos(a) * 0.7 + n * sin(a)) * mo
		b.tri(p + n.rotated(a) * 3.0 * k, p - (p - m).normalized() * 7.0 * k, p - n.rotated(a) * 3.0 * k, Color("f2ead8"))
	# THE EYE: big, on top, watching him (it glows before a spit)
	var e := h + n * 12.0 * k + dir * 8.0 * k
	b.ellipse(e + n * 6.0 * k, 20.0 * k, 7.0 * k, SKIN_DARK, dir.angle())          # a heavy brow
	if stunned:
		b.ellipse(e, 16.0 * k, 4.0 * k, Color("4a2a3a"), dir.angle())
		for i in 3:
			var a2 := t * 4.0 + i * TAU / 3.0
			var s := e + n * 30.0 * k + Vector2(cos(a2) * 26.0, sin(a2) * 8.0) * k
			b.tri(s + Vector2(0, -5) * k, s + Vector2(4, 3) * k, s + Vector2(-4, 3) * k, Color("ffe14a"))
			b.tri(s + Vector2(0, 5) * k, s + Vector2(4, -3) * k, s + Vector2(-4, -3) * k, Color("ffe14a"))
	else:
		b.ellipse(e, 17.0 * k, 15.0 * k, Color("fff6dc").lerp(Color("c8ff6a"), glow))
		var ir := e + look * 5.0 * k
		b.circle(ir, 9.5 * k, Color("c0341f").lerp(Color("4aa83a"), glow), 16)
		b.circle(ir, 7.5 * k, Color("ff9a2a").lerp(Color("c8ff4a"), glow), 16)
		b.ellipse(ir, 2.4 * k, 7.5 * k, Color("12060a"))
		b.circle(ir + Vector2(-3, -3) * k, 2.2 * k, Color(1, 1, 1, 0.9), 8)


## ================================================================ THE WORM
class Worm extends Node2D:
	var level: Node
	var hp := HP
	var state := "sleep"           ## sleep, tell, move, stunned, dive, dead
	var move := "breach"           ## breach, drop, erupt, spit (charge = a mound, then erupt)
	var st := 0.0                  ## time in this state
	var met := false
	var fight := false
	var lured: Node2D = null       ## the trap it is going for (this attack)
	var a := Vector2.ZERO          ## where it comes out (world)
	var b := Vector2.ZERO          ## breach: where it goes back in
	var peak := 0.0
	var u := 0.0                   ## how far through the move (0..1)
	var dur := 1.5                 ## this move's length
	var mound := Vector2.ZERO      ## the charge: the bump racing under the floor
	var fake_at := Vector2.ZERO    ## the fake: where the big rumble is (it comes up at `a`)
	var _last := ""
	var _misses := {}              ## move -> how many times running he dodged it
	var _hit_him := false
	var _spat := 0
	var _again := 0                ## attacks at HIM still to come before it goes for the bait
	var _double := false           ## a second breach right after this one
	var _hurt := 0.0
	var _t := 0.0
	var _hitbox: Hitbox
	var _stun_head := Vector2.ZERO
	var _body: Array = []          ## [pos, radius] this frame, head first (world)

	func _ready() -> void:
		met = GameState.mystery(ID) != ""
		z_index = 3
		add_to_group("glow")
		add_to_group("light")
		_hitbox = Hitbox.new()
		_hitbox.worm = self
		_hitbox.collision_layer = 4
		_hitbox.collision_mask = 0
		_hitbox.monitoring = false
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 44.0
		cs.shape = c
		_hitbox.add_child(cs)
		add_child(_hitbox)
		_hitbox.position = Vector2(-99999, -99999)

	func light() -> Vector4:
		if _body.is_empty():
			return Vector4.ZERO
		var h: Vector2 = _body[0][0]
		return Vector4(h.x, h.y, 170.0, 0.0)

	func light_strength() -> float:
		return 0.0 if _body.is_empty() else 0.8

	func phase() -> Array:
		return PHASES[0 if hp > HP * 2 / 3 else (1 if hp > HP / 3 else 2)]

	## ------------------------------------------ the rock round the hall
	func _ray(from: Vector2, to: Vector2) -> float:
		var q := PhysicsRayQueryParameters2D.create(from, to, 1)
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		return INF if hit.is_empty() else float((hit["position"] as Vector2).y)

	func _floor(x: float) -> float:
		var y := _ray(Vector2(x, ZONE.get_center().y), Vector2(x, ZONE.end.y + 60.0))
		return y if y < ZONE.end.y + 20.0 else INF

	func _roof(x: float) -> float:
		var y := _ray(Vector2(x, ZONE.get_center().y), Vector2(x, ZONE.position.y - 80.0))
		return y if y < INF else ZONE.position.y

	## A spot on the floor near x (never over the pit), inside the hall.
	func _spot(x: float) -> Vector2:
		x = clampf(x, ZONE.position.x + 40.0, ZONE.end.x - 40.0)
		for d in [0.0, 60.0, -60.0, 130.0, -130.0, 200.0, -200.0]:
			var xx := clampf(x + d, ZONE.position.x + 40.0, ZONE.end.x - 40.0)
			var fy := _floor(xx)
			if fy < INF:
				return Vector2(xx, fy)
		return Vector2(x, ZONE.end.y - 10.0)

	## ------------------------------------------ the fight
	func _process(delta: float) -> void:
		_t += delta
		st += delta
		_hurt = maxf(_hurt - delta, 0.0)
		var p: CaveMan = level.player
		if p == null:
			return
		var inside := ZONE.grow(30.0).has_point(p.global_position) and not p.dead
		match state:
			"sleep":
				if inside and not p.talking and (not met or st > 0.0):
					if not met:
						_first_meeting(p)
					else:
						fight = true
						_choose(p)
			"tell":
				if move == "charge":
					# the mound races at him (it steers a little after him)
					var to := p.global_position.x
					mound.x = move_toward(mound.x, to, (520.0 * float(phase()[4])) * delta)
					mound.y = _spot(mound.x).y
					if (st >= 0.35 and absf(mound.x - to) < 24.0) or st > 1.6:
						a = _spot(mound.x)
						_go("erupt", 1.0)
				elif st >= float(phase()[1]) * (1.4 if lured != null else 1.0):
					if move == "fake":
						a = _spot(p.global_position.x + randf_range(-30.0, 30.0))
						FX.burst(level, a + Vector2(0, -6), "dust")            # the little puff: the real one
						_go("erupt", 1.0)
					else:
						_go(move, {"breach": 1.5, "drop": 1.1, "spit": 2.0}.get(move, 1.2))
			"move":
				u = clampf(st / dur, 0.0, 1.4)
				if move == "breach" and lured != null and is_instance_valid(lured) and u >= 0.14 and not _hit_him:
					_blinded()
				else:
					if move == "spit":
						_spit(p)
					_bite(p)
					if u >= 1.0 + (0.35 if move == "breach" else 0.0):
						_after()
			"stunned":
				if st >= STUN:
					state = "dive"
					st = 0.0
					hud_say("It shakes its head... and dives back into the rock!")
			"dive":
				_stun_head = _stun_head.lerp(a + Vector2(0, 40), minf(1.0, delta * 5.0))
				if st >= 0.6:
					_after()
			"dead":
				if st >= 2.4:
					_rewards()
					queue_free()
					return
		if fight and not inside and state in ["sleep", "tell"]:
			fight = false
			state = "sleep"
			st = 0.0
			level.hud.set_boss(-1.0)
			if _no_trap():
				hud_say("It sinks back into the rock and waits... Make a GLARE TRAP (bag, CRAFT) and come back!")
		if fight:
			level.hud.set_boss(float(hp) / HP)
		_shape()
		_hitbox.position = (_body[0][0] - global_position) if not _body.is_empty() else Vector2(-99999, -99999)
		if LevelBase.near_view(self):
			queue_redraw()

	func _no_trap() -> bool:
		return Bag.count(level.player, "trap") <= 0 and get_tree().get_nodes_in_group("worm_trap").is_empty()

	func hud_say(text: String) -> void:
		level.hud.say(text, 4.5)

	func _word(text: String, at: Vector2, col: Color, size := 40) -> void:
		var w := CaveMan.WordPop.new()
		w.text = text
		w.size = size
		w.color = col
		w.centered = true
		w.life = 0.8
		w.position = at
		level.add_child(w)

	## The first time: it bursts out in front of him, the title card, the pages.
	func _first_meeting(p: CaveMan) -> void:
		met = true
		GameState.open_mystery(ID)
		fight = true
		var ahead := p.global_position.x + p.facing * 220.0
		a = _spot(ahead - p.facing * 30.0)
		b = _spot(ahead + p.facing * 230.0)
		peak = _roof((a.x + b.x) * 0.5) + 60.0
		lured = null
		_go("breach", 1.6)
		_hit_him = true                  # (the first one is a show: it doesn't bite)
		level.shake(10.0, 0.6)
		Bag.unearth(level, a + Vector2(0, -20), "quartz", "level2", "ow0")
		Bag.unearth(level, a + Vector2(30, -20), "pyrite", "level2", "ow1")
		level.hud.title_card("OLD ONE-EYE", "the worm that eats mountains")
		var tw := create_tween()
		tw.tween_interval(1.6)
		tw.tween_callback(func() -> void:
			var g := Guide.new()
			g.pages = OneEye.pages()
			g.player = level.player
			g.done.connect(func() -> void: hud_say("RUN! Out of its hall!"))
			level.add_child(g))

	## What next. Never the same thing twice running; less of what he dodges;
	## after a stun, him once or twice before the bait again.
	func _choose(p: CaveMan) -> void:
		state = "tell"
		st = 0.0
		_hit_him = false
		_spat = 0
		lured = null
		if _double:
			_double = false
			move = "breach"
			_aim_breach(p)
			_tell_at(a, false)
			return
		if _again <= 0:
			for tr in get_tree().get_nodes_in_group("worm_trap"):
				if ZONE.has_point((tr as Node2D).global_position) and tr.charges > 0:
					lured = tr
					break
		if lured != null:
			move = "breach"
			var dx := 1.0 if p.global_position.x >= lured.global_position.x else -1.0
			a = _spot(lured.global_position.x - dx * 10.0)
			b = _spot(lured.global_position.x + dx * 230.0)
			peak = _roof((a.x + b.x) * 0.5) + 60.0
			_tell_at(a, false)
			return
		_again = maxi(_again - 1, 0)
		var pool: Array = phase()[0]
		var weights := {}
		var total := 0.0
		for m in pool:
			if m == _last:
				continue
			var wgt := 1.0 / (1.0 + float(_misses.get(m, 0)))     # what he keeps dodging, less
			weights[m] = wgt
			total += wgt
		var r := randf() * total
		move = pool[0]
		for m in weights:
			r -= float(weights[m])
			if r <= 0.0:
				move = m
				break
		_last = move
		match move:
			"breach":
				_aim_breach(p)
				_tell_at(a, false)
			"double":
				move = "breach"
				_double = true
				_aim_breach(p)
				_tell_at(a, false)
			"drop":
				var x := clampf(p.global_position.x + p.velocity.x * 0.35, ZONE.position.x + 40.0, ZONE.end.x - 40.0)
				a = Vector2(x, _roof(x))
				b = _spot(x)
				_tell_at(a, true)
			"charge":
				var side := -1.0 if p.global_position.x > ZONE.get_center().x else 1.0
				mound = _spot(p.global_position.x + side * 340.0)
				_word("!", mound + Vector2(0, -50), Color("ff6a4a"))
			"spit":
				var far := -1.0 if p.global_position.x > ZONE.get_center().x else 1.0
				a = _spot(p.global_position.x + far * 300.0)
				_tell_at(a, false)
			"fake":
				fake_at = _spot(p.global_position.x + (260.0 if randf() < 0.5 else -260.0))
				_tell_at(fake_at, false)

	func _aim_breach(p: CaveMan) -> void:
		var dir := float(p.facing) if randf() < 0.6 else -float(p.facing)
		a = _spot(p.global_position.x - dir * 130.0)
		b = _spot(p.global_position.x + dir * 170.0)
		peak = _roof((a.x + b.x) * 0.5) + 60.0

	## The tell: cracks in the floor (or dust from the roof), and "!".
	func _tell_at(at: Vector2, roof: bool) -> void:
		_word("!", at + Vector2(0, 60 if roof else -50), Color("ff6a4a"))
		level.shake(3.0, 0.5)

	func _go(m: String, secs: float) -> void:
		move = m
		state = "move"
		st = 0.0
		u = 0.0
		dur = secs / float(phase()[4])
		if m == "erupt":
			peak = _roof(a.x) + 50.0
		FX.burst(level, a + Vector2(0, -8 if m != "drop" else 8), "dust")
		FX.shards(level, a, Vector2.UP if m != "drop" else Vector2.DOWN, true)
		level.shake(7.0, 0.3)

	## Its body this frame (world), head first, only what's out in the hall.
	func _shape() -> void:
		_body.clear()
		match state:
			"move":
				match move:
					"breach":
						for i in SEGS + 1:
							var v := u - i * 0.06
							if v > 0.0 and v < 1.0:
								_body.append([_arc(v), 44.0 if i == 0 else 30.0 - i])
					"drop":
						var reach := sin(clampf(u, 0.0, 1.0) * PI)
						_line(a + Vector2(0, -6), a.lerp(b + Vector2(0, -40), reach))
					"erupt":
						var reach2 := sin(clampf(u, 0.0, 1.0) * PI)
						_line(a + Vector2(0, 6), a.lerp(Vector2(a.x, peak), reach2))
					"spit":
						var up := clampf(u / 0.2, 0.0, 1.0) * clampf((1.0 - u) / 0.2, 0.0, 1.0)
						_line(a + Vector2(0, 6), a + Vector2(0, -150.0 * up))
			"stunned", "dive", "dead":
				var sink := clampf(st / 2.4, 0.0, 1.0) * 60.0 if state == "dead" else 0.0
				_body.append([_stun_head + Vector2(0, sink), 44.0])
				for i in range(1, SEGS + 1):
					var q := float(i) / SEGS
					_body.append([a.lerp(_stun_head, 1.0 - q) + Vector2(0, -sin((1.0 - q) * PI) * 40.0 + sink), 30.0 - i])

	## A straight body from where it comes out (`from`) to the head.
	func _line(from: Vector2, h: Vector2) -> void:
		if from.distance_to(h) < 12.0:
			return
		_body.append([h, 44.0])
		var n := int(clampf(from.distance_to(h) / 26.0, 1.0, float(SEGS)))
		for i in range(1, n + 1):
			_body.append([h.lerp(from, float(i) / n), 30.0 - i])

	func _arc(v: float) -> Vector2:
		var p := a.lerp(b, v)
		return p + Vector2(0, -(a.y - peak) * 4.0 * v * (1.0 - v))

	func _head_dir() -> Vector2:
		if state == "move":
			match move:
				"breach":
					return (_arc(u + 0.02) - _arc(u - 0.02)).normalized()
				"drop":
					return Vector2.DOWN if u < 0.5 else Vector2.UP
				_:
					return Vector2.UP
		return Vector2.from_angle(PI * 0.5 - 0.6 * signf(b.x - a.x))

	## The spit: three globs of acid lobbed at him while it peeks out.
	func _spit(p: CaveMan) -> void:
		var times := [0.35, 0.5, 0.65]
		while _spat < times.size() and u >= float(times[_spat]):
			var g := Glob.new()
			var mouth: Vector2 = a + Vector2(0, -150)
			g.position = mouth
			var dx := p.global_position.x - mouth.x + randf_range(-50, 50)
			g.vel = Vector2(dx / 0.9, -420.0)
			g.level = level
			level.add_child(g)
			_spat += 1

	## Its bite: anything of it that touches him, once an attack. TWO hearts.
	func _bite(p: CaveMan) -> void:
		if _hit_him or _body.is_empty():
			return
		var him := p.global_position + Vector2(0, -32)
		for seg in _body:
			if (seg[0] as Vector2).distance_to(him) < float(seg[1]) + 14.0:
				_hit_him = true
				var side := signf(him.x - (seg[0] as Vector2).x)
				p.hurt_toss(DMG, (seg[0] as Vector2).x, Vector2((side if side != 0.0 else 1.0) * 360.0, -420.0))
				_misses[_last] = 0
				return

	## FLASH: the trap goes off in its eye.
	func _blinded() -> void:
		_hit_him = true
		lured.flash()
		state = "stunned"
		st = 0.0
		_stun_head = _spot(a.x + (b.x - a.x) * 0.3) + Vector2(0, -30)
		_again = 1 if hp > HP / 3 else 2              # after a stun: him first, the bait after
		Critter.slow_time(get_tree(), 0.12, 0.1)
		_word("BLINDED!", _stun_head + Vector2(0, -90), Color("ffe14a"), 30)

	## After an attack (or a stun): a breather, then the next.
	func _after() -> void:
		if state == "move" and not _hit_him and _last != "":
			_misses[_last] = int(_misses.get(_last, 0)) + 1     # he dodged it: it'll try other things
		state = "sleep"
		var ph := phase()
		st = -randf_range(float(ph[2]), float(ph[3])) if not _double else -0.15

	## A blow from him (its head's hitbox): only while it lies blinded.
	func take_hit(dmg: int, _from_dir: int) -> void:
		if state == "dead" or _body.is_empty():
			return
		var h: Vector2 = _body[0][0]
		if state != "stunned":
			var w := Treasure.FloatText.new()
			w.text = "TINK!"
			w.position = h + Vector2(-20, -60)
			level.add_child(w)
			FX.burst(level, h + Vector2(0, -20), "sparks")
			return
		hp -= dmg
		_hurt = 0.15
		var d := Treasure.FloatText.new()
		d.text = "-%d" % dmg
		d.position = h + Vector2(-12, -70)
		level.add_child(d)
		Critter.slow_time(get_tree(), 0.03, 0.1)
		if hp <= 0:
			hp = 0
			state = "dead"
			st = 0.0
			fight = false
			level.hud.set_boss(-1.0)
			level.shake(12.0, 0.8)
			level.hud.title_card("OLD ONE-EYE IS BEATEN!", "the Root Hollows are quiet again")

	func _rewards() -> void:
		GameState.solve_mystery(ID)
		var h := _stun_head
		for i in 2:
			var f := Bag.Find.new()
			f.id = "obsidian"
			f.position = h + Vector2(-20 + i * 40, -40)
			f.vel = Vector2(randf_range(-80, 80), -420)
			level.add_child(f)
		GameState.orbs += 25
		GameState.save()
		_word("+25 SPIRIT ORBS", h + Vector2(0, -120), Color("cfeeff"), 26)
		FX.burst(level, h, "dust")

	## ------------------------------------------ the picture
	func draw_glow(g) -> void:   # g: the glow layer's Batch
		if state == "tell":
			var at := mound if move == "charge" else (fake_at if move == "fake" else a)
			g.draw_circle(at, 30.0 + 10.0 * sin(_t * 30.0), Color(1.0, 0.4, 0.3, 0.25))
		if not _body.is_empty() and state != "dead":
			g.draw_circle(_body[0][0], 60.0, Color(0.7, 0.5, 1.0, 0.14))

	func _draw() -> void:
		var bt := Batch.new()
		var o := -global_position
		if state == "tell":
			var k := clampf(st / maxf(float(phase()[1]), 0.1), 0.0, 1.0)
			match move:
				"drop":
					# dust trickling from the roof, cracks spreading in it
					for i in 6:
						var q := fmod(_t * 2.2 + i * 0.17, 1.0)
						bt.circle(a + o + Vector2(-30.0 + i * 12.0, 8.0 + q * 120.0), 2.5, Color(0.6, 0.55, 0.5, 1.0 - q), 6)
					for i in 6:
						var ang := 0.2 + i * 0.5
						bt.line(a + o, a + o + Vector2.from_angle(ang) * Vector2(70.0, 10.0) * k, Color(0.1, 0.05, 0.05, 0.9), 3.0)
				"charge":
					# the mound racing along under the floor
					bt.ellipse(mound + o + Vector2(0, -6), 40.0, 14.0, Color("5a3e2a"))
					bt.ellipse(mound + o + Vector2(0, -10), 32.0, 10.0, Color("7a5638"))
					for i in 4:
						var hop := absf(sin(_t * 20.0 + i)) * 16.0
						bt.circle(mound + o + Vector2(-24.0 + i * 16.0, -14.0 - hop), 3.0, Color("8d857a"), 6)
				_:
					var at := (fake_at if move == "fake" else a) + o
					for i in 7:
						var ang2 := PI + 0.2 + i * 0.45
						bt.line(at, at + Vector2.from_angle(ang2) * Vector2(70.0, 10.0) * k, Color(0.1, 0.05, 0.05, 0.9), 3.0)
					for i in 5:
						var hop2 := absf(sin(_t * 18.0 + i)) * 14.0 * k
						bt.circle(at + Vector2(-40.0 + i * 20.0, -6.0 - hop2), 3.5, Color("8d857a"), 6)
		if _body.is_empty():
			bt.draw(self)
			return
		var flash := _hurt > 0.0
		for i in range(_body.size() - 1, 0, -1):
			_seg(bt, _body[i][0] + o, float(_body[i][1]), i, flash)
		var p: CaveMan = level.player
		var h: Vector2 = _body[0][0]
		var look := (p.global_position + Vector2(0, -30) - h).normalized() if p != null else Vector2.ZERO
		var stunned := state in ["stunned", "dive", "dead"]
		var thrash := sin(_t * 30.0) * 0.4 if state == "dead" else 0.0
		var open := sin(clampf(u, 0.0, 1.0) * PI) if state == "move" else 0.6
		var glow := 1.0 if state == "move" and move == "spit" and u < 0.7 else 0.0
		OneEye.head(bt, h + o, _head_dir().rotated(thrash), 1.0, stunned, look, open, _t, glow)
		if flash:
			bt.circle(h + o, 48.0, Color(1, 1, 1, 0.45), 18)
		bt.draw(self)

	func _seg(bt: Batch, p: Vector2, r: float, i: int, flash: bool) -> void:
		var col := SKIN if i % 2 == 0 else SKIN.darkened(0.12)
		if flash:
			col = col.lerp(Color.WHITE, 0.5)
		bt.circle(p, r + 2.0, SKIN_DARK, 16)
		bt.circle(p, r, col, 16)
		bt.circle(p + Vector2(0, r * 0.35), r * 0.55, BELLY, 12)
		if i % 3 == 1:
			bt.circle(p + Vector2(0, -r * 0.6), 2.6, Color("7ff0ff", 0.8), 6)


## A glob of its acid: lobbed in an arc; two hearts if it lands on him, and a
## hissing green puddle where it lands that fades.
class Glob extends Node2D:
	var vel := Vector2.ZERO
	var level: Node
	var t := 0.0
	var _landed := -1.0

	func _ready() -> void:
		z_index = 4
		add_to_group("glow")

	func _process(delta: float) -> void:
		t += delta
		if _landed >= 0.0:
			_landed += delta
			if _landed > 1.2:
				queue_free()
			queue_redraw()
			return
		vel.y += 900.0 * delta
		var to := global_position + vel * delta
		var q := PhysicsRayQueryParameters2D.create(global_position, to, 1)
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			global_position = hit["position"]
			_landed = 0.0
			FX.burst(level, global_position, "dust")
			return
		global_position = to
		var p: CaveMan = level.player
		if p != null and p.global_position.distance_to(global_position + Vector2(0, 30)) < 34.0:
			p.hurt_toss(DMG, global_position.x, Vector2(signf(vel.x) * 260.0, -360.0))
			_landed = 0.6
		if t > 4.0:
			queue_free()
		queue_redraw()

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		g.draw_circle(global_position, 16.0, Color(0.6, 1.0, 0.3, 0.35 if _landed < 0.0 else 0.2 * (1.0 - _landed / 1.2)))

	func _draw() -> void:
		var b := Batch.new()
		if _landed >= 0.0:
			var k := 1.0 - _landed / 1.2
			b.ellipse(Vector2(0, -2), 22.0 * (0.6 + _landed), 5.0, Color(0.5, 0.9, 0.25, 0.7 * k))
			for i in 3:
				var q := fmod(t * 2.0 + i * 0.33, 1.0)
				b.circle(Vector2(-10.0 + i * 10.0, -4.0 - q * 18.0), 2.5 * (1.0 - q), Color(0.7, 1.0, 0.4, k), 6)
		else:
			b.circle(Vector2.ZERO, 9.0, Color("3f7a1a"), 12)
			b.circle(Vector2.ZERO, 7.0, Color("9be15d"), 12)
			b.circle(Vector2(-2, -3), 2.5, Color(1, 1, 0.8, 0.9), 6)
		b.draw(self)


## Its head, as something a club (or a thrown rock) can hit.
class Hitbox extends Area2D:
	var worm: Node

	func take_hit(dmg: int, from_dir: int) -> void:
		worm.take_hit(dmg, from_dir)
