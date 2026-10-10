extends Node3D
## UGU IN 3D, for the home (shelter/home.gd), true to his design sheet
## (docs/caveman_design.png) and to his 2D rig (common/player.gd): the big wild
## mane, a hairline of locks, heavy brows in a scowl, a strong jaw, a short beard
## and moustache, brown eyes; the fur tunic over one shoulder with a light-fur
## trim and a jagged hem (the leaf skirt in era 1), a fang necklace, a rope belt
## and a pouch, leather forearm wraps, fur calf wraps tied with cord, bare feet.
## His costume (GameState.skin) recolours the hide and adds its pieces; he
## carries his weapon (GameState.weapon).
## Smooth shapes built in code: the head, the beard, the hair cap and the tunic
## are meshes of their own (_head_mesh, _tunic_mesh); the rest are capsules and
## spheres, with a soft rim light.
## Animated by code: a walk / run cycle, breathing, a tuck in the air; and THE AIR:
## every loose piece (mane spikes, the hem, belt ends, fangs, capes) is a pivot
## that drags behind him as he moves, flies up as he falls, and flutters, faster
## the faster he goes.
## The game sets `speed` and `air` every frame (his velocity he works out from
## how he moved), and calls `refresh()` after his costume or weapon changes.
## Feet at the origin, facing +Z.

const SKIN := Color("c98d63")
const SKIN_DARK := Color("a46a46")
const HAIR := Color("45302a")
const HAIR_HI := Color("6e4c3a")
const FUR := Color("7a4b36")
const FUR_DARK := Color("4a2c1f")
const FUR_LIGHT := Color("d9b08e")
const LEATHER := Color("8a5a3a")
const CORD := Color("3b2a22")
const FANG := Color("efe6d2")
const ROPE := Color("a77a52")
const EYE := Color("efe8da")
const IRIS := Color("6a3c1c")
const DARK := Color("1e1612")
const WOOD := Color("846141")
const LEAF := Color("6a8447")

var speed := 0.0                        ## 0 standing .. 1 running (set by the game)
var air := false
var era := 2
var vel := Vector3.ZERO                 ## his velocity (world), worked out from how he moved
var _last := Vector3.INF
var _t := 0.0
var _phase := 0.0
var _drag := Vector3.ZERO               ## the air on him, model space: a spring toward -velocity
var _drag_v := Vector3.ZERO
var _hips: Node3D
var _body: Node3D
var _head: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _elbow_l: Node3D
var _elbow_r: Node3D
var _hand_r: Node3D
var _loose: Array = []                  ## [pivot, rest basis, reach, phase, outward dir (model space)]
var _extras: Array = []                 ## era / costume / weapon pieces, rebuilt by refresh()
var _mats := {}                         ## colour -> material (shared)


func _ready() -> void:
	_hips = _node(Vector3(0, 0.86, 0), self)
	_build_legs()
	_body = _node(Vector3.ZERO, _hips)
	_build_torso()
	_build_arms()
	_build_head()
	refresh()


## ------------------------------------------------------------------ the body
func _build_legs() -> void:
	for side in [-1.0, 1.0]:
		var leg := _node(Vector3(side * 0.12, 0, 0), _hips)
		_part(_capsule(0.095, 0.46), SKIN, Vector3(0, -0.2, 0), leg)                          # thigh
		var knee := _node(Vector3(0, -0.42, 0), leg)
		_part(_capsule(0.075, 0.42), SKIN, Vector3(0, -0.19, 0), knee)                        # shin
		# the fur calf wrap, two cord ties, a ragged top
		_part(_cyl(0.092, 0.2, 0.084), FUR, Vector3(0, -0.24, 0), knee)
		for y in [-0.18, -0.3]:
			_part(_torus(0.088, 0.012), CORD, Vector3(0, y, 0), knee)
		for k in 7:
			var a := k * TAU / 7.0
			_loose_part(knee, Vector3(cos(a) * 0.088, -0.13, sin(a) * 0.088), _cone(0.028, 0.06), FUR_DARK, Vector3(0, -1, 0), 0.25, k * 0.9)
		# the bare foot, toes forward
		var foot := _node(Vector3(0, -0.42, 0.04), knee)
		_part(_sphere(0.075), SKIN, Vector3(0, 0, 0.03), foot, Vector3(1.05, 0.55, 1.75))
		for k2 in 4:
			_part(_sphere(0.022), SKIN, Vector3(-0.045 + k2 * 0.03, -0.005, 0.135), foot)
		if side < 0.0:
			_leg_l = leg
			_knee_l = knee
		else:
			_leg_r = leg
			_knee_r = knee


