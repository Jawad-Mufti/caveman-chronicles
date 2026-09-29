class_name OldScar
extends Critter
## OLD SCAR, Terror of the Long Dark: a sabre-tooth with a scar across one eye
## and one fang broken off short. Every attack has a tell, and every tell is
## big enough to read from across the clearing.
##
## The entrance. His eyes open in the dark of his lair; he steps out into the
##   moonlight, rears, and roars.
## Phase 1 — the Hunt. He prowls at the edge of the light. When he means to
##   pounce he sinks low, rump up, and wiggles his hindquarters like a house
##   cat — then flies. Meet the pounce with fire (a torch above half held
##   toward him, or a lit brazier's light) and he's knocked out of the air and
##   cowers: hit him, hits land double. Crowd him and he rakes you, twice.
## Phase 2 — the Roar (below 60%). The roar is a shockwave: it throws you
##   back, snuffs the torch (unless the Fire Club feeds it) and shakes rocks
##   down. He vaults clean over your head to pounce from behind, and takes to
##   the ledges to come down on you from above.
## Phase 3 — Cornered (below 25%). He scrapes the ground and gallops blind
##   across the clearing into the rocks — and stands there dazed, stars
##   going round. His pounces come in pairs, and faster.
## And he's clever:
##   He learns. Stop two pounces with the torch and he stops leaping into it:
##     he vaults over and comes from behind instead.
##   He hates the light. He stalks to a burning brazier and swats it out — his
##     back is turned while he does it.
##   The eye trick (phase 2+). He melts into the dark, and TWO pairs of eyes
##     open, on either side. Only one is him.
##   Rock in the teeth. When he rears up to roar, a rock thrown into his open
##     jaws stuns him flat.
##   The meteor (phase 3). He climbs his lair rock and roars; a shadow grows
##     under the man; then he comes down on it.
##   The Firestone Hammer's fire wave knocks him down, and trips his charge.
## Beaten, he goes down hard; his broken fang flies from his jaw; he rises,
##   roars once at the sky, and limps away into the dark.
##
## He is drawn by a small skeleton — hips, shoulders, a bending spine, a head
## that stays level while the body moves, two-joint legs, a lagging tail — so
## everything he does is animated, not swapped between poses.

signal phase_changed(phase: int)
signal roared
signal beaten
signal fang_out(at: Vector2)
signal rock_in_teeth

const MAX_HP := 100
const GRAV := 1800.0
const PROWL := 170.0
const CHARGE := 600.0
const SIZE := 1.3               ## drawn (and hit) this much bigger than his design

var arena_l := 0.0
var arena_r := 0.0
var floor_y := 0.0
var ledges: Array = []          ## [[x0, x1, top y]]
var lair_x := 0.0               ## where his lair mouth is (he comes out of it)
var state := "wait"
var phase := 1
var dir := -1
var t := 0.0
var timer := 0.0
var cd := 2.0                   ## until his next attack
var roar_cd := 10.0
var swipe_cd := 0.0
var vel := Vector2.ZERO
var vx := 0.0                   ## ground speed while prowling or charging
var cur_floor := 0.0
var resolved := false
var night: Night
var home := Vector2.ZERO
var _from_ledge := false
var _was_vault := false
var _swipes := 0
var _double := false            ## phase 3: this pounce is followed by another
var _look_at := Vector2.ZERO
var _beat_t := 0.0
var _down := false
var _land := 0.0                ## > 0 just after landing: the squash
var _phase_walk := 0.0          ## the gait's phase, driven by distance covered
var _tail := 0.0                ## the tail lags behind what the body does
var _tail_v := 0.0
var _eye_at := Vector2.ZERO        ## where his eye is, for the glow
var _roar_hit := false
var braziers: Array = []        ## the clearing's stone bowls (he puts them out)
var _foiled := 0                ## pounces the torch has stopped in a row: he learns
var _target: Node2D = null      ## the brazier he's going to swat out
var _decoy: Node2D = null
var _meteor_cd := 6.0
var _mark: Node2D = null
var _hide_x := 0.0
var _rock_top := 0.0


func _setup() -> void:
	hp = MAX_HP
	damage = 0
	stompable = false
	add_rect_shape(Vector2(130, 70) * SIZE * 0.85, Vector2(-4, -44) * SIZE)
	floor_y = position.y
	cur_floor = floor_y
	home = position
	visible = false
	add_to_group("glow")


func ratio() -> float:
	return clampf(float(hp) / MAX_HP, 0.0, 1.0)


## The entrance: eyes in the dark of the lair, then out into the moonlight.
func start() -> void:
	visible = true
	modulate.a = 1.0
	rotation = 0.0
	position = Vector2(lair_x, floor_y)
	cur_floor = floor_y
	dir = -1
	vx = 0.0
	state = "lurk_in"
	timer = 1.3


func reset_fight() -> void:
	hp = MAX_HP
	phase = 1
	state = "wait"
	visible = false
	damage = 0
	position = home
	rotation = 0.0
	cur_floor = floor_y
	cd = 2.0
	roar_cd = 10.0


## Old Bongo threw something at him: he turns and snarls at the tree.
func distract(at: Vector2) -> void:
	if state in ["prowl", "crouch", "recover"]:
		state = "distracted"
		timer = 1.6
		_look_at = at


## --------------------------------------------------------------- being hit
func burned(dmg: int, from: Vector2) -> void:
	if state in ["wait", "lurk_in", "emerge", "intro", "beaten"]:
		return
	_hurt(dmg, 1 if global_position.x > from.x else -1)
	if hp > 0:
		state = "cower"
		timer = 3.0
		vel = Vector2(signf(global_position.x - from.x) * 200.0, -220.0)


func take_hit(dmg: int, from_dir: int) -> void:
	if state in ["wait", "lurk_in", "emerge", "intro", "beaten"]:
		return
	var open := state in ["cower", "dazed", "distracted", "swat"]
	# a rock (from further off than any club could reach) into his roaring jaws
	if state == "roar" and player != null and absf(player.global_position.x - position.x) > 170.0:
		_hurt(dmg * 2, from_dir)
		if hp > 0:
			state = "dazed"
			timer = 2.6
			_stars(2.5)
			rock_in_teeth.emit()
		return
	_hurt(dmg * (2 if open else 1), from_dir)
	if hp > 0 and not open and player != null and player.hammer and state in ["prowl", "recover", "swipe", "crouch"]:
		# the Firestone's fire always makes him flinch
		state = "flinch"
		timer = 0.55
		vel = Vector2(from_dir * 200.0, -160.0)


