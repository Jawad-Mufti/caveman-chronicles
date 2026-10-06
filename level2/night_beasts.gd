## Level 2 critters: the things that live at the edge of the firelight.
## Kept in one file so the whole bestiary for the night is in view.
class_name NightBeasts
extends RefCounted


class Wolf extends Critter:
	## A pack hunter that respects the light — but doesn't run from it.
	##
	## The moment it sees him it charges: a short crouch (eyes flare — the
	## tell), then the leap, aimed where he'll be when it lands. It doesn't back
	## off as he comes on; it stands its ground and goes for him again and again,
	## and two of a pack can come close together. What happens when a leap
	## arrives depends on the light, and on which way he faces:
	##   a strong light (torch at half or more, or a bonfire) held TOWARD it
	##       -> it yelps and recoils, stunned for a beat: the moment to club it
	##   his back to it, or the torch below half -> the leap lands and bites
	##   torch out and no fire near -> the whole pack comes in
	## It runs faster than he does, and if he turns to flee it gives chase. So
	## the way through a pack is to face it and fight — and hitting a wolf as
	## it recoils is how the level teaches the sabre-tooth.

	## Only one wolf tests him at a time; shared across the whole pack.
	static var _last_lunge_ms := -100000

	const GRAV := 1720.0
	const WALK := 230.0
	const RETREAT := 340.0
	const HUNT := 310.0       ## faster than he runs: he can't simply outrun the pack
	const PATROL := 72.0
	const NOTICE := 560.0     ## he is noticed inside this, if he is on roughly its level
	const FORGET := 820.0     ## and forgotten again past this
	## He is in its reach only while his footing — where he last stood, so a
	## jump doesn't count — is its own ground, give or take this much (the
	## hollow's rim, 100 above the pack, still counts). Up on an outcrop, a sky
	## island or a branch he is out of reach: it forgets him and goes back to
	## pacing, rather than running about underneath him.
	const REACH_UP := 105.0
	static var _his_footing := 600.0
	const SIZE := 0.8         ## drawn at 0.8 of its design size

	var left_x := 0.0        ## the stretch of ground it is bound to
	var right_x := 0.0
	var floor_y := 0.0
	var dir := -1
	var state := "patrol"    ## patrol stalk crouch lunge recoil hunt flee cower
	var timer := 0.0
	var vel := Vector2.ZERO
	var t := 0.0
	var lunge_cd := 2.0
	var panic := false       ## running for its life from something bigger: ignores him entirely
	var panic_end := 0.0     ## and is gone once it passes this x
	var slot := 50.0         ## how far past the light's edge it waits; its own, so the pack spreads out
	var slot_t := 0.0
	var pause := 0.0         ## sniffing at the end of a patrol leg
	var resolved := false    ## has this leap already been judged against the light?
	var night: Night
	var _stride := 0.0       ## gait phase, driven by distance covered so paws do not slide
	var _moving := 0.0
	## Tougher now that he has weapons: nine health, it snaps back when hit,
	## bites twice, and only a strong light turns its leap. Some flank him.
	var frenzy := false      ## called by Old Scar: the light doesn't hold it back at all
	var flank := false       ## in the dark it darts past him, to bite from behind
	var _second := false     ## its follow-up bite is used

	func _setup() -> void:
		hp = 7
		flank = randf() < 0.4
		self_modulate = Color(0.84, 0.82, 0.86)     # a darker, meaner coat
		damage = 0
		stomp_top = -36.0
		add_rect_shape(Vector2(60, 34), Vector2(0, -19))
		floor_y = position.y
		t = randf() * 10.0
		dir = 1 if randf() < 0.5 else -1
		lunge_cd = randf_range(1.5, 4.0)
		add_to_group("glow")

	func scare(_from: Vector2) -> void:
		if dying > 0.0:
			return
		state = "flee"
		timer = 1.6

	## Beaten, a wolf doesn't just die — it's a cartoon: "YIP!", a pinwheel
	## tumble through the air, a landing flat on its back with X-eyes and its
	## tongue out, legs twitching... then it springs up and bolts for the
	## trees, tail tucked, crying "KAI! KAI!" (A stomp still squashes it flat.)
	var _ko_t := 0.0
	var _kai_in := 0.0

	func death_style() -> String:
		return "wolf"

	func _begin_death(from_dir: int) -> void:
		super._begin_death(from_dir)
		if _style != "wolf":
			return
		var d := float(from_dir) if from_dir != 0 else 1.0
		_dv = Vector2(d * 240.0, -560.0) * Vector2(fling, sqrt(fling))
		_dspin = d * 15.0
		_dlift = _body_height()
		dying = 2.8
		state = "tumble"
		_say("YIP!")

	func _say(word: String) -> void:
		var pop := Treasure.FloatText.new()
		pop.text = word
		pop.position = global_position + Vector2(-14, -60)
		get_parent().add_child.call_deferred(pop)

	func _death_step(delta: float) -> void:
		if _style != "wolf":
			super._death_step(delta)
			return
		death_t += delta
		dying = maxf(2.8 - death_t, 0.001)
		match state:
			"tumble":
				_dv.y += 1500.0 * delta
				position += _dv * delta
				rotation += _dspin * delta
				if position.y >= _dfloor and _dv.y > 0.0:
					# flat on its back, legs in the air
					position.y = _dfloor - _dlift
					rotation = PI
					state = "ko"
					_ko_t = 0.0
					var stars := Critter.Dizzy.new()
					stars.life = 0.75
					stars.radius = 22.0
					stars.position = Vector2(0, 40)
					add_child(stars)
					var dust := Critter.DeathPop.new()
					dust.dust = true
					dust.position = Vector2(position.x, _dfloor)
					get_parent().add_child(dust)
			"ko":
				_ko_t += delta
				rotation = PI + sin(death_t * 34.0) * 0.03
				if _ko_t > 0.75:
					# up on its feet, and away from him as fast as it can go
					state = "bolt"
					rotation = 0.0
					position.y = _dfloor
					dir = -1 if player == null or player.global_position.x > position.x else 1
					_say("KAI!")
			"bolt":
				position.x += dir * 640.0 * delta
				_stride += 640.0 * delta
				_moving = 640.0
				_kai_in -= delta
				if _kai_in <= 0.0:
					_kai_in = 0.32
					_say("KAI!")
					var dust := Critter.DeathPop.new()
					dust.dust = true
					dust.position = Vector2(position.x - dir * 20.0, _dfloor)
					get_parent().add_child(dust)
				modulate.a = clampf((2.8 - death_t) / 0.5, 0.0, 1.0)
		if death_t >= 2.8:
			queue_free()
			return
		queue_redraw()

	## Fire is what a wolf fears most: a fire burst (the wood he spends on it)
	## kills one outright.
	func burned(_dmg: int, from: Vector2) -> void:
		if dying > 0.0:
			return
		take_hit(maxi(hp, 1), 1 if global_position.x > from.x else -1)

	## The hammer's rolling fire: it hurts, and it knocks the wolf flat.
	func fire_wave(dmg: int, from: Vector2) -> void:
		if dying > 0.0:
			return
		var d := 1 if global_position.x > from.x else -1
		take_hit(dmg, d)
		stagger(d, 0.9)

	## Knocked flat by the hammer: thrown back and stunned, no snapping back.
	func stagger(from_dir: int, secs: float) -> void:
		if dying > 0.0 or hp <= 0:
			return
		state = "recoil"
		vel = Vector2(from_dir * 300.0, -260.0)
		timer = secs
		damage = 0

	## Hit, it doesn't run any more: it staggers, then snaps straight back.
	func _on_hit(from_dir: int) -> void:
		position.x = clampf(position.x + from_dir * 16.0, left_x, right_x)
		if hp > 0 and state != "recoil":
			if randf() < 0.75 and Critter.may_attack(self, 1400):
				# it snaps straight back at him
				state = "crouch"
				timer = 0.45
				lunge_cd = 0.0
				dir = -from_dir
			else:
				# or backs off a few steps, snarling, to come again
				state = "flee"
				timer = 0.5

	func _in_reach() -> bool:
		return absf(_his_footing - floor_y) <= REACH_UP

	func _level() -> bool:
		return absf(player.global_position.y - floor_y) < 60.0

	func _lit_at(x: float) -> bool:
		return night.is_lit(Vector2(x, floor_y - 24.0))

	func _shelter() -> float:
		return night.shelter_at(player.global_position + Vector2(0, -36))

	## Where to stand: the first dark ground on this wolf's side of him, plus
	## a little restless drift. Walks outward from him until the light ends.
	func _edge_target() -> float:
		var side := signf(position.x - player.global_position.x)
		if side == 0.0:
			side = 1.0
		var x := player.global_position.x
		var steps := 0
		while steps < 45 and _lit_at(x):
			x += side * 16.0
			steps += 1
		return x + side * slot

	func _move_to(tx: float, speed: float, delta: float, avoid_light: bool) -> void:
		tx = clampf(tx, left_x, right_x)
		var step := clampf(tx - position.x, -speed * delta, speed * delta)
		if avoid_light and step != 0.0 and _lit_at(position.x + step + signf(step) * 20.0):
			step = 0.0
		position.x += step
		_stride += absf(step)
		_moving = absf(step) / maxf(delta, 0.001)
		if _moving > 60.0:
			dir = 1 if step > 0.0 else -1

	func _tick(delta: float) -> void:
		t += delta
		timer = maxf(timer - delta, 0.0)
		lunge_cd = maxf(lunge_cd - delta, 0.0)
		_moving = 0.0
		if night == null:
			night = get_tree().get_first_node_in_group("night") as Night
		if night == null or player == null:
			return
		damage = 0
		if panic:
			dir = -1
			position.x -= 430.0 * delta
			_stride += 430.0 * delta
			_moving = 430.0
			state = "flee"
			if position.x < panic_end:
				queue_free()
			return
		if player.is_on_floor():
			_his_footing = player.global_position.y
		var dx := player.global_position.x - position.x
		if frenzy and state in ["patrol", "stalk", "cower"]:
			state = "hunt"
		match state:
			"patrol":
				_patrol(delta)
				if absf(dx) < NOTICE and _in_reach():
					state = "stalk"
					slot_t = 0.0
					# it charges the moment it sees him: a short crouch (the tell), then the leap
					if _level() and player.invuln <= 0.0 and Critter.may_attack(self, 1400):
						_last_lunge_ms = Time.get_ticks_msec()
						state = "crouch"
						timer = 0.26
			"stalk":
				_stalk(dx, delta)
				if state == "stalk":
					_restless(dx, delta)
			"feint":
				# a fake lunge: in at him, snapping... and straight back out
				var into := 1.0 if timer > 0.2 else -1.0
				_move_to(position.x + _feint_dir * into * 40.0, 300.0, delta, false)
				dir = int(_feint_dir)
				if timer <= 0.0:
					state = "stalk"
			"howl":
				# head up, calling the pack: when the howl ends, another one comes running
				dir = 1 if dx > 0.0 else -1
				if timer <= 0.0:
					_call_packmate()
					state = "stalk"
			"crouch":
				dir = 1 if dx > 0.0 else -1
				if timer <= 0.0:
					if floor_y - player.global_position.y > 140.0:
						# he has gone up out of reach (a bloom, a ledge) while it crouched: no leap
						state = "stalk"
						lunge_cd = 0.4
					else:
						_leap(dx)
			"lunge":
				damage = 1
				_fly(delta)
			"recoil":
				_fall(delta)
				if timer <= 0.0:
					state = "stalk"
			"hunt":
				_hunt(dx, delta)
				if state == "hunt":
					_restless(dx, delta)
			"flee":
				var away := -1 if dx > 0.0 else 1
				_move_to(position.x + away * 120.0, RETREAT, delta, false)
				dir = away
				if timer <= 0.0:
					state = "stalk"
			"cower":
				dir = 1 if dx > 0.0 else -1
				if not _lit_at(position.x):
					state = "stalk"

	## Waiting its turn, it doesn't just stand there: it feints at him (a fake
	## lunge and a snarl), and a hurt or a lone wolf HOWLS for the pack.
	var _feint_cd := 1.5
	var _feint_dir := 1.0
	var _howled := false
	var _stalk_t := 0.0
	static var _last_howl_ms := -100000
	static var _called := 0          ## packmates called and still about

	func _restless(dx: float, delta: float) -> void:
		_feint_cd -= delta
		_stalk_t += delta
		if not _howled and _level() and absf(dx) < 600.0 and _called < 4 \
				and Time.get_ticks_msec() - _last_howl_ms > 8000 and (hp <= 4 or _stalk_t > 6.0) and randf() < (0.06 if hp <= 4 else 0.02):
			_howled = true
			_last_howl_ms = Time.get_ticks_msec()
			state = "howl"
			timer = 1.0
			_say("AWOOOO!")
			return
		if _feint_cd <= 0.0 and absf(dx) < 420.0 and _level():
			_feint_cd = randf_range(1.0, 2.4)
			_feint_dir = signf(dx) if dx != 0.0 else 1.0
			state = "feint"
			timer = 0.4
			if randf() < 0.45:
				_say("GRRR!")

	## The howl is answered: a packmate comes running in from beyond the view.
	func _call_packmate() -> void:
		if not is_inside_tree() or player == null:
			return
		var mate := Wolf.new()
		mate.left_x = left_x
		mate.right_x = right_x
		var side := -1.0 if randf() < 0.5 else 1.0
		var x := clampf(player.global_position.x + side * (LevelBase.view_half(self).x + 60.0), left_x, right_x)
		if absf(x - player.global_position.x) < 160.0:
			x = right_x if player.global_position.x < (left_x + right_x) * 0.5 else left_x
		mate.position = Vector2(x, floor_y)
		mate.state = "stalk"
		mate._howled = true                       # (no chain of howls)
		mate.tree_exiting.connect(func() -> void: _called = maxi(0, _called - 1))
		_called += 1
		get_parent().add_child(mate)

	## Not hunting yet: an even trot from one end of its ground to the other,
	## a pause to sniff at each end, and it turns back rather than walk into light.
	func _patrol(delta: float) -> void:
		if pause > 0.0:
			pause -= delta
			return
		var goal := right_x - 20.0 if dir > 0 else left_x + 20.0
		var before := position.x
		_move_to(goal, PATROL, delta, true)
		if absf(position.x - goal) < 2.0 or absf(position.x - before) < 0.01:
			dir = -dir
			pause = randf_range(1.0, 2.4)

	func _stalk(dx: float, delta: float) -> void:
		if absf(dx) > FORGET or not _in_reach():
			state = "patrol"
			pause = 0.6
			return
		slot_t -= delta
		if slot_t <= 0.0:
			slot = randf_range(30.0, 80.0)
			slot_t = randf_range(3.0, 5.0)
		if _shelter() <= 0.0 and _level() and absf(dx) < 700.0:
			state = "hunt"
			return
		# he's turned his back to run: it gives chase, light or no light, and
		# leaps from close behind — the torch only scares it off when it's held
		# toward it
		var facing_it := player.facing == (1 if position.x > player.global_position.x else -1)
		if not facing_it and _level() and absf(dx) < 560.0:
			_move_to(player.global_position.x - signf(dx) * 60.0, HUNT, delta, false)
			dir = 1 if dx > 0.0 else -1
			if lunge_cd <= 0.0 and absf(dx) < 300.0 and player.invuln <= 0.0 \
					and Critter.may_attack(self, 1400):
				_last_lunge_ms = Time.get_ticks_msec()
				state = "crouch"
				timer = 0.2
			return
		var tx := _edge_target()
		if _lit_at(position.x):
			# caught in his light: it doesn't back off any more — it stands its
			# ground, snarling, and goes for him as soon as it can
			dir = 1 if dx > 0.0 else -1
			if lunge_cd <= 0.0 and _level() and absf(dx) < 560.0 and player.invuln <= 0.0 \
					and Critter.may_attack(self, 1400):
				_last_lunge_ms = Time.get_ticks_msec()
				state = "crouch"
				timer = 0.26
			return
		# a dead band, so it holds its spot instead of twitching after every step
		# he takes — and it only ever closes in: as he comes on, it stands its ground
		var closer := signf(tx - position.x) == signf(dx)
		if absf(tx - position.x) > 18.0 and closer:
			_move_to(tx, WALK, delta, true)
		if _moving < 60.0:
			dir = 1 if dx > 0.0 else -1
		var px := player.global_position.x
		if lunge_cd <= 0.0 and _level() and absf(dx) < 560.0 \
				and px > left_x - 40.0 and px < right_x + 40.0 \
				and player.invuln <= 0.0 and Critter.may_attack(self, 1400):
			_last_lunge_ms = Time.get_ticks_msec()
			state = "crouch"
			timer = 0.26

	## In the dark he is simply prey: close in, and leap from close range.
	## No turn-taking here — the pack comes in together.
	func _hunt(dx: float, delta: float) -> void:
		if not frenzy and (_shelter() > 0.0 or not _level()):
			state = "stalk"
			return
		dir = 1 if dx > 0.0 else -1
		# a flanker goes round to his far side, to come at him from behind
		var side := signf(dx) if flank else -signf(dx)
		var want := clampf(player.global_position.x + side * 100.0, left_x, right_x)
		if absf(want - position.x) > 20.0:
			_move_to(want, HUNT * (1.25 if frenzy else 1.0), delta, false)
		if lunge_cd <= 0.0 and absf(dx) < 260.0 and player.invuln <= 0.0 and Critter.may_attack(self, 1400):
			state = "crouch"
			timer = 0.24

	func _leap(dx: float) -> void:
		Critter.keep_attack(self, 1100)          # its turn lasts the whole leap
		# it aims where he'll be when it comes down, not where he is
		var land := clampf(player.global_position.x + player.velocity.x * 0.42, left_x, right_x)
		var d := clampf(land - position.x, -470.0, 470.0)
		if absf(d) < 30.0:
			d = 30.0 * signf(dx if dx != 0.0 else 1.0)
		vel = Vector2(d / 0.42, -430.0)
		state = "lunge"
		resolved = false
		lunge_cd = randf_range(1.1, 1.8) if frenzy else (randf_range(0.8, 1.4) if _shelter() <= 0.0 else randf_range(0.9, 1.6))

	func _fly(delta: float) -> void:
		vel.y += GRAV * delta
		position += vel * delta
		if not resolved:
			var ddx := absf(player.global_position.x - position.x)
			var ddy := absf((player.global_position.y - 30.0) - (position.y - 18.0))
			if ddx < 58.0 and ddy < 70.0:
				resolved = true
				# only a strong light HELD TOWARD it turns it now: running away, his
				# back is to it and the bite lands. A frenzied one, nothing turns.
				var facing_it := player.facing == (1 if position.x > player.global_position.x else -1)
				if not frenzy and _shelter() >= 0.75 and facing_it:
					_yelp()
					return
		if position.y >= floor_y and vel.y > 0.0:
			position.y = floor_y
			vel = Vector2.ZERO
			position.x = clampf(position.x, left_x, right_x)
			# landed right by him after a bite: now and then it snaps again at once
			if resolved and not _second and absf(player.global_position.x - position.x) < 110.0 and randf() < 0.5 \
					and Critter._attackers.has(get_instance_id()):
				_second = true
				state = "crouch"
				timer = 0.2
				return
			_second = false
			Critter.attack_done(self)          # its turn is over: the next one may come
			state = "hunt" if frenzy else "stalk"

	## The leap broke on the light. It flinches back and stays stunned.
	func _yelp() -> void:
		Critter.attack_done(self)
		state = "recoil"
		damage = 0
		var away := -1.0 if player.global_position.x > position.x else 1.0
		vel = Vector2(away * 260.0, -240.0)
		dir = -int(away)
		timer = 1.25
		flash = 0.12

	func _fall(delta: float) -> void:
		if position.y < floor_y or vel.y < 0.0:
			vel.y += GRAV * delta
			position += vel * delta
			position.x = clampf(position.x, left_x, right_x)
			if position.y >= floor_y:
				position.y = floor_y
				vel = Vector2.ZERO

	## ------------------------------------------------------------- drawing
	## Designed facing right at 1/0.8 size; flipped and scaled in one transform.
	const FUR := preload("res://common/art/fur_grey.png")
	const FUR_TINT := Color(1.0, 0.97, 1.02)

	func _paint() -> void:
		var f := float(dir)
		_st(Vector2.ZERO, 0.0, Vector2(SIZE * f, SIZE))
		var low := 0.25
		var stretch := 0.0
		var tuck := 0.0
		match state:
			"crouch", "feint":
				low = 1.0
			"howl":
				low = 0.0
				# the howl rolling out from its raised muzzle, ring after ring
				for k in 3:
					var q := fmod((1.0 - timer) * 1.6 + k * 0.33, 1.0)
					_ac(Vector2(40, -58), 12.0 + q * 60.0, -1.3, 0.5, 10, Color(0.8, 0.9, 1.0, 0.7 * (1.0 - q)), 3.0)
				low = 0.0
				stretch = 1.0
			"cower", "recoil":
				low = 0.8
				tuck = 1.0
			"bolt":
				low = 0.35
				tuck = 1.0
			"ko", "tumble":
				low = 0.0
			"patrol":
				low = 0.7 if pause > 0.0 else 0.1
			"hunt":
				low = 0.5
		var ph := _stride / 22.0
		var gait := clampf(_moving / 160.0, 0.0, 1.0)
		if state == "ko":
			ph = death_t * 30.0
			gait = 0.5
		var sink := low * 8.0 + absf(sin(_stride / STEP * TAU)) * 2.0 * clampf(_moving / 120.0, 0.0, 1.0)
		var shiver := sin(t * 60.0) * 1.2 if state == "cower" else 0.0

		# far legs, in the body's shadow
		_legs(-1.0, ph + PI, gait, sink, stretch, Pal.WOLF_DARK)
		# tail: out straight when it leaps, tucked when it is afraid
		var tail := PackedVector2Array()
		if tuck > 0.0:
			tail = PackedVector2Array([Vector2(-26, -30 + sink), Vector2(-34, -24 + sink), Vector2(-30, -10), Vector2(-24, -8), Vector2(-26, -20 + sink)])
		elif stretch > 0.0:
			tail = PackedVector2Array([Vector2(-26, -34), Vector2(-48, -38), Vector2(-66, -36), Vector2(-50, -30), Vector2(-26, -28)])
		else:
			var wag := sin(t * 3.0 + slot) * 3.0
			tail = PackedVector2Array([Vector2(-26, -32 + sink), Vector2(-42, -30 + sink), Vector2(-52, -20 + wag), Vector2(-50, -10 + wag),
				Vector2(-44, -14 + wag), Vector2(-34, -22 + sink)])
		_fur_shape(tail, FUR, FUR_TINT.darkened(0.25), 1.4)
		# body: deep chest, tucked belly, a ruff at the shoulders
		var body := PackedVector2Array([
			Vector2(-30, -30 + sink), Vector2(-18, -39 + sink), Vector2(0, -41 + sink * 1.2), Vector2(16, -42 + sink * 1.4),
			Vector2(26, -36 + sink * 1.4), Vector2(29, -24 + sink), Vector2(18, -16 + sink * 0.6), Vector2(0, -19 + sink * 0.6),
			Vector2(-18, -17 + sink * 0.6), Vector2(-29, -21 + sink)])
		for i in body.size():
			body[i] = body[i] + Vector2(stretch * (body[i].x * 0.18), shiver)
		_fur_shape(body, FUR, FUR_TINT)
		# hackles: a bristling ridge along the neck and back, raised high when it attacks
		var bristle := 1.6 if state in ["crouch", "lunge", "hunt"] else 1.0
		for i in 9:
			var rx := -14.0 + i * 5.0
			var hgt := (7.0 + sin(i * 1.7) * 2.0) * bristle
			_fill(PackedVector2Array([Vector2(rx - 3, -38 + sink * 1.3), Vector2(rx + 1, -38 - hgt + sink * 1.3), Vector2(rx + 3, -38 + sink * 1.3)]), Pal.WOLF_DARK)
		# near legs
		_legs(1.0, ph, gait, sink, stretch, Pal.WOLF)
		# head: low and level when it stalks, thrown forward when it leaps
		var hy := -40.0 + low * 14.0 - stretch * 4.0
		var hx := 30.0 + stretch * 8.0
		var ears := -9.0 if tuck > 0.0 else 0.0
		_shape(PackedVector2Array([Vector2(hx + 2, hy - 8 + ears * 0.2), Vector2(hx + 3, hy - 20 - ears), Vector2(hx + 8, hy - 9)]), Pal.WOLF_DARK, 2.0)
		_shape(PackedVector2Array([Vector2(hx + 7, hy - 9), Vector2(hx + 10, hy - 20 - ears), Vector2(hx + 13, hy - 8)]), Pal.WOLF, 2.0)
		# it always shows its teeth now; wider when it attacks
		var snarl := 3.0 if state == "crouch" or state == "lunge" or state == "hunt" else 1.5
		var head := PackedVector2Array([
			Vector2(hx - 6, hy - 2), Vector2(hx + 4, hy - 10), Vector2(hx + 14, hy - 8), Vector2(hx + 26, hy - 3),
			Vector2(hx + 29, hy + 1), Vector2(hx + 26, hy + 4 + snarl), Vector2(hx + 12, hy + 7 + snarl), Vector2(hx - 2, hy + 8)])
		_fur_shape(head, FUR, FUR_TINT.lightened(0.08))
		_cc(Vector2(hx + 28, hy), 2.4, Pal.OUTLINE)
		# an old scar across its muzzle
		_ln(Vector2(hx + 12, hy - 7), Vector2(hx + 22, hy + 1), Pal.WOLF_BELLY.lightened(0.2), 1.6, true)
		if snarl > 0.0:
			_ln(Vector2(hx + 14, hy + 3), Vector2(hx + 26, hy + 2), Pal.MAW, 2.0, true)
			# long fangs, top and bottom
			_fill(PackedVector2Array([Vector2(hx + 23, hy + 1), Vector2(hx + 25.5, hy + 1), Vector2(hx + 24.5, hy + 8)]), Pal.TOOTH)
			_fill(PackedVector2Array([Vector2(hx + 17, hy + 6 + snarl), Vector2(hx + 19, hy + 6 + snarl), Vector2(hx + 18, hy + 1 + snarl)]), Pal.TOOTH)
			for k in 3:
				var tx := hx + 16.0 + k * 3.5
				_fill(PackedVector2Array([Vector2(tx, hy + 2), Vector2(tx + 1.2, hy + 5), Vector2(tx + 2.4, hy + 2)]), Pal.TOOTH)
		if state in ["ko", "tumble"]:
			# X for eyes, and the tongue lolling out
			_ln(Vector2(hx + 7, hy - 6), Vector2(hx + 13, hy), Pal.OUTLINE, 2.0, true)
			_ln(Vector2(hx + 13, hy - 6), Vector2(hx + 7, hy), Pal.OUTLINE, 2.0, true)
			_fill(PackedVector2Array([Vector2(hx + 20, hy + 4), Vector2(hx + 26, hy + 5), Vector2(hx + 27, hy + 16), Vector2(hx + 22, hy + 17)]), Color("d96b7a"))
		else:
			_cc(Vector2(hx + 10, hy - 3), 2.2, Pal.OUTLINE)
		_st(Vector2.ZERO, 0.0, Vector2.ONE)

	## A real trot: diagonal pairs move together (near fore with far hind),
	## and every paw PLANTS — it stays put on the ground while the body travels
	## over it, then lifts and swings forward. The step is driven by distance
	## covered, so at any speed the paws never skate.
	const STEP := 52.0              ## body travel per full step
	const STANCE := 0.6             ## share of the step a paw is on the ground

	func _legs(side: float, _ph: float, gait: float, sink: float, stretch: float, col: Color) -> void:
		var s := side * 3.0
		var reach := STEP * STANCE      # how far a planted paw travels back
		for fore in [true, false]:
			var is_fore: bool = fore
			var hip := Vector2(18.0 + s if is_fore else -20.0 + s, -26.0 + sink)
			# diagonal pairs: near fore + far hind, near hind + far fore
			var off := 0.0 if (is_fore == (side > 0.0)) else 0.5
			var u := fmod(_stride / STEP + off + 10.0, 1.0)
			var paw := Vector2(hip.x, 0.0)
			if gait > 0.05:
				if u < STANCE:
					paw.x = hip.x + reach * 0.5 - (u / STANCE) * reach
				else:
					var k := (u - STANCE) / (1.0 - STANCE)
					paw.x = hip.x - reach * 0.5 + k * reach
					paw.y = -sin(k * PI) * 9.0
				paw = Vector2(hip.x, 0.0).lerp(paw, clampf(gait * 1.6, 0.0, 1.0))
			if stretch > 0.0:
				paw = hip + (Vector2(24, 14) if is_fore else Vector2(-26, 12))
			var knee := hip.lerp(paw, 0.5) + Vector2(-4.0 if is_fore else 5.0, 0)
			_limb(hip, knee, 6.0, col)
			_limb(knee, paw, 5.0, col)
			_fill(_pts_oval(paw + Vector2(2, -1), 4.5, 2.5), col.darkened(0.2))

	## The eyes shine through the dark — a pair, as if the head were turned
	## a little toward him. They flare in the crouch that comes before a leap.
	func draw_glow(g) -> void:   # g: the glow layer's Batch
		if dying > 0.0:
			return
		var f := float(dir)
		var low := 1.0 if state == "crouch" else (0.8 if state == "cower" or state == "recoil" else 0.25)
		var e := global_position + Vector2(f * 40.0 * SIZE, (-43.0 + low * 14.0) * SIZE)
		var flare := 1.0 if state == "crouch" else 0.0
		var dim := 0.45 if state == "cower" or state == "recoil" else 1.0
		g.draw_circle(e, 4.0 + flare * 3.0, Color(Color("ff4a36"), (0.10 + flare * 0.16) * dim))
		g.draw_circle(e, 2.4 + flare * 0.8, Color(Color("ff4a36"), 0.95 * dim))
		g.draw_circle(e + Vector2(-f * 6.0, 1.0), 2.0 + flare * 0.6, Color(Color("ff4a36"), 0.7 * dim))


