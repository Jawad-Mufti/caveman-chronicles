extends "res://shelter/system.gd"
## NATURE, for the eyes (the home, shelter/home.gd):
## - FLOWER MEADOWS: patches of five-petal flowers all over the grass, swaying
##   in the wind (the grass's own shader), one batch per colour.
## - BUTTERFLIES by day (one batch: every wing an instance), fluttering over the
##   flowers; at night the fireflies take over.
## - SHOOTING STARS at night, now and then.
## - A RAINBOW in the waterfall's mist, by day.
## - The POOL: lily pads that bob, pink lotus on them; FISH jump in the pool and
##   in the sea by the pier.
## - THE MOONPUFF GROVE, across the stream (the Bone Bridge, shelter/builds.gd,
##   is the way over): glowing moonpuffs (Level 2's bounce mushrooms) that throw
##   him up, BOING, to STAR ROCK, and on top THE WISHING STONE: a wish every
##   WISH_EVERY seconds (a shooting star comes down with a gift).

const Organic := preload("res://shelter/organic.gd")
const GROVE := Vector2(39.5, -20.5)              ## the Moonpuff grove's middle
const GROVE_R := 9.0
const STAR_ROCK := Vector2(42.6, -25.2)
const ROCK_TOP := 6.2                             ## Star Rock's top, over the ground
## The bouncing moonpuffs: [where, cap radius, cap top over the ground, bounce (m/s)]
const MOONPUFFS := [[Vector2(36.4, -17.2), 1.35, 1.15, 12.5], [Vector2(39.4, -21.0), 1.25, 3.1, 13.2]]
const PETALS := [Color("ffd84a"), Color("b07cff"), Color("ff7a8a"), Color("ffffff"), Color("6ad8ff")]
const WINGS := [Color("ff9a3a"), Color("5ab0ff"), Color("ffe14a"), Color("ffffff"), Color("ff7ac0"), Color("9be15d")]
const WISH_EVERY := 6.0 * 3600.0                  ## a wish every six hours (real time)
const RAINBOW_SHADER := "shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform float day = 1.0;
void fragment() {
	float v = UV.y;
	float hue = (1.0 - v) * 0.8;
	vec3 c = clamp(abs(mod(hue * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	float edge = smoothstep(0.0, 0.18, v) * smoothstep(1.0, 0.82, v);
	float ends = smoothstep(0.0, 0.2, UV.x) * smoothstep(1.0, 0.8, UV.x);
	ALBEDO = mix(c, vec3(1.0), 0.18);
	ALPHA = 0.42 * edge * ends * day * smoothstep(6.0, 14.0, length(VERTEX));      // (close up it fades: no wall of colour)
}
"

var _clusters: Array = []                         ## flower patches: [middle (x, z), radius]
var _flies: MultiMeshInstance3D
var _fly: Array = []                              ## [patch, phase, speed, size]
var _star: MeshInstance3D
var _star_t := -1.0
var _star_from := Vector3.ZERO
var _star_to := Vector3.ZERO
var _star_in := 5.0
var _rainbow: ShaderMaterial
var _lilies: Array = []                           ## [pivot, phase]
var _fish: Node3D
var _fish_t := -1.0
var _fish_from := Vector3.ZERO
var _fish_to := Vector3.ZERO
var _fish_in := 3.0
var _caps: Array = []                             ## the bouncing moonpuffs' caps (pivots)
var _cap_mat: StandardMaterial3D
var _spot_mat: StandardMaterial3D
var _wish_star: MeshInstance3D
var _wish_mat: StandardMaterial3D
var _grove_flies: CPUParticles3D
var _rng := RandomNumberGenerator.new()


func reserved(p: Vector2, pad: float) -> bool:
	return p.distance_to(GROVE) < GROVE_R + pad or p.distance_to(STAR_ROCK) < 3.5 + pad


func build() -> void:
	_rng.seed = 77
	_flowers()
	_butterflies()
	_sky()
	_pool()
	_grove()


func movers() -> Array:
	var out: Array = [_flies, _star, _fish]
	for l in _lilies:
		out.append(l[0])
	out.append_array(_caps)
	return out


## ------------------------------------------------------------------ flowers
func _flowers() -> void:
	var meshes: Array = []
	for c in PETALS:
		meshes.append(_flower_mesh(c))
	var lists: Array = [[], [], [], [], []]
	var tries := 0
	while _clusters.size() < 52 and tries < 900:
		tries += 1
		var p := Vector2(_rng.randf_range(-home.R, home.R), _rng.randf_range(-home.R, home.R))
		var h := ground(p.x, p.y)
		if h < 0.9 or h > 3.2 or home._clear(p, 1.0):
			continue
		var r := _rng.randf_range(1.4, 3.2)
		var main := _rng.randi() % PETALS.size()
		_clusters.append([p, r])
		for k in _rng.randi_range(26, 52):
			var a := _rng.randf() * TAU
			var q := p + Vector2(cos(a), sin(a)) * r * sqrt(_rng.randf())
			var hq := ground(q.x, q.y)
			if hq < 0.8 or home._clear(q, 0.2):
				continue
			var s := _rng.randf_range(0.8, 1.35)
			var col := main if _rng.randf() < 0.72 else _rng.randi() % PETALS.size()
			(lists[col] as Array).append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.85, 1.25), s)), Vector3(q.x, hq - 0.02, q.y)))
	for i in PETALS.size():
		var xf: Array = lists[i]
		if xf.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[i]
		mm.instance_count = xf.size()
		for k in xf.size():
			mm.set_instance_transform(k, xf[k])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = home._wind_mat
		mi.layers = home.LAYER_GRASS                     # (the fire lights skip flowers: they are many)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