## The Firestone Hammer's fire wave: it knocks him flat — and trips a charge.
func fire_wave(dmg: int, from: Vector2) -> void:
	if state in ["wait", "lurk_in", "emerge", "intro", "beaten", "perch", "meteor", "climb"]:
		return
	var from_dir := 1 if global_position.x > from.x else -1
	var tripped := state == "charge"
	_hurt(dmg, from_dir)
	if hp <= 0:
		return
	if tripped:
		state = "dazed"
		timer = 3.0
		vx = 0.0
		_stars(2.9)
	elif vel == Vector2.ZERO:
		state = "cower"
		timer = 1.4
		vel = Vector2(from_dir * 200.0, -200.0)


func _stars(life: float) -> void:
	var stars := Critter.Dizzy.new()
	stars.life = life
	stars.radius = 36.0
	stars.position = Vector2(float(dir) * 70.0, -120.0) * SIZE
	add_child(stars)


func _hurt(amount: int, from_dir: int) -> void:
	hp -= amount
	flash = 0.14
	# a spark where the blow landed
	var spark := Critter.DeathPop.new()
	spark.position = global_position + Vector2(-float(from_dir) * 40.0, -70.0) * SIZE
	get_parent().add_child(spark)
	if hp <= 0:
		hp = 0
		_defeat(from_dir)
		return
	if phase == 1 and ratio() <= 0.6:
		phase = 2
		phase_changed.emit(2)
		_begin_roar()
	elif phase == 2 and ratio() <= 0.25:
		phase = 3
		phase_changed.emit(3)
		_begin_roar()


## ----------------------------------------------------------------- thinking
func _tick(delta: float) -> void:
	t += delta
	timer -= delta
	cd -= delta
	roar_cd -= delta
	swipe_cd -= delta
	_meteor_cd -= delta
	_land = maxf(_land - delta, 0.0)
	if night == null:
		night = get_tree().get_first_node_in_group("night") as Night
	if player == null or state == "wait":
		return
	var dx := player.global_position.x - position.x
	damage = 0
	match state:
		"lurk_in":
			# only his eyes, in the dark of the lair
			if timer <= 0.0:
				state = "emerge"
		"emerge":
			dir = -1
			_prowl_to(lair_x - 280.0, 110.0, delta)
			if position.x <= lair_x - 240.0:
				state = "intro"
				timer = 1.8
				roared.emit()
				_shockwave(false)
		"intro":
			if timer <= 0.0:
				state = "prowl"
				cd = 1.2
		"prowl":
			_think(dx, delta)
		"crouch":
			# rump up, chest down, hindquarters wiggling: the tell
			dir = 1 if dx > 0.0 else -1
			vx = move_toward(vx, 0.0, 1400.0 * delta)
			if timer <= 0.0:
				_pounce()
		"pounce", "leap", "vault":
			damage = 2 if state == "pounce" else 0
			_fly(delta)
		"land":
			if timer <= 0.0:
				if _double and not resolved:
					_double = false
					state = "crouch"
					timer = 0.3
				else:
					state = "recover"
					timer = 0.5
		"recover":
			vx = move_toward(vx, 0.0, 1200.0 * delta)
			if timer <= 0.0:
				state = "prowl"
		"swipe":
			_swipe(dx, delta)
		"cower", "dazed", "flinch":
			_settle(delta)
			if timer <= 0.0:
				state = "prowl"
				cd = 1.2
				# shaking it off: a moment before he can rake at the man beside him
				swipe_cd = maxf(swipe_cd, 0.7)
				if cur_floor != floor_y:
					var away := signf(position.x - player.global_position.x)
					_leap_to(Vector2(clampf(position.x + away * 180.0, arena_l + 90.0, arena_r - 90.0), floor_y))
		"distracted":
			dir = 1 if _look_at.x > position.x else -1
			if timer <= 0.0:
				state = "prowl"
				cd = 1.0
		"roar":
			vx = 0.0
			# a breath in (head back), then the roar itself
			if timer <= 1.0 and not _roar_hit:
				_roar_hit = true
				roared.emit()
				_shockwave(true)
			if timer <= 0.0:
				state = "prowl"
				cd = 1.0
		"scrape":
			dir = 1 if dx > 0.0 else -1
			if timer <= 0.0:
				state = "charge"
				vx = dir * 120.0
		"charge":
			damage = 3
			vx = move_toward(vx, dir * CHARGE, 1500.0 * delta)
			position.x += vx * delta
			_phase_walk += absf(vx) * delta
			_trail_dust(delta)
			if position.x <= arena_l + 80.0 or position.x >= arena_r - 80.0:
				position.x = clampf(position.x, arena_l + 80.0, arena_r - 80.0)
				_crash()
		"beaten":
			_beaten_step(delta)
		"to_brazier":
			# stalking to a burning bowl, to put it out
			if _target == null or not _target.lit:
				state = "prowl"
			else:
				var side := signf(position.x - _target.global_position.x)
				if side == 0.0:
					side = 1.0
				_prowl_to(_target.global_position.x + side * 70.0, 260.0, delta)
				if absf(position.x - (_target.global_position.x + side * 70.0)) < 16.0:
					state = "swat"
					timer = 1.0
					dir = 1 if _target.global_position.x > position.x else -1
		"swat":
			# the paw goes up... and comes down on the fire. His back is to the man.
			vx = 0.0
			if timer <= 0.45 and _target != null and _target.lit:
				_target.lit = false
				# its embers catch again after a while
				var bowl := _target
				get_tree().create_timer(12.0).timeout.connect(func() -> void:
					if is_instance_valid(bowl) and not bowl.lit:
						bowl.kindle())
				var puff := Critter.DeathPop.new()
				puff.dust = true
				puff.big = true
				puff.position = _target.global_position + Vector2(0, -100)
				get_parent().add_child(puff)
			if timer <= 0.0:
				state = "prowl"
				cd = 1.0
		"vanish":
			# back into the dark, fading as he goes
			_prowl_to(_hide_x, 420.0, delta)
			modulate.a = move_toward(modulate.a, 0.08, delta * 2.5)
			if absf(position.x - _hide_x) < 20.0 and modulate.a <= 0.1:
				state = "eyes"
				timer = 1.4
				dir = 1 if player.global_position.x > position.x else -1
				_decoy = DecoyEyes.new()
				var fake := clampf(player.global_position.x - (position.x - player.global_position.x), arena_l + 80.0, arena_r - 80.0)
				_decoy.position = Vector2(fake, floor_y - 78.0 * SIZE)
				(_decoy as DecoyEyes).facing = -dir
				get_parent().add_child(_decoy)
		"eyes":
			# two pairs of eyes in the dark. Only one is him.
			dir = 1 if player.global_position.x > position.x else -1
			if timer <= 0.0:
				state = "crouch"
				timer = 0.4
		"climb":
			damage = 0
			_fly(delta)
		"perch":
			# up on his rock, roaring; the shadow grows under the man
			vx = 0.0
			if _mark != null:
				_mark.global_position.x = move_toward(_mark.global_position.x, player.global_position.x, 260.0 * delta)
			if timer <= 0.0:
				var at := _mark.global_position if _mark != null else player.global_position
				_launch(Vector2(at.x, floor_y), 0.75)
				state = "meteor"
		"meteor":
			damage = 3
			_fly(delta)
	if state != "vanish" and state != "eyes" and modulate.a < 1.0 and state != "beaten":
		modulate.a = move_toward(modulate.a, 1.0, delta * 4.0)
	_tail_step(delta)


