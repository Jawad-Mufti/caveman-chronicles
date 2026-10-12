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
## PAINTED, AFTER THE REAL ANIMAL (2026-10-12, after paleoart references):
## Smilodon fatalis was bear-heavy and front-heavy, with huge forelimbs, high
## shoulders over short hind legs, a short bobtail, a thick neck, a short broad
## muzzle and deep cheekbones; the slender sabres hang below the chin even with
## the mouth shut. His coat is a plain tawny (a cat of open country), darker
## down the back, pale underneath, with the faintest dapples low on the flank.
## Painted like an illustration, not a cartoon: soft form shading from the
## moon above (each mass a gradient, round masses shaded like balls), muscle
## masses picked out in light and shadow, shadow pockets (under the chin,
## behind the elbow, along the belly), fur strokes that follow the form at the
## silhouette (longer at the throat and nape), a thin cool moon rim, a cat's
## dark tear-line from the eye down the muzzle. A thin rim in a darker tone of
## each part (the game's rule: no black outlines) keeps him readable.
const FUR := Color("b98652")
const FUR_LIT := Color("d9aa70")
const FUR_DARK := Color("7a5634")
const BACK := Color("8a6038")
const BELLY := Color("eadab4")
const SKIN := Color("2a1a12")
const MOON := Color(0.8, 0.9, 1.0, 0.5)
const RIM := 1.6                   ## the rim's width (design px)
const HEAD := 1.15

var _rim_pass := false             ## drawing the rims (every part a little bigger, darker), then the fills
var _far := false                  ## drawing the far legs (in shadow)
var _moon_pts := PackedVector2Array()   ## his moonlit outline (design units): drawn on the glow layer too
var _sab_pts := PackedVector2Array()    ## the sabre (design units): its gleam in the dark


func _col(c: Color) -> Color:
	if _far:
		c = c.darkened(0.3)
	return c.darkened(0.55) if _rim_pass else c


## Lit from above: a colour for a point, by how high it is between y0 (top) and y1.
func _tone(top: Color, bottom: Color, y: float, y0: float, y1: float) -> Color:
	return _col(top.lerp(bottom, clampf((y - y0) / maxf(y1 - y0, 1.0), 0.0, 1.0)))


## A shape shaded from `top` (its highest point) to `bottom` (its lowest).
func _soft(b: Batch, pts: PackedVector2Array, top: Color, bottom: Color) -> void:
	if _rim_pass:
		_part(b, pts, top)
		return
	var y0 := INF
	var y1 := -INF
	for q in pts:
		y0 = minf(y0, q.y)
		y1 = maxf(y1, q.y)
	var cols := PackedColorArray()
	for q in pts:
		cols.append(_tone(top, bottom, q.y, y0, y1))
	b.draw_polygon(pts, cols)


## A round mass shaded like a ball lit from above: light at the top, the core
## shadow underneath, a little bounce light at the very bottom.
func _ball(b: Batch, at: Vector2, r: Vector2, lit: Color, dark: Color, segs := 18) -> void:
	if _rim_pass:
		b.ellipse(at, r.x + RIM, r.y + RIM, _col(dark), 0.0, segs)
		return
	var mid := _col(lit.lerp(dark, 0.35))
	var prev := Vector2.ZERO
	var prev_c := Color.BLACK
	for i in segs + 1:
		var a := TAU * i / segs
		var p := at + Vector2(cos(a) * r.x, sin(a) * r.y)
		var k := (sin(a) + 1.0) * 0.5                           # 0 top .. 1 bottom
		var c := _col(lit.lerp(dark, smoothstep(0.1, 0.85, k)))
		if k > 0.92:
			c = c.lightened(0.06)                               # bounce light from the ground
		if i > 0:
			b.tri_cols(at + Vector2(0, -r.y * 0.25), prev, p, mid, prev_c, c)
		prev = p
		prev_c = c


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


## A tuft of fur: a thin tapering stroke from `root` along `dir`.
func _stroke(b: Batch, root: Vector2, dir: Vector2, w: float, col: Color) -> void:
	var n := Vector2(-dir.y, dir.x).normalized() * w * 0.5
	b.tri(root + n, root - n, root + dir, col)


