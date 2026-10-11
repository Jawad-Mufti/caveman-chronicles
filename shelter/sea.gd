extends "res://shelter/system.gd"
## THE SEA round the island (the home, shelter/home.gd): SWIMMING and DIVING.
## Walk into the sea (or jump off the pier) and he swims: a doggy paddle, head
## up, the water round his shoulders. Hold SPACE: he dives, head first, down to
## the sea floor; let go: he floats back up. A breath meter while he's under
## (he floats up for air when it runs out; it never hurts). The PIER LADDER
## gets him out (and E on the deck there: jump in!).
## Under the water (only drawn while he swims: it costs nothing otherwise):
## the sea floor (sand, rock), swaying kelp, corals (brain, branch, fan),
## starfish, schools of fish, THE SUNKEN MAMMOTH (a whole skeleton, fish swim
## through its ribs), THE GIANT CLAM (it opens and closes: a PEARL once a day),
## shells glinting on the sand to collect; blue water, light shafts from above,
## bubbles; the camera goes under with him.

const SURF_Y := -1.05                              ## his feet floating (the water round his shoulders)
const SWIM := 3.0
const SWIM_FAST := 4.6
const DIVE := 2.8
const RISE := 2.0
const AIR := 25.0                                  ## seconds of breath
const SEA_IN := 1.15                               ## this deep: he swims (less: he wades)
const PEARL_EVERY := 24.0 * 3600.0
const MAMMOTH := Vector2(-38.0, 62.0)              ## the sunken mammoth (on the sea floor, south-west of the pier)
const CLAM := Vector2(30.0, 66.0)
const UNDER_SHADER := "shader_type canvas_item;
uniform float k = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	float c = sin(uv.x * 24.0 + TIME * 1.3) * sin(uv.y * 18.0 - TIME * 1.1) + sin((uv.x + uv.y) * 31.0 + TIME * 2.0) * 0.5;
	float caustic = smoothstep(0.75, 1.3, c) * (1.0 - uv.y) * 0.55;
	float vig = smoothstep(0.35, 0.95, length(uv - vec2(0.5)) * 1.3);
	vec3 col = mix(vec3(0.05, 0.32, 0.42), vec3(0.6, 0.95, 1.0), caustic);
	COLOR = vec4(col, k * (0.2 + caustic * 0.35 + vig * 0.35));
}
"
const RAY_SHADER := "shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float k = 0.0;
void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	ALBEDO = vec3(0.55, 0.9, 1.0) * pow(across, 2.0) * (1.0 - UV.y * 0.0) * pow(UV.y, 1.5) * 0.28 * k;
}
"

var swimming := false
var under := false                                 ## the camera is under the water
var air := AIR
var dive_hold := false                             ## (tests) as if SPACE were held
var _gasp := false                                 ## out of breath: up he goes, whatever
var _dive_k := 0.0                                 ## the camera: 0 his usual, 1 under with him
var _world: Node3D                                 ## everything under the water (hidden while he's dry)
var _fish_mm: MultiMeshInstance3D
var _schools: Array = []                           ## [centre, radius, depth, speed, phase, count, first index]
var _shells: Array = []                            ## [node, where] to collect this visit
var _clam_top: Node3D
var _pearl: MeshInstance3D
var _clam_t := 0.0
var _rays: Array = []
var _ray_mat: ShaderMaterial
var _bubbles: CPUParticles3D
var _overlay: ColorRect
var _overlay_mat: ShaderMaterial
var _hud: CanvasLayer
var _env_saved := {}
var _said_swim := false
var _rng := RandomNumberGenerator.new()


func movers() -> Array:
	return [_world] if _world != null else []


func build() -> void:
	_rng.seed = 404
	_world = Node3D.new()
	_world.name = "Underwater"
	add_child(_world)
	_seabed()
	var still := Node3D.new()                       # (still things: merged into cells of their own, below)
	_world.add_child(still)
	_kelp()
	_corals(still)
	_mammoth(still)
	_clam(still)
	_fish_schools()
	_collectables()
	_ladder()
	# merge the still things (the home's own merge, in cells)
	var cells := {}
	home._bake_walk(still, {}, cells, _world.global_transform.affine_inverse())
	for key in cells:
		home._add_baked(_world, cells[key], false)
	_rays_and_bubbles()
	_screen()
	_world.visible = false