## What to do next, when he has the choice.
func _think(dx: float, delta: float) -> void:
	var level := absf(player.global_position.y - cur_floor) < 80.0
	dir = 1 if dx > 0.0 else -1
	# phase 2+: a roar every so often
	if phase >= 2 and roar_cd <= 0.0 and cur_floor == floor_y:
		_begin_roar()
		return
	# on a ledge: watch him, then come down on him
	if cur_floor != floor_y:
		vx = 0.0
		if cd <= 0.0:
			state = "crouch"
			timer = 0.45
		return
	# too close: the claws, twice
	if level and absf(dx) < 120.0 * SIZE and swipe_cd <= 0.0:
		# the paw goes up and is HELD there — a clear warning — then rakes twice
		state = "swipe"
		_swipes = 0
		timer = 0.7
		swipe_cd = 2.2
		return
	# he learns: two pounces stopped by the torch, and he stops leaping into it
	if cd <= 0.0 and level and _foiled >= 2:
		_foiled = 0
		var behind := clampf(player.global_position.x + signf(dx) * 230.0, arena_l + 90.0, arena_r - 90.0)
		_launch(Vector2(behind, floor_y), 0.7)
		state = "vault"
		cd = 1.8
		return
	# the meteor: up onto his rock, to come down on him
	if phase == 3 and _meteor_cd <= 0.0 and cd <= 0.0:
		_meteor_cd = 12.0
		_rock_top = floor_y - 292.0
		_launch(Vector2(lair_x + 10.0, _rock_top), 0.8)
		state = "climb"
		cd = 3.0
		return
	# he hates the light: now and then he goes to put a brazier out — but never
	# the last one burning, or the man could be left with no fire at all
	var lit := braziers.filter(func(b): return b.lit).size()
	if cd <= 0.0 and lit >= 2 and randf() < 0.25:
		for b in braziers:
			if b.lit and absf(player.global_position.x - b.global_position.x) > 260.0:
				_target = b
				state = "to_brazier"
				cd = 2.5
				return
	if cd <= 0.0 and level:
		var roll := randf()
		if phase >= 2 and roll > 0.75:
			# the eye trick: into the dark on the far side of him
			var side := signf(position.x - player.global_position.x)
			if side == 0.0:
				side = 1.0
			_hide_x = clampf(player.global_position.x + side * 400.0, arena_l + 90.0, arena_r - 90.0)
			if absf(_hide_x - player.global_position.x) < 300.0:
				_hide_x = clampf(player.global_position.x - side * 400.0, arena_l + 90.0, arena_r - 90.0)
			state = "vanish"
			cd = 2.4
			return
		if phase == 3 and roll < 0.45:
			state = "scrape"
			timer = 0.65
			cd = 2.6
			return
		if phase >= 2 and roll < 0.3:
			# up onto the nearer ledge, to come down on him from above
			var l: Array = ledges[0] if absf(float(ledges[0][0]) - position.x) < absf(float(ledges[1][0]) - position.x) else ledges[1]
			_leap_to(Vector2((float(l[0]) + float(l[1])) * 0.5, float(l[2])))
			cd = 1.4
			return
		if phase >= 2 and roll < 0.55:
			# over the top of him, to pounce from behind
			var behind := clampf(player.global_position.x + signf(dx) * 230.0, arena_l + 90.0, arena_r - 90.0)
			_launch(Vector2(behind, floor_y), 0.7)
			state = "vault"
			cd = 1.8
			return
		if absf(dx) < 640.0:
			state = "crouch"
			timer = [0.75, 0.55, 0.4][phase - 1]
			_double = phase == 3 and randf() < 0.6
			return
	# otherwise: prowl at the edge of the light
	var tx := _edge_target()
	_prowl_to(tx, PROWL, delta)
	if absf(vx) < 30.0:
		dir = 1 if dx > 0.0 else -1


## Two rakes of the claws, each with its paw raised first.
func _swipe(dx: float, delta: float) -> void:
	dir = 1 if dx > 0.0 else -1
	vx = move_toward(vx, 0.0, 1400.0 * delta)
	if timer <= 0.15 and timer + delta > 0.15:
		if absf(dx) < 135.0 * SIZE and absf(player.global_position.y - position.y) < 90.0:
			player.hurt(1, position.x)
		position.x = clampf(position.x + dir * 18.0, arena_l + 80.0, arena_r - 80.0)
	if timer <= 0.0:
		_swipes += 1
		if _swipes < 2:
			timer = 0.32
		else:
			state = "recover"
			timer = 0.6


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
	return clampf(x + side * 90.0, arena_l + 90.0, arena_r - 90.0)


