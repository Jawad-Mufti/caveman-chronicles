class_name CaveMan
extends CharacterBody2D
## The caveman. He never changes across the game, only what he holds.
## Origin is at his feet. Drawn as a flat charcoal silhouette.

signal hp_changed(hp: int)
signal died
signal rock_picked
signal stick_picked
signal rocks_changed(count: int)
signal berries_changed(count: int)
signal poultice(ok: bool, note: String)
signal wood_changed(count: int)
signal torch_out
signal fire_released
signal said(note: String)

const SPEED := 300.0
## Ramped instead of snapped, so direction changes read as weight rather than teleporting.
const ACCEL := 2600.0
const FRICTION := 2800.0
const AIR_ACCEL := 1700.0
const THROW_SPEED := 640.0
## Bare hands reach barely past his own shoulder. The club roughly doubles the
## area he can threaten, which is the real reason to go and fetch it.
const FIST_BOX := Vector2(34, 56)
const FIST_REACH := 20.0
const CLUB_BOX := Vector2(62, 70)
const CLUB_REACH := 36.0
const JUMP := -640.0
## Asymmetric gravity: rise gently, fall fast. Removes the floaty feel.
const GRAVITY_UP := 1540.0
const GRAVITY_DOWN := 2280.0
const JUMP_CUT := 0.45        ## velocity kept when the jump key is released early
const COYOTE_TIME := 0.10     ## can still jump this long after walking off a ledge
const JUMP_BUFFER := 0.12     ## a jump press is remembered this long before landing
const STOMP_BOUNCE := -430.0  ## pop up after crushing something underfoot
const MAX_JUMPS := 2
const AIR_JUMP := -520.0      ## weaker than the ground jump: a recovery, not a free second jump
const SWING_TIME := 0.26
## Bare-handed he throws a one-two: a jab off the lead hand, then a cross off
## the rear. Two separate strikes inside a single press.
const PUNCH_TIME := 0.36
const LAND_TIME := 0.16
const STRIDE := 40.0      ## how far a foot swings either side of the hip, design units
## The torch (Level 2 on). Fuel runs 1 -> 0; the light's radius follows it down
## from TORCH_R_MAX to TORCH_R_MIN, then it is out. Half fuel is the line the
## wolves respect, so the meter's midpoint is the number that matters.
const TORCH_BURN := 50.0      ## seconds from full to out
const TORCH_R_MAX := 300.0
const TORCH_R_MIN := 120.0
## An ability is announced by ~1 s of visible anger. He is untouchable and
## rooted through all of it; the fire leaves at FURY_RELEASE, the rest is snarl.
const FURY_TIME := 1.0
const FURY_RELEASE := 0.6
const FIRE_COST := 2          ## bundles of wood burned by one fire
## Wind (the mountain). In the air it carries him; on the ground it only
## drifts him, and holding INTO it braces him to a slow walk.
const WIND_GROUND := 0.35
const BRACE_SPEED := 90.0

var hp := 5
var max_hp := 5
var has_stick := false
var rocks := 0
var max_rocks := 6
var throwing := 0.0
var berries := 0
var max_berries := 3
var facing := 1
var attacking := 0.0
var attack_cd := 0.0
var invuln := 0.0
var knock := 0.0
var anim_t := 0.0
var dead := false
var has_torch := false
var torch_fuel := 0.0
var wood := 0
var max_wood := 4
var costume := 1          ## 1 = leaves (Level 1), 2 = first hide loincloth (Level 2)
var fury := -1.0          ## seconds into the fire's wind-up; -1 when calm
var wind := 0.0           ## world px/s the air is pushing him; set by the level's Wind
var talking := false      ## in a conversation: stands still, can't be hurt, torch waits
## From upgrades and the gem forge (GameState puts these on him at level start).
var torch_burn := TORCH_BURN
var club_bonus := 0
## The Firestone Hammer (Level 2's forged weapon). Tap attack: a heavy blow.
## Hold attack: he raises it overhead and the gem burns brighter; let go and
## he SLAMS the ground, and a wave of fire rolls out both ways along it.
var hammer := false
const SLAM_READY := 0.5         ## how long the charge takes to be full
const SLAM_COOLDOWN := 1.3
var slam_charge := -1.0         ## >= 0 while raising the hammer
var slam_t := 0.0               ## > 0 just after a slam: the hammer down on the ground
var slam_cd := 0.0
var showing_off := 0.0          ## > 0: holding a new treasure up high (set by the level)
var _attack_held := 0.0
## His costume. The fire-discovery set: wolf_hood, ember_paint, bear_cloak,
## firekeeper (and the older wolf_pelt, war_paint, bone_necklace, plain).
var skin := "plain"
var axe := false           ## the Flint Axe: a knapped flint blade, harder blows

## ------------------------------------------------------------------ weapons
## Every weapon fights its own way, and each has its own special (hold
## attack, then let go):
##   Wooden Club — a quick overhead BONK.
##     Special: HOME RUN — pulled back low, then a huge sweeping swing that
##     sends small things flying.
##   Flint Axe — fast slashes: tap three times for slash, back-slash, CHOP.
##     Special: AXE THROW — it spins out, cuts through everything in its way,
##     and flies back to his hand.
##   Firestone Hammer — heaved up high and SMASHED down in front of him: slow,
##     heavy, it shakes the ground.
##     Special: FIRE SLAM — a wave of fire rolls out along the ground.
## Each swing: [how long, time before the next, hits from, hits until (as parts
## of the swing), reach, height, damage]
const SWINGS := {
	"club": [0.26, 0.38, 0.20, 1.00, 36.0, -34.0, 3],
	"axe0": [0.17, 0.20, 0.10, 0.90, 44.0, -48.0, 3],
	"axe1": [0.17, 0.20, 0.10, 0.90, 44.0, -30.0, 3],
	"axe2": [0.34, 0.44, 0.52, 1.00, 42.0, -30.0, 6],
	"hammer": [0.50, 0.64, 0.58, 0.88, 50.0, -18.0, 6],
	"homerun": [0.38, 0.60, 0.30, 0.82, 64.0, -42.0, 7],
}
const CHARGE_READY := {"club": 0.45, "axe": 0.3, "hammer": 0.5}
var _swing_kind := "club"
var _swing_time := 0.26
var _combo := 0
var _combo_t := 9.0             ## time since the last axe swing ended
var axe_out := false            ## the axe is out, spinning (thrown)
var _struck := false            ## this swing has already struck something (for its effects)
var preview := false       ## a mannequin in the shop: stands, breathes, never moves
signal ate_fig
var _fig_prev := false
## Scorched by standing in a campfire: "YEOWCH!", a leap, his loincloth
## smoking with little flames, a panicked run — then a sooty face a while.
var scorch_t := 0.0
var soot_t := 0.0
var _panic_dir := 1.0
var _smoke_in := 0.0
## Vine swinging. While on one he is placed by the swing, not by physics.
const HANG := 80.0        ## px from the grip down to his feet
## Jumping off a vine he somersaults the way he's flying: curls into a ball,
## spins, then opens out — arms wide, legs reaching — to land in a crouch.
## A big fast release is a DOUBLE flip; letting go on the backswing is a BACK
## flip, arms flung out. Faded ghosts of the ball trace the arc behind him.
const FLIP_TIME := 0.62
var flip_t := 0.0
var flip_dir := 1.0
var flip_len := FLIP_TIME
var flip_turns := 1.0
var flip_back := false
var _ghosts: Array = []         ## [global centre, time left] of the ball, for the trail
var _ghost_in := 0.0
var _flipped := false           ## was flipping just before landing: a puff of dust
var vine: Node2D = null
var _vine_a := 0.0        ## angle from straight down
var _vine_w := 0.0        ## angular speed
var _vine_cd := 0.0       ## brief no-regrab of the vine he just let go of
var _last_vine: Node2D = null
var touch := {"left": false, "right": false, "jump": false, "attack": false, "heal": false, "throw": false, "fire": false}

var _jump_prev := false
var _attack_prev := false
var _heal_prev := false
var _throw_prev := false
var _fire_prev := false
var _torch_tip := Vector2(-22, -80)   ## where the flame is, in his local space; set by drawing
var _embers: CPUParticles2D           ## embers rising from the torch
var _coyote := 0.0
var _buffer := 0.0
var _jumps_left := 0
var _hitbox: Area2D
var _hit_box: RectangleShape2D
var _swing_hits: Array = []
var _punch_beat := 0
## --- animation state (visual only, never read by gameplay)
var _run_phase := 0.0     ## advances with distance travelled, so feet never slide
var _land := 0.0          ## landing squash timer
var _land_amt := 0.0      ## how hard that landing was, 0..1
var _was_floor := true
var _hit_shape: CollisionShape2D


func _ready() -> void:
	if preview:
		# just for show: no body, no hit box, not "the player"
		set_physics_process(false)
		collision_layer = 0
		collision_mask = 0
		has_stick = true
		costume = 2
		return
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	_embers = FX.embers(3.0, 8, 0.7)
	_embers.emitting = false
	add_child(_embers)

	var body := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 13.0
	cap.height = 64.0
	body.shape = cap
	body.position = Vector2(0, -32)
	add_child(body)

	_hitbox = Area2D.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 4
	_hitbox.monitorable = false
	_hit_shape = CollisionShape2D.new()
	_hit_box = RectangleShape2D.new()
	_hit_box.size = FIST_BOX            ## starts bare-handed and short
	_hit_shape.shape = _hit_box
	_hit_shape.position = Vector2(FIST_REACH, -30)
	_hitbox.add_child(_hit_shape)
	add_child(_hitbox)


func scorched(fire_x: float) -> void:
	if dead or scorch_t > 0.0 or vine != null:
		return
	scorch_t = 1.5
	soot_t = 6.0
	_panic_dir = 1.0 if global_position.x >= fire_x else -1.0
	facing = int(_panic_dir)
	velocity = Vector2(_panic_dir * 260.0, -720.0)
	var word := WordPop.new()
	word.text = "YEOWCH!"
	word.position = global_position + Vector2(-50, -120)
	get_parent().add_child(word)
	FX.burst(get_parent(), global_position + Vector2(0, -40), "embers")


## A roast fig: two hearts back.
func eat_fig() -> bool:
	if GameState.figs <= 0 or hp >= max_hp or dead:
		return false
	GameState.figs -= 1
	hp = mini(hp + 2, max_hp)
	GameState.save()
	var pop := HeartPop.new()
	pop.position = global_position + Vector2(0, -120)
	get_parent().add_child(pop)
	ate_fig.emit()
	return true


## The Flint Axe, thrown: it spins out, slowing, cutting through everything in
## its path; at the end of its flight (or when it hits a wall) it turns and
## flies back to his hand, cutting again on the way.
class ThrownAxe extends Area2D:
	const SPEED := 820.0
	const OUT := 0.6                ## about 400 px out before it turns back
	const DAMAGE := 4
	var man: CaveMan
	var dir := 1
	var t := 0.0
	var back := false
	var spin := 0.0
	var _hit := {}

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 4
		monitorable = false
		z_index = 4
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 34.0
		cs.shape = c
		add_child(cs)

	func _physics_process(delta: float) -> void:
		t += delta
		spin += delta * 24.0 * dir
		if man == null or not is_instance_valid(man):
			queue_free()
			return
		var vel: Vector2
		if not back:
			vel = Vector2(dir * SPEED * (1.0 - 0.5 * t / OUT), 0.0)
			var q := PhysicsRayQueryParameters2D.create(global_position, global_position + vel * delta * 2.0, 1)
			if t > OUT or not get_world_2d().direct_space_state.intersect_ray(q).is_empty():
				back = true
				_hit.clear()
		else:
			var to := man.global_position + Vector2(0, -46) - global_position
			if to.length() < 44.0 or t > 3.0:
				man.axe_out = false
				queue_free()
				return
			vel = to.normalized() * SPEED * 1.1
		global_position += vel * delta
		for a in get_overlapping_areas():
			if a.has_method("take_hit") and not _hit.has(a.get_instance_id()):
				_hit[a.get_instance_id()] = true
				a.take_hit(DAMAGE, dir if not back else -dir)
		queue_redraw()

	func _draw() -> void:
		# a blur of the spin, then the axe itself, turning
		draw_arc(Vector2.ZERO, 34.0, spin - 1.6, spin, 12, Color("dfeaf2", 0.35), 6.0, true)
		draw_set_transform(Vector2.ZERO, spin, Vector2.ONE)
		draw_line(Vector2(-30, 0), Vector2(24, 0), Color("3a2a18"), 9.0, true)
		draw_line(Vector2(-30, 0), Vector2(24, 0), Color("c49a64"), 5.0, true)
		draw_colored_polygon(PackedVector2Array([Vector2(14, -4), Vector2(18, -26), Vector2(34, -24), Vector2(38, -4), Vector2(26, 4)]), Color("3d4650"))
		draw_colored_polygon(PackedVector2Array([Vector2(16, -5), Vector2(19, -23), Vector2(32, -22), Vector2(35, -5), Vector2(26, 2)]), Color("6f7f8f"))
		draw_line(Vector2(32, -22), Vector2(35, -5), Color("d9e4ee"), 2.0, true)


