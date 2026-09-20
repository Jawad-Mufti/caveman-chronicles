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
var _swing_hits: Array = []
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
	var box := RectangleShape2D.new()
	box.size = Vector2(62, 70)          ## reaches from the floor to over his head
	_hit_shape.shape = box
	_hit_shape.position = Vector2(36, -34)
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
	_hit_shape.position.x = 36.0 * facing

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
		attack_cd = 0.38
		attacking = SWING_TIME
		_swing_hits.clear()
	_attack_prev = attack_now

	# The club connects across the WHOLE swing, not on one frame. Checking only
	# at the keypress meant anything that was not already touching him was a miss.
	if attacking > 0.0:
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

	move_and_slide()


func _process(_delta: float) -> void:
	if invuln > 0.0 and fmod(invuln * 12.0, 1.0) < 0.5:
		modulate.a = 0.35
	else:
		modulate.a = 1.0
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


func fx(v: Vector2) -> Vector2:
	return Vector2(v.x * facing, v.y)


func _pts(arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in arr:
		out.append(fx(v))
	return out


func _draw() -> void:
	var c := Pal.CHARCOAL
	if dead:
		draw_set_transform(Vector2.ZERO, facing * PI * 0.5, Vector2.ONE)

	var moving := absf(velocity.x) > 10.0 and is_on_floor()
	var s := sin(anim_t * 13.0) if moving else 0.0
	var air := not is_on_floor()

	# legs
	var la := Vector2(-6.0 + s * 9.0, 0.0)
	var lb := Vector2(6.0 - s * 9.0, 0.0)
	if air:
		la = Vector2(-10, -8)
		lb = Vector2(9, 1)
	draw_line(fx(Vector2(-4, -24)), fx(la), c, 7.0)
	draw_line(fx(Vector2(4, -24)), fx(lb), c, 7.0)

	# torso, slightly hunched forward
	draw_polygon(_pts([Vector2(-8, -46), Vector2(11, -44), Vector2(12, -22), Vector2(-11, -22)]), PackedColorArray([c]))

	# head and hair
	draw_circle(fx(Vector2(4, -56)), 10.0, c)
	draw_polygon(_pts([Vector2(-7, -60), Vector2(-3, -71), Vector2(2, -63), Vector2(7, -72), Vector2(12, -61)]), PackedColorArray([c]))
	# brow ridge
	draw_line(fx(Vector2(6, -58)), fx(Vector2(14, -57)), c, 4.0)
	# eye
	draw_circle(fx(Vector2(10, -55)), 1.8, Pal.OCHRE)

	# back arm
	draw_line(fx(Vector2(-4, -42)), fx(Vector2(-12.0 - s * 6.0, -26)), c, 6.0)

	# berries tucked at the small of his back: red, small, and well clear of the
	# grey rocks at his waist so the two are never confused
	for i in berries:
		draw_circle(fx(Vector2(-14.0 + i * 4.0, -33)), 2.2, Pal.EMBER)

	# a couple of spare rocks tucked at his waist
	for i in mini(rocks, 3):
		draw_circle(fx(Vector2(-6.0 + i * 6.0, -24)), 3.4, Pal.STONE)

	# front arm. The swing is three beats: cock back, whip through, follow out.
	# A linear sweep reads as a robot arm; anticipation and easing read as weight.
	var ang := 0.0
	var trail := 0.0        ## how far the club lags behind the hand
	var reach := 21.0       ## the arm extends as he commits
	if throwing > 0.0:
		var q := 1.0 - throwing / 0.28
		ang = -2.6 + (1.0 - pow(1.0 - q, 3.0)) * 2.4
		reach = 19.0 + q * 5.0
	elif attacking > 0.0:
		var sp := 1.0 - attacking / SWING_TIME    # 0 at the start, 1 at the end
		if sp < 0.24:
			# anticipation: he pulls it further back before anything moves forward
			ang = -0.95 - (sp / 0.24) * 0.85
			trail = 0.55
			reach = 19.0
		else:
			var q2 := (sp - 0.24) / 0.76
			var eased := 1.0 - pow(1.0 - q2, 2.6)   # fast out of the wind-up, settling late
			ang = -1.80 + eased * 3.05
			trail = (1.0 - q2) * 0.85               # the head of the club drags, then whips past
			reach = 19.0 + sin(q2 * PI) * 7.0       # the arm straightens through the strike
	elif has_stick:
		ang = -0.55 + s * 0.12                       # rests on the shoulder, breathing
	else:
		ang = 0.35 + s * 0.45
	var shoulder := Vector2(8, -42)
	var hand := shoulder + Vector2(cos(ang), sin(ang)) * reach

	# smear of the club head through the arc, so a fast swing still reads
	if attacking > 0.0:
		var smear := PackedVector2Array()
		for i in 7:
			var a2 := ang - trail - 0.75 + i * (0.75 / 6.0)
			smear.append(fx(shoulder + Vector2(cos(a2), sin(a2)) * (reach + 32.0)))
		draw_polyline(smear, Color(Pal.BONE, 0.30), 3.0)

	draw_line(fx(shoulder), fx(hand), c, 6.0)
	if has_stick:
		# knotted club. Drawn on the lagging angle, not the hand angle.
		var ca := ang - trail
		var grip := shoulder + Vector2(cos(ca), sin(ca)) * (reach - 6.0)
		var tip := shoulder + Vector2(cos(ca), sin(ca)) * (reach + 34.0)
		draw_line(fx(grip), fx(tip), Pal.OCHRE_DEEP, 7.0)
		draw_circle(fx(tip), 7.5, Pal.OCHRE_DARK)
		draw_circle(fx(tip + Vector2(-3, -3)), 2.5, Pal.OCHRE)
	if throwing > 0.0:
		draw_circle(fx(hand), 7.0, Pal.STONE)
