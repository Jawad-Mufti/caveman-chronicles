class_name OldScar
extends Critter
## OLD SCAR, Terror of the Long Dark. A sabre-tooth with a scar across one
## eye and one fang broken off short. Everything he does has a tell.
##
## Phase 1 — the Stalk. He circles just outside the light and pounces (a low
##   crouch and flaring eyes first). If the pounce meets fire — a torch above
##   half held toward him, or a lit brazier's light — he flinches and cowers:
##   that's the window, and hits land double. Walk up on him while he isn't
##   cowering and he swipes (a raised paw first).
## Phase 2 — the Roar (below 60%). He roars: the torch goes out (unless the
##   club carries the Firestone's fire) and rocks shake loose. He takes to the
##   ledges and pounces from above, and sometimes feints: crouches, then
##   vaults over him to pounce from behind — turn the torch. Relight at a brazier.
## Phase 3 — Cornered (below 25%). He scrapes (the tell) and charges blind
##   across the clearing into the rocks, and stands there dazed: hit him.
## A fire burst always stops him. Beaten, he flees — leaving his broken fang.

signal phase_changed(phase: int)
signal roared
signal beaten

const MAX_HP := 80
const GRAV := 1800.0
const STALK := 190.0
const CHARGE := 560.0
const SIZE := 1.3               ## drawn (and hit) this much bigger than his design

var arena_l := 0.0
var arena_r := 0.0
var floor_y := 0.0
var ledges: Array = []          ## [[x0, x1, top y]]
var state := "wait"             ## wait enter intro stalk crouch pounce vault swipe cower flinch roar leap scrape charge dazed distracted beaten
var phase := 1
var dir := -1
var t := 0.0
var timer := 0.0
var cd := 2.0
var roar_cd := 10.0
var vel := Vector2.ZERO
var cur_floor := 0.0            ## the surface he is standing on (ground or a ledge)
var resolved := false
var swipe_cd := 0.0
var _from_ledge := false        ## a pounce off a ledge always comes down to the ground
var _swiped := false
var night: Night
var home := Vector2.ZERO
var _moving := 0.0
var _stride := 0.0
var _look_at := Vector2.ZERO    ## where he glares when distracted


func _setup() -> void:
	hp = MAX_HP
	damage = 0
	stompable = false
	add_rect_shape(Vector2(120, 64) * SIZE, Vector2(0, -34) * SIZE)
	floor_y = position.y
	cur_floor = floor_y
	home = position
	visible = false
	add_to_group("glow")


func ratio() -> float:
	return clampf(float(hp) / MAX_HP, 0.0, 1.0)


func start() -> void:
	visible = true
	position = Vector2(arena_r + 120.0, floor_y)
	cur_floor = floor_y
	state = "enter"
	dir = -1


func reset_fight() -> void:
	hp = MAX_HP
	phase = 1
	state = "wait"
	visible = false
	damage = 0
	position = home
	cur_floor = floor_y
	cd = 2.0
	roar_cd = 10.0


## Old Bongo threw something at him: he turns and roars at the tree.
func distract(at: Vector2) -> void:
	if state in ["stalk", "crouch"]:
		state = "distracted"
		timer = 1.6
		_look_at = at


func burned(dmg: int, _from: Vector2) -> void:
	if state in ["wait", "enter", "intro", "beaten"]:
		return
	_hurt(dmg)
	if hp > 0:
		state = "cower"
		timer = 3.0
		vel = Vector2.ZERO


func take_hit(dmg: int, from_dir: int) -> void:
	if state in ["wait", "enter", "intro", "beaten"]:
		return
	var open := state in ["cower", "dazed", "distracted"]
	_hurt(dmg * (2 if open else 1))
	if hp > 0 and not open and player != null and player.fire_club:
		# the Firestone's fire always makes him flinch
		state = "flinch"
		timer = 0.6
		vel = Vector2(from_dir * 180.0, -140.0)


