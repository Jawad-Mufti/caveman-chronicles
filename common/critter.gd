class_name Critter
extends Area2D
## Base for everything that can hurt the caveman or be hit by him.
## Subclasses set up their shape in _setup, move in _tick, and draw themselves.

var hp := 1
var damage := 1
var flash := 0.0
var dying := 0.0
var fling := 1.0                ## > 1 while a HOME RUN lands: a killing blow throws it much further
var player: CaveMan

## Dying, so it reads from across the screen. The world holds its breath for
## a blink (hit-stop), there's a pop where the blow landed, and the last hit
## throws it the way the blow went, spinning; it lands, bounces once, and lies
## legs-up before it fades. A stomp squashes it flat instead. Each creature
## can choose its own way to go with death_style():
##   knock  — thrown back, tumbling (the default)
##   flip   — flipped high, end over end, lands belly-up
##   spiral — flying things: spin down to the ground in a wobbling spiral
##   curl   — drops and curls up, legs to the sky
##   limp   — no flight at all: slumps where it is
##   wilt   — plants: droop and shrink
const DEATH_TIME := 1.3
var death_t := -1.0
var _style := "knock"
var _dv := Vector2.ZERO
var _dspin := 0.0
var _dfloor := 0.0
var _drest := PI
var _dlift := 0.0
var _dbounces := 0
var _dstart := Vector2.ZERO

## Slow-motion that nests safely: the longest request wins, and time only
## comes back to normal when the last one runs out.
static var _slow_until_ms := 0

## Stomping. Landing on a critter from above crushes it.
## Big or spiked things set stompable = false so the player learns the exception.
var stompable := true
var stomp_top := -14.0    ## y offset of this critter's top, relative to its origin
var stomp_damage := 99    ## a clean landing kills almost anything small
var stomp_push := 0.0     ## sideways shove handed to the player, so big things throw him clear
var _prev_feet := -1000000.0   ## where his feet were last frame, so fast falls still register
var _prev_vy := 0.0            ## and how fast he was going, so the landing frame still counts


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	monitorable = true
	add_to_group("critters")
	_setup()


func _setup() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func _on_hit(_from_dir: int) -> void:
	pass


func _on_die() -> void:
	pass


func _on_stomped() -> void:
	pass


## How this creature dies (see the list at the top). Override to change it.
func death_style() -> String:
	return "knock"


## The ground it lands on when it dies. Flying things override this.
func death_floor() -> float:
	return position.y


## The whole game slows to `time_scale` for `secs` of real time (a hit-stop,
## or a boss's last moment). A small keeper node watches the real clock and
## puts time back to normal when the last slow-down runs out.
static var _keeper_alive := false


static func slow_time(tree: SceneTree, secs: float, time_scale: float) -> void:
	_slow_until_ms = maxi(_slow_until_ms, Time.get_ticks_msec() + int(secs * 1000.0))
	Engine.time_scale = minf(Engine.time_scale, time_scale)
	if not _keeper_alive:
		_keeper_alive = true
		tree.root.call_deferred("add_child", SlowKeeper.new())


class SlowKeeper extends Node:
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_delta: float) -> void:
		if Time.get_ticks_msec() >= Critter._slow_until_ms:
			Engine.time_scale = 1.0
			Critter._keeper_alive = false
			queue_free()



## ------------------------------------------------------------ one draw call
## Everything drawn here is collected into one Batch and handed to the GPU as
## a SINGLE draw call. Drawn shape by shape, a wolf was ~30 draw calls and the
## caveman ~200 — every frame — which is what made busy scenes stutter. The
## _ln / _pl / _cc / _pg / _rc / _ac / _st / _stm helpers stand in for
## draw_line / draw_polyline / draw_circle / draw_colored_polygon / draw_rect /
## draw_arc / draw_set_transform / draw_set_transform_matrix.
var _bb: Batch = null


func _draw() -> void:
	_bb = Batch.new()
	_paint()
	_bb.draw(self)
	_bb = null


func _segs(r: float) -> int:
	return clampi(int(r * 0.7) + 8, 8, 28)


func _ln(a: Vector2, b: Vector2, col: Color, w: float = -1.0, _aa: bool = false) -> void:
	if _bb == null:
		draw_line(a, b, col, w, _aa)
		return
	_bb.line(a, b, col, maxf(w, 1.0))


func _pl(pts: PackedVector2Array, col: Color, w: float = -1.0, _aa: bool = false) -> void:
	if _bb == null:
		draw_polyline(pts, col, w, _aa)
		return
	_bb.polyline(pts, col, maxf(w, 1.0))


