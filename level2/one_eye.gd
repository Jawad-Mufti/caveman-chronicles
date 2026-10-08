class_name OneEye
extends RefCounted
## SEMI-BOSS: OLD ONE-EYE, the worm that eats mountains. It lives in the rock
## of the Glow Hollow (the low gallery at the mountain's east foot) and moves
## like a whale through the sea: it BREACHES up out of the floor, arcs through
## the tunnel and dives back in. Every breach is told first: the floor
## rumbles and cracks where it will come up ("!").
##
## The first time Ugu comes into the hollow it bursts out in front of him, the
## title card, and a TUTORIAL page: too big to fight (a club just goes TINK),
## RUN, and make a GLARE TRAP (Bag: 1 berry + 1 quartz + 1 fire-gold + 1
## clay; its eye hates light, it loves sweet things). The burst knocks a quartz
## and a fire-gold loose for him. While he is in the hollow it hunts him;
## outside, it sinks back into the rock and waits.
##
## Set the trap down in the hollow (HIT) and it can't resist the smell: it
## comes up right under it... FLASH! Blinded, it flops down, eye shut, stars
## going round: for a few seconds it can be hurt. Hit the eye! The trap has
## three flashes; two good stuns beat it. Kept: GameState.mysteries["one_eye"].

const ID := "one_eye"
const ZONE := Rect2(11230, 470, 530, 260)    ## the Glow Hollow gallery: floor ~640-680, roof ~520
const HP := 60
const STUN := 5.0                             ## seconds it lies blinded
const BREACH := 1.5                           ## seconds a breach takes, head out to tail in
const SEGS := 12
const SKIN := Color("b98fb5")
const SKIN_DARK := Color("7a557a")
const BELLY := Color("e6c9da")


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
			[func(c: CanvasItem, at: Vector2) -> void: OneEye.portrait(c, at, false), "TOO BIG TO FIGHT!", "Your club just bounces off its skin. RUN! Get out of the Glow Hollow, out of its reach."],
			["trap", "MAKE A GLARE TRAP", "Its ONE EYE hates bright light, and it LOVES sweet things. Bag (I), CRAFT: 1 berry + 1 quartz + 1 fire-gold + 1 clay."],
			["quartz", "THE STONES", "Its crash knocked a QUARTZ and a FIRE-GOLD loose: grab them! Clay: Shivers' mud bank, outside. Berries: the grape vines."],
		]},
		{"title": "THE TRAP", "tag": "Come back and set it", "accent": Color("f0b44a"), "items": [
			["trap", "SET IT DOWN", "Back in the hollow, pick the trap in your bag and HIT: down it goes, in front of you."],
			[func(c: CanvasItem, at: Vector2) -> void: OneEye.portrait(c, at, true), "FLASH!", "It comes up to eat the berry... and the quartz BLINDS it. It flops down, eye shut, for a few seconds."],
			["club", "BONK THE EYE!", "Only then can it be hurt: hit it fast! The trap flashes three times. Watch for the cracks: that's where it comes up."],
		]},
	]


## Its head, for the tutorial pages: big, one eye (shut, with stars, if `stunned`).
static func portrait(c: CanvasItem, at: Vector2, stunned: bool) -> void:
	var b := Batch.new()
	OneEye.head(b, at + Vector2(0, 4), Vector2.UP.rotated(0.4), 0.9, stunned, Vector2.ZERO, 0.4, 0.0)
	b.draw(c)


## The head, centred on h, facing `dir` (the mouth end), scale k.
static func head(b: Batch, h: Vector2, dir: Vector2, k: float, stunned: bool, look: Vector2, open: float, t: float) -> void:
	var n := Vector2(-dir.y, dir.x)
	if n.y > 0.0:
		n = -n                                   # "up" on the head: the side the eye is on
	b.ellipse(h, 46.0 * k, 40.0 * k, SKIN_DARK, dir.angle())
	b.ellipse(h - n * 2.0 * k, 43.0 * k, 37.0 * k, SKIN, dir.angle())
	b.ellipse(h - n * 14.0 * k + dir * 6.0 * k, 30.0 * k, 16.0 * k, BELLY, dir.angle())
	# glowing spots along its back
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
	# THE EYE: big, on top, watching him
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
		b.ellipse(e, 17.0 * k, 15.0 * k, Color("fff6dc"))
		var ir := e + look * 5.0 * k
		b.circle(ir, 9.5 * k, Color("c0341f"), 16)
		b.circle(ir, 7.5 * k, Color("ff9a2a"), 16)
		b.ellipse(ir, 2.4 * k, 7.5 * k, Color("12060a"))
		b.circle(ir + Vector2(-3, -3) * k, 2.2 * k, Color(1, 1, 1, 0.9), 8)