## Dust and sparks where the hammer hits the ground.
class SmashDust extends Node2D:
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		if t > 0.45:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := t / 0.45
		for i in 6:
			var dx := (i - 2.5) * 12.0 * (1.0 + k * 1.6)
			draw_circle(Vector2(dx, -6.0 - k * 14.0), 7.0 + k * 10.0, Color(0.72, 0.66, 0.56, 0.5 * (1.0 - k)))
		for i in 5:
			var p := Vector2.from_angle(-PI * 0.5 + (i - 2) * 0.45) * (10.0 + k * 60.0) + Vector2(0, -6)
			draw_circle(p, 3.0 * (1.0 - k) + 1.0, Color(1.0, 0.8, 0.4, 1.0 - k))


## A word bursting out of a big hit ("HOME RUN!").
class WordPop extends Node2D:
	var text := ""
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		if t > 0.9:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := 1.0 + 0.4 * clampf(1.0 - t / 0.15, 0.0, 1.0)
		var a := clampf((0.9 - t) / 0.3, 0.0, 1.0)
		draw_set_transform(Vector2(0, -t * 40.0), -0.08, Vector2(k, k))
		draw_string(ThemeDB.fallback_font, Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0, 0, 0, 0.6 * a))
		draw_string(ThemeDB.fallback_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.85, 0.35, a))


## Two little hearts rising and fading where he ate a fig.
class HeartPop extends Node2D:
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		if t > 0.9:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var a := 1.0 - t / 0.9
		for k in 2:
			var c := Vector2(-14.0 + k * 28.0, -t * 60.0 - k * 8.0)
			var r := 7.0
			draw_circle(c + Vector2(-r * 0.5, 0), r * 0.6, Color(0.95, 0.35, 0.4, a))
			draw_circle(c + Vector2(r * 0.5, 0), r * 0.6, Color(0.95, 0.35, 0.4, a))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.05, 2), c + Vector2(r * 1.05, 2), c + Vector2(0, r * 1.3)]), Color(0.95, 0.35, 0.4, a))
		draw_string(ThemeDB.fallback_font, Vector2(-14, -t * 60.0 + 26.0), "+2", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.9, 0.9, a))


func _physics_process(delta: float) -> void:
	var fig_now: bool = Input.is_physical_key_pressed(KEY_H) or touch.get("fig", false)
	if fig_now and not _fig_prev:
		eat_fig()
	_fig_prev = fig_now
	if dead:
		if not is_on_floor():
			velocity.y += GRAVITY_DOWN * delta
			move_and_slide()
		return

	anim_t += delta
	attack_cd = maxf(attack_cd - delta, 0.0)
	invuln = maxf(invuln - delta, 0.0)
	knock = maxf(knock - delta, 0.0)
	attacking = maxf(attacking - delta, 0.0)
	if flip_t > 0.0:
		flip_t = maxf(flip_t - delta, 0.0)
		_ghost_in -= delta
		if _ghost_in <= 0.0:
			_ghost_in = 0.035
			_ghosts.append([global_position + Vector2(0, -38), 0.22])
		if is_on_floor() or vine != null or knock > 0.0:
			flip_t = 0.0
	for g in _ghosts:
		g[1] = float(g[1]) - delta
	_ghosts = _ghosts.filter(func(g): return float(g[1]) > 0.0)
	if _flipped and is_on_floor():
		# landed out of a flip: a crouch and a puff of dust
		_flipped = false
		var dust := SmashDust.new()
		dust.position = global_position
		dust.scale = Vector2(0.6, 0.6)
		get_parent().add_child(dust)
	elif _flipped and (vine != null or knock > 0.0):
		_flipped = false
	if attacking <= 0.0:
		_combo_t += delta
	throwing = maxf(throwing - delta, 0.0)

	if talking:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		if not is_on_floor():
			velocity.y += GRAVITY_DOWN * delta
		move_and_slide()
		return

	if has_torch and torch_fuel > 0.0:
		torch_fuel = maxf(torch_fuel - delta / torch_burn, 0.0)
		if hammer:
			# the Firestone in the hammer feeds the flame: it never sinks below half
			torch_fuel = maxf(torch_fuel, 0.5)
		if torch_fuel <= 0.0:
			torch_out.emit()

	# The fire: a burst of visible anger, THEN the flame. He cannot be hurt
	# through it — it is the button you press when swarmed, so a wind-up that
	# could be punished would be a trap — and he cannot steer, jump or strike:
	# the rage roots him. Fire leaves at 0.6 s; the rest is the snarl.
	var fire_now: bool = Input.is_physical_key_pressed(KEY_F) or touch["fire"]
	if fury >= 0.0:
		var before := fury
		fury += delta
		if before < FURY_RELEASE and fury >= FURY_RELEASE:
			_release_fire()
		if fury >= FURY_TIME:
			fury = -1.0
		_fire_prev = fire_now
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		if not is_on_floor():
			velocity.y += GRAVITY_DOWN * delta
		move_and_slide()
		_was_floor = is_on_floor()
		return

	# raising the Firestone Hammer: rooted while the charge builds; letting go
	# of attack brings it down — a SLAM if the charge was full
	slam_t = maxf(slam_t - delta, 0.0)
	slam_cd = maxf(slam_cd - delta, 0.0)
	showing_off = maxf(showing_off - delta, 0.0)
	var held: bool = Input.is_physical_key_pressed(KEY_J) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or touch["attack"]
	if slam_charge >= 0.0:
		slam_charge += delta
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		if not is_on_floor():
			velocity.y += GRAVITY_DOWN * delta
		move_and_slide()
		if not held:
			if slam_charge >= _charge_ready():
				match _weapon():
					"hammer":
						_slam()
					"axe":
						_throw_axe()
					_:
						_home_run()
			slam_charge = -1.0
		_attack_prev = held
		return
	if held:
		_attack_held += delta
	else:
		_attack_held = 0.0
	# holding attack turns the swing into the weapon's special: if he's still
	# holding during the wind-up (before the blow has landed), the swing is
	# dropped and the charge begins — so the special never waits for a whole swing
	if has_stick and not axe_out and is_on_floor() and slam_cd <= 0.0 and _attack_held > 0.22:
		var winding := attacking > 0.0 and (1.0 - attacking / _swing_time) < float(SWINGS[_swing_kind][2]) and _swing_kind != "homerun"
		if attacking <= 0.0 or winding:
			attacking = 0.0
			slam_charge = 0.0

	# scorched: running off in a panic, smoke trailing behind
	scorch_t = maxf(scorch_t - delta, 0.0)
	soot_t = maxf(soot_t - delta, 0.0)
	if scorch_t > 0.0:
		_smoke_in -= delta
		if _smoke_in <= 0.0:
			_smoke_in = 0.08
			FX.burst(get_parent(), global_position + Vector2(-_panic_dir * 16.0, -44.0), "smoke", -_panic_dir)
	var dir := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT) or touch["left"]:
		dir -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT) or touch["right"]:
		dir += 1.0
	if scorch_t > 0.0:
		dir = _panic_dir
	if dir != 0.0:
		facing = int(signf(dir))
	_vine_cd = maxf(_vine_cd - delta, 0.0)
	if vine != null:
		_swing(delta, dir)
		return
	var armed := has_stick and not axe_out
	var _reach := CLUB_REACH if armed else FIST_REACH
	var _height := -34.0 if armed else -30.0
	if not armed and attacking > 0.0 and _punch_beat == 1:
		_reach = FIST_REACH + 9.0
	if armed and attacking > 0.0:
		var sw: Array = SWINGS[_swing_kind]
		_reach = sw[4]
		_height = sw[5]
	_hit_shape.position.x = _reach * facing
	_hit_shape.position.y = _height
	if armed:
		_hit_box.size = CLUB_BOX * (1.5 if _swing_kind == "homerun" and attacking > 0.0 else 1.0)
	else:
		_hit_box.size = FIST_BOX

	if knock <= 0.0:
		var a := ACCEL if is_on_floor() else AIR_ACCEL
		if dir != 0.0:
			velocity.x = move_toward(velocity.x, dir * SPEED, a * delta)
		else:
			var f := FRICTION if is_on_floor() else AIR_ACCEL * 0.5
			velocity.x = move_toward(velocity.x, 0.0, f * delta)
	if not is_on_floor():
		velocity.y += (GRAVITY_UP if velocity.y < 0.0 else GRAVITY_DOWN) * delta

	# coyote time: full on the ground, draining in the air
	if is_on_floor():
		_coyote = COYOTE_TIME
		_jumps_left = MAX_JUMPS
	else:
		_coyote = maxf(_coyote - delta, 0.0)
		# walking off a ledge without jumping spends the ground jump
		if _coyote <= 0.0 and _jumps_left == MAX_JUMPS:
			_jumps_left = MAX_JUMPS - 1

	var jump_now: bool = Input.is_physical_key_pressed(KEY_SPACE) \
		or Input.is_physical_key_pressed(KEY_W) \
		or Input.is_physical_key_pressed(KEY_UP) \
		or touch["jump"]

	# jump buffer: remember a press so an early tap still fires on landing
	if jump_now and not _jump_prev:
		_buffer = JUMP_BUFFER
	else:
		_buffer = maxf(_buffer - delta, 0.0)

	if _buffer > 0.0:
		if _coyote > 0.0 and _jumps_left == MAX_JUMPS:
			velocity.y = JUMP
			_jumps_left -= 1
			_buffer = 0.0
			_coyote = 0.0
		elif _jumps_left > 0:
			velocity.y = AIR_JUMP
			_jumps_left -= 1
			_buffer = 0.0

	# variable height: releasing early cuts the jump short
	if not jump_now and _jump_prev and velocity.y < 0.0:
		velocity.y *= JUMP_CUT
	_jump_prev = jump_now

	var attack_now: bool = Input.is_physical_key_pressed(KEY_J) \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
		or touch["attack"]
	if attack_now and not _attack_prev and attack_cd <= 0.0:
		if has_stick and not axe_out:
			var kind := _weapon()
			if kind == "axe":
				# slash, back-slash, CHOP — if the taps come quickly enough
				_combo = (_combo + 1) % 3 if _combo_t < 0.45 else 0
				kind = "axe%d" % _combo
			_start_swing(kind)
		else:
			attack_cd = 0.46
			attacking = PUNCH_TIME
		_punch_beat = 0
		_swing_hits.clear()
	_attack_prev = attack_now

	# The club connects across the WHOLE swing, not on one frame. Checking only
	# at the keypress meant anything that was not already touching him was a miss.
	if attacking > 0.0:
		if not has_stick or axe_out:
			# the cross is a fresh strike, so the same target can be hit by both
			var beat := 1 if (1.0 - attacking / PUNCH_TIME) >= 0.5 else 0
			if beat != _punch_beat:
				_punch_beat = beat
				_swing_hits.clear()
		_apply_swing()

	var throw_now: bool = Input.is_physical_key_pressed(KEY_K) \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) \
		or touch["throw"]
	if throw_now and not _throw_prev:
		throw_rock()
	_throw_prev = throw_now

	if fire_now and not _fire_prev:
		start_fire()
	_fire_prev = fire_now

	# the wind: carried in the air, drifted on the ground, braced against by
	# walking into it (which slows him to a lean-forward crawl)
	var push := 0.0
	if wind != 0.0:
		var into := dir != 0.0 and signf(dir) != signf(wind)
		if is_on_floor():
			# bracing slows his walk to a lean, and the lean just about holds him
			if into:
				velocity.x = clampf(velocity.x, -BRACE_SPEED, BRACE_SPEED)
			push = wind * WIND_GROUND
		else:
			push = wind

	var pre_vy := velocity.y
	move_and_slide()
	if push != 0.0:
		move_and_collide(Vector2(push * delta, 0.0))
	var on_floor := is_on_floor()
	if on_floor and not _was_floor and pre_vy > 200.0:
		_land = LAND_TIME
		_land_amt = clampf(pre_vy / 1400.0, 0.3, 1.0)
		if pre_vy > 650.0:
			FX.burst(get_parent(), global_position, "dust", float(facing))
	_was_floor = on_floor