## A flower: a bent stem, two leaves, five petals cupped up round a middle.
func _flower_mesh(petal: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var stem := Color("3f7f3a")
	var hy := 0.55
	var tris := [[Vector3(-0.018, 0, 0), Vector3(0.018, 0, 0), Vector3(0.03, hy, 0.015)], [Vector3(-0.018, 0, 0), Vector3(0.03, hy, 0.015), Vector3(-0.006, hy, 0.015)],
		[Vector3(0, 0.14, 0), Vector3(0.16, 0.26, 0.04), Vector3(0.03, 0.22, 0)], [Vector3(0, 0.2, 0), Vector3(-0.15, 0.33, -0.03), Vector3(-0.015, 0.27, 0)]]
	for t in tris:
		for v in t:
			st.set_color(stem.lightened(0.15 * (v as Vector3).y))
			st.add_vertex(v)
	# five round petals, a fan each, cupped up and paler at the rim
	var mid := Vector3(0.012, hy + 0.01, 0.015)
	var r := 0.17
	for k in 5:
		var a := k * TAU / 5.0
		var rim: Array = []
		for j in 7:
			var aj := a + lerpf(-0.48, 0.48, j / 6.0)
			var rj := r * (0.42 + 0.58 * sin(j / 6.0 * PI) * 0.75 + 0.25 * (1.0 - absf(j - 3.0) / 3.0))
			rim.append(mid + Vector3(cos(aj) * rj, 0.03 + rj * 0.28, sin(aj) * rj))
		for j in 6:
			for v2 in [mid, rim[j], rim[j + 1]]:
				st.set_color(petal.darkened(0.15) if v2 == mid else petal.lightened(0.12))
				st.add_vertex(v2)
	var core := Color("e0a020") if petal != PETALS[0] else Color("b0601a")
	for k in 6:
		var b0 := k * TAU / 6.0
		var b1 := b0 + TAU / 6.0
		for v3 in [mid + Vector3(0, 0.055, 0), mid + Vector3(cos(b0) * 0.045, 0.04, sin(b0) * 0.045), mid + Vector3(cos(b1) * 0.045, 0.04, sin(b1) * 0.045)]:
			st.set_color(core)
			st.add_vertex(v3)
	return st.commit()


## ------------------------------------------------------------------ butterflies
func _butterflies() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	# one wing (the right): a rounded fore wing and a smaller hind wing, flat in XZ
	var pts := [Vector3(0, 0, 0), Vector3(0.05, 0, -0.1), Vector3(0.13, 0, -0.09), Vector3(0.15, 0, -0.02), Vector3(0.1, 0, 0.02),
		Vector3(0.11, 0, 0.07), Vector3(0.05, 0, 0.09), Vector3(0.0, 0, 0.03)]
	for i in range(1, pts.size() - 1):
		for v in [pts[0], pts[i], pts[i + 1]]:
			st.set_color(Color.WHITE.darkened(0.25) if v == pts[0] else Color.WHITE)
			st.add_vertex(v)
	var wing := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = wing
	var n := mini(18, _clusters.size())
	mm.instance_count = n * 2
	for i in n:
		_fly.append([_clusters[(i * 7) % _clusters.size()], _rng.randf() * TAU, _rng.randf_range(0.6, 1.1), _rng.randf_range(0.8, 1.3)])
		var c: Color = WINGS[i % WINGS.size()]
		mm.set_instance_color(i * 2, c)
		mm.set_instance_color(i * 2 + 1, c)
	_flies = MultiMeshInstance3D.new()
	_flies.multimesh = mm
	_flies.material_override = mat
	_flies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flies)


