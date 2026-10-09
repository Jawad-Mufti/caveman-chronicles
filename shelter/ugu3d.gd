extends Node3D
## UGU IN 3D, for the home (shelter/home.gd): a low-poly toy figure built from
## shapes in code, true to his 2D drawing (common/player.gd): the big head, the
## wild dark mane with the bone in his topknot, the beard, the heavy unibrow,
## the button nose, amber eyes, warm skin, the loincloth of his era (leaves,
## then leopard hide), his costume (GameState.skin) and his weapon
## (GameState.weapon). Animated by code: a walk cycle (legs, arms, a bob, a
## lean), breathing at rest, a tuck in the air. ~1.75 m tall; feet at the origin.
## The game sets `speed` (0..1 of a run) and `air` each frame; `refresh()`
## after his costume or weapon changes.

const SKIN := Color("c89263")
const SKIN_DARK := Color("a67148")
const HAIR := Color("5a2c18")
const HAIR_HI := Color("94512a")
const BONE := Color("efe4c8")
const LEOPARD := Color("d9a64e")
const SPOT := Color("4a2a14")
const LEAF := Color("6a8447")
const EYE := Color("ece3cd")
const IRIS := Color("d08a2a")          ## amber
const DARK := Color("2a1d16")
const WOOD := Color("846141")

var speed := 0.0                        ## 0 standing .. 1 running
var air := false
var era := 2
var _t := 0.0
var _phase := 0.0
var _hips: Node3D
var _body: Node3D
var _head: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _hand_r: Node3D
var _extras: Array = []                 ## costume and weapon pieces, rebuilt by refresh()