## ------------------------------------------------------------------ the sea floor
## Where the island's ground stops (all four corners deeper than -2.2), the sea
## floor goes on, out to where he may swim: sand, darker deeper, rock patches.
func _seabed() -> void:
	var span: float = home.SEA_R + 6.0
	var n := int(span * 2.0) + 1
	var tile := 22
	var mat: Material = home.Look.ground()
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for j in n:
		for i in n:
			hs[j * n + i] = home.height(-span + i, -span + j)
	for tj in range(0, n - 1, tile):
		for ti in range(0, n - 1, tile):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var any := false
			var w := mini(tile, n - 1 - ti) + 1
			var hh := mini(tile, n - 1 - tj) + 1
			for j in hh:
				for i in w:
					var k := (tj + j) * n + ti + i
					var x: float = -span + ti + i
					var z: float = -span + tj + j
					var h: float = hs[k]
					var rocky: bool = home._noise.get_noise_2d(x * 0.9, z * 0.9) > 0.25
					var c: Color = home.SAND_WET.lerp(Color("4a7a78"), clampf((-h - 2.2) / 6.0, 0.0, 0.75))      # (on from the island's wet sand: no seam)
					if rocky:
						c = home.ROCK.lerp(Color("3a5a5a"), 0.4)
					st.set_color(c)
					st.set_normal(Vector3.UP)
					st.add_vertex(Vector3(x, h, z))
			for j in hh - 1:
				for i in w - 1:
					var g := (tj + j) * n + ti + i
					if not (hs[g] < -2.2 and hs[g + 1] < -2.2 and hs[g + n] < -2.2 and hs[g + n + 1] < -2.2):
						continue
					any = true
					var a := j * w + i
					for q in [a, a + 1, a + w, a + 1, a + w + 1, a + w]:
						st.add_index(q)
			if not any:
				continue
			st.generate_normals()
			var m := MeshInstance3D.new()
			m.mesh = st.commit()
			m.material_override = mat
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_world.add_child(m)


## A spot on the sea floor at least `deep` down, in the ring he can reach.
func _floor_spot(deep: float, tries := 40) -> Vector3:
	for i in tries:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(home.R - 2.0, home.SEA_R - 4.0)
		var p := Vector2(cos(a), sin(a)) * r
		var h: float = home.height(p.x, p.y)
		if h < -deep and Vector2(p.x - home.PIER.x, p.y - home.PIER.y - 5.0).length() > 4.0:
			return Vector3(p.x, h, p.y)
	return Vector3.INF


## ------------------------------------------------------------------ kelp, corals, starfish
func _kelp() -> void:
	# a frond: a long ribbon, three bends, dark at the root, olive at the tip
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var root := Color("1f4a2a")
	var tip := Color("7a9a3a")
	var segs := 6
	for k in segs:
		var y0 := k * 0.45
		var y1 := (k + 1) * 0.45
		var w0 := 0.12 * (1.0 - k / float(segs)) + 0.03
		var w1 := 0.12 * (1.0 - (k + 1) / float(segs)) + 0.03
		var o0 := sin(k * 1.3) * 0.08
		var o1 := sin((k + 1) * 1.3) * 0.08
		var c0 := root.lerp(tip, k / float(segs))
		var c1 := root.lerp(tip, (k + 1) / float(segs))
		for v in [[Vector3(-w0 + o0, y0, 0), c0], [Vector3(w0 + o0, y0, 0), c0], [Vector3(w1 + o1, y1, 0), c1], [Vector3(-w0 + o0, y0, 0), c0], [Vector3(w1 + o1, y1, 0), c1], [Vector3(-w1 + o1, y1, 0), c1]]:
			st.set_color(v[1])
			st.set_normal(Vector3.BACK)
			st.add_vertex(v[0])
	var frond := st.commit()
	var xf: Array = []
	for c in 40:
		var at := _floor_spot(2.6)
		if at == Vector3.INF:
			continue
		for k in _rng.randi_range(6, 14):
			var p := at + Vector3(_rng.randf_range(-1.6, 1.6), 0, _rng.randf_range(-1.6, 1.6))
			p.y = home.height(p.x, p.z) - 0.05
			var depth := -p.y
			var s := _rng.randf_range(0.7, 1.0) * clampf(depth / 3.0, 0.6, 2.2)        # (tall in the deep)
			xf.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(1.0, s, 1.0)), p))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = frond
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var mat: ShaderMaterial = home._wind_mat.duplicate()
	mat.set_shader_parameter("strength", 0.25)                                   # (the swell, slow and long)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(mi)