func _process(delta: float) -> void:
	if preview:
		# the shop's mannequin: just breathes
		anim_t += delta
		queue_redraw()
		return
	if _embers != null:
		_embers.position = _torch_tip
		_embers.emitting = has_torch and torch_fuel > 0.05 and not dead
	if invuln > 0.0 and fmod(invuln * 12.0, 1.0) < 0.5:
		modulate.a = 0.35
	else:
		modulate.a = 1.0
	# The stride is driven by distance covered, not by time. Tie it to time and
	# the feet skate whenever his speed changes; tie it to distance and every
	# footfall lands where the ground actually is.
	if is_on_floor():
		var k := clampf(absf(velocity.x) / SPEED, 0.0, 1.0)
		_run_phase += absf(velocity.x) * delta / (_stride_amp(k) * ART)
	_land = maxf(_land - delta, 0.0)
	queue_redraw()


## Runs every frame the swing is live. Each target can only be hit once per swing.
func _apply_swing() -> void:
	var dmg := 1
	if has_stick and not axe_out:
		var sw: Array = SWINGS[_swing_kind]
		var prog := 1.0 - attacking / _swing_time
		if prog < float(sw[2]) or prog > float(sw[3]):
			return
		dmg = int(sw[6]) + club_bonus
		if _swing_kind == "hammer" and not _struck:
			# the hammer comes down on the ground: it shakes, and sparks fly
			_struck = true
			var level := get_parent()
			if level.has_method("shake"):
				level.shake(4.0, 0.15)
			var dust := SmashDust.new()
			dust.position = global_position + Vector2(facing * 86.0, 0)
			level.add_child(dust)
	for area in _hitbox.get_overlapping_areas():
		if not area.has_method("take_hit"):
			continue
		var id := area.get_instance_id()
		if _swing_hits.has(id):
			continue
		_swing_hits.append(id)
		var flings := _swing_kind == "homerun" and has_stick and "fling" in area
		if flings:
			area.fling = 2.4
		area.take_hit(dmg, facing)
		if has_stick:
			FX.burst(get_parent(), (area as Node2D).global_position + Vector2(-facing * 10.0, -34.0), "sparks", float(facing))
		if flings and is_instance_valid(area):
			area.fling = 1.0
		# the hammer's weight: what it hits and doesn't kill is knocked flat
		if _swing_kind == "hammer" and is_instance_valid(area) and area.has_method("stagger"):
			area.stagger(facing, 0.9)
		if _swing_kind == "homerun" and not _struck:
			_struck = true
			var word := WordPop.new()
			word.text = "HOME RUN!"
			word.position = area.global_position + Vector2(-50, -90)
			get_parent().add_child(word)


## Which weapon is in his hand.
func _weapon() -> String:
	if hammer:
		return "hammer"
	if axe:
		return "axe"
	return "club"


func _charge_ready() -> float:
	return CHARGE_READY[_weapon()]


func _start_swing(kind: String) -> void:
	var sw: Array = SWINGS[kind]
	_swing_kind = kind
	_swing_time = sw[0]
	attacking = sw[0]
	attack_cd = sw[1]
	_struck = false
	if kind.begins_with("axe"):
		_combo_t = 0.0


## The Wooden Club's special: a huge sweep from low behind him, round in front.
func _home_run() -> void:
	_start_swing("homerun")
	_swing_hits.clear()
	slam_cd = 0.7


## The Flint Axe's special: it spins out, and comes back.
func _throw_axe() -> void:
	axe_out = true
	slam_cd = 0.3
	var flying := ThrownAxe.new()
	flying.man = self
	flying.dir = facing
	flying.position = global_position + Vector2(facing * 40.0, -46.0)     # waist-high: low enough for wolves
	get_parent().add_child(flying)


## The hammer comes down: a wave of fire rolls out along the ground.
func _slam() -> void:
	slam_t = 0.3
	slam_cd = SLAM_COOLDOWN
	var wave := NightWoods.FireWave.new()
	wave.position = global_position
	wave.player = self
	get_parent().add_child(wave)
	var level := get_parent()
	if level.has_method("shake"):
		level.shake(7.0, 0.35)


## ------------------------------------------------------------------ vines
## A vine hands itself to him when he flies into its end. He keeps the speed he
## arrived with, can pump with left/right, and jumps to let go — carrying the
## swing's speed with him, plus a little hop.
func grab_vine(v: Node2D) -> bool:
	if vine != null or dead or talking or fury >= 0.0 or is_on_floor():
		return false
	if v == _last_vine and _vine_cd > 0.0:
		return false
	vine = v
	var rel: Vector2 = (global_position - Vector2(0, HANG)) - v.global_position
	_vine_a = atan2(rel.x, rel.y)
	var length: float = v.length
	_vine_w = clampf((velocity.x * cos(_vine_a) - velocity.y * sin(_vine_a)) / length, -3.0, 3.0)
	velocity = Vector2.ZERO
	_jumps_left = MAX_JUMPS
	return true


func _swing(delta: float, dir: float) -> void:
	var length: float = vine.length
	var acc := -(1800.0 / length) * sin(_vine_a) + dir * 2.6 * cos(_vine_a)
	_vine_w = clampf((_vine_w + acc * delta) * (1.0 - 0.12 * delta), -3.4, 3.4)
	_vine_a = clampf(_vine_a + _vine_w * delta, -1.3, 1.3)
	var grip: Vector2 = vine.global_position + Vector2(sin(_vine_a), cos(_vine_a)) * length
	global_position = grip + Vector2(0, HANG)
	vine.angle = _vine_a
	var jump_now: bool = Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_W) \
		or Input.is_physical_key_pressed(KEY_UP) or touch["jump"]
	if jump_now and not _jump_prev:
		var tangent := Vector2(cos(_vine_a), -sin(_vine_a)) * _vine_w * length
		_let_go(tangent + Vector2(0, -320))
		# off the vine with a somersault, turning the way he's flying
		flip_dir = signf(velocity.x) if absf(velocity.x) > 40.0 else float(facing)
		flip_back = flip_dir != float(facing) and absf(velocity.x) > 60.0
		flip_turns = 2.0 if absf(velocity.x) > 430.0 and not flip_back else 1.0
		flip_len = FLIP_TIME * (1.35 if flip_turns > 1.0 else 1.0)
		flip_t = flip_len
		_ghosts.clear()
		_flipped = true
	_jump_prev = jump_now


func _let_go(vel: Vector2) -> void:
	if vine != null and vine.has_method("let_go"):
		vine.let_go()
	_last_vine = vine
	vine = null
	velocity = vel
	_vine_cd = 0.45
	_jumps_left = MAX_JUMPS - 1


## Called by a critter when he lands on top of it.
func stomp_bounce(push_x: float = 0.0) -> void:
	velocity.y = STOMP_BOUNCE
	if push_x != 0.0:
		velocity.x = push_x
		# brief loss of steering so the shove actually carries him off the back,
		# instead of being cancelled by his own input on the very next frame
		knock = 0.24
	_coyote = 0.0
	_buffer = 0.0
	_jumps_left = maxi(_jumps_left, 1)   # a crush refunds an air jump, so stomps chain
	invuln = maxf(invuln, 0.12)          # brief grace so a neighbour cannot punish a clean stomp


## Fired by a spring. Resets the air jumps so he can steer out of the launch.
func launch(vy: float) -> void:
	velocity.y = vy
	_coyote = 0.0
	_buffer = 0.0
	_jumps_left = MAX_JUMPS


func hurt(amount: int, from_x: float) -> void:
	if invuln > 0.0 or dead or fury >= 0.0 or talking:
		return
	hp -= amount
	invuln = 1.1
	knock = 0.25
	slam_charge = -1.0
	if vine != null:
		_let_go(Vector2.ZERO)
	var away := signf(global_position.x - from_x)
	if away == 0.0:
		away = -float(facing)
	velocity = Vector2(away * 280.0, -340.0)
	hp_changed.emit(hp)
	if hp <= 0:
		dead = true
		died.emit()
	elif berries > 0 and is_inside_tree():
		get_tree().create_timer(0.45).timeout.connect(_auto_eat)


## Put back on solid ground after a fall. Costs one health point, but applies
## NO knockback: being flung again while standing at the lip of the same hole
## is how one fall turns into three.
func respawn_at(spot: Vector2) -> void:
	global_position = spot
	velocity = Vector2.ZERO
	knock = 0.0
	fury = -1.0
	if vine != null:
		_let_go(Vector2.ZERO)
	if dead:
		return
	hp -= 1
	invuln = 1.3
	hp_changed.emit(hp)
	if hp <= 0:
		dead = true
		died.emit()


func pick_up_stick() -> void:
	has_stick = true
	_hit_box.size = CLUB_BOX     ## longer and taller the moment he has it
	stick_picked.emit()


func add_rock(n: int = 1) -> bool:
	if rocks >= max_rocks:
		return false
	rocks = mini(rocks + n, max_rocks)
	rocks_changed.emit(rocks)
	rock_picked.emit()
	return true


## Throws a rock in the direction he faces. Ranged answer to things that bite back.
func throw_rock() -> bool:
	if dead or rocks <= 0 or throwing > 0.0:
		return false
	rocks -= 1
	rocks_changed.emit(rocks)
	throwing = 0.28
	var r := World.ThrownRock.new()
	r.position = global_position + Vector2(20.0 * facing, -44)
	r.vel = Vector2(THROW_SPEED * facing, -140.0)
	get_parent().add_child(r)
	return true


## Health fruit (a bunch of grapes, or a banana) looks after itself: if he's
## hurt he eats it on the spot; if he isn't, it goes in his pouch, and he eats
## one by himself the moment he gets hurt. No key to press.
func add_berry() -> bool:
	if hp < max_hp and not dead:
		_eat_fruit()
		return true
	if berries >= max_berries:
		return false
	berries += 1
	berries_changed.emit(berries)
	return true


func _eat_fruit() -> void:
	hp = mini(hp + 2, max_hp)
	hp_changed.emit(hp)
	var pop := HeartPop.new()
	pop.position = global_position + Vector2(0, -120)
	get_parent().add_child(pop)


## Hurt, with fruit in the pouch: a moment later (so the hit is felt), he eats one.
func _auto_eat() -> void:
	if dead or berries <= 0 or hp >= max_hp:
		return
	berries -= 1
	berries_changed.emit(berries)
	_eat_fruit()


## Gather -> craft -> ability: berries become a poultice that heals.
## Always reports back, so pressing E never looks like nothing happened.
func use_poultice() -> bool:
	if dead:
		return false
	if berries <= 0:
		poultice.emit(false, "No berries to crush.")
		return false
	if hp >= max_hp:
		poultice.emit(false, "He is not hurt. Save them.")
		return false
	berries -= 1
	hp = mini(hp + 2, max_hp)
	berries_changed.emit(berries)
	hp_changed.emit(hp)
	poultice.emit(true, "He chews the poultice. Two wounds close.")
	return true