func _flutter(t: float) -> void:
	var day := night() < 0.55
	_flies.visible = day
	if not day:
		return
	var mm := _flies.multimesh
	for i in _fly.size():
		var f: Array = _fly[i]
		var c: Vector2 = f[0][0]
		var r: float = f[0][1] + 0.6
		var ph: float = f[1]
		var sp: float = f[2]
		var s: float = f[3]
		var a := t * 0.45 * sp + ph
		var p := Vector3(c.x + sin(a) * r + sin(a * 2.3) * 0.5, 0.0, c.y + cos(a * 0.8) * r)
		p.y = ground(p.x, p.z) + 0.7 + 0.35 * sin(t * 1.7 * sp + ph) + 0.15 * sin(t * 5.0 + ph)
		var vel := Vector2(cos(a) * r + cos(a * 2.3) * 1.15, -sin(a * 0.8) * r * 0.8)
		var head := atan2(vel.x, vel.y)
		var flap := sin(t * 17.0 * sp + ph) * 1.05
		var base := Basis(Vector3.UP, head)
		mm.set_instance_transform(i * 2, Transform3D(base * Basis(Vector3.BACK, flap).scaled(Vector3.ONE * s), p))
		mm.set_instance_transform(i * 2 + 1, Transform3D(base * Basis(Vector3.BACK, -flap) * Basis.from_scale(Vector3(-s, s, s)), p))


## ------------------------------------------------------------------ the sky, the rainbow
func _sky() -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.96, 0.85)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.95, 0.8)
	m.emission_energy_multiplier = 3.0
	var bm := BoxMesh.new()
	bm.size = Vector3(1, 0.25, 0.25)
	_star = MeshInstance3D.new()
	_star.mesh = bm
	_star.material_override = m
	_star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_star.visible = false
	add_child(_star)
	# the rainbow: a band on a half circle, in the waterfall's mist
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rad := 7.0
	var w := 1.25
	var segs := 40
	for k in segs:
		var a0 := PI * k / segs
		var a1 := PI * (k + 1) / segs
		var quad := [[a0, 0.0], [a1, 0.0], [a1, 1.0], [a0, 0.0], [a1, 1.0], [a0, 1.0]]
		for q in quad:
			var aa: float = q[0]
			var vv: float = q[1]
			st.set_uv(Vector2(aa / PI, vv))
			st.add_vertex(Vector3(cos(aa), sin(aa), 0) * (rad + (vv - 0.5) * w))
	var rm := MeshInstance3D.new()
	rm.mesh = st.commit()
	_rainbow = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = RAINBOW_SHADER
	_rainbow.shader = sh
	rm.material_override = _rainbow
	rm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rm.position = Vector3(home.POOL.x, -0.6, home.POOL.z - 3.2)      # in the mist under the fall
	add_child(rm)


