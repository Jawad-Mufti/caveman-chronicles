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
## THE SIEGE (at half health). He leaps up onto his lair rock, out of reach,
##   and howls — and the night answers: first TWO wolves, then THREE, then
##   FOUR bats bursting out of his cave, each wave once the last is beaten.
##   Only then does he come crashing down on the man — and lands dazed.
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
signal siege_wave(n: int)
signal howled                   ## a siege howl: calls the pack, but brings no rocks down
signal countered(kind: String)  ## the man found a weak spot: "parry", "fang", "dodge" (the level tells him, once)

const MAX_HP := 120
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
var _siege := 0                 ## which wave of the siege is out (0: none yet, 4: over)
var _hit_t := 0.0               ## > 0 just after a blow lands: the recoil
var _hit_dir := 1
var arena: Node = null          ## the clearing (level2/scar_arena.gd): clouds, the fallen tree, burning branches
var _branch_cd := 3.0
var _fang_cd := 0.0
var _stripe_pts: Array = []     ## the stripes (design units): in his rage they glow like embers


func _setup() -> void:
	sleeps_far = false               # the boss of the Long Dark acts whether or not he is seen
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
	_siege = 0
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
	if state in ["wait", "lurk_in", "emerge", "intro", "beaten", "siege_climb", "siege"]:
		return
	_hurt(dmg, 1 if global_position.x > from.x else -1)
	if hp > 0:
		state = "cower"
		timer = 3.0
		vel = Vector2(signf(global_position.x - from.x) * 200.0, -220.0)


func take_hit(dmg: int, from_dir: int) -> void:
	if state in ["wait", "lurk_in", "emerge", "intro", "beaten", "siege_climb", "siege"]:
		return
	var open := state in ["cower", "dazed", "distracted", "swat", "staggered", "stumble"]
	var ranged := player != null and absf(player.global_position.x - position.x) > 170.0
	var facing_him := player != null and signf(player.global_position.x - position.x) == float(dir)
	# PARRY: a blow to his paw while it's raised for a swipe, from in front
	if state == "swipe" and timer > 0.15 and not ranged and facing_him:
		_hurt(dmg, from_dir)
		if hp > 0:
			_counter("parry", "PARRY!")
			state = "staggered"
			timer = 1.4
			vel = Vector2(-float(dir) * 220.0, -160.0)
			Critter.slow_time(get_tree(), 0.35, 0.35)
		return
	# THE BROKEN FANG: a rock from afar, square in his face, cracks on the stump
	if ranged and facing_him and _fang_cd <= 0.0 and not open and state not in ["roar", "rage_roar", "pounce", "vault", "leap", "meteor", "climb"]:
		_fang_cd = 5.0
		_hurt(dmg * 3, from_dir)
		if hp > 0:
			_counter("fang", "CRACK!")
			state = "flinch"
			timer = 0.9
			vel = Vector2(float(from_dir) * 160.0, -140.0)
		return
	# a rock (from further off than any club could reach) into his roaring jaws
	if state == "roar" and ranged:
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
	if state in ["wait", "lurk_in", "emerge", "intro", "beaten", "perch", "meteor", "climb", "siege_climb", "siege"]:
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


## A blow lands: no big flash — a quick recoil (head snapped back, body
## jolted, ears flat, tail lashing), tufts of fur flying from the spot, a
## brief warm tint, and a "GRRAH!" when it's a hit during an opening.
func _hurt(amount: int, from_dir: int) -> void:
	hp -= amount
	_hit_t = 0.3
	_hit_dir = from_dir
	flash = 0.1                  # a light flash of the whole silhouette (a shader)
	FX.burst(get_parent(), global_position + Vector2(-float(from_dir) * 30.0, -80.0) * SIZE, "sparks", -float(from_dir))
	_tail_v += 18.0 * float(from_dir)
	var at := global_position + Vector2(-float(from_dir) * 30.0, -80.0) * SIZE
	var tufts := FurTufts.new()
	tufts.position = at
	tufts.dir = float(from_dir)
	get_parent().add_child(tufts)
	if state in ["cower", "dazed", "distracted", "swat"] and hp > 0:
		var word := CaveMan.WordPop.new()
		word.text = ["GRRAH!", "RRAWR!", "HRRNGH!"][randi() % 3]
		word.position = global_position + Vector2(-40, -190)
		get_parent().add_child(word)
	if hp <= 0:
		hp = 0
		_defeat(from_dir)
		return
	if phase == 1 and ratio() <= 0.5:
		phase = 2
		phase_changed.emit(2)
		_begin_siege()
	elif phase == 2 and ratio() <= 0.25:
		phase = 3
		phase_changed.emit(3)
		_begin_roar()
		if arena != null:
			arena.fell_tree()                       # his roar brings the dead tree down
	elif phase == 3 and ratio() <= 0.12:
		phase = 4
		phase_changed.emit(4)
		_begin_rage()