func _corals(still: Node3D) -> void:
	var cols := [Color("ff7a8a"), Color("ff9a3a"), Color("b07cff"), Color("ffd84a"), Color("4ad0c0"), Color("ff5aa8")]
	for c in 46:
		var at := _floor_spot(2.4)
		if at == Vector3.INF:
			continue
		var col: Color = cols[c % cols.size()]
		match c % 4:
			0:  # brain coral: a lumpy dome, grooved
				shape(home.Organic.rock(c % 10, 2), col, at + Vector3(0, 0.15, 0), Vector3(0, c * 37.0, 0), Vector3(0.8, 0.55, 0.8) * _rng.randf_range(0.6, 1.3), still)
			1:  # branch coral: a little tree of horns
				var b := pivot(at, still)
				for k in 6:
					var a := k * TAU / 6.0 + _rng.randf() * 0.4
					var tilt := _rng.randf_range(15.0, 40.0)
					shape(cyl(0.06, 0.7, 6, 0.025), col, Vector3(cos(a) * 0.12, 0.33, sin(a) * 0.12), Vector3(cos(a) * tilt, 0, -sin(a) * tilt), Vector3.ONE, b)
					shape(ball(0.05, 5), col.lightened(0.25), Vector3(cos(a) * 0.32, 0.66, sin(a) * 0.32), Vector3.ZERO, Vector3.ONE, b)
			2:  # a fan: a flat lace disc on a stalk
				var f := pivot(at, still)
				f.rotation.y = _rng.randf() * TAU
				shape(cyl(0.035, 0.4, 5), col.darkened(0.25), Vector3(0, 0.2, 0), Vector3.ZERO, Vector3.ONE, f)
				shape(cyl(0.55, 0.03, 14), col, Vector3(0, 0.85, 0), Vector3(90, 0, 0), Vector3(1.0, 1.0, 0.8), f)
			3:  # tube coral and a starfish beside it
				var t := pivot(at, still)
				for k in 5:
					var a2 := k * TAU / 5.0
					shape(cyl(0.07, 0.3 + k * 0.08, 7), col, Vector3(cos(a2) * 0.13, 0.15 + k * 0.04, sin(a2) * 0.13), Vector3.ZERO, Vector3.ONE, t)
				var sf := pivot(Vector3(0.6, 0.04, 0.2), t)
				for arm in 5:
					var aa := arm * TAU / 5.0
					shape(cone(0.07, 0.3, 4), Color("ff7a3a"), Vector3(cos(aa) * 0.13, 0, sin(aa) * 0.13), Vector3(0, -rad_to_deg(aa), -90), Vector3(1, 1, 0.5), sf)