func _hurt(amount: int) -> void:
	hp -= amount
	flash = 0.12
	if hp <= 0:
		hp = 0
		state = "beaten"
		timer = 0.0
		damage = 0
		beaten.emit()
		return
	if phase == 1 and ratio() <= 0.6:
		phase = 2
		phase_changed.emit(2)
		_begin_roar()
	elif phase == 2 and ratio() <= 0.25:
		phase = 3
		phase_changed.emit(3)
		_begin_roar()


func _begin_roar() -> void:
	state = "roar"
	timer = 1.4
	vel = Vector2.ZERO
	roar_cd = 11.0
	roared.emit()


func _tick(delta: float) -> void:
	t += delta
	timer -= delta
	cd -= delta
	roar_cd -= delta
	swipe_cd -= delta
	_moving = 0.0
	if night == null:
		night = get_tree().get_first_node_in_group("night") as Night
	if player == null or state == "wait":
		return
	var dx := player.global_position.x - position.x
	damage = 0
	match state:
		"enter":
			dir = -1
			_walk_to(arena_r - 160.0, 200.0, delta)
			if position.x <= arena_r - 158.0:
				state = "intro"
				timer = 1.6
				roared.emit()
		"intro":
			dir = 1 if dx > 0.0 else -1
			if timer <= 0.0:
				state = "stalk"
				cd = 1.5
		"stalk":
			_stalk(dx, delta)
		"crouch":
			dir = 1 if dx > 0.0 else -1
			if timer <= 0.0:
				# from phase 2 he sometimes feints: over the top, to pounce from behind
				if phase >= 2 and cur_floor == floor_y and randf() < 0.35:
					var behind := clampf(player.global_position.x + signf(dx) * 200.0, arena_l + 80.0, arena_r - 80.0)
					_launch(Vector2(behind, floor_y), 0.65)
					state = "vault"
				else:
					_pounce()
		"pounce", "leap", "vault":
			damage = 2 if state == "pounce" else 0
			_fly(delta)
			if state == "stalk" and _vaulted():
				state = "crouch"
				timer = 0.4
		"swipe":
			# the paw goes up (the tell), then comes down
			dir = 1 if dx > 0.0 else -1
			if timer <= 0.25 and not _swiped:
				_swiped = true
				if absf(dx) < 115.0 * SIZE and absf(player.global_position.y - position.y) < 80.0:
					player.hurt(2, position.x)
			if timer <= 0.0:
				state = "stalk"
				cd = maxf(cd, 0.8)
		"cower", "dazed":
			_settle(delta)
			if timer <= 0.0:
				state = "stalk"
				cd = 1.4
				if cur_floor != floor_y:
					# never sulk up on a ledge: down, away from him
					var away := signf(position.x - player.global_position.x)
					_leap_to(Vector2(clampf(position.x + away * 180.0, arena_l + 80.0, arena_r - 80.0), floor_y))
		"flinch":
			_settle(delta)
			if timer <= 0.0:
				state = "stalk"
				cd = 0.8
		"distracted":
			dir = 1 if _look_at.x > position.x else -1
			if timer <= 0.0:
				state = "stalk"
				cd = 1.0
		"roar":
			if timer <= 0.0:
				state = "stalk"
				cd = 1.2
		"scrape":
			if timer <= 0.0:
				state = "charge"
				vel = Vector2(dir * CHARGE, 0)
		"charge":
			damage = 2
			position.x += vel.x * delta
			_moving = CHARGE
			_stride += CHARGE * delta
			if position.x <= arena_l + 70.0 or position.x >= arena_r - 70.0:
				position.x = clampf(position.x, arena_l + 70.0, arena_r - 70.0)
				state = "dazed"
				timer = 3.0     # long enough to run the width of the clearing
				vel = Vector2.ZERO
		"beaten":
			# limps off into the dark on the right, and is gone
			dir = 1
			position.x += 110.0 * delta
			_moving = 110.0
			_stride += 110.0 * delta
			modulate.a = clampf(1.0 - (position.x - (arena_r - 200.0)) / 260.0, 0.0, 1.0)
			if modulate.a <= 0.0:
				visible = false
				state = "wait"


