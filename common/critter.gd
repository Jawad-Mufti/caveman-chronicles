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
	# struck, the whole silhouette flashes white (a shader), not a circle over it
	material = FX.flash_material()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS     # painted fur: smooth, not blocky
	_setup()
	_hp0 = hp


var kb := 0.0                   ## knock-back speed from the last blow (px/s, sideways)


## ---------------------------------------------------------- THE ATTACK DIRECTOR
## Beasts take TURNS: at most MAX_ATTACKERS go for him at once, and a new one
## only every TURN_GAP_MS — the rest circle, snarl and feint, waiting for an
## opening. A beast asks before it commits to an attack (`may_attack`) and
## hands its turn back after (`attack_done`); a turn also runs out by itself.
static var _attackers := {}         ## instance id -> when its turn runs out (ms)
static var _last_grant := -100000
const MAX_ATTACKERS := 2
const TURN_GAP_MS := 550


static func may_attack(c: Object, hold_ms: int = 1500) -> bool:
	var now := Time.get_ticks_msec()
	for id in _attackers.keys():
		if int(_attackers[id]) < now or not is_instance_id_valid(id):
			_attackers.erase(id)
	var me := c.get_instance_id()
	if _attackers.has(me):
		return true
	if _attackers.size() >= MAX_ATTACKERS or now - _last_grant < TURN_GAP_MS:
		return false
	_attackers[me] = now + hold_ms
	_last_grant = now
	return true


## Still mid-attack (a leap, a follow-up bite): its turn is held on a little longer.
static func keep_attack(c: Object, hold_ms: int = 900) -> void:
	_attackers[c.get_instance_id()] = Time.get_ticks_msec() + hold_ms


static func attack_done(c: Object) -> void:
	_attackers.erase(c.get_instance_id())


## A little "!" (or a word) over a beast that's about to do something: its tell.
func tell(text: String = "!", col: Color = Color("ffdf5a")) -> void:
	if not is_inside_tree():
		return
	var w := CaveMan.WordPop.new()
	w.text = text
	w.size = 22 if text.length() <= 2 else 18
	w.color = col
	w.centered = true
	w.life = 0.5
	w.position = global_position + Vector2(0, -_body_height() - 46.0)
	get_parent().add_child(w)


## The damage a blow did, popping off the creature: bigger and hotter for bigger hits.
class DamageNumber extends Node2D:
	var value := 1
	var t := 0.0
	var _vx := 0.0

	func _ready() -> void:
		z_index = 25
		_vx = randf_range(-40.0, 40.0)

	func _process(delta: float) -> void:
		t += delta
		if t > 0.7:
			queue_free()
			return
		position += Vector2(_vx, -90.0 + t * 160.0) * delta
		queue_redraw()

	func _draw() -> void:
		var big := value >= 5
		var col := Color.WHITE if value <= 2 else (Color("ffe066") if value <= 4 else Color("ff8a3a"))
		var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - t / 0.12)
		var a := clampf((0.7 - t) / 0.25, 0.0, 1.0)
		var size := int((22 if not big else 30) * pop)
		var txt := str(value)
		var font := ThemeDB.fallback_font
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := Vector2(-w * 0.5, 0)
		for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
			draw_string(font, at + o, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.1, 0.05, 0.02, a))
		draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col, a))


## SPIRIT ORBS (common/spirit_orbs.gd): beaten, it lets go of a burst of them,
## more for bigger beasts; they stream into him by themselves.
const ORBS := preload("res://common/spirit_orbs.gd")
var _hp0 := 1                   ## its hp when it appeared: what it's worth
var gives_orbs := true          ## false for things that aren't beasts to beat


func _release_orbs() -> void:
	if not gives_orbs or _hp0 > 500 or not is_inside_tree():
		return
	var him := player if player != null else get_tree().get_first_node_in_group("player") as CaveMan
	if him == null:
		return
	var burst := ORBS.new()
	burst.count = ORBS.worth(_hp0)
	burst.target = him
	burst.origin = global_position + Vector2(0, -_body_height() * 0.6 - 10.0)
	get_parent().add_child.call_deferred(burst)


func _setup() -> void:
	pass


var _flash_shown := 0.0


func _show_flash() -> void:
	var k := clampf(flash / 0.15, 0.0, 1.0) * 0.85
	if k != _flash_shown and material is ShaderMaterial:
		_flash_shown = k
		(material as ShaderMaterial).set_shader_parameter("flash", k)


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
	_furs.clear()
	_paint()
	if _furs.is_empty():
		_bb.draw(self)
	else:
		# the furred shapes, textured, each in its place among the rest: the batch
		# is drawn in pieces, cut where each fur shape was asked for
		var at := 0
		for f in _furs:
			_bb.draw_range(self, at, f[6])
			at = f[6]
			draw_set_transform_matrix(f[3])
			draw_colored_polygon(f[0], f[1], f[4], f[2])
			var ring: PackedVector2Array = f[0].duplicate()
			ring.append(f[0][0])
			draw_polyline(ring, f[1].darkened(0.75), f[5])
			draw_set_transform_matrix(Transform2D.IDENTITY)
		_bb.draw_range(self, at, _bb.points.size())
	_bb = null