class Bat extends Bestiary.Insect:
	## The insect's hunt — hover, wind up, dash straight across him — in a
	## bat's body. Bats come to the torch, so they are the danger that finds
	## him INSIDE the light, where the wolves will not go.
	func _setup() -> void:
		super._setup()
		hp = 3
		dash_speed = 560.0
		add_to_group("glow")

	## Its second attack, the SCREECH: it hangs, mouth wide, and lets go a ring
	## of sound that flies at him. Jump it — or swing and POP it.
	var _screech_cd := 3.0

	func _tick(delta: float) -> void:
		_screech_cd -= delta
		if state == "screech":
			t += delta
			timer = maxf(timer - delta, 0.0)
			vel = vel.move_toward(Vector2.ZERO, 900.0 * delta)
			global_position += vel * delta
			if timer <= 0.0:
				if player != null and is_inside_tree():
					var wave := SonicWave.new()
					wave.position = global_position + Vector2(_facing() * 12.0, -6.0)
					wave.vel = (player.global_position + Vector2(0, -34) - wave.position).normalized() * 380.0
					get_parent().add_child(wave)
				Critter.attack_done(self)
				state = "rest"
				timer = 1.2
			return
		if state == "hover" and _screech_cd <= 0.0 and player != null and not player.dead:
			var dx := absf(player.global_position.x - global_position.x)
			var dy := absf(player.global_position.y - 30.0 - global_position.y)
			if dx > 120.0 and dx < 380.0 and dy < 160.0 and Critter.may_attack(self, 1500):
				_screech_cd = randf_range(4.0, 7.0)
				state = "screech"
				timer = 0.55
				tell("!")
				return
		super._tick(delta)

	func _facing() -> float:
		if absf(vel.x) > 30.0:
			return signf(vel.x)
		if player != null:
			return 1.0 if player.global_position.x > global_position.x else -1.0
		return 1.0

	func _paint() -> void:
		var rate := 34.0 if state == "wind" else 15.0
		var flap := sin(t * rate)
		if state == "wind":
			flap = -0.8 + sin(t * rate) * 0.25     # wings held high, trembling
		_st(Vector2.ZERO, 0.0, Vector2(_facing(), 1.0))
		for side in [-1.0, 1.0]:
			var s: float = side
			var wing := PackedVector2Array([
				Vector2(s * 4, -4), Vector2(s * 16, -12 + flap * 9.0), Vector2(s * 31, -8 + flap * 15.0),
				Vector2(s * 25, 2 + flap * 7.0), Vector2(s * 18, -1 + flap * 5.0), Vector2(s * 12, 5 + flap * 2.0),
				Vector2(s * 3, 5)])
			_shape(wing, Pal.BAT_WING if s > 0.0 else Pal.BAT_WING.darkened(0.15), 1.6)
			_ln(Vector2(s * 4, -4), Vector2(s * 16, -12 + flap * 9.0), Pal.BAT.darkened(0.3), 1.6, true)
			_ln(Vector2(s * 16, -12 + flap * 9.0), Vector2(s * 25, 2 + flap * 7.0), Pal.BAT.darkened(0.3), 1.2, true)
		_oval(Vector2(0, 1), 7.0, 9.0, Pal.BAT, 1.8)
		_dot(Vector2(1, -9), 5.5, Pal.BAT, 1.6)
		for s2 in [-1.0, 1.0]:
			var e: float = s2
			_fill(PackedVector2Array([Vector2(1 + e * 2, -12), Vector2(1 + e * 5, -20), Vector2(1 + e * 5.5, -11)]), Pal.BAT.darkened(0.2))
		# two long fangs
		_fill(PackedVector2Array([Vector2(2, -7), Vector2(3.4, -1), Vector2(4.2, -7)]), Pal.TOOTH)
		_fill(PackedVector2Array([Vector2(5.2, -7), Vector2(6.4, -1), Vector2(7.2, -7)]), Pal.TOOTH)
		if state == "screech":
			# mouth wide, the shriek building in rings
			_oval(Vector2(5, -5), 3.5, 4.5, Color("2a0a0a"), 0.0)
			for k in 3:
				var q := fmod(t * 3.0 + k * 0.33, 1.0)
				_ac(Vector2(6, -6), 6.0 + q * 22.0, -0.9, 0.9, 8, Color(1.0, 0.85, 0.95, 0.75 * (1.0 - q)), 2.0, true)
		_st(Vector2.ZERO, 0.0, Vector2.ONE)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		if dying > 0.0:
			return
		var f := _facing()
		var a := 1.0 if state == "wind" else 0.7
		for s in [-1.0, 1.0]:
			var e := global_position + Vector2(1.0 * f + float(s) * 2.4, -10.0)
			g.draw_circle(e, 3.5, Color(Color("ff3a2a"), 0.2 * a))
			g.draw_circle(e, 1.3, Color(Color("ff3a2a"), a))