func _build_torso() -> void:
	# a broad chest over a narrower waist, shoulders, pecs
	_part(_sphere(0.27), SKIN, Vector3(0, 0.42, 0), _body, Vector3(1.22, 1.0, 0.8))
	_part(_sphere(0.22), SKIN, Vector3(0, 0.14, 0), _body, Vector3(1.05, 0.95, 0.8))
	for side in [-1.0, 1.0]:
		_part(_sphere(0.1), SKIN, Vector3(side * 0.11, 0.47, 0.17), _body, Vector3(1.2, 0.8, 0.5))
	# (the clothes are era / costume pieces: refresh())


func _build_arms() -> void:
	for side in [-1.0, 1.0]:
		var arm := _node(Vector3(side * 0.34, 0.54, 0), _body)
		_part(_sphere(0.11), SKIN, Vector3.ZERO, arm)                                          # shoulder
		_part(_capsule(0.082, 0.34), SKIN, Vector3(0, -0.16, 0), arm)                         # upper arm, bicep
		_part(_sphere(0.07), SKIN, Vector3(0, -0.13, 0.04), arm, Vector3(1, 1.2, 0.9))
		var elbow := _node(Vector3(0, -0.3, 0), arm)
		_part(_capsule(0.075, 0.32), SKIN, Vector3(0, -0.14, 0.01), elbow)                     # forearm
		# the leather wrap and its cords
		_part(_cyl(0.082, 0.17, 0.074), LEATHER, Vector3(0, -0.18, 0.01), elbow)
		for y in [-0.12, -0.19, -0.25]:
			_part(_torus(0.078, 0.009), LEATHER.darkened(0.4), Vector3(0, y, 0.01), elbow)
		var hand := _node(Vector3(0, -0.32, 0.02), elbow)
		_part(_sphere(0.075), SKIN, Vector3.ZERO, hand, Vector3(0.95, 1.05, 0.9))
		if side < 0.0:
			_arm_l = arm
			_elbow_l = elbow
		else:
			_arm_r = arm
			_elbow_r = elbow
			_hand_r = hand


## ------------------------------------------------------------------ the head
## ONE smooth head (_head_point): a broad skull, a heavy brow ridge, cheekbones,
## a wide squared jaw and a chin. The beard and the hair cap are shells of the
## same head a little bigger, cut along the jaw and along a hairline of locks, so
## they hug him. Spikes of mane, the face's features on top.
const HEAD_C := Vector3(0, 0.14, 0)
const HEAD_R := Vector3(0.172, 0.205, 0.185)


## The point of his head at latitude `lat` (up +) and longitude `lon` (0: the
## front, + toward his +X), pushed out by `inflate`.
func _head_point(lat: float, lon: float, inflate := 1.0) -> Vector3:
	var d := Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))
	var p := d * HEAD_R
	var front := maxf(d.z, 0.0)
	if d.y < 0.0:
		p.x *= 1.0 + 0.16 * (-d.y)                           # the wide jaw
		p.y *= 1.0 - 0.18 * d.y * d.y                         # squared off underneath
		p.z += 0.035 * (-d.y) * front * front                 # the chin forward
	p.z += 0.02 * exp(-pow((d.y - 0.33) / 0.11, 2)) * front * front        # the brow ridge
	p += Vector3(signf(d.x) * 0.012, 0, 0.01) * exp(-pow(d.y / 0.13, 2) - pow((absf(d.x) - 0.6) / 0.2, 2))   # cheekbones
	return HEAD_C + p * inflate