## A weak spot found: the word, a flash of sparks, and the level's tip (once).
func _counter(kind: String, word_text: String) -> void:
	var word := CaveMan.WordPop.new()
	word.text = word_text
	word.position = global_position + Vector2(-50, -220)
	get_parent().add_child(word)
	FX.burst(get_parent(), global_position + Vector2(float(dir) * 90.0, -100.0) * SIZE, "sparks", float(dir))
	countered.emit(kind)


## PHASE 4, RAGE: up on his hind legs, the last-stand roar: the clearing
## flashes red, the roar throws the man back, burning branches crash down.
## From now on: red eyes, his stripes glowing like embers, faster, combos.
func _begin_rage() -> void:
	state = "rage_roar"
	timer = 2.0
	vx = 0.0
	vel = Vector2.ZERO
	_roar_hit = false
	flash = 0.3
	_branch_cd = 4.0
	_meteor_cd = 4.0


## ----------------------------------------------------------------- thinking
func _tick(delta: float) -> void:
	t += delta
	timer -= delta
	cd -= delta
	roar_cd -= delta
	swipe_cd -= delta
	_meteor_cd -= delta
	_land = maxf(_land - delta, 0.0)
	_hit_t = maxf(_hit_t - delta, 0.0)
	_fang_cd -= delta
	# his rage: burning branches torn down onto the man, every few seconds
	if phase == 4 and arena != null and player != null and state not in ["beaten", "wait", "rage_roar"]:
		_branch_cd -= delta
		if _branch_cd <= 0.0:
			_branch_cd = 5.5
			arena.drop_branch(player.global_position.x + randf_range(-50.0, 50.0))
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
		"rage_roar":
			vx = 0.0
			dir = 1 if dx > 0.0 else -1
			if timer <= 1.3 and not _roar_hit:
				_roar_hit = true
				roared.emit()
				_shockwave(true)
				if arena != null:
					arena.rage()
					for k in 3:
						arena.drop_branch(player.global_position.x + (k - 1) * 230.0)
				var lv := get_parent()
				if lv.has_method("shake"):
					lv.shake(16.0, 0.9)
			if timer <= 0.0:
				state = "prowl"
				cd = 0.8
		"staggered", "stumble":
			_settle(delta)
			if timer <= 0.0:
				state = "prowl"
				cd = 0.9
				swipe_cd = maxf(swipe_cd, 0.6)
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
			vx = move_toward(vx, dir * CHARGE * (1.15 if phase == 4 else 1.0), 1500.0 * delta)
			position.x += vx * delta
			_phase_walk += absf(vx) * delta
			_trail_dust(delta)
			# the fallen tree: he runs blind, right into it
			var stop: float = arena.log_stop(position.x, vx) if arena != null else INF
			if stop != INF:
				position.x = stop
				arena.log_hit()
				_crash()
				_counter("log", "WHAM!")
			elif position.x <= arena_l + 80.0 or position.x >= arena_r - 80.0:
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
			damage = 2
			_fly(delta)
		"siege_climb":
			damage = 0
			_fly(delta)
		"siege":
			vx = 0.0
			damage = 0
			dir = 1 if player.global_position.x > position.x else -1
			if timer <= -3.5:
				timer = 1.2
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
	if phase >= 3 and _meteor_cd <= 0.0 and cd <= 0.0:
		_meteor_cd = 12.0 if phase == 3 else 8.0
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
		if phase >= 2 and roll > (0.45 if arena != null and arena.is_dark() else 0.75):      # (the moon behind clouds: he loves the dark)
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
		if phase >= 3 and roll < 0.45:
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
			timer = [0.75, 0.55, 0.4, 0.32][phase - 1]
			_double = phase >= 3 and randf() < (0.6 if phase == 3 else 0.8)
			return
	# otherwise: prowl at the edge of the light
	var tx := _edge_target()
	_prowl_to(tx, PROWL * (1.35 if phase == 4 else 1.0), delta)
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
		elif phase == 4:
			# his rage: swipe, swipe, and straight into a pounce
			state = "crouch"
			timer = 0.22
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
	cd = [2.6, 2.0, 1.5, 1.1][phase - 1]


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
				timer = [1.3, 1.1, 0.9, 0.8][phase - 1]
				vel = Vector2(-dir * 260.0, -220.0)
				cur_floor = floor_y
				damage = 0
				_double = false
				return
	if vel.y > 0.0:
		var surface := floor_y
		var may_perch := not (state == "pounce" and _from_ledge) and state != "meteor"
		if state == "climb" or state == "siege_climb":
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
			if state == "siege_climb":
				state = "siege"
				timer = 1.2
				_siege = 1
				howled.emit()
				_shockwave(false)
				siege_wave.emit(1)
				return
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
			elif state == "pounce" and not resolved and player.global_position.distance_to(position) < 190.0 * SIZE:
				# CLOSE ONE: the man slipped it at the last moment (over him, or
				# just aside): time slows; he lands off balance, open
				_counter("dodge", "CLOSE ONE!")
				Critter.slow_time(get_tree(), 0.6, 0.3)
				state = "stumble"
				timer = 1.1
				_double = false
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