## A bat's screech: a ring of sound flying straight at him. It stings if it
## reaches him (jump it); a swing POPS it.
class SonicWave extends Area2D:
	var vel := Vector2.ZERO
	var t := 0.0

	func _ready() -> void:
		z_index = 4
		collision_layer = 4               # his swing can pop it
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 18.0
		cs.shape = c
		add_child(cs)
		add_to_group("glow")

	func take_hit(_dmg: int, _from_dir: int) -> void:
		var w := Treasure.FloatText.new()
		w.text = "POP!"
		w.position = global_position + Vector2(-16, -24)
		get_parent().add_child(w)
		queue_free()

	func _physics_process(delta: float) -> void:
		t += delta
		position += vel * delta
		if t > 1.6:
			queue_free()
			return
		var p := get_tree().get_first_node_in_group("player") as CaveMan
		if p != null and not p.dead and p.global_position.distance_to(global_position + Vector2(0, 34)) < 32.0:
			p.hurt(1, global_position.x)
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var r := 12.0 + sin(t * 30.0) * 2.0
		var a := vel.angle()
		for k in 3:
			var rr := r + k * 6.0
			draw_arc(Vector2.ZERO, rr, a - 1.0, a + 1.0, 12, Color(1.0, 0.8, 0.95, 0.85 - k * 0.25), 3.0)

	func draw_glow(g) -> void:
		g.draw_circle(global_position, 22.0, Color(1.0, 0.7, 0.9, 0.25))