## ------------------------------------------------------------------ the sunken mammoth
## A whole skeleton lying on the sea floor: the skull, the great curled tusks,
## the spine and a cage of ribs fish swim through, the leg bones scattered.
func _mammoth(still: Node3D) -> void:
	var p := Vector3(MAMMOTH.x, home.height(MAMMOTH.x, MAMMOTH.y), MAMMOTH.y)
	var n := pivot(p, still)
	n.rotation.y = 0.6
	var bone: Color = home.BONE.darkened(0.08)
	var spine: Array = []
	for k in 9:
		spine.append(Vector3(-2.4 + k * 0.6, 1.35 + sin(k / 8.0 * PI) * 0.35, 0))
	for k in 8:
		home._bone(spine[k], spine[k + 1], 0.11, bone, n)
		shape(ball(0.16, 6), bone, spine[k], Vector3.ZERO, Vector3.ONE, n)
	# the ribs: arcs down to the sand on both sides
	for k in 6:
		var top: Vector3 = spine[2 + k]
		for s: float in [-1.0, 1.0]:
			var prev := top
			for q in 4:
				var a := (q + 1) / 4.0 * PI * 0.55
				var pt := top + Vector3(0, -sin(a) * 1.3 - 0.05, s * (0.25 + cos(a - PI * 0.5) * 0.9))
				pt.y = maxf(pt.y, 0.08)
				_bone_l(n, prev, pt, 0.055, bone)
				prev = pt
	# the skull and the tusks
	var sk := Vector3(3.2, 1.25, 0)
	shape(home.Organic.rock(4, 2), bone, sk, Vector3(0, 0, -20), Vector3(1.0, 1.0, 0.85), n)
	for s2: float in [-1.0, 1.0]:
		var prev2 := sk + Vector3(0.6, -0.4, s2 * 0.35)
		for q2 in 10:
			var a2 := (q2 + 1) / 10.0
			var pt2 := sk + Vector3(0.6 + sin(a2 * 2.4) * 1.6, -0.4 - sin(a2 * 1.4) * 0.6 + a2 * a2 * 1.4, s2 * (0.35 + a2 * 0.9))
			var r := lerpf(0.13, 0.04, a2)
			var seg := shape(cyl(r, prev2.distance_to(pt2), 7), Color("e8dcc0"), (prev2 + pt2) * 0.5, Vector3.ZERO, Vector3.ONE, n)
			var y := (pt2 - prev2).normalized()
			var x := (Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).cross(y).normalized()
			seg.basis = Basis(x, y, x.cross(y))
			prev2 = pt2
	# leg bones scattered about
	for k2 in 4:
		var lp := Vector3(-1.6 + k2 * 1.2, 0.1, (1.0 if k2 % 2 == 0 else -1.0) * _rng.randf_range(1.3, 2.0))
		_bone_l(n, lp, lp + Vector3(_rng.randf_range(-0.6, 0.6), 0.05, _rng.randf_range(-1.2, 1.2)), 0.1, bone)
	home._spot("mammoth", Vector3(p.x, p.y + 1.5, p.z), "THE SUNKEN MAMMOTH", "A whole mammoth, asleep on the sea floor forever. Fish live in its ribs now.")


func _bone_l(n: Node3D, a: Vector3, b: Vector3, r: float, col: Color) -> void:
	home._bone(a, b, r, col, n)


## ------------------------------------------------------------------ the giant clam
func _clam(still: Node3D) -> void:
	var p := Vector3(CLAM.x, home.height(CLAM.x, CLAM.y), CLAM.y)
	var shell := Color("b0a0c0")
	shape(ball(1.0, 12), shell, p + Vector3(0, 0.25, 0), Vector3.ZERO, Vector3(1.4, 0.45, 1.1), still)          # the bottom half
	for k in 7:                                                                                                  # its ridges
		var a := (k - 3) * 0.32
		shape(cyl(0.08, 2.2, 5), shell.darkened(0.12), p + Vector3(sin(a) * 0.9, 0.12, cos(a) * 0.2), Vector3(90, rad_to_deg(a), 0), Vector3(1, 1, 0.5), still)
	_clam_top = pivot(p + Vector3(0, 0.4, -0.9), _world)
	shape(ball(1.0, 12), shell.lightened(0.08), Vector3(0, 0.15, 0.9), Vector3.ZERO, Vector3(1.4, 0.42, 1.1), _clam_top)
	_pearl = glowing(ball(0.2, 10), Color("fff6ea"), 1.4, p + Vector3(0, 0.55, 0), Vector3.ZERO, Vector3.ONE, _world)
	home._spot("clam", Vector3(p.x, p.y + 1.0, p.z), "THE GIANT CLAM", "Swim close when it opens...")


