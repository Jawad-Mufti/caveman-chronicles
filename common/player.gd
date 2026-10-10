class_name CaveMan
extends CaveManBody
## How the caveman LOOKS: the whole rig drawn in code, in design units, as ONE
## draw call (what he does is common/player_body.gd). Everything here only
## reads his state; nothing in it changes the game.
##
## Where things are:
##   palette + shapes        colours, the mane, beard and fringe
##   one draw call           _draw() and the _ln/_pl/_cc/... batch helpers
##   _paint                  the rig: body, legs (IK), head and face, arms and weapons
##   costumes                skins and their extra pieces
##   parts                   face, limbs, weapons, fur, shading helpers
##   effects                 SUNFIRE aura and flames, the air kicks' light, draw_glow

## ------------------------------------------------------------------ drawing
## He is designed at about 2.6x game size and scaled down in one transform (ART).
## Facing is folded into the same transform (a negative x scale), so none of
## the shapes below need to know which way he is looking.
const OLW := 5.0         ## rim width in design units (~2 px on screen)
## Shapes are drawn twice — a shadow tone, then the base tone pulled toward the
## light — so each form has a shaded edge instead of a flat colour and a black
## line. The sun in the sky sits high and right, so the light comes from there.
const LIGHT := Vector2(0.55, -0.83)

const C_OL := Color("2a211a")
const C_SKIN := Color("c98d63")     ## warm sun-tanned skin (the design sheet, docs/caveman_design.png)
const C_SK2 := Color("a46a46")
const C_HAIR := Color("45302a")      ## dark brown (the sheet's #2A211D, a little lighter: it must read on the night)
const C_HAIR_HI := Color("6e4c3a")   ## lighter strands in it
## The head is drawn bigger than life (like most platformer heroes): the face is
## what reads from far away. Scaled about the neck, mane, face and topknot together.
const HEAD_K := 1.2
const NECK := Vector2(4, -126)
const C_LEOPARD := Color("d9a64e")   ## his leopard-skin loincloth
const C_LEOPARD_SPOT := Color("4a2a14")
const C_LEAF := Color("6a8447")
const C_LEAF2 := Color("55703a")
const C_VINE := Color("6a5535")
const C_WOOD := Color("846141")
const C_WOOD2 := Color("5a4029")
const C_EYE := Color("ece3cd")
const C_MOUTH := Color("33211a")
## The sheet's palette for his clothes: fur, leather, cord, stone.
const C_FUR_DARK := Color("7a4b36")
const C_FUR := Color("b27a52")
const C_FUR_LIGHT := Color("d9b08e")
const C_STONE := Color("8d9196")
const C_CORD := Color("3b2a22")
const C_LEATHER := Color("8a5a3a")
const C_FANG := Color("efe6d2")
var _skin := C_SKIN      ## flushes toward ember while he is winding up the fire

## The mane: a wild shock of spikes swept back off his head, [angle deg, length]
## from MANE_C, going from the front of the crown round the back to the nape.
const MANE_C := Vector2(2, -158)
const MANE_SPIKES := [[-52.0, 36.0], [-76.0, 46.0], [-100.0, 50.0], [-124.0, 50.0], [-148.0, 47.0],
	[-171.0, 43.0], [-194.0, 38.0], [-216.0, 30.0]]
## The beard and the fringe (painted with fur); the face is the original, front on.
const BEARD := [
	Vector2(-19, -144), Vector2(-21, -138), Vector2(-17, -131), Vector2(-12, -124),
	Vector2(-7, -119), Vector2(-1, -123), Vector2(4, -116), Vector2(9, -122),
	Vector2(15, -118), Vector2(20, -125), Vector2(25, -130), Vector2(29, -139),
	Vector2(27, -144), Vector2(20, -142), Vector2(12, -144), Vector2(4, -142),
	Vector2(-4, -144), Vector2(-12, -142),
]
const FRINGE := [
	Vector2(-20, -164), Vector2(-22, -172), Vector2(-14, -180), Vector2(-8, -175),
	Vector2(-1, -184), Vector2(6, -177), Vector2(12, -186), Vector2(18, -178),
	Vector2(26, -176), Vector2(28, -166), Vector2(22, -167), Vector2(15, -171),
	Vector2(8, -168), Vector2(1, -172), Vector2(-6, -168), Vector2(-13, -170),
]
const FACE := Vector2.ZERO      ## (the features could sit toward his facing; front on now)
const FUR := preload("res://common/art/fur.png")
const FUR_GREY := preload("res://common/art/fur_grey.png")
var _hair_off := Vector2.ZERO   ## how far the hair tips trail his motion (a spring)
var _hair_vel := Vector2.ZERO


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
	# the furred shapes (mane, beard, loincloth), textured, each in its place
	# among the rest: the batch is drawn in pieces, cut where each was asked for
	var at := 0
	for f in _furs:
		_bb.draw_range(self, at, f[5])
		at = f[5]
		draw_set_transform_matrix(f[3])
		draw_colored_polygon(f[0], f[1], f[4], f[2])
		var ring: PackedVector2Array = f[0].duplicate()
		ring.append(f[0][0])
		draw_polyline(ring, f[1].darkened(0.62), OLW * 0.62)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	_bb.draw_range(self, at, _bb.points.size())
	_bb = null


## A shape covered in a fur texture (`tex`, tinted `col`), in its place in the
## painting order. The hair is laid on a slant, along the shape.
var _furs: Array = []
func _fur(pts: PackedVector2Array, tex: Texture2D, col: Color, tex_scale := 1.0) -> void:
	if _bb == null:
		_shape(pts, col)
		return
	var uv := PackedVector2Array()
	var ts := tex.get_size() * 0.5 * tex_scale
	for p in pts:
		uv.append(p.rotated(0.75) / ts)
	_furs.append([pts, col, tex, _bb.xf, uv, _bb.points.size()])