func _stalk(dx: float, delta: float) -> void:
	if phase >= 2 and roar_cd <= 0.0 and cur_floor == floor_y:
		_begin_roar()
		return
	var level := absf(player.global_position.y - cur_floor) < 70.0
	# too close: a swipe, with the paw raised first
	if level and absf(dx) < 105.0 and swipe_cd <= 0.0:
		state = "swipe"
		timer = 0.6
		_swiped = false
		swipe_cd = 1.3
		return
	# phase 3: the blind charge, whenever he's on the ground with him
	if phase == 3 and cd <= 0.0 and cur_floor == floor_y and level and randf() < 0.6:
		state = "scrape"
		timer = 0.6
		dir = 1 if dx > 0.0 else -1
		cd = 2.5
		return
	# phase 2+: up onto a ledge now and then, and pounce down from it
	if phase >= 2 and cd <= 0.0 and cur_floor == floor_y and randf() < 0.5:
		var l: Array = ledges[0] if absf(float(ledges[0][0]) - position.x) < absf(float(ledges[1][0]) - position.x) else ledges[1]
		_leap_to(Vector2((float(l[0]) + float(l[1])) * 0.5, float(l[2])))
		cd = 1.6
		return
	if cur_floor != floor_y:
		# on a ledge: wait, watch, and come down on him
		dir = 1 if dx > 0.0 else -1
		if cd <= 0.0:
			state = "crouch"
			timer = 0.55
		return
	var tx := _edge_target()
	if absf(tx - position.x) > 20.0:
		_walk_to(tx, STALK, delta)
	if _moving < 60.0:
		dir = 1 if dx > 0.0 else -1
	if cd <= 0.0 and level and absf(dx) < 620.0:
		state = "crouch"
		timer = 0.7 if phase == 1 else 0.55


## The first dark ground on his side of the man, a little past the light.
func _edge_target() -> float:
	var side := signf(position.x - player.global_position.x)
	if side == 0.0:
		side = 1.0
	var x := player.global_position.x
	var steps := 0
	while steps < 40 and night != null and night.is_lit(Vector2(x, floor_y - 30.0)):
		x += side * 16.0
		steps += 1
	return clampf(x + side * 60.0, arena_l + 60.0, arena_r - 60.0)


func _walk_to(tx: float, speed: float, delta: float) -> void:
	var step := clampf(tx - position.x, -speed * delta, speed * delta)
	position.x += step
	_stride += absf(step)
	_moving = absf(step) / maxf(delta, 0.001)
	if _moving > 60.0:
		dir = 1 if step > 0.0 else -1


func _pounce() -> void:
	_from_ledge = cur_floor != floor_y
	var target := player.global_position
	target.x = clampf(target.x, arena_l + 60.0, arena_r - 60.0)
	_launch(target, 0.6)
	state = "pounce"
	resolved = false
	cd = 3.2 if phase == 1 else 2.2


func _leap_to(at: Vector2) -> void:
	_launch(at, 0.7)
	state = "leap"


## Ballistic: from here to `to` in `time` seconds.
func _launch(to: Vector2, time: float) -> void:
	var d := to - position
	vel = Vector2(d.x / time, (d.y - 0.5 * GRAV * time * time) / time)
	dir = 1 if d.x >= 0.0 else -1