func _cc(c: Vector2, r: float, col: Color, filled: bool = true, w: float = -1.0, _aa: bool = false) -> void:
	if _bb == null:
		draw_circle(c, r, col, filled, w, _aa)
		return
	if r <= 0.05:
		return
	if filled:
		_bb.circle(c, r, col, _segs(r))
	else:
		_bb.arc(c, r, 0.0, TAU, _segs(r), col, maxf(w, 1.0))


func _pg(pts: PackedVector2Array, col: Color) -> void:
	if _bb == null:
		draw_colored_polygon(pts, col)
		return
	_bb.poly(pts, col)


func _rc(r: Rect2, col: Color, filled: bool = true, w: float = -1.0, _aa: bool = false) -> void:
	if _bb == null:
		draw_rect(r, col, filled, w, _aa)
		return
	if filled:
		_bb.rect(r, col)
	else:
		_bb.polyline(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]), col, maxf(w, 1.0))


func _ac(c: Vector2, r: float, a0: float, a1: float, n: int, col: Color, w: float = -1.0, _aa: bool = false) -> void:
	if _bb == null:
		draw_arc(c, r, a0, a1, n, col, w, _aa)
		return
	_bb.arc(c, r, a0, a1, maxi(n, 2), col, maxf(w, 1.0))


func _st(pos: Vector2 = Vector2.ZERO, rot: float = 0.0, sc: Vector2 = Vector2.ONE) -> void:
	if _bb == null:
		draw_set_transform(pos, rot, sc)
		return
	_bb.set_xf(Transform2D(rot, sc, 0.0, pos))


func _stm(m: Transform2D) -> void:
	if _bb == null:
		draw_set_transform_matrix(m)
		return
	_bb.set_xf(m)


## What the creature looks like. Each kind of creature draws itself here.
func _paint() -> void:
	pass


## Caught in a fire burst. Most things simply take the damage; a few react.
func burned(dmg: int, from: Vector2) -> void:
	var d := int(signf(global_position.x - from.x))
	take_hit(dmg, d if d != 0 else 1)


func take_hit(dmg: int, from_dir: int) -> void:
	if dying > 0.0:
		return
	hp -= dmg
	flash = 0.15
	_on_hit(from_dir)
	if hp <= 0:
		_begin_death(from_dir)


func _begin_death(from_dir: int) -> void:
	dying = DEATH_TIME
	death_t = 0.0
	flash = 0.2
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var d := float(from_dir)
	if d == 0.0 and player != null:
		d = signf(global_position.x - player.global_position.x)
	if d == 0.0:
		d = 1.0
	_style = death_style() if from_dir != 0 else "squash"
	_dfloor = death_floor()
	_dstart = position
	_dlift = _body_height()
	_drest = PI + randf_range(-0.15, 0.15)
	match _style:
		"knock":
			_dv = Vector2(d * 320.0, -400.0)
			_dspin = d * 11.0
		"flip":
			_dv = Vector2(d * 200.0, -520.0)
			_dspin = d * 16.0
		"spiral":
			_dv = Vector2(d * 100.0, -150.0)
			_dspin = d * 18.0
		"curl":
			_dv = Vector2(d * 150.0, -280.0)
			_dspin = d * 9.0
		_:
			# limp, wilt, squash: no flight
			_dv = Vector2.ZERO
			_dspin = 0.0
			_drest = 0.0
			_dlift = 0.0
	_dv *= fling
	_dspin *= minf(fling, 1.6)
	_on_die()
	# the world holds its breath for a blink, and there's a pop where it was hit
	if is_inside_tree():
		Critter.slow_time(get_tree(), 0.07, 0.08)
		var pop := DeathPop.new()
		pop.position = global_position + Vector2(0, -_body_height() * 0.6)
		pop.big = _body_height() > 40.0
		get_parent().call_deferred("add_child", pop)


## How tall it stands above its origin (from its hit box), so a creature lying
## legs-up can be lifted to rest on its back instead of sinking into the ground.
func _body_height() -> float:
	for c in get_children():
		if c is CollisionShape2D:
			var cs := c as CollisionShape2D
			if cs.shape is RectangleShape2D:
				return maxf(0.0, -(cs.position.y - (cs.shape as RectangleShape2D).size.y * 0.5)) * 0.9
			return 0.0
	return 0.0