func _shoot(delta: float) -> void:
	if _star_t < 0.0:
		_star_in -= delta
		if _star_in <= 0.0 and night() > 0.6:
			var a := _rng.randf_range(-2.4, 0.6)
			_star_from = Vector3(cos(a) * 150.0, _rng.randf_range(70.0, 110.0), sin(a) * 150.0 - 40.0)
			_star_to = _star_from + Vector3(_rng.randf_range(-60.0, 60.0), -_rng.randf_range(25.0, 45.0), _rng.randf_range(-20.0, 20.0))
			_star_t = 0.0
			_star.visible = true
		return
	_star_t += delta / 1.1
	if _star_t >= 1.0:
		_star_t = -1.0
		_star.visible = false
		_star_in = _rng.randf_range(5.0, 14.0)
		return
	var thick := 1.4 if _star_from.y > 60.0 else 0.3          # (a wish's star comes down close: thinner)
	_aim_streak(_star, _star_from.lerp(_star_to, _star_t), _star_to - _star_from, (18.0 if thick > 1.0 else 5.0) * sin(_star_t * PI), thick)


## A streak at `at`, along `dir`, `len` long.
func _aim_streak(m: MeshInstance3D, at: Vector3, dir: Vector3, len: float, thick: float) -> void:
	var x := dir.normalized()
	var up := Vector3.UP if absf(x.y) < 0.95 else Vector3.RIGHT
	var z := x.cross(up).normalized()
	m.global_transform = Transform3D(Basis(x * maxf(len, 0.01), z.cross(x) * thick, z * thick), at)


## ------------------------------------------------------------------ the pool: lilies, fish
func _pool() -> void:
	var c := Vector2(home.POOL.x, home.POOL.z)
	for k in 8:
		var a := k * TAU / 8.0 + _rng.randf_range(-0.3, 0.3)
		var r := _rng.randf_range(1.2, 3.6)
		var p := c + Vector2(cos(a), sin(a)) * r
		var pv := pivot(Vector3(p.x, 0.17, p.y))
		var s := _rng.randf_range(0.7, 1.15)
		shape(cyl(0.42 * s, 0.03, 12), Color("3f8a3a"), Vector3.ZERO, Vector3(0, _rng.randf() * 90.0, 0), Vector3.ONE, pv)
		shape(cyl(0.3 * s, 0.035, 10), Color("57a84a"), Vector3(0.04, 0.005, 0.02), Vector3.ZERO, Vector3.ONE, pv)
		if k % 3 == 0:
			for q in 6:                                            # a lotus
				var qa := q * TAU / 6.0
				shape(cone(0.06, 0.2, 4), Color("ffb0d0") if q % 2 == 0 else Color("ff8fbf"), Vector3(cos(qa) * 0.07, 0.1, sin(qa) * 0.07), Vector3(cos(qa) * 35.0, 0, -sin(qa) * 35.0), Vector3.ONE, pv)
			shape(ball(0.05, 6), Color("ffd84a"), Vector3(0, 0.12, 0), Vector3.ZERO, Vector3.ONE, pv)
		_lilies.append([pv, _rng.randf() * TAU])
	_fish = pivot(Vector3(0, -5, 0))
	shape(ball(0.16, 8), Color("ff8a3a"), Vector3.ZERO, Vector3.ZERO, Vector3(0.6, 0.7, 1.4), _fish)
	shape(cone(0.13, 0.2, 4), Color("ffb05a"), Vector3(0, 0, -0.27), Vector3(-90, 0, 0), Vector3(1, 1, 0.3), _fish)
	_fish.visible = false


