## Level 2 critters: the things that live at the edge of the firelight.
## Kept in one file so the whole bestiary for the night is in view.
class_name NightBeasts
extends RefCounted


class Wolf extends Critter:
	## A pack hunter that obeys the light.
	##
	## It paces just outside whatever light surrounds him and never walks into
	## it. Every few seconds one wolf of the pack tests him: it crouches (eyes
	## flare — the tell), then leaps. What happens when it arrives depends on
	## how strong the light is around him at that moment:
	##   torch at half or more, or beside a bonfire -> it yelps and recoils,
	##       stunned for a beat: the moment to club it
	##   torch below half -> the leap lands and bites
	##   torch out and no fire near -> the pack stops testing and comes in
	## So the torch is a defence that decays, not a force field — and hitting
	## a wolf as it recoils is how the level teaches the sabre-tooth.

	## Only one wolf tests him at a time; shared across the whole pack.
	static var _last_lunge_ms := -100000

	const GRAV := 1720.0
	const WALK := 165.0
	const RETREAT := 340.0
	const HUNT := 250.0
	const PATROL := 72.0
	const NOTICE := 460.0     ## he is noticed inside this, if he is on roughly its level
	const FORGET := 820.0     ## and forgotten again past this
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
	var slot := 50.0         ## how far past the light's edge it waits; its own, so the pack spreads out
	var slot_t := 0.0
	var pause := 0.0         ## sniffing at the end of a patrol leg
	var resolved := false    ## has this leap already been judged against the light?
	var night: Night
	var _stride := 0.0       ## gait phase, driven by distance covered so paws do not slide
	var _moving := 0.0

	func _setup() -> void:
		# 6 health, like the lizard: two clubs or two rocks. The fire kills outright.
		hp = 6
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

	func _on_hit(from_dir: int) -> void:
		position.x = clampf(position.x + from_dir * 16.0, left_x, right_x)
		if hp > 0 and state != "recoil":
			state = "flee"
			timer = 0.9

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
		var dx := player.global_position.x - position.x
		match state:
			"patrol":
				_patrol(delta)
				if absf(dx) < NOTICE and absf(player.global_position.y - floor_y) < 160.0:
					state = "stalk"
					slot_t = 0.0
			"stalk":
				_stalk(dx, delta)
			"crouch":
				dir = 1 if dx > 0.0 else -1
				if timer <= 0.0:
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
		if absf(dx) > FORGET or absf(player.global_position.y - floor_y) > 260.0:
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
		var tx := _edge_target()
		if _lit_at(position.x):
			# caught in the light: get out of it, or cower if cornered
			var before := position.x
			_move_to(tx, RETREAT, delta, false)
			if absf(position.x - before) < 0.5:
				state = "cower"
			return
		# a dead band, so it holds its spot instead of twitching after every step he takes
		if absf(tx - position.x) > 18.0:
			_move_to(tx, WALK, delta, true)
		if _moving < 60.0:
			dir = 1 if dx > 0.0 else -1
		var px := player.global_position.x
		if lunge_cd <= 0.0 and _level() and absf(dx) < 560.0 and absf(position.x - tx) < 60.0 \
				and px > left_x - 40.0 and px < right_x + 40.0 \
				and Time.get_ticks_msec() - _last_lunge_ms > 1300 and player.invuln <= 0.0:
			_last_lunge_ms = Time.get_ticks_msec()
			state = "crouch"
			timer = 0.5

	## In the dark he is simply prey: close in, and leap from close range.
	## No turn-taking here — the pack comes in together.
	func _hunt(dx: float, delta: float) -> void:
		if _shelter() > 0.0 or not _level():
			state = "stalk"
			return
		dir = 1 if dx > 0.0 else -1
		if absf(dx) > 120.0:
			_move_to(player.global_position.x - signf(dx) * 100.0, HUNT, delta, false)
		if lunge_cd <= 0.0 and absf(dx) < 260.0 and player.invuln <= 0.0:
			state = "crouch"
			timer = 0.3

	func _leap(dx: float) -> void:
		var land := clampf(player.global_position.x, left_x, right_x)
		var d := clampf(land - position.x, -470.0, 470.0)
		if absf(d) < 30.0:
			d = 30.0 * signf(dx if dx != 0.0 else 1.0)
		vel = Vector2(d / 0.5, -430.0)
		state = "lunge"
		resolved = false
		lunge_cd = randf_range(1.0, 1.8) if _shelter() <= 0.0 else randf_range(2.6, 4.6)

	func _fly(delta: float) -> void:
		vel.y += GRAV * delta
		position += vel * delta
		if not resolved:
			var ddx := absf(player.global_position.x - position.x)
			var ddy := absf((player.global_position.y - 30.0) - (position.y - 18.0))
			if ddx < 58.0 and ddy < 70.0:
				resolved = true
				if _shelter() >= 0.5:
					_yelp()
					return
		if position.y >= floor_y and vel.y > 0.0:
			position.y = floor_y
			vel = Vector2.ZERO
			position.x = clampf(position.x, left_x, right_x)
			state = "stalk"

	## The leap broke on the light. It flinches back and stays stunned.
	func _yelp() -> void:
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
	func _draw() -> void:
		var f := float(dir)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(SIZE * f, SIZE))
		var low := 0.25
		var stretch := 0.0
		var tuck := 0.0
		match state:
			"crouch":
				low = 1.0
			"lunge":
				low = 0.0
				stretch = 1.0
			"cower", "recoil":
				low = 0.8
				tuck = 1.0
			"patrol":
				low = 0.7 if pause > 0.0 else 0.1
			"hunt":
				low = 0.5
		var ph := _stride / 22.0
		var gait := clampf(_moving / 160.0, 0.0, 1.0)
		var sink := low * 8.0
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
		_shape(tail, Pal.WOLF_DARK, 2.2)
		# body: deep chest, tucked belly, a ruff at the shoulders
		var body := PackedVector2Array([
			Vector2(-30, -30 + sink), Vector2(-18, -39 + sink), Vector2(0, -41 + sink * 1.2), Vector2(16, -42 + sink * 1.4),
			Vector2(26, -36 + sink * 1.4), Vector2(29, -24 + sink), Vector2(18, -16 + sink * 0.6), Vector2(0, -19 + sink * 0.6),
			Vector2(-18, -17 + sink * 0.6), Vector2(-29, -21 + sink)])
		for i in body.size():
			body[i] = body[i] + Vector2(stretch * (body[i].x * 0.18), shiver)
		_shape(body, Pal.WOLF)
		_fill(_pts_oval(Vector2(0, -20 + sink * 0.6), 17.0, 3.5), Pal.WOLF_BELLY)
		for i in 5:
			var rx := 8.0 + i * 5.0
			_fill(PackedVector2Array([Vector2(rx - 3, -38 + sink * 1.3), Vector2(rx, -46 + sink * 1.3), Vector2(rx + 3, -38 + sink * 1.3)]), Pal.WOLF_DARK)
		# near legs
		_legs(1.0, ph, gait, sink, stretch, Pal.WOLF)
		# head: low and level when it stalks, thrown forward when it leaps
		var hy := -40.0 + low * 14.0 - stretch * 4.0
		var hx := 30.0 + stretch * 8.0
		var ears := -9.0 if tuck > 0.0 else 0.0
		_shape(PackedVector2Array([Vector2(hx + 2, hy - 8 + ears * 0.2), Vector2(hx + 3, hy - 20 - ears), Vector2(hx + 8, hy - 9)]), Pal.WOLF_DARK, 2.0)
		_shape(PackedVector2Array([Vector2(hx + 7, hy - 9), Vector2(hx + 10, hy - 20 - ears), Vector2(hx + 13, hy - 8)]), Pal.WOLF, 2.0)
		var snarl := 3.0 if state == "crouch" or state == "lunge" or state == "hunt" else 0.0
		var head := PackedVector2Array([
			Vector2(hx - 6, hy - 2), Vector2(hx + 4, hy - 10), Vector2(hx + 14, hy - 8), Vector2(hx + 26, hy - 3),
			Vector2(hx + 29, hy + 1), Vector2(hx + 26, hy + 4 + snarl), Vector2(hx + 12, hy + 7 + snarl), Vector2(hx - 2, hy + 8)])
		_shape(head, Pal.WOLF)
		_fill(_pts_oval(Vector2(hx + 16, hy + 4 + snarl * 0.5), 9.0, 2.2), Pal.WOLF_BELLY)
		draw_circle(Vector2(hx + 28, hy), 2.4, Pal.OUTLINE)
		if snarl > 0.0:
			draw_line(Vector2(hx + 14, hy + 3), Vector2(hx + 26, hy + 2), Pal.MAW, 2.0, true)
			for k in 3:
				var tx := hx + 16.0 + k * 3.5
				_fill(PackedVector2Array([Vector2(tx, hy + 2), Vector2(tx + 1.2, hy + 5), Vector2(tx + 2.4, hy + 2)]), Pal.TOOTH)
		draw_circle(Vector2(hx + 10, hy - 3), 2.2, Pal.OUTLINE)
		if flash > 0.0:
			draw_circle(Vector2(0, -28), 32.0, Color(1, 1, 1, 0.45))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _legs(side: float, ph: float, gait: float, sink: float, stretch: float, col: Color) -> void:
		var s := side * 3.0
		for fore in [true, false]:
			var is_fore: bool = fore
			var hip := Vector2(18.0 + s if is_fore else -20.0 + s, -26.0 + sink)
			var swing := sin(ph + (0.0 if is_fore else PI)) * 12.0 * gait
			var lift := maxf(0.0, cos(ph + (0.0 if is_fore else PI))) * 7.0 * gait
			var paw := Vector2(hip.x + swing, 0.0 - lift)
			if stretch > 0.0:
				paw = hip + (Vector2(24, 14) if is_fore else Vector2(-26, 12))
			var knee := hip.lerp(paw, 0.5) + Vector2(-4.0 if is_fore else 5.0, 0)
			_limb(hip, knee, 6.0, col)
			_limb(knee, paw, 5.0, col)
			_fill(_pts_oval(paw + Vector2(2, -1), 4.5, 2.5), col.darkened(0.2))

	## The eyes shine through the dark — a pair, as if the head were turned
	## a little toward him. They flare in the crouch that comes before a leap.
	func draw_glow(g: Node2D) -> void:
		if dying > 0.0:
			return
		var f := float(dir)
		var low := 1.0 if state == "crouch" else (0.8 if state == "cower" or state == "recoil" else 0.25)
		var e := global_position + Vector2(f * 40.0 * SIZE, (-43.0 + low * 14.0) * SIZE)
		var flare := 1.0 if state == "crouch" else 0.0
		var dim := 0.45 if state == "cower" or state == "recoil" else 1.0
		g.draw_circle(e, 7.0 + flare * 6.0, Color(Pal.WOLF_EYE, (0.14 + flare * 0.25) * dim))
		g.draw_circle(e, 2.4 + flare * 0.8, Color(Pal.WOLF_EYE, 0.95 * dim))
		g.draw_circle(e + Vector2(-f * 6.0, 1.0), 2.0 + flare * 0.6, Color(Pal.WOLF_EYE, 0.7 * dim))