func _ready() -> void:
	_hips = Node3D.new()
	_hips.position = Vector3(0, 0.78, 0)
	add_child(_hips)
	# legs: thigh + shin as one tapered column each, and a big bare foot
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.13, 0, 0)
		_hips.add_child(leg)
		_part(_cyl(0.11, 0.42, 0.09), SKIN, Vector3(0, -0.2, 0), leg)
		_part(_cyl(0.09, 0.38, 0.075), SKIN, Vector3(0, -0.56, 0), leg)
		_part(_ball(0.1), SKIN_DARK, Vector3(0, -0.39, 0.0), leg, Vector3(1, 0.8, 1))
		_part(_ball(0.11), SKIN, Vector3(0, -0.76, 0.07), leg, Vector3(1.0, 0.45, 1.6))
		if side < 0.0:
			_leg_l = leg
		else:
			_leg_r = leg
	# the body: a barrel chest over a narrower waist; the loincloth round the hips
	_body = Node3D.new()
	_hips.add_child(_body)
	_part(_ball(0.27), SKIN, Vector3(0, 0.38, 0), _body, Vector3(1.15, 1.05, 0.85))
	_part(_ball(0.22), SKIN, Vector3(0, 0.12, 0), _body, Vector3(1.05, 0.8, 0.8))
	# the arms: shoulder ball, a thick upper arm and forearm, a fist
	for side2 in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side2 * 0.33, 0.52, 0)
		_body.add_child(arm)
		_part(_ball(0.11), SKIN, Vector3.ZERO, arm)
		_part(_cyl(0.085, 0.3, 0.075), SKIN, Vector3(0, -0.17, 0), arm)
		_part(_cyl(0.075, 0.28, 0.065), SKIN, Vector3(0, -0.44, 0.02), arm)
		var hand := Node3D.new()
		hand.position = Vector3(0, -0.6, 0.03)
		arm.add_child(hand)
		_part(_ball(0.08), SKIN, Vector3.ZERO, hand)
		if side2 < 0.0:
			_arm_l = arm
		else:
			_arm_r = arm
			_hand_r = hand
	# the HEAD: drawn bigger than life, like his 2D one
	_head = Node3D.new()
	_head.position = Vector3(0, 0.78, 0.02)
	_body.add_child(_head)
	_part(_cyl(0.09, 0.12, 0.1), SKIN, Vector3(0, -0.08, 0), _head)                         # the neck
	_part(_ball(0.21), SKIN, Vector3(0, 0.12, 0), _head, Vector3(1.0, 1.08, 0.95))
	for side3 in [-1.0, 1.0]:
		_part(_ball(0.05), SKIN_DARK, Vector3(side3 * 0.2, 0.12, -0.01), _head, Vector3(0.6, 1.0, 0.8))       # ears
		# the eyes: white, an amber iris, a dark pupil
		_part(_ball(0.045), EYE, Vector3(side3 * 0.075, 0.15, 0.175), _head, Vector3(1.0, 1.1, 0.6))
		_part(_ball(0.026), IRIS, Vector3(side3 * 0.075, 0.148, 0.2), _head, Vector3(1, 1, 0.5))
		_part(_ball(0.013), DARK, Vector3(side3 * 0.075, 0.148, 0.212), _head, Vector3(1, 1, 0.5))
	# the heavy UNIBROW, sculpted, one piece across
	_part(BoxMesh.new(), HAIR, Vector3(0, 0.215, 0.18), _head, Vector3(0.26, 0.045, 0.06)).rotation_degrees = Vector3(-10, 0, 0)
	# the BUTTON NOSE
	_part(_ball(0.045), SKIN_DARK.lightened(0.15), Vector3(0, 0.09, 0.215), _head, Vector3(1.1, 0.9, 0.9))
	# a big grin under the beard
	_part(BoxMesh.new(), DARK, Vector3(0, 0.025, 0.2), _head, Vector3(0.1, 0.022, 0.03))
	# the BEARD round the jaw, and the moustache
	_part(_ball(0.17), HAIR, Vector3(0, -0.02, 0.07), _head, Vector3(1.15, 0.75, 0.9))
	_part(_ball(0.06), HAIR, Vector3(-0.05, 0.05, 0.19), _head, Vector3(1.2, 0.5, 0.6))
	_part(_ball(0.06), HAIR, Vector3(0.05, 0.05, 0.19), _head, Vector3(1.2, 0.5, 0.6))
	# re-cover the cheeks and the mouth over the beard
	_part(_ball(0.14), SKIN, Vector3(0, 0.1, 0.09), _head, Vector3(1.05, 0.7, 0.85))
	_part(BoxMesh.new(), DARK, Vector3(0, 0.025, 0.21), _head, Vector3(0.1, 0.022, 0.02))
	_part(_ball(0.045), SKIN_DARK.lightened(0.15), Vector3(0, 0.09, 0.225), _head, Vector3(1.1, 0.9, 0.9))
	# the wild MANE: a thick cap of hair over the crown, the sides and the back...
	var crown := Vector3(0, 0.17, -0.03)
	_part(_ball(0.235), HAIR, crown + Vector3(0, 0.03, -0.01), _head, Vector3(1.06, 0.82, 1.08))
	# ...and spikes bursting out of it all round the crown, the sides and the back,
	# swept back (a wild shock, like his drawing), two tones
	var n := 0
	for el in [10.0, 32.0, 55.0, 78.0]:
		var count := 9 if el < 60.0 else 5
		for i in count:
			var az := deg_to_rad(lerpf(62.0, 298.0, float(i) / (count - 1)) if el < 70.0 else lerpf(0.0, 360.0, float(i) / count))
			var e := deg_to_rad(el)
			var dir := Vector3(sin(az) * cos(e), sin(e), cos(az) * cos(e))
			var swept := (dir + Vector3(0, 0.15, -0.55)).normalized()
			var len := 0.15 + 0.07 * float((i * 7 + n) % 3) / 2.0 + (0.04 if el > 20.0 and el < 70.0 else 0.0)
			var sp := _part(_cone(0.055, len), HAIR if (i + n) % 2 == 0 else HAIR_HI, crown + dir * 0.2 + swept * len * 0.4, _head)
			sp.basis = Basis(Quaternion(Vector3.UP, swept))
			n += 1
	# a ragged fringe over the brow
	for k in 6:
		var fx := -0.13 + k * 0.052
		var fr := _part(_cone(0.045, 0.1), HAIR if k % 2 == 0 else HAIR_HI, Vector3(fx, 0.27, 0.16), _head)
		fr.basis = Basis(Quaternion(Vector3.UP, Vector3(fx * 0.8, -0.35, 1.0).normalized()))
	# side burns into the beard
	for side6 in [-1.0, 1.0]:
		_part(_ball(0.07), HAIR, Vector3(side6 * 0.19, 0.08, 0.04), _head, Vector3(0.6, 1.4, 0.9))
	# the beard's bottom edge: a few points hanging down
	for k2 in 5:
		var bx := -0.1 + k2 * 0.05
		var bp := _part(_cone(0.045, 0.1), HAIR, Vector3(bx, -0.1, 0.1), _head)
		bp.basis = Basis(Quaternion(Vector3.UP, Vector3(bx * 0.5, -1.0, 0.3).normalized()))
	# the TOPKNOT, with a bone through it
	_part(_ball(0.07), HAIR, Vector3(0, 0.38, -0.05), _head, Vector3(1, 1.3, 1))
	_part(_cyl(0.018, 0.26, 0.018), BONE, Vector3(0, 0.4, -0.05), _head).rotation_degrees = Vector3(0, 0, 90)
	for side5 in [-1.0, 1.0]:
		_part(_ball(0.03), BONE, Vector3(side5 * 0.13, 0.4, -0.05), _head)
	refresh()