## ------------------------------------------------------------------- siege
## Half his health gone: up onto his rock, to call the night down on the man.
func _begin_siege() -> void:
	state = "siege_climb"
	_siege = 0
	_rock_top = floor_y - 292.0
	flash = 0.3
	_launch(Vector2(lair_x + 10.0, _rock_top), 0.8)


## The level has beaten a wave: the next one, or down he comes.
func next_wave() -> void:
	if state != "siege":
		return
	if _siege < 3:
		_siege += 1
		timer = 1.2
		howled.emit()
		_shockwave(false)
		siege_wave.emit(_siege)
	else:
		# all of them beaten: he rears up on his rock — a shadow grows under the
		# man and follows him, as fair a warning as the meteor gives — then down
		_siege = 4
		state = "perch"
		timer = 1.6
		howled.emit()
		_shockwave(false)
		_mark = MeteorMark.new()
		_mark.position = Vector2(player.global_position.x, floor_y)
		get_parent().add_child(_mark)
		roar_cd = 4.0


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
		"gait": 0.0, "gallop": 0.0, "wiggle": 0.0, "paw": 0.0, "tuck": 0.0, "down": 0.0, "limp": 0.0, "recoil": 0.0}
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
		"staggered":
			p["cower"] = 0.8
			p["head_up"] = 0.35
			p["jaw"] = 0.5
		"stumble":
			p["crouch"] = 0.55
			p["cower"] = 0.3
			p["jaw"] = 0.4
		"rage_roar":
			# up on his hind legs, head thrown back, jaws wide
			p["head_up"] = 1.0
			p["jaw"] = 0.3 if timer > 1.3 else 1.0
			p["rump"] = -1.0
			p["stretch"] = 0.3
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
		"siege_climb":
			p["stretch"] = 1.0
			p["jaw"] = 0.6
			p["tuck"] = 1.0 if vel.y < 0.0 else 0.0
		"siege":
			# howling to the night, then watching the fight below, head low
			p["head_up"] = 1.0 if timer > 0.0 else 0.0
			p["jaw"] = 1.0 if timer > 0.0 else 0.15
			p["crouch"] = 0.0 if timer > 0.0 else 0.35
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
	if _hit_t > 0.0:
		var k := sin(_hit_t / 0.3 * PI)
		p["cower"] = maxf(float(p["cower"]), 0.35 * k)
		p["jaw"] = maxf(float(p["jaw"]), 0.45 * k)
		p["recoil"] = k
	return p


## ------------------------------------------------------------------ his look
## Designed for the read (2026-10-12): a front-heavy, forward-leaning wedge
## of a predator, the danger in triangles (a spiky ruff round his neck and
## shoulders, tufts at the elbows, chin and tail, swept-back ears, the great
## curved sabres), his face the focal point (a big wedge of a head, an angry
## brow, a burning amber eye with a slit pupil, the scar). Three tones of fur
## (a dark saddle down his back, a warm orange flank, a pale belly) with bold
## tapering stripes; every part rimmed in a darker tone of its own fill (no
## black outlines: the game's rule) so he never melts into one blob; and a
## cool moonlit edge along his back that lifts him out of the Long Dark.
const FUR := Color("c98a4a")
const FUR_FAR := Color("9a6436")
const SADDLE := Color("6b4426")
const STRIPE := Color("4a2a16")
const BELLY := Color("f0dcb0")
const RUFF := Color("e8c890")
const MOON := Color(0.78, 0.88, 1.0, 0.6)
const RIM := 3.2                   ## the rim's width (design px)
const HEAD := 1.25                 ## his head, bigger than life: the focal point

var _rim_pass := false             ## drawing the rims (every part a little bigger, darker), then the fills
var _moon_pts := PackedVector2Array()   ## his moonlit outline (design units): drawn on the glow layer too
var _sab_pts := PackedVector2Array()    ## the sabre (design units): its gleam in the dark


## A part's colour: itself, or (the rim pass) a darker tone of it.
func _col(c: Color) -> Color:
	return c.darkened(0.55) if _rim_pass else c


func _circ(b: Batch, at: Vector2, r: float, c: Color, segs := 12) -> void:
	b.circle(at, r + (RIM if _rim_pass else 0.0), _col(c), segs)


## A shape; in the rim pass pushed out from its middle by the rim's width.
func _part(b: Batch, pts: PackedVector2Array, c: Color) -> void:
	if _rim_pass:
		var mid := Vector2.ZERO
		for p in pts:
			mid += p
		mid /= pts.size()
		var big := PackedVector2Array()
		for p in pts:
			big.append(p + (p - mid).normalized() * RIM)
		pts = big
	b.poly(pts, _col(c))