## ================================================================ MONKEYS
class Monkey extends Area2D:
	var _pen: Batch             ## its picture, collected into one draw call
	## Lives in the great tree and minds its own business: eats bananas,
	## scratches, stares at his torch like it has never seen fire (it has not),
	## and copies him — he jumps, it hops; he swings, it swings.
	## Walk past and it gives you a look. Crowd it, bump it, hit it, or light
	## a fire near it and it shrieks, the troop shrieks with it, and they pelt
	## him with bananas. A banana that hits hurts; one that misses is food.
	## Three hits kill one (a fire burst, all at once); it drops its banana.
	signal shrieked
	signal died
	const ANNOY_AT := 1.2
	const THROWS := 2          ## per outburst; it keeps having outbursts while he stays close
	var perch_y := 0.0
	var hanging := false       ## hangs by its tail under the branch instead of sitting on it
	var habit := 0             ## 0 eats; 1 scratches between bites
	var state := "calm"        ## calm shriek throw sulk dead
	var hits := 3
	var t := 0.0
	var timer := 0.0
	var annoy := 0.0
	var bananas := 3
	var throws := 0
	var dir := 1
	var vy := 0.0
	var vx := 0.0
	var hop_at := -1.0
	var eat := 0.0             ## 0..1 through a banana
	var stare := 0.0
	var wave := 0.0
	var flash := 0.0
	var dying := 0.0
	var player: CaveMan
	var _touching := false
	var _p_floor := true
	var _p_attack := 0.0

	func _ready() -> void:
		collision_layer = 4    # his swing and his rocks find it
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 17.0
		cs.shape = c
		cs.position = Vector2(0, 20 if hanging else -18)
		add_child(cs)
		body_entered.connect(_on_enter)
		body_exited.connect(_on_leave)
		perch_y = position.y
		t = randf() * 10.0
		eat = randf()
		add_to_group("monkeys")

	func _on_enter(b: Node) -> void:
		if b is CaveMan:
			_touching = true

	func _on_leave(b: Node) -> void:
		if b is CaveMan:
			_touching = false

	func take_hit(_dmg: int, from_dir: int) -> void:
		if dying > 0.0:
			return
		hits -= 1
		flash = 0.12
		if hits <= 0:
			_die(from_dir)
			return
		if not hanging and vy == 0.0:
			vy = -260.0
		bother()

	## Caught inside a fire burst.
	func burn() -> void:
		if dying > 0.0:
			return
		hits = 0
		_die(1 if player == null or player.global_position.x < global_position.x else -1)

	func scare(_from: Vector2) -> void:
		bother()

	func bother() -> void:
		if state != "calm":
			return
		state = "shriek"
		timer = 0.6
		throws = 0
		annoy = 0.0
		shrieked.emit()
		# it sets off the rest of the troop nearby, one after another
		for m in get_tree().get_nodes_in_group("monkeys"):
			if m != self and m.state == "calm" and (m as Node2D).global_position.distance_to(global_position) < 280.0:
				get_tree().create_timer(randf_range(0.15, 0.4)).timeout.connect(m.bother)

	func _die(from_dir: int) -> void:
		state = "dead"
		dying = 1.3
		vy = -380.0
		vx = from_dir * 160.0
		Critter.slow_time(get_tree(), 0.07, 0.08)
		var pop := Critter.DeathPop.new()
		pop.position = global_position + Vector2(0, -20)
		get_parent().call_deferred("add_child", pop)
		hanging = false
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		remove_from_group("monkeys")
		# its banana stays on the branch
		if bananas > 0:
			var b := BananaPickup.new()
			b.position = Vector2(position.x, perch_y)
			get_parent().call_deferred("add_child", b)
		died.emit()

	func _physics_process(delta: float) -> void:
		t += delta
		timer = maxf(timer - delta, 0.0)
		flash = maxf(flash - delta, 0.0)
		wave = maxf(wave - delta, 0.0)
		if dying > 0.0:
			# off the branch, tumbling
			dying -= delta
			vy += 1500.0 * delta
			position += Vector2(vx, vy) * delta
			rotation += 12.0 * delta * signf(vx if vx != 0.0 else 1.0)
			modulate.a = clampf(dying / 0.6, 0.0, 1.0)
			queue_redraw()
			if dying <= 0.0:
				queue_free()
			return
		if not hanging and (vy != 0.0 or position.y < perch_y):
			vy += 1500.0 * delta
			position.y += vy * delta
			if position.y >= perch_y:
				position.y = perch_y
				vy = 0.0
		if player == null or player.dead:
			queue_redraw()
			return
		var to_p := player.global_position - global_position
		var dist := to_p.length()
		if dist < 420.0:
			dir = 1 if to_p.x > 0.0 else -1
		if _touching:
			annoy += 1.8 * delta
		elif dist < 64.0:
			annoy += 0.9 * delta
		else:
			annoy = maxf(annoy - 0.5 * delta, 0.0)
		match state:
			"calm":
				_calm(delta, dist)
				if annoy >= ANNOY_AT:
					bother()
			"shriek":
				if timer <= 0.0:
					state = "throw"
					timer = 0.1
			"throw":
				if timer <= 0.0:
					if throws < THROWS and bananas > 0 and dist < 700.0:
						_throw()
						throws += 1
						timer = 0.9
					else:
						state = "sulk"
						timer = 3.0
			"sulk":
				if timer <= 0.0:
					if dist > 170.0:
						state = "calm"
						annoy = 0.0
						bananas = 3
					elif annoy >= ANNOY_AT:
						state = "shriek"
						timer = 0.5
						throws = 0
						annoy = 0.0
		_p_floor = player.is_on_floor()
		_p_attack = player.attacking
		if dist < 900.0:
			queue_redraw()

	func _calm(delta: float, dist: float) -> void:
		# his torch is the most interesting thing that has ever been in this tree
		var near_torch := player.has_torch and player.torch_fuel > 0.0 and dist < 170.0
		stare = move_toward(stare, 1.0 if near_torch else 0.0, delta * 3.0)
		if stare < 0.5:
			eat = fmod(eat + delta / (6.0 if habit == 0 else 9.0), 1.0)
		if dist < 420.0:
			if _p_floor and not player.is_on_floor() and player.velocity.y < -300.0:
				hop_at = t + 0.28
			if player.attacking > 0.0 and _p_attack <= 0.0:
				wave = 0.4
		if hop_at > 0.0 and t >= hop_at:
			hop_at = -1.0
			if not hanging and vy == 0.0:
				vy = -280.0

	func _throw() -> void:
		var from := global_position + Vector2(dir * 8.0, 12.0 if hanging else -30.0)
		wave = 0.3
		bananas -= 1
		var b := BananaThrow.new()
		b.setup(from, player.global_position)
		get_parent().add_child(b)

	## ------------------------------------------------------------ drawing
	## Designed sitting, facing right, origin where it sits on the branch.
	## Hanging is the same monkey turned upside down under the branch.
	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		MonkeyArt.draw_monkey(_pen, {
			"dir": dir, "t": t, "state": state, "hanging": hanging, "habit": habit,
			"eat": eat, "stare": stare, "wave": wave, "flash": flash,
			"fur": Pal.MONKEY, "dark": Pal.MONKEY_DARK, "face": Pal.MONKEY_FACE})