func _fly(delta: float) -> void:
	vel.y += GRAV * delta
	position += vel * delta
	position.x = clampf(position.x, arena_l + 50.0, arena_r - 50.0)
	if state == "pounce" and not resolved:
		var ddx := absf(player.global_position.x - position.x)
		var ddy := absf((player.global_position.y - 36.0) - (position.y - 34.0))
		if ddx < 80.0 * SIZE and ddy < 80.0 * SIZE:
			resolved = true
			if _meets_fire():
				# knocked out of the air by the fire: he comes down on the
				# ground and cowers there, where the club can reach him
				state = "cower"
				timer = 1.6 if phase == 1 else 1.3
				vel = Vector2(-dir * 240.0, -200.0)
				cur_floor = floor_y
				damage = 0
				return
	# land on a ledge if coming down onto one, else on the ground
	if vel.y > 0.0:
		var surface := floor_y
		var may_perch := not (state == "pounce" and _from_ledge)
		for l in ledges:
			if may_perch and position.x > float(l[0]) - 10.0 and position.x < float(l[1]) + 10.0 and position.y - vel.y * delta <= float(l[2]) + 2.0:
				surface = minf(surface, float(l[2]))
		if position.y >= surface:
			position.y = surface
			cur_floor = surface
			vel = Vector2.ZERO
			_was_vault = state == "vault"
			state = "stalk"


## Did that landing come out of a vault? (then he pounces again at once)
var _was_vault := false


func _vaulted() -> bool:
	var v := _was_vault
	_was_vault = false
	return v


## Fire in his face: a torch above half held toward him, or a brazier's light.
func _meets_fire() -> bool:
	var toward := (player.facing > 0) == (position.x > player.global_position.x)
	if player.has_torch and player.torch_fuel >= 0.5 and toward:
		return true
	if night != null:
		for i in night._l.size():
			var l: Vector4 = night._l[i]
			if night._str[i] >= 1.0 and player.global_position.distance_to(Vector2(l.x, l.y)) < l.z * Night.EDGE:
				return true
	return false


## Falls back to whatever surface he is over (after a recoil or flinch hop).
func _settle(delta: float) -> void:
	if vel != Vector2.ZERO or position.y < cur_floor:
		vel.y += GRAV * delta
		position += vel * delta
		position.x = clampf(position.x, arena_l + 50.0, arena_r - 50.0)
		var surface := floor_y
		for l in ledges:
			if position.x > float(l[0]) and position.x < float(l[1]) and position.y <= float(l[2]) + 2.0 and cur_floor == float(l[2]):
				surface = float(l[2])
		if position.y >= surface:
			position.y = surface
			cur_floor = surface
			vel = Vector2.ZERO