## One frame of dying, whichever way it goes.
func _death_step(delta: float) -> void:
	death_t += delta
	dying = maxf(DEATH_TIME - death_t, 0.001)
	match _style:
		"squash":
			var k := clampf(death_t / 0.1, 0.0, 1.0)
			scale = Vector2(lerpf(1.0, 1.6, k), lerpf(1.0, 0.2, k))
		"wilt":
			var k := clampf(death_t / 0.6, 0.0, 1.0)
			rotation = lerpf(0.0, 0.7, k)
			scale = Vector2.ONE * lerpf(1.0, 0.6, k)
		"limp":
			var k := clampf(death_t / 0.3, 0.0, 1.0)
			position.y = lerpf(_dstart.y, _dfloor, k * k)
		_:
			if _dbounces < 2:
				_dv.y += 1500.0 * delta
				if _style == "spiral":
					_dv.x = cos(death_t * 11.0) * 160.0
				position += _dv * delta
				rotation += _dspin * delta
				if position.y >= _dfloor and _dv.y > 0.0:
					position.y = _dfloor
					_dbounces += 1
					if _dbounces == 1:
						# one bounce off the ground, and a puff of dust
						_dv = Vector2(_dv.x * 0.35, -absf(_dv.y) * 0.28)
						_dspin *= 0.3
						var dust := DeathPop.new()
						dust.dust = true
						dust.position = Vector2(position.x, _dfloor)
						get_parent().add_child(dust)
					else:
						_dv = Vector2.ZERO
			else:
				# and lies legs-up, still
				rotation = lerp_angle(rotation, _drest, minf(12.0 * delta, 1.0))
				position.y = move_toward(position.y, _dfloor - _dlift, 300.0 * delta)
	modulate.a = clampf((DEATH_TIME - death_t) / 0.35, 0.0, 1.0)
	if death_t >= DEATH_TIME:
		queue_free()
		return
	queue_redraw()


## Stars going round over something that has been knocked silly.
class Dizzy extends Node2D:
	var t := 0.0
	var life := 3.0
	var radius := 26.0

	func _process(delta: float) -> void:
		t += delta
		if t > life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var a := clampf((life - t) / 0.5, 0.0, 1.0)
		for i in 3:
			var ang := t * 5.0 + i * TAU / 3.0
			var p := Vector2(cos(ang) * radius, sin(ang) * radius * 0.3)
			var r := 6.0
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.35, -r * 0.35), p + Vector2(r, 0),
				p + Vector2(r * 0.35, r * 0.35), p + Vector2(0, r), p + Vector2(-r * 0.35, r * 0.35), p + Vector2(-r, 0),
				p + Vector2(-r * 0.35, -r * 0.35)]), Color(1.0, 0.88, 0.45, a))


## The pop where a creature dies: a flash ring and a scatter of stars — or,
## with dust set, a puff of dust where a body hits the ground.
class DeathPop extends Node2D:
	var t := 0.0
	var big := false
	var dust := false

	func _process(delta: float) -> void:
		t += delta
		if t > 0.5:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := t / 0.5
		var a := 1.0 - k
		var s := 1.6 if big else 1.0
		if dust:
			for i in 6:
				var dx := (i - 2.5) * 9.0 * s
				draw_circle(Vector2(dx * (1.0 + k * 1.5), -4.0 - k * 10.0), (5.0 + k * 8.0) * s, Color(0.72, 0.66, 0.56, 0.5 * a))
			return
		draw_arc(Vector2.ZERO, (10.0 + k * 38.0) * s, 0.0, TAU, 24, Color(1, 1, 1, 0.9 * a), 4.0 * a + 1.0)
		for i in 7:
			var ang := TAU * i / 7.0 + 0.4
			var p := Vector2.from_angle(ang) * (8.0 + k * 46.0) * s
			var r := 5.0 * a * s
			if r < 1.0:
				continue
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.35, -r * 0.35), p + Vector2(r, 0),
				p + Vector2(r * 0.35, r * 0.35), p + Vector2(0, r), p + Vector2(-r * 0.35, r * 0.35), p + Vector2(-r, 0),
				p + Vector2(-r * 0.35, -r * 0.35)]), Color(1.0, 0.93, 0.6, a))


## True when he is coming down and his feet are above this critter's back.
## Checks last frame as well as this one: at full fall speed he covers ~10 px
## per physics step, so a single-frame test misses the landing entirely.
func _is_stomp() -> bool:
	if not stompable or dying > 0.0 or player == null:
		return false
	# Landing on the floor zeroes his fall speed in the SAME frame he touches a
	# ground-level critter, so testing only the current velocity makes anything
	# standing on the floor impossible to stomp. Last frame's speed counts too.
	if player.velocity.y <= 40.0 and _prev_vy <= 40.0:
		return false
	# The faster he is falling, the further past the ideal point he will be by
	# the time this runs, so the allowance grows with fall speed.
	var slack := 18.0 + maxf(player.velocity.y, 0.0) * 0.035
	var line := global_position.y + stomp_top + slack
	return player.global_position.y <= line or _prev_feet <= line