## Walks with weight: speeds up and slows down rather than sliding.
func _prowl_to(tx: float, speed: float, delta: float) -> void:
	var want := clampf((tx - position.x) * 3.0, -speed, speed)
	if absf(tx - position.x) < 14.0:
		want = 0.0
	vx = move_toward(vx, want, 700.0 * delta)
	position.x = clampf(position.x + vx * delta, arena_l + 60.0, arena_r - 60.0)
	_phase_walk += absf(vx) * delta
	if absf(vx) > 40.0:
		dir = 1 if vx > 0.0 else -1


func _pounce() -> void:
	_from_ledge = cur_floor != floor_y
	if _decoy != null:
		_decoy.queue_free()
		_decoy = null
	var target := player.global_position
	target.x = clampf(target.x, arena_l + 70.0, arena_r - 70.0)
	_launch(target, 0.62)
	state = "pounce"
	resolved = false
	cd = [2.6, 2.0, 1.5][phase - 1]


func _leap_to(at: Vector2) -> void:
	_launch(at, 0.7)
	state = "leap"


func _launch(to: Vector2, time: float) -> void:
	var d := to - position
	vel = Vector2(d.x / time, (d.y - 0.5 * GRAV * time * time) / time)
	dir = 1 if d.x >= 0.0 else -1
	vx = 0.0


func _fly(delta: float) -> void:
	vel.y += GRAV * delta
	position += vel * delta
	position.x = clampf(position.x, arena_l + 50.0, arena_r - 50.0)
	if state == "pounce" and not resolved:
		var ddx := absf(player.global_position.x - position.x)
		var ddy := absf((player.global_position.y - 36.0) - (position.y - 50.0))
		if ddx < 90.0 * SIZE and ddy < 90.0 * SIZE:
			resolved = true
			if _meets_fire():
				_foiled += 1
				# knocked out of the air by the fire: down on the ground, cowering
				state = "cower"
				timer = [1.3, 1.1, 0.9][phase - 1]
				vel = Vector2(-dir * 260.0, -220.0)
				cur_floor = floor_y
				damage = 0
				_double = false
				return
	if vel.y > 0.0:
		var surface := floor_y
		var may_perch := not (state == "pounce" and _from_ledge) and state != "meteor"
		if state == "climb":
			surface = _rock_top
		for l in ledges:
			if may_perch and position.x > float(l[0]) - 10.0 and position.x < float(l[1]) + 10.0 and position.y - vel.y * delta <= float(l[2]) + 2.0:
				surface = minf(surface, float(l[2]))
		if position.y >= surface:
			position.y = surface
			cur_floor = surface
			vel = Vector2.ZERO
			_land = 0.18
			_dust(1.0)
			_was_vault = state == "vault"
			if state == "climb":
				state = "perch"
				timer = 1.6
				roared.emit()
				_shockwave(false)
				_mark = MeteorMark.new()
				_mark.position = Vector2(player.global_position.x, floor_y)
				get_parent().add_child(_mark)
				return
			if state == "meteor":
				# he comes down like a boulder: the ground shakes, and he's dazed by it
				if _mark != null:
					_mark.queue_free()
					_mark = null
				_shockwave(true)
				_dust(1.8)
				if player.global_position.distance_to(position) < 110.0 * SIZE:
					player.hurt(2, position.x)
				state = "dazed"
				timer = 1.8
				_stars(1.7)
				return
			if _was_vault:
				# landed behind him: at him again, at once
				state = "crouch"
				timer = 0.35
				dir = 1 if player.global_position.x > position.x else -1
			elif state == "pounce":
				state = "land"
				timer = 0.25
			else:
				state = "prowl"


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


func _settle(delta: float) -> void:
	vx = move_toward(vx, 0.0, 1400.0 * delta)
	if vel != Vector2.ZERO or position.y < cur_floor:
		vel.y += GRAV * delta
		position += vel * delta
		position.x = clampf(position.x, arena_l + 50.0, arena_r - 50.0)
		if position.y >= cur_floor:
			position.y = cur_floor
			vel = Vector2.ZERO
			_land = 0.15
			_dust(0.6)


func _begin_roar() -> void:
	state = "roar"
	timer = 1.5
	vx = 0.0
	vel = Vector2.ZERO
	roar_cd = 9.0
	_roar_hit = false


## The roar as a wall of air: a ring rolling out from his jaws; close enough
## and it throws the man back.
func _shockwave(push: bool) -> void:
	var ring := ShockRing.new()
	ring.position = global_position + Vector2(float(dir) * 70.0, -80.0) * SIZE
	get_parent().add_child(ring)
	var level := get_parent()
	if level.has_method("shake"):
		level.shake(8.0, 0.6)
	if push and player != null and player.global_position.distance_to(global_position) < 520.0:
		var away := signf(player.global_position.x - global_position.x)
		player.velocity = Vector2(away * 520.0, -260.0)
		player.knock = 0.35


func _crash() -> void:
	state = "dazed"
	timer = 3.0
	vx = 0.0
	_dust(1.6)
	var stars := Critter.Dizzy.new()
	stars.life = 2.9
	stars.radius = 36.0
	stars.position = Vector2(float(dir) * 70.0, -120.0) * SIZE
	add_child(stars)
	var level := get_parent()
	if level.has_method("shake"):
		level.shake(10.0, 0.5)


func _dust(amount: float) -> void:
	var d := Critter.DeathPop.new()
	d.dust = true
	d.big = amount > 0.9
	d.position = Vector2(position.x, cur_floor)
	get_parent().add_child(d)


var _dust_in := 0.0


func _trail_dust(delta: float) -> void:
	_dust_in -= delta
	if _dust_in <= 0.0:
		_dust_in = 0.09
		_dust(0.5)


## ------------------------------------------------------------------- beaten
func _defeat(from_dir: int) -> void:
	state = "beaten"
	_beat_t = 0.0
	_down = false
	damage = 0
	flash = 0.3
	var d := float(from_dir) if from_dir != 0 else -float(dir)
	vel = Vector2(d * 400.0, -480.0)
	dir = -int(d)
	Critter.slow_time(get_tree(), 1.1, 0.25)
	var pop := Critter.DeathPop.new()
	pop.big = true
	pop.position = global_position + Vector2(0, -80)
	get_parent().add_child(pop)
	beaten.emit()


