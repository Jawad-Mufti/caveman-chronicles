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
var touch := {"left": false, "right": false, "jump": false, "attack": false, "heal": false, "throw": false}

var _jump_prev := false
var _attack_prev := false
var _heal_prev := false
var _throw_prev := false
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
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1

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


func _physics_process(delta: float) -> void:
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
	throwing = maxf(throwing - delta, 0.0)

	var dir := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT) or touch["left"]:
		dir -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT) or touch["right"]:
		dir += 1.0
	if dir != 0.0:
		facing = int(signf(dir))
	var _reach := CLUB_REACH if has_stick else FIST_REACH
	if not has_stick and attacking > 0.0 and _punch_beat == 1:
		_reach = FIST_REACH + 9.0
	_hit_shape.position.x = _reach * facing
	_hit_shape.position.y = -34.0 if has_stick else -30.0

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
		if has_stick:
			attack_cd = 0.38
			attacking = SWING_TIME
		else:
			attack_cd = 0.46
			attacking = PUNCH_TIME
		_punch_beat = 0
		_swing_hits.clear()
	_attack_prev = attack_now

	# The club connects across the WHOLE swing, not on one frame. Checking only
	# at the keypress meant anything that was not already touching him was a miss.
	if attacking > 0.0:
		if not has_stick:
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

	var heal_now: bool = Input.is_physical_key_pressed(KEY_E) \
		or Input.is_physical_key_pressed(KEY_L) \
		or touch["heal"]
	if heal_now and not _heal_prev:
		use_poultice()
	_heal_prev = heal_now

	var pre_vy := velocity.y
	move_and_slide()
	var on_floor := is_on_floor()
	if on_floor and not _was_floor and pre_vy > 200.0:
		_land = LAND_TIME
		_land_amt = clampf(pre_vy / 1400.0, 0.3, 1.0)
	_was_floor = on_floor


func _process(delta: float) -> void:
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
	var dmg := 3 if has_stick else 1
	for area in _hitbox.get_overlapping_areas():
		if not area.has_method("take_hit"):
			continue
		var id := area.get_instance_id()
		if _swing_hits.has(id):
			continue
		_swing_hits.append(id)
		area.take_hit(dmg, facing)


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
	if invuln > 0.0 or dead:
		return
	hp -= amount
	invuln = 1.1
	knock = 0.25
	var away := signf(global_position.x - from_x)
	if away == 0.0:
		away = -float(facing)
	velocity = Vector2(away * 280.0, -340.0)
	hp_changed.emit(hp)
	if hp <= 0:
		dead = true
		died.emit()


## Put back on solid ground after a fall. Costs one health point, but applies
## NO knockback: being flung again while standing at the lip of the same hole
## is how one fall turns into three.
func respawn_at(spot: Vector2) -> void:
	global_position = spot
	velocity = Vector2.ZERO
	knock = 0.0
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


func add_berry() -> bool:
	if berries >= max_berries:
		return false
	berries += 1
	berries_changed.emit(berries)
	return true


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


## ------------------------------------------------------------------ drawing
## He is designed at about 2.6x game size and scaled down in one transform.
## Facing is folded into the same transform (a negative x scale), so none of
## the shapes below need to know which way he is looking.
const ART := 0.38        ## design units -> game pixels. ~186 tall -> ~71 px
const OLW := 5.0         ## outline width in design units (~2 px on screen)

const C_OL := Color("2b1a10")
const C_SKIN := Color("d99a64")
const C_SK2 := Color("bf7c48")
const C_HAIR := Color("3b2414")
const C_LEAF := Color("4a9b3a")
const C_LEAF2 := Color("3a7d2c")
const C_VINE := Color("6b4a22")
const C_WOOD := Color("8b5a2b")
const C_WOOD2 := Color("5e3a1c")
const C_EYE := Color("f4ecd8")
const C_MOUTH := Color("3a1a0e")

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