class Bat extends Bestiary.Insect:
	## The insect's hunt — hover, wind up, dash straight across him — in a
	## bat's body. Bats come to the torch, so they are the danger that finds
	## him INSIDE the light, where the wolves will not go.
	func _setup() -> void:
		super._setup()
		add_to_group("glow")

	func _facing() -> float:
		if absf(vel.x) > 30.0:
			return signf(vel.x)
		if player != null:
			return 1.0 if player.global_position.x > global_position.x else -1.0
		return 1.0

	func _draw() -> void:
		var rate := 34.0 if state == "wind" else 15.0
		var flap := sin(t * rate)
		if state == "wind":
			flap = -0.8 + sin(t * rate) * 0.25     # wings held high, trembling
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(_facing(), 1.0))
		for side in [-1.0, 1.0]:
			var s: float = side
			var wing := PackedVector2Array([
				Vector2(s * 4, -4), Vector2(s * 16, -12 + flap * 9.0), Vector2(s * 31, -8 + flap * 15.0),
				Vector2(s * 25, 2 + flap * 7.0), Vector2(s * 18, -1 + flap * 5.0), Vector2(s * 12, 5 + flap * 2.0),
				Vector2(s * 3, 5)])
			_shape(wing, Pal.BAT_WING if s > 0.0 else Pal.BAT_WING.darkened(0.15), 1.6)
			draw_line(Vector2(s * 4, -4), Vector2(s * 16, -12 + flap * 9.0), Pal.BAT.darkened(0.3), 1.6, true)
			draw_line(Vector2(s * 16, -12 + flap * 9.0), Vector2(s * 25, 2 + flap * 7.0), Pal.BAT.darkened(0.3), 1.2, true)
		_oval(Vector2(0, 1), 7.0, 9.0, Pal.BAT, 1.8)
		_dot(Vector2(1, -9), 5.5, Pal.BAT, 1.6)
		for s2 in [-1.0, 1.0]:
			var e: float = s2
			_fill(PackedVector2Array([Vector2(1 + e * 2, -12), Vector2(1 + e * 5, -20), Vector2(1 + e * 5.5, -11)]), Pal.BAT.darkened(0.2))
		_fill(PackedVector2Array([Vector2(3, -7), Vector2(5, -4), Vector2(7, -7)]), Pal.TOOTH)
		if flash > 0.0:
			draw_circle(Vector2.ZERO, 16.0, Color(1, 1, 1, 0.5))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func draw_glow(g: Node2D) -> void:
		if dying > 0.0:
			return
		var f := _facing()
		var a := 1.0 if state == "wind" else 0.7
		for s in [-1.0, 1.0]:
			var e := global_position + Vector2(1.0 * f + float(s) * 2.4, -10.0)
			g.draw_circle(e, 3.5, Color(Pal.EMBER_GLOW, 0.2 * a))
			g.draw_circle(e, 1.3, Color(Pal.EMBER_GLOW, a))