func _tri3(b: Batch, a: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	if _rim_pass:
		var mid := (a + c + d) / 3.0
		a += (a - mid).normalized() * RIM
		c += (c - mid).normalized() * RIM
		d += (d - mid).normalized() * RIM
	b.tri(a, c, d, _col(col))


func _draw() -> void:
	if not visible:
		return
	var b := Batch.new()
	var p := _pose()
	for pass_ in 2:
		_rim_pass = pass_ == 0
		_paint_body(b, p)
	_rim_pass = false
	if flash > 0.2:
		b.circle(Vector2(-6, -60), 72.0, Color(1, 1, 1, 0.18 * clampf(flash / 0.3, 0.0, 1.0)), 20)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(float(dir) * SIZE, SIZE))
	b.draw(self)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _paint_body(b: Batch, p: Dictionary) -> void:
	var recoil: float = p["recoil"]
	var fur := FUR.lerp(Color("f0c090"), 0.35 * recoil)        # a brief warm flash when hit
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
	# the skeleton, built like a real Smilodon: bear-heavy and front-heavy, the
	# shoulders held high over short hind legs, the back sloping down to the hips
	var hip := Vector2(-40.0 - stretch * 16.0 + float(p["wiggle"]) * 5.0, -54.0 + crouch * 12.0 - rump * 18.0 + cower * 16.0 + bob * 0.6 + down * 26.0)
	var shoulder := Vector2(40.0 + stretch * 16.0, -90.0 + crouch * 32.0 + cower * 24.0 - bob * 0.4 + down * 46.0 + breath * 0.3)
	if float(p["gallop"]) > 0.0:
		var g := sin(_phase_walk / 30.0)
		hip.x += g * 12.0
		shoulder.x -= g * 10.0
	shoulder.x -= 10.0 * recoil
	hip.x -= 4.0 * recoil
	var mid := (hip + shoulder) * 0.5 + Vector2(0, -8.0 + crouch * 6.0 - cower * 4.0)

	# far legs first, darker
	_legs(b, hip, shoulder, p, -1.0, FUR_FAR)
	# the tail: a short thick bobtail that lags and swings, a dark tuft at its tip
	var ta := -2.6 + _tail - stretch * 0.4 + cower * 0.9
	var t1 := hip + Vector2(-10, -4)
	var t2 := t1 + Vector2.from_angle(ta) * 14.0
	var t3 := t2 + Vector2.from_angle(ta + _tail * 0.6) * 10.0
	_tapered(b, t1, t2, 15.0, 11.0, fur)
	_tapered(b, t2, t3, 11.0, 7.0, SADDLE)
	_tri3(b, t3 + Vector2.from_angle(ta + 1.4) * 5.0, t3 + Vector2.from_angle(ta) * 11.0, t3 + Vector2.from_angle(ta - 1.4) * 5.0, STRIPE)
	# the body along the bent spine: lean at the waist, a deep chest
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i in 13:
		var k := i / 12.0
		var c := hip.lerp(mid, k).lerp(mid.lerp(shoulder, k), k)
		var thick := lerpf(44.0, 32.0, sin(k * PI * 0.9)) if k < 0.7 else lerpf(36.0, 62.0, (k - 0.7) / 0.3)
		thick += breath * k
		top.append(c + Vector2(0, -thick * 0.55))
		bottom.append(c + Vector2(0, thick * 0.45))
	var body := PackedVector2Array(top)
	for i in range(bottom.size() - 1, -1, -1):
		body.append(bottom[i])
	_circ(b, hip + Vector2(-6, -4), 27.0, fur, 18)
	_part(b, body, fur)
	_circ(b, shoulder + Vector2(2, 2), 35.0, fur, 20)
	_circ(b, shoulder + Vector2(-10, -24), 27.0, fur, 16)           # the great hump over the shoulder blades
	if not _rim_pass:
		# the dark saddle down his back
		_stripe_pts.clear()
		var saddle := PackedVector2Array()
		for i in 13:
			saddle.append(top[i] + Vector2(0, 2))
		for i in range(12, -1, -1):
			saddle.append(top[i].lerp(bottom[i], 0.4 if i < 9 else 0.3))
		b.poly(saddle, SADDLE)
		b.circle(shoulder + Vector2(-10, -30), 21.0, SADDLE, 14)
		# the pale belly underneath
		var under := PackedVector2Array()
		for i in range(4, 13):
			under.append(bottom[i] + Vector2(0, -2))
		for i in range(12, 3, -1):
			under.append(top[i].lerp(bottom[i], lerpf(0.9, 0.62, (i - 4) / 8.0)))     # (deeper at the chest)
		b.poly(under, BELLY)
		# bold stripes: tapering down from the saddle, longer over the shoulder
		for i in 7:
			var k := 1 + i * 1.5
			var a: Vector2 = top[int(k)].lerp(bottom[int(k)], 0.24)
			var len := 22.0 + (i % 3) * 6.0 + (8.0 if i >= 5 else 0.0)
			var lean := Vector2(-6.0, len)
			b.tri(a + Vector2(-4.5, 0), a + Vector2(4.5, 0), a + lean, STRIPE)
			_stripe_pts.append([a + Vector2(-4.5, 0), a + Vector2(4.5, 0), a + lean])
		# the haunch: the saddle over it, curved stripes round it
		var hc2 := hip + Vector2(-6, -4)
		b.circle(hc2 + Vector2(2, -12), 17.0, SADDLE, 12)
		for k7 in 3:
			var ha := -2.2 + k7 * 0.5
			var hs := hc2 + Vector2.from_angle(ha) * 22.0
			b.tri(hs + Vector2.from_angle(ha + PI * 0.5) * 4.0, hs - Vector2.from_angle(ha + PI * 0.5) * 4.0, hc2 + Vector2.from_angle(ha + 0.35) * 4.0, STRIPE)
		for k2 in 3:
			var sa := shoulder + Vector2(-34 + k2 * 10.0, -36 + k2 * 4.0)
			b.tri(sa + Vector2(-4, 0), sa + Vector2(4, 0), sa + Vector2(-8, 26), STRIPE)
			_stripe_pts.append([sa + Vector2(-4, 0), sa + Vector2(4, 0), sa + Vector2(-8, 26)])
		# the pale marks of old fights across the shoulder
		for k3 in 3:
			var sc := shoulder + Vector2(-20 + k3 * 7.0, -6 + k3 * 3.0)
			b.line(sc, sc + Vector2(16, 12), Color("f2d8c8"), 2.4)
		# the moon on his back: a cool edge along the top of him
		# (along his outline: the round of the haunch, the back, the round of the hump)
		var moon := PackedVector2Array()
		var hc := hip + Vector2(-6, -4)
		for k5 in 6:
			moon.append(hc + Vector2.from_angle(lerpf(-2.5, -1.35, k5 / 5.0)) * 25.5)
		for i in range(3, 8):
			moon.append(top[i] + Vector2(0, 1.5))
		var hump := shoulder + Vector2(-10, -24)
		for k6 in 7:
			moon.append(hump + Vector2.from_angle(lerpf(-2.6, -1.0, k6 / 6.0)) * 25.5)
		b.polyline(moon, MOON, 2.6)
		_moon_pts = moon                                 # (the glow layer draws it again, over the dark)
	# near legs
	_legs(b, hip, shoulder, p, 1.0, fur)
	# the neck, and the RUFF: a spiky collar of long fur round his neck
	var neck := shoulder + Vector2(14, -6 + cower * 10.0)
	var head_ang := -float(p["head_up"]) * 0.75 + cower * 0.5 + crouch * 0.12 + down * 0.35 - 0.45 * recoil
	var head := neck + Vector2(24, -4).rotated(head_ang) + Vector2(stretch * 10.0, 0)
	_tapered(b, shoulder + Vector2(0, -8), head + Vector2(-8, 6), 52.0, 40.0, fur)
	var ruff_c := shoulder + Vector2(18, 4).rotated(head_ang * 0.5)
	for k4 in 7:
		var a4 := -1.9 + k4 * 0.42 + head_ang * 0.5
		var base := ruff_c + Vector2.from_angle(a4) * 22.0
		var tip := ruff_c + Vector2.from_angle(a4 + 0.15) * (44.0 + (k4 % 2) * 8.0)
		var side := Vector2.from_angle(a4 + PI * 0.5) * 8.0
		_tri3(b, base + side, tip, base - side, RUFF if k4 % 2 == 0 else fur)
	_head(b, head, head_ang, float(p["jaw"]), cower, fur)