## A closed curve rounded through the control points (a quadratic B-spline).
func _smooth(ctrl: Array, n: int = 4) -> PackedVector2Array:
	var out := PackedVector2Array()
	var m := ctrl.size()
	for i in m:
		var a: Vector2 = (ctrl[(i - 1 + m) % m] + ctrl[i]) * 0.5
		var b: Vector2 = (ctrl[i] + ctrl[(i + 1) % m]) * 0.5
		out.append_array(_quad(a, ctrl[i], b, n))
	return out


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
	var on_floor := (is_on_floor() or preview) and not puppet_air
	var air := not on_floor and not dead
	var speed_k := clampf(absf(velocity.x) / SPEED, 0.0, 1.0) if on_floor else 0.0
	var running := speed_k > 0.08 and not dead
	var ph := _run_phase
	var boxing := attacking > 0.0 and not has_stick and throwing <= 0.0 and not _kicking()
	var wince := invuln > 0.8 and not dead
	var tumble := _tumble if air else 0.0
	var spear := _spear * (1.0 - _tumble) if air else 0.0
	# the anger: builds 0 -> 1 through the wind-up, then the snarl
	var rage := 0.0
	var roaring := false
	if fury >= 0.0:
		rage = clampf(fury / FURY_RELEASE, 0.0, 1.0)
		roaring = fury >= FURY_RELEASE
	_sun_k = move_toward(_sun_k, 1.0 if sun_t > 0.0 and not dead else 0.0, get_process_delta_time() * 3.5)
	_skin = C_SKIN.lerp(Pal.EMBER, 0.22 * rage) if rage > 0.0 else C_SKIN
	_hands.clear()
	if sun_t > 0.0:
		_skin = _skin.lerp(Sunfire.GOLD, 0.3 + 0.12 * sin(anim_t * 9.0))
		_paint_sun_aura()

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
		# tumbling: stretched by the rushing air, with a jelly wobble
		sy += (0.07 + sin(anim_t * 19.0) * 0.03) * tumble
		sx -= (0.04 + sin(anim_t * 19.0) * 0.02) * tumble
	var gu := getup if on_floor and not dead else -1.0
	if gu >= 0.0:
		if gu < GETUP_SPLAT:
			# SPLAT: flattened like a pancake, wobbling
			var w := sin(gu * 40.0) * 0.05 * (1.0 - gu / GETUP_SPLAT)
			sx = 1.38 + w
			sy = 0.5 - w
		elif gu < GETUP_FLEX:
			# BOING: back up, stretched tall
			var q := (gu - GETUP_SPLAT) / (GETUP_FLEX - GETUP_SPLAT)
			sx = lerpf(1.38, 1.0, q) - 0.1 * sin(q * PI)
			sy = lerpf(0.5, 1.0, q) + 0.2 * sin(q * PI)
		else:
			# the flex: chest out, a proud little puff
			var q2 := clampf((gu - GETUP_FLEX) / 0.15, 0.0, 1.0)
			sx = 1.0 + 0.05 * q2
			sy = 1.0 + 0.04 * q2
	if _sun_k > 0.0:
		# SUNFIRE: he grows, a pop past full size and back
		var grow := 1.0 + 0.15 * _sun_k + 0.06 * sin(_sun_k * PI)
		sx *= grow
		sy *= grow
	if stomp_state == "dive" or stomp_state == "dash":
		# a meteor: stretched long and thin by the speed
		sx -= 0.12 + 0.04 * stomp_level
		sy += 0.16 + 0.06 * stomp_level
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
	# dead: he topples over backwards onto his back, with a little bounce at the end
	var rot := 0.0
	if dead:
		var dk := clampf(_die_t / DIE_TIME, 0.0, 1.0)
		var back_out := 1.0 + 2.2 * pow(dk - 1.0, 3.0) + 1.2 * pow(dk - 1.0, 2.0)
		rot = -float(facing) * PI * 0.5 * back_out
	var base := Transform2D(rot, Vector2(ART * facing * sx, ART * sy), 0.0, Vector2.ZERO)
	if wall_cling and not is_on_floor() and not dead:
		base.origin.x -= float(facing) * 12.0       # drawn just off the wall he clings to, not sunk into it
	if vine != null and not dead:
		# on a vine the body hangs along it, swinging from the grip
		var grip := Vector2(0, -HANG)
		base = Transform2D(-_vine_a * 0.9, grip) * Transform2D(0.0, -grip) * base
	if stomp_state == "dash" and not dead:
		# the dash: laid out flat, head first, like a thrown spear
		var mid := Vector2(0, -38)
		base = Transform2D(0.0, mid) * Transform2D(float(stomp_dir) * PI * 0.5, Vector2.ZERO) * Transform2D(0.0, -mid) * base
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
		# the whoosh: bright arcs where his head just swept round
		if curl > 0.3:
			var hot := Color(1.0, 0.9, 0.55) if _air_glide else Color(0.85, 0.95, 1.0)
			var head_a := -PI * 0.5 + ang
			for w in 3:
				var a0 := head_a - flip_dir * (0.4 + 0.55 * w)
				var a1 := head_a - flip_dir * 0.1
				_ac(pivot, 52.0 + w * 10.0, minf(a0, a1), maxf(a0, a1), 12, Color(hot, (0.95 - w * 0.25) * curl), 10.0 - w * 2.5)
		# a ball is smaller than a man: squeeze him in while he's curled
		base = Transform2D(0.0, pivot) * Transform2D(ang, Vector2.ONE * (1.0 - 0.14 * curl)) * Transform2D(0.0, -pivot) * base

	var kick_k := -1.0              ## 0 -> 1 through an air kick; -1: not kicking
	if _kicking() and not dead:
		kick_k = 1.0 - attacking / _swing_time
		if _swing_kind == "kick2":
			# the FLASH KICK: a whole backflip, the lead leg held straight out
			var e := kick_k * kick_k * (3.0 - 2.0 * kick_k)
			var kp := Vector2(0, -38)
			base = Transform2D(0.0, kp) * Transform2D(-float(facing) * TAU * e, Vector2.ONE) * Transform2D(0.0, -kp) * base

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
	lean = lerpf(lean, 0.16, spear)                                  # driving forward into the dive
	if attacking > 0.0 and _swing_kind == "ram":
		lean += 0.32                                                  # head down, charging
	if attacking > 0.0 and _swing_kind == "dig" and has_stick:
		# digging: stretched up for the lift, hunched over the blow
		var dp := 1.0 - attacking / _swing_time
		lean += -0.08 if dp < 0.45 else 0.32 * sin(clampf((dp - 0.45) / 0.5, 0.0, 1.0) * PI)
		bob += 0.0 if dp < 0.45 else 10.0 * sin(clampf((dp - 0.45) / 0.5, 0.0, 1.0) * PI)
	if attacking > 0.0 and _swing_kind == "club2" and has_stick:
		# the finisher: rearing back, then thrown forward into the blow
		var fp := 1.0 - attacking / _swing_time
		lean += -0.14 * sin(clampf(fp / 0.45, 0.0, 1.0) * PI * 0.5) if fp < 0.45 else 0.3 * sin(clampf((fp - 0.45) / 0.55, 0.0, 1.0) * PI)
	lean = lerpf(lean, -0.08 + sin(anim_t * 11.0) * 0.17, tumble)   # rocking as he flails
	if fury >= 0.0 and not roaring:
		bob += 7.0 * rage
	if wall_cling and not on_floor:
		bob += 4.0 * sin(anim_t * 22.0)          # heaving himself up with each pull
		lean = 0.12
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
		if vine != null:
			# legs trail the swing, and kick forward when he pumps it
			var swg := clampf(_vine_w / 3.0, -1.0, 1.0) * float(facing)
			foot_f = Vector2(18.0 - 26.0 * swg, -12.0 - 14.0 * absf(swg))
			foot_b = Vector2(-12.0 - 26.0 * swg, -6.0 - 10.0 * absf(swg))
		elif wall_cling:
			# scrambling up the wall: the feet take turns, pushing
			var cl := anim_t * 11.0
			foot_f = Vector2(40, -54.0 + 16.0 * sin(cl))
			foot_b = Vector2(34, -14.0 - 16.0 * sin(cl))
		elif velocity.y < -150.0:
			foot_f = Vector2(42, -36)      # lead knee drives up
			foot_b = Vector2(-32, -12)     # trail leg hangs back
		elif velocity.y < 180.0:
			foot_f = Vector2(34, -28)      # tucked at the top
			foot_b = Vector2(-26, -26)
		else:
			foot_f = Vector2(30, -6)       # reaching for the ground
			foot_b = Vector2(-24, -12)
		if tumble > 0.0:
			# running on thin air, like a cartoon who has just looked down
			var pp := anim_t * 22.0
			foot_f = foot_f.lerp(Vector2(28.0 + cos(pp) * 26.0, -22.0 + sin(pp) * 20.0), tumble)
			foot_b = foot_b.lerp(Vector2(-18.0 + cos(pp + PI) * 26.0, -22.0 + sin(pp + PI) * 20.0), tumble)
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
	if kick_k >= 0.0:
		bend = 1.0
		if _swing_kind == "kick1":
			# the SNAP KICK: knee chambered... then the foot whipped straight up over his head
			var up := sin(clampf(kick_k / 0.55, 0.0, 1.0) * PI * 0.5) * (1.0 - 0.45 * clampf((kick_k - 0.7) / 0.3, 0.0, 1.0))
			foot_f = Vector2(44, -40).lerp(Vector2(72, -108), up)
			foot_b = Vector2(-22, -14)
		else:
			foot_f = Vector2(62, -110)       # straight out: the flip carries it round
			foot_b = Vector2(-8, -32)        # the other tucked
	if spear > 0.0:
		# the lead leg reaching out in front, the back one tucked up behind
		foot_f = foot_f.lerp(Vector2(58, -30), spear)
		foot_b = foot_b.lerp(Vector2(-34, -46), spear)
		bend = 1.0
	_leg(hip_b, foot_b, bend)
	_leg(hip_f, foot_f, bend)
	if tumble > 0.0:
		# wind streaks rushing up past him
		for i in 5:
			var q := fmod(anim_t * 3.2 + i * 0.37, 1.0)
			var wx := -52.0 + i * 26.0 + sin(i * 2.3) * 6.0
			var wy := -20.0 - q * 260.0
			_ln(Vector2(wx, wy), Vector2(wx, wy - 46.0), Color(1, 1, 1, 0.75 * (1.0 - q) * tumble), 4.0)

	# ---- everything above the waist leans and bobs as one piece
	var upper := base * Transform2D(lean, Vector2(shake.x, -62.0 + bob + shake.y)) * Transform2D(0.0, Vector2(0, 62))
	_stm(upper)

	var head_xf := upper * Transform2D(0.0, Vector2(HEAD_K, HEAD_K), 0.0, NECK * (1.0 - HEAD_K))
	var face_xf := head_xf * Transform2D(0.0, FACE)
	# the hair trails his motion on a spring: streams back in a run, flies up
	# in a fall, flops down and bounces on a landing
	# (the step is capped: after one long frame (a hitch) a stiff spring stepped
	# raw blows up to INF/NaN, and NaN hair is hundreds of errors every frame after)
	var dt := minf(get_process_delta_time(), 1.0 / 30.0)
	var hair_to := Vector2(-clampf(velocity.x * facing / SPEED, -1.6, 1.6) * 11.0,
		clampf(-velocity.y / 900.0, -1.2, 1.2) * 10.0) if not dead and velocity.is_finite() else Vector2.ZERO
	_hair_vel += ((hair_to - _hair_off) * 140.0 - _hair_vel * 11.0) * dt
	_hair_off += _hair_vel * dt
	if not (_hair_off.is_finite() and _hair_vel.is_finite()):
		_hair_off = Vector2.ZERO
		_hair_vel = Vector2.ZERO
	_hair_off = _hair_off.limit_length(40.0)
	_stm(head_xf)
	_mane()
	_stm(upper)
	_costume_back()
	# spare wood rides tucked in the belt at his back, behind the body
	for i in wood:
		var wx := -20.0 - i * 6.0
		_ln(Vector2(wx, -60), Vector2(wx - 22, -104), Pal.DEADWOOD_DARK, 9.0, true)
		_ln(Vector2(wx, -60), Vector2(wx - 22, -104), Pal.DEADWOOD, 5.0, true)
	_oval(Vector2(4, -130), 17.0, 10.0, _skin)
	# a hero's chest: broad shoulders tapering to the waist
	var torso := PackedVector2Array([Vector2(-50, -124)])
	torso.append_array(_quad(Vector2(-50, -124), Vector2(4, -142), Vector2(58, -124)))
	torso.append_array(_quad(Vector2(58, -124), Vector2(50, -90), Vector2(30, -68)))
	torso.append(Vector2(-22, -68))
	torso.append_array(_quad(Vector2(-22, -68), Vector2(-40, -90), Vector2(-50, -124)))
	torso.remove_at(torso.size() - 1)
	_shape(torso, _skin)
	# pecs, lit on the top; soft abs
	_fan(_quad(Vector2(-32, -118), Vector2(-14, -98), Vector2(2, -110), 8, true), Color(1, 0.95, 0.85, 0.16))
	_fan(_quad(Vector2(6, -110), Vector2(24, -98), Vector2(44, -118), 8, true), Color(1, 0.95, 0.85, 0.16))
	_pl(_quad(Vector2(-32, -114), Vector2(-14, -98), Vector2(2, -108), 8, true), C_SK2, 3.5, true)
	_pl(_quad(Vector2(6, -108), Vector2(24, -98), Vector2(44, -114), 8, true), C_SK2, 3.5, true)
	var ab := Color(C_SK2, 0.55)
	_ln(Vector2(4, -98), Vector2(4, -76), ab, 2.5, true)
	for yy in [-92.0, -84.0]:
		_ln(Vector2(-6, yy), Vector2(2, yy + 1.0), ab, 2.5, true)
		_ln(Vector2(6, yy + 1.0), Vector2(14, yy), ab, 2.5, true)
	# a little tuft of chest hair
	for k in 3:
		_ln(Vector2(-1.0 + k * 5.0, -110), Vector2(-3.0 + k * 5.0 + (k - 1) * 2.0, -102), C_HAIR, 3.0, true)
	if _sun_k > 0.0:
		# the muscles lit from inside, gold
		var gl := Color(Sunfire.WHITE_HOT, 0.6 * _sun_k)
		_pl(_quad(Vector2(-32, -114), Vector2(-14, -100), Vector2(2, -108), 8, true), gl, 2.5, true)
		_pl(_quad(Vector2(6, -108), Vector2(22, -100), Vector2(40, -114), 8, true), gl, 2.5, true)
		_ln(Vector2(4, -100), Vector2(4, -74), gl, 2.0, true)
		for yy in [-94.0, -86.0, -78.0]:
			_ln(Vector2(-6, yy), Vector2(14, yy), gl, 2.0, true)
	if costume >= 2:
		_fur_tunic()
	_costume_chest()
	_fang_necklace()

	# far arm: pumps against the legs when running
	var back_sh := Vector2(-42, -118)
	if has_torch and not boxing:
		_torch_arm(back_sh, running, air, ph, speed_k, rage, upper)
	elif carrying != null:
		# the other hand up too, steadying it
		_arm(back_sh, back_sh + Vector2(16, -44), back_sh + Vector2(44, -96), 11.0, true)
	elif not boxing:
		var fa := _pose_arm(back_sh, -1.0, running, air, ph, speed_k)
		_arm(back_sh, fa[0], fa[1], 10.0, true)

	if costume >= 2:
		_tunic_skirt(speed_k)
	else:
		for i in 6:
			var lx := -21.0 + i * 10.0
			var ang := (i - 2.5) * 0.11 - speed_k * 0.18 + _flutter(i * 1.1 + 6.0, 1.0).x * 0.045        # leaves in the air
			_leaf(Vector2(lx, -70), 29.0 + (3.0 if i % 2 == 1 else 0.0), 8.0, ang, C_LEAF2 if i % 2 == 1 else C_LEAF)
	_rope_belt()
	for i in berries:
		_grapes(Vector2(-30.0 + i * 11.0, -80), 0.5)
	_costume_belt()
	for i in mini(rocks, 3):
		_dot(Vector2(36.0 + i * 10.0, -62), 6.5, Pal.STONE, 2.5)

	# ---- head: a warm, cheeky face (he scowls only in a fight or a rage)
	_stm(head_xf)
	# ears, half in the mane
	_dot(Vector2(-22, -151), 7.0, _skin, 3.0)
	_dot(Vector2(30, -151), 7.0, _skin, 3.0)
	_cc(Vector2(-24, -151), 2.6, C_SK2)
	_cc(Vector2(32, -151), 2.6, C_SK2)
	# his mood, for the funny faces
	_idle_t = _idle_t + get_process_delta_time() if on_floor and speed_k < 0.05 and attacking <= 0.0 and not talking and not dead and fury < 0.0 else 0.0
	var mood := ""
	if wall_cling and not on_floor:
		mood = "strain"
	elif on_floor and speed_k > 0.85 and attacking <= 0.0 and sun_t <= 0.0:
		mood = "run"
	elif air and velocity.y < -200.0 and flip_t <= 0.0 and tumble < 0.3 and vine == null:
		mood = "ooh"
	elif _idle_t > 5.0 and fmod(_idle_t - 5.0, 9.0) < 1.6:
		mood = "yawn"
	_jaw_head()
	_short_beard()
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
	elif dead:
		_dead_mouth()
	elif tumble > 0.5:
		_yell()
	elif gu >= 0.0 and gu < GETUP_SPLAT:
		_dead_mouth()
	elif gu >= GETUP_FLEX:
		_grin()
	elif sun_t > 0.0 and attacking <= 0.0:
		_grin()                                # SUNFIRE: a fierce, delighted grin
	elif vine != null and absf(_vine_w) > 1.6:
		_grin()                                # wheee!
	elif mood == "strain" and not wince:
		_tongue_out(false)                     # tongue poking out: concentrating hard
	elif mood == "run" and not wince:
		_tongue_out(true)                      # tongue flapping like a happy dog
	elif mood == "ooh":
		_oval(Vector2(4, -135), 4.5, 5.5, C_MOUTH, 2.2)
	elif mood == "yawn":
		_oval(Vector2(4, -134), 7.5, 9.0 * sin(clampf(fmod(_idle_t - 5.0, 9.0) / 1.6, 0.0, 1.0) * PI) + 2.0, C_MOUTH, 2.2)
	elif attacking > 0.0 or slam_charge >= 0.0 or wall_cling or wince or scorch_t > 0.0:
		_mouth()                               # teeth gritted: effort
	else:
		_smile()
	# the moustache over the lip (over every mouth), then the nose
	_moustache()
	_nose()
	var blink := fmod(anim_t, 3.7) < 0.12
	if dead:
		# X for eyes
		for ec in [Vector2(-7, -151), Vector2(15, -151)]:
			_ln(ec + Vector2(-5, -5), ec + Vector2(5, 5), C_OL, 3.0, true)
			_ln(ec + Vector2(-5, 5), ec + Vector2(5, -5), C_OL, 3.0, true)
	elif tumble > 0.5 and not wince:
		# eyes like saucers
		for ec in [Vector2(-7, -152), Vector2(15, -152)]:
			_oval(ec, 7.5, 7.0, C_EYE, 3.0)
			_cc(ec + Vector2(1.5 + sin(anim_t * 23.0), 1.0), 2.2, Color("1a0f08"))
	else:
		var shut := blink or mood == "yawn"
		_eye(Vector2(-7, -150), wince, shut or mood == "strain", 0.8, -1.0)
		_eye(Vector2(15, -150), wince, shut, 0.84, 1.0)
		if mood == "strain":
			# sweat flying off his brow
			var q := fmod(anim_t * 1.8, 1.0)
			_cc(Vector2(-22.0 - q * 10.0, -166.0 + q * 18.0), 3.2 * (1.0 - q * 0.5), Color("bfe6ff", 0.9 * (1.0 - q)))
	# brows: heavy and angled down at rest (the sheet's determined scowl); lower still when it's on
	var inner := 8.0 if wince else 4.0
	if attacking > 0.0 or slam_charge >= 0.0:
		inner = 6.0
	if fury >= 0.0:
		inner = 12.0
	if tumble > 0.5:
		inner = -7.0                          # shot up in alarm
	if dead:
		inner = 0.0                           # no more scowling
	if gu >= GETUP_FLEX:
		inner = -4.0                          # brows up: proud of himself
	if tumble > 0.0:
		# hair blown straight up, flapping
		for k in 4:
			var hx := -14.0 + k * 11.0
			var fl := sin(anim_t * 30.0 + k * 1.7) * 5.0
			_pg(PackedVector2Array([Vector2(hx - 6.0, -172), Vector2(hx + 6.0, -172), Vector2(hx + fl, -172.0 - 26.0 * tumble)]), C_HAIR)
		# sweat flying off him
		for k in 2:
			var q := fmod(anim_t * 2.6 + k * 0.5, 1.0)
			var side := -1.0 if k == 0 else 1.0
			var dp := Vector2(4.0 + side * (30.0 + q * 34.0), -166.0 - q * 30.0 + q * q * 40.0)
			_cc(dp, 4.0 * tumble * (1.0 - q * 0.5), Color("bfe6ff", 0.9 * (1.0 - q)))
	# THE UNIBROW: his trademark, sculpted (_brows)
	if mood == "strain":
		inner = 5.0
	elif mood == "ooh" or mood == "yawn":
		inner = -5.0
	_brows(inner)
	_hair_fringe()
	_stm(face_xf)
	if skin == "war_paint":
		_rc(Rect2(-12, -161, 36, 3.5), Pal.EMBER)
	_costume_head()
	if gu >= 0.0 and gu < GETUP_FLEX:
		# seeing stars
		for k in 3:
			var a := anim_t * 9.0 + k * TAU / 3.0
			var sp := Vector2(4.0 + cos(a) * 34.0, -182.0 + sin(a) * 9.0)
			_pg(PackedVector2Array([sp + Vector2(0, -7), sp + Vector2(2, -2), sp + Vector2(7, 0), sp + Vector2(2, 2), sp + Vector2(0, 7), sp + Vector2(-2, 2), sp + Vector2(-7, 0), sp + Vector2(-2, -2)]), Color("ffd84a"))
	if _bb != null:
		_head_at = _bb.xf * Vector2(4, -168)
	_soot_face()
	if fury >= 0.0:
		_rage_marks(rage, roaring)

	_stm(upper)
	# ---- the near arm: fists, throw, club swing, club carry, or pumping
	var sh := Vector2(50, -118)
	var charge_k := clampf(slam_charge / _charge_ready(), 0.0, 1.0) if slam_charge >= 0.0 else 0.0
	if gu >= GETUP_FLEX and attacking <= 0.0 and throwing <= 0.0:
		# the flex: bicep up, fist by his ear, the club held up like a trophy
		var hd := sh + Vector2(18, -64)
		_arm(sh, sh + Vector2(40, -8), hd, 17.0, true)
		if has_stick and not axe_out:
			_club(hd + Vector2(-4, 14), hd + Vector2(8, -96), 7.0, 26.0)
		# a glint off the bicep
		var gl := sh + Vector2(36, -22)
		var r := 7.0 + sin(anim_t * 18.0) * 2.5
		_pg(PackedVector2Array([gl + Vector2(0, -r), gl + Vector2(r * 0.25, 0), gl + Vector2(0, r), gl + Vector2(-r * 0.25, 0)]), Color(1, 1, 0.9, 0.9))
		_pg(PackedVector2Array([gl + Vector2(-r, 0), gl + Vector2(0, r * 0.25), gl + Vector2(r, 0), gl + Vector2(0, -r * 0.25)]), Color(1, 1, 0.9, 0.9))
	elif carrying != null:
		# hoisting a critter overhead: one mighty arm, straight up (it wobbles)
		var lk := clampf(_carry_t / Grab.LIFT_TIME, 0.0, 1.0)
		lk = 1.0 - pow(1.0 - lk, 3.0)
		var hd := Vector2(46, -120).lerp(Vector2(14, -232), lk) + Vector2(sin(anim_t * 17.0) * 3.0, 0)
		_arm(sh, sh.lerp(hd, 0.5) + Vector2(14, 4), hd, 15.0, false)
		_fist(hd, 13.0)
		if _bb != null:
			_carry_hand = _bb.xf * hd
	elif showing_off > 0.0 and has_stick:
		# holding the new treasure up high, both arms, for everyone to see
		var hd := Vector2(20, -232)
		_arm(sh, sh + Vector2(10, -60), hd, 13.0, false)
		_club(hd + Vector2(0, 30), hd + Vector2(0, -80), 7.0, 26.0)
		_fist(hd)
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
		_fist(hd)
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
		_fist(hd)
	elif scorch_t > 0.0 and has_stick:
		# arms up, waving wildly
		var hd := Vector2(24 + sin(anim_t * 26.0) * 14.0, -214)
		_arm(sh, sh + Vector2(12, -52), hd, 13.0, false)
		_club(hd, hd + Vector2(-50, -60), 7.0, 22.0)
		_fist(hd)
	elif spear > 0.3 and throwing <= 0.0 and attacking <= 0.0:
		# the spear: arm thrust straight out in front, club pointed ahead like a spear
		var hd := sh + Vector2(72, 12)
		_arm(sh, sh.lerp(hd, 0.5) + Vector2(0, -3), hd, 13.0, false)
		if has_stick and not axe_out:
			_club(hd + Vector2(-22, -3), hd + Vector2(96, 16), 7.0, 22.0)
		_fist(hd)
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
		_fist(hd)
	elif tumble > 0.0 and throwing <= 0.0 and attacking <= 0.0:
		# windmilling: the near arm whirls, the club whirling with it
		var a := anim_t * 19.0
		var hd := sh + Vector2(cos(a) * 54.0, sin(a) * 54.0 - 30.0)
		_arm(sh, sh.lerp(hd, 0.5) + Vector2(sin(a) * 10.0, -cos(a) * 10.0), hd, 13.0, false)
		if has_stick and not axe_out:
			_club(hd, hd + Vector2.from_angle(a + 0.9) * 92.0, 7.0, 22.0)
		_fist(hd)
	elif wall_cling and not is_on_floor() and throwing <= 0.0 and attacking <= 0.0:
		# climbing: the near hand reaching up the wall and pulling, in time with the feet
		var hd := Vector2(60, -184.0 + 18.0 * sin(anim_t * 11.0 + PI))
		_arm(sh, sh + Vector2(22, -30), hd, 13.0, false)
		if has_stick and not axe_out:
			_club(hd + Vector2(-14, 40), hd + Vector2(-34, -60), 7.0, 22.0)
		_fist(hd)
		# fingers spread on the rock
		for k in 3:
			_ln(hd, hd + Vector2(8.0, -10.0 + k * 8.0), _skin, 6.0, true)
	elif vine != null:
		# hanging on: the near hand up on the vine, the club tucked under the arm
		var hd := Vector2(0, -HANG / ART)
		_arm(sh, sh + Vector2(-8, -48), hd, 13.0, false)
		_fist(hd)
	elif fury >= 0.0 and has_stick:
		# the club goes up overhead for the whole rage and is shaken at the
		# world as the fire leaves: the pose reads from across the screen
		var ca := -1.85 if not roaring else -1.35
		var hd := sh + Vector2(8, -58)
		_arm(sh, sh + Vector2(26, -24), hd, 13.0, false)
		_club(hd - Vector2.from_angle(ca) * 12.0, hd + Vector2.from_angle(ca) * 112.0, 7.0, 26.0)
		_fist(hd)
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
		# overhand, ending pointed the way he aimed (ahead, up, 45 degrees, down)
		var end_a := atan2(_throw_aim.y, absf(_throw_aim.x)) - 0.2
		var ta := lerpf(-2.6, end_a, 1.0 - pow(1.0 - q, 3.0))
		var reach := 48.0 + q * 14.0
		var hd := sh + Vector2.from_angle(ta) * reach
		var el := sh + Vector2.from_angle(ta) * reach * 0.5 + Vector2.from_angle(ta - PI * 0.5) * 9.0
		_arm(sh, el, hd, 11.0, false)
		_dot(hd, 15.0, Pal.STONE)
		_dot(hd + Vector2(-2, 4), 9.0, _skin, 4.0)
	elif has_stick and attacking > 0.0 and not axe_out and not _kicking():
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
			"axe2", "axe3":
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
			"dig", "spike":
				# like a pickaxe: up over his head, then DRIVEN straight down at his feet
				if sp < 0.38:
					var q := sp / 0.38
					ang = lerpf(-0.6, -2.3, q * q * (3.0 - 2.0 * q))
					trail = -0.15
				else:
					var q := clampf((sp - 0.38) / 0.12, 0.0, 1.0)     # lands at 0.5, as the blow does
					# the club lands slanted, its head on the ground ahead of his feet: driven
					# straight down, planted in the dirt, it looked just like a shovel
					ang = -2.3 + q * q * (3.75 if tool == "shovel" else 3.2)
					trail = (1.0 - q) * 1.0
					reach = 44.0 - 6.0 * q
				smear_col = Color(0.85, 0.7, 0.5, 0.45)
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
			"club1":
				# the uppercut: from low in front, whipped back up over his head
				var q := 1.0 - pow(1.0 - sp, 2.4)
				ang = lerpf(1.25, -1.9, q)
				trail = -(1.0 - q) * 0.8
				reach = 50.0 + sin(q * PI) * 14.0
				smear_col = Color(Pal.BONE, 0.4)
			"club2":
				# the finisher: wound right up behind his head... then SMASHED down
				if sp < 0.45:
					var q := sp / 0.45
					ang = lerpf(-1.9, -3.05, q * q * (3.0 - 2.0 * q))
					trail = -0.2
				else:
					var q := clampf((sp - 0.45) / 0.22, 0.0, 1.0)
					ang = -3.05 + (1.0 - pow(1.0 - q, 3.0)) * 3.7       # lands slanted ahead (straight down, planted, it looked like a shovel)
					trail = (1.0 - q) * 1.2
					reach = 52.0 + sin(q * PI) * 22.0
				smear_col = Color(1.0, 0.9, 0.6, 0.55)
			"homerun":
				# from low behind him, a full sweep round to high in front
				var q := 1.0 - pow(1.0 - sp, 2.2)
				ang = lerpf(2.6, -1.1, q)
				trail = -(1.0 - q) * 0.9
				reach = 60.0
				smear_col = Color(Pal.BONE, 0.45)
			"cyclone":
				# round and round: the club whirls twice right round him, a blur
				ang = -PI * 0.5 + sp * TAU * 2.0
				trail = 0.9
				reach = 54.0
				smear_col = Color("bfe6ff", 0.55)
			"ram":
				# the charge: the club driven straight out in front like a battering ram
				ang = lerpf(-0.35, 0.12, minf(sp / 0.3, 1.0))
				trail = 0.15
				reach = 64.0
				smear_col = Color("ffd36b", 0.5)
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
		# the smear fades as the swing slows: a still arc left beside the landed club read as a shovel's handle
		smear_col.a *= clampf(absf(trail) / 0.45, 0.0, 1.0)
		if smear_col.a > 0.02:
			_pl(smear, smear_col, 9.0 if _swing_kind in ["hammer", "homerun", "axe2", "axe3", "cyclone", "ram"] else 7.0, true)
		_arm(sh, el, hd, 13.0, false)
		_club(hd - Vector2.from_angle(ca) * 12.0, hd + Vector2.from_angle(ca) * 112.0, 7.0, 26.0)
		_fist(hd)
	elif has_stick and kick_k >= 0.0:
		# kicking: the club flung up and back for balance, out of the leg's way
		var hd := Vector2(66, -184)
		_arm(sh, Vector2(70, -150), hd, 10.0, false)
		_club(hd + Vector2(10, 4), hd + Vector2(-92, -36), 7.0, 26.0)
		_fist(hd)
	elif has_stick:
		# carries the club on his shoulder; it rides the body's bob and lean
		var lift := -8.0 if air else 0.0
		var hd := Vector2(60, -76.0 + lift)
		_arm(sh, Vector2(68, -96.0 + lift), hd, 10.0, false)
		_club(Vector2(58, -64.0 + lift), Vector2(84, -184.0 + lift), 7.0, 26.0)
		_fist(hd)
	else:
		var na := _pose_arm(sh, 1.0, running, air, ph, speed_k)
		_arm(sh, na[0], na[1], 10.0, true)

	if kick_k >= 0.0:
		# kicking: the leg comes round in FRONT of everything, club and all
		_stm(base)
		_leg(hip_f, foot_f, 1.0)
	_st(Vector2.ZERO, 0.0, Vector2.ONE)
	if sun_t > 0.0:
		_paint_sun_flames()
	_paint_kick()