## His era's loincloth, his costume, his weapon: rebuilt from GameState.
func refresh() -> void:
	for e in _extras:
		(e as Node).queue_free()
	_extras.clear()
	# the loincloth: leaves (era 1), leopard hide (era 2)
	if era >= 2:
		_extra(_cyl(0.26, 0.24, 0.3), LEOPARD, Vector3(0, -0.05, 0), _hips)
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		for k in 9:
			var a := rng.randf() * TAU
			_extra(_ball(0.025), SPOT, Vector3(cos(a) * 0.29, -0.05 + rng.randf_range(-0.08, 0.08), sin(a) * 0.29), _hips)
		_extra(_cyl(0.035, 0.02, 0.035), HAIR, Vector3(0, 0.08, 0), _hips, Vector3(7.6, 1, 7.6))     # the belt
	else:
		for k in 8:
			var a2 := k * TAU / 8.0
			_extra(_ball(0.1), LEAF.lightened((k % 3) * 0.06), Vector3(cos(a2) * 0.2, -0.08, sin(a2) * 0.2), _hips, Vector3(0.8, 1.4, 0.4)).rotation.y = -a2
	match GameState.skin:
		"wolf_hood":
			_extra(_ball(0.23), Color("8a8a90"), Vector3(0, 0.2, -0.04), _head, Vector3(1.05, 0.9, 1.05))
			for side in [-1.0, 1.0]:
				_extra(_cone(0.06, 0.14), Color("6a6a72"), Vector3(side * 0.12, 0.38, -0.02), _head)
			_extra(_ball(0.3), Color("8a8a90"), Vector3(0, 0.3, -0.18), _body, Vector3(1.0, 1.2, 0.3))
		"bear_cloak":
			_extra(_ball(0.36), Color("5a3a22"), Vector3(0, 0.28, -0.16), _body, Vector3(1.1, 1.3, 0.35))
			_extra(_ball(0.23), Color("5a3a22"), Vector3(0, 0.22, -0.05), _head, Vector3(1.05, 0.85, 1.0))
			for side2 in [-1.0, 1.0]:
				_extra(_ball(0.06), Color("4a2e1a"), Vector3(side2 * 0.15, 0.4, -0.04), _head)
		"firekeeper":
			_extra(_cyl(0.215, 0.04, 0.215), Color("6a4028"), Vector3(0, 0.24, 0), _head)
			_extra(_ball(0.035), Color("ff8a2a"), Vector3(0, 0.25, 0.21), _head).material_override = _glow(Color("ff8a2a"))
			for k2 in 3:
				_extra(_cone(0.03, 0.22), [Color("c0392b"), Color("f0c040"), Color("e8e0d0")][k2], Vector3(0.16, 0.36, -0.05 + k2 * 0.04), _head).rotation_degrees = Vector3(0, 0, -20 - k2 * 8)
		"ember_paint":
			for k3 in 3:
				_extra(BoxMesh.new(), Color("e0602a"), Vector3(0, 0.25 + k3 * 0.09, 0.24), _body, Vector3(0.3 - k3 * 0.06, 0.025, 0.02))
			_extra(BoxMesh.new(), DARK, Vector3(0, 0.15, 0.19), _head, Vector3(0.32, 0.05, 0.03))
		"bone_necklace", "war_paint":
			for k4 in 7:
				var a3 := lerpf(-1.1, 1.1, k4 / 6.0)
				_extra(_cyl(0.012, 0.07, 0.012), BONE, Vector3(sin(a3) * 0.2, 0.6 - cos(a3) * 0.07, 0.17 + cos(a3) * 0.04), _body)
	# the weapon in his right hand
	match GameState.weapon:
		"axe":
			_extra(_cyl(0.025, 0.7, 0.025), WOOD, Vector3(0, 0.2, 0.08), _hand_r).rotation_degrees = Vector3(20, 0, 0)
			_extra(BoxMesh.new(), Color("6f6a66"), Vector3(0, 0.5, 0.2), _hand_r, Vector3(0.04, 0.16, 0.22))
		"hammer":
			_extra(_cyl(0.03, 0.75, 0.03), WOOD.darkened(0.2), Vector3(0, 0.22, 0.08), _hand_r).rotation_degrees = Vector3(20, 0, 0)
			_extra(BoxMesh.new(), Color.WHITE, Vector3(0, 0.55, 0.2), _hand_r, Vector3(0.24, 0.14, 0.14)).material_override = _glow(Color("e05a2a"))
		_:
			_extra(_cyl(0.035, 0.75, 0.075), WOOD, Vector3(0, 0.25, 0.1), _hand_r).rotation_degrees = Vector3(22, 0, 0)
			_extra(_ball(0.085), WOOD.darkened(0.1), Vector3(0, 0.6, 0.24), _hand_r)