## A limb or neck: a quad tapering from one width to another.
func _tapered(b: Batch, a: Vector2, c: Vector2, w0: float, w1: float, col: Color) -> void:
	var d := c - a
	if d.length() < 0.5:
		return
	var grow := RIM * 2.0 if _rim_pass else 0.0
	var n := Vector2(-d.y, d.x).normalized()
	b.quad(a + n * (w0 + grow) * 0.5, c + n * (w1 + grow) * 0.5, c - n * (w1 + grow) * 0.5, a - n * (w0 + grow) * 0.5, _col(col))
	b.circle(c, (w1 + grow) * 0.5, _col(col), 10)


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




## A paw: a broad pad, four toes, and (claws out) four hooked claws.
func _paw(b: Batch, at: Vector2, tilt: float, col: Color, big: float = 1.0, claws := false) -> void:
	var r := func(v: Vector2) -> Vector2: return at + (v * big).rotated(tilt)
	_part(b, PackedVector2Array([r.call(Vector2(-8, -7)), r.call(Vector2(9, -8)), r.call(Vector2(18, 0)), r.call(Vector2(-9, 1))]), col.darkened(0.08))
	if _rim_pass:
		return
	for k in 4:
		b.circle(r.call(Vector2(4 + k * 3.8, 0)), 2.6 * big, col.darkened(0.3), 6)
		if claws:
			var c: Vector2 = r.call(Vector2(5 + k * 3.8, 1))
			b.tri(c + Vector2(-1.6, 0), c + Vector2(1.6, 0), c + Vector2(3.0, 7.0).rotated(tilt), Color("f3ead6"))