## ================================================================ THE WORM
class Worm extends Node2D:
	var level: Node
	var hp := HP
	var state := "sleep"           ## sleep, rumble, breach, stunned, dive, dead
	var st := 0.0                  ## time in this state
	var met := false
	var fight := false             ## he is in the hollow and it is after him
	var a := Vector2.ZERO          ## where it comes up (world)
	var b := Vector2.ZERO          ## where it dives back in (world)
	var peak := 0.0                ## the top of its arc (world y)
	var lured: Node2D = null       ## the trap it is going for
	var u := 0.0                   ## where the head is along the arc (0 out of the floor, 1 back in)
	var _cool := 0.0
	var _hurt := 0.0
	var _t := 0.0
	var _hitbox: Hitbox
	var _hit_him := false          ## one bite per breach
	var _stun_head := Vector2.ZERO
	var _intro := false            ## the first meeting is playing

	func _ready() -> void:
		met = GameState.mystery(ID) != ""
		z_index = 3
		add_to_group("glow")
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

	## ------------------------------------------ where things are
	func _floor(x: float) -> float:
		var y: float = level.mountain.ground_y(x, ZONE.get_center().y)
		return y if y < INF else ZONE.end.y - 50.0

	func _roof(x: float) -> float:
		var y: float = level.mountain.roof_y(x, ZONE.get_center().y)
		return y if y > -INF else ZONE.position.y + 40.0

	## A point on the arc, u 0..1 (beyond: under the floor).
	func _at(v: float) -> Vector2:
		var p := a.lerp(b, v)
		return p + Vector2(0, -(a.y - peak) * 4.0 * v * (1.0 - v))

	func _dir_at(v: float) -> Vector2:
		return (_at(v + 0.02) - _at(v - 0.02)).normalized()

	func _head_pos() -> Vector2:
		return _stun_head if state == "stunned" else _at(u)

	func _visible_head() -> bool:
		return (state == "breach" and u > 0.02 and u < 0.98) or state == "stunned" or state == "dive" or state == "dead"

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
				if inside and not p.talking and (not met or st > 0.6):
					if not met:
						_first_meeting(p)
					else:
						fight = true
						_start_rumble(p)
			"rumble":
				if st >= 0.9:
					_breach()
			"breach":
				u = st / BREACH * (1.0 + 0.35) - 0.05
				if lured != null and is_instance_valid(lured) and u >= 0.14 and u < 0.2 and not _hit_him:
					_blinded()
				elif u >= 1.35:
					_after()
				else:
					_bite(p)
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
		# out of the hollow: it gives up (once the breach it is in is over)
		if fight and not inside and state in ["sleep", "rumble"]:
			fight = false
			state = "sleep"
			st = 0.0
			level.hud.set_boss(-1.0)
			hud_say("It sinks back into the rock and waits... Make a GLARE TRAP (bag, CRAFT) and come back!" if _no_trap() else "")
		if fight:
			level.hud.set_boss(float(hp) / HP)
		var h := _head_pos()
		_hitbox.position = (h - global_position) if _visible_head() else Vector2(-99999, -99999)
		if LevelBase.near_view(self):
			queue_redraw()

	func _no_trap() -> bool:
		return Bag.count(level.player, "trap") <= 0 and get_tree().get_nodes_in_group("worm_trap").is_empty()

	func hud_say(text: String) -> void:
		if text != "":
			level.hud.say(text, 4.5)

	## The first time: it bursts out in front of him, the title card, the pages.
	func _first_meeting(p: CaveMan) -> void:
		met = true
		_intro = true
		GameState.open_mystery(ID)
		fight = true
		var ahead := clampf(p.global_position.x + p.facing * 200.0, ZONE.position.x + 60.0, ZONE.end.x - 60.0)
		_set_arc(ahead - p.facing * 30.0, ahead + p.facing * 210.0)
		lured = null
		state = "breach"
		st = 0.0
		_hit_him = true                  # (the first one is a show: it doesn't bite)
		level.shake(10.0, 0.6)
		# its crash knocks two of the trap's stones loose for him
		Bag.unearth(level, a + Vector2(0, -20), "quartz", "level2", "ow0")
		Bag.unearth(level, a + Vector2(30, -20), "pyrite", "level2", "ow1")
		level.hud.title_card("OLD ONE-EYE", "the worm that eats mountains")
		var tw := create_tween()
		tw.tween_interval(1.6)
		tw.tween_callback(func() -> void:
			var g := Guide.new()
			g.pages = OneEye.pages()
			g.player = level.player
			g.done.connect(func() -> void:
				_intro = false
				hud_say("RUN! Out of the Glow Hollow!"))
			level.add_child(g))

	func _set_arc(x0: float, x1: float) -> void:
		x0 = clampf(x0, ZONE.position.x + 30.0, ZONE.end.x - 30.0)
		x1 = clampf(x1, ZONE.position.x + 30.0, ZONE.end.x - 30.0)
		if absf(x1 - x0) < 160.0:
			x1 = x0 + (160.0 if x1 >= x0 else -160.0)
		a = Vector2(x0, _floor(x0))
		b = Vector2(x1, _floor(x1))
		peak = _roof((x0 + x1) * 0.5) + 44.0

	## The tell: the floor rumbles and cracks where it will come up.
	func _start_rumble(p: CaveMan) -> void:
		state = "rumble"
		st = 0.0
		_hit_him = false
		lured = null
		for tr in get_tree().get_nodes_in_group("worm_trap"):
			if ZONE.has_point((tr as Node2D).global_position) and tr.charges > 0:
				lured = tr
				break
		if lured != null:
			# the smell: up right under the bait, out toward him
			var dx := 1.0 if p.global_position.x >= lured.global_position.x else -1.0
			_set_arc(lured.global_position.x - dx * 10.0, lured.global_position.x + dx * 220.0)
		else:
			# at him: up behind him, over where he stands
			var dir := float(p.facing)
			_set_arc(p.global_position.x - dir * 120.0, p.global_position.x + dir * 160.0)
		var w := CaveMan.WordPop.new()
		w.text = "!"
		w.size = 40
		w.color = Color("ff6a4a")
		w.centered = true
		w.life = 0.8
		w.position = a + Vector2(0, -50)
		level.add_child(w)
		level.shake(4.0, 0.9)

	func _breach() -> void:
		state = "breach"
		st = 0.0
		FX.burst(level, a + Vector2(0, -8), "dust")
		FX.shards(level, a + Vector2(0, -6), Vector2.UP, true)
		level.shake(7.0, 0.3)

	## FLASH: the trap goes off in its eye.
	func _blinded() -> void:
		_hit_him = true
		lured.flash()
		state = "stunned"
		st = 0.0
		_stun_head = Vector2(a.x + (b.x - a.x) * 0.3, _floor(a.x + (b.x - a.x) * 0.3) - 30.0)
		Critter.slow_time(get_tree(), 0.12, 0.1)
		var w := CaveMan.WordPop.new()
		w.text = "BLINDED!"
		w.size = 30
		w.color = Color("ffe14a")
		w.centered = true
		w.life = 1.2
		w.position = _stun_head + Vector2(0, -90)
		level.add_child(w)

	## Its bite: anything of it that touches him, once a breach.
	func _bite(p: CaveMan) -> void:
		if _hit_him or u <= 0.0:
			return
		var him := p.global_position + Vector2(0, -32)
		for i in SEGS + 1:
			var v := u - i * 0.06
			if v <= 0.0 or v >= 1.0:
				continue
			var r := 44.0 if i == 0 else 30.0 - i
			if _at(v).distance_to(him) < r + 14.0:
				_hit_him = true
				var side := signf(him.x - _at(v).x)
				p.hurt_toss(1, _at(v).x, Vector2((side if side != 0.0 else 1.0) * 320.0, -380.0))
				return

	## After a breach or a stun: a breather, then again (if he is still here).
	func _after() -> void:
		state = "sleep"
		st = 0.0
		lured = null
		if fight:
			st = -randf_range(0.4, 1.0)

	## A blow from him (its head's hitbox): only while it lies blinded.
	func take_hit(dmg: int, _from_dir: int) -> void:
		if state == "dead":
			return
		var h := _head_pos()
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
			level.hud.title_card("OLD ONE-EYE IS BEATEN!", "the mountain is quiet again")

	func _rewards() -> void:
		GameState.solve_mystery(ID)
		var h := _head_pos()
		for i in 2:
			var f := Bag.Find.new()
			f.id = "obsidian"
			f.position = h + Vector2(-20 + i * 40, -40)
			f.vel = Vector2(randf_range(-80, 80), -420)
			level.add_child(f)
		GameState.orbs += 25
		GameState.save()
		var w := CaveMan.WordPop.new()
		w.text = "+25 SPIRIT ORBS"
		w.size = 26
		w.color = Color("cfeeff")
		w.centered = true
		w.life = 1.6
		w.position = h + Vector2(0, -120)
		level.add_child(w)
		FX.burst(level, h, "dust")

	## ------------------------------------------ the picture
	func draw_glow(g) -> void:   # g: the glow layer's Batch
		if state == "rumble":
			g.draw_circle(a, 30.0 + 10.0 * sin(_t * 30.0), Color(1.0, 0.4, 0.3, 0.25))
		if _visible_head() and state != "dead":
			var h := _head_pos()
			g.draw_circle(h, 60.0, Color(0.7, 0.5, 1.0, 0.14))

	func _draw() -> void:
		var bt := Batch.new()
		var o := -global_position
		if state == "rumble":
			# cracks spreading on the floor where it will come up, pebbles hopping
			var k := clampf(st / 0.9, 0.0, 1.0)
			for i in 7:
				var ang := PI + 0.2 + i * 0.45
				var end := a + o + Vector2.from_angle(ang) * Vector2(70.0, 10.0) * k
				bt.line(a + o, end, Color(0.1, 0.05, 0.05, 0.9), 3.0)
			for i in 5:
				var hop := absf(sin(_t * 18.0 + i)) * 14.0 * k
				bt.circle(a + o + Vector2(-40.0 + i * 20.0, -6.0 - hop), 3.5, Color("8d857a"), 6)
		if not _visible_head():
			bt.draw(self)
			return
		var flash := _hurt > 0.0
		if state == "stunned" or state == "dive" or state == "dead":
			# lying blinded: the body comes up out of the floor in a low hump to the head
			var root := a + o
			var hp2 := _head_pos() + o
			var sink := clampf(st / 2.4, 0.0, 1.0) if state == "dead" else 0.0
			for i in range(SEGS, 0, -1):
				var q := float(i) / SEGS
				var p := root.lerp(hp2, 1.0 - q) + Vector2(0, -sin((1.0 - q) * PI) * 40.0 + sink * 60.0)
				_seg(bt, p, 30.0 - i, i, flash)
			var thrash := sin(_t * 30.0) * 0.4 * (1.0 - sink) if state == "dead" else 0.0
			OneEye.head(bt, hp2 + Vector2(0, sink * 60.0), Vector2.from_angle(PI * 0.5 - 0.6 * signf(b.x - a.x) + thrash), 1.0, true, Vector2.ZERO, 0.6, _t)
		else:
			# breaching: segments along the arc behind the head, the ones under the floor hidden
			for i in range(SEGS, 0, -1):
				var v := u - i * 0.06
				if v <= 0.0 or v >= 1.0:
					continue
				_seg(bt, _at(v) + o, 30.0 - i, i, flash)
			if u > 0.0 and u < 1.0:
				var p: CaveMan = level.player
				var look := (p.global_position + Vector2(0, -30) - _at(u)).normalized() if p != null else Vector2.ZERO
				OneEye.head(bt, _at(u) + o, _dir_at(u), 1.0, false, look, sin(clampf(u, 0.0, 1.0) * PI), _t)
		if flash:
			bt.circle(_head_pos() + o, 48.0, Color(1, 1, 1, 0.45), 18)
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


## Its head, as something a club (or a thrown rock) can hit.
class Hitbox extends Area2D:
	var worm: Node

	func take_hit(dmg: int, from_dir: int) -> void:
		worm.take_hit(dmg, from_dir)