## ------------------------------------------------------------------ fish schools
func _fish_schools() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# a little fish: a diamond body and a tail, flat, along +Z
	var body := [Vector3(0, 0, 0.16), Vector3(0, 0.07, 0), Vector3(0, -0.06, 0), Vector3(0, 0, -0.12)]
	for tri in [[0, 1, 3], [0, 3, 2], [3, Vector3(0, 0.07, -0.22), Vector3(0, -0.07, -0.22)]]:
		for v in tri:
			var q: Vector3 = body[v] if v is int else v
			st.set_color(Color.WHITE.darkened(0.25) if q.y < 0.0 else Color.WHITE)
			st.set_normal(Vector3.RIGHT)
			st.add_vertex(q)
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var cols := [Color("ffcf40"), Color("5ab0ff"), Color("ff7a5a"), Color("c0e0f0"), Color("9be15d"), Color("ff9ad0"), Color("ffffff")]
	var total := 0
	for k in 9:
		var at := _floor_spot(3.0)
		if at == Vector3.INF:
			continue
		var count := _rng.randi_range(9, 18)
		_schools.append([at, _rng.randf_range(2.0, 4.5), _rng.randf_range(1.2, minf(-at.y - 1.0, 4.0)), _rng.randf_range(0.35, 0.7) * (1.0 if k % 2 == 0 else -1.0), _rng.randf() * TAU, count, total, cols[k % cols.size()]])
		total += count
	# a school round the mammoth's ribs
	var mp := Vector3(MAMMOTH.x, home.height(MAMMOTH.x, MAMMOTH.y), MAMMOTH.y)
	_schools.append([mp, 2.2, 1.0, 0.5, 0.0, 14, total, Color("ffe066")])
	total += 14
	mm.instance_count = total
	for s in _schools:
		for i in int(s[5]):
			mm.set_instance_color(int(s[6]) + i, (s[7] as Color).lerp(Color.WHITE, (i % 3) * 0.12))
	_fish_mm = MultiMeshInstance3D.new()
	_fish_mm.multimesh = mm
	_fish_mm.material_override = mat
	_fish_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(_fish_mm)


func _swim_fish(t: float) -> void:
	var mm := _fish_mm.multimesh
	for s in _schools:
		var c: Vector3 = s[0]
		var r: float = s[1]
		var up: float = s[2]
		var sp: float = s[3]
		var ph: float = s[4]
		for i in int(s[5]):
			var a := t * sp + ph + i * 0.21
			var lane := 1.0 + sin(i * 2.3) * 0.25
			var p := c + Vector3(cos(a) * r * lane, up + sin(i * 1.7) * 0.4 + sin(t * 1.3 + i) * 0.15, sin(a) * r * lane)
			var dir := Vector3(-sin(a), 0, cos(a)) * signf(sp)
			var b := Basis.looking_at(-dir, Vector3.UP)
			b = b.rotated(Vector3.UP, sin(t * 9.0 + i) * 0.15)                   # (a wiggle)
			mm.set_instance_transform(int(s[6]) + i, Transform3D(b, p))


## ------------------------------------------------------------------ shells to collect, the ladder
func _collectables() -> void:
	_rng.randomize()                                  # (new shells every visit)
	for k in 9:
		var at := _floor_spot(2.0)
		if at == Vector3.INF:
			continue
		var n := pivot(at + Vector3(0, 0.08, 0), _world)
		shape(cone(0.16, 0.12, 8), Color("fff0d8"), Vector3.ZERO, Vector3(0, k * 40.0, 0), Vector3(1, 1, 0.7), n)
		glowing(ball(0.05, 6), Color("fff8e0"), 2.0, Vector3(0, 0.12, 0), Vector3.ZERO, Vector3.ONE, n)
		_shells.append([n, at])
	_rng.seed = 405


func _ladder() -> void:
	var pier: Vector2 = home.PIER
	var x := pier.x + 0.95
	var z := pier.y + 7.5
	for s: float in [-0.3, 0.3]:
		home._bone(Vector3(x, -1.6, z + s), Vector3(x, 1.0, z + s), 0.035)
	for k in 6:
		var y := -1.3 + k * 0.42
		home._bone(Vector3(x, y, z - 0.33), Vector3(x, y, z + 0.33), 0.025)
	home._spot("ladder", Vector3(x + 0.4, 0.66, z), "THE PIER LADDER", "E: climb out (or, on the deck: jump in!)")