## One front leg: shoulder -> elbow (bent back) -> wrist -> paw; a spiky tuft
## of fur at the elbow.
func _front_leg(b: Batch, sh: Vector2, paw: Vector2, swinging: bool, col: Color) -> void:
	var wrist := paw + (Vector2(-9, -10) if swinging else Vector2(-2, -13))
	var elbow := _joint(sh, wrist, 34.0, 27.0, false)
	_tapered(b, sh, elbow, 42.0, 30.0, col)
	_tapered(b, elbow, wrist, 30.0, 21.0, col)
	_tapered(b, wrist, paw + Vector2(2, -4), 21.0, 17.0, col)
	var away := (elbow - (sh + wrist) * 0.5).normalized()
	_tri3(b, elbow + away.rotated(1.4) * 9.0, elbow + away * 22.0, elbow + away.rotated(-1.4) * 9.0, col)
	_paw(b, paw, -0.7 if swinging else 0.0, col, 1.5, swinging)


## One hind leg: hip -> knee (forward) -> hock (high, behind) -> paw.
func _hind_leg(b: Batch, hip: Vector2, paw: Vector2, swinging: bool, col: Color) -> void:
	var hock := paw + (Vector2(-17, -20) if swinging else Vector2(-13, -25))
	var knee := _joint(hip, hock, 30.0, 27.0, true)
	_tapered(b, hip, knee, 40.0, 25.0, col)
	_tapered(b, knee, hock, 23.0, 15.0, col)
	_tapered(b, hock, paw + Vector2(2, -4), 15.0, 12.0, col)
	_paw(b, paw, -0.6 if swinging else 0.0, col, 1.15)


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