func _draw() -> void:
	if not visible:
		return
	var b := Batch.new()
	var p := _pose()
	# his shadow on the ground (it stays on the ground when he leaps)
	var gy := (cur_floor - position.y) / SIZE
	var lift := clampf(-gy / 300.0, 0.0, 1.0)
	b.ellipse(Vector2(0, gy - 2.0), 92.0 * (1.0 - lift * 0.4), 9.0 * (1.0 - lift * 0.4), Color(0, 0, 0, 0.28 * (1.0 - lift * 0.6)), 0.0, 20)
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
	var fur := FUR.lerp(Color("e8b88a"), 0.3 * recoil)        # a brief warm flush when hit
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
	var hip := Vector2(-40.0 - stretch * 16.0 + float(p["wiggle"]) * 5.0, -54.0 + crouch * 12.0 - rump * 18.0 + cower * 16.0 + bob * 0.6 + down * 26.0)
	var shoulder := Vector2(40.0 + stretch * 16.0, -88.0 + crouch * 32.0 + cower * 24.0 - bob * 0.4 + down * 46.0 + breath * 0.3)
	if float(p["gallop"]) > 0.0:
		var g := sin(_phase_walk / 30.0)
		hip.x += g * 12.0
		shoulder.x -= g * 10.0
	shoulder.x -= 10.0 * recoil
	hip.x -= 4.0 * recoil
	var mid := (hip + shoulder) * 0.5 + Vector2(0, -8.0 + crouch * 6.0 - cower * 4.0)

	# the far legs, in shadow
	_far = true
	_legs(b, hip, shoulder, p, -1.0, fur)
	_far = false
	# the tail: a short thick bobtail, darker to its tip
	var ta := -2.6 + _tail - stretch * 0.4 + cower * 0.9
	var t1 := hip + Vector2(-12, -6)
	var t2 := t1 + Vector2.from_angle(ta) * 14.0
	var t3 := t2 + Vector2.from_angle(ta + _tail * 0.6) * 9.0
	_tapered(b, t1, t2, 15.0, 12.0, fur)
	_tapered(b, t2, t3, 12.0, 8.0, BACK)
	# the trunk along the bent spine: lean at the loins, a deep chest
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i in 13:
		var k := i / 12.0
		var c := hip.lerp(mid, k).lerp(mid.lerp(shoulder, k), k)
		var thick := lerpf(46.0, 34.0, sin(k * PI * 0.9)) if k < 0.7 else lerpf(38.0, 62.0, (k - 0.7) / 0.3)
		thick += breath * k
		top.append(c + Vector2(0, -thick * 0.55))
		bottom.append(c + Vector2(0, thick * 0.45))
	var body := PackedVector2Array(top)
	for i in range(bottom.size() - 1, -1, -1):
		body.append(bottom[i])
	var haunch := hip + Vector2(-6, -4)
	var hump := shoulder + Vector2(-8, -20)
	_ball(b, haunch, Vector2(29, 28), FUR_LIT, FUR_DARK)
	_soft(b, body, fur, FUR_DARK)
	_ball(b, shoulder + Vector2(2, 2), Vector2(35, 35), fur.lerp(FUR_LIT, 0.4), FUR_DARK)
	_ball(b, hump, Vector2(27, 24), FUR_LIT, fur)
	if not _rim_pass:
		# the darker coat down his back (soft-edged: shaded into the flank)
		var cols := PackedColorArray()
		var back := PackedVector2Array()
		for i in 13:
			back.append(top[i] + Vector2(0, 1))
			cols.append(Color(BACK, 0.85))
		for i in range(12, -1, -1):
			back.append(top[i].lerp(bottom[i], 0.3))
			cols.append(Color(BACK, 0.0))
		b.draw_polygon(back, cols)
		b.ellipse(hump + Vector2(0, -8), 22.0, 13.0, Color(BACK, 0.55), 0.0, 14)
		b.ellipse(haunch + Vector2(0, -12), 22.0, 12.0, Color(BACK, 0.5), 0.0, 14)
		# the pale belly and chest, shaded in (the belly's lowest line darker: a shadow pocket)
		var under := PackedVector2Array()
		var ucols := PackedColorArray()
		for i in range(4, 13):
			under.append(bottom[i] + Vector2(0, -2))
			ucols.append(BELLY.darkened(0.22))
		for i in range(12, 3, -1):
			under.append(top[i].lerp(bottom[i], lerpf(0.86, 0.6, (i - 4) / 8.0)))
			ucols.append(Color(BELLY, 0.0))
		b.draw_polygon(under, ucols)
		# muscle: the light catching the shoulder blade and the thigh; the shadow
		# behind the triceps and under the haunch
		b.ellipse(hump + Vector2(-2, -4), 16.0, 9.0, Color(FUR_LIT.lightened(0.12), 0.3), -0.5, 12)
		b.ellipse(shoulder + Vector2(-16, 18), 12.0, 22.0, Color(FUR_DARK, 0.45), 0.25, 12)
		b.ellipse(haunch + Vector2(4, -6), 15.0, 10.0, Color(FUR_LIT.lightened(0.1), 0.25), 0.4, 12)
		b.ellipse(haunch + Vector2(10, 18), 16.0, 8.0, Color(FUR_DARK, 0.5), -0.2, 12)
		# the faintest dapples, low on the flank
		for i in 7:
			var k2 := 0.18 + (i % 4) * 0.14
			var row := 0.55 + (i / 4) * 0.14
			var at: Vector2 = top[int(k2 * 12.0)].lerp(bottom[int(k2 * 12.0)], row)
			b.circle(at + Vector2(sin(i * 2.3) * 4.0, 0), 2.6, Color(FUR_DARK, 0.28), 8)
		# the pale marks of old fights across the shoulder
		for k3 in 3:
			var sc := shoulder + Vector2(-20 + k3 * 7.0, -4 + k3 * 3.0)
			b.line(sc, sc + Vector2(15, 11), Color("d9b89a"), 1.8)
		# fur: strokes along the back (raised hackles in his rage), under the belly
		_stripe_pts.clear()
		var hackle := 2.2 if phase == 4 and state != "beaten" else 1.0
		for i in range(2, 12):
			var r: Vector2 = top[i]
			var along: Vector2 = (top[i + 1] - top[i - 1]).normalized()
			var up := Vector2(along.y, -along.x)
			if up.y > 0.0:
				up = -up
			var len := (5.0 + (i % 3) * 2.0) * (hackle if i > 6 else 1.0)
			var d := (up * 0.6 - along * 0.8).normalized() * len
			_stroke(b, r + up * 1.0, d, 4.0, BACK.darkened(0.1))
			if hackle > 1.0 and i > 6:
				_stripe_pts.append([r + Vector2(-2, 0), r + Vector2(2, 0), r + d])
		for i in range(4, 12, 2):
			_stroke(b, bottom[i] + Vector2(0, -2), Vector2(-4, 7), 4.0, BELLY.darkened(0.18))
		# the moon on his back: a thin cool edge along his outline
		var moon := PackedVector2Array()
		for k5 in 6:
			moon.append(haunch + Vector2.from_angle(lerpf(-2.5, -1.35, k5 / 5.0)) * 28.5)
		for i in range(3, 8):
			moon.append(top[i] + Vector2(0, 1.0))
		for k6 in 7:
			moon.append(hump + Vector2.from_angle(lerpf(-2.6, -1.0, k6 / 6.0)) * 23.5)
		b.polyline(moon, MOON, 1.6)
		_moon_pts = moon
	# the near legs
	_legs(b, hip, shoulder, p, 1.0, fur)
	# the neck: thick, a mane of longer fur at the throat
	var neck := shoulder + Vector2(14, -6 + cower * 10.0)
	var head_ang := -float(p["head_up"]) * 0.75 + cower * 0.5 + crouch * 0.12 + down * 0.35 - 0.45 * recoil
	var head := neck + Vector2(24, -4).rotated(head_ang) + Vector2(stretch * 10.0, 0)
	_tapered(b, shoulder + Vector2(0, -8), head + Vector2(-8, 6), 54.0, 42.0, fur)
	if not _rim_pass:
		for k4 in 6:
			var q := k4 / 5.0
			var root := (shoulder + Vector2(18, 16)).lerp(head + Vector2(-6, 20), q)
			_stroke(b, root, Vector2(-3 - q * 2.0, 10.0 + (k4 % 2) * 4.0).rotated(head_ang * 0.5), 6.0, BELLY.darkened(0.12))
		# the shadow pocket under the jaw, on the neck
		b.ellipse(head + Vector2(-6, 18).rotated(head_ang), 16.0, 7.0, Color(FUR_DARK, 0.45), head_ang, 12)
	_head(b, head, head_ang, float(p["jaw"]), cower, fur)