func _fishing(delta: float) -> void:
	if _fish_t < 0.0:
		_fish_in -= delta
		if _fish_in <= 0.0:
			var c := Vector2(home.POOL.x, home.POOL.z)
			var y := 0.15
			if _rng.randf() < 0.45:
				c = Vector2(home.PIER.x + _rng.randf_range(-6.0, 6.0), home.PIER.y + _rng.randf_range(3.0, 10.0))
				y = 0.0
			var a := _rng.randf() * TAU
			_fish_from = Vector3(c.x + cos(a) * 1.2, y, c.y + sin(a) * 1.2)
			_fish_to = _fish_from + Vector3(cos(a + PI) * 2.2, 0, sin(a + PI) * 2.2)
			if c.distance_to(Vector2(ugu().x, ugu().z)) < 30.0:
				_fish_t = 0.0
				_fish.visible = true
				puff(_fish_from, Color(0.8, 0.92, 1.0, 0.8), 12, 2.5)
			else:
				_fish_in = 2.0
		return
	_fish_t += delta / 0.85
	if _fish_t >= 1.0:
		_fish_t = -1.0
		_fish.visible = false
		puff(_fish_to, Color(0.8, 0.92, 1.0, 0.8), 14, 2.5)
		_fish_in = _rng.randf_range(3.0, 8.0)
		return
	var p := _fish_from.lerp(_fish_to, _fish_t) + Vector3(0, sin(_fish_t * PI) * 1.3, 0)
	var v := (_fish_to - _fish_from) + Vector3(0, cos(_fish_t * PI) * 1.3 * PI, 0)
	_fish.position = p
	_fish.look_at(p + v, Vector3.UP)
	_fish.rotate_object_local(Vector3.UP, PI)


## ------------------------------------------------------------------ the Moonpuff grove
func _grove() -> void:
	_cap_mat = StandardMaterial3D.new()
	_cap_mat.albedo_color = Color("b49cff")
	_cap_mat.emission_enabled = true
	_cap_mat.emission = Color("8a6aff")
	_cap_mat.roughness = 0.6
	_spot_mat = StandardMaterial3D.new()
	_spot_mat.albedo_color = Color("f4f0ff")
	_spot_mat.emission_enabled = true
	_spot_mat.emission = Color("d8ccff")
	_spot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for m in MOONPUFFS:
		var p: Vector2 = m[0]
		var cr: float = m[1]
		var top: float = m[2]
		var g := ground(p.x, p.y)
		shape(cyl(0.42 * cr, top - 0.2, 10, 0.32 * cr), Color("ece4ff"), Vector3(p.x, g + (top - 0.2) * 0.5, p.y))
		var cap := pivot(Vector3(p.x, g + top - 0.32, p.y))
		_moonpuff_cap(cap, cr)
		_caps.append(cap)
		home.add_pad({"c": p, "r": cr * 0.95, "top": g + top, "bounce": float(m[3])})
	# little moonpuffs all over the grove (one batch of caps)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = ball(0.5, 10)
	var xf: Array = []
	for k in 26:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(2.0, GROVE_R)
		var q := GROVE + Vector2(cos(a), sin(a)) * r
		var gq := ground(q.x, q.y)
		if gq < 0.6 or q.distance_to(STAR_ROCK) < 3.0 or _near_pad(q, 1.8):
			continue
		var s := _rng.randf_range(0.25, 0.6)
		var hgt := s * 1.4
		shape(cyl(0.07 * s * 2.0, hgt, 6), Color("ece4ff"), Vector3(q.x, gq + hgt * 0.5, q.y))
		xf.append(Transform3D(Basis.from_scale(Vector3(s, s * 0.45, s)), Vector3(q.x, gq + hgt, q.y)))
	mm.instance_count = xf.size()
	for k2 in xf.size():
		mm.set_instance_transform(k2, xf[k2])
	var small := MultiMeshInstance3D.new()
	small.multimesh = mm
	small.material_override = _cap_mat
	small.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(small)
	# the grove's own fireflies: lilac
	_grove_flies = home._particles(40, 4.0, Color("c9b8ff"), 0.04, 0.07, true)
	_grove_flies.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_grove_flies.emission_sphere_radius = GROVE_R
	_grove_flies.position = at_ground(GROVE.x, GROVE.y, 1.5)
	_grove_flies.gravity = Vector3(0, 0.05, 0)
	_grove_flies.spread = 180.0
	_grove_flies.initial_velocity_min = 0.1
	_grove_flies.initial_velocity_max = 0.3
	add_child(_grove_flies)
	_star_rock()