## ================================================================ MONKEYS
class Monkey extends Area2D:
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
		dying = 1.2
		vy = -240.0
		vx = from_dir * 80.0
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
			rotation += 6.0 * delta * signf(vx if vx != 0.0 else 1.0)
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
		MonkeyArt.draw_monkey(self, {
			"dir": dir, "t": t, "state": state, "hanging": hanging, "habit": habit,
			"eat": eat, "stare": stare, "wave": wave, "flash": flash,
			"fur": Pal.MONKEY, "dark": Pal.MONKEY_DARK, "face": Pal.MONKEY_FACE})


class MonkeyArt extends RefCounted:
	## The monkey drawing, shared by the troop and by Old Bongo (who adds a
	## beard, a crown and a gem to it). Draws into `c` in the monkey's own space.
	static func draw_monkey(c: CanvasItem, o: Dictionary) -> void:
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

	static func _oval(c: CanvasItem, at: Vector2, rx: float, ry: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 14:
			var a := TAU * i / 14.0
			pts.append(at + Vector2(cos(a) * rx, sin(a) * ry))
		c.draw_colored_polygon(pts, col)

	## A banana in the hand: `left` is how much is still uneaten.
	static func banana(c: CanvasItem, at: Vector2, left: float, peeled: bool) -> void:
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
		# the banana box beside him: a crate bound with vine, a stone lock
		var bx := Vector2(-58, 0)
		var lid := 0.0 if not box_open else -0.9
		draw_rect(Rect2(bx + Vector2(-26, -34), Vector2(52, 34)), Pal.BARK_DARK)
		draw_rect(Rect2(bx + Vector2(-23, -31), Vector2(46, 28)), Pal.BARK)
		for k in 3:
			draw_line(bx + Vector2(-23 + k * 23, -31), bx + Vector2(-23 + k * 23, -3), Pal.BARK_DARK, 2.0)
		if box_open:
			for k in 4:
				MonkeyArt.banana(self, bx + Vector2(-20 + k * 9, -44 + (k % 2) * 3), 1.0, false)
		draw_set_transform(bx + Vector2(-26, -34), lid, Vector2.ONE)
		draw_rect(Rect2(Vector2(0, -7), Vector2(54, 8)), Pal.BARK_DARK)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if not box_open:
			draw_line(bx + Vector2(-26, -20), bx + Vector2(26, -20), Pal.VINE, 3.0)
			draw_circle(bx + Vector2(0, -20), 7.0, Pal.CRAG_DARK)
			draw_circle(bx + Vector2(0, -20), 5.0, Pal.CRAG)
			draw_rect(Rect2(bx + Vector2(-1, -22), Vector2(2, 5)), Pal.CHARCOAL)
		MonkeyArt.draw_monkey(self, {
			"dir": dir, "t": t, "state": "calm", "hanging": false, "habit": 0,
			"eat": 1.0, "stare": 0.0, "wave": 0.0, "flash": flash, "scale": SIZE, "elder": true,
			"holding": "gem" if has_gem else "none", "talking": speaking,
			"fur": Pal.ELDER, "dark": Pal.ELDER_DARK, "face": Pal.ELDER_FACE})

	## The gem shows through the dark, so it can be spotted from below.
	func draw_glow(g: Node2D) -> void:
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
