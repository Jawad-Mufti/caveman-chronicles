extends RefCounted
## ORGANIC SHAPES for the home (shelter/home.gd and its systems), made in code:
## no perfect spheres, cones and cylinders. Each is an ArrayMesh with normals
## and a vertex colour that is SHADING, not paint (1.0 = the shape's own colour;
## darker in cracks and under, lighter on tops): the home's merge multiplies its
## colour by it (home._bake_walk). Every shape is made once per variant and kept.
## - rock(v): a lumpy boulder, chiselled into facets, cracks darker, top lighter.
## - bone(v): a long bone: a waisted shaft, knobbed ends, a little bent.
## - trunk(v): a tree trunk that leans and wanders, roots flaring at its foot.
## - crown(v): a broadleaf crown: lumps grown into one cloud, darker underneath.
## - boughs(v): a pine's layer: a ragged star of drooping bough tips.
## - frond(v): a palm leaf: an arched midrib, notched blade, drooping tip.
## (unit sizes: scale them where they are used)

static var _cache := {}


static func _noise(seed: int, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = freq
	n.fractal_octaves = 3
	return n


## An icosphere: [vertices, triangles (index triples)].
static func _ico(subdiv: int) -> Array:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var vs: Array = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
		Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	for i in vs.size():
		vs[i] = (vs[i] as Vector3).normalized()
	var fs: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for s in subdiv:
		var mid := {}
		var nf: Array = []
		for f in fs:
			var m: Array = []
			for e in 3:
				var a: int = f[e]
				var b: int = f[(e + 1) % 3]
				var key := Vector2i(mini(a, b), maxi(a, b))
				if not mid.has(key):
					vs.append(((vs[a] as Vector3) + (vs[b] as Vector3)).normalized())
					mid[key] = vs.size() - 1
				m.append(mid[key])
			nf.append([f[0], m[0], m[2]])
			nf.append([f[1], m[1], m[0]])
			nf.append([f[2], m[2], m[1]])
			nf.append([m[0], m[1], m[2]])
		fs = nf
	return [vs, fs]


## Triangles into a mesh, each facing out from `centre` (flat: a facet each).
static func _commit_flat(tris: Array, centre: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		var n := (b - a).cross(c - a).normalized()
		if n.dot((a + b + c) / 3.0 - centre) < 0.0:
			n = -n
			var tmp := b
			b = c
			c = tmp
			var tc: Color = t[4]
			t[4] = t[5]
			t[5] = tc
		# (Godot's front faces wind clockwise seen from outside)
		for v in [[a, t[3]], [c, t[5]], [b, t[4]]]:
			st.set_normal(n)
			st.set_color(v[1])
			st.add_vertex(v[0])
	return st.commit()


static func _shade(k: float) -> Color:
	return Color(k, k, k)


## ------------------------------------------------------------------ rock
## A boulder about 1 across (radius 1): lumpy, squat, a flat-ish foot; cut into
## facets; dark in its hollows, light on top.
static func rock(v: int, detail := 2) -> ArrayMesh:
	var key := "rock%d_%d" % [v, detail]
	if _cache.has(key):
		return _cache[key]
	var ico := _ico(detail)
	var vs: Array = ico[0]
	var nz := _noise(1000 + v * 17, 0.9)
	var nz2 := _noise(2000 + v * 31, 2.6)
	var pos: Array = []
	var shade: Array = []
	for p0 in vs:
		var p: Vector3 = p0
		var d := nz.get_noise_3dv(p * 1.3) * 0.38 + nz2.get_noise_3dv(p) * 0.12
		var q := p * (1.0 + d)
		q.y *= 0.72
		if q.y < -0.35:
			q.y = lerpf(q.y, -0.35, 0.7)                   # (it sits on the ground)
		pos.append(q)
		shade.append(clampf(0.86 + d * 0.9 + p.y * 0.12, 0.62, 1.12))
	var tris: Array = []
	for f in ico[1]:
		tris.append([pos[f[0]], pos[f[1]], pos[f[2]], _shade(shade[f[0]]), _shade(shade[f[1]]), _shade(shade[f[2]])])
	var m := _commit_flat(tris, Vector3.ZERO)
	_cache[key] = m
	return m


## ------------------------------------------------------------------ bone
## A long bone along +Y, 1 long, about 0.08 thick at the waist: knobbed ends
## (two bumps each), a little bend, lighter on top.
static func bone(v: int) -> ArrayMesh:
	var key := "bone%d" % v
	if _cache.has(key):
		return _cache[key]
	var rings := 14
	var sides := 8
	var vs: Array = []
	var ns: Array = []
	var cs: Array = []
	var fs: Array = []
	var bend := 0.04 + 0.03 * (v % 3)
	for i in rings + 1:
		var q := float(i) / rings
		var y := q - 0.5
		var waist := 0.06 + 0.035 * pow(absf(y) * 2.0, 4.0)
		var c := Vector3(sin(q * PI) * bend, y, 0)
		for j in sides:
			var a := TAU * j / sides
			var knob := 0.0
			if absf(y) > 0.38:                             # the two knuckles at each end
				knob = 0.025 * maxf(0.0, cos(a * 2.0 + (0.6 if y > 0.0 else 0.0))) * smoothstep(0.38, 0.48, absf(y))
			var r := waist + knob
			var dir := Vector3(cos(a), 0, sin(a))
			vs.append(c + dir * r * (1.0 - 0.6 * smoothstep(0.47, 0.5, absf(y))))
			ns.append(dir)
			cs.append(_shade(0.9 + 0.12 * dir.z * -1.0 + 0.06 * dir.x))
	for i in rings:
		for j in sides:
			var a := i * sides + j
			var b := i * sides + (j + 1) % sides
			var c2 := (i + 1) * sides + (j + 1) % sides
			var d := (i + 1) * sides + j
			fs.append([a, b, c2])
			fs.append([a, c2, d])
	# the ends capped
	for end in [0, rings]:
		vs.append(Vector3(0, end / float(rings) - 0.5, 0) + Vector3(sin(float(end) / rings * PI) * bend, 0, 0))
		ns.append(Vector3(0, -1 if end == 0 else 1, 0))
		cs.append(_shade(0.95))
		var ci := vs.size() - 1
		for j in sides:
			fs.append([ci, end * sides + j, end * sides + (j + 1) % sides])
	var m := _commit_bone(vs, ns, cs, fs)
	_cache[key] = m
	return m


## (a tube: each triangle faces away from the axis at its height)
static func _commit_bone(vs: Array, ns: Array, cs: Array, fs: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in vs.size():
		st.set_normal(ns[i])
		st.set_color(cs[i])
		st.add_vertex(vs[i])
	for f in fs:
		var a: Vector3 = vs[f[0]]
		var b: Vector3 = vs[f[1]]
		var c: Vector3 = vs[f[2]]
		var mid := (a + b + c) / 3.0
		var out := (ns[f[0]] as Vector3) + (ns[f[1]] as Vector3) + (ns[f[2]] as Vector3)
		var n := (b - a).cross(c - a)
		if n.dot(out) > 0.0:
			st.add_index(f[0])
			st.add_index(f[2])
			st.add_index(f[1])
		else:
			st.add_index(f[0])
			st.add_index(f[1])
			st.add_index(f[2])
	return st.commit()


## ------------------------------------------------------------------ trunk
## A trunk 1 tall, about 0.12 thick: it wanders as it rises, bark ridges, three
## or four roots flaring at its foot; darker low down.
static func trunk(v: int) -> ArrayMesh:
	var key := "trunk%d" % v
	if _cache.has(key):
		return _cache[key]
	var nz := _noise(3000 + v * 13, 1.6)
	var rings := 10
	var sides := 9
	var vs: Array = []
	var ns: Array = []
	var cs: Array = []
	var fs: Array = []
	var roots := 3 + v % 2
	for i in rings + 1:
		var q := float(i) / rings
		var c := Vector3(nz.get_noise_1d(q * 3.0) * 0.12 * q, q, nz.get_noise_1d(q * 3.0 + 40.0) * 0.12 * q)
		for j in sides:
			var a := TAU * j / sides
			var dir := Vector3(cos(a), 0, sin(a))
			var r := lerpf(0.13, 0.08, q) * (1.0 + 0.12 * sin(a * 5.0 + q * 3.0))           # bark ridges
			var flare := 0.0
			for k in roots:
				var ra := TAU * k / roots + v
				flare += pow(maxf(0.0, cos(a - ra)), 6.0) * 0.16 * pow(1.0 - minf(q / 0.22, 1.0), 2.0)
			vs.append(c + dir * (r + flare))
			ns.append(dir)
			cs.append(_shade(0.72 + 0.3 * q + 0.08 * sin(a * 5.0 + q * 3.0)))
	for i in rings:
		for j in sides:
			var a2 := i * sides + j
			var b := i * sides + (j + 1) % sides
			var c2 := (i + 1) * sides + (j + 1) % sides
			var d := (i + 1) * sides + j
			fs.append([a2, b, c2])
			fs.append([a2, c2, d])
	var m := _commit_bone(vs, ns, cs, fs)
	_cache[key] = m
	return m


## ------------------------------------------------------------------ crown
## A broadleaf crown about 2 across: five or six lumps grown into one cloud;
## smooth, darker underneath and inside, lighter on top.
static func crown(v: int) -> ArrayMesh:
	var key := "crown%d" % v
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4000 + v
	var nz := _noise(5000 + v, 1.4)
	var ico := _ico(2)
	var all_v: Array = []
	var all_n: Array = []
	var all_c: Array = []
	var all_f: Array = []
	var lumps := 5 + v % 2
	for k in lumps:
		var c := Vector3(rng.randf_range(-0.55, 0.55), rng.randf_range(-0.15, 0.45), rng.randf_range(-0.55, 0.55)) if k > 0 else Vector3(0, 0.1, 0)
		var r := rng.randf_range(0.55, 0.8) if k > 0 else 0.85
		var base := all_v.size()
		for p0 in ico[0]:
			var p: Vector3 = p0
			var d := nz.get_noise_3dv(p * 1.5 + c * 2.0) * 0.22
			var q := c + p * r * (1.0 + d)
			q.y = c.y + (q.y - c.y) * 0.85
			all_v.append(q)
			all_n.append(p)
			var up := clampf(q.y * 0.5 + 0.5, 0.0, 1.0)
			all_c.append(_shade(clampf(0.7 + up * 0.38 + d * 0.8, 0.6, 1.15)))
		for f in ico[1]:
			all_f.append([base + f[0], base + f[1], base + f[2]])
	var m := _commit_lumps(all_v, all_n, all_c, all_f)
	_cache[key] = m
	return m


## (lumps: each triangle faces along its vertices' normals)
static func _commit_lumps(vs: Array, ns: Array, cs: Array, fs: Array) -> ArrayMesh:
	return _commit_bone(vs, ns, cs, fs)


## ------------------------------------------------------------------ boughs
## One layer of a pine, about 1 across, 0.8 tall: a ragged star of bough tips
## drooping out and down from its peak; darker under, light at the tips.
static func boughs(v: int) -> ArrayMesh:
	var key := "boughs%d" % v
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 6000 + v
	var tips := 11
	var tris: Array = []
	var peak := Vector3(0, 0.8, 0)
	var rim: Array = []
	for k in tips * 2:
		var a := TAU * k / (tips * 2) + rng.randf_range(-0.08, 0.08)
		var out := k % 2 == 0
		var r := (1.0 + rng.randf_range(-0.12, 0.1)) if out else 0.62
		var y := (-0.05 + rng.randf_range(-0.06, 0.04)) if out else 0.1
		rim.append([Vector3(cos(a) * r, y, sin(a) * r), out])
	var under := Vector3(0, 0.12, 0)
	for k in rim.size():
		var a2: Vector3 = rim[k][0]
		var b2: Vector3 = rim[(k + 1) % rim.size()][0]
		var sa := 1.08 if rim[k][1] else 0.78
		var sb := 1.08 if rim[(k + 1) % rim.size()][1] else 0.78
		tris.append([peak, a2, b2, _shade(0.95), _shade(sa), _shade(sb)])            # the top
		tris.append([under, b2, a2, _shade(0.55), _shade(sb * 0.6), _shade(sa * 0.6)])  # underneath, darker
	var m := _commit_flat(tris, Vector3(0, 0.3, 0))
	_cache[key] = m
	return m


## ------------------------------------------------------------------ frond
## A palm leaf along +X, 2 long: an arched midrib, a blade notched into
## fingers, drooping toward its tip; lighter along the rib.
static func frond(v: int) -> ArrayMesh:
	var key := "frond%d" % v
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 12
	for k in segs:
		var q0 := float(k) / segs
		var q1 := float(k + 1) / segs
		for s: float in [-1.0, 1.0]:
			var p0 := _rib(q0)
			var p1 := _rib(q1)
			var w0 := sin(q0 * PI) * 0.32 * (0.55 if k % 2 == 1 else 1.0)            # (notched: fingers)
			var w1 := sin(q1 * PI) * 0.32 * (0.55 if (k + 1) % 2 == 1 else 1.0)
			var e0 := p0 + Vector3(0.06, -w0 * 0.4, s * w0)
			var e1 := p1 + Vector3(0.06, -w1 * 0.4, s * w1)
			# both sides (seen from under, too), each wound its own way
			for vtx in [[p0, 1.08, 1.0], [e0, 0.85, 1.0], [p1, 1.08, 1.0], [p1, 1.08, 1.0], [e0, 0.85, 1.0], [e1, 0.85, 1.0],
					[p0, 0.8, -1.0], [p1, 0.8, -1.0], [e0, 0.62, -1.0], [p1, 0.8, -1.0], [e1, 0.62, -1.0], [e0, 0.62, -1.0]]:
				st.set_normal(Vector3.UP * float(vtx[2]))
				st.set_color(_shade(vtx[1]))
				st.add_vertex(vtx[0])
	var m := st.commit()
	_cache[key] = m
	return m


static func _rib(q: float) -> Vector3:
	return Vector3(q * 2.0, sin(q * PI * 0.8) * 0.45 - q * q * 0.9, 0)