## The torch arm. Held up and behind his head so the light falls on both
## sides of him; it bobs with the stride but never swings wild. Records where
## the flame is, which is where Night centres his light.
func _torch_arm(sh: Vector2, running: bool, air: bool, ph: float, k: float, rage: float, xf: Transform2D) -> void:
	var hd := Vector2(-60, -150)
	if running:
		hd += Vector2(cos(ph) * 3.0 * k, -absf(sin(ph)) * 4.0 * k)
	elif air:
		hd += Vector2(2, -10)
		# the spear pose: the torch carried forward and high; tumbling: waved wildly
		hd += Vector2(34, -14) * _spear * (1.0 - _tumble)
		hd += Vector2(sin(anim_t * 14.0) * 16.0, -30.0 + cos(anim_t * 14.0) * 8.0) * _tumble
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
	var sw := -k * 6.0 + sin(anim_t * 2.0) * 1.2 + _hair_off.x * 0.5
	var hem := [Vector2(40, -40), Vector2(31, -34), Vector2(22, -38), Vector2(13, -31),
		Vector2(3, -36), Vector2(-7, -30), Vector2(-16, -35), Vector2(-24, -32), Vector2(-29, -40)]
	var pts := PackedVector2Array([Vector2(-27, -74), Vector2(35, -74)])
	for i in hem.size():
		var h: Vector2 = hem[i]
		pts.append(h + Vector2(sw + sin(anim_t * 2.6 + i) * 0.8, 0))
	var hide := C_LEOPARD
	var spots := C_LEOPARD_SPOT
	var leopard := true
	if skin in ["wolf_pelt", "wolf_hood"]:
		leopard = false
		hide = Pal.WOLF
		spots = Pal.WOLF_DARK
	elif skin == "ember_paint":
		leopard = false
		hide = Color("9a4a22")
		spots = Color("4a2414")
	elif skin == "bear_cloak":
		leopard = false
		hide = Color("6b4a2e")
		spots = Color("45301c")
	elif skin == "firekeeper":
		leopard = false
		hide = Color("c49a64")
		spots = Color("8a6a3c")
	_shape(pts, hide, 3.5)
	_fur(pts, FUR, Color(1.0, 0.9, 0.7, 0.32), 0.5)       # the hide is real fur
	if leopard:
		# leopard rosettes: broken dark rings round a warmer middle
		for r in [Vector2(-14, -62), Vector2(6, -66), Vector2(26, -60), Vector2(-4, -48), Vector2(18, -46), Vector2(-20, -44), Vector2(32, -46)]:
			var rp: Vector2 = r + Vector2(sw * 0.5, 0)
			_cc(rp, 4.2, Color("c07a2c"))
			for q in 3:
				var a: float = q * TAU / 3.0 + rp.x
				_cc(rp + Vector2.from_angle(a) * 4.6, 2.2, spots)
	else:
		_oval(Vector2(-8, -54), 7.0, 4.5, spots, 0.0, 0.3)
		_oval(Vector2(20, -48), 5.0, 3.5, spots, 0.0, -0.2)
	for i in 8:
		var fx := -24.0 + i * 8.0 + sw
		_ln(Vector2(fx, -37), Vector2(fx - 2, -29), Pal.WOLF_BELLY if skin in ["wolf_pelt", "wolf_hood"] else spots, 2.5, true)