func _beaten_step(delta: float) -> void:
	_beat_t += delta
	if not _down:
		vel.y += GRAV * delta
		position += vel * delta
		position.x = clampf(position.x, arena_l + 80.0, arena_r - 80.0)
		if position.y >= floor_y and vel.y > 0.0:
			position.y = floor_y
			cur_floor = floor_y
			vel = Vector2.ZERO
			_down = true
			_beat_t = 0.0
			_dust(1.6)
			var stars := Critter.Dizzy.new()
			stars.life = 1.9
			stars.radius = 40.0
			stars.position = Vector2(float(dir) * 70.0, -70.0) * SIZE
			add_child(stars)
			fang_out.emit(global_position + Vector2(float(dir) * 110.0 * SIZE, 0))
		return
	if _beat_t > 3.9:
		# away into the dark, limping on one front paw
		dir = 1
		vx = 140.0 + sin(_beat_t * 7.0) * 50.0
		position.x += vx * delta
		_phase_walk += absf(vx) * delta
		modulate.a = clampf(1.0 - (position.x - (arena_r - 200.0)) / 260.0, 0.0, 1.0)
		if modulate.a <= 0.0:
			visible = false
			state = "wait"
	elif _beat_t > 2.4:
		dir = -1 if position.x > (arena_l + arena_r) * 0.5 else 1


## --------------------------------------------------------------------- tail
func _tail_step(delta: float) -> void:
	# a spring toward where the body wants it, so it lags and overshoots
	var want := -vx * 0.0015 + sin(t * 1.6) * 0.12
	match state:
		"crouch":
			want = 0.5 + sin(t * 14.0) * 0.25     # lashing
		"cower", "dazed":
			want = -0.8                           # tucked
		"pounce", "vault", "leap", "charge":
			want = 0.25
	_tail_v += (want - _tail) * 60.0 * delta
	_tail_v *= 1.0 - 8.0 * delta
	_tail += _tail_v * delta


## ------------------------------------------------------------------ drawing
## The pose, worked out from what he is doing this frame.
func _pose() -> Dictionary:
	var p := {"crouch": 0.0, "rump": 0.0, "stretch": 0.0, "cower": 0.0, "head_up": 0.0, "jaw": 0.0,
		"gait": 0.0, "gallop": 0.0, "wiggle": 0.0, "paw": 0.0, "tuck": 0.0, "down": 0.0, "limp": 0.0}
	var moving := clampf(absf(vx) / 180.0, 0.0, 1.0)
	p["gait"] = moving
	match state:
		"lurk_in", "prowl", "emerge", "recover":
			p["crouch"] = 0.25 * moving
		"crouch":
			p["crouch"] = 1.0
			p["rump"] = 1.0
			p["wiggle"] = sin(t * 24.0)
			p["jaw"] = 0.25
		"pounce", "vault", "leap":
			p["stretch"] = clampf(1.0 - absf(vel.y) / 700.0, 0.0, 1.0) * 0.4 + 0.6
			p["jaw"] = 0.6 if state == "pounce" else 0.2
			p["tuck"] = 1.0 if vel.y < 0.0 else 0.0
		"land":
			p["crouch"] = 0.6
		"swipe":
			p["crouch"] = 0.3
			p["paw"] = 1.0 if timer > 0.15 else -1.0     # raised, then raking down
			p["jaw"] = 0.7
		"cower":
			p["cower"] = 1.0
		"dazed":
			p["cower"] = 0.7
		"flinch":
			p["cower"] = 0.6
			p["head_up"] = 0.4
		"roar", "intro":
			var k := 1.0 - clampf(timer / 1.5, 0.0, 1.0)
			p["head_up"] = 1.0
			p["jaw"] = 0.25 if timer > 1.0 else 1.0
			p["crouch"] = 0.3 if timer > 1.0 else 0.0
			p["rump"] = -0.4 * k
		"distracted":
			p["head_up"] = 0.6
			p["jaw"] = 0.8
		"to_brazier":
			p["crouch"] = 0.2 * moving
		"swat":
			p["paw"] = 1.0 if timer > 0.45 else -1.0
			p["head_up"] = 0.3
			p["jaw"] = 0.5
		"vanish", "eyes":
			p["crouch"] = 0.6
		"climb", "meteor":
			p["stretch"] = 1.0
			p["jaw"] = 0.9
			p["tuck"] = 1.0 if vel.y < 0.0 else 0.0
		"perch":
			p["head_up"] = 1.0
			p["jaw"] = 1.0 if timer < 1.2 else 0.3
		"scrape":
			p["crouch"] = 0.7
			p["gait"] = 0.8
			p["jaw"] = 0.5
		"charge":
			p["gallop"] = 1.0
			p["crouch"] = 0.2
			p["jaw"] = 0.5
		"beaten":
			if not _down:
				p["stretch"] = 0.5
				p["cower"] = 0.5
			elif _beat_t < 1.9:
				p["down"] = 1.0
			elif _beat_t < 2.4:
				p["down"] = 1.0 - (_beat_t - 1.9) / 0.5
				p["cower"] = 0.6
			elif _beat_t < 3.9:
				p["head_up"] = 1.0
				p["jaw"] = 0.85 + sin(t * 30.0) * 0.1
			else:
				p["limp"] = 1.0
				p["cower"] = 0.3
	if _land > 0.0:
		p["crouch"] = maxf(float(p["crouch"]), _land / 0.18 * 0.8)
	return p