## ------------------------------------------------------------------- drawing
## Designed facing right, feet at the origin; a head taller than the man.
func _draw() -> void:
	if not visible:
		return
	var f := float(dir)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(f * SIZE, SIZE))
	var low := 0.15
	var stretch := 0.0
	var cow := 0.0
	var head_up := 0.0
	match state:
		"crouch", "scrape":
			low = 1.0
		"pounce", "leap", "charge":
			stretch = 1.0
			low = 0.2
		"cower", "dazed", "flinch":
			cow = 1.0
			low = 0.9
		"roar", "intro", "distracted":
			head_up = 1.0
		"swipe":
			low = 0.4
		"beaten":
			cow = 0.6
			low = 0.6
	var sink := low * 14.0
	var gait := clampf(_moving / 200.0, 0.0, 1.0)
	var ph := _stride / 34.0
	var shake := sin(t * 60.0) * 1.5 if state in ["cower", "scrape"] else 0.0
	var fur := Color("a88a5b")
	var fur_dark := Color("6f5839")
	var belly := Color("d8c69c")

	_legs(-1.0, ph + PI, gait, sink, stretch, fur_dark)
	# a stub of a tail
	_shape(PackedVector2Array([Vector2(-68, -60 + sink), Vector2(-84, -56 + sink), Vector2(-86, -46 + sink), Vector2(-70, -48 + sink)]), fur_dark, 2.5)
	# the body: deep shoulders, back sloping down to the hips
	var body := PackedVector2Array([
		Vector2(-70, -48 + sink), Vector2(-60, -66 + sink), Vector2(-30, -72 + sink), Vector2(0, -80 + sink * 1.2),
		Vector2(28, -88 + sink * 1.3), Vector2(52, -80 + sink * 1.3), Vector2(58, -58 + sink), Vector2(40, -36 + sink * 0.5),
		Vector2(0, -34 + sink * 0.5), Vector2(-40, -32 + sink * 0.5), Vector2(-66, -36 + sink)])
	for i in body.size():
		body[i] = body[i] + Vector2(stretch * body[i].x * 0.15, shake)
	_shape(body, fur, 3.5)
	_fill(_pts_oval(Vector2(0, -38 + sink * 0.5), 38.0, 6.0), belly)
	# stripes of darker fur
	for i in 5:
		var x := -48.0 + i * 20.0
		_fill(PackedVector2Array([Vector2(x, -70 + sink + (4 - i) * 1.5), Vector2(x + 8, -72 + sink), Vector2(x + 2, -52 + sink)]), fur_dark)
	if state == "swipe":
		# the near forepaw: raised high, then slashing down
		var up := timer > 0.25
		var hip := Vector2(39, -48 + sink)
		var paw := hip + (Vector2(20, -52) if up else Vector2(58, -6))
		_limb(hip, hip.lerp(paw, 0.5) + Vector2(4, -6), 13.0, fur)
		_limb(hip.lerp(paw, 0.5) + Vector2(4, -6), paw, 10.0, fur)
		_fill(_pts_oval(paw, 11.0, 7.0), fur.darkened(0.2))
		for k in 3:
			draw_line(paw + Vector2(6, -4 + k * 4), paw + Vector2(16, -2 + k * 4), Pal.TOOTH, 2.0, true)
		_legs_back_only(ph, gait, sink, stretch, fur)
	else:
		_legs(1.0, ph, gait, sink, stretch, fur)
	# head: low when stalking, thrown up to roar, tucked when cowering
	var hx := 60.0 + stretch * 14.0 - cow * 8.0
	var hy := -80.0 + low * 18.0 - head_up * 14.0 + cow * 10.0
	var jaw := 0.0
	if state in ["roar", "intro", "distracted"]:
		jaw = 16.0 + sin(t * 30.0) * 2.0
	elif state in ["crouch", "pounce", "charge"]:
		jaw = 5.0
	# ears: flat back when afraid
	var ear := -10.0 * cow
	_shape(PackedVector2Array([Vector2(hx - 6, hy - 14), Vector2(hx - 2 + ear, hy - 24 - ear * 0.3), Vector2(hx + 6, hy - 14)]), fur_dark, 2.5)
	var head := PackedVector2Array([Vector2(hx - 14, hy - 4), Vector2(hx - 4, hy - 16), Vector2(hx + 14, hy - 16), Vector2(hx + 30, hy - 8),
		Vector2(hx + 36, hy + 2), Vector2(hx + 30, hy + 8), Vector2(hx + 10, hy + 10), Vector2(hx - 10, hy + 8)])
	_shape(head, fur, 3.0)
	# lower jaw, dropping open to roar
	_shape(PackedVector2Array([Vector2(hx + 2, hy + 8), Vector2(hx + 30, hy + 6 + jaw * 0.6), Vector2(hx + 26, hy + 14 + jaw),
		Vector2(hx + 4, hy + 16 + jaw * 0.4)]), belly, 2.5)
	if jaw > 4.0:
		_fill(PackedVector2Array([Vector2(hx + 6, hy + 9), Vector2(hx + 30, hy + 7 + jaw * 0.5), Vector2(hx + 20, hy + 11 + jaw * 0.6)]), Pal.MAW)
	# the fangs: one long, one snapped off short
	_fill(PackedVector2Array([Vector2(hx + 22, hy + 6), Vector2(hx + 27, hy + 6), Vector2(hx + 24, hy + 34)]), Pal.TOOTH)
	_fill(PackedVector2Array([Vector2(hx + 14, hy + 7), Vector2(hx + 19, hy + 7), Vector2(hx + 17, hy + 16), Vector2(hx + 14, hy + 15)]), Pal.TOOTH)
	# nose, and the scar across the eye
	draw_circle(Vector2(hx + 34, hy - 2), 3.0, Pal.OUTLINE)
	draw_line(Vector2(hx + 4, hy - 16), Vector2(hx + 20, hy + 2), belly.lightened(0.2), 2.5, true)
	draw_circle(Vector2(hx + 14, hy - 6), 2.6, Pal.OUTLINE)
	if flash > 0.0:
		draw_circle(Vector2(0, -56), 60.0, Color(1, 1, 1, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if state == "dazed":
		# stars going round
		for i in 3:
			var a := t * 5.0 + i * TAU / 3.0
			var p := Vector2(f * hx, hy - 30.0) * SIZE + Vector2(cos(a) * 22.0, sin(a) * 7.0)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(2, -1), p + Vector2(6, 0), p + Vector2(2, 1),
				p + Vector2(0, 5), p + Vector2(-2, 1), p + Vector2(-6, 0), p + Vector2(-2, -1)]), Pal.OCHRE.lightened(0.3))