## ------------------------------------------------------------------ torch
## Level 2 on. The torch rides in his back hand, so the club stays in front.
func give_torch() -> void:
	has_torch = true
	torch_fuel = 1.0
	add_to_group("light")


func relight(amount: float = 1.0) -> void:
	if has_torch:
		torch_fuel = maxf(torch_fuel, amount)


func light_radius() -> float:
	if not has_torch or torch_fuel <= 0.0 or dead:
		return 0.0
	return lerpf(TORCH_R_MIN, TORCH_R_MAX, torch_fuel)


## For Night: where the flame is (x, y), how far it reaches (z), how warm (w).
func light() -> Vector4:
	var r := light_radius()
	if r <= 0.0:
		return Vector4.ZERO
	var tip := to_global(_torch_tip)
	r *= 1.0 + sin(anim_t * 13.0) * 0.012 + sin(anim_t * 7.3 + 1.0) * 0.018
	# his anger feeds the flame: the pool of light swells as the fire builds,
	# which reads from across the screen and pushes the wolves back
	if fury >= 0.0:
		r *= 1.0 + 0.6 * clampf(fury / FURY_RELEASE, 0.0, 1.0)
	return Vector4(tip.x, tip.y, r, 0.9)


## How much the light protects him. The wolves read this, not the radius.
func light_strength() -> float:
	return torch_fuel if has_torch and not dead else 0.0


func add_wood(n: int = 1) -> bool:
	if wood >= max_wood:
		return false
	wood = mini(wood + n, max_wood)
	wood_changed.emit(wood)
	return true


## Gather -> craft -> ability: dry wood becomes fire. Always reports back.
func start_fire() -> bool:
	if dead or fury >= 0.0:
		return false
	if wood < FIRE_COST:
		said.emit("A fire takes two bundles of wood. Dead trees give it up to the club.")
		return false
	wood -= FIRE_COST
	wood_changed.emit(wood)
	fury = 0.0
	attacking = 0.0
	throwing = 0.0
	return true


func _release_fire() -> void:
	var fb := NightWoods.FireBurst.new()
	fb.position = global_position + Vector2(0, -40)
	get_parent().add_child(fb)
	relight(0.5)
	fire_released.emit()


## Back on his feet at a checkpoint, whole, torch full.
func revive(spot: Vector2) -> void:
	if vine != null:
		_let_go(Vector2.ZERO)
	dead = false
	global_position = spot
	velocity = Vector2.ZERO
	knock = 0.0
	fury = -1.0
	hp = max_hp
	invuln = 1.6
	if has_torch:
		torch_fuel = 1.0
	hp_changed.emit(hp)


## ------------------------------------------------------------------ drawing
## He is designed at about 2.6x game size and scaled down in one transform.
## Facing is folded into the same transform (a negative x scale), so none of
## the shapes below need to know which way he is looking.
const ART := 0.38        ## design units -> game pixels. ~186 tall -> ~71 px
const OLW := 5.0         ## rim width in design units (~2 px on screen)
## Shapes are drawn twice — a shadow tone, then the base tone pulled toward the
## light — so each form has a shaded edge instead of a flat colour and a black
## line. The sun in the sky sits high and right, so the light comes from there.
const LIGHT := Vector2(0.55, -0.83)

const C_OL := Color("2a211a")
const C_SKIN := Color("c89263")
const C_SK2 := Color("a67148")
const C_HAIR := Color("3a2a1c")
const C_LEAF := Color("6a8447")
const C_LEAF2 := Color("55703a")
const C_VINE := Color("6a5535")
const C_WOOD := Color("846141")
const C_WOOD2 := Color("5a4029")
const C_EYE := Color("ece3cd")
const C_MOUTH := Color("33211a")
var _skin := C_SKIN      ## flushes toward ember while he is winding up the fire

const MANE := [
	Vector2(-24, -128), Vector2(-30, -142), Vector2(-28, -158), Vector2(-31, -170),
	Vector2(-22, -182), Vector2(-14, -190), Vector2(-2, -186), Vector2(8, -194),
	Vector2(18, -186), Vector2(28, -188), Vector2(34, -174), Vector2(40, -162),
	Vector2(37, -146), Vector2(42, -132), Vector2(34, -124), Vector2(22, -130),
	Vector2(4, -134), Vector2(-12, -130),
]
const BEARD := [
	Vector2(-19, -150), Vector2(-21, -140), Vector2(-17, -131), Vector2(-12, -124),
	Vector2(-7, -119), Vector2(-1, -123), Vector2(4, -116), Vector2(9, -122),
	Vector2(15, -118), Vector2(20, -125), Vector2(25, -130), Vector2(29, -141),
	Vector2(27, -150), Vector2(20, -142), Vector2(12, -144), Vector2(4, -142),
	Vector2(-4, -144), Vector2(-12, -142),
]
const FRINGE := [
	Vector2(-20, -164), Vector2(-22, -172), Vector2(-14, -180), Vector2(-8, -175),
	Vector2(-1, -184), Vector2(6, -177), Vector2(12, -186), Vector2(18, -178),
	Vector2(26, -176), Vector2(28, -166), Vector2(22, -167), Vector2(15, -171),
	Vector2(8, -168), Vector2(1, -172), Vector2(-6, -168), Vector2(-13, -170),
]



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