## Ugu's topknot: a fiery tuft tied up on top with a little bone through it.
## It bounces a beat behind his head.
func _topknot() -> void:
	var sway := sin(anim_t * 3.0) * 2.0 - velocity.x / SPEED * 4.0 * float(facing)
	var base := Vector2(2, -184)
	var tip := base + Vector2(-6.0 + sway, -30.0)
	_shape(PackedVector2Array([base + Vector2(-11, 4), base + Vector2(-12, -10), tip + Vector2(-6, 2), tip, tip + Vector2(8, 4),
		base + Vector2(10, -10), base + Vector2(11, 4)]), C_HAIR, 4.0)
	_ln(base + Vector2(-2, -8), tip + Vector2(2, 6), C_HAIR_HI, 3.0, true)
	# the bone through the knot
	var b0 := base + Vector2(-20, -8)
	var b1 := base + Vector2(20, -12)
	_ln(b0, b1, C_OL, 9.0, true)
	_ln(b0, b1, Pal.KEY_BONE, 5.0, true)
	for e in [b0, b1]:
		_dot(e + Vector2(0, -2), 4.0, Pal.KEY_BONE, 2.5)
		_dot(e + Vector2(0, 3), 4.0, Pal.KEY_BONE, 2.5)

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
			# (it streams out behind him in the air: the lower, the freer)
			_shape(PackedVector2Array([Vector2(-20, -176), Vector2(-40, -150) + _flutter(20.0, 0.5), Vector2(-54, -110) + _flutter(21.0, 0.9),
				Vector2(-56, -74) + _flutter(22.0, 1.5), Vector2(-40, -80) + _flutter(23.0, 1.3), Vector2(-30, -120) + _flutter(24.0, 0.6),
				Vector2(-8, -160)]), Pal.WOLF, 3.5)
			for k in 4:
				var fk := _flutter(21.0 + k * 0.5, 0.6 + k * 0.2)
				_ln(Vector2(-46 + k * 3, -120 + k * 10) + fk, Vector2(-52 + k * 2, -112 + k * 10) + fk, Pal.WOLF_DARK, 2.5, true)
		"bear_cloak":
			# a heavy bear-fur cloak over the shoulders, down to the knees: it billows
			# out behind him when he runs, lifts in a fall, the hem rippling
			var hem := [Vector2(-36, -30), Vector2(-47, -27), Vector2(-58, -29), Vector2(-70, -26)]
			var moved: Array = []
			for k in hem.size():
				moved.append((hem[k] as Vector2) + _flutter(30.0 + k * 0.9, 1.6))
			var cloak := PackedVector2Array([Vector2(-46, -134), Vector2(-16, -138), Vector2(-14, -100), Vector2(-26, -64) + _flutter(28.0, 0.7)])
			for m in moved:
				cloak.append(m)
			cloak.append_array([Vector2(-64, -70) + _flutter(33.0, 1.0), Vector2(-58, -112) + _flutter(34.0, 0.4)])
			_shape(cloak, Color("6b4a2e"), 3.5)
			for k in 6:
				var q := k / 5.0
				var at: Vector2 = (moved[0] as Vector2).lerp(moved[moved.size() - 1], q)
				_ln(at + Vector2(0, -10), at + Vector2(-3.0, 2.0) + _flutter(36.0 + k, 0.5), Color("45301c"), 2.5, true)


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
	_limb([hip, knee, foot], [[25.0, 17.0], [18.0, 12.0]])     # a big thigh, a strong calf, a slim ankle
	_calf_wrap(knee, foot)
	# a big bare foot, three toes at the front
	_oval(foot + Vector2(6, 2), 19.0, 8.5, _skin)
	for tx in [15.0, 20.0]:
		_ln(foot + Vector2(tx, 0), foot + Vector2(tx + 1.0, 6), _skin.darkened(0.45), 2.0, true)