## A shape covered in a fur texture (`tex`, tinted `col`), drawn over the rest.
## Fur runs along the body: the texture is laid in the shape's own space.
var _furs: Array = []
func _fur_shape(pts: PackedVector2Array, tex: Texture2D, col: Color, w: float = 1.6, tex_scale := 1.0) -> void:
	var uv := PackedVector2Array()
	var ts := tex.get_size() * 0.35 * tex_scale
	for p in pts:
		uv.append(p.rotated(0.75) / ts)       # (the hair in the texture runs on a slant: laid along the body)
	var xf: Transform2D = _bb.xf if _bb != null else Transform2D.IDENTITY
	_furs.append([pts, col, tex, xf, uv, w, _bb.points.size() if _bb != null else 0])


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


## Knocked flat by a heavy blow (the hammer): most creatures shrug it off;
## some are stunned for `secs`.
func stagger(_from_dir: int, _secs: float) -> void:
	pass


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
	# a number pops off it, and the blow knocks it back (big beasts barely budge)
	if dmg > 0 and dmg < 99 and is_inside_tree():
		var num := DamageNumber.new()
		num.value = dmg
		num.position = global_position + Vector2(randf_range(-10, 10), -_body_height() - 24.0)
		get_parent().add_child(num)
	if from_dir != 0:
		kb = float(from_dir) * minf(240.0 + 40.0 * dmg, 460.0) * (0.3 if _hp0 > 20 else 1.0)
	_on_hit(from_dir)
	if hp <= 0:
		_begin_death(from_dir)


## ---------------------------------------------------------- LAUNCH, JUGGLE, SLAM
## His uppercut (UP + HIT) LAUNCHES a beast into the air; hit it again up
## there and it's JUGGLED back up; DOWN + HIT on it SLAMS it into the ground,
## and the landing knocks over everything round about (a SLAM DUNK).
## Big beasts (hp at spawn over 20) can't be lifted.
var airborne := false
var _air_vy := 0.0
var _air_ground := 0.0
var _slammed := false


## An ELITE (deep in the level, in the big ambushes): bigger, blood-red, twice
## the health, and worth twice the orbs.
var elite := false


func make_elite() -> void:
	elite = true
	hp = hp * 2 + 1
	_hp0 = hp
	modulate = Color(1.0, 0.66, 0.6)
	scale = Vector2(1.15, 1.15)


func can_launch() -> bool:
	return _hp0 <= 20 and dying <= 0.0 and is_physics_processing()


func launch(vy: float) -> void:
	if not can_launch():
		return
	if not airborne:
		_air_ground = position.y
	airborne = true
	_air_vy = vy
	kb *= 0.15                     # straight UP, not away: it stays in reach for the juggle
	_slammed = false


func slam() -> void:
	if airborne:
		_air_vy = 1500.0
		_slammed = true


func _land_from_air() -> void:
	position.y = _air_ground
	airborne = false
	rotation = 0.0
	if not is_inside_tree():
		return
	FX.burst(get_parent(), global_position, "dust", 0.0)
	if not _slammed:
		return
	# SLAM DUNK: the ground jumps, and everything near is knocked flying
	_slammed = false
	FX.shards(get_parent(), global_position, Vector2(0, -1), true)
	var lvl := get_parent()
	if lvl.has_method("shake"):
		lvl.shake(7.0, 0.25)
	var w := CaveMan.WordPop.new()
	w.text = "SLAM DUNK!!"
	w.size = 32
	w.color = Color("ffe066")
	w.star = Color("c0392b", 0.85)
	w.centered = true
	w.life = 0.9
	w.position = global_position + Vector2(0, -120)
	lvl.add_child(w)
	take_hit(3, 0 if hp > 3 else 1)
	for n in get_tree().get_nodes_in_group("critters"):
		var c := n as Critter
		if c == null or c == self or c.dying > 0.0:
			continue
		var d := c.global_position - global_position
		if absf(d.x) < 140.0 and absf(d.y) < 90.0:
			c.take_hit(3, 1 if d.x >= 0.0 else -1)
			c.launch(-360.0)
			if player != null:
				player.combo_hit()


func _begin_death(from_dir: int) -> void:
	airborne = false
	rotation = 0.0
	attack_done(self)            # its turn goes to the next one
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
	_release_orbs()
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
	_show_flash()
	if dying > 0.0:
		_death_step(delta)
		return

	if player == null:
		var p := get_tree().get_first_node_in_group("player")
		if p != null:
			player = p as CaveMan

	# launched (his uppercut): it flies up helpless, tumbling, and comes back
	# down where it was — or is SLAMMED down, and the landing shakes the ground
	if airborne:
		_air_vy += (1100.0 if not _slammed else 1600.0) * delta       # a floaty arc: time to jump after it
		position.y += _air_vy * delta
		position.x += kb * delta
		kb = move_toward(kb, 0.0, 700.0 * delta)
		rotation += (8.0 if kb >= 0.0 else -8.0) * delta
		if position.y >= _air_ground and _air_vy > 0.0:
			_land_from_air()
		queue_redraw()
		return

	# knocked back by a blow: it slides, slowing, then its own moves take over
	if kb != 0.0:
		position.x += kb * delta
		kb = move_toward(kb, 0.0, 1700.0 * delta)
		if "left_x" in self and "right_x" in self and float(get("right_x")) > float(get("left_x")):
			position.x = clampf(position.x, float(get("left_x")), float(get("right_x")))

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