func use(id: String) -> bool:
	if id != "ladder":
		return false
	var pier: Vector2 = home.PIER
	if swimming:
		_stop_swimming()
		home._pos = Vector3(pier.x + 0.45, 0.66, pier.y + 7.5)
		home._vy = 0.0
		home._on_ground = true
		home._model.rotation.y = -PI * 0.5
		puff(Vector3(pier.x + 1.0, 0.0, pier.y + 7.5), Color(0.85, 0.95, 1.0, 0.9), 18, 2.5)
		home.say("Up the ladder, dripping wet!")
	else:
		# jump in: off the edge, up and out over the water
		home._pos.x = pier.x + 1.4
		home._vy = 7.0
		home._hv = Vector2(3.0, 0.0)
		home._on_ground = false
		home._jumps = 1
		home._model.rotation.y = PI * 0.5
		home._model.jumped(true)
		pop_word("CANNONBALL!", home._pos + Vector3(1.5, 2.5, 0), Color("bfe3ff"))
	return true


## ------------------------------------------------------------------ light shafts, bubbles, the blue
func _rays_and_bubbles() -> void:
	_ray_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = RAY_SHADER
	_ray_mat.shader = sh
	var qm := QuadMesh.new()
	qm.size = Vector2(1.6, 9.0)
	for k in 7:
		var r := MeshInstance3D.new()
		r.mesh = qm
		r.material_override = _ray_mat
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(r)
		_rays.append([r, Vector2(_rng.randf_range(-7, 7), _rng.randf_range(-7, 7)), _rng.randf() * TAU])
	_bubbles = home._particles(16, 2.2, Color(0.85, 0.95, 1.0, 0.8), 0.03, 0.07, true)
	_bubbles.direction = Vector3.UP
	_bubbles.spread = 15.0
	_bubbles.gravity = Vector3(0, 1.6, 0)
	_bubbles.initial_velocity_min = 0.3
	_bubbles.initial_velocity_max = 0.8
	_bubbles.emitting = false
	_world.add_child(_bubbles)


func _screen() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 0
	home.add_child(cl)
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = UNDER_SHADER
	_overlay_mat.shader = sh
	_overlay.material = _overlay_mat
	_overlay.visible = false
	cl.add_child(_overlay)
	_hud = CanvasLayer.new()
	_hud.layer = 3
	var h := SeaHud.new()
	h.sea = self
	_hud.add_child(h)
	home.add_child(_hud)


## ------------------------------------------------------------------ swimming (home.walk asks first)
## True while he is in the sea (it moved him, posed him, set the camera).
func swim_step(dir: Vector3, delta: float) -> bool:
	var me := Vector2(home._pos.x, home._pos.z)
	var g: float = home.height(me.x, me.y)
	var depth := -g
	if not swimming:
		if depth > SEA_IN and home._pos.y <= SURF_Y + 0.35 and not home._on_pier(me) and home.pad_top(me) == -INF:
			_start_swimming()
		else:
			return false
	elif depth < SEA_IN - 0.25:
		_stop_swimming()                               # (his feet touch: he wades out)
		home._pos.y = maxf(home._pos.y, g)
		return false
	# across the water
	var moving := dir.length() > 0.01
	if moving:
		dir = dir.normalized()
	var fast := moving and Input.is_physical_key_pressed(KEY_SHIFT)
	var want := Vector2(dir.x, dir.z) * (SWIM_FAST if fast else SWIM)
	home._hv = home._hv.move_toward(want, 8.0 * delta)
	var step: Vector2 = home._hv * delta
	if (me + step).length() < home.SEA_R:
		home._pos.x += step.x
		home._pos.z += step.y
	if home._hv.length() > 0.3:
		home._model.rotation.y = lerp_angle(home._model.rotation.y, atan2(home._hv.x, home._hv.y), minf(1.0, delta * 6.0))
	# down and up
	var floor_y := g + 0.25
	var diving := (dive_hold or Input.is_physical_key_pressed(KEY_SPACE)) and not _gasp
	var target := -DIVE if diving else (RISE * 1.7 if _gasp else RISE)        # (gasping: up, quick)
	home._vy = move_toward(home._vy, target, 7.0 * delta)
	home._pos.y += home._vy * delta
	if home._pos.y < floor_y:
		home._pos.y = floor_y
		home._vy = maxf(home._vy, 0.0)
	if home._pos.y >= SURF_Y and not diving:
		home._pos.y = SURF_Y + sin(home._t * 2.2) * 0.05      # bobbing at the top
		home._vy = 0.0
		if air > AIR * 0.5:
			_gasp = false                          # (a few good breaths first)
	var head_under: bool = home._pos.y + 1.15 < -0.3          # (floating at the top his head is out)
	# breath
	if head_under:
		air = maxf(0.0, air - delta)
		if air <= 0.0 and not _gasp:
			_gasp = true
			home.say("Out of breath! Up for air!")
	else:
		air = minf(AIR, air + delta * 9.0)
	# his pose
	var m: Node3D = home._model
	var sp: float = home._hv.length()
	m.speed = clampf(sp / SWIM, 0.0, 1.0)
	m.sprint = 0.0
	m.air = false
	var under_k := clampf((SURF_Y - home._pos.y) / 0.8, 0.0, 1.0)
	m.swim = 1.0
	m.dive = lerpf(float(m.dive), under_k, minf(1.0, delta * 5.0))
	m.dive_dir = lerpf(float(m.dive_dir), clampf(-home._vy / DIVE, -1.0, 1.0), minf(1.0, delta * 4.0))
	m.look_at_point = Vector3.INF
	home._on_ground = false
	home._jumps = 0
	home._jump_buf = 0.0
	if moving and not head_under and fmod(home._t, 0.4) < delta:
		puff(home._pos + Vector3(0, 1.25, 0), Color(0.85, 0.95, 1.0, 0.7), 5, 1.2)
	_bubbles.emitting = head_under
	_bubbles.global_position = home._pos + Vector3(0, 1.1, 0) + m.global_transform.basis.z * 0.5
	home._model.position = home._pos
	home._camera(delta)
	return true