## Elbow and hand for an arm that is not doing anything else. side is -1 for
## the far arm and +1 for the near one; running, the two swing out of phase,
## each paired with the opposite leg the way a real runner's are.
func _pose_arm(sh: Vector2, side: float, running: bool, air: bool, phase: float, k: float) -> Array:
	if air and _tumble > 0.3:
		# windmilling, the other way round to the near arm
		var a := anim_t * 19.0 + PI
		var hd := sh + Vector2(cos(a) * 50.0, sin(a) * 50.0 - 28.0)
		return [sh.lerp(hd, 0.5) + Vector2(sin(a) * 9.0, -cos(a) * 9.0), hd]
	if air and _spear > 0.3:
		# reaching forward too, a little higher than the club arm
		return [sh + Vector2(36, -8), sh + Vector2(70, -14)]
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


func _eye(c: Vector2, wince: bool, blink: bool, s := 1.0, side := 1.0) -> void:
	if wince:
		# squeezed shut: > <
		_pl(PackedVector2Array([c + Vector2(-5.0 * side, -4), c + Vector2(4.0 * side, 0), c + Vector2(-5.0 * side, 4)]), C_OL, 3.0, true)
		return
	# big and clear, so they read from across the screen
	var ry := 0.8 if blink else 5.6 * s
	_oval(c, 6.6 * s, ry, C_EYE, 2.0)
	if not blink:
		# warm brown eyes with an amber glint (the sheet)
		_cc(c + Vector2(2.0, 0.6) * s, 3.9 * s, Color("4a2a14"))
		_cc(c + Vector2(2.0, 0.6) * s, 3.1 * s, Color("8a5426"))
		_cc(c + Vector2(2.2, 0.8) * s, 1.8 * s, Color("1a0f08"))
		_cc(c + Vector2(0.9, -1.0) * s, 1.3 * s, Color.WHITE)
		_cc(c + Vector2(3.4, 2.0) * s, 0.6 * s, Color.WHITE)     # a second sparkle: lively eyes
		# a lash line along the top, swept out at the outer corner
		_ac(c, 6.8 * s, PI * 1.12, PI * 1.88, 8, C_OL, 2.2, true)
		var outer := c + Vector2(6.6 * s * side, -1.5 * s)
		_ln(outer, outer + Vector2(3.0 * side, -2.5) * s, C_OL, 2.0, true)


## The hide he wears, by costume: [fur, its darker tone].
func _hide_colours() -> Array:
	match skin:
		"wolf_pelt", "wolf_hood":
			return [Pal.WOLF, Pal.WOLF_DARK]
		"ember_paint":
			return [Color("9a4a22"), Color("4a2414")]
		"bear_cloak":
			return [Color("6b4a2e"), Color("45301c")]
		"firekeeper":
			return [Color("c49a64"), Color("8a6a3c")]
	return [C_FUR_DARK, C_FUR_DARK.darkened(0.4)]


## The fur tunic (Level 2 on, the design sheet): over his FAR shoulder only, a
## strap running down across the chest to the near hip, lighter fur along its
## edge. (The skirt below the belt is _tunic_skirt.)
func _fur_tunic() -> void:
	var cols := _hide_colours()
	var fur: Color = cols[0]
	var dark: Color = cols[1]
	var body := PackedVector2Array([Vector2(-52, -124), Vector2(-42, -136), Vector2(-26, -137), Vector2(-6, -122), Vector2(16, -108),
		Vector2(36, -94), Vector2(46, -86), Vector2(42, -70), Vector2(-24, -68), Vector2(-42, -88), Vector2(-50, -108)])
	_shape_k("tunic", body, fur, 2.5)
	# the fur in it: short strokes in the darker tone
	for k in 12:
		var p := Vector2(-38.0 + (k % 4) * 16.0 + (k / 4) * 6.0, -118.0 + (k / 4) * 16.0)
		if p.y < -122.0 + (p.x + 26.0) * 0.6:
			continue                            # (above the strap: bare chest)
		_ln(p, p + Vector2(-3, 7), Color(dark, 0.7), 2.0, true)
	# the trim along the strap's edge: a lighter band, tufted
	var a := Vector2(-28, -136)
	var b := Vector2(47, -87)
	_taper(a, b, 9.0, 8.0, C_FUR_LIGHT.darkened(0.12))
	_taper(a + Vector2(0, -1), b + Vector2(0, -1), 6.0, 5.0, C_FUR_LIGHT)
	var nrm := (b - a).normalized().orthogonal()
	for k in 7:
		var q := a.lerp(b, (k + 0.5) / 7.0)
		_pg(PackedVector2Array([q - (b - a).normalized() * 3.0, q + (b - a).normalized() * 3.0, q + nrm * 7.0 + (b - a).normalized() * 1.0 + _flutter(k * 1.4 + 3.0, 0.45)]), C_FUR_LIGHT)


## The tunic's skirt below the belt: the hide, swinging, a jagged lighter fur hem.
func _tunic_skirt(k: float) -> void:
	var cols := _hide_colours()
	var fur: Color = cols[0]
	var dark: Color = cols[1]
	var sw := -k * 4.0
	var hem := [Vector2(42, -38), Vector2(32, -30), Vector2(22, -36), Vector2(12, -27), Vector2(2, -34), Vector2(-8, -26),
		Vector2(-17, -33), Vector2(-25, -28), Vector2(-30, -40)]
	# each point of the hem moves in the air on its own (_flutter): the hem ripples,
	# lifts behind him in a run, flies up in a fall
	var moved: Array = []
	for i in hem.size():
		moved.append((hem[i] as Vector2) + Vector2(sw, 0) + _flutter(i * 0.9, 1.0) * Vector2(1.0, 0.8))
	var pts := PackedVector2Array([Vector2(-28, -76), Vector2(38, -76)])
	for m in moved:
		pts.append(m)
	_shape_k("skirt", pts, fur, 2.5)
	for i in 6:
		var top := Vector2(-20.0 + i * 10.0, -64)
		var bend := _flutter(i * 1.3 + 2.0, 0.5)
		_ln(top + bend * 0.3, top + Vector2(-2, 14) + bend, Color(dark, 0.65), 2.0, true)
	# the jagged lighter fur at the hem, each tuft flicking a beat behind
	for i in moved.size() - 1:
		var p0: Vector2 = moved[i]
		var p1: Vector2 = moved[i + 1]
		var mid := p0.lerp(p1, 0.5) + _flutter(i * 1.7 + 5.0, 0.6)
		_pg(PackedVector2Array([p0 + Vector2(0, -7), p1 + Vector2(0, -7), mid + Vector2(0, 4)]), C_FUR_LIGHT)
	_seat_flames()


## THE AIR on everything loose (hair, fur, cloth, cords): how far a point `reach`
## (0..1: a root barely, a tip fully) is pushed this frame. It drags behind him
## as he runs and streams up as he falls (the hair spring, _hair_off), and it
## flutters: faster and wider the faster he goes, a soft breeze when he stands.
## `i` gives each point its own phase, so the motion ripples along a hem.
func _flutter(i: float, reach: float) -> Vector2:
	if dead:
		return Vector2.ZERO
	# what is the same for every point this frame, worked out once
	var fr := Engine.get_process_frames()
	if fr != _fl_frame:
		_fl_frame = fr
		var spd := clampf(velocity.length() / SPEED, 0.0, 1.8)
		_fl_w = Vector3(anim_t * (6.0 + 7.0 * spd), anim_t * (11.0 + 9.0 * spd), anim_t * (5.0 + 6.0 * spd))
		_fl_amp = 0.3 + 1.2 * spd
		_fl_base = _hair_off * 0.5
	var f := sin(_fl_w.x + i * 1.7) + 0.45 * sin(_fl_w.y + i * 2.9)
	var g := cos(_fl_w.z + i * 2.3)
	return (_fl_base + Vector2(f * 2.4, g * 1.3) * _fl_amp) * reach


var _fl_frame := -1
var _fl_w := Vector3.ZERO
var _fl_amp := 0.0
var _fl_base := Vector2.ZERO


## A necklace of pale fangs on a dark cord (the design sheet), in every costume.
func _fang_necklace() -> void:
	var cord := PackedVector2Array()
	for i in 11:
		var q := i / 10.0
		cord.append(Vector2(lerpf(-16.0, 26.0, q), -125.0 + sin(q * PI) * 12.0))
	_pl(cord, C_CORD, 2.6, true)
	for i in [2, 3, 4, 5, 6, 7, 8]:
		var p: Vector2 = cord[i]
		var len := 9.0 if i in [4, 5, 6] else 7.0
		var lean := (float(i) - 5.0) * 0.08
		var tip := p + Vector2(lean * len, len) + _flutter(i * 0.8 + 11.0, 0.35)          # the fangs swing on the cord
		_shape(PackedVector2Array([p + Vector2(-2.2, 0), p + Vector2(2.2, 0), tip]), C_FANG, 1.2)