## The head: a big wedge (HEAD times life size), after the real Smilodon skull
## but pushed for the read: a heavy brow in an angry wedge over a burning amber
## eye with a slit pupil, swept-back pointed ears (the near one torn), a short
## broad muzzle gone grey, a dark nose; the deep lower jaw that drops to ~110
## degrees in a roar; and the SABRES, long curved crescents with a gleam, one
## snapped off short. The old scar runs across the eye.
func _head(b: Batch, at: Vector2, ang: float, jaw: float, cower: float, fur: Color) -> void:
	var r := func(v: Vector2) -> Vector2: return at + (v * HEAD).rotated(ang)
	# ears: pointed, swept back (pinned flat when he's afraid); the near one notched
	var ear := -cower * 8.0
	_tri3(b, r.call(Vector2(-16, -14)), r.call(Vector2(-22 + ear, -34)), r.call(Vector2(-2, -20)), SADDLE)
	if not _rim_pass:
		b.tri(r.call(Vector2(-14, -18)), r.call(Vector2(-19 + ear, -30)), r.call(Vector2(-6, -21)), Color("3a2418"))
		b.tri(r.call(Vector2(-12 + ear * 0.5, -27)), r.call(Vector2(-8 + ear * 0.5, -30)), r.call(Vector2(-9 + ear * 0.5, -24)), Color("16203a"))   # the tear
	# the lower jaw first, so the skull sits over its hinge
	var hinge := Vector2(-2, 10)
	var jang := jaw * 1.9
	var jw := func(v: Vector2) -> Vector2: return at + ((hinge + (v - hinge).rotated(jang)) * HEAD).rotated(ang)
	_part(b, PackedVector2Array([jw.call(Vector2(-4, 8)), jw.call(Vector2(32, 10)), jw.call(Vector2(34, 16)), jw.call(Vector2(30, 30)),
		jw.call(Vector2(22, 33)), jw.call(Vector2(18, 23)), jw.call(Vector2(2, 22))]), BELLY.darkened(0.15))
	if not _rim_pass:
		_tri3(b, jw.call(Vector2(14, 24)), jw.call(Vector2(10, 34)), jw.call(Vector2(22, 26)), BELLY.darkened(0.1))   # the chin tuft
		if jaw > 0.1:
			b.poly(PackedVector2Array([r.call(Vector2(0, 8)), r.call(Vector2(38, 8)), jw.call(Vector2(34, 10)), jw.call(Vector2(0, 10))]), Pal.MAW)
			b.poly(PackedVector2Array([jw.call(Vector2(4, 11)), jw.call(Vector2(28, 11)), jw.call(Vector2(24, 15)), jw.call(Vector2(8, 15))]), Color("c96a74"))
			for k in 4:
				var lt: Vector2 = jw.call(Vector2(10 + k * 6, 11))
				b.tri(lt, lt + Vector2(3.5, 0).rotated(ang + jang), lt + Vector2(1.7, -6).rotated(ang + jang), Pal.TOOTH)
	# the skull: a broad wedge, a crest along the top
	_part(b, PackedVector2Array([r.call(Vector2(-22, -2)), r.call(Vector2(-16, -18)), r.call(Vector2(-2, -24)), r.call(Vector2(16, -20)),
		r.call(Vector2(30, -12)), r.call(Vector2(30, 8)), r.call(Vector2(4, 14)), r.call(Vector2(-16, 12))]), fur)
	# the muzzle, short and broad, gone grey; the dark nose
	_part(b, PackedVector2Array([r.call(Vector2(12, -12)), r.call(Vector2(32, -10)), r.call(Vector2(42, -2)), r.call(Vector2(40, 9)),
		r.call(Vector2(14, 10))]), fur)
	# the sabres: long curved crescents (one snapped off short, gone once it flew)
	var fang_gone := state == "beaten" and _down
	if fang_gone:
		_sab_pts = PackedVector2Array()
	var sab_len := 1.0 if not fang_gone else 0.0
	if sab_len > 0.0:
		var sab := PackedVector2Array([r.call(Vector2(21, 7)), r.call(Vector2(31, 7)), r.call(Vector2(32, 26)), r.call(Vector2(29, 44)),
			r.call(Vector2(24, 58)), r.call(Vector2(25, 42)), r.call(Vector2(24, 24))])
		_part(b, sab, Pal.TOOTH)
		if not _rim_pass:
			_sab_pts = sab
			b.polyline(PackedVector2Array([r.call(Vector2(29, 10)), r.call(Vector2(29.5, 28)), r.call(Vector2(27, 44))]), Color(1, 1, 1, 0.8), 1.6)   # the gleam
			for k in 5:
				var q: Vector2 = r.call(Vector2(24.5, 16 + k * 7))
				b.line(q, q + Vector2(-1.8, 0.4).rotated(ang), Color("c9bfa6"), 1.0)
	else:
		_part(b, PackedVector2Array([r.call(Vector2(21, 7)), r.call(Vector2(31, 7)), r.call(Vector2(30, 14)), r.call(Vector2(22, 14))]), Pal.TOOTH)
	_part(b, PackedVector2Array([r.call(Vector2(11, 8)), r.call(Vector2(18, 8)), r.call(Vector2(17, 20)), r.call(Vector2(12, 18))]), Pal.TOOTH)   # the broken one
	if _rim_pass:
		return
	b.poly(PackedVector2Array([r.call(Vector2(17, 3)), r.call(Vector2(26, -1)), r.call(Vector2(36, -1)), r.call(Vector2(42, 3)),
		r.call(Vector2(40, 9)), r.call(Vector2(28, 11)), r.call(Vector2(17, 9))]), BELLY)                 # the grey muzzle, rounded
	for k in 6:
		b.circle(r.call(Vector2(22 + (k % 3) * 6, -3 + (k / 3) * 5)), 1.4, Color("8a7a66"), 6)
	b.tri(r.call(Vector2(36, -8)), r.call(Vector2(44, -6)), r.call(Vector2(41, 1)), Color("2a1810"))      # the nose
	# the stripes on his brow, and the dark saddle over the crest
	b.poly(PackedVector2Array([r.call(Vector2(-16, -17)), r.call(Vector2(-2, -23)), r.call(Vector2(14, -19)), r.call(Vector2(4, -14)), r.call(Vector2(-12, -11))]), SADDLE)
	for k in 3:
		var sp: Vector2 = r.call(Vector2(-10 + k * 6, -14))
		b.tri(sp, sp + Vector2(4, 0).rotated(ang), sp + Vector2(-2, 10).rotated(ang), STRIPE)
	# the eye: a burning amber eye with a slit pupil, under an angry brow wedge
	var eye: Vector2 = r.call(Vector2(19, -6))
	var big := 5.2 * HEAD
	var open := 0.85 if cower < 0.5 else 0.35                # (afraid: he squeezes it shut)
	b.ellipse(eye, big * 1.2, big * open, (Color("ff3a26") if phase == 4 else Color("ffb02e")), ang, 10)
	b.ellipse(eye, big * 0.3, big * minf(open, 0.8), Color("1a0f08"), ang, 8)
	b.circle(eye + Vector2(-1.5, -1.5).rotated(ang), 1.4, Color.WHITE, 6)
	_eye_at = eye
	var brow := 4.0 * cower
	b.poly(PackedVector2Array([r.call(Vector2(4, -17 - brow)), r.call(Vector2(30, -9 + brow * 0.3)), r.call(Vector2(28, -4)), r.call(Vector2(8, -9 - brow))]), STRIPE)
	# the old scar across the eye: pink, ragged
	b.polyline(PackedVector2Array([r.call(Vector2(8, -22)), r.call(Vector2(16, -12)), r.call(Vector2(22, -4)), r.call(Vector2(30, 6))]), Color("f2b8a8"), 3.4)
	for k in 3:
		var st: Vector2 = r.call(Vector2(12 + k * 7, -17 + k * 8))
		b.line(st + Vector2(-3, -2).rotated(ang), st + Vector2(3, 2).rotated(ang), Color("d88a7a"), 1.4)
	# whiskers
	for k in 3:
		var w: Vector2 = r.call(Vector2(34, 2 + k * 3))
		b.line(w, w + Vector2(16, -4 + k * 4).rotated(ang), Color(1, 1, 1, 0.55), 1.0)