func _near_pad(q: Vector2, d: float) -> bool:
	for m in MOONPUFFS:
		if q.distance_to(m[0]) < float(m[1]) + d:
			return true
	return false


func _moonpuff_cap(cap: Node3D, cr: float) -> void:
	var c := MeshInstance3D.new()
	c.mesh = ball(1.0, 14)
	c.material_override = _cap_mat
	c.scale = Vector3(cr, cr * 0.42, cr)
	c.position.y = 0.1
	cap.add_child(c)
	shape(cyl(cr * 0.92, 0.06, 16), Color("6a52b0"), Vector3(0, 0.02, 0), Vector3.ZERO, Vector3.ONE, cap)   # the gills
	for k in 7:
		var a := k * TAU / 7.0 + 0.4
		var rr := cr * (0.55 if k % 2 == 0 else 0.3)
		var s := MeshInstance3D.new()
		s.mesh = ball(0.13 * cr, 6)
		s.material_override = _spot_mat
		s.position = Vector3(cos(a) * rr, 0.1 + cr * 0.42 * sqrt(maxf(0.0, 1.0 - pow(rr / cr, 2))) - 0.02, sin(a) * rr)
		s.scale = Vector3(1, 0.5, 1)
		cap.add_child(s)


## Star Rock: rocks heaped up into a high flat top; on it the Wishing Stone.
func _star_rock() -> void:
	var p := STAR_ROCK
	var g := ground(p.x, p.y)
	var rock: Color = home.ROCK
	shape(Organic.rock(7, 2), rock.darkened(0.08), Vector3(p.x, g + 1.4, p.y), Vector3(0, 20, 0), Vector3(3.4, 3.2, 3.1))
	shape(Organic.rock(3, 2), rock, Vector3(p.x + 0.3, g + 3.6, p.y - 0.2), Vector3(0, 70, 0), Vector3(2.9, 2.7, 2.7))
	shape(cyl(2.55, 1.1, 12, 2.7), rock.lightened(0.05), Vector3(p.x, g + ROCK_TOP - 0.55, p.y), Vector3(0, 12, 0))
	for k in 6:                                                     # moss and glow-moss on its sides
		var a := k * TAU / 6.0
		shape(ball(0.5, 6), Color("4f8a3a"), Vector3(p.x + cos(a) * 2.7, g + 2.2 + (k % 3) * 1.1, p.y + sin(a) * 2.6), Vector3.ZERO, Vector3(1.2, 0.4, 0.9))
	home.add_pad({"c": p, "r": 2.45, "top": g + ROCK_TOP})
	# the Wishing Stone, a gold star carved on it (bright when a wish is ready)
	var ws := Vector3(p.x - 0.6, g + ROCK_TOP, p.y - 0.5)
	shape(ball(0.55, 10), Color("9a8f86"), ws + Vector3(0, 0.35, 0), Vector3.ZERO, Vector3(1.0, 0.75, 0.8))
	_wish_mat = StandardMaterial3D.new()
	_wish_mat.albedo_color = Color("ffd84a")
	_wish_mat.emission_enabled = true
	_wish_mat.emission = Color("ffcf40")
	_wish_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wish_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wish_star = MeshInstance3D.new()
	_wish_star.mesh = _star_mesh(0.26, 0.11)
	_wish_star.material_override = _wish_mat
	_wish_star.position = ws + Vector3(0, 0.4, 0.5)
	add_child(_wish_star)
	home._spot("wish", Vector3(p.x, g + ROCK_TOP, p.y), "THE WISHING STONE", "E: make a wish")