## A mesh of the head's surface pushed out by `inflate`: for each longitude,
## from latitude span(lo).x up to span(lo).y (none where x >= y). The rows follow
## the span, so a cut edge (the jawline, the hairline) is a smooth curve.
func _head_mesh(inflate: float, span: Callable) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 28
	var segs := 96
	for j in segs:
		var lo0 := TAU * float(j) / segs - PI
		var lo1 := TAU * float(j + 1) / segs - PI
		var s0: Vector2 = span.call(lo0)
		var s1: Vector2 = span.call(lo1)
		if s0.x >= s0.y or s1.x >= s1.y:
			continue
		for i in rings:
			var a := _head_point(lerpf(s0.x, s0.y, float(i) / rings), lo0, inflate)
			var b := _head_point(lerpf(s1.x, s1.y, float(i) / rings), lo1, inflate)
			var c := _head_point(lerpf(s1.x, s1.y, float(i + 1) / rings), lo1, inflate)
			var d := _head_point(lerpf(s0.x, s0.y, float(i + 1) / rings), lo0, inflate)
			for p in [a, b, c, a, c, d]:
				st.add_vertex(p)
	st.index()
	st.generate_normals()
	return st.commit()


func _surface(mesh: Mesh, col: Color, parent: Node3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var mat: StandardMaterial3D = _mat(col).duplicate()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	parent.add_child(m)
	return m


## The hairline (a latitude) round his head: low at the nape, up at the temples,
## and over the forehead a row of locks dipping down.
func _hairline(lon: float) -> float:
	var c := cos(lon)
	var locks := 0.52 - 0.13 * pow(maxf(0.0, cos(lon * 13.0 + 0.4)), 2.0)
	var temples := 0.3
	if c > 0.55:
		return lerpf(temples, locks, smoothstep(0.55, 0.8, c))
	return lerpf(-0.75, temples, smoothstep(-0.6, 0.55, c))


## The beard's top edge (a latitude): along the jaw at the front, rising up the
## sides into sideburns. Nothing round the back.
func _beard_top(lon: float) -> float:
	var s := absf(sin(lon))
	return lerpf(-0.3, 0.14, smoothstep(0.45, 0.9, s))


func _build_head() -> void:
	_head = _node(Vector3(0, 0.74, 0.03), _body)
	_part(_cyl(0.1, 0.16, 0.115), SKIN, Vector3(0, -0.07, -0.01), _head)                    # neck
	_surface(_head_mesh(1.0, func(_lo): return Vector2(-PI * 0.5, PI * 0.5)), SKIN, _head)
	# the BEARD: short and thick round the jaw and chin, up the sides as sideburns
	_surface(_head_mesh(1.06, func(lo): return Vector2(-1.3, _beard_top(lo)) if cos(lo) > -0.15 else Vector2.ZERO), HAIR.lerp(FUR, 0.3), _head)
	# the moustache and the mouth, over the beard
	for side in [-1.0, 1.0]:
		var mo := _part(_capsule(0.02, 0.085), HAIR, _head_point(-0.14, side * 0.17, 1.1), _head)
		mo.rotation = Vector3(0, side * 0.3, PI * 0.5 + side * 0.5)
	_part(_capsule(0.009, 0.05), DARK, _head_point(-0.25, 0.0, 1.07), _head).rotation.z = PI * 0.5
	# the nose: a straight bridge, a broad tip
	var bridge := _part(_capsule(0.02, 0.08), SKIN, _head_point(0.08, 0.0, 1.06), _head)
	bridge.rotation.x = -0.4
	_part(_sphere(0.032), SKIN.darkened(0.03), _head_point(-0.06, 0.0, 1.17), _head, Vector3(1.25, 0.9, 1.0))
	for side2 in [-1.0, 1.0]:
		# ears, half under the hair
		_part(_sphere(0.04), SKIN_DARK, _head_point(0.02, side2 * 1.5, 1.02), _head, Vector3(0.5, 1.0, 0.8))
		# the eyes, set in under the brow: white, brown iris, pupil, a glint
		var e := _head_point(0.13, side2 * 0.4, 0.93)
		_part(_sphere(0.033), EYE, e, _head, Vector3(1.15, 0.8, 0.75))
		_part(_sphere(0.02), IRIS, e + Vector3(-side2 * 0.003, -0.002, 0.02), _head, Vector3(1, 1, 0.45))
		_part(_sphere(0.01), DARK, e + Vector3(-side2 * 0.003, -0.002, 0.028), _head, Vector3(1, 1, 0.4))
		_part(_sphere(0.005), Color.WHITE, e + Vector3(0.006, 0.006, 0.032), _head).material_override = _glow(Color.WHITE, 0.5)
		# a heavy upper lid (the determined look)
		var lid := _part(_sphere(0.036), SKIN_DARK, e + Vector3(0, 0.017, 0.006), _head, Vector3(1.2, 0.42, 0.8))
		lid.rotation.z = -side2 * 0.2
		# the heavy BROWS, angled down to the nose: the scowl
		var brow := _part(_capsule(0.024, 0.13), HAIR, _head_point(0.3, side2 * 0.36, 1.07), _head)
		brow.rotation = Vector3(-0.2, side2 * 0.35, PI * 0.5 + side2 * 0.32)
	_build_hair()


## The hair: the cap (a shell of the head from the hairline up, so its edge is a
## row of locks over the forehead), and the wild mane of spikes round the back and
## top (each a loose pivot: it moves in the air).
func _build_hair() -> void:
	_surface(_head_mesh(1.09, func(lo): return Vector2(_hairline(lo), PI * 0.5)), HAIR, _head)
	var crown := HEAD_C + Vector3(0, 0.03, -0.02)
	var n := 0
	for layer in 2:
		var col := HAIR.darkened(0.12) if layer == 0 else HAIR
		for el in ([5.0, 28.0, 52.0, 76.0] if layer == 0 else [18.0, 42.0, 66.0]):
			var count := 11 if el < 60.0 else 6
			for i in count:
				var az := deg_to_rad(lerpf(70.0, 290.0, float(i) / (count - 1)) + (12.0 if layer == 1 else 0.0)) if el < 70.0 else (i * TAU / count)
				var e := deg_to_rad(el)
				var dir := Vector3(sin(az) * cos(e), sin(e), cos(az) * cos(e))
				var out := (dir + Vector3(0, 0.12, -0.5)).normalized()
				var len := 0.13 + 0.06 * float((i * 7 + n) % 3) / 2.0 + (0.04 if layer == 0 else 0.0)
				_loose_part(_head, crown + dir * 0.18, _cone(0.05, len), col if (i + n) % 3 != 0 else HAIR_HI, out, 0.7 + 0.3 * len / 0.19, n * 0.37)
				n += 1


## ------------------------------------------------------------------ clothes, costume, weapon
func _hide() -> Array:
	match GameState.skin:
		"wolf_hood", "wolf_pelt":
			return [Pal.WOLF, Pal.WOLF_DARK]
		"ember_paint":
			return [Color("9a4a22"), Color("4a2414")]
		"bear_cloak":
			return [Color("6b4a2e"), Color("45301c")]
		"firekeeper":
			return [Color("c49a64"), Color("8a6a3c")]
	return [FUR, FUR_DARK]


## His era's clothes, his costume, his weapon: rebuilt from GameState.
func refresh() -> void:
	for e in _extras:
		(e as Node).queue_free()
	_extras.clear()
	_loose = _loose.filter(func(l): return not (l[0] as Node).has_meta("extra"))
	var cols := _hide()
	var fur: Color = cols[0]
	var dark: Color = cols[1]
	if era >= 2:
		# the TUNIC: a fur shell round the torso, cut on the diagonal (_tunic_cut)
		var shell := MeshInstance3D.new()
		shell.mesh = _tunic_mesh()
		shell.material_override = _mat(fur).duplicate()
		(shell.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
		_body.add_child(shell)
		_extras.append(shell)
		# the strap's light fur trim along the cut, front and back: soft tufts
		for side in [1.0, -1.0]:
			for k in 11:
				var x := lerpf(-0.36, 0.33, k / 10.0)
				var y := _tunic_cut(x)
				var z: float = side * TUNIC_R.z * sqrt(maxf(0.0, 1.0 - pow(x / TUNIC_R.x, 2) - pow((y - TUNIC_C.y) / TUNIC_R.y, 2))) * 1.04
				var tuft := _extra(_sphere(0.045), FUR_LIGHT if k % 2 == 0 else FUR_LIGHT.darkened(0.08), Vector3(x, y, z), _body, Vector3(1.25, 0.8, 0.8))
				tuft.rotation.z = -0.75
		# the skirt below the belt, and its jagged light hem: each point moves in the air
		_extra(_cyl(0.25, 0.3, 0.31), fur, Vector3(0, -0.13, 0), _hips)
		for k2 in 14:
			var a := k2 * TAU / 14.0
			var rad := Vector3(sin(a), 0, cos(a))
			_loose_part(_hips, rad * 0.3 + Vector3(0, -0.27, 0), _cone(0.05, 0.11), FUR_LIGHT if k2 % 2 == 0 else fur, (rad * 0.25 + Vector3(0, -1, 0)).normalized(), 0.9, 30.0 + k2 * 0.9).set_meta("extra", true)
		for k3 in 8:
			var a2 := k3 * TAU / 8.0
			_extra(_capsule(0.008, 0.18), dark, Vector3(sin(a2) * 0.29, -0.13, cos(a2) * 0.29), _hips)
	else:
		# era 1: the LEAF skirt, each leaf moving in the air
		for k4 in 12:
			var a3 := k4 * TAU / 12.0
			var rad2 := Vector3(sin(a3), 0, cos(a3))
			_loose_part(_hips, rad2 * 0.23 + Vector3(0, -0.04, 0), _sphere(0.06), LEAF.lightened((k4 % 3) * 0.07), (rad2 * 0.2 + Vector3(0, -1, 0)).normalized(), 0.9, 40.0 + k4, Vector3(0.9, 2.4, 0.4)).set_meta("extra", true)
	# the twisted ROPE BELT, the knot, its swinging ends, the pouch
	_extra(_torus(0.25, 0.028), ROPE, Vector3(0, 0.02, 0), _hips, Vector3(1, 1, 0.85))
	_extra(_torus(0.25, 0.018), ROPE.darkened(0.35), Vector3(0, 0.025, 0), _hips, Vector3(1.02, 1.6, 0.87)).rotation.y = 0.3
	_extra(_sphere(0.04), ROPE, Vector3(0.06, 0.02, 0.215), _hips)
	for k5 in 2:
		_loose_part(_hips, Vector3(0.05 + k5 * 0.03, 0.0, 0.22), _capsule(0.012, 0.12), ROPE, Vector3(0.1 * k5, -1, 0.15).normalized(), 0.6, 50.0 + k5).set_meta("extra", true)
	_extra(_sphere(0.075), LEATHER, Vector3(-0.21, -0.05, 0.13), _hips, Vector3(0.9, 1.1, 0.6))
	_extra(_sphere(0.075), LEATHER.darkened(0.15), Vector3(-0.21, 0.0, 0.135), _hips, Vector3(0.95, 0.45, 0.62))
	# the FANG NECKLACE: a dark cord, seven pale fangs (they swing)
	_extra(_torus(0.15, 0.008), CORD, Vector3(0, 0.66, 0.08), _body, Vector3(1, 1, 1)).rotation.x = 0.7
	for k6 in 7:
		var a4 := lerpf(-0.95, 0.95, k6 / 6.0)
		var at2 := Vector3(sin(a4) * 0.14, 0.63 - cos(a4) * 0.06, 0.17 + cos(a4) * 0.045)
		_loose_part(_body, at2, _cone(0.014, 0.06 if absf(a4) < 0.4 else 0.045), FANG, Vector3(0, -1, 0.15).normalized(), 0.3, 60.0 + k6).set_meta("extra", true)
	_costume_pieces()
	_weapon()


## The tunic: an ellipsoid shell a little bigger than his torso, only the part
## below the cut kept (over the left shoulder, down across to the right hip).
const TUNIC_C := Vector3(0, 0.3, 0.0)
const TUNIC_R := Vector3(0.375, 0.44, 0.255)


## The height of the cut at `x`: high over the left shoulder, low at the right hip.
func _tunic_cut(x: float) -> float:
	return 0.66 - (x + 0.36) * 0.82


func _tunic_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 18
	var segs := 32
	var pt := func(i: int, j: int) -> Vector3:
		var lat := lerpf(-PI * 0.5, PI * 0.5, float(i) / rings)
		var lon := TAU * float(j) / segs
		return TUNIC_C + Vector3(cos(lat) * sin(lon) * TUNIC_R.x, sin(lat) * TUNIC_R.y, cos(lat) * cos(lon) * TUNIC_R.z)
	for i in rings:
		for j in segs:
			var a: Vector3 = pt.call(i, j)
			var b: Vector3 = pt.call(i, j + 1)
			var c: Vector3 = pt.call(i + 1, j + 1)
			var d: Vector3 = pt.call(i + 1, j)
			var mid := (a + c) * 0.5
			if mid.y > _tunic_cut(mid.x) or mid.y < 0.0:
				continue                                # above the cut (bare), or below the belt (the skirt)
			for p in [a, c, b, a, d, c]:
				st.set_normal(((p as Vector3) - TUNIC_C) / (TUNIC_R * TUNIC_R))
				st.add_vertex(p)
	st.generate_normals()
	return st.commit()


func _costume_pieces() -> void:
	match GameState.skin:
		"wolf_hood":
			_extra(_sphere(0.235), Pal.WOLF, Vector3(0, 0.25, -0.03), _head, Vector3(1.06, 0.82, 1.06))
			_extra(_capsule(0.06, 0.2), Pal.WOLF_BELLY, Vector3(0, 0.3, 0.2), _head).rotation.x = PI * 0.5
			for side in [-1.0, 1.0]:
				_extra(_cone(0.06, 0.14), Pal.WOLF_DARK, Vector3(side * 0.12, 0.43, -0.02), _head)
			for k in 4:
				_loose_part(_body, Vector3(0, 0.62 - k * 0.13, -0.24), _sphere(0.14 - k * 0.012), Pal.WOLF, Vector3(0, -1, -0.3).normalized(), 0.3 + k * 0.25, 70.0 + k, Vector3(1.2, 1.0, 0.4)).set_meta("extra", true)
		"bear_cloak":
			_extra(_sphere(0.235), Color("6b4a2e"), Vector3(0, 0.25, -0.03), _head, Vector3(1.07, 0.82, 1.07))
			for side2 in [-1.0, 1.0]:
				_extra(_sphere(0.065), Color("6b4a2e"), Vector3(side2 * 0.15, 0.41, -0.02), _head)
			for k2 in 5:
				_loose_part(_body, Vector3(0, 0.6 - k2 * 0.16, -0.25), _sphere(0.2), Color("6b4a2e"), Vector3(0, -1, -0.35).normalized(), 0.3 + k2 * 0.3, 80.0 + k2, Vector3(1.55, 1.0, 0.32)).set_meta("extra", true)
		"firekeeper":
			_extra(_torus(0.205, 0.022), Color("a0703c"), Vector3(0, 0.25, 0), _head)
			_extra(_sphere(0.035), Color("ff8a2a"), Vector3(0, 0.26, 0.205), _head).material_override = _glow(Color("ff8a2a"), 2.5)
			for k3 in 2:
				_loose_part(_head, Vector3(-0.15, 0.3, -0.1), _cone(0.028, 0.24), [Color("e8e0cc"), Color("c0392b")][k3], Vector3(-0.3 - k3 * 0.2, 1, -0.4).normalized(), 0.6, 90.0 + k3).set_meta("extra", true)
		"ember_paint":
			for k4 in 3:
				_extra(_capsule(0.012, 0.12 - k4 * 0.025), Color("e0602a"), Vector3(-0.08 + k4 * 0.08, 0.3, 0.215), _body)
			_extra(_capsule(0.022, 0.24), DARK, Vector3(0, 0.155, 0.19), _head).rotation.z = PI * 0.5


func _weapon() -> void:
	match GameState.weapon:
		"axe":
			_extra(_cyl(0.022, 0.72, 0.022), WOOD, Vector3(0, 0.22, 0.1), _hand_r).rotation.x = 0.35
			_extra(BoxMesh.new(), Color("8d9196"), Vector3(0, 0.52, 0.22), _hand_r, Vector3(0.04, 0.17, 0.2))
		"hammer":
			_extra(_cyl(0.028, 0.76, 0.028), WOOD.darkened(0.2), Vector3(0, 0.24, 0.1), _hand_r).rotation.x = 0.35
			_extra(BoxMesh.new(), Color.WHITE, Vector3(0, 0.56, 0.22), _hand_r, Vector3(0.24, 0.14, 0.14)).material_override = _glow(Color("e05a2a"), 1.5)
		_:
			var club := _extra(_cyl(0.07, 0.78, 0.032), WOOD, Vector3(0, 0.27, 0.12), _hand_r)
			club.rotation.x = 0.4
			for k in 3:
				_extra(_sphere(0.022), WOOD.darkened(0.25), Vector3(0.05 * (k - 1), 0.5 + k * 0.05, 0.22 + k * 0.02), _hand_r)


## ------------------------------------------------------------------ every frame
func _process(delta: float) -> void:
	_t += delta
	var dt := minf(delta, 1.0 / 30.0)
	if _last != Vector3.INF and delta > 0.0:
		var step := (global_position - _last) / delta
		if step.length() < 20.0:              # (more is a teleport, not a run)
			vel = vel.lerp(step, minf(1.0, delta * 20.0))
	_last = global_position
	var local := global_transform.basis.inverse() * vel                     # his velocity, model space
	var flat := Vector2(local.x, local.z).length()
	var run := maxf(speed, clampf(flat / 5.0, 0.0, 1.0))
	_phase += delta * (2.0 + 9.0 * run) * (1.0 if run > 0.01 else 0.0)
	var swing := sin(_phase) * 0.75 * run
	# THE AIR: a spring toward the opposite of his motion (falling: upward)
	var to := Vector3(-local.x, -local.y * 0.6, -local.z) * 0.14
	_drag_v += ((to - _drag) * 90.0 - _drag_v * 10.0) * dt
	_drag += _drag_v * dt
	_drag = _drag.limit_length(1.2)
	if air:
		_leg_l.rotation.x = -0.95
		_knee_l.rotation.x = 1.2
		_leg_r.rotation.x = -0.4
		_knee_r.rotation.x = 0.6
		_arm_l.rotation = Vector3(-0.5, 0, 0.7)
		_arm_r.rotation = Vector3(-1.0, 0, -0.45)
		_hips.position.y = 0.86
		_body.rotation.x = 0.08
	else:
		_leg_l.rotation.x = swing
		_leg_r.rotation.x = -swing
		_knee_l.rotation.x = maxf(0.0, -sin(_phase)) * 1.1 * run + 0.05
		_knee_r.rotation.x = maxf(0.0, sin(_phase)) * 1.1 * run + 0.05
		_arm_l.rotation = Vector3(-swing * 0.85, 0, 0.14)
		_arm_r.rotation = Vector3(swing * 0.6 - 0.3 * run - 0.25, 0, -0.14)
		_elbow_l.rotation.x = -0.25 - 0.6 * run
		_elbow_r.rotation.x = -0.55 - 0.4 * run
		_hips.position.y = 0.86 - absf(sin(_phase)) * 0.045 * run + sin(_t * 2.2) * 0.007 * (1.0 - run)
		_body.rotation.x = 0.1 * run
	_body.scale = Vector3(1.0, 1.0 + sin(_t * 2.2) * 0.012 * (1.0 - run), 1.0)
	_head.rotation.y = sin(_t * 0.7) * 0.15 * (1.0 - run)
	# every loose piece: pushed by the air round its root, and fluttering
	var spd := clampf(vel.length() / 5.0, 0.0, 1.8)
	for l in _loose:
		var piv: Node3D = l[0]
		if not is_instance_valid(piv):
			continue
		var reach: float = l[2]
		var ph: float = l[3]
		var outward: Vector3 = l[4]
		var f := sin(_t * (5.0 + 7.0 * spd) + ph) + 0.45 * sin(_t * (10.0 + 9.0 * spd) + ph * 1.9)
		var push := _drag + outward * f * (0.05 + 0.16 * spd)
		# tip the piece toward `push`, about the axis across it
		var axis := outward.cross(push)
		var ang := clampf(axis.length() * 1.6, 0.0, 0.9) * reach
		var rest: Basis = l[1]
		if axis.length() > 0.0001:
			piv.basis = Basis(axis.normalized(), ang) * rest
		else:
			piv.basis = rest


## ------------------------------------------------------------------ building blocks
func _node(at: Vector3, parent: Node3D) -> Node3D:
	var n := Node3D.new()
	n.position = at
	parent.add_child(n)
	return n


## A loose piece (it moves in the air): a pivot at `at` on `parent`, the mesh
## pointing along `dir` out of it. `reach`: how freely it moves (0..1).
func _loose_part(parent: Node3D, at: Vector3, mesh: Mesh, col: Color, dir: Vector3, reach: float, phase: float, scl := Vector3.ONE) -> Node3D:
	var piv := _node(at, parent)
	var rest := Basis(Quaternion(Vector3.UP, dir.normalized()))
	piv.basis = rest
	var h := 0.0
	if mesh is CylinderMesh:
		h = (mesh as CylinderMesh).height * 0.5
	elif mesh is CapsuleMesh:
		h = (mesh as CapsuleMesh).height * 0.5
	elif mesh is SphereMesh:
		h = (mesh as SphereMesh).radius * scl.y * 0.8
	_part(mesh, col, Vector3(0, h, 0), piv, scl)
	_loose.append([piv, rest, reach, phase, dir.normalized()])
	return piv


func _part(mesh: Mesh, col: Color, at: Vector3, parent: Node3D, scl := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = _mat(col)
	m.position = at
	m.scale = scl
	parent.add_child(m)
	return m


func _extra(mesh: Mesh, col: Color, at: Vector3, parent: Node3D, scl := Vector3.ONE) -> MeshInstance3D:
	var m := _part(mesh, col, at, parent, scl)
	_extras.append(m)
	return m


## One material per colour, shared: soft, with a gentle rim light so he reads
## against the world.
func _mat(col: Color) -> StandardMaterial3D:
	if _mats.has(col):
		return _mats[col]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.72
	m.rim_enabled = true
	m.rim = 0.18
	m.rim_tint = 0.4
	_mats[col] = m
	return m


func _glow(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 20
	s.rings = 12
	return s


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 16
	c.rings = 6
	return c


func _cyl(r: float, h: float, top: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 18
	c.rings = 1
	return c


func _cone(r: float, h: float) -> CylinderMesh:
	return _cyl(r, h, 0.0)


func _torus(r: float, thick: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = r - thick
	t.outer_radius = r + thick
	t.rings = 24
	t.ring_segments = 8
	return t