func _draw() -> void:
	if not visible:
		return
	var f := float(dir)
	var p := _pose()
	var b := Batch.new()
	var fur := Color("b58d58")
	var fur_dark := Color("7a5a36")
	var fur_deep := Color("5b4127")
	var belly := Color("e2d0a6")
	var shade := fur.darkened(0.18)

	var crouch: float = p["crouch"]
	var rump: float = p["rump"]
	var stretch: float = p["stretch"]
	var cower: float = p["cower"]
	var down: float = p["down"]
	var breath := sin(t * 2.2) * 1.5
	var bob := 0.0
	if float(p["gallop"]) > 0.0:
		bob = sin(_phase_walk / 30.0) * 8.0
	elif float(p["gait"]) > 0.0:
		bob = sin(_phase_walk / SIZE / 110.0 * TAU * 2.0) * 2.0 * float(p["gait"])

	# the skeleton
	# a stocky, heavy build: short back, deep chest, a hump of muscle at the shoulders
	var hip := Vector2(-46.0 - stretch * 16.0 + float(p["wiggle"]) * 5.0, -62.0 + crouch * 14.0 - rump * 16.0 + cower * 18.0 + bob * 0.6 + down * 30.0)
	var shoulder := Vector2(40.0 + stretch * 16.0, -80.0 + crouch * 30.0 + cower * 22.0 - bob * 0.4 + down * 42.0 + breath * 0.3)
	if float(p["gallop"]) > 0.0:
		# the spine bunching and stretching in the gallop
		var g := sin(_phase_walk / 30.0)
		hip.x += g * 12.0
		shoulder.x -= g * 10.0
	var mid := (hip + shoulder) * 0.5 + Vector2(0, -8.0 + crouch * 6.0 - cower * 4.0)

	# far legs first, in shadow
	_legs(b, hip, shoulder, p, -1.0, fur_dark)
	# the tail: a short, thick bobtail that lags and swings
	var ta := -2.6 + _tail - stretch * 0.4 + cower * 0.9
	var t1 := hip + Vector2(-10, -4)
	var t2 := t1 + Vector2.from_angle(ta) * 22.0
	var t3 := t2 + Vector2.from_angle(ta + _tail * 0.6) * 16.0
	_tapered(b, t1, t2, 13.0, 10.0, fur_dark)
	_tapered(b, t2, t3, 10.0, 6.0, fur_deep)
	# the body: a thick shape along the bent spine, with a deep chest
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i in 13:
		var k := i / 12.0
		var c := hip.lerp(mid, k).lerp(mid.lerp(shoulder, k), k)
		var thick := lerpf(46.0, 38.0, sin(k * PI * 0.9)) if k < 0.7 else lerpf(42.0, 60.0, (k - 0.7) / 0.3)
		thick += breath * k
		top.append(c + Vector2(0, -thick * 0.55))
		bottom.append(c + Vector2(0, thick * 0.45))
	var body := PackedVector2Array(top)
	for i in range(bottom.size() - 1, -1, -1):
		body.append(bottom[i])
	b.circle(hip + Vector2(-6, -4), 28.0, fur, 18)
	b.poly(body, fur)
	b.circle(shoulder + Vector2(2, 2), 34.0, fur, 20)
	b.circle(shoulder + Vector2(-8, -18), 20.0, fur, 14)     # the shoulder hump
	# the belly, pale underneath
	var under := PackedVector2Array()
	for i in range(3, 12):
		under.append(bottom[i] + Vector2(0, -4))
	for i in range(11, 2, -1):
		under.append(bottom[i] + Vector2(0, -12))
	b.poly(under, belly)
	# stripes down the back, and a darker saddle
	for i in 6:
		var k := 0.18 + i * 0.12
		var at: Vector2 = top[int(k * 12.0)]
		b.poly(PackedVector2Array([at + Vector2(-5, 1), at + Vector2(4, 0), at + Vector2(1, 18 - i), at + Vector2(-3, 16 - i)]), fur_dark)
	b.polyline(PackedVector2Array([top[2], top[5], top[8], top[11]]), shade, 5.0)
	# near legs
	_legs(b, hip, shoulder, p, 1.0, fur)
	# the head: level and steady while the body moves (a hunter's head)
	var neck := shoulder + Vector2(18, -10 + cower * 10.0)
	var head_ang := -float(p["head_up"]) * 0.75 + cower * 0.5 + crouch * 0.12 + down * 0.35
	var head := neck + Vector2(26, -6).rotated(head_ang) + Vector2(stretch * 10.0, 0)
	_tapered(b, shoulder + Vector2(4, -6), head + Vector2(-8, 4), 34.0, 26.0, fur)
	_head(b, head, head_ang, float(p["jaw"]), cower, fur, fur_dark, belly)

	if flash > 0.0:
		b.circle(Vector2(-6, -60), 72.0, Color(1, 1, 1, 0.45 * flash / 0.14), 20)
	draw_set_transform(Vector2.ZERO, rotation * 0.0, Vector2(f * SIZE, SIZE))
	b.draw(self)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A limb or neck: a quad tapering from one width to another.
func _tapered(b: Batch, a: Vector2, c: Vector2, w0: float, w1: float, col: Color) -> void:
	var d := c - a
	if d.length() < 0.5:
		return
	var n := Vector2(-d.y, d.x).normalized()
	b.quad(a + n * w0 * 0.5, c + n * w1 * 0.5, c - n * w1 * 0.5, a - n * w0 * 0.5, col)
	b.circle(c, w1 * 0.5, col, 10)


## Solves a two-bone limb from `a` to `c` with bone lengths l1, l2, and
## returns the middle joint — on the forward side of the line if `forward`,
## otherwise behind it. (Front elbows point back; hind knees point forward.)
func _joint(a: Vector2, c: Vector2, l1: float, l2: float, forward: bool) -> Vector2:
	var d := c - a
	var dist := clampf(d.length(), 1.0, l1 + l2 - 0.5)
	var dir := d.normalized()
	var ang := acos(clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0))
	var j1 := a + dir.rotated(ang) * l1
	var j2 := a + dir.rotated(-ang) * l1
	if forward:
		return j1 if j1.x > j2.x else j2
	return j1 if j1.x < j2.x else j2


## Where a paw is in its step. `u` runs 0..1 through one step: planted and
## sliding back under the body for the stance part (moving back exactly as far
## as the body moves forward, so it never skids), then lifted and swung
## forward in an arc.
func _step(anchor_x: float, u: float, stride: float, stance: float, lift: float) -> Vector2:
	if u < stance:
		return Vector2(anchor_x + stride * 0.5 - (u / stance) * stride, 0.0)
	var k := (u - stance) / (1.0 - stance)
	return Vector2(anchor_x - stride * 0.5 + k * stride, -sin(k * PI) * lift)