## A flat five-point star, facing +Z.
func _star_mesh(r: float, r2: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.BACK)
	for k in 10:
		var a0 := PI * 0.5 + k * TAU / 10.0
		var a1 := a0 + TAU / 10.0
		var rr0 := r if k % 2 == 0 else r2
		var rr1 := r2 if k % 2 == 0 else r
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a0) * rr0, sin(a0) * rr0, 0))
		st.add_vertex(Vector3(cos(a1) * rr1, sin(a1) * rr1, 0))
	return st.commit()


## Is a wish ready? (seconds still to wait, 0: ready)
func wish_wait() -> float:
	return maxf(0.0, float(saved("wish", 0.0)) + WISH_EVERY - now())


func use(id: String) -> bool:
	if id != "wish":
		return false
	var w := wish_wait()
	if w > 0.0:
		var hrs := ceili(w / 3600.0)
		home.say("The stone is asleep. Come back in %s: it'll have a wish for you." % ("an hour" if hrs <= 1 else "%d hours" % hrs))
		return true
	save_key("wish", now())
	_wish()
	return true


## A star comes down out of the sky onto the stone, and leaves a gift.
func _wish() -> void:
	var at := _wish_star.global_position
	_star_from = at + Vector3(-24, 30, -18)
	_star_to = at
	_star_t = 0.0
	_star.visible = true
	await get_tree().create_timer(1.1).timeout
	puff(at, Color("ffe680"), 40, 4.0, true)
	var gift := _gift()
	home.say("A WISH!  %s" % gift)
	pop_word("A WISH!", at + Vector3(0, 1.2, 0), Color("ffe066"), 96)
	home._model.cheer(1.8)


## What a wish brings: shells mostly, sometimes orbs, a stone, a fig.
func _gift() -> String:
	var r := _rng.randf()
	if r < 0.45:
		var n := _rng.randi_range(12, 25)
		GameState.shells += n
		GameState.save()
		return "+%d SHELLS" % n
	if r < 0.7:
		var o := _rng.randi_range(4, 8)
		GameState.orbs += o
		GameState.save()
		return "+%d SPIRIT ORBS" % o
	if r < 0.85 and GameState.figs < GameState.fig_max():
		GameState.figs += 1
		GameState.save()
		return "A ROAST FIG, warm from the sky"
	var id := "quartz" if r > 0.96 else "pyrite"
	Bag.add(id)
	return "+1 %s" % Bag.name_of(id)


func bounced(pad: Dictionary) -> void:
	for cap in _caps:
		var c: Node3D = cap
		if Vector2(c.position.x, c.position.z).distance_to(pad["c"]) < 0.1:
			var tw := c.create_tween()
			tw.tween_property(c, "scale", Vector3(1.25, 0.55, 1.25), 0.07)
			tw.tween_property(c, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			puff(c.position + Vector3(0, 0.4, 0), Color("d8ccff"), 16, 3.0, true)
			pop_word("BOING!", c.position + Vector3(0, 1.6, 0), Color("c9b8ff"))


## ------------------------------------------------------------------ every frame
func _process(delta: float) -> void:
	if home == null:
		return
	var t: float = home._t
	_flutter(t)
	_shoot(delta)
	_fishing(delta)
	for l in _lilies:
		var pv: Node3D = l[0]
		pv.position.y = 0.17 + sin(t * 1.3 + float(l[1])) * 0.025
		pv.rotation.y = sin(t * 0.3 + float(l[1])) * 0.2
	var n := night()
	_rainbow.set_shader_parameter("day", 1.0 - smoothstep(0.3, 0.6, n))
	_cap_mat.emission_energy_multiplier = lerpf(0.15, 1.6, n)
	_spot_mat.emission_energy_multiplier = lerpf(0.3, 2.5, n)
	_grove_flies.emitting = n > 0.45
	var ready := wish_wait() <= 0.0
	_wish_mat.emission_energy_multiplier = (1.6 + 0.8 * sin(t * 3.0)) if ready else 0.15
	_wish_mat.albedo_color = Color("ffd84a") if ready else Color("8a7a50")
	if ready:
		_wish_star.rotation.z = sin(t * 1.5) * 0.15