func _start_swimming() -> void:
	swimming = true
	home._model.show_weapon(false)
	air = AIR
	_world.visible = true
	home._vy = minf(home._vy, 0.0) * 0.3
	puff(home._pos + Vector3(0, 1.0, 0), Color(0.85, 0.95, 1.0, 0.95), 30, 4.0)
	pop_word("SPLASH!", home._pos + Vector3(0, 2.6, 0), Color("bfe3ff"), 80)
	if not _said_swim:
		_said_swim = true
		home.say("SWIMMING! Hold SPACE to DIVE and see what's down there. (The ladder on the pier gets you out.)")


func _stop_swimming() -> void:
	swimming = false
	home._model.show_weapon(true)
	_gasp = false
	air = AIR
	home._model.swim = 0.0
	home._model.dive = 0.0
	home._model.dive_dir = 0.0
	_bubbles.emitting = false


## ------------------------------------------------------------------ the camera goes under with him
func camera(cam_want: Vector3, aim: Vector3, delta: float) -> Array:
	var down: bool = swimming and home._pos.y < SURF_Y - 0.4
	_dive_k = move_toward(_dive_k, 1.0 if down else 0.0, delta * 1.8)
	if _dive_k <= 0.0:
		return [cam_want, aim]
	var k := _dive_k * _dive_k * (3.0 - 2.0 * _dive_k)
	var behind: Vector3 = -home._model.global_transform.basis.z
	var c: Vector3 = home._pos + Vector3(0, 1.5, 0) + Vector3(behind.x, 0, behind.z).normalized() * 4.2
	c.y = minf(c.y, -0.5)
	c.y = maxf(c.y, home.height(c.x, c.z) + 0.6)
	return [cam_want.lerp(c, k), aim.lerp(home._pos + Vector3(0, 0.8, 0), k)]