func _paint() -> void:
	var on_floor := is_on_floor() or preview
	var air := not on_floor and not dead
	var speed_k := clampf(absf(velocity.x) / SPEED, 0.0, 1.0) if on_floor else 0.0
	var running := speed_k > 0.08 and not dead
	var ph := _run_phase
	var boxing := attacking > 0.0 and not has_stick and throwing <= 0.0
	var wince := invuln > 0.8 and not dead
	# the anger: builds 0 -> 1 through the wind-up, then the snarl
	var rage := 0.0
	var roaring := false
	if fury >= 0.0:
		rage = clampf(fury / FURY_RELEASE, 0.0, 1.0)
		roaring = fury >= FURY_RELEASE
	_skin = C_SKIN.lerp(Pal.EMBER, 0.22 * rage) if rage > 0.0 else C_SKIN

	# ---- whole-body squash and stretch, pivoting on his feet so they stay planted
	var sx := 1.0
	var sy := 1.0
	var land_k := 0.0
	if _land > 0.0:
		land_k = sin(_land / LAND_TIME * PI) * _land_amt
		sx += 0.14 * land_k
		sy -= 0.16 * land_k
	elif air:
		var st := clampf(-velocity.y / 1600.0, -0.05, 0.09)
		sx -= st * 0.6
		sy += st
	if fury >= 0.0:
		if not roaring:
			# hunched and gathering
			sx += 0.05 * rage
			sy -= 0.06 * rage
		else:
			# and then he rears up as it leaves him
			var pop := 1.0 - clampf((fury - FURY_RELEASE) / 0.15, 0.0, 1.0)
			sy += 0.06 * pop
			sx -= 0.03 * pop
	var rot := float(facing) * PI * 0.5 if dead else 0.0
	var base := Transform2D(rot, Vector2(ART * facing * sx, ART * sy), 0.0, Vector2.ZERO)
	var curl := 0.0                 ## 1 = curled into a ball; 0 = open
	var open_k := 0.0               ## 1 = opened out for the landing
	if flip_t > 0.0:
		var k := 1.0 - flip_t / flip_len
		# the spin: all of it in the curled part, finished as he opens out
		var spin_k := clampf(k / 0.78, 0.0, 1.0)
		var ang := flip_dir * TAU * flip_turns * (spin_k * spin_k * (3.0 - 2.0 * spin_k))
		curl = clampf(k / 0.12, 0.0, 1.0) * (1.0 - clampf((k - 0.72) / 0.12, 0.0, 1.0))
		open_k = clampf((k - 0.72) / 0.2, 0.0, 1.0)
		var pivot := Vector2(0, -38)
		# the ghosts of the ball, fading along the arc behind him
		_stm(Transform2D.IDENTITY)
		for g in _ghosts:
			var a := float(g[1]) / 0.22
			var at: Vector2 = (g[0] as Vector2) - global_position
			_cc(at, 17.0, Color(C_SKIN, 0.28 * a))
			_cc(at + Vector2(-flip_dir * 4.0, -6.0), 8.0, Color(C_HAIR, 0.3 * a))
		# a ball is smaller than a man: squeeze him in while he's curled
		base = Transform2D(0.0, pivot) * Transform2D(ang, Vector2.ONE * (1.0 - 0.14 * curl)) * Transform2D(0.0, -pivot) * base

	# ---- pelvis: rises through each stride, sinks on a landing, leans into a run
	var bob := land_k * 9.0
	var lean := 0.0
	if running:
		bob -= absf(sin(ph)) * 7.0 * speed_k
		lean = 0.14 * speed_k
	elif air:
		lean = 0.06
	if flip_t > 0.0:
		lean = 0.5 * curl - 0.1 * open_k      # curled forward into the ball
	if fury >= 0.0 and not roaring:
		bob += 7.0 * rage
	var shake := Vector2.ZERO
	if fury >= 0.0 and not roaring:
		shake = Vector2(sin(anim_t * 71.0) * 2.6, cos(anim_t * 89.0) * 1.8) * rage

	# ---- legs, solved with two-bone IK so the knees always bend the right way
	_stm(base)
	var hip_b := Vector2(-14, -62.0 + bob)
	var hip_f := Vector2(22, -62.0 + bob)
	# standing: feet planted straight under the hips
	var foot_b := Vector2(-16, -6)
	var foot_f := Vector2(24, -6)
	var bend := 0.0
	if air and flip_t > 0.0:
		bend = 1.0
		foot_f = Vector2(34, -28).lerp(Vector2(22, -62), curl).lerp(Vector2(34, -4), open_k)
		foot_b = Vector2(-26, -26).lerp(Vector2(-2, -60), curl).lerp(Vector2(-28, -8), open_k)
		if flip_back:
			foot_f = foot_f.lerp(Vector2(30, -40), curl * 0.6)
	elif air:
		bend = 1.0
		if velocity.y < -150.0:
			foot_f = Vector2(42, -36)      # lead knee drives up
			foot_b = Vector2(-32, -12)     # trail leg hangs back
		elif velocity.y < 180.0:
			foot_f = Vector2(34, -28)      # tucked at the top
			foot_b = Vector2(-26, -26)
		else:
			foot_f = Vector2(30, -6)       # reaching for the ground
			foot_b = Vector2(-24, -12)
	elif not dead:
		# eases between standing and full stride, so stopping does not pop
		var w := clampf(speed_k * 4.0, 0.0, 1.0)
		foot_f = foot_f.lerp(_run_foot(hip_f.x, ph, speed_k), w)
		foot_b = foot_b.lerp(_run_foot(hip_b.x, ph + PI, speed_k), w)
		bend = maxf(w, land_k)
		if land_k > 0.0:
			foot_f.x += 6.0 * land_k
			foot_b.x -= 6.0 * land_k
		if fury >= 0.0:
			# a wide, braced stance while it builds
			bend = maxf(bend, 0.7 * rage)
			foot_f.x += 8.0 * rage
			foot_b.x -= 8.0 * rage
	_leg(hip_b, foot_b, bend)
	_leg(hip_f, foot_f, bend)

	# ---- everything above the waist leans and bobs as one piece
	var upper := base * Transform2D(lean, Vector2(shake.x, -62.0 + bob + shake.y)) * Transform2D(0.0, Vector2(0, 62))
	_stm(upper)

	_shape(PackedVector2Array(MANE), C_HAIR)
	_costume_back()
	# spare wood rides tucked in the belt at his back, behind the body
	for i in wood:
		var wx := -20.0 - i * 6.0
		_ln(Vector2(wx, -60), Vector2(wx - 22, -104), Pal.DEADWOOD_DARK, 9.0, true)
		_ln(Vector2(wx, -60), Vector2(wx - 22, -104), Pal.DEADWOOD, 5.0, true)
	_oval(Vector2(4, -130), 17.0, 10.0, _skin)
	var torso := PackedVector2Array([Vector2(-46, -122)])
	torso.append_array(_quad(Vector2(-46, -122), Vector2(4, -138), Vector2(54, -122)))
	torso.append_array(_quad(Vector2(54, -122), Vector2(44, -94), Vector2(30, -68)))
	torso.append(Vector2(-22, -68))
	torso.append_array(_quad(Vector2(-22, -68), Vector2(-36, -94), Vector2(-46, -122)))
	torso.remove_at(torso.size() - 1)
	_shape(torso, _skin)
	_pl(_quad(Vector2(-32, -114), Vector2(-14, -100), Vector2(2, -108), 8, true), C_SK2, 3.5, true)
	_pl(_quad(Vector2(6, -108), Vector2(22, -100), Vector2(40, -114), 8, true), C_SK2, 3.5, true)
	_ln(Vector2(4, -100), Vector2(4, -74), C_SK2, 3.0, true)
	for yy in [-94.0, -86.0, -78.0]:
		_ln(Vector2(-6, yy), Vector2(2, yy + 1.0), C_SK2, 3.0, true)
		_ln(Vector2(6, yy + 1.0), Vector2(14, yy), C_SK2, 3.0, true)
	_ticks([[-4, -114, -6, -108], [3, -116, 2, -109], [10, -113, 12, -107], [-1, -106, -3, -100],
		[6, -106, 7, -100], [2, -100, 3, -94], [-10, -110, -12, -104], [16, -110, 18, -104]])
	_costume_chest()

	# far arm: pumps against the legs when running
	var back_sh := Vector2(-42, -118)
	if has_torch and not boxing:
		_torch_arm(back_sh, running, air, ph, speed_k, rage, upper)
	elif not boxing:
		var fa := _pose_arm(back_sh, -1.0, running, air, ph, speed_k)
		_arm(back_sh, fa[0], fa[1], 10.0, true)

	if costume >= 2:
		_hide_loincloth(speed_k)
		_seat_flames()
	else:
		for i in 6:
			var lx := -21.0 + i * 10.0
			var ang := (i - 2.5) * 0.11 + sin(anim_t * 2.2 + i) * 0.045 - speed_k * 0.18
			_leaf(Vector2(lx, -70), 29.0 + (3.0 if i % 2 == 1 else 0.0), 8.0, ang, C_LEAF2 if i % 2 == 1 else C_LEAF)
	var belt := _quad(Vector2(-25, -71), Vector2(4, -66), Vector2(33, -71), 10, true)
	_pl(belt, C_OL, 12.0, true)
	_pl(belt, C_VINE, 7.0, true)
	for i in 7:
		var bx := -20.0 + i * 8.0
		_ln(Vector2(bx - 2, -73), Vector2(bx + 2, -68), C_WOOD2, 2.0, true)
	for i in berries:
		_grapes(Vector2(-30.0 + i * 11.0, -80), 0.5)
	_costume_belt()
	for i in mini(rocks, 3):
		_dot(Vector2(36.0 + i * 10.0, -62), 6.5, Pal.STONE, 2.5)

	# ---- head: one steady grumpy expression
	_dot(Vector2(-20, -152), 6.0, _skin, 4.0)
	_dot(Vector2(28, -152), 6.0, _skin, 4.0)
	_oval(Vector2(4, -154), 24.0, 27.0, _skin)
	_shape(PackedVector2Array(BEARD), C_HAIR, 4.0)
	_costume_face()
	if skin == "war_paint":
		for k in 3:
			_ln(Vector2(-14 + k * 12, -104), Vector2(-4 + k * 12, -86), Pal.EMBER, 4.0, true)
	elif skin == "bone_necklace":
		var cord := PackedVector2Array()
		for k in 9:
			var x := -16.0 + k * 5.2
			cord.append(Vector2(x, -114.0 + sin(k / 8.0 * PI) * 12.0))
		_pl(cord, C_VINE, 2.5, true)
		for k in [1, 3, 5, 7]:
			var bp: Vector2 = cord[k]
			_oval(bp + Vector2(0, 4), 2.6, 5.5, Pal.KEY_BONE, 1.5)
	if roaring:
		_roar()
	else:
		_mouth()
	_oval(Vector2(4, -146), 8.0, 5.0, C_SK2, 3.0)
	_cc(Vector2(1, -145), 1.4, C_MOUTH)
	_cc(Vector2(7, -145), 1.4, C_MOUTH)
	var blink := fmod(anim_t, 3.7) < 0.12
	_eye(Vector2(-7, -151), wince, blink)
	_eye(Vector2(15, -151), wince, blink)
	# brows set in a permanent V: grumpy is his resting face
	var inner := 9.0 if wince else 5.0
	if fury >= 0.0:
		inner = 12.0
	_ln(Vector2(-18, -160), Vector2(-2, -160.0 + inner), C_HAIR, 8.0, true)
	_ln(Vector2(10, -160.0 + inner), Vector2(26, -160), C_HAIR, 8.0, true)
	_shape(PackedVector2Array(FRINGE), C_HAIR, 4.0)
	if skin == "war_paint":
		_rc(Rect2(-12, -161, 36, 3.5), Pal.EMBER)
	_costume_head()
	_soot_face()
	if fury >= 0.0:
		_rage_marks(rage, roaring)

	# ---- the near arm: fists, throw, club swing, club carry, or pumping
	var sh := Vector2(50, -118)
	var charge_k := clampf(slam_charge / _charge_ready(), 0.0, 1.0) if slam_charge >= 0.0 else 0.0
	if showing_off > 0.0 and has_stick:
		# holding the new treasure up high, both arms, for everyone to see
		var hd := Vector2(20, -232)
		_arm(sh, sh + Vector2(10, -60), hd, 13.0, false)
		_club(hd + Vector2(0, 30), hd + Vector2(0, -80), 7.0, 26.0)
		_dot(hd, 11.0, _skin)
	elif slam_charge >= 0.0 and has_stick:
		var tremble := Vector2(sin(anim_t * 60.0), cos(anim_t * 71.0)) * 2.5 * charge_k
		var hd: Vector2
		var ca: float
		match _weapon():
			"hammer":
				# raised overhead and trembling as the gem burns brighter
				hd = Vector2(8, -196) + tremble
				ca = -1.9 - 0.35 * charge_k
				_arm(sh, sh + Vector2(20, -40), hd, 13.0, false)
			"axe":
				# drawn back behind his head, ready to throw
				hd = Vector2(-26, -186) + tremble
				ca = -2.5 - 0.4 * charge_k
				_arm(sh, sh + Vector2(-10, -46), hd, 13.0, false)
			_:
				# pulled back low behind him, like a batter
				hd = Vector2(-40, -104) + tremble
				ca = 2.5 + 0.25 * charge_k
				_arm(sh, sh + Vector2(-20, 6), hd, 13.0, false)
		_club(hd - Vector2.from_angle(ca) * 12.0, hd + Vector2.from_angle(ca) * 112.0, 7.0, 26.0)
		_dot(hd, 11.0, _skin)
		if charge_k >= 1.0:
			# ready: a glint at the weapon's head
			var tip := hd + Vector2.from_angle(ca) * 104.0
			var r := 9.0 + sin(anim_t * 20.0) * 3.0
			_pg(PackedVector2Array([tip + Vector2(0, -r), tip + Vector2(r * 0.25, 0), tip + Vector2(0, r), tip + Vector2(-r * 0.25, 0)]), Color(1, 1, 0.9, 0.9))
			_pg(PackedVector2Array([tip + Vector2(-r, 0), tip + Vector2(0, r * 0.25), tip + Vector2(r, 0), tip + Vector2(0, -r * 0.25)]), Color(1, 1, 0.9, 0.9))
	elif slam_t > 0.0 and has_stick:
		# brought down onto the ground in front of him
		var hd := Vector2(96, -70)
		_arm(sh, sh + Vector2(40, 10), hd, 13.0, false)
		_club(hd, Vector2(190, -8), 7.0, 26.0)
		_dot(hd, 11.0, _skin)
	elif scorch_t > 0.0 and has_stick:
		# arms up, waving wildly
		var hd := Vector2(24 + sin(anim_t * 26.0) * 14.0, -214)
		_arm(sh, sh + Vector2(12, -52), hd, 13.0, false)
		_club(hd, hd + Vector2(-50, -60), 7.0, 22.0)
		_dot(hd, 11.0, _skin)
	elif flip_t > 0.0 and (curl > 0.0 or open_k > 0.0):
		var hd: Vector2
		if open_k > 0.0:
			hd = Vector2(70, -150).lerp(Vector2(88, -120), open_k)          # out wide for balance
		elif flip_back:
			hd = Vector2(20, -210)                                          # flung up and back
		else:
			hd = Vector2(34, -84)                                           # hugging the knees
		_arm(sh, sh.lerp(hd, 0.5) + Vector2(10, 14), hd, 13.0, false)
		_club(hd, hd + Vector2(-60, 40), 7.0, 22.0)
		_dot(hd, 11.0, _skin)
	elif vine != null:
		# hanging on: the near hand up on the vine, the club tucked under the arm
		var hd := Vector2(0, -HANG / ART)
		_arm(sh, sh + Vector2(-8, -48), hd, 13.0, false)
		_dot(hd, 11.0, _skin)
	elif fury >= 0.0 and has_stick:
		# the club goes up overhead for the whole rage and is shaken at the
		# world as the fire leaves: the pose reads from across the screen
		var ca := -1.85 if not roaring else -1.35
		var hd := sh + Vector2(8, -58)
		_arm(sh, sh + Vector2(26, -24), hd, 13.0, false)
		_club(hd - Vector2.from_angle(ca) * 12.0, hd + Vector2.from_angle(ca) * 112.0, 7.0, 26.0)
		_dot(hd, 11.0, _skin)
	elif boxing:
		var prog := 1.0 - attacking / PUNCH_TIME
		var jab := 0.0
		var cross := 0.0
		if prog < 0.5:
			jab = pow(sin(prog / 0.5 * PI), 0.55)
		else:
			cross = pow(sin((prog - 0.5) / 0.5 * PI), 0.55)
		var bh := Vector2(-20.0 + cross * 112.0, -112.0 + cross * 4.0)
		_arm(back_sh, back_sh.lerp(bh, 0.5) + Vector2(0, 10), bh, 11.0, true)
		var fh := Vector2(64.0 + jab * 52.0, -110.0 + jab * 4.0)
		_arm(sh, sh.lerp(fh, 0.5) + Vector2(0, 10), fh, 11.0, true)
		if jab > 0.72:
			_cc(fh + Vector2(16, 0), 9.0, Color(Pal.BONE, 0.45))
		if cross > 0.72:
			_cc(bh + Vector2(16, 0), 11.0, Color(Pal.BONE, 0.5))
	elif throwing > 0.0:
		var q := 1.0 - throwing / 0.28
		var ta := -2.6 + (1.0 - pow(1.0 - q, 3.0)) * 2.4
		var reach := 48.0 + q * 14.0
		var hd := sh + Vector2.from_angle(ta) * reach
		var el := sh + Vector2.from_angle(ta) * reach * 0.5 + Vector2.from_angle(ta - PI * 0.5) * 9.0
		_arm(sh, el, hd, 11.0, false)
		_dot(hd, 15.0, Pal.STONE)
		_dot(hd + Vector2(-2, 4), 9.0, _skin, 4.0)
	elif has_stick and attacking > 0.0 and not axe_out:
		var sp := 1.0 - attacking / _swing_time
		var ang := 0.0
		var trail := 0.0
		var reach := 49.0
		var smear_col := Color(Pal.BONE, 0.32)
		match _swing_kind:
			"axe0", "axe1":
				# a fast slash: up across the front, then back down across it
				var q := 1.0 - pow(1.0 - sp, 2.0)
				ang = lerpf(1.0, -1.15, q) if _swing_kind == "axe0" else lerpf(-1.15, 1.0, q)
				trail = (1.0 - q) * 0.6 * (-1.0 if _swing_kind == "axe0" else 1.0)
				reach = 56.0
				smear_col = Color("dfeaf2", 0.4)
			"axe2":
				# up over his head, a beat at the top... then the CHOP
				if sp < 0.45:
					ang = lerpf(-0.8, -2.35, sp / 0.45)
					trail = -0.3
				else:
					var q := (sp - 0.45) / 0.55
					ang = -2.35 + (1.0 - pow(1.0 - q, 3.0)) * 3.7
					trail = (1.0 - q) * 0.9
					reach = 49.0 + sin(q * PI) * 22.0
				smear_col = Color("dfeaf2", 0.45)
			"hammer":
				# heaved up and back, slowly... then SMASHED down onto the ground
				if sp < 0.56:
					var q := sp / 0.56
					ang = lerpf(-0.9, -2.75, q * q * (3.0 - 2.0 * q))
					trail = -0.2
				else:
					var q := clampf((sp - 0.56) / 0.2, 0.0, 1.0)
					ang = -2.75 + q * q * 4.1
					trail = (1.0 - q) * 1.1
					reach = 52.0 + sin(q * PI) * 10.0
				smear_col = Color(Pal.EMBER_GLOW, 0.45)
			"homerun":
				# from low behind him, a full sweep round to high in front
				var q := 1.0 - pow(1.0 - sp, 2.2)
				ang = lerpf(2.6, -1.1, q)
				trail = -(1.0 - q) * 0.9
				reach = 60.0
				smear_col = Color(Pal.BONE, 0.45)
			_:
				# the club: a quick overhead bonk
				if sp < 0.24:
					ang = -0.95 - (sp / 0.24) * 0.85
					trail = 0.55
				else:
					var q2 := (sp - 0.24) / 0.76
					ang = -1.80 + (1.0 - pow(1.0 - q2, 2.6)) * 3.05
					trail = (1.0 - q2) * 0.85
					reach = 49.0 + sin(q2 * PI) * 18.0
		var hd := sh + Vector2.from_angle(ang) * reach
		var el := sh + Vector2.from_angle(ang) * reach * 0.5 + Vector2.from_angle(ang - PI * 0.5) * 9.0
		var ca := ang - trail
		var smear := PackedVector2Array()
		var span := 0.75 * signf(trail if trail != 0.0 else 1.0)
		for i in 7:
			smear.append(sh + Vector2.from_angle(ca - span + i * (span / 6.0)) * (reach + 100.0))
		_pl(smear, smear_col, 9.0 if _swing_kind in ["hammer", "homerun", "axe2"] else 7.0, true)
		_arm(sh, el, hd, 13.0, false)
		_club(hd - Vector2.from_angle(ca) * 12.0, hd + Vector2.from_angle(ca) * 112.0, 7.0, 26.0)
		_dot(hd, 11.0, _skin)
	elif has_stick:
		# carries the club on his shoulder; it rides the body's bob and lean
		var lift := -8.0 if air else 0.0
		var hd := Vector2(60, -76.0 + lift)
		_arm(sh, Vector2(68, -96.0 + lift), hd, 10.0, false)
		_club(Vector2(58, -64.0 + lift), Vector2(84, -184.0 + lift), 7.0, 26.0)
		_dot(hd, 11.0, _skin)
	else:
		var na := _pose_arm(sh, 1.0, running, air, ph, speed_k)
		_arm(sh, na[0], na[1], 10.0, true)

	_st(Vector2.ZERO, 0.0, Vector2.ONE)