func _paw(b: Batch, at: Vector2, tilt: float, col: Color) -> void:
	var r := func(v: Vector2) -> Vector2: return at + v.rotated(tilt)
	b.poly(PackedVector2Array([r.call(Vector2(-8, -5)), r.call(Vector2(9, -6)), r.call(Vector2(16, 0)), r.call(Vector2(-9, 1))]), col.darkened(0.12))
	for k in 3:
		b.circle(r.call(Vector2(6 + k * 3.8, 0)), 2.5, col.darkened(0.3), 6)


## One front leg: shoulder -> elbow (bent back) -> wrist -> paw.
func _front_leg(b: Batch, sh: Vector2, paw: Vector2, swinging: bool, col: Color) -> void:
	var wrist := paw + (Vector2(-9, -10) if swinging else Vector2(-2, -13))
	var elbow := _joint(sh, wrist, 31.0, 31.0, false)
	_tapered(b, sh, elbow, 30.0, 22.0, col)
	_tapered(b, elbow, wrist, 22.0, 15.0, col)
	_tapered(b, wrist, paw + Vector2(2, -4), 15.0, 13.0, col)
	_paw(b, paw, -0.7 if swinging else 0.0, col)


## One hind leg: hip -> knee (forward) -> hock (high, behind) -> paw: the long
## zig-zag of a big cat's back leg.
func _hind_leg(b: Batch, hip: Vector2, paw: Vector2, swinging: bool, col: Color) -> void:
	var hock := paw + (Vector2(-20, -24) if swinging else Vector2(-15, -30))
	var knee := _joint(hip, hock, 34.0, 32.0, true)
	_tapered(b, hip, knee, 36.0, 24.0, col)
	_tapered(b, knee, hock, 22.0, 14.0, col)
	_tapered(b, hock, paw + Vector2(2, -4), 14.0, 12.0, col)
	_paw(b, paw, -0.6 if swinging else 0.0, col)


## Both legs on one side. The walk is a four-beat walk — one paw at a time,
## back then front on one side, then the other — with every planted paw
## staying put on the ground while the body travels over it.
func _legs(b: Batch, hip: Vector2, shoulder: Vector2, p: Dictionary, side: float, col: Color) -> void:
	var s := side * 4.0
	var gait: float = p["gait"]
	var gallop: float = p["gallop"]
	var stretch: float = p["stretch"]
	var tuck: float = p["tuck"]
	var down: float = p["down"]
	var sh := shoulder + Vector2(6 + s, 22)
	var hp := hip + Vector2(-2 + s, 12)
	var front_anchor := sh.x + 8.0
	var hind_anchor := hp.x - 4.0
	var fpaw := Vector2(front_anchor, 0.0)
	var hpaw := Vector2(hind_anchor, 0.0)
	var fswing := false
	var hswing := false
	var dist := _phase_walk / SIZE
	if gallop > 0.0:
		# the gallop: the back legs drive together, then the front legs reach
		var cyc := dist / 200.0
		var uf := fmod(cyc + (0.5 if side > 0.0 else 0.58), 1.0)
		var uh := fmod(cyc + (0.0 if side > 0.0 else 0.08), 1.0)
		fpaw = _step(front_anchor + 10.0, uf, 80.0, 0.4, 30.0)
		hpaw = _step(hind_anchor - 6.0, uh, 84.0, 0.4, 26.0)
		fswing = uf >= 0.4
		hswing = uh >= 0.4
	elif gait > 0.02:
		# the walk: lateral sequence — hind, fore, hind, fore
		var cyc := dist / 110.0
		var uh := fmod(cyc + (0.0 if side > 0.0 else 0.5), 1.0)
		var uf := fmod(cyc + (0.25 if side > 0.0 else 0.75), 1.0)
		var stride := 70.4     # exactly how far the body moves while a paw is down: no skidding
		fpaw = _step(front_anchor, uf, stride, 0.64, 16.0)
		hpaw = _step(hind_anchor, uh, stride, 0.64, 14.0)
		fswing = uf >= 0.64
		hswing = uh >= 0.64
	if stretch > 0.0:
		fpaw = sh + (Vector2(20, 24) if tuck > 0.0 else Vector2(46, 26))
		hpaw = hp + (Vector2(-4, 28) if tuck > 0.0 else Vector2(-54, 22))
		fswing = true
		hswing = true
	if float(p["paw"]) != 0.0 and side > 0.0:
		fpaw = sh + (Vector2(22, -48) if float(p["paw"]) > 0.0 else Vector2(64, 20))
		fswing = true
	if float(p["limp"]) > 0.0 and side > 0.0:
		# the hurt paw held up off the ground
		fpaw = sh + Vector2(16, 26)
		fswing = true
	if down > 0.0:
		fpaw = fpaw.lerp(sh + Vector2(34.0 * side, 16), down)
		hpaw = hpaw.lerp(hp + Vector2(-38.0 * side, 16), down)
	_hind_leg(b, hp, hpaw, hswing, col)
	_front_leg(b, sh, fpaw, fswing, col)