## A twisted rope belt, knotted at the front, a small leather pouch on the hip.
func _rope_belt() -> void:
	var belt := _quad(Vector2(-27, -72), Vector2(5, -67), Vector2(36, -72), 10, true)
	_pl(belt, C_FUR.darkened(0.45), 10.0, true)
	_pl(belt, C_FUR.lightened(0.05), 6.5, true)
	for i in range(1, belt.size() - 1):
		var p: Vector2 = belt[i]
		_ln(p + Vector2(-2.5, -3), p + Vector2(2.5, 3), C_FUR.darkened(0.4), 1.6, true)
	# the knot, its ends hanging
	_dot(Vector2(10, -68), 4.5, C_FUR, 1.5)
	_ln(Vector2(9, -66), Vector2(7, -55) + _flutter(8.0, 0.9), C_FUR.darkened(0.15), 3.0, true)       # the ends swing
	_ln(Vector2(12, -66), Vector2(15, -57) + _flutter(9.3, 0.9), C_FUR.darkened(0.15), 3.0, true)
	# the pouch on the hip
	_shape_k("pouch", PackedVector2Array([Vector2(-24, -70), Vector2(-8, -70), Vector2(-6, -56), Vector2(-15, -50), Vector2(-25, -56)]), C_LEATHER, 2.0)
	_shape_k("pouch_flap", PackedVector2Array([Vector2(-25, -70), Vector2(-7, -70), Vector2(-9, -62), Vector2(-23, -62)]), C_LEATHER.darkened(0.15), 1.5)
	_cc(Vector2(-16, -63), 1.6, C_FANG)


## Leather wraps round the forearm (the design sheet): a band near the wrist, cords across it.
func _forearm_wrap(el: Vector2, hd: Vector2, w: float) -> void:
	var a := el.lerp(hd, 0.4)
	var b := el.lerp(hd, 0.82)
	_wrap_band(a, b, w + 3.0, w + 2.0, C_LEATHER.darkened(0.25))
	_wrap_band(a, b, w, w - 1.0, C_LEATHER)
	var d := (b - a)
	var n := d.normalized().orthogonal() * (w * 0.5)
	for k in 4:
		var c := a.lerp(b, (k + 0.5) / 4.0)
		_ln(c - n - d * 0.06, c + n + d * 0.06, C_LEATHER.darkened(0.35), 1.6, true)


## Fur wrapped round the calf and ankle, tied with cord (the design sheet).
func _calf_wrap(knee: Vector2, foot: Vector2) -> void:
	var a := knee.lerp(foot, 0.42)
	var b := knee.lerp(foot, 0.92)
	_wrap_band(a, b, 24.0, 19.0, C_FUR_DARK.darkened(0.2))
	_wrap_band(a, b, 21.0, 16.0, C_FUR_DARK)
	var d := (b - a).normalized()
	var n := d.orthogonal()
	# a ragged fur top edge
	for k in 4:
		var p := a + n * (-9.0 + k * 6.0)
		_pg(PackedVector2Array([p - n * 3.0, p + n * 3.0, p - d * 5.0 + _flutter(k * 1.9 + knee.x * 0.05, 0.4)]), C_FUR)
	# cord ties
	for t in [0.35, 0.75]:
		var c := a.lerp(b, t)
		_ln(c - n * 11.0, c + n * 11.0 + d * 2.0, C_CORD, 2.2, true)


## His head (the design sheet): a broad skull, cheekbones, a strong squared jaw.
var _head_pts := PackedVector2Array()       ## the head's outline and the hair cap's arc: constant, built once
var _cap_arc := PackedVector2Array()

func _jaw_head() -> void:
	if _head_pts.is_empty():
		_head_pts = _smooth([Vector2(-20, -170), Vector2(-14, -182), Vector2(4, -186), Vector2(22, -182), Vector2(29, -170),
			Vector2(30, -152), Vector2(28, -138), Vector2(22, -127), Vector2(10, -121), Vector2(-2, -121), Vector2(-15, -127),
			Vector2(-21, -138), Vector2(-22, -152)], 3)
	var head := _head_pts
	_shape_k("head", head, _skin, 3.0)
	# the cheekbones catch the light; the hollows under them in shade
	_oval(Vector2(-12, -146), 6.0, 3.0, Color(1, 0.92, 0.8, 0.14), 0.0, -0.2)
	_oval(Vector2(22, -146), 6.0, 3.0, Color(1, 0.92, 0.8, 0.14), 0.0, 0.2)


## A short, thick beard round the jaw and chin, framing the mouth, with strands in it.
func _short_beard() -> void:
	# along the jaw only (the cheeks stay bare), fullest at the chin
	var beard := C_HAIR.lerp(C_FUR_DARK, 0.35)
	var outer := [Vector2(-22, -146), Vector2(-21, -136), Vector2(-15, -126), Vector2(-6, -120), Vector2(4, -118),
		Vector2(14, -120), Vector2(23, -126), Vector2(29, -136), Vector2(30, -146)]
	var inner := [Vector2(25, -145), Vector2(22, -136), Vector2(14, -130), Vector2(4, -128), Vector2(-6, -130), Vector2(-14, -136), Vector2(-17, -145)]
	var pts := PackedVector2Array()
	for p in outer:
		pts.append(p)
	for p in inner:
		pts.append(p)
	_shape_k("beard", pts, beard, 2.0)
	# a few strands, and a ragged lower edge at the chin
	for k in 5:
		var x := -10.0 + k * 7.0
		_ln(Vector2(x, -127 + absf(x - 4.0) * 0.2), Vector2(x - 1.0, -121 + absf(x - 4.0) * 0.25), Color(C_HAIR_HI, 0.8), 1.5, true)
	for k in 4:
		var bx := -6.0 + k * 7.0
		_pg(PackedVector2Array([Vector2(bx - 3, -120), Vector2(bx + 3, -120), Vector2(bx, -115)]), beard)


## The moustache over the upper lip, its ends running down into the beard.
func _moustache() -> void:
	_shape_k("moustache", PackedVector2Array([Vector2(-11, -132), Vector2(-9, -140), Vector2(-1, -145), Vector2(4, -143.5), Vector2(9, -145),
		Vector2(17, -140), Vector2(19, -132), Vector2(15, -136), Vector2(9, -139.5), Vector2(4, -139), Vector2(-1, -139.5), Vector2(-7, -136)]), C_HAIR, 2.0)
	_ln(Vector2(-4, -142), Vector2(2, -143), C_HAIR_HI, 1.4, true)
	_ln(Vector2(7, -143), Vector2(13, -142), C_HAIR_HI, 1.4, true)


## The front of his hair: ONE shape, the cap over the crown flowing straight
## into curved locks that fall over the forehead and the temples (no pieces
## stuck on), each lock tapering to a tip that flicks to the side; strands of
## light follow the curve of each lock. Tufts curl up off the crown. (The big
## mane behind is _mane.)
## Locks, right temple to left: [root right x, root left x, tip, bend].
const FRINGE_LOCKS := [[32.0, 23.0, Vector2(31, -155), 4.0], [24.0, 15.0, Vector2(21, -163.5), -3.0],
	[16.0, 6.0, Vector2(9, -162), -4.0], [7.0, -3.0, Vector2(0, -164), -3.0], [-2.0, -12.0, Vector2(-11, -162), -4.0],
	[-11.0, -24.0, Vector2(-22, -154), -3.0]]          ## (2026-10-10: shorter, the forehead shows)
const FRINGE_ROOT_Y := -171.0

func _hair_fringe() -> void:
	# the cap: from the left temple up over the crown to the right temple
	if _cap_arc.is_empty():
		var pts := _smooth([Vector2(-25, -160), Vector2(-25, -173), Vector2(-17, -186), Vector2(-2, -192), Vector2(15, -191),
			Vector2(28, -183), Vector2(34, -170), Vector2(33, -160)], 3)
		# keep only the arc (the smoothing closes the loop: drop the bottom stretch)
		for p in pts:
			if p.y < -161.0:
				_cap_arc.append(p)
	# ...then the locks, right to left, each a curve down to its tip and back up
	var hairline := PackedVector2Array(_cap_arc)
	var spines: Array = []
	var li := 0
	for lk in FRINGE_LOCKS:
		var r_root := Vector2(float(lk[0]), FRINGE_ROOT_Y)
		var l_root := Vector2(float(lk[1]), FRINGE_ROOT_Y)
		var tip: Vector2 = (lk[2] as Vector2) + _flutter(li * 1.1, 0.55) * Vector2(1.0, 0.6)
		li += 1
		var bend: float = lk[3]
		var mid := r_root.lerp(l_root, 0.5)
		hairline.append_array(_quad(r_root, r_root.lerp(tip, 0.55) + Vector2(bend * 0.4 + 1.5, 0), tip, 4, true))
		hairline.append_array(_quad(tip, l_root.lerp(tip, 0.5) + Vector2(bend * 0.6 - 1.0, -1.5), l_root, 4))
		# a little notch up between this lock and the next
		hairline.append(l_root + Vector2(-0.5, -3.0))
		spines.append([mid, mid.lerp(tip, 0.5) + Vector2(bend * 0.5, 0), tip])
	_shape_k("fringe", hairline, C_HAIR, 2.0)
	# shade at the roots, a soft light band across the crown, light down each lock
	_pl(_quad(Vector2(-18, -178), Vector2(4, -186), Vector2(26, -177), 5, true), Color(C_HAIR_HI, 0.55), 4.0, true)
	for sp in spines:
		var line := _quad(sp[0] + Vector2(0, -3), sp[1], (sp[2] as Vector2).lerp(sp[1], 0.25), 3, true)
		_pl(line, Color(C_HAIR_HI, 0.85), 1.8, true)
	# tufts curling up off the crown, toward where he faces (not under a hood)
	if skin in ["wolf_hood", "bear_cloak"]:
		return
	for tf in [[Vector2(-10, -186), Vector2(-18, -195), Vector2(-28, -196)], [Vector2(3, -190), Vector2(-3, -201), Vector2(-14, -204)],
			[Vector2(16, -188), Vector2(14, -200), Vector2(5, -205)], [Vector2(27, -180), Vector2(33, -191), Vector2(30, -199)]]:
		var b: Vector2 = tf[0]
		var c: Vector2 = tf[1] + _flutter(b.x * 0.2, 0.6)
		var t: Vector2 = tf[2] + _flutter(b.x * 0.2 + 0.7, 1.1)
		var side := (c - b).normalized().orthogonal() * 5.5
		var tuft := PackedVector2Array([b - side])
		tuft.append_array(_quad(b - side, c - side * 0.5, t, 3))
		tuft.append_array(_quad(t, c + side * 0.6, b + side, 3))
		_shape_k("tuft%d" % int(b.x), tuft, C_HAIR, 1.6)
		_pl(_quad(b, c, t.lerp(c, 0.3), 3, true), Color(C_HAIR_HI, 0.8), 1.6, true)


## A strong nose: a straight bridge, a broad rounded tip, the nostrils in shadow.
func _nose() -> void:
	var col := _skin.darkened(0.06)
	_shape(PackedVector2Array([Vector2(3, -156), Vector2(8, -156), Vector2(11, -147), Vector2(14, -142), Vector2(11, -138),
		Vector2(5, -137.5), Vector2(-1, -138), Vector2(-4, -142), Vector2(-1, -147)]), col, 2.4)
	_ln(Vector2(6, -154), Vector2(7.5, -145), Color(1, 0.9, 0.78, 0.55), 2.0, true)      # the light down the bridge
	_cc(Vector2(1.5, -140), 1.7, _skin.darkened(0.45))
	_cc(Vector2(9.5, -140), 1.7, _skin.darkened(0.45))