## The torch arm. Held up and behind his head so the light falls on both
## sides of him; it bobs with the stride but never swings wild. Records where
## the flame is, which is where Night centres his light.
func _torch_arm(sh: Vector2, running: bool, air: bool, ph: float, k: float, rage: float, xf: Transform2D) -> void:
	var hd := Vector2(-60, -150)
	if running:
		hd += Vector2(cos(ph) * 3.0 * k, -absf(sin(ph)) * 4.0 * k)
	elif air:
		hd += Vector2(2, -10)
	else:
		hd.y += sin(anim_t * 1.8) * 1.5
	hd += Vector2(-4, -16) * rage          # thrust up as the anger builds
	var el := sh.lerp(hd, 0.5) + Vector2(-18, 10)
	var butt := hd + Vector2(7, 26)
	var top := hd + Vector2(-9, -60)
	var u := (top - butt).normalized()
	var n := Vector2(-u.y, u.x)
	_shape(PackedVector2Array([butt + n * 4.0, top + n * 6.0, top - n * 6.0, butt - n * 4.0]), C_WOOD, 3.5)
	_oval(top + u * 2.0, 8.5, 13.0, Pal.DEADWOOD_DARK, 3.0, u.angle() + PI * 0.5)
	for i in 3:
		var bp := top - u * (4.0 + i * 5.0)
		_ln(bp + n * 8.0, bp - n * 8.0, C_VINE, 2.5, true)
	_arm(sh, el, hd, 10.0, false)
	_dot(hd, 10.0, _skin)
	var base := top + u * 6.0
	if torch_fuel > 0.0:
		var h := (30.0 + 36.0 * torch_fuel) * (1.0 + 0.7 * rage)
		var sway := sin(anim_t * 9.0) * 5.0 + sin(anim_t * 15.0) * 2.5 - k * 14.0 + wind * facing / 10.0
		_flame(base, 17.0, h, sway, Color(Pal.EMBER_GLOW, 0.85))
		_flame(base + Vector2(0, 2), 12.0, h * 0.78, sway * 0.8, Pal.FLAME)
		_flame(base + Vector2(0, 4), 6.5, h * 0.45, sway * 0.5, Pal.FLAME_CORE)
		_torch_tip = xf * (base + Vector2(sway * 0.3, -h * 0.35))
	else:
		# out: a red ember and a thread of smoke
		var e := 0.5 + 0.5 * sin(anim_t * 3.0)
		_cc(base, 5.0, Color(Pal.EMBER_GLOW, 0.5 + 0.4 * e))
		for i in 3:
			var q := fmod(anim_t * 0.6 + i / 3.0, 1.0)
			_cc(base + Vector2(sin(q * 6.0 + i) * 6.0, -10.0 - q * 50.0), 4.0 + q * 7.0, Color(Pal.ASH, 0.35 * (1.0 - q)))
		_torch_tip = xf * base