## A limb or neck: a quad tapering from one width to another, its upper side
## lit and its under side in shade.
func _tapered(b: Batch, a: Vector2, c: Vector2, w0: float, w1: float, col: Color) -> void:
	var d := c - a
	if d.length() < 0.5:
		return
	var grow := RIM * 2.0 if _rim_pass else 0.0
	var n := Vector2(-d.y, d.x).normalized()
	var up_side := n if n.y < 0.0 else -n
	var lit := _col(col.lerp(FUR_LIT, 0.35))
	var shade := _col(col.lerp(FUR_DARK, 0.55))
	if _rim_pass:
		lit = _col(col)
		shade = lit
	var p1 := a + up_side * (w0 + grow) * 0.5
	var p2 := c + up_side * (w1 + grow) * 0.5
	var p3 := c - up_side * (w1 + grow) * 0.5
	var p4 := a - up_side * (w0 + grow) * 0.5
	b.quad(p1, p2, p3, p4, lit, PackedColorArray([lit, lit, shade, shade]))
	var mid_c := lit.lerp(shade, 0.5)
	b.circle(c, (w1 + grow) * 0.5, mid_c, 10)


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




## A paw: broad, the toes picked out, a dark gap between them; claws out when it swings.
func _paw(b: Batch, at: Vector2, tilt: float, col: Color, big: float = 1.0, claws := false) -> void:
	var r := func(v: Vector2) -> Vector2: return at + (v * big).rotated(tilt)
	_soft(b, PackedVector2Array([r.call(Vector2(-8, -8)), r.call(Vector2(8, -9)), r.call(Vector2(17, -2)), r.call(Vector2(17, 1)), r.call(Vector2(-9, 1))]),
		col.lerp(FUR_LIT, 0.2), col.lerp(FUR_DARK, 0.6))
	if _rim_pass:
		return
	for k in 3:
		var g: Vector2 = r.call(Vector2(7 + k * 3.6, -4))
		b.line(g, g + Vector2(0.6, 4.5).rotated(tilt), _col(FUR_DARK.darkened(0.3)), 1.1)
	if claws:
		for k2 in 4:
			var c: Vector2 = r.call(Vector2(5 + k2 * 3.8, 1))
			b.tri(c + Vector2(-1.4, 0), c + Vector2(1.4, 0), c + Vector2(3.0, 7.0).rotated(tilt), Color("efe6d0"))