class MonkeyArt extends RefCounted:
	## The monkey drawing, shared by the troop and by Old Bongo (who adds a
	## beard, a crown and a gem to it). Draws into `c` in the monkey's own space.
	static func draw_monkey(c, o: Dictionary) -> void:
		var f := float(o["dir"])
		var t: float = o["t"]
		var state: String = o["state"]
		var hanging: bool = o["hanging"]
		var eat: float = o["eat"]
		var stare: float = o["stare"]
		var wave: float = o["wave"]
		var fur: Color = o["fur"]
		var dark: Color = o["dark"]
		var face: Color = o["face"]
		var sc: float = o.get("scale", 1.0)
		var holding: String = o.get("holding", "banana")    # banana, gem, none
		var talking: bool = o.get("talking", false)
		var shake := Vector2(sin(t * 55.0) * 1.5, 0) if state == "shriek" else Vector2.ZERO
		if hanging:
			c.draw_set_transform(shake + Vector2(sin(t * 1.3) * 3.0, 0), PI + sin(t * 1.3) * 0.08, Vector2(-f, 1) * sc)
		else:
			c.draw_set_transform(shake, 0.0, Vector2(f, 1) * sc)
		# tail: hangs below the branch and curls
		var sw := sin(t * 1.7) * 3.0
		c.draw_polyline(PackedVector2Array([Vector2(-7, -6), Vector2(-14, -1), Vector2(-17, 9 + sw), Vector2(-14, 20 + sw),
			Vector2(-8, 25 + sw), Vector2(-4, 21 + sw), Vector2(-7, 16 + sw)]), dark, 3.5, true)
		# legs folded, feet over the edge
		c.draw_circle(Vector2(-4, -4), 6.5, dark)
		c.draw_circle(Vector2(7, -4), 6.0, dark)
		c.draw_circle(Vector2(10, 0), 3.0, face)
		# body
		var bob := sin(t * 2.0) * 0.8
		_oval(c, Vector2(0, -15 + bob), 10.0, 13.0, fur)
		_oval(c, Vector2(2.5, -13 + bob), 5.5, 8.0, face.darkened(0.15))
		# head
		var head := Vector2(3, -32 + bob)
		if stare > 0.0:
			head += Vector2(2, -1) * stare
		c.draw_circle(head + Vector2(-9, -1), 4.0, dark)
		c.draw_circle(head + Vector2(10, -2), 4.0, dark)
		c.draw_circle(head + Vector2(-9, -1), 2.0, face)
		c.draw_circle(head, 9.5, fur)
		_oval(c, head + Vector2(1.5, 2), 6.5, 6.0, face)
		var er := 1.6 + stare * 0.8
		c.draw_circle(head + Vector2(-1, -0.5), er, Pal.OUTLINE)
		c.draw_circle(head + Vector2(4, -0.5), er, Pal.OUTLINE)
		# mouth: shrieking, talking, chewing, or shut
		var chewing := state == "calm" and holding == "banana" and eat > 0.35 and eat < 0.95 and stare < 0.5
		if state == "shriek" or state == "throw":
			_oval(c, head + Vector2(2, 5.5), 3.8, 3.5, Pal.MAW)
			c.draw_line(head + Vector2(-0.5, 3), head + Vector2(4.5, 3), Pal.TOOTH, 1.5)
		elif talking:
			_oval(c, head + Vector2(2, 5.5), 2.8, 1.0 + absf(sin(t * 16.0)) * 2.2, Pal.MAW)
		elif chewing:
			c.draw_line(head + Vector2(0, 5 + sin(t * 14.0)), head + Vector2(4, 5), Pal.OUTLINE, 1.5, true)
		else:
			c.draw_line(head + Vector2(0, 5), head + Vector2(4, 5), Pal.OUTLINE, 1.2, true)
		# arms, by what it is doing
		var sh_b := Vector2(-5, -22 + bob)
		var sh_f := Vector2(7, -22 + bob)
		var hb := Vector2(-2, -10)
		var hf := Vector2(12, -18)
		var banana_at := Vector2.INF
		match state:
			"shriek":
				hb = Vector2(-10, -46 + sin(t * 30.0) * 3.0)
				hf = Vector2(16, -46 - sin(t * 30.0) * 3.0)
			"throw":
				hb = Vector2(-4, -14)
				hf = Vector2(10, -46) if wave > 0.15 else Vector2(18, -30)
			"sulk":
				hb = Vector2(4, -17)
				hf = Vector2(0, -16)
			_:
				if holding == "gem":
					var turn := sin(t * 1.2) * 3.0
					hf = Vector2(14 + turn, -40)
				elif wave > 0.0:
					hf = Vector2(12, -46)
				elif stare > 0.3:
					hf = Vector2(12, -22).lerp(Vector2(20, -28), stare)
				elif int(o["habit"]) == 1 and fmod(t, 7.0) < 1.6:
					hb = Vector2(-7, -42 + sin(t * 16.0) * 2.0)
				if holding == "banana" and eat < 0.95 and stare < 0.3:
					if eat > 0.3:
						hf = head + Vector2(6, 6)
					banana_at = hf
		for a in [[sh_b, hb], [sh_f, hf]]:
			var s0: Vector2 = a[0]
			var s1: Vector2 = a[1]
			c.draw_line(s0, s1, dark, 3.5, true)
			c.draw_circle(s1, 2.6, face)
		if banana_at != Vector2.INF:
			var left := 1.0 if eat < 0.3 else clampf(1.0 - (eat - 0.3) / 0.65, 0.15, 1.0)
			banana(c, banana_at + Vector2(1, -4), left, eat > 0.15)
		if holding == "gem" and state == "calm":
			var g := hf + Vector2(1, -6)
			c.draw_colored_polygon(PackedVector2Array([g + Vector2(-5, 0), g + Vector2(0, -6), g + Vector2(5, 0), g + Vector2(0, 7)]), Pal.GEM)
			c.draw_colored_polygon(PackedVector2Array([g + Vector2(-5, 0), g + Vector2(0, -6), g + Vector2(0, 0)]), Pal.GEM_LIGHT)
		if o.get("elder", false):
			# white beard and brows, and a crown of leaves
			c.draw_colored_polygon(PackedVector2Array([head + Vector2(-5, 5), head + Vector2(8, 5), head + Vector2(5, 17),
				head + Vector2(1.5, 20), head + Vector2(-2, 16)]), Pal.BONE)
			c.draw_line(head + Vector2(-4, -4), head + Vector2(1, -3), Pal.BONE, 2.2, true)
			c.draw_line(head + Vector2(3, -3), head + Vector2(7, -4), Pal.BONE, 2.2, true)
			for k in 5:
				var a := -2.6 + k * 0.42
				var lp := head + Vector2.from_angle(a) * 9.5
				c.draw_colored_polygon(PackedVector2Array([lp + Vector2.from_angle(a + 1.2) * 2.5, lp + Vector2.from_angle(a) * 7.0,
					lp - Vector2.from_angle(a + 1.2) * 2.5]), Pal.CANOPY.lightened(0.25) if k % 2 == 0 else Pal.FROND_LIGHT)
		if float(o["flash"]) > 0.0:
			c.draw_circle(Vector2(0, -20), 20.0, Color(1, 1, 1, 0.5))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# what it screams, the right way round whatever way it faces
		if state == "shriek" or (state == "throw" and wave > 0.0):
			var font := ThemeDB.fallback_font
			var word := "EEK! EEK!" if state == "shriek" else "OOK!"
			var at := Vector2(-26, 58 if hanging else -58) + Vector2(0, sin(t * 20.0) * 2.0)
			c.draw_string(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.BONE)

	static func _oval(c, at: Vector2, rx: float, ry: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 14:
			var a := TAU * i / 14.0
			pts.append(at + Vector2(cos(a) * rx, sin(a) * ry))
		c.draw_colored_polygon(pts, col)

	## A banana in the hand: `left` is how much is still uneaten.
	static func banana(c, at: Vector2, left: float, peeled: bool) -> void:
		var pts := PackedVector2Array()
		var span := 1.1 * left
		for i in 7:
			var a := -PI * 0.5 - span * 0.5 + span * i / 6.0
			pts.append(at + Vector2(10, 12) + Vector2.from_angle(a) * 15.0)
		for i in 7:
			var a := -PI * 0.5 + span * 0.5 - span * i / 6.0
			pts.append(at + Vector2(10, 12) + Vector2.from_angle(a) * 10.0)
		c.draw_colored_polygon(pts, Pal.BANANA_DARK if peeled else Pal.BANANA)
		if peeled:
			c.draw_circle(pts[6], 3.0, Pal.BONE)
			for k in 3:
				c.draw_line(pts[0] + Vector2(0, 2), pts[0] + Vector2(-4 + k * 4, 9), Pal.BANANA, 2.0, true)


class Elder extends Area2D:
	var _pen: Batch             ## its picture, collected into one draw call
	## Old Bongo, king of the great tree. Bigger, greyer, bearded, crowned with
	## leaves — and the only animal in the woods that talks. He sits by his
	## locked banana box turning the shiny stone over in his fingers.
	## He cannot be hurt. Only offended.
	signal poked
	const SIZE := 1.6
	var t := 0.0
	var dir := -1
	var has_gem := true
	var box_open := false
	var show_box := true
	var speaking := false
	var flash := 0.0
	var player: CaveMan

	func _ready() -> void:
		collision_layer = 4    # so a club or a rock finds him (and he can complain)
		collision_mask = 0
		monitoring = false
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 30.0
		cs.shape = c
		cs.position = Vector2(0, -34)
		add_child(cs)
		add_to_group("glow")

	func take_hit(_dmg: int, _from_dir: int) -> void:
		flash = 0.12
		poked.emit()

	func open_box() -> void:
		box_open = true

	func _process(delta: float) -> void:
		t += delta
		flash = maxf(flash - delta, 0.0)
		if player != null and absf(player.global_position.x - global_position.x) < 500.0:
			dir = 1 if player.global_position.x > global_position.x else -1
		if NightWoods.near_view(self):
			queue_redraw()

	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		if not show_box:
			_draw_self()
			return
		# the banana box beside him: a crate bound with vine, a stone lock
		var bx := Vector2(-58, 0)
		var lid := 0.0 if not box_open else -0.9
		_pen.draw_rect(Rect2(bx + Vector2(-26, -34), Vector2(52, 34)), Pal.BARK_DARK)
		_pen.draw_rect(Rect2(bx + Vector2(-23, -31), Vector2(46, 28)), Pal.BARK)
		for k in 3:
			_pen.draw_line(bx + Vector2(-23 + k * 23, -31), bx + Vector2(-23 + k * 23, -3), Pal.BARK_DARK, 2.0)
		if box_open:
			for k in 4:
				MonkeyArt.banana(_pen, bx + Vector2(-20 + k * 9, -44 + (k % 2) * 3), 1.0, false)
		_pen.draw_set_transform(bx + Vector2(-26, -34), lid, Vector2.ONE)
		_pen.draw_rect(Rect2(Vector2(0, -7), Vector2(54, 8)), Pal.BARK_DARK)
		_pen.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if not box_open:
			_pen.draw_line(bx + Vector2(-26, -20), bx + Vector2(26, -20), Pal.VINE, 3.0)
			_pen.draw_circle(bx + Vector2(0, -20), 7.0, Pal.CRAG_DARK)
			_pen.draw_circle(bx + Vector2(0, -20), 5.0, Pal.CRAG)
			_pen.draw_rect(Rect2(bx + Vector2(-1, -22), Vector2(2, 5)), Pal.CHARCOAL)
		_draw_self()

	func _draw_self() -> void:
		MonkeyArt.draw_monkey(_pen, {
			"dir": dir, "t": t, "state": "calm", "hanging": false, "habit": 0,
			"eat": 1.0, "stare": 0.0, "wave": 0.0, "flash": flash, "scale": SIZE, "elder": true,
			"holding": "gem" if has_gem else "none", "talking": speaking,
			"fur": Pal.ELDER, "dark": Pal.ELDER_DARK, "face": Pal.ELDER_FACE})

	## The gem shows through the dark, so it can be spotted from below.
	func draw_glow(g) -> void:   # g: the glow layer's Batch
		if not has_gem:
			return
		var c := global_position + Vector2(dir * 24.0, -76.0)
		var s := absf(sin(t * 1.3))
		g.draw_circle(c, 10.0 + s * 6.0, Color(Pal.GEM_LIGHT, 0.12 + 0.12 * s))
		if s > 0.7:
			var k := (s - 0.7) / 0.3
			for a in [0.0, PI * 0.5, PI, PI * 1.5]:
				g.draw_line(c + Vector2.from_angle(a) * 4.0, c + Vector2.from_angle(a) * (8.0 + k * 12.0), Color(1, 1, 1, k), 2.0, true)


class Thrown extends Area2D:
	## Something a monkey throws: an arc from its hand to where he was standing.
	const G := 1400.0
	var p0 := Vector2.ZERO
	var p1 := Vector2.ZERO
	var dur := 0.8
	var v0 := Vector2.ZERO
	var t := 0.0
	var done := false

	func setup(from: Vector2, to: Vector2) -> void:
		p0 = from
		p1 = to + Vector2(0, -6)
		dur = clampf(from.distance_to(to) / 480.0, 0.5, 1.1)
		v0 = Vector2((p1.x - p0.x) / dur, (p1.y - p0.y) / dur - 0.5 * G * dur)
		position = from

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 11.0
		cs.shape = c
		add_child(cs)
		body_entered.connect(_on_body)

	func _on_body(b: Node) -> void:
		if not done and b is CaveMan:
			done = true
			_hit(b as CaveMan)

	func _physics_process(delta: float) -> void:
		if done:
			return
		t += delta
		if t >= dur:
			done = true
			position = p1
			_land()
			return
		position = p0 + v0 * t + Vector2(0, 0.5 * G * t * t)
		rotation += 11.0 * delta
		queue_redraw()

	func _hit(_man: CaveMan) -> void:
		call_deferred("queue_free")

	func _land() -> void:
		call_deferred("queue_free")


class GiftBanana extends Thrown:
	## Old Bongo's help in the fight: a banana lobbed to him that heals as he
	## catches it (or lands as food if he doesn't).
	func _hit(man: CaveMan) -> void:
		man.hp = mini(man.hp + 2, man.max_hp)
		man.hp_changed.emit(man.hp)
		call_deferred("queue_free")

	func _land() -> void:
		var b := BananaPickup.new()
		b.position = p1 + Vector2(0, 6)
		get_parent().call_deferred("add_child", b)
		call_deferred("queue_free")

	func _draw() -> void:
		var pts := PackedVector2Array()
		for i in 7:
			pts.append(Vector2.from_angle(-PI * 0.5 - 0.55 + 1.1 * i / 6.0) * 14.0 + Vector2(0, 10))
		for i in 7:
			pts.append(Vector2.from_angle(-PI * 0.5 + 0.55 - 1.1 * i / 6.0) * 9.0 + Vector2(0, 10))
		draw_colored_polygon(pts, Pal.BANANA)


class BananaThrow extends Thrown:
	func _hit(man: CaveMan) -> void:
		man.hurt(1, global_position.x)
		call_deferred("queue_free")

	func _land() -> void:
		var b := BananaPickup.new()
		b.position = p1 + Vector2(0, 6)
		get_parent().call_deferred("add_child", b)
		call_deferred("queue_free")

	func _draw() -> void:
		var pts := PackedVector2Array()
		for i in 7:
			pts.append(Vector2.from_angle(-PI * 0.5 - 0.55 + 1.1 * i / 6.0) * 14.0 + Vector2(0, 10))
		for i in 7:
			pts.append(Vector2.from_angle(-PI * 0.5 + 0.55 - 1.1 * i / 6.0) * 9.0 + Vector2(0, 10))
		draw_colored_polygon(pts, Pal.BANANA)


class BananaPickup extends Area2D:
	## A banana that missed him, or that a monkey dropped. Food: counts as a berry.
	var t := 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 20.0
		cs.shape = c
		cs.position = Vector2(0, -8)
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
		var pulse := 0.5 + 0.5 * sin(t * 2.4)
		draw_arc(Vector2(0, -8), 18.0 + pulse * 4.0, 0.0, TAU, 24, Color(Pal.BANANA, 0.15 + pulse * 0.25), 2.0)
		var pts := PackedVector2Array()
		for i in 7:
			pts.append(Vector2.from_angle(PI * 0.2 + 0.6 * PI * i / 6.0) * 14.0 + Vector2(0, -18))
		for i in 7:
			pts.append(Vector2.from_angle(PI * 0.8 - 0.6 * PI * i / 6.0) * 9.0 + Vector2(0, -18))
		draw_colored_polygon(pts, Pal.BANANA)


## ================================================================ PEOPLE
class Toolmaker extends Node2D:
	var _pen: Batch             ## its picture, collected into one draw call
	## The Toolmaker: an old hermit living at the edge of the Long Dark, by his
	## fire and his forge stone. Old Scar took his arm forty winters ago. He
	## knows the beast, trades in shells, and can forge a Firestone into a
	## club that burns.
	var t := 0.0
	var dir := -1
	var forging := 0.0           ## > 0 while hammering: sparks fly
	var speaking := false
	var player: CaveMan

	func _process(delta: float) -> void:
		t += delta
		forging = maxf(forging - delta, 0.0)
		if player != null and absf(player.global_position.x - global_position.x) < 500.0:
			dir = 1 if player.global_position.x > global_position.x else -1
		if NightWoods.near_view(self):
			queue_redraw()

	func _draw() -> void:
		_pen = Batch.new()
		_paint()
		_pen.draw(self)

	func _paint() -> void:
		# the forge stone beside him, a flat anvil rock
		var bt := Batch.new()
		var fx := float(dir) * 56.0
		bt.poly(PackedVector2Array([Vector2(fx - 26, 0), Vector2(fx - 22, -22), Vector2(fx + 24, -24), Vector2(fx + 28, 0)]), Pal.CRAG_DARK)
		bt.rect(Rect2(fx - 22, -26, 46, 5), Pal.CRAG_LIGHT)
		bt.draw(self)
		_pen.draw_set_transform(Vector2.ZERO, 0.0, Vector2(float(dir) * 0.38, 0.38))
		var skin := Color("b98a62")
		var hair := Color("c9c3b6")
		var bob := sin(t * 1.4) * 1.5
		# legs, bent with age
		for lx in [-12.0, 14.0]:
			_pen.draw_line(Vector2(lx, -70), Vector2(lx + 4, -34), skin.darkened(0.2), 14.0, true)
			_pen.draw_line(Vector2(lx + 4, -34), Vector2(lx, -2), skin.darkened(0.2), 12.0, true)
			_pen.draw_circle(Vector2(lx + 4, -2), 8.0, skin.darkened(0.3))
		# hunched body in an old hide
		var body := PackedVector2Array([Vector2(-26, -70), Vector2(-30, -120 + bob), Vector2(-10, -150 + bob), Vector2(24, -146 + bob),
			Vector2(34, -116 + bob), Vector2(28, -70)])
		_pen.draw_colored_polygon(body, skin)
		_pen.draw_colored_polygon(PackedVector2Array([Vector2(-28, -96), Vector2(30, -96), Vector2(32, -58), Vector2(-30, -58)]), Pal.HIDE_DARK)
		# the stump where his left arm was
		_pen.draw_circle(Vector2(-24, -128 + bob), 11.0, skin.darkened(0.1))
		_pen.draw_line(Vector2(-30, -128 + bob), Vector2(-20, -122 + bob), skin.darkened(0.35), 2.0, true)
		# his one arm, with a stone hammer — raised and falling while he forges
		var swing := sin(t * 14.0) if forging > 0.0 else 0.0
		var hand := Vector2(56, -112 - 40.0 * maxf(swing, 0.0) + bob)
		_pen.draw_line(Vector2(26, -136 + bob), Vector2(46, -110 + bob), skin, 13.0, true)
		_pen.draw_line(Vector2(46, -110 + bob), hand, skin, 12.0, true)
		_pen.draw_line(hand, hand + Vector2(10, -34), Pal.TRUNK_DARK, 6.0, true)
		_pen.draw_colored_polygon(PackedVector2Array([hand + Vector2(0, -34), hand + Vector2(26, -44), hand + Vector2(28, -30), hand + Vector2(4, -24)]), Pal.STONE)
		_pen.draw_circle(hand, 9.0, skin)
		# head: bald on top, a ring of grey, a long grey beard
		var head := Vector2(10, -168 + bob)
		_pen.draw_circle(head, 24.0, skin)
		_pen.draw_colored_polygon(PackedVector2Array([head + Vector2(-24, 0), head + Vector2(-20, -16), head + Vector2(-8, -8), head + Vector2(-16, 12)]), hair)
		_pen.draw_colored_polygon(PackedVector2Array([head + Vector2(-14, 8), head + Vector2(20, 8), head + Vector2(22, 40), head + Vector2(6, 58),
			head + Vector2(-8, 44)]), hair)
		_pen.draw_line(head + Vector2(-6, -8), head + Vector2(4, -6), hair, 4.0, true)
		_pen.draw_line(head + Vector2(10, -6), head + Vector2(20, -8), hair, 4.0, true)
		_pen.draw_circle(head + Vector2(0, -1), 2.6, Pal.OUTLINE)
		_pen.draw_circle(head + Vector2(15, -1), 2.6, Pal.OUTLINE)
		if speaking:
			_pen.draw_rect(Rect2(head + Vector2(2, 14 + absf(sin(t * 16.0)) * 2.0), Vector2(10, 3)), Pal.MAW)
		_pen.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if forging > 0.0:
			for i in 10:
				var q := fmod(t * 2.5 + i * 0.1, 1.0)
				var a := -PI * 0.5 + (i - 4.5) * 0.3
				var p := Vector2(fx, -26) + Vector2.from_angle(a) * q * 60.0 + Vector2(0, q * q * 30.0)
				_pen.draw_circle(p, 2.5 * (1.0 - q) + 0.5, Color(Pal.FLAME_CORE, 1.0 - q))