## ------------------------------------------------------------------ every frame
func _process(delta: float) -> void:
	if home == null or _world == null:
		return
	var cam: Camera3D = home._cam
	var cp := cam.global_position
	var now_under: bool = cp.y < -0.05 and home.height(cp.x, cp.z) < -0.05
	if now_under != under:
		under = now_under
		_underwater(under)
	_world.visible = swimming or under
	if not _world.visible:
		return
	var t: float = home._t
	_swim_fish(t)
	# the shafts of light, round him
	for r in _rays:
		var mi: MeshInstance3D = r[0]
		var off: Vector2 = r[1]
		var p := Vector3(home._pos.x + off.x, -4.5, home._pos.z + off.y)
		mi.global_position = p
		mi.rotation = Vector3(0.25 * sin(t * 0.3 + float(r[2])), atan2(cp.x - p.x, cp.z - p.z), 0.2)
	_ray_mat.set_shader_parameter("k", (1.0 if under else 0.0) * (1.0 - home._night * 0.8))
	if under:
		_overlay_mat.set_shader_parameter("k", 1.0)
		var env: Environment = home._env
		env.fog_light_color = Color(0.08, 0.32, 0.4).lerp(Color(0.02, 0.06, 0.12), home._night)
	# the clam: opens and shuts, slowly
	_clam_t += delta
	var open := clampf(sin(_clam_t * 0.5) * 1.6, 0.0, 1.0)
	_clam_top.rotation.x = -open * 0.7
	var pearl_ready := now() - float(saved("pearl", 0.0)) >= PEARL_EVERY
	_pearl.visible = pearl_ready
	var me: Vector3 = home._pos
	if swimming:
		if pearl_ready and open > 0.5 and me.distance_to(_pearl.global_position) < 2.2:
			save_key("pearl", now())
			GameState.shells += 25
			GameState.save()
			pop_word("A PEARL!", _pearl.global_position + Vector3(0, 1.2, 0), Color("fff6ea"), 96)
			puff(_pearl.global_position, Color("fff6ea"), 30, 3.0, true)
			home.say("A PEARL, as big as a fig! Kekko pays 25 shells for it. (The clam makes one a day.)")
			home._model.cheer(1.5)
		for s in _shells.duplicate():
			var at: Vector3 = s[1]
			if me.distance_to(at) < 1.6:
				_shells.erase(s)
				(s[0] as Node).queue_free()
				GameState.shells += 2
				GameState.save()
				pop_word("+2 SHELLS", at + Vector3(0, 1.0, 0), Color("ffe066"), 60)
				puff(at, Color("fff8e0"), 12, 2.0, true)


## Under the water: the blue fog, the tint on the screen; and back.
func _underwater(on: bool) -> void:
	var env: Environment = home._env
	_overlay.visible = on
	if on:
		_env_saved = {"density": env.fog_density, "colour": env.fog_light_color, "sky": env.fog_sky_affect}
		env.fog_density = 0.075
		env.fog_sky_affect = 1.0
	elif not _env_saved.is_empty():
		env.fog_density = _env_saved["density"]
		env.fog_light_color = _env_saved["colour"]
		env.fog_sky_affect = _env_saved["sky"]
		home._apply_daylight(true)


## ------------------------------------------------------------------ the screen: breath, how to dive
class SeaHud extends Control:
	var sea: Node
	var t := 0.0

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		visible = sea.swimming
		if visible:
			queue_redraw()

	func _draw() -> void:
		var vs := get_viewport_rect().size
		var tx := Pal.text_font()
		var air: float = sea.air / sea.AIR
		var under: bool = sea.home._pos.y + 1.15 < -0.3
		if under or air < 0.999:
			# breath: a row of bubbles, popping as it runs out
			var n := 10
			for i in n:
				var full := air * n - i
				var c := Vector2(vs.x * 0.5 - (n - 1) * 15.0 + i * 30.0, vs.y - 120.0)
				if full > 0.0:
					var r := 10.0 * clampf(full, 0.3, 1.0)
					draw_circle(c, r + 2.0, Color(0.1, 0.25, 0.35, 0.8))
					draw_circle(c, r, Color(0.75, 0.93, 1.0, 0.95) if air > 0.25 or fmod(t, 0.4) < 0.2 else Color(1.0, 0.6, 0.5))
					draw_circle(c + Vector2(-r * 0.35, -r * 0.35), r * 0.25, Color.WHITE)
		var line := "Hold SPACE: dive deeper      let go: float up      Shift: swim fast" if under else "SPACE: dive!      swim to the shore, or the pier LADDER, to get out"
		draw_string_outline(tx, Vector2(vs.x * 0.5 - 450, vs.y - 78), line, HORIZONTAL_ALIGNMENT_CENTER, 900, 17, 6, Color(0.05, 0.1, 0.15, 0.9))
		draw_string(tx, Vector2(vs.x * 0.5 - 450, vs.y - 78), line, HORIZONTAL_ALIGNMENT_CENTER, 900, 17, Color("dff4ff"))