func _physics_process(delta: float) -> void:
	flash = maxf(flash - delta, 0.0)
	if dying > 0.0:
		_death_step(delta)
		return

	if player == null:
		var p := get_tree().get_first_node_in_group("player")
		if p != null:
			player = p as CaveMan

	_tick(delta)

	if player != null and not player.dead and overlaps_body(player):
		if _is_stomp():
			_on_stomped()
			take_hit(stomp_damage, 0)
			# bounce him off to whichever side he landed on, so he cannot keep
			# dropping onto the same back over and over
			var away := signf(player.global_position.x - global_position.x)
			if away == 0.0:
				away = float(player.facing)
			player.stomp_bounce(stomp_push * away)
		elif damage > 0:
			player.hurt(damage, global_position.x)

	if player != null:
		_prev_feet = player.global_position.y
		_prev_vy = player.velocity.y

	# Redrawing is only needed for ANIMATION. A creature far off screen still
	# moves (its transform updates without re-running _draw), so re-running the
	# drawing for it is pure waste — and most of a 9,400 px level is off screen.
	if player == null or absf(player.global_position.x - global_position.x) < 820.0:
		queue_redraw()


## ---------------------------------------------------------------- drawing
## Shared by every creature, so one change restyles the whole bestiary.
## Every filled shape is drawn TWICE: once in a shadow tone, then again pulled
## in toward the light in the base tone. That leaves a shaded rim around each
## form, which is what makes a shape read as rounded rather than as a sticker.
## Outlines are kept, but thin and tinted from the fill — never black.
const OLW := 2.5
const LIGHT := Vector2(0.55, -0.83)   ## the sun sits high and to the right


func _pts_oval(c: Vector2, rx: float, ry: float, rot: float = 0.0, n: int = 10) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cr := cos(rot)
	var sr := sin(rot)
	for i in n:
		var a := TAU * i / float(n)
		var v := Vector2(cos(a) * rx, sin(a) * ry)
		pts.append(c + Vector2(v.x * cr - v.y * sr, v.x * sr + v.y * cr))
	return pts


func _fill(pts: PackedVector2Array, col: Color) -> void:
	_pg(pts, col)


## The same outline, shrunk toward its own centre and nudged into the light.
func _lit(pts: PackedVector2Array, amount: float = 0.86) -> PackedVector2Array:
	var mid := Vector2.ZERO
	for p in pts:
		mid += p
	mid /= float(pts.size())
	var span := 0.0
	for p in pts:
		span = maxf(span, p.distance_to(mid))
	var push := LIGHT * minf(2.6, span * 0.10)
	var out := PackedVector2Array()
	for p in pts:
		out.append(mid + (p - mid) * amount + push)
	return out


func _shape(pts: PackedVector2Array, col: Color, w: float = OLW) -> void:
	if _bb != null:
		_bb.poly_pair(pts, col.darkened(0.30), _lit(pts), col)
	else:
		_pg(pts, col.darkened(0.30))
		_pg(_lit(pts), col)
	if w > 0.0:
		var ring := PackedVector2Array(pts)
		ring.append(pts[0])
		_pl(ring, col.darkened(0.62), w * 0.7, false)


func _oval(c: Vector2, rx: float, ry: float, col: Color, w: float = OLW, rot: float = 0.0) -> void:
	_shape(_pts_oval(c, rx, ry, rot), col, w)


func _dot(c: Vector2, r: float, col: Color, w: float = OLW) -> void:
	_cc(c, r, col.darkened(0.30))
	_cc(c + LIGHT * r * 0.16, r * 0.86, col)
	if w > 0.0:
		_ac(c, r, 0.0, TAU, 12, col.darkened(0.62), w * 0.7, false)


## A thick outlined limb: outline pass, then fill, with round joints.
func _limb(a: Vector2, b: Vector2, width: float, col: Color) -> void:
	_ln(a, b, Pal.OUTLINE, width + 4.0, false)
	_cc(a, (width + 4.0) * 0.5, Pal.OUTLINE)
	_cc(b, (width + 4.0) * 0.5, Pal.OUTLINE)
	_ln(a, b, col, width, false)
	_cc(a, width * 0.5, col)
	_cc(b, width * 0.5, col)


## An eye with a pupil. slit = a reptile's vertical pupil.
func _eye(c: Vector2, r: float, look: Vector2, white: Color, slit: bool = false) -> void:
	_dot(c, r, white, 1.4)
	if slit:
		_fill(_pts_oval(c + look, r * 0.34, r * 0.82), Pal.OUTLINE)
	else:
		_cc(c + look, r * 0.46, Pal.OUTLINE)
	_cc(c + look - Vector2(r * 0.3, r * 0.35), r * 0.2, Color(1, 1, 1, 0.9))


func add_circle_shape(radius: float, offset: Vector2 = Vector2.ZERO) -> void:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	cs.shape = c
	cs.position = offset
	add_child(cs)


func add_rect_shape(size: Vector2, offset: Vector2 = Vector2.ZERO) -> void:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = offset
	add_child(cs)