## The head: a heavy skull, the long sabres, the scar, the jaw that drops.
func _head(b: Batch, at: Vector2, ang: float, jaw: float, cower: float, fur: Color, fur_dark: Color, belly: Color) -> void:
	var r := func(v: Vector2) -> Vector2: return at + v.rotated(ang)
	# ears: pinned back when he's afraid
	var ear := -cower * 10.0
	b.poly(PackedVector2Array([r.call(Vector2(-10, -20)), r.call(Vector2(-4 + ear, -34 - ear * 0.2)), r.call(Vector2(4, -20))]), fur_dark)
	# lower jaw first, so the skull sits over its hinge
	var hinge := Vector2(0, 8)
	var jang := jaw * 0.7
	var jw := func(v: Vector2) -> Vector2: return at + (hinge + (v - hinge).rotated(jang)).rotated(ang)
	b.poly(PackedVector2Array([jw.call(Vector2(-2, 8)), jw.call(Vector2(34, 10)), jw.call(Vector2(30, 20)), jw.call(Vector2(4, 20))]), belly.darkened(0.08))
	if jaw > 0.1:
		b.poly(PackedVector2Array([r.call(Vector2(2, 8)), r.call(Vector2(36, 8)), jw.call(Vector2(34, 10)), jw.call(Vector2(4, 10))]), Pal.MAW)
		for k in 3:
			var lt: Vector2 = jw.call(Vector2(12 + k * 7, 11))
			b.tri(lt, lt + Vector2(3, 0).rotated(ang + jang), lt + Vector2(1.5, -5).rotated(ang + jang), Pal.TOOTH)
	# skull and muzzle
	var skull := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		skull.append(r.call(Vector2(4, -4) + Vector2(cos(a) * 22.0, sin(a) * 17.0)))
	b.poly(skull, fur)
	var muzzle := PackedVector2Array([r.call(Vector2(12, -12)), r.call(Vector2(36, -8)), r.call(Vector2(44, 0)), r.call(Vector2(40, 9)),
		r.call(Vector2(14, 10))])
	b.poly(muzzle, fur)
	b.poly(PackedVector2Array([r.call(Vector2(18, 2)), r.call(Vector2(42, 2)), r.call(Vector2(40, 9)), r.call(Vector2(16, 10))]), belly)
	b.circle(r.call(Vector2(43, -2)), 4.0, Pal.OUTLINE, 8)
	# the sabres: one long and curved, one snapped off short (and gone, once it has flown)
	var fang_gone := state == "beaten" and _down
	if not fang_gone:
		b.poly(PackedVector2Array([r.call(Vector2(24, 7)), r.call(Vector2(31, 7)), r.call(Vector2(30, 26)), r.call(Vector2(26, 44))]), Pal.TOOTH)
	else:
		b.poly(PackedVector2Array([r.call(Vector2(24, 7)), r.call(Vector2(31, 7)), r.call(Vector2(29, 13)), r.call(Vector2(25, 13))]), Pal.TOOTH)
	b.poly(PackedVector2Array([r.call(Vector2(14, 8)), r.call(Vector2(20, 8)), r.call(Vector2(19, 17)), r.call(Vector2(15, 16))]), Pal.TOOTH)
	# brow, eye and the old scar across it
	b.poly(PackedVector2Array([r.call(Vector2(8, -16)), r.call(Vector2(26, -14)), r.call(Vector2(24, -9)), r.call(Vector2(8, -10))]), fur_dark)
	var eye: Vector2 = r.call(Vector2(18, -7))
	b.circle(eye, 3.8, Pal.OUTLINE, 10)
	_eye_at = eye
	b.line(r.call(Vector2(10, -20)), r.call(Vector2(28, 2)), belly.lightened(0.25), 3.0)
	# whisker pads
	for k in 3:
		b.circle(r.call(Vector2(34 + k * 3, 4 + (k % 2) * 2)), 1.2, fur_dark, 6)


## Big amber eyes that burn through the dark, flaring in the tell.
func draw_glow(g: Node2D) -> void:
	if not visible or state == "wait":
		return
	var e := global_position + Vector2(float(dir) * _eye_at.x, _eye_at.y) * SIZE
	var flare := 1.0 if state in ["crouch", "scrape", "lurk_in", "perch"] else 0.0
	var dim := 0.35 if state in ["cower", "dazed"] or (state == "beaten" and _down and _beat_t < 2.4) else 1.0
	g.draw_circle(e, 12.0 + flare * 10.0, Color(Pal.WOLF_EYE, (0.2 + flare * 0.3) * dim))
	g.draw_circle(e, 4.0 + flare * 1.5, Color(Pal.WOLF_EYE, 0.95 * dim))
	# the far eye, just showing
	g.draw_circle(e + Vector2(-float(dir) * 10.0, 1.0), 3.0 + flare, Color(Pal.WOLF_EYE, 0.6 * dim))


## The roar made visible: a ring of air rolling out from his jaws.
class ShockRing extends Node2D:
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		if t > 0.6:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := t / 0.6
		for i in 3:
			var r := 30.0 + k * 420.0 - i * 40.0
			if r > 10.0:
				draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.9, 0.95, 1.0, (0.45 - i * 0.12) * (1.0 - k)), 5.0 - i, true)


## The other pair of eyes in the eye trick: just a glint in the dark — or is it?
class DecoyEyes extends Node2D:
	var t := 0.0
	var facing := 1

	func _ready() -> void:
		add_to_group("glow")

	func _process(delta: float) -> void:
		t += delta
		if t > 3.0:
			queue_free()

	func draw_glow(g: Node2D) -> void:
		var blink := 0.1 if fmod(t, 1.1) < 0.12 else 1.0
		var a := clampf(t / 0.3, 0.0, 1.0)
		g.draw_circle(global_position, 12.0, Color(Pal.WOLF_EYE, 0.2 * a))
		g.draw_colored_polygon(PackedVector2Array([global_position + Vector2(-5, 0), global_position + Vector2(0, -4 * blink),
			global_position + Vector2(5, 0), global_position + Vector2(0, 4 * blink)]), Color(Pal.WOLF_EYE, 0.95 * a))
		var e2 := global_position + Vector2(-float(facing) * 10.0, 1.0)
		g.draw_colored_polygon(PackedVector2Array([e2 + Vector2(-4, 0), e2 + Vector2(0, -3 * blink), e2 + Vector2(4, 0), e2 + Vector2(0, 3 * blink)]),
			Color(Pal.WOLF_EYE, 0.7 * a))


## The shadow of the meteor: a dark patch on the ground that grows, and follows
## the man, until the sabre-tooth comes down on it.
class MeteorMark extends Node2D:
	var t := 0.0

	func _ready() -> void:
		z_index = 3

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var k := clampf(t / 1.6, 0.0, 1.0)
		var pts := PackedVector2Array()
		for i in 20:
			var a := TAU * i / 20.0
			pts.append(Vector2(cos(a) * (40.0 + 90.0 * k), -3.0 + sin(a) * (8.0 + 12.0 * k)))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.25 + 0.35 * k))
		draw_arc(Vector2(0, -3), 40.0 + 90.0 * k, 0.0, TAU, 32, Color(Pal.EMBER_GLOW, 0.5 * k), 2.0)