func _process(delta: float) -> void:
	_t += delta
	var run := clampf(speed, 0.0, 1.0)
	_phase += delta * (2.0 + 9.0 * run) * (1.0 if run > 0.01 else 0.0)
	var swing := sin(_phase) * 0.75 * run
	if air:
		# a tuck in the air: knees up, arms out
		_leg_l.rotation.x = -0.9
		_leg_r.rotation.x = -0.5
		_arm_l.rotation = Vector3(-0.4, 0, 0.6)
		_arm_r.rotation = Vector3(-1.0, 0, -0.4)
		_hips.position.y = 0.78
		_body.rotation.x = 0.1
	else:
		_leg_l.rotation.x = swing
		_leg_r.rotation.x = -swing
		_arm_l.rotation = Vector3(-swing * 0.8, 0, 0.12)
		_arm_r.rotation = Vector3(swing * 0.6 - 0.35 * run - 0.2, 0, -0.12)
		_hips.position.y = 0.78 - absf(sin(_phase)) * 0.05 * run + sin(_t * 2.2) * 0.008 * (1.0 - run)
		_body.rotation.x = 0.12 * run
	_body.scale = Vector3(1.0, 1.0 + sin(_t * 2.2) * 0.012 * (1.0 - run), 1.0)
	_head.rotation.y = sin(_t * 0.7) * 0.15 * (1.0 - run)


## ------------------------------------------------------------------ shapes
func _part(mesh: Mesh, col: Color, at: Vector3, parent: Node3D, scl := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.75
	m.material_override = mat
	m.position = at
	m.scale = scl
	parent.add_child(m)
	return m


func _extra(mesh: Mesh, col: Color, at: Vector3, parent: Node3D, scl := Vector3.ONE) -> MeshInstance3D:
	var m := _part(mesh, col, at, parent, scl)
	_extras.append(m)
	return m


func _glow(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 2.0
	return m


func _cyl(r: float, h: float, top: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 10
	c.rings = 1
	return c


func _cone(r: float, h: float) -> CylinderMesh:
	return _cyl(r, h, 0.0)


func _ball(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 8
	return s