## Big amber eyes that burn through the dark, flaring in the tell.
func draw_glow(g) -> void:   # g: the glow layer's Batch
	if not visible or state == "wait":
		return
	var e := global_position + Vector2(float(dir) * _eye_at.x, _eye_at.y) * SIZE
	var flare := 1.0 if state in ["crouch", "scrape", "lurk_in", "perch", "siege", "rage_roar"] else 0.0
	var dim := 0.35 if state in ["cower", "dazed", "staggered"] or (state == "beaten" and _down and _beat_t < 2.4) else 1.0
	var eye_c := Color("ff3a26") if phase == 4 and state != "beaten" else Pal.WOLF_EYE      # (his rage: red)
	g.draw_circle(e, 12.0 + flare * 10.0, Color(eye_c, (0.2 + flare * 0.3) * dim))
	g.draw_circle(e, 4.0 + flare * 1.5, Color(eye_c, 0.95 * dim))
	# the far eye, just showing
	g.draw_circle(e + Vector2(-float(dir) * 10.0, 1.0), 3.0 + flare, Color(eye_c, 0.6 * dim))
	var at0 := func(v: Vector2) -> Vector2: return global_position + Vector2(float(dir) * v.x, v.y) * SIZE
	# his rage: the stripes glow like embers, pulsing
	if phase == 4 and state != "beaten" and modulate.a > 0.5:
		var pulse := 0.45 + 0.25 * sin(t * 7.0)
		for s in _stripe_pts:
			g.draw_colored_polygon(PackedVector2Array([at0.call(s[0]), at0.call(s[1]), at0.call(s[2])]), Color(Pal.EMBER_GLOW, pulse))
	# his moonlit outline and the gleam of his sabre, over the dark (not when he
	# melts into it for the eye trick, nor in the dark of his lair)
	if state in ["vanish", "eyes", "lurk_in"] or modulate.a < 0.5:
		return
	var at := func(v: Vector2) -> Vector2: return global_position + Vector2(float(dir) * v.x, v.y) * SIZE
	var moon_a: float = 0.42 * (0.6 if dim < 1.0 else 1.0) * (1.0 - 0.85 * (arena.dark if arena != null else 0.0))      # (clouds over the moon: his outline goes)
	for i in range(_moon_pts.size() - 1):
		g.draw_line(at.call(_moon_pts[i]), at.call(_moon_pts[i + 1]), Color(0.8, 0.9, 1.0, moon_a), 3.0)
	if _sab_pts.size() >= 3:
		var sab := PackedVector2Array()
		for v in _sab_pts:
			sab.append(at.call(v))
		g.draw_colored_polygon(sab, Color(1.0, 0.97, 0.88, 0.5))


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

	func draw_glow(g) -> void:   # g: the glow layer's Batch
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


## Tufts of fur knocked loose by a blow: they fly off, tumble and fade.
class FurTufts extends Node2D:
	var dir := 1.0
	var t := 0.0
	var _bits: Array = []

	func _ready() -> void:
		for i in 7:
			_bits.append([Vector2(dir * randf_range(60, 220), randf_range(-260, -80)), randf_range(0, TAU), randf_range(-9, 9)])

	func _process(delta: float) -> void:
		t += delta
		if t > 0.7:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var a := 1.0 - t / 0.7
		for bit in _bits:
			var v: Vector2 = bit[0]
			var p := v * t + Vector2(0, 520.0 * t * t)
			var ang: float = bit[1] + bit[2] * t
			var tip := p + Vector2.from_angle(ang) * 9.0
			var side := Vector2.from_angle(ang + PI * 0.5) * 2.5
			draw_colored_polygon(PackedVector2Array([p + side, tip, p - side]), Color(0.78, 0.62, 0.4, a))