## A teardrop of flame: round at the base, drawn to a swaying point.
func _flame(base: Vector2, w: float, h: float, sway: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var a := PI * (i / 8.0)
		pts.append(base + Vector2(cos(a) * w, sin(a) * w * 0.8))
	pts.append(base + Vector2(-w * 0.8 + sway * 0.3, -h * 0.35))
	pts.append(base + Vector2(sway, -h))
	pts.append(base + Vector2(w * 0.7 + sway * 0.4, -h * 0.4))
	_pg(pts, col)


## Level 2: his first hide. A rough wrap cut from a pelt, ragged at the hem.
func _hide_loincloth(k: float) -> void:
	var sw := -k * 6.0 + sin(anim_t * 2.0) * 1.2
	var hem := [Vector2(40, -40), Vector2(31, -34), Vector2(22, -38), Vector2(13, -31),
		Vector2(3, -36), Vector2(-7, -30), Vector2(-16, -35), Vector2(-24, -32), Vector2(-29, -40)]
	var pts := PackedVector2Array([Vector2(-27, -74), Vector2(35, -74)])
	for i in hem.size():
		var h: Vector2 = hem[i]
		pts.append(h + Vector2(sw + sin(anim_t * 2.6 + i) * 0.8, 0))
	var hide := Pal.HIDE
	var spots := Pal.HIDE_DARK
	if skin in ["wolf_pelt", "wolf_hood"]:
		hide = Pal.WOLF
		spots = Pal.WOLF_DARK
	elif skin == "ember_paint":
		hide = Color("9a4a22")
		spots = Color("4a2414")
	elif skin == "bear_cloak":
		hide = Color("6b4a2e")
		spots = Color("45301c")
	elif skin == "firekeeper":
		hide = Color("c49a64")
		spots = Color("8a6a3c")
	_shape(pts, hide, 3.5)
	_oval(Vector2(-8, -54), 7.0, 4.5, spots, 0.0, 0.3)
	_oval(Vector2(20, -48), 5.0, 3.5, spots, 0.0, -0.2)
	for i in 8:
		var fx := -24.0 + i * 8.0 + sw
		_ln(Vector2(fx, -37), Vector2(fx - 2, -29), Pal.WOLF_BELLY if skin in ["wolf_pelt", "wolf_hood"] else spots, 2.5, true)


## A little bunch of grapes (the health fruit), at the given size.
func _grapes(at: Vector2, k: float) -> void:
	_ln(at + Vector2(0, -14) * k, at + Vector2(3, -22) * k, Color("6b4a2a"), 3.0 * k)
	for g in [Vector2(-6, -8), Vector2(0, -9), Vector2(6, -8), Vector2(-3, -2), Vector2(3, -2), Vector2(0, 4)]:
		_cc(at + g * k, 4.6 * k, Color("3e1a52"))
		_cc(at + g * k, 3.8 * k, Color("7b3aa0"))
		_cc(at + (g + Vector2(-1.3, -1.3)) * k, 1.3 * k, Color("d9b8ef"))


## The sooty face after a scorching: black with soot, just the whites of
## his eyes showing, fading over its last second.
func _soot_face() -> void:
	if soot_t <= 0.0:
		return
	var a := clampf(soot_t, 0.0, 1.0)
	_pg(_oval_pts(Vector2(4, -150), 23.0, 20.0), Color(0.12, 0.1, 0.09, 0.78 * a))
	for e in [Vector2(-7, -151), Vector2(15, -151)]:
		_cc(e, 5.0, Color(1, 1, 1, a))
		_cc(e + Vector2(1.5, 0.5), 2.2, Color(0.1, 0.08, 0.06, a))


## Little flames licking at the seat of his loincloth while he panics.
func _seat_flames() -> void:
	if scorch_t <= 0.0:
		return
	for i in 3:
		var x := -30.0 + i * 11.0
		var h := 26.0 + sin(anim_t * 30.0 + i * 2.0) * 7.0
		_pg(_seat_flame_pts(Vector2(x, -52), 9.0, h, 6.0), Color(1.0, 0.55, 0.15, 0.95))
		_pg(_seat_flame_pts(Vector2(x, -52), 5.0, h * 0.6, 4.0), Color(1.0, 0.9, 0.5))


## A small flame: a teardrop rising from `base`, `w` wide and `h` tall, its tip leaning by `lean`.
func _seat_flame_pts(base: Vector2, w: float, h: float, lean: float) -> PackedVector2Array:
	return PackedVector2Array([base + Vector2(-w, 0), base + Vector2(-w * 0.8, -h * 0.45), base + Vector2(lean, -h),
		base + Vector2(w * 0.8, -h * 0.45), base + Vector2(w, 0), base + Vector2(0, h * 0.12)])


## ------------------------------------------------------------------ costumes
## The fire-discovery costumes, drawn in layers: what hangs behind him, what
## is painted or worn on his chest and face, what sits on his head, and what
## hangs at his belt.
func _costume_back() -> void:
	match skin:
		"wolf_hood":
			# the wolf's pelt hanging down his back from the hood
			_shape(PackedVector2Array([Vector2(-20, -176), Vector2(-40, -150), Vector2(-54, -110), Vector2(-56, -74), Vector2(-40, -80),
				Vector2(-30, -120), Vector2(-8, -160)]), Pal.WOLF, 3.5)
			for k in 4:
				_ln(Vector2(-46 + k * 3, -120 + k * 10), Vector2(-52 + k * 2, -112 + k * 10), Pal.WOLF_DARK, 2.5, true)
		"bear_cloak":
			# a heavy bear-fur cloak over the shoulders, down to the knees
			# the cloak hangs down his back to the knees, swaying a little
			var fl := sin(anim_t * 2.0) * 2.0
			_shape(PackedVector2Array([Vector2(-46, -134), Vector2(-16, -138), Vector2(-14, -100), Vector2(-26, -64), Vector2(-36, -30 + fl),
				Vector2(-70, -26 + fl), Vector2(-64, -70 + fl), Vector2(-58, -112)]), Color("6b4a2e"), 3.5)
			for k in 6:
				var x := -66.0 + k * 5.0
				_ln(Vector2(x, -36 + fl), Vector2(x - 3.0, -24 + fl), Color("45301c"), 2.5, true)


func _costume_chest() -> void:
	match skin:
		"ember_paint":
			# charcoal-edged ochre flames rising from the belt up the chest
			for f in [[-24.0, 34.0], [4.0, 44.0], [30.0, 32.0]]:
				var x: float = f[0]
				var h: float = f[1]
				var flick := sin(anim_t * 3.0 + x) * 1.5
				var pts := PackedVector2Array([Vector2(x - 9, -72), Vector2(x - 6, -72 - h * 0.5), Vector2(x - 2 + flick, -72 - h),
					Vector2(x + 2, -72 - h * 0.6), Vector2(x + 5, -72 - h * 0.75), Vector2(x + 9, -72)])
				_shape(pts, Color("d9822b"), 2.5)
				_pg(PackedVector2Array([Vector2(x - 4, -72), Vector2(x - 1 + flick, -72 - h * 0.6), Vector2(x + 4, -72)]), Color("f3c14f"))
		"bear_cloak":
			# a fur mantle over both shoulders, scalloped where the fur ends,
			# fastened at the front with two bear claws
			var mantle := PackedVector2Array([Vector2(-50, -126), Vector2(-32, -142), Vector2(4, -146), Vector2(42, -142), Vector2(60, -126)])
			for k in 10:
				var x := 54.0 - k * 11.0
				mantle.append(Vector2(x, -114.0 if k % 2 == 0 else -120.0))
			_shape(mantle, Color("6b4a2e"), 3.5)
			for k in 7:
				var x := -36.0 + k * 13.0
				_ln(Vector2(x, -136), Vector2(x - 3.0, -126), Color("8a6440"), 2.5, true)
			for cx in [-2.0, 10.0]:
				_shape(PackedVector2Array([Vector2(cx - 3, -118), Vector2(cx + 3, -118), Vector2(cx + 1, -102)]), Color("efe6d2"), 2.0)
		"firekeeper":
			# ash smeared in two broad stripes across the chest
			_ln(Vector2(-30, -112), Vector2(30, -104), Color(0.8, 0.8, 0.78, 0.55), 6.0, true)
			_ln(Vector2(-26, -100), Vector2(28, -92), Color(0.8, 0.8, 0.78, 0.45), 5.0, true)


func _costume_face() -> void:
	match skin:
		"ember_paint":
			# a band of charcoal across the eyes, ochre dots below it
			_rc(Rect2(-20, -158, 48, 13), Color(0.12, 0.08, 0.06, 0.8))
			for k in 4:
				_cc(Vector2(-12 + k * 10, -141), 2.2, Color("d9822b"))
		"firekeeper":
			# ash stripes on the cheeks
			for sx in [-16.0, 20.0]:
				_ln(Vector2(sx - 4, -146), Vector2(sx + 4, -144), Color(0.85, 0.85, 0.82, 0.8), 2.5, true)
				_ln(Vector2(sx - 4, -140), Vector2(sx + 4, -138), Color(0.85, 0.85, 0.82, 0.8), 2.5, true)


func _costume_head() -> void:
	match skin:
		"wolf_hood":
			# a wolf's head worn over his own: skull cap, snout over the brow,
			# teeth at the fringe, pointed ears, and its eyes above his
			_shape(PackedVector2Array([Vector2(-24, -168), Vector2(-20, -184), Vector2(0, -192), Vector2(26, -188), Vector2(40, -176),
				Vector2(52, -170), Vector2(50, -162), Vector2(30, -164), Vector2(-10, -164)]), Pal.WOLF, 3.5)
			_shape(PackedVector2Array([Vector2(28, -172), Vector2(52, -170), Vector2(50, -162), Vector2(30, -164)]), Pal.WOLF_BELLY, 2.0)
			_cc(Vector2(52, -168), 3.0, Pal.OUTLINE)
			for k in 3:
				var tx := 34.0 + k * 5.0
				_pg(PackedVector2Array([Vector2(tx, -163), Vector2(tx + 3, -163), Vector2(tx + 1.5, -157)]), Color("f4efe2"))
			for e in [[-8.0, -186.0], [14.0, -190.0]]:
				_shape(PackedVector2Array([Vector2(e[0] - 7, e[1] + 2), Vector2(e[0] - 1, e[1] - 18), Vector2(e[0] + 6, e[1] + 1)]), Pal.WOLF_DARK, 2.5)
			_cc(Vector2(30, -178), 2.4, Pal.WOLF_EYE)
		"bear_cloak":
			# the bear's hood: a brown fur cap with round ears
			_shape(PackedVector2Array([Vector2(-26, -164), Vector2(-24, -182), Vector2(-6, -194), Vector2(18, -194), Vector2(34, -182),
				Vector2(34, -166), Vector2(18, -170), Vector2(-8, -170)]), Color("6b4a2e"), 3.5)
			for e in [Vector2(-14, -190), Vector2(24, -192)]:
				_dot(e, 7.5, Color("6b4a2e"), 3.0)
				_cc(e, 3.5, Color("45301c"))
		"firekeeper":
			# a leather headband with a glowing ember charm at the front
			_ln(Vector2(-24, -168), Vector2(32, -170), C_OL, 9.0, true)
			_ln(Vector2(-24, -168), Vector2(32, -170), Color("a0703c"), 6.0, true)
			var glow := 0.6 + 0.4 * sin(anim_t * 4.0)
			_cc(Vector2(28, -170), 11.0, Color(Pal.EMBER_GLOW, 0.3 * glow))
			_dot(Vector2(28, -170), 5.0, Color("f08a24").lerp(Color("ffd36b"), glow), 2.0)
			# two feathers tucked in at the back
			for k in 2:
				var fx := -20.0 - k * 6.0
				_shape(PackedVector2Array([Vector2(fx, -168), Vector2(fx - 8, -196 + k * 6), Vector2(fx - 2, -194 + k * 6), Vector2(fx + 3, -170)]),
					Color("e8e0cc") if k == 0 else Color("c0392b"), 2.0)


func _costume_belt() -> void:
	if skin == "firekeeper":
		# a little leather pouch of live embers, glowing through the seams
		var glow := 0.6 + 0.4 * sin(anim_t * 3.3 + 1.0)
		_shape(PackedVector2Array([Vector2(26, -70), Vector2(40, -70), Vector2(42, -54), Vector2(24, -54)]), Color("8a5a2c"), 2.5)
		_ln(Vector2(28, -62), Vector2(38, -62), Color("ffb347", glow), 2.5, true)
		_cc(Vector2(33, -58), 7.0, Color(Pal.EMBER_GLOW, 0.25 * glow))


## The snarl: jaw dropped, both rows of teeth bared.
func _roar() -> void:
	var pts := _oval_pts(Vector2(4, -134), 10.0, 7.5)
	_pg(pts, C_MOUTH)
	_rc(Rect2(-4, -141, 16, 3.5), C_EYE)
	_rc(Rect2(-3, -130.5, 14, 3.0), C_EYE)
	var ring := PackedVector2Array(pts)
	ring.append(pts[0])
	_pl(ring, C_OL, 2.5, true)


## Breath snorting from the nose while it builds, and sparks drawn in toward
## his chest; at the release they are gone into the burst.
func _rage_marks(rage: float, roaring: bool) -> void:
	if roaring:
		return
	for i in 3:
		var q := fmod(anim_t * 2.6 + i / 3.0, 1.0)
		_cc(Vector2(14.0 + q * 30.0, -144.0 - q * 14.0), 5.0 + q * 8.0, Color(Pal.BONE, 0.5 * (1.0 - q) * rage))
	for i in 10:
		var q := fmod(anim_t * 1.7 + i / 10.0, 1.0)
		var a := i * 0.63 + anim_t * 3.0
		var p := Vector2(4, -100) + Vector2.from_angle(a) * 200.0 * (1.0 - q)
		_cc(p, 5.0 + 4.0 * q, Color(Pal.FLAME, rage * q))
		_cc(p, 2.5 + 2.0 * q, Color(Pal.FLAME_CORE, rage * q))


## Where a foot is at a given point in the stride. It travels BACKWARDS while on
## the ground (pushing him forward) and swings forward while lifted. Get that
## the wrong way round and he looks like he is running on ice.
func _run_foot(hip_x: float, phase: float, k: float) -> Vector2:
	var lift := 24.0 * k
	return Vector2(hip_x + 4.0 - cos(phase) * _stride_amp(k), -6.0 - maxf(0.0, sin(phase)) * lift)


## Stride grows with speed up to a limit. Used by BOTH the foot placement and
## the phase rate, which is what keeps a planted foot exactly still on the
## ground: phase advances by distance / stride, so the foot sweeps backwards
## at precisely the speed the body moves forwards.
func _stride_amp(k: float) -> float:
	return STRIDE * clampf(k, 0.55, 1.0)


## Two-bone IK: given hip and foot, find the knee. Always bends forward.
func _knee(hip: Vector2, foot: Vector2, a: float, b: float) -> Vector2:
	var d := clampf(hip.distance_to(foot), absf(a - b) + 0.01, a + b - 0.01)
	var cos_h := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	return hip + Vector2.from_angle((foot - hip).angle() - acos(cos_h)) * a


## The IK bones are long so a full running stride can reach. Standing, that
## same length would have to fold into a much shorter hip-to-foot distance and
## bow the knees — so at rest the leg is simply straight, and the IK knee is
## blended in only as he moves, jumps or lands.
func _leg(hip: Vector2, foot: Vector2, bend: float) -> void:
	var straight := hip.lerp(foot, 0.5) + Vector2(1.5, 0)
	var knee := straight.lerp(_knee(hip, foot, 36.0, 36.0), bend)
	_limb([hip, knee, foot], [19.0, 16.0])
	_oval(foot + Vector2(4, 3), 17.0, 8.0, _skin)
	_seg_hair(knee, foot, 2)


## Elbow and hand for an arm that is not doing anything else. side is -1 for
## the far arm and +1 for the near one; running, the two swing out of phase,
## each paired with the opposite leg the way a real runner's are.
func _pose_arm(sh: Vector2, side: float, running: bool, air: bool, phase: float, k: float) -> Array:
	if air:
		if velocity.y < -150.0:
			return [sh + Vector2(20.0 * side, -18.0), sh + Vector2(24.0 * side, -44.0)]
		if velocity.y > 180.0:
			var fl := sin(anim_t * 22.0) * 5.0 * side
			return [sh + Vector2(26.0 * side, -12.0), sh + Vector2(34.0 * side, -36.0 + fl)]
		return [sh + Vector2(28.0 * side, 4.0), sh + Vector2(46.0 * side, 2.0)]
	if running:
		var sw := cos(phase) * k * side
		var ua := PI * 0.5 - sw * 0.95
		var el := sh + Vector2.from_angle(ua) * 28.0
		return [el, el + Vector2.from_angle(ua - 1.35) * 24.0]
	var br := sin(anim_t * 1.8) * 1.2
	return [sh + Vector2(15.0 * side, 24.0), sh + Vector2(9.0 * side, 48.0 + br)]


func _eye(c: Vector2, wince: bool, blink: bool) -> void:
	if wince:
		_ln(c + Vector2(-6, -2), c + Vector2(6, 1), C_OL, 3.0, true)
		return
	var ry := 0.6 if blink else 3.4
	_oval(c, 6.0, ry, C_EYE, 3.0)
	if not blink:
		_cc(c + Vector2(1.6, 0.4), 2.6, Color("1a0f08"))
		_cc(c + Vector2(0.8, -0.4), 0.9, Color.WHITE)


## Clenched teeth with the corners pulled down.
func _mouth() -> void:
	var w := 16.0
	var h := 5.0
	var x0 := 4.0 - w * 0.5
	_rc(Rect2(x0, -139, w, h), C_EYE, true)
	_rc(Rect2(x0, -139, w, h), C_OL, false, 2.5)
	for i in range(1, 4):
		var tx := x0 + i * w / 4.0
		_ln(Vector2(tx, -139), Vector2(tx, -139.0 + h), C_OL, 1.5, true)
	_ln(Vector2(x0 - 4, -133), Vector2(x0, -138), C_OL, 3.0, true)
	_ln(Vector2(x0 + w + 4, -133), Vector2(x0 + w, -138), C_OL, 3.0, true)


func _oval_pts(c: Vector2, rx: float, ry: float, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cr := cos(rot)
	var sr := sin(rot)
	for i in 22:
		var a := TAU * i / 22.0
		var v := Vector2(cos(a) * rx, sin(a) * ry)
		pts.append(c + Vector2(v.x * cr - v.y * sr, v.x * sr + v.y * cr))
	return pts


func _club(p0: Vector2, p1: Vector2, w0: float, w1: float) -> void:
	if axe_out:
		return
	if hammer:
		_hammer(p0, p1)
		return
	if axe:
		_axe(p0, p1)
		return
	## Thin at the grip, thickening all the way up: cut from a branch with the
	## root end kept, so most of the weight sits in the head.
	var d := p1 - p0
	var u := d.normalized()
	var nrm := Vector2(-u.y, u.x)
	var n := 10
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n + 1:
		var sf := float(i) / n
		var w := (w0 + (w1 - w0) * pow(sf, 1.4)) * 0.5
		var bl := sin(i * 2.3) * 2.0 if sf > 0.5 else 0.0
		var br := cos(i * 1.9) * 2.0 if sf > 0.5 else 0.0
		left.append(p0 + d * sf + nrm * (w + bl))
		right.append(p0 + d * sf - nrm * (w + br))
	var pts := PackedVector2Array(left)
	pts.append_array(_quad(left[n], p1 + u * w1 * 0.9, right[n], 6))
	for i in range(n - 1, -1, -1):
		pts.append(right[i])
	_shape(pts, C_WOOD)
	var grain := PackedVector2Array()
	for i in range(2, n + 1):
		var sf := float(i) / n
		grain.append(p0 + d * sf + nrm * ((w0 + (w1 - w0) * pow(sf, 1.4)) * 0.5 * -0.3))
	_pl(grain, C_WOOD2, 3.0, true)
	for q in [[0.62, 1.0], [0.83, -1.0]]:
		var sf: float = q[0]
		var k: Vector2 = p0 + d * sf + nrm * ((w0 + (w1 - w0) * pow(sf, 1.4)) * 0.5 * float(q[1]) * 0.85)
		_dot(k, 4.5, C_WOOD2, 2.5)



## The Flint Axe: a straight haft, and a blade of knapped flint — blue-grey,
## flaked to an edge — lashed into it with sinew.
func _axe(p0: Vector2, p1: Vector2) -> void:
	var d := (p1 - p0).normalized()
	var n := Vector2(-d.y, d.x)
	_shape(PackedVector2Array([p0 + n * 4.5, p1 + n * 5.0, p1 - n * 5.0, p0 - n * 4.5]), C_WOOD, 3.0)
	var hc := p1 - d * 14.0
	var blade := PackedVector2Array([hc + n * 4.0 - d * 12.0, hc + n * 30.0 - d * 20.0, hc + n * 40.0 - d * 2.0, hc + n * 34.0 + d * 18.0,
		hc + n * 4.0 + d * 12.0])
	_shape(blade, Color("6f7f8f"), 3.0)
	# the flake scars, and the pale fresh edge
	_pg(PackedVector2Array([hc + n * 10.0 - d * 8.0, hc + n * 26.0 - d * 14.0, hc + n * 22.0 + d * 2.0]), Color("8c9cab"))
	_pg(PackedVector2Array([hc + n * 12.0 + d * 8.0, hc + n * 24.0 + d * 4.0, hc + n * 28.0 + d * 14.0]), Color("5c6b7a"))
	_ln(hc + n * 30.0 - d * 20.0, hc + n * 40.0 - d * 2.0, Color("c9d6e2"), 2.5, true)
	_ln(hc + n * 40.0 - d * 2.0, hc + n * 34.0 + d * 18.0, Color("c9d6e2"), 2.5, true)
	# lashed on with sinew
	for k in 3:
		var q := hc + d * (-8.0 + k * 7.0)
		_ln(q + n * 7.0 - d * 3.0, q - n * 7.0 + d * 3.0, C_VINE, 3.0, true)


## The Firestone Hammer: a long haft bound with sinew, a heavy stone head,
## and the Firestone set in its face, glowing — brighter as the slam charges.
func _hammer(p0: Vector2, p1: Vector2) -> void:
	var d := (p1 - p0).normalized()
	var n := Vector2(-d.y, d.x)
	var charge_k := clampf(slam_charge / SLAM_READY, 0.0, 1.0) if slam_charge >= 0.0 else 0.0
	# the haft
	_shape(PackedVector2Array([p0 + n * 4.5, p1 - d * 20.0 + n * 5.5, p1 - d * 20.0 - n * 5.5, p0 - n * 4.5]), C_WOOD, 3.0)
	for k in 3:
		var q := p0 + d * (10.0 + k * 7.0)
		_ln(q + n * 6.0, q - n * 6.0, C_VINE, 3.0, true)
	# the head: a heavy block of stone across the end of the haft
	var hc := p1 - d * 6.0
	var head := PackedVector2Array([hc + n * 32.0 - d * 20.0, hc + n * 36.0 + d * 14.0, hc - n * 30.0 + d * 18.0, hc - n * 34.0 - d * 16.0])
	if charge_k > 0.0:
		_cc(hc, 40.0 + 30.0 * charge_k, Color(Pal.FLAME, 0.25 * charge_k))
	_shape(head, Color("7b7469"), 3.5)
	_shape(PackedVector2Array([hc + n * 30.0 - d * 16.0, hc + n * 32.0 + d * 4.0, hc - n * 26.0 + d * 8.0, hc - n * 28.0 - d * 12.0]), Color("948c80"), 0.0)
	_ln(hc + n * 10.0 - d * 12.0, hc - n * 4.0 + d * 10.0, Color("5b554c"), 2.5, true)
	# the Firestone, set in the head
	var g := hc + n * 2.0
	var pulse := 0.5 + 0.5 * sin(anim_t * 5.0)
	_cc(g, 14.0 + charge_k * 8.0, Color(Pal.EMBER_GLOW, 0.35 + 0.3 * pulse + 0.3 * charge_k))
	_shape(PackedVector2Array([g + n * 11.0, g + d * 9.0, g - n * 11.0, g - d * 9.0]), Pal.GEM, 2.5)
	_pg(PackedVector2Array([g + n * 6.0, g + d * 4.0, g - n * 2.0]), Pal.GEM_LIGHT)
	# embers drifting off it
	for i in 4:
		var q := fmod(anim_t * 0.9 + i * 0.25, 1.0)
		_cc(hc + Vector2(sin(i * 2.1 + anim_t * 2.0) * 16.0, -q * 70.0), 3.5 * (1.0 - q) + 0.8, Color(Pal.FLAME_CORE, 1.0 - q))
	if charge_k > 0.0:
		# sparks drawn in toward the gem as the charge builds
		for i in 8:
			var q := fmod(anim_t * 2.2 + i / 8.0, 1.0)
			var p := g + Vector2.from_angle(i * 0.79 + anim_t * 4.0) * 90.0 * (1.0 - q)
			_cc(p, 3.5 + 3.0 * q, Color(Pal.FLAME_CORE, q * charge_k))


func _leaf(a: Vector2, length: float, width: float, ang: float, col: Color) -> void:
	var dirv := Vector2(sin(ang), cos(ang))
	var tip := a + dirv * length
	var mid := a + dirv * length * 0.45
	var nrm := Vector2(-dirv.y, dirv.x)
	var pts := PackedVector2Array([a])
	pts.append_array(_quad(a, mid + nrm * width, tip, 6))
	pts.append_array(_quad(tip, mid - nrm * width, a, 6))
	pts.remove_at(pts.size() - 1)
	_shape(pts, col, 3.5)
	_ln(a, a + dirv * length * 0.85, Color(0.08, 0.2, 0.06, 0.55), 2.5, true)


func _arm(sh: Vector2, el: Vector2, hd: Vector2, bicep: float, fist: bool) -> void:
	_limb([sh, el, hd], [16.0, 16.0])
	_oval((sh + el) * 0.5, sh.distance_to(el) * 0.46, bicep, _skin, 3.5, (el - sh).angle())
	_seg_hair(el, hd, 3)
	_dot(sh, 15.0, _skin)
	if fist:
		_dot(hd, 10.0, _skin)


## Outline pass first, then fill, with round joints, so segments merge cleanly.
func _limb(p: Array, w: Array) -> void:
	var dark := _skin.darkened(0.34)
	for i in p.size() - 1:
		var ow: float = w[i] + 5.0
		_ln(p[i], p[i + 1], dark, ow, true)
		_cc(p[i], ow * 0.5, dark)
		_cc(p[i + 1], ow * 0.5, dark)
	for i in p.size() - 1:
		var fw: float = float(w[i]) * 0.88
		var off: Vector2 = LIGHT * float(w[i]) * 0.13
		_ln(p[i] + off, p[i + 1] + off, _skin, fw, true)
		_cc(p[i] + off, fw * 0.5, _skin)
		_cc(p[i + 1] + off, fw * 0.5, _skin)


func _ticks(list: Array) -> void:
	for q in list:
		_ln(Vector2(q[0], q[1]), Vector2(q[2], q[3]), C_HAIR, 3.0, true)


func _seg_hair(a: Vector2, b: Vector2, n: int) -> void:
	for i in range(1, n + 1):
		var p := a.lerp(b, float(i) / (n + 1))
		_ln(p + Vector2(-3, -3), p + Vector2(2, 3), C_HAIR, 3.0, true)


func _lit(pts: PackedVector2Array, amount: float = 0.87) -> PackedVector2Array:
	var mid := Vector2.ZERO
	for p in pts:
		mid += p
	mid /= float(pts.size())
	var span := 0.0
	for p in pts:
		span = maxf(span, p.distance_to(mid))
	var push := LIGHT * minf(5.0, span * 0.10)
	var out := PackedVector2Array()
	for p in pts:
		out.append(mid + (p - mid) * amount + push)
	return out


func _shape(pts: PackedVector2Array, fill: Color, w: float = OLW) -> void:
	if _bb != null:
		_bb.poly_pair(pts, fill.darkened(0.30), _lit(pts), fill)
	else:
		_pg(pts, fill.darkened(0.30))
		_pg(_lit(pts), fill)
	if w > 0.0:
		var ring := PackedVector2Array(pts)
		ring.append(pts[0])
		_pl(ring, fill.darkened(0.60), w * 0.62, true)


func _dot(c: Vector2, r: float, fill: Color, w: float = OLW) -> void:
	_cc(c, r, fill.darkened(0.30))
	_cc(c + LIGHT * r * 0.16, r * 0.86, fill)
	if w > 0.0:
		_ac(c, r, 0.0, TAU, 20, fill.darkened(0.60), w * 0.62, true)


func _oval(c: Vector2, rx: float, ry: float, fill: Color, w: float = OLW, rot: float = 0.0) -> void:
	_shape(_oval_pts(c, rx, ry, rot), fill, w)


## Samples a quadratic curve. Leaves out the start point unless asked, so
## consecutive curves can be chained without doubling up vertices.
func _quad(a: Vector2, c: Vector2, b: Vector2, n: int = 8, with_start: bool = false) -> PackedVector2Array:
	var out := PackedVector2Array()
	if with_start:
		out.append(a)
	for i in range(1, n + 1):
		var tq := float(i) / n
		out.append(a.lerp(c, tq).lerp(c.lerp(b, tq), tq))
	return out