## One front leg: the great forearm of a cat that held its prey down.
func _front_leg(b: Batch, sh: Vector2, paw: Vector2, swinging: bool, col: Color) -> void:
	var wrist := paw + (Vector2(-9, -10) if swinging else Vector2(-2, -13))
	var elbow := _joint(sh, wrist, 34.0, 27.0, false)
	_tapered(b, sh, elbow, 44.0, 30.0, col)
	_tapered(b, elbow, wrist, 31.0, 21.0, col)
	_tapered(b, wrist, paw + Vector2(2, -4), 21.0, 17.0, col)
	if not _rim_pass and not _far:
		# the forearm's muscle catching the light; the shadow behind the elbow
		var mid_arm := elbow.lerp(wrist, 0.35)
		b.ellipse(mid_arm + Vector2(4, -2), 7.0, 11.0, Color(FUR_LIT, 0.35), 0.3, 10)
		b.circle(elbow + Vector2(-6, 2), 7.0, Color(FUR_DARK, 0.45), 10)
	_paw(b, paw, -0.7 if swinging else 0.0, col, 1.45, swinging)


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


## The head, after the Smilodon skull: a long low cranium with a crest, deep
## cheekbones, a short broad muzzle, a lion's nose; small rounded ears set back
## (the near one torn); an amber eye under a heavy brow, a cat's dark tear-line
## from its corner down the muzzle, pale around the eye and on the muzzle; the
## deep lower jaw with its bony flange, dropping to ~110 degrees in a roar; the
## sabres long, slender and curved, hanging below the chin even with the mouth
## shut (one snapped short). The old scar runs across his eye, healed pale.
func _head(b: Batch, at: Vector2, ang: float, jaw: float, cower: float, fur: Color) -> void:
	var r := func(v: Vector2) -> Vector2: return at + (v * HEAD).rotated(ang)
	# the ear: small, rounded, set back; pinned flat when he's afraid
	var ear := -cower * 7.0
	_soft(b, PackedVector2Array([r.call(Vector2(-16, -14)), r.call(Vector2(-18 + ear, -27)), r.call(Vector2(-10 + ear, -31)), r.call(Vector2(-3, -21))]), BACK, FUR_DARK)
	if not _rim_pass:
		b.poly(PackedVector2Array([r.call(Vector2(-13, -17)), r.call(Vector2(-14 + ear, -25)), r.call(Vector2(-9 + ear, -27)), r.call(Vector2(-6, -20))]), Color("4a2e1e"))
		b.tri(r.call(Vector2(-12 + ear, -29)), r.call(Vector2(-8 + ear, -31)), r.call(Vector2(-10 + ear, -26)), Color(0.09, 0.11, 0.2))   # the tear
	# the lower jaw first, so the skull sits over its hinge
	var hinge := Vector2(-4, 10)
	var jang := jaw * 1.9
	var jw := func(v: Vector2) -> Vector2: return at + ((hinge + (v - hinge).rotated(jang)) * HEAD).rotated(ang)
	_soft(b, PackedVector2Array([jw.call(Vector2(-8, 8)), jw.call(Vector2(28, 11)), jw.call(Vector2(33, 14)), jw.call(Vector2(31, 24)),
		jw.call(Vector2(24, 30)), jw.call(Vector2(18, 24)), jw.call(Vector2(0, 21))]), BELLY.darkened(0.08), BELLY.darkened(0.35))
	if not _rim_pass and jaw > 0.1:
		b.poly(PackedVector2Array([r.call(Vector2(-2, 8)), r.call(Vector2(34, 8)), jw.call(Vector2(31, 11)), jw.call(Vector2(-2, 10))]), Pal.MAW)
		b.poly(PackedVector2Array([jw.call(Vector2(4, 12)), jw.call(Vector2(26, 12)), jw.call(Vector2(22, 16)), jw.call(Vector2(8, 16))]), Color("b25c66"))
		for k in 4:
			var lt: Vector2 = jw.call(Vector2(10 + k * 5, 11))
			b.tri(lt, lt + Vector2(3.0, 0).rotated(ang + jang), lt + Vector2(1.5, -5).rotated(ang + jang), Pal.TOOTH)
	# the skull: long and low, a crest along the top, the cheek deep
	var skull := PackedVector2Array([r.call(Vector2(-24, 2)), r.call(Vector2(-21, -12)), r.call(Vector2(-8, -21)), r.call(Vector2(8, -22)),
		r.call(Vector2(21, -17)), r.call(Vector2(29, -9)), r.call(Vector2(35, -5)), r.call(Vector2(38, 1)), r.call(Vector2(36, 8)),
		r.call(Vector2(26, 12)), r.call(Vector2(12, 14)), r.call(Vector2(-6, 14)), r.call(Vector2(-19, 10))])
	_soft(b, skull, fur.lerp(FUR_LIT, 0.3), fur.lerp(FUR_DARK, 0.5))
	# the sabres: slender, curved, hanging below the chin
	var fang_gone := state == "beaten" and _down
	if fang_gone:
		_sab_pts = PackedVector2Array()
		_part(b, PackedVector2Array([r.call(Vector2(22, 8)), r.call(Vector2(29, 8)), r.call(Vector2(28, 14)), r.call(Vector2(23, 14))]), Pal.TOOTH)
	else:
		var sab := PackedVector2Array([r.call(Vector2(21, 8)), r.call(Vector2(29, 8)), r.call(Vector2(30, 24)), r.call(Vector2(28, 40)),
			r.call(Vector2(24, 52)), r.call(Vector2(24, 38)), r.call(Vector2(23, 22))])
		if _rim_pass:
			_part(b, sab, Color("cfc2a0"))
		else:
			_sab_pts = sab
			var sc := PackedColorArray([Color("c9b88e"), Color("c9b88e"), Color("efe6cf"), Color("f6f0e0"), Color("fbf8ee"), Color("e6dcc2"), Color("d6c8a4")])
			b.draw_polygon(sab, sc)
			b.polyline(PackedVector2Array([r.call(Vector2(28, 12)), r.call(Vector2(28.5, 28)), r.call(Vector2(26.5, 42))]), Color(1, 1, 1, 0.75), 1.3)   # the gleam
	_part(b, PackedVector2Array([r.call(Vector2(12, 9)), r.call(Vector2(17, 9)), r.call(Vector2(16, 18)), r.call(Vector2(13, 17))]), Color("e6dcc2"))   # the broken one
	if _rim_pass:
		return
	# the forms of the face: the brow's shadow, the cheekbone lit, the muzzle pale
	b.ellipse(r.call(Vector2(4, 0)), 13.0 * HEAD, 7.0 * HEAD, Color(FUR_LIT.lightened(0.1), 0.45), ang + 0.2, 12)       # the cheekbone
	b.ellipse(r.call(Vector2(16, -13)), 12.0 * HEAD, 4.0 * HEAD, Color(FUR_DARK, 0.6), ang - 0.15, 10)                  # the brow's shadow
	b.poly(PackedVector2Array([r.call(Vector2(20, 0)), r.call(Vector2(30, -4)), r.call(Vector2(37, 1)), r.call(Vector2(35, 8)),
		r.call(Vector2(26, 11)), r.call(Vector2(18, 9))]), Color(BELLY, 0.9))                                         # the pale muzzle
	b.ellipse(r.call(Vector2(17, -5)), 8.0 * HEAD, 5.0 * HEAD, Color(BELLY, 0.5), ang, 10)                            # pale round the eye
	# the dark crest line and the faint forehead marks
	b.polyline(PackedVector2Array([r.call(Vector2(-18, -14)), r.call(Vector2(-6, -20)), r.call(Vector2(10, -19))]), Color(BACK.darkened(0.2), 0.8), 2.0)
	for k in 3:
		var fm: Vector2 = r.call(Vector2(2 + k * 4, -16))
		b.line(fm, fm + Vector2(-1, 5).rotated(ang), Color(FUR_DARK, 0.6), 1.2)
	# the nose: a lion's, dark leather
	b.poly(PackedVector2Array([r.call(Vector2(32, -5)), r.call(Vector2(38, -2)), r.call(Vector2(38, 2)), r.call(Vector2(34, 1))]), Color("3a2420"))
	b.line(r.call(Vector2(35, 2)), r.call(Vector2(34, 8)), Color("3a2420"), 1.2)
	# the eye: amber, a dark rim, a pupil (wide in the dark), a glint
	var eye: Vector2 = r.call(Vector2(17, -7))
	var open := 0.75 if cower < 0.5 else 0.3
	var eye_c := Color("ff3a26") if phase == 4 and state != "beaten" else Color("e8a030")
	b.ellipse(eye, 5.2 * HEAD, 5.2 * HEAD * open + 0.9, SKIN, ang, 12)
	b.ellipse(eye, 4.6 * HEAD, 4.6 * HEAD * open, eye_c, ang, 12)
	b.ellipse(eye + Vector2(0.6, 0).rotated(ang), 1.6 * HEAD, 3.6 * HEAD * open, Color("120a06"), ang, 8)
	b.circle(eye + Vector2(-1.4, -1.6).rotated(ang), 1.1, Color(1, 1, 1, 0.9), 6)
	_eye_at = eye
	# the tear-line: dark, from the eye's front corner down the muzzle
	b.polyline(PackedVector2Array([r.call(Vector2(23, -4)), r.call(Vector2(25, 2)), r.call(Vector2(26, 8))]), Color(SKIN, 0.7), 1.6)
	# the old scar: healed pale, across the eye
	b.polyline(PackedVector2Array([r.call(Vector2(10, -20)), r.call(Vector2(16, -11)), r.call(Vector2(22, -3)), r.call(Vector2(27, 5))]), Color("dcc0a8"), 2.0)
	# whisker spots and whiskers
	for k2 in 6:
		b.circle(r.call(Vector2(27 + (k2 % 3) * 3.0, 3 + (k2 / 3) * 3)), 0.8, Color(SKIN, 0.6), 5)
	for k3 in 4:
		var w: Vector2 = r.call(Vector2(30, 3 + k3 * 2))
		b.line(w, w + Vector2(17, -5 + k3 * 3.5).rotated(ang), Color(1, 1, 1, 0.45), 0.8)


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