func _legs(side: float, ph: float, gait: float, sink: float, stretch: float, col: Color) -> void:
	var s := side * 5.0
	for fore in [true, false]:
		var is_fore: bool = fore
		var hip := Vector2(34.0 + s if is_fore else -50.0 + s, -48.0 + sink)
		var swing := sin(ph + (0.0 if is_fore else PI)) * 18.0 * gait
		var lift := maxf(0.0, cos(ph + (0.0 if is_fore else PI))) * 10.0 * gait
		var paw := Vector2(hip.x + swing, -lift)
		if stretch > 0.0:
			paw = hip + (Vector2(34, 22) if is_fore else Vector2(-38, 18))
		var knee := hip.lerp(paw, 0.5) + Vector2(-6.0 if is_fore else 8.0, 0)
		_limb(hip, knee, 13.0, col)
		_limb(knee, paw, 10.0, col)
		_fill(_pts_oval(paw + Vector2(4, -2), 9.0, 5.0), col.darkened(0.2))


func _legs_back_only(ph: float, gait: float, sink: float, stretch: float, col: Color) -> void:
	var hip := Vector2(-45.0, -48.0 + sink)
	var swing := sin(ph + PI) * 18.0 * gait
	var paw := Vector2(hip.x + swing, 0.0)
	var knee := hip.lerp(paw, 0.5) + Vector2(8.0, 0)
	_limb(hip, knee, 13.0, col)
	_limb(knee, paw, 10.0, col)
	_fill(_pts_oval(paw + Vector2(4, -2), 9.0, 5.0), col.darkened(0.2))


## Big amber eyes that burn through the dark; they flare in the crouch.
func draw_glow(g: Node2D) -> void:
	if not visible or state == "wait":
		return
	var f := float(dir)
	var low := 1.0 if state in ["crouch", "scrape"] else (0.9 if state in ["cower", "dazed"] else 0.15)
	var hx := 60.0
	var hy := -80.0 + low * 18.0
	var e := global_position + Vector2(f * (hx + 14.0), hy - 6.0) * SIZE
	var flare := 1.0 if state in ["crouch", "scrape"] else 0.0
	var dim := 0.4 if state in ["cower", "dazed"] else 1.0
	g.draw_circle(e, 10.0 + flare * 8.0, Color(Pal.WOLF_EYE, (0.18 + flare * 0.25) * dim))
	g.draw_circle(e, 3.2 + flare, Color(Pal.WOLF_EYE, 0.95 * dim))
	g.draw_circle(e + Vector2(-f * 9.0, 1.0), 2.6 + flare, Color(Pal.WOLF_EYE, 0.7 * dim))