## His unibrow, sculpted: thick at the ends, thinner where it meets over the
## nose. `inner` > 0 brings the middle down (a frown), < 0 lifts it.
func _brows(inner: float) -> void:
	# two heavy brows (the sheet), thick at the nose and driven down there by `inner`
	_brow(Vector2(1, -159.0 + inner * 0.7), Vector2(-20, -163), 10.0, 7.0, 1.5)
	_brow(Vector2(8, -159.0 + inner * 0.7), Vector2(29, -163), 10.0, 7.0, 1.5)
	# a deep crease between them when they come down
	if inner > 2.0:
		_ln(Vector2(4.5, -158), Vector2(4.5, -152), Color(_skin.darkened(0.35), clampf(inner / 10.0, 0.0, 0.8)), 2.0, true)


## One brow: a furry band from `a` (by the nose) to `b`, `w_a` thick at a, `w_b`
## at b, arched up by `arch`, with a few hairs flicking up out of it.
func _brow(a: Vector2, b: Vector2, w_a: float, w_b: float, arch: float) -> void:
	var mid := (a + b) * 0.5 + Vector2(0, -arch * 2.0)
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 7:
		var q := i / 6.0
		var p := a.lerp(mid, q).lerp(mid.lerp(b, q), q)
		var w := lerpf(w_a, w_b, q) * (1.0 - 0.25 * pow(q, 4.0))
		top.append(p + Vector2(0, -w * 0.5))
		bot.append(p + Vector2(0, w * 0.5))
	var pts := PackedVector2Array(top)
	for i in range(bot.size() - 1, -1, -1):
		pts.append(bot[i])
	_shape(pts, C_HAIR, 3.0)
	for i in [1, 3, 5]:
		var t0: Vector2 = top[i]
		_ln(t0 + Vector2(0, 1), t0 + (b - a).normalized() * 3.5 + Vector2(0, -3.5), C_HAIR, 2.0, true)


## Out cold: mouth hanging open, tongue lolling out of the side.
func _dead_mouth() -> void:
	_oval(Vector2(4, -135), 8.0, 5.0, C_MOUTH, 3.0)
	_oval(Vector2(10, -128), 4.5, 7.0, Color("d9675e"), 2.0, 0.3)


## Mouth wide open in a yell, tongue waggling.
func _yell() -> void:
	var o := 1.0 + sin(anim_t * 17.0) * 0.12
	_oval(Vector2(4, -134), 9.0 * o, 9.0 * o, C_MOUTH, 3.0)
	_oval(Vector2(4 + sin(anim_t * 21.0) * 2.0, -129), 5.0, 3.5, Color("d9675e"), 2.0)
	_rc(Rect2(-2, -143, 12, 3), C_EYE, true)


## Clenched teeth with the corners pulled down.
## A big toothy grin (the flex).
func _grin() -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var a := PI * i / 8.0
		pts.append(Vector2(4.0 - cos(a) * 13.0, -140.0 + sin(a) * 8.0))
	_pg(pts, C_EYE)
	_pl(pts, C_OL, 2.5, true)
	_ln(Vector2(-9, -140), Vector2(17, -140), C_OL, 2.5, true)
	for i in range(1, 4):
		var tx := -9.0 + i * 6.5
		_ln(Vector2(tx, -140), Vector2(tx, -135), C_OL, 1.5, true)


## The smile with his tongue out of the corner: poking out (concentrating), or
## flapping about (running flat out).
func _tongue_out(flap: bool) -> void:
	_smile()
	var w := sin(anim_t * 26.0) * 3.0 if flap else 0.0
	var tip := Vector2(19.0 + (6.0 if flap else 0.0), -132.0 + w)
	_shape(PackedVector2Array([Vector2(10, -136), Vector2(14, -138), tip + Vector2(3, -2), tip + Vector2(2, 3), Vector2(11, -132)]), Color("e0707a"), 2.0)
	_ln(Vector2(12, -135), tip + Vector2(-1, 0), Color("b04a55"), 1.5, true)

## His resting face: a happy open smile, top teeth showing, a bit of tongue.
func _smile() -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var a := PI * i / 8.0
		pts.append(Vector2(4.0 - cos(a) * 10.0, -138.0 + sin(a) * 7.0))
	_pg(pts, C_MOUTH)
	_oval(Vector2(4, -133.5), 4.5, 2.4, Color("d9656a"), 0.0)
	# the gap in his front teeth
	_rc(Rect2(-3, -138, 6, 3.4), C_EYE)
	_rc(Rect2(5, -138, 6, 3.4), C_EYE)
	_pl(pts, C_OL, 2.2, true)
	_ln(Vector2(-6, -138), Vector2(14, -138), C_OL, 2.2, true)
	# smile lines lifting the cheeks
	_ln(Vector2(-9, -137), Vector2(-7, -140), C_OL, 2.0, true)
	_ln(Vector2(17, -137), Vector2(15, -140), C_OL, 2.0, true)


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
	if tool == "shovel":
		_shovel(p0, p1)
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


## The shovel (the hotbar's digging tool): a straight haft, a cross-grip at
## the top, and a broad flat blade of shoulder-bone lashed on at the end.
func _shovel(p0: Vector2, p1: Vector2) -> void:
	var d := (p1 - p0).normalized()
	var n := Vector2(-d.y, d.x)
	var neck := p1 - d * 34.0
	_shape(PackedVector2Array([p0 + n * 4.0, neck + n * 4.0, neck - n * 4.0, p0 - n * 4.0]), C_WOOD, 3.0)
	_ln(p0 - n * 10.0, p0 + n * 10.0, C_WOOD2, 6.0, true)            # the grip
	var blade := PackedVector2Array([neck + n * 14.0, neck + d * 26.0 + n * 15.0, p1 + d * 10.0 + n * 6.0,
		p1 + d * 14.0, p1 + d * 10.0 - n * 6.0, neck + d * 26.0 - n * 15.0, neck - n * 14.0])
	_shape(blade, Pal.KEY_BONE.darkened(0.05), 3.0)
	_ln(neck + d * 6.0, p1 + d * 4.0, Pal.KEY_BONE.darkened(0.3), 2.0, true)
	for k in 2:
		var q := neck + d * (2.0 + k * 6.0)
		_ln(q + n * 9.0, q - n * 9.0, C_VINE, 3.0, true)              # lashed on


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
	if _bb != null:
		_hands.append(_bb.xf * hd)
	var buff := 1.0 + 0.22 * _sun_k          # SUNFIRE: thicker arms, a bigger bicep
	# a cartoon strongman's arm: a round shoulder, and forearms thicker than the upper arm
	_limb([sh, el, hd], [[17.0 * buff, 14.0 * buff], [15.0 * buff, 20.0 * buff]])
	_oval(sh.lerp(el, 0.55), sh.distance_to(el) * 0.4, bicep * 0.85 * (1.0 + 0.45 * _sun_k), _skin, 0.0, (el - sh).angle())
	_forearm_wrap(el, hd, 17.0 * buff)
	if fist:
		_fist(hd, 10.5)


## A big fist: a round mitt with the knuckles marked.
func _fist(hd: Vector2, r: float = 12.0) -> void:
	_dot(hd, r, _skin, 3.5)
	var k := _skin.darkened(0.4)
	_ac(hd + Vector2(r * 0.15, 0), r * 0.6, -0.9, 0.9, 6, k, 2.0, true)
	_ln(hd + Vector2(-r * 0.2, -r * 0.55), hd + Vector2(r * 0.3, -r * 0.3), k, 2.0, true)


## Outline pass first, then fill, so segments merge cleanly. Each segment
## tapers from w[i][0] to w[i][1], the joints rounded.
func _limb(p: Array, w: Array) -> void:
	var dark := _skin.darkened(0.42)
	for i in p.size() - 1:
		var w0: float = w[i][0]
		var w1: float = w[i][1]
		_taper(p[i], p[i + 1], w0 + 5.0, w1 + 5.0, dark)
	for i in p.size() - 1:
		_taper(p[i], p[i + 1], w[i][0], w[i][1], _skin.darkened(0.16))
	for i in p.size() - 1:
		var w0: float = w[i][0]
		var w1: float = w[i][1]
		var off: Vector2 = LIGHT * w0 * 0.12
		_taper(p[i] + off, p[i + 1] + off, w0 * 0.72, w1 * 0.72, _skin)


## A limb segment that tapers from width w0 at a to w1 at b, ends rounded.
func _taper(a: Vector2, b: Vector2, w0: float, w1: float, col: Color) -> void:
	var d := b - a
	if d.length_squared() < 0.01:
		_cc(a, w0 * 0.5, col)
		return
	var n := Vector2(-d.y, d.x).normalized()
	var q := PackedVector2Array([a + n * w0 * 0.5, b + n * w1 * 0.5, b - n * w1 * 0.5, a - n * w0 * 0.5])
	if _bb != null:
		_bb.quad(q[0], q[1], q[2], q[3], col)
	else:
		_pg(q, col)
	_cc(a, w0 * 0.5, col)
	_cc(b, w1 * 0.5, col)


## A convex shape filled as a fan of triangles (no triangulating every frame).
func _fan(pts: PackedVector2Array, col: Color) -> void:
	if _bb == null:
		_pg(pts, col)
		return
	for i in range(1, pts.size() - 1):
		_bb.tri(pts[0], pts[i], pts[i + 1], col)


## The mane: spikes round the back of his head, painted with fur. The long
## ones swing most with the motion (_hair_off).
func _mane() -> void:
	# the design sheet's big wild mane: two layers of jagged spikes all round the
	# back and top of the head (vector shapes, no texture), the long ones swinging.
	# Their roots never move: built once (_mane_spikes); only the tips move.
	var hooded := skin in ["wolf_hood", "bear_cloak"]
	if _mane_spikes.is_empty() or _mane_hooded != hooded:
		_build_mane_spikes(hooded)
	var sway := sin(anim_t * 2.4) * 1.5
	# the mass of it: a solid base round the back of the head
	_oval(MANE_C + Vector2(-4, -2), 31.0, 29.0, C_HAIR.darkened(0.1), 1.2)
	var reach_k := 0.6 if hooded else 1.3
	var hi := Color(C_HAIR_HI, 0.9)
	for s in _mane_spikes:
		var swing: float = s[3]
		var tip: Vector2 = (s[2] as Vector2) + Vector2(sway * swing, 0) + _flutter(float(s[5]), swing * reach_k)
		_tri3(PackedVector2Array([s[0], s[1], tip]), s[4], 1.2)
		if s[6] != Vector2.INF:
			_ln(s[6], tip.lerp(MANE_C, 0.25), hi, 2.2, true)


## The mane's spikes: [root a, root b, tip at rest, swing, colour, flutter phase,
## start of its light strand (INF: none)]. Darker, longer ones behind first.
var _mane_spikes: Array = []
var _mane_hooded := false