func _draw() -> void:
	var on_floor := is_on_floor()
	var air := not on_floor and not dead
	var speed_k := clampf(absf(velocity.x) / SPEED, 0.0, 1.0) if on_floor else 0.0
	var running := speed_k > 0.08 and not dead
	var ph := _run_phase
	var boxing := attacking > 0.0 and not has_stick and throwing <= 0.0
	var wince := invuln > 0.8 and not dead

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
	var rot := float(facing) * PI * 0.5 if dead else 0.0
	var base := Transform2D(rot, Vector2(ART * facing * sx, ART * sy), 0.0, Vector2.ZERO)

	# ---- pelvis: rises through each stride, sinks on a landing, leans into a run
	var bob := land_k * 9.0
	var lean := 0.0
	if running:
		bob -= absf(sin(ph)) * 7.0 * speed_k
		lean = 0.14 * speed_k
	elif air:
		lean = 0.06

	# ---- legs, solved with two-bone IK so the knees always bend the right way
	draw_set_transform_matrix(base)
	var hip_b := Vector2(-14, -62.0 + bob)
	var hip_f := Vector2(22, -62.0 + bob)
	# standing: feet planted straight under the hips
	var foot_b := Vector2(-16, -6)
	var foot_f := Vector2(24, -6)
	var bend := 0.0
	if air:
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
	_leg(hip_b, foot_b, bend)
	_leg(hip_f, foot_f, bend)

	# ---- everything above the waist leans and bobs as one piece
	var upper := base * Transform2D(lean, Vector2(0, -62.0 + bob)) * Transform2D(0.0, Vector2(0, 62))
	draw_set_transform_matrix(upper)

	_shape(PackedVector2Array(MANE), C_HAIR)
	_oval(Vector2(4, -130), 17.0, 10.0, C_SKIN)
	var torso := PackedVector2Array([Vector2(-46, -122)])
	torso.append_array(_quad(Vector2(-46, -122), Vector2(4, -138), Vector2(54, -122)))
	torso.append_array(_quad(Vector2(54, -122), Vector2(44, -94), Vector2(30, -68)))
	torso.append(Vector2(-22, -68))
	torso.append_array(_quad(Vector2(-22, -68), Vector2(-36, -94), Vector2(-46, -122)))
	torso.remove_at(torso.size() - 1)
	_shape(torso, C_SKIN)
	draw_polyline(_quad(Vector2(-32, -114), Vector2(-14, -100), Vector2(2, -108), 8, true), C_SK2, 3.5, true)
	draw_polyline(_quad(Vector2(6, -108), Vector2(22, -100), Vector2(40, -114), 8, true), C_SK2, 3.5, true)
	draw_line(Vector2(4, -100), Vector2(4, -74), C_SK2, 3.0, true)
	for yy in [-94.0, -86.0, -78.0]:
		draw_line(Vector2(-6, yy), Vector2(2, yy + 1.0), C_SK2, 3.0, true)
		draw_line(Vector2(6, yy + 1.0), Vector2(14, yy), C_SK2, 3.0, true)
	_ticks([[-4, -114, -6, -108], [3, -116, 2, -109], [10, -113, 12, -107], [-1, -106, -3, -100],
		[6, -106, 7, -100], [2, -100, 3, -94], [-10, -110, -12, -104], [16, -110, 18, -104]])

	# far arm: pumps against the legs when running
	var back_sh := Vector2(-42, -118)
	if not boxing:
		var fa := _pose_arm(back_sh, -1.0, running, air, ph, speed_k)
		_arm(back_sh, fa[0], fa[1], 10.0, true)

	for i in 6:
		var lx := -21.0 + i * 10.0
		var ang := (i - 2.5) * 0.11 + sin(anim_t * 2.2 + i) * 0.045 - speed_k * 0.18
		_leaf(Vector2(lx, -70), 29.0 + (3.0 if i % 2 == 1 else 0.0), 8.0, ang, C_LEAF2 if i % 2 == 1 else C_LEAF)
	var belt := _quad(Vector2(-25, -71), Vector2(4, -66), Vector2(33, -71), 10, true)
	draw_polyline(belt, C_OL, 12.0, true)
	draw_polyline(belt, C_VINE, 7.0, true)
	for i in 7:
		var bx := -20.0 + i * 8.0
		draw_line(Vector2(bx - 2, -73), Vector2(bx + 2, -68), C_WOOD2, 2.0, true)
	for i in berries:
		_dot(Vector2(-30.0 + i * 8.0, -79), 5.0, Pal.EMBER, 2.5)
	for i in mini(rocks, 3):
		_dot(Vector2(36.0 + i * 10.0, -62), 6.5, Pal.STONE, 2.5)

	# ---- head: one steady grumpy expression
	_dot(Vector2(-20, -152), 6.0, C_SKIN, 4.0)
	_dot(Vector2(28, -152), 6.0, C_SKIN, 4.0)
	_oval(Vector2(4, -154), 24.0, 27.0, C_SKIN)
	_shape(PackedVector2Array(BEARD), C_HAIR, 4.0)
	_mouth()
	_oval(Vector2(4, -146), 8.0, 5.0, C_SK2, 3.0)
	draw_circle(Vector2(1, -145), 1.4, C_MOUTH)
	draw_circle(Vector2(7, -145), 1.4, C_MOUTH)
	var blink := fmod(anim_t, 3.7) < 0.12
	_eye(Vector2(-7, -151), wince, blink)
	_eye(Vector2(15, -151), wince, blink)
	# brows set in a permanent V: grumpy is his resting face
	var inner := 9.0 if wince else 5.0
	draw_line(Vector2(-18, -160), Vector2(-2, -160.0 + inner), C_HAIR, 8.0, true)
	draw_line(Vector2(10, -160.0 + inner), Vector2(26, -160), C_HAIR, 8.0, true)
	_shape(PackedVector2Array(FRINGE), C_HAIR, 4.0)

	# ---- the near arm: fists, throw, club swing, club carry, or pumping
	var sh := Vector2(50, -118)
	if boxing:
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
			draw_circle(fh + Vector2(16, 0), 9.0, Color(Pal.BONE, 0.45))
		if cross > 0.72:
			draw_circle(bh + Vector2(16, 0), 11.0, Color(Pal.BONE, 0.5))
	elif throwing > 0.0:
		var q := 1.0 - throwing / 0.28
		var ta := -2.6 + (1.0 - pow(1.0 - q, 3.0)) * 2.4
		var reach := 48.0 + q * 14.0
		var hd := sh + Vector2.from_angle(ta) * reach
		var el := sh + Vector2.from_angle(ta) * reach * 0.5 + Vector2.from_angle(ta - PI * 0.5) * 9.0
		_arm(sh, el, hd, 11.0, false)
		_dot(hd, 15.0, Pal.STONE)
		_dot(hd + Vector2(-2, 4), 9.0, C_SKIN, 4.0)
	elif has_stick and attacking > 0.0:
		var sp := 1.0 - attacking / SWING_TIME
		var ang := 0.0
		var trail := 0.0
		var reach := 49.0
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
		for i in 7:
			smear.append(sh + Vector2.from_angle(ca - 0.75 + i * (0.75 / 6.0)) * (reach + 100.0))
		draw_polyline(smear, Color(Pal.BONE, 0.32), 7.0, true)
		_arm(sh, el, hd, 13.0, false)
		_club(hd - Vector2.from_angle(ca) * 12.0, hd + Vector2.from_angle(ca) * 112.0, 7.0, 26.0)
		_dot(hd, 11.0, C_SKIN)
	elif has_stick:
		# carries the club on his shoulder; it rides the body's bob and lean
		var lift := -8.0 if air else 0.0
		var hd := Vector2(60, -76.0 + lift)
		_arm(sh, Vector2(68, -96.0 + lift), hd, 10.0, false)
		_club(Vector2(58, -64.0 + lift), Vector2(84, -184.0 + lift), 7.0, 26.0)
		_dot(hd, 11.0, C_SKIN)
	else:
		var na := _pose_arm(sh, 1.0, running, air, ph, speed_k)
		_arm(sh, na[0], na[1], 10.0, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
	_oval(foot + Vector2(4, 3), 17.0, 8.0, C_SKIN)
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
		draw_line(c + Vector2(-6, -2), c + Vector2(6, 1), C_OL, 3.0, true)
		return
	var ry := 0.6 if blink else 3.4
	_oval(c, 6.0, ry, C_EYE, 3.0)
	if not blink:
		draw_circle(c + Vector2(1.6, 0.4), 2.6, Color("1a0f08"))
		draw_circle(c + Vector2(0.8, -0.4), 0.9, Color.WHITE)


## Clenched teeth with the corners pulled down.
func _mouth() -> void:
	var w := 16.0
	var h := 5.0
	var x0 := 4.0 - w * 0.5
	draw_rect(Rect2(x0, -139, w, h), C_EYE, true)
	draw_rect(Rect2(x0, -139, w, h), C_OL, false, 2.5)
	for i in range(1, 4):
		var tx := x0 + i * w / 4.0
		draw_line(Vector2(tx, -139), Vector2(tx, -139.0 + h), C_OL, 1.5, true)
	draw_line(Vector2(x0 - 4, -133), Vector2(x0, -138), C_OL, 3.0, true)
	draw_line(Vector2(x0 + w + 4, -133), Vector2(x0 + w, -138), C_OL, 3.0, true)


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
	draw_polyline(grain, C_WOOD2, 3.0, true)
	for q in [[0.62, 1.0], [0.83, -1.0]]:
		var sf: float = q[0]
		var k: Vector2 = p0 + d * sf + nrm * ((w0 + (w1 - w0) * pow(sf, 1.4)) * 0.5 * float(q[1]) * 0.85)
		_dot(k, 4.5, C_WOOD2, 2.5)


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
	draw_line(a, a + dirv * length * 0.85, Color(0.08, 0.2, 0.06, 0.55), 2.5, true)


func _arm(sh: Vector2, el: Vector2, hd: Vector2, bicep: float, fist: bool) -> void:
	_limb([sh, el, hd], [16.0, 16.0])
	_oval((sh + el) * 0.5, sh.distance_to(el) * 0.46, bicep, C_SKIN, 3.5, (el - sh).angle())
	_seg_hair(el, hd, 3)
	_dot(sh, 15.0, C_SKIN)
	if fist:
		_dot(hd, 10.0, C_SKIN)


## Outline pass first, then fill, with round joints, so segments merge cleanly.
func _limb(p: Array, w: Array) -> void:
	for i in p.size() - 1:
		var ow: float = w[i] + 10.0
		draw_line(p[i], p[i + 1], C_OL, ow, true)
		draw_circle(p[i], ow * 0.5, C_OL)
		draw_circle(p[i + 1], ow * 0.5, C_OL)
	for i in p.size() - 1:
		var fw: float = w[i]
		draw_line(p[i], p[i + 1], C_SKIN, fw, true)
		draw_circle(p[i], fw * 0.5, C_SKIN)
		draw_circle(p[i + 1], fw * 0.5, C_SKIN)


func _ticks(list: Array) -> void:
	for q in list:
		draw_line(Vector2(q[0], q[1]), Vector2(q[2], q[3]), C_HAIR, 3.0, true)


func _seg_hair(a: Vector2, b: Vector2, n: int) -> void:
	for i in range(1, n + 1):
		var p := a.lerp(b, float(i) / (n + 1))
		draw_line(p + Vector2(-3, -3), p + Vector2(2, 3), C_HAIR, 3.0, true)


func _shape(pts: PackedVector2Array, fill: Color, w: float = OLW) -> void:
	draw_colored_polygon(pts, fill)
	var ring := PackedVector2Array(pts)
	ring.append(pts[0])
	draw_polyline(ring, C_OL, w, true)


func _dot(c: Vector2, r: float, fill: Color, w: float = OLW) -> void:
	draw_circle(c, r, fill)
	draw_arc(c, r, 0.0, TAU, 24, C_OL, w, true)


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