func _build_mane_spikes(hooded: bool) -> void:
	_mane_spikes.clear()
	_mane_hooded = hooded
	for layer in 2:
		var n := 12 if layer == 0 else 10
		var col := C_HAIR.darkened(0.08) if layer == 0 else C_HAIR.lightened(0.05)
		for i in n:
			var a := deg_to_rad(lerpf(-28.0, -250.0, float(i) / (n - 1)) + (9.0 if layer == 1 else 0.0))
			if hooded and a > deg_to_rad(-150.0):
				continue                                # under the hood: only the back shows
			var r := (38.0 if layer == 0 else 33.0) + 10.0 * float((i * 7 + layer * 3) % 5) / 4.0
			var w := 0.46 if layer == 0 else 0.4
			_mane_spikes.append([MANE_C + Vector2.from_angle(a - w) * 20.0, MANE_C + Vector2.from_angle(a + w) * 20.0,
				MANE_C + Vector2.from_angle(a) * r, (r - 26.0) / 26.0, col, i * 1.3 + layer * 0.6,
				MANE_C + Vector2.from_angle(a) * 22.0 if layer == 1 else Vector2.INF])


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
	if pts.size() == 3 and _bb != null:
		_tri3(pts, fill, w)
		return
	if _bb != null:
		_bb.poly_pair(pts, fill.darkened(0.30), _lit(pts), fill)
	else:
		_pg(pts, fill.darkened(0.30))
		_pg(_lit(pts), fill)
	if w > 0.0:
		var ring := PackedVector2Array(pts)
		ring.append(pts[0])
		_pl(ring, fill.darkened(0.60), w * 0.62, true)


## A triangle the way _shape draws a shape, but cheap (spikes, tufts, fangs): the
## rim is a slightly bigger dark triangle behind it, no outline to build.
func _tri3(pts: PackedVector2Array, fill: Color, w: float) -> void:
	var p0 := pts[0]
	var p1 := pts[1]
	var p2 := pts[2]
	var mid := (p0 + p1 + p2) / 3.0
	if w > 0.0:
		var g := w * 0.62
		_bb.tri(p0 + (p0 - mid).normalized() * g, p1 + (p1 - mid).normalized() * g, p2 + (p2 - mid).normalized() * g, fill.darkened(0.60))
	_bb.tri(p0, p1, p2, fill.darkened(0.30))
	# the lit copy (as _lit does it, inline)
	var span := maxf(p0.distance_to(mid), maxf(p1.distance_to(mid), p2.distance_to(mid)))
	var push := LIGHT * minf(5.0, span * 0.10) + mid * 0.13
	_bb.tri(p0 * 0.87 + push, p1 * 0.87 + push, p2 * 0.87 + push, fill)


## _shape for a big shape drawn every frame whose points only move a little (the
## hair, the head, the tunic): cut into triangles once per `key`, then reused.
var _tri_cache := {}

func _shape_k(key: String, pts: PackedVector2Array, fill: Color, w: float = OLW) -> void:
	if _bb == null:
		_shape(pts, fill, w)
		return
	var idx: PackedInt32Array = _tri_cache.get(key, PackedInt32Array())
	if idx.is_empty() or int(_tri_cache.get(key + "#", -1)) != pts.size():
		idx = Geometry2D.triangulate_polygon(pts)
		if idx.is_empty():
			return
		_tri_cache[key] = idx
		_tri_cache[key + "#"] = pts.size()
	_bb.poly_pair_idx(pts, idx, fill.darkened(0.30), _lit(pts), fill)
	if w > 0.0:
		var ring := PackedVector2Array(pts)
		ring.append(pts[0])
		_pl(ring, fill.darkened(0.60), w * 0.62, true)


## A plain band along a limb (the wraps): no round ends, they sit on the limb.
func _wrap_band(a: Vector2, b: Vector2, w0: float, w1: float, col: Color) -> void:
	var d := b - a
	if d.length_squared() < 0.01:
		return
	var n := Vector2(-d.y, d.x).normalized()
	if _bb != null:
		_bb.quad(a + n * w0 * 0.5, b + n * w1 * 0.5, b - n * w1 * 0.5, a - n * w0 * 0.5, col)
	else:
		_pg(PackedVector2Array([a + n * w0 * 0.5, b + n * w1 * 0.5, b - n * w1 * 0.5, a - n * w0 * 0.5]), col)


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


## The aura, under everything: a gold halo breathing round him, and turning rays.
func _paint_sun_aura() -> void:
	var c := Vector2(0, -38)
	var warn := sun_t < Sunfire.WARN and fmod(sun_t * 6.0, 1.0) < 0.5
	var a := 0.35 if warn else 1.0
	var pulse := 1.0 + 0.06 * sin(anim_t * 8.0)
	for i in 3:
		_cc(c, (62.0 - i * 14.0) * pulse, Color(Sunfire.GOLD, (0.08 + i * 0.06) * a))
	for i in 10:
		var ang := i * TAU / 10.0 + anim_t * 1.6
		var p0 := c + Vector2.from_angle(ang) * 30.0
		var p1 := c + Vector2.from_angle(ang) * (66.0 + 10.0 * sin(anim_t * 7.0 + i)) * pulse
		_ln(p0, p1, Color(Sunfire.WHITE_HOT, 0.22 * a), 4.0)
	# behind him: fire blazing up off his shoulders and back, trailing as he moves
	var lean := clampf(-velocity.x / 520.0, -0.9, 0.9)
	var g := 1.0 + 0.15 * _sun_k
	var f := float(facing)
	for bf in [[Vector2(-f * 22.0, -52.0), 34.0], [Vector2(f * 20.0, -54.0), 28.0], [Vector2(-f * 24.0, -30.0), 26.0], [Vector2(-f * 6.0, -62.0), 30.0]]:
		var bp: Vector2 = bf[0]
		Sunfire.flame(_bb, bp * g, float(bf[1]) * _sun_k, anim_t * 1.2 + bp.x * 0.3, 0.85 * a, lean)


## Fire in both fists and in his hair; the embers he sheds.
## The air kicks' light, in his own upright frame (it doesn't flip with him):
## the snap kick's whoosh up to a star at the foot, and the flash kick's
## crescent, white-hot at the foot and fading to orange, chasing it round.
func _paint_kick() -> void:
	if not _kicking() or dead:
		return
	var k := 1.0 - attacking / _swing_time
	_stm(Transform2D(0.0, Vector2(ART * facing, ART), 0.0, Vector2.ZERO))
	if _swing_kind == "kick1":
		var hip := Vector2(22, -62)
		var up := sin(clampf(k / 0.55, 0.0, 1.0) * PI * 0.5)
		var fade := 1.0 - clampf((k - 0.45) / 0.55, 0.0, 1.0)
		var a1 := lerpf(0.785, -0.744, up)
		for w in 3:
			_ac(hip, 68.0 - w * 9.0, a1, 0.785, 12, Color(0.85, 0.95, 1.0, (0.85 - w * 0.25) * fade), 10.0 - w * 3.0)
		if up > 0.95 and fade > 0.2:
			var tip := Vector2(80, -114)
			var s := 26.0 * fade
			_ln(tip + Vector2(0, -s), tip + Vector2(0, s), Color(1, 1, 1, 0.9 * fade), 5.0)
			_ln(tip + Vector2(-s, 0), tip + Vector2(s, 0), Color(1, 1, 1, 0.9 * fade), 5.0)
	else:
		var e := k * k * (3.0 - 2.0 * k)
		var pivot := Vector2(0, -38)
		var now := -0.860 - TAU * e              # where the foot is: it started up and ahead
		var tail := minf(TAU * e, 2.6)
		var fade := 1.0 - clampf((k - 0.75) / 0.25, 0.0, 1.0)
		for l in [[110.0, 22.0, Color(1.0, 0.55, 0.12, 0.35)], [104.0, 13.0, Color(1.0, 0.82, 0.3, 0.7)], [100.0, 6.0, Color(1.0, 0.98, 0.85, 0.95)]]:
			var col: Color = l[2]
			_ac(pivot, l[0], now, now + tail, 24, Color(col, col.a * fade), l[1])
		for i in 5:                              # embers flung off the crescent
			var a := now + tail * (i / 5.0) + sin(anim_t * 20.0 + i) * 0.05
			_cc(pivot + Vector2.from_angle(a) * (120.0 + 10.0 * sin(anim_t * 13.0 + i * 2.0)), 4.0, Color(1.0, 0.8, 0.3, 0.8 * fade))
		_cc(pivot + Vector2.from_angle(now) * 95.0, 16.0, Color(1.0, 0.95, 0.7, 0.45 * fade))
	_st(Vector2.ZERO, 0.0, Vector2.ONE)


func _paint_sun_flames() -> void:
	var warn := sun_t < Sunfire.WARN and fmod(sun_t * 6.0, 1.0) < 0.5
	var a := 0.45 if warn else 1.0
	# the fire trails behind him as he moves
	var lean := clampf(-velocity.x / 520.0, -0.9, 0.9)
	for i in _hands.size():
		var h: Vector2 = _hands[i]
		_bb.circle(h, 9.0, Color(Sunfire.HOT, 0.8 * a), 12)
		Sunfire.flame(_bb, h + Vector2(0, 4), 28.0, anim_t * 1.3 + i * 2.1, a, lean * 0.6)
	for k in 3:
		var hx := (k - 1) * 7.0
		Sunfire.flame(_bb, _head_at + Vector2(hx, 4), 18.0 + 8.0 * float(k == 1), anim_t + k * 1.7, 0.85 * a, lean)
	for s in _sun_sparks:
		var q: float = clampf(float(s[2]) / 0.7, 0.0, 1.0)
		_bb.circle(to_local(s[0]), 3.0 * q + 0.8, Color(Sunfire.GOLD, q), 6)


## Through the dark: his halo, the fists' glow, the embers.
func draw_glow(g) -> void:   # g: the glow layer's Batch
	if sun_t <= 0.0 or dead:
		return
	var o := global_position + Vector2(0, -38)
	var warn := sun_t < Sunfire.WARN and fmod(sun_t * 6.0, 1.0) < 0.5
	var a := 0.4 if warn else 1.0
	g.draw_circle(o, 90.0 + 8.0 * sin(anim_t * 8.0), Color(1.0, 0.8, 0.3, 0.16 * a))
	g.draw_circle(o, 48.0, Color(1.0, 0.85, 0.45, 0.18 * a))
	for h in _hands:
		g.draw_circle(to_global(h), 15.0, Color(1.0, 0.55, 0.15, 0.3 * a))
		g.draw_circle(to_global(h), 5.0, Color(1.0, 0.95, 0.7, 0.7 * a))
	g.draw_circle(to_global(_head_at), 16.0, Color(1.0, 0.6, 0.2, 0.45 * a))
	for s in _sun_sparks:
		var q: float = clampf(float(s[2]) / 0.7, 0.0, 1.0)
		g.draw_circle(s[0], 2.5, Color(1.0, 0.85, 0.4, q))


