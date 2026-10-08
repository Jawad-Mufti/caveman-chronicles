class_name Terrain
extends Node2D
## Terraria-style ground from a text map: hills, overhangs, tunnels, caves —
## and every bit of it can be DUG (the edges of the map are bedrock).
## Each character is one sample, CELL px apart (the first one at `position`):
##   '#' rock    '=' strata (deep, layered)    'o' grey stone    'd' dirt
##   '.' open but INSIDE (a tunnel or a chamber: the dark back wall shows)
##   ' ' open air
## The outline between solid and open is smoothed (a light blur, then marching
## squares), so steps come out as rounded slopes and bumps. Flat ground lies
## exactly half-way between the first solid row and the open row above it:
## surface y = position.y + (row - 0.5) * CELL, where `row` is the solid one.
## Features thinner than 2 samples are smoothed away.
##
## Digging (Terraria): his blows land on the rock nearest the spot he aims at —
## ahead of him, under him (DOWN + HIT), or over his head (HIT while rising) — a
## block about his own size per blow; harder rock takes more blows (HARD). A
## stomp digs a crater. What was dug becomes '.' (tunnel). Finds can be buried
## in the rock (`loot`): they glint through it, and pop out when dug free.
##
## Built in chunks of CHUNK columns, each with its own textured meshes (back
## wall, rock, material patches, moss), its own outline overlay (a Batch) and
## its own collision; a blow rebuilds only the chunks it touches.

signal dug(at: Vector2, material: String)

const CELL := 40.0
const CHUNK := 8
const SOLIDS := "#=od"
const HARD := {"d": 1, "#": 2, "o": 3, "=": 3}        ## blows to break a sample
const TEX := {
	"#": "res://common/art/rock_boulders.png",
	"=": "res://common/art/rock_strata.png",
	"o": "res://common/art/rock_grey.png",
	"d": "res://common/art/dirt.png",
}
const BACK_TEX := "res://common/art/rock_boulders.png"
const MOSS_TEX := "res://common/art/grass.png"     ## (clover-and-grass, painted: lusher than the old moss.png)
const GRASS_TEX := "res://common/art/grass.png"
const EARTH_TEX := "res://common/art/earth.png"
const ROCK_TEX := "res://common/art/rock_boulders.png"
## The night's light on the painted textures (shared by everything painted with them).
const NIGHT_ROCK := Color(0.66, 0.63, 0.74)
const NIGHT_EARTH := Color(0.62, 0.52, 0.48)
const NIGHT_GRASS := Color(0.5, 0.68, 0.45)
const TEXEL := 1.6                 ## world px per texture px (512 px texture -> ~820 px tile)
## Each material's colour under the night (the strata are deep, dark earth).
const MAT_TINT := {"=": Color(0.42, 0.3, 0.3), "o": Color(0.6, 0.6, 0.68), "d": Color(0.62, 0.5, 0.42)}
const CHIP := {"#": Color("6b625c"), "=": Color("6e4a40"), "o": Color("8d8a96"), "d": Color("7a5236")}

var map: Array = []                ## the rows (Strings)
var level_id := "level2"
## Finds buried in the rock: sample index -> [kind, id]. A kind "relic:<k>" is a
## rare find (Relics.KINDS), anything else a Treasure.Pickup kind.
var loot := {}
var tint := Color(0.66, 0.63, 0.74)            ## night light on the rock
var back_tint := Color(0.13, 0.11, 0.16)       ## the back wall of tunnels and caves: well back, so the walkable rock stands out
var moss_tint := Color(0.5, 0.68, 0.45)
var outline := Color("1d1712")

var _w := 0
var _h := 0
var _g := PackedByteArray()        ## the map, one byte (char code) per sample
var _hits := PackedByteArray()     ## blows left per sample
var _fields := {}                  ## which -> PackedFloat32Array (blurred): F_SOLID, F_INSIDE, or a material code
var _chunks: Array = []            ## per chunk: Dictionary (see _build_chunk)
var _glints: Node2D
var _dirty := {}                   ## chunk -> materials changed: rebuilt one per frame (the one hit, at once)
var _damaged := {}                 ## sample index -> true: rock that has taken a blow but stands (its cracks are drawn)
const F_SOLID := -1
const F_INSIDE := -2
const C_AIR := 32
const C_IN := 46
const MATS := ["=", "o", "d"]      ## drawn as patches over the main rock


func _ready() -> void:
	_h = map.size()
	for r in map:
		_w = maxi(_w, (r as String).length())
	_g.resize(_w * _h)
	_hits.resize(_w * _h)
	for r in _h:
		var row: String = map[r]
		for c in _w:
			var ch := row[c] if c < row.length() else " "
			_g[r * _w + c] = ch.unicode_at(0)
			_hits[r * _w + c] = HARD.get(ch, 1)
	var whichs := [F_SOLID, F_INSIDE]
	for m in MATS:
		whichs.append((m as String).unicode_at(0))
	for which in whichs:
		var f := PackedFloat32Array()
		f.resize(_w * _h)
		_fields[which] = f
	_refield(0, 0, _w - 1, _h - 1)
	for k in ceili(float(_w - 1) / CHUNK):
		_chunks.append({})
		_build_chunk(k)
	# one area over all of it: his swing finds it, and we work out where it landed
	var area := _Hitter.new()
	area.terrain = self
	area.collision_layer = 4
	area.collision_mask = 0
	area.monitoring = false
	var acs := CollisionShape2D.new()
	var ash := RectangleShape2D.new()
	ash.size = Vector2(_w - 1, _h - 1) * CELL
	acs.shape = ash
	acs.position = ash.size * 0.5
	area.add_child(acs)
	add_child(area)
	add_to_group("stomp_spot")
	add_to_group("diggable")
	_glints = _Glints.new()
	_glints.terrain = self
	add_child(_glints)


func _process(_delta: float) -> void:
	if not _dirty.is_empty():
		var k: int = _dirty.keys()[0]
		_build_chunk(k, _dirty[k])
		_dirty.erase(k)


func _code(c: int, r: int) -> int:
	return _g[clampi(r, 0, _h - 1) * _w + clampi(c, 0, _w - 1)]


func _ch(c: int, r: int) -> String:
	return char(_code(c, r))


func _is_solid_code(code: int) -> bool:
	return code == 35 or code == 61 or code == 111 or code == 100


func _raw(which: int, c: int, r: int) -> float:
	var code := _code(c, r)
	if which == F_SOLID:
		return 1.0 if _is_solid_code(code) else 0.0
	if which == F_INSIDE:
		return 0.0 if code == C_AIR else 1.0
	return 1.0 if code == which else 0.0


## Re-blur every field over samples [c0..c1] x [r0..r1] (a light 3x3 blur, so corners round off).
func _refield(c0: int, r0: int, c1: int, r1: int, only: Array = []) -> void:
	c0 = maxi(c0, 0)
	r0 = maxi(r0, 0)
	c1 = mini(c1, _w - 1)
	r1 = mini(r1, _h - 1)
	for which in _fields:
		if not only.is_empty() and not only.has(which):
			continue
		var f: PackedFloat32Array = _fields[which]
		for r in range(r0, r1 + 1):
			for c in range(c0, c1 + 1):
				var s := 4.0 * _raw(which, c, r)
				s += 2.0 * (_raw(which, c - 1, r) + _raw(which, c + 1, r) + _raw(which, c, r - 1) + _raw(which, c, r + 1))
				s += _raw(which, c - 1, r - 1) + _raw(which, c + 1, r - 1) + _raw(which, c - 1, r + 1) + _raw(which, c + 1, r + 1)
				f[r * _w + c] = s / 16.0
		_fields[which] = f


func _v(f: PackedFloat32Array, c: int, r: int) -> float:
	return f[clampi(r, 0, _h - 1) * _w + clampi(c, 0, _w - 1)]


## Marching squares for one cell: the solid part as one convex polygon, and the
## outline pieces through it (exit -> entry, walking clockwise).
func _cell(f: PackedFloat32Array, c: int, r: int, edges: Array) -> PackedVector2Array:
	# fast paths: most cells are all open or all solid
	var i00 := clampi(r, 0, _h - 1) * _w
	var i01 := clampi(r + 1, 0, _h - 1) * _w
	var ca := clampi(c, 0, _w - 1)
	var cb := clampi(c + 1, 0, _w - 1)
	var v0 := f[i00 + ca]
	var v1 := f[i00 + cb]
	var v2 := f[i01 + cb]
	var v3 := f[i01 + ca]
	if v0 < 0.5 and v1 < 0.5 and v2 < 0.5 and v3 < 0.5:
		return PackedVector2Array()
	if v0 >= 0.5 and v1 >= 0.5 and v2 >= 0.5 and v3 >= 0.5:
		return PackedVector2Array([Vector2(c, r) * CELL, Vector2(c + 1, r) * CELL, Vector2(c + 1, r + 1) * CELL, Vector2(c, r + 1) * CELL])
	var p := [Vector2(c, r) * CELL, Vector2(c + 1, r) * CELL, Vector2(c + 1, r + 1) * CELL, Vector2(c, r + 1) * CELL]
	var v := [_v(f, c, r), _v(f, c + 1, r), _v(f, c + 1, r + 1), _v(f, c, r + 1)]
	var poly := PackedVector2Array()
	var exit_at := Vector2.INF
	var exit_air := Vector2.ZERO
	for i in 4:
		var j := (i + 1) % 4
		var vi: float = v[i]
		var vj: float = v[j]
		var pi: Vector2 = p[i]
		var pj: Vector2 = p[j]
		if vi >= 0.5:
			poly.append(pi)
		if (vi >= 0.5) != (vj >= 0.5):
			var e := pi.lerp(pj, (0.5 - vi) / (vj - vi))
			poly.append(e)
			if vi >= 0.5:
				exit_at = e
				exit_air = pj
			elif exit_at != Vector2.INF:
				edges.append(_edge(exit_at, e, exit_air))
				exit_at = Vector2.INF
	# an exit not yet closed (the walk started outside): it pairs with the first entry
	if exit_at != Vector2.INF:
		for i in 4:
			var j := (i + 1) % 4
			var vi: float = v[i]
			var vj: float = v[j]
			if vi < 0.5 and vj >= 0.5:
				var pi: Vector2 = p[i]
				edges.append(_edge(exit_at, pi.lerp(p[j], (0.5 - vi) / (vj - vi)), exit_air))
				break
	return poly


func _edge(a: Vector2, b: Vector2, toward_air: Vector2) -> Array:
	var d := (b - a).normalized()
	var n := Vector2(d.y, -d.x)
	if (toward_air - (a + b) * 0.5).dot(n) < 0.0:
		n = -n
	return [a, b, n]


func _mesh(mi: MeshInstance2D, parent: Node, polys: Array, tex_path: String, col: Color, z: int) -> MeshInstance2D:
	if mi == null:
		mi = MeshInstance2D.new()
		mi.texture = load(tex_path) as Texture2D
		mi.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		mi.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS     # smooth paint, not blocky pixels
		mi.modulate = col
		mi.z_index = z
		parent.add_child(mi)
	if polys.is_empty():
		mi.mesh = null
		return mi
	var tsz := mi.texture.get_size() * TEXEL
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for poly in polys:
		var pp: PackedVector2Array = poly
		for i in range(1, pp.size() - 1):
			for q in [pp[0], pp[i], pp[i + 1]]:
				verts.append(q)
				uvs.append((q + position) / tsz)      # world-anchored, so chunks and neighbours tile seamlessly
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mi.mesh = am
	return mi


## (Re)builds chunk k: cells [k*CHUNK, (k+1)*CHUNK) of the sample grid. `mats`: which
## material patches to rebuild (default all; after a dig, only those that changed).
func _build_chunk(k: int, mats: Array = MATS) -> void:
	var ch: Dictionary = _chunks[k]
	if ch.is_empty():
		var node := Node2D.new()
		add_child(node)
		ch["node"] = node
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		node.add_child(body)
		ch["body"] = body
		var over := Node2D.new()
		over.z_index = 2
		node.add_child(over)
		over.draw.connect(_draw_edges.bind(k, over))
		ch["over"] = over
		ch["patch"] = {}
		ch["mseams"] = {}
	var node2: Node2D = ch["node"]
	var c0 := k * CHUNK
	var c1 := mini(c0 + CHUNK, _w - 1)
	var back := []
	var rock := []
	var edges := []
	var full_runs := []
	var parts := []
	var dummy := []
	var fs: PackedFloat32Array = _fields[F_SOLID]
	var fi: PackedFloat32Array = _fields[F_INSIDE]
	for r in _h - 1:
		var run_start := -1
		for c in range(c0, c1 + 1):
			var full := false
			if c < c1:
				var bp := _cell(fi, c, r, dummy)
				if bp.size() >= 3:
					back.append(bp)
				var poly := _cell(fs, c, r, edges)
				if poly.size() >= 3:
					rock.append(poly)
					full = poly.size() == 4 and _v(fs, c, r) >= 0.5 and _v(fs, c + 1, r) >= 0.5 \
						and _v(fs, c + 1, r + 1) >= 0.5 and _v(fs, c, r + 1) >= 0.5
					if not full:
						parts.append(poly)
			if full and run_start < 0:
				run_start = c
			elif not full and run_start >= 0:
				full_runs.append(Rect2(run_start * CELL, r * CELL, (c - run_start) * CELL, CELL))
				run_start = -1
	ch["back"] = _mesh(ch.get("back"), node2, back, BACK_TEX, back_tint, -1)
	ch["rock"] = _mesh(ch.get("rock"), node2, rock, TEX["#"], tint, 0)
	# each other material as its own smoothed patch over the rock: blends in with curves
	var patches: Dictionary = ch["patch"]
	var mseams: Dictionary = ch["mseams"]
	for m in mats:
		var mf: PackedFloat32Array = _fields[(m as String).unicode_at(0)]
		var polys := []
		var ms := []
		for r in _h - 1:
			for c in range(c0, c1):
				var pp := _cell(mf, c, r, ms)
				if pp.size() >= 3:
					polys.append(pp)
		patches[m] = _mesh(patches.get(m), node2, polys, TEX[m], MAT_TINT.get(m, tint), 0)
		var keep := []
		for s in ms:
			# only the seams inside the rock (an outer edge is drawn anyway)
			if _sample(fs, (s[0] + s[1]) * 0.5 + (s[2] as Vector2) * CELL * 0.5) >= 0.5:
				keep.append(s)
		mseams[m] = keep
	var seams := []
	for m in mseams:
		seams.append_array(mseams[m])
	# moss along the tops out under the sky
	var moss := []
	for e in edges:
		var n: Vector2 = e[2]
		if n.y < -0.55 and not _in_tunnel(e):
			var a: Vector2 = e[0]
			var b: Vector2 = e[1]
			moss.append(PackedVector2Array([a + n * 3.0, b + n * 3.0, b - n * 16.0, a - n * 16.0]))
	ch["moss"] = _mesh(ch.get("moss"), node2, moss, MOSS_TEX, moss_tint, 1)
	ch["edges"] = edges
	ch["seams"] = seams
	# collision: merged full cells, one convex shape per edge cell
	var body2: StaticBody2D = ch["body"]
	for o in body2.get_shape_owners():
		body2.remove_shape_owner(o)
	for rc in full_runs:
		var rect: Rect2 = rc
		var sh := RectangleShape2D.new()
		sh.size = rect.size
		var o2 := body2.create_shape_owner(body2)
		body2.shape_owner_set_transform(o2, Transform2D(0.0, rect.get_center()))
		body2.shape_owner_add_shape(o2, sh)
	if not parts.is_empty():
		var own := body2.create_shape_owner(body2)
		for poly in parts:
			var cp := ConvexPolygonShape2D.new()
			cp.points = poly
			body2.shape_owner_add_shape(own, cp)
	(ch["over"] as Node2D).queue_redraw()


## A field's value at a point (local px), bilinear between samples.
func _sample(f: PackedFloat32Array, at: Vector2) -> float:
	var g := at / CELL
	var c := floori(g.x)
	var r := floori(g.y)
	var fx := g.x - c
	var fy := g.y - r
	return lerpf(lerpf(_v(f, c, r), _v(f, c + 1, r), fx), lerpf(_v(f, c, r + 1), _v(f, c + 1, r + 1), fx), fy)


## Is the open side of this edge inside the mountain (a tunnel or a cave)?
func _in_tunnel(e: Array) -> bool:
	var n: Vector2 = e[2]
	return _sample(_fields[F_INSIDE], (e[0] + e[1]) * 0.5 + n * CELL * 0.6) >= 0.5


func edge_count() -> int:
	var n := 0
	for ch in _chunks:
		n += (ch.get("edges", []) as Array).size()
	return n


## The surface under (x, from_y) in world px, or INF: for placing things on it.
func ground_y(x: float, from_y: float) -> float:
	return _surface(x, from_y, true)


## The cave roof above (x, from_y) in world px, or -INF: for hanging things from it.
func roof_y(x: float, from_y: float) -> float:
	return _surface(x, from_y, false)


func _surface(x: float, from_y: float, floor_side: bool) -> float:
	var lx := x - position.x
	var best := INF if floor_side else -INF
	var k := clampi(floori(lx / CELL / CHUNK), 0, _chunks.size() - 1)
	for kk in [k - 1, k, k + 1]:
		if kk < 0 or kk >= _chunks.size():
			continue
		for e in _chunks[kk].get("edges", []):
			var n: Vector2 = e[2]
			if (floor_side and n.y >= -0.2) or (not floor_side and n.y <= 0.2):
				continue
			var a: Vector2 = e[0]
			var b: Vector2 = e[1]
			if lx < minf(a.x, b.x) or lx > maxf(a.x, b.x) or absf(b.x - a.x) < 0.001:
				continue
			var y := lerpf(a.y, b.y, (lx - a.x) / (b.x - a.x)) + position.y
			if floor_side and y >= from_y - 1.0 and y < best:
				best = y
			elif not floor_side and y <= from_y + 1.0 and y > best:
				best = y
	return best


## Is this world point inside a tunnel or a cave (not out under the sky)?
func is_inside(at: Vector2) -> bool:
	var l := at - position
	if l.x < 0.0 or l.y < 0.0 or l.x > (_w - 1) * CELL or l.y > (_h - 1) * CELL:
		return false
	return _sample(_fields[F_INSIDE], l) >= 0.5 and _sample(_fields[F_SOLID], l) < 0.5


## Is there rock at this world point?
func is_solid(at: Vector2) -> bool:
	var l := at - position
	if l.x < 0.0 or l.y < 0.0 or l.x > (_w - 1) * CELL or l.y > (_h - 1) * CELL:
		return false
	return _sample(_fields[F_SOLID], l) >= 0.5


## The world rect the map covers.
func bounds() -> Rect2:
	return Rect2(position, Vector2(_w - 1, _h - 1) * CELL)


## ------------------------------------------------------------------ digging
func _diggable(c: int, r: int) -> bool:
	return c >= 2 and c <= _w - 3 and r >= 0 and r <= _h - 3 and _is_solid_code(_code(c, r))


## One blow at a world point: the (up to) `n` solid samples nearest it within
## `reach` px each lose a blow; those with none left are dug out. True if it hit rock.
func dig_at(world: Vector2, reach := 52.0, n := 4) -> bool:
	var l := (world - position) / CELL
	var cands := []
	for r in range(floori(l.y) - 1, floori(l.y) + 3):
		for c in range(floori(l.x) - 1, floori(l.x) + 3):
			if not _diggable(c, r):
				continue
			var d := Vector2(c, r).distance_to(l) * CELL
			if d <= reach:
				cands.append([d, c, r])
	if cands.is_empty():
		return false
	cands.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	var broke := []
	var mat := ""
	for i in mini(n, cands.size()):
		var c: int = cands[i][1]
		var r: int = cands[i][2]
		var idx := r * _w + c
		if mat == "":
			mat = char(_g[idx])
		_hits[idx] = maxi(_hits[idx] - 1, 0)
		if _hits[idx] == 0:
			broke.append(Vector2i(c, r))
			_damaged.erase(idx)
		else:
			_damaged[idx] = true
	if broke.is_empty():
		_glints.chip(world, CHIP.get(mat, Color.GRAY), 4)
		FX.dig_flash(get_parent(), world, CHIP.get(mat, Color.GRAY), false)
		return true
	var lo := Vector2i(_w, _h)
	var hi := Vector2i(-1, -1)
	var changed := []
	for s in broke:
		var was := char(_g[s.y * _w + s.x])
		if MATS.has(was) and not changed.has(was):
			changed.append(was)
		_g[s.y * _w + s.x] = C_IN
		lo = Vector2i(mini(lo.x, s.x), mini(lo.y, s.y))
		hi = Vector2i(maxi(hi.x, s.x), maxi(hi.y, s.y))
	var only := [F_SOLID, F_INSIDE]
	for m in changed:
		only.append((m as String).unicode_at(0))
	_refield(lo.x - 1, lo.y - 1, hi.x + 1, hi.y + 1, only)
	var k0 := clampi(floori(float(lo.x - 2) / CHUNK), 0, _chunks.size() - 1)
	var k1 := clampi(floori(float(hi.x + 2) / CHUNK), 0, _chunks.size() - 1)
	var main := clampi(floori(float(lo.x + hi.x) * 0.5 / CHUNK), 0, _chunks.size() - 1)
	for k in range(k0, k1 + 1):
		var m2: Array = _dirty.get(k, [])
		for m in changed:
			if not m2.has(m):
				m2.append(m)
		_dirty[k] = m2
	_build_chunk(main, _dirty[main])
	_dirty.erase(main)
	_glints.chip(world, CHIP.get(mat, Color.GRAY), 12)
	FX.dig_flash(get_parent(), world, CHIP.get(mat, Color.GRAY), true)
	FX.burst(get_parent(), world, "dust")
	for s in broke:
		_reveal(s)
	dug.emit(world, mat)
	return true


## A dug-out sample with a find in it: out it pops.
func _reveal(s: Vector2i) -> void:
	var idx := s.y * _w + s.x
	if not loot.has(idx):
		return
	var l: Array = loot[idx]
	loot.erase(idx)
	if GameState.is_taken(level_id, l[1]):
		return
	var at := position + Vector2(s) * CELL
	var lvl := get_parent()
	var kind: String = l[0]
	if kind.begins_with("stone:"):
		Bag.unearth(lvl, at, kind.substr(6), level_id, l[1])
		return
	if kind.begins_with("relic:"):
		var relic := Relics.Relic.new()
		relic.kind = kind.substr(6)
		relic.level_id = level_id
		relic.id = l[1]
		relic.position = at + Vector2(0, -10)
		if lvl.has_method("_relic_found"):
			relic.found.connect(lvl._relic_found)
		lvl.add_child.call_deferred(relic)
		return
	var pk := Treasure.Pickup.new()
	pk.kind = kind
	pk.level_id = level_id
	pk.id = l[1]
	pk.position = at
	pk.vel = Vector2(randf_range(-60, 60), -320)
	var fy := ground_y(at.x, at.y - 20.0)
	pk.floor_y = fy if fy < INF else at.y + CELL
	if lvl.has_method("_on_treasure_popped"):
		lvl._on_treasure_popped(pk)
	lvl.add_child.call_deferred(pk)


## His blow: where it lands depends on how he swings (see the class comment).
func struck() -> void:
	var p := get_tree().get_first_node_in_group("player") as CaveMan
	if p == null or p.attacking <= 0.0:
		return                     # (fireballs and the like don't dig)
	var feet := p.global_position
	if p.tool == "shovel" and not p.digging_down:
		# the SHOVEL (the hotbar): it bites wherever he aims, and bigger than a club
		dig_at(feet + Vector2(0, -40) + p._dig_aim * 50.0, 60.0, 6)
	elif p.digging_down:
		dig_at(feet + Vector2(0, 26), 60.0 if p.tool == "shovel" else 52.0, 6 if p.tool == "shovel" else 4)
	elif not p.is_on_floor() and p.velocity.y < 0.0:
		dig_at(feet + Vector2(0, -104))
	else:
		dig_at(feet + Vector2(p.facing * 46.0, -40.0))


## A stomp (group "stomp_spot"): a crater where he lands, wider for a MEGA stomp.
func stomped(level: int, at: Vector2) -> void:
	if not bounds().grow(40.0).has_point(at):
		return
	if level >= 2:
		for i in 3:
			dig_at(at + Vector2(0, 24), 70.0, 8)
	else:
		dig_at(at + Vector2(0, 24))


func _draw_edges(k: int, over: Node2D) -> void:
	var ch: Dictionary = _chunks[k]
	var edges: Array = ch.get("edges", [])
	var b := Batch.new()
	# shading in from every edge: the rock darkens toward its rim, so it reads round
	for e in edges:
		var a: Vector2 = e[0]
		var c: Vector2 = e[1]
		var n: Vector2 = e[2]
		var dark := Color(0.05, 0.03, 0.06, 0.55 if n.y > 0.3 else 0.35)
		var clear := Color(0.05, 0.03, 0.06, 0.0)
		b.quad(a, c, c - n * 26.0, a - n * 26.0, dark, PackedColorArray([dark, dark, clear, clear]))
	# the cartoon outline, like everything else in the world
	for e in edges:
		b.line(e[0], e[1], outline, 5.0)
	for s in ch.get("seams", []):
		b.line(s[0], s[1], Color(outline, 0.6), 3.0)
	# inside the mountain, the rock's edges catch the torchlight: a warm rim
	for e in edges:
		if _in_tunnel(e):
			var rn: Vector2 = e[2]
			b.line((e[0] as Vector2) - rn * 4.0, (e[1] as Vector2) - rn * 4.0, Color(0.95, 0.78, 0.55, 0.42), 3.0)
	# tufts of grass on the moss
	for i in edges.size():
		var e: Array = edges[i]
		var n2: Vector2 = e[2]
		if n2.y < -0.7 and i % 3 == 0 and not _in_tunnel(e):
			var m: Vector2 = (e[0] + e[1]) * 0.5
			for t in 3:
				var bx := m + Vector2(-6.0 + t * 6.0, 1.0)
				b.tri(bx + Vector2(-2.5, 0), bx + Vector2(2.5, 0), bx + Vector2(sin(i + t) * 3.0, -9.0 - (i + t) % 4 * 2.0), Color(0.38, 0.55, 0.32))
	b.draw(over)


## Paints a plain rectangle of rock (a Crag, a cave floor) with the same painted
## texture as the terrain, world-anchored so neighbours line up: one textured
## MeshInstance2D child of `owner_node` (whose position is the rect's corner).
## The caller draws its own lip and outline over it.
static func paint_rect(owner_node: Node2D, size: Vector2, tex_key: String, col: Color, z: int = 0) -> void:
	var tex := load(TEX.get(tex_key, tex_key if tex_key.begins_with("res://") else TEX["#"])) as Texture2D     # a map key, or a texture path
	var tsz := tex.get_size() * TEXEL
	var o := owner_node.position
	var pts := [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in [0, 1, 2, 0, 2, 3]:
		var q: Vector2 = pts[i]
		verts.append(q)
		uvs.append((q + o) / tsz)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance2D.new()
	mi.mesh = am
	mi.texture = tex
	mi.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	mi.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS     # smooth paint, not blocky pixels
	mi.modulate = col
	mi.z_index = z
	mi.z_as_relative = true
	mi.show_behind_parent = true
	owner_node.add_child(mi)



## Paints any polygon (in `owner_node`'s space) with a painted texture: one
## textured mesh, behind the owner's own drawing (so its outline and details go
## on top). The texture is anchored at `anchor` + the polygon (pass the world
## position, so islands side by side don't all show the same patch). Triangulated
## once: for things that are built once and only move as a whole.
static func paint_poly(owner_node: Node2D, poly: PackedVector2Array, tex_path: String, col: Color, anchor := Vector2.ZERO) -> MeshInstance2D:
	var idx := Geometry2D.triangulate_polygon(poly)
	if idx.is_empty():
		return null
	var tex := load(tex_path) as Texture2D
	var tsz := tex.get_size() * TEXEL
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in idx:
		var q: Vector2 = poly[i]
		verts.append(q)
		uvs.append((q + anchor) / tsz)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance2D.new()
	mi.mesh = am
	mi.texture = tex
	mi.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	mi.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS     # smooth paint, not blocky pixels
	mi.modulate = col
	mi.show_behind_parent = true
	owner_node.add_child(mi)
	return mi

## ================================================================ HITTER
class _Hitter extends Area2D:
	var terrain: Terrain

	func take_hit(_dmg: int, _from_dir: int) -> void:
		terrain.struck()


## ================================================================ GLINTS
class _Glints extends Node2D:
	## What shows through the rock: buried finds glinting (a little fossil
	## shell in the stone, a coloured gleam for a rare one), cracks where it
	## has been hit, and the chips flying off a blow. Redrawn only near view.
	var terrain: Terrain
	var _t := 0.0
	var _chips: Array = []       ## [pos (local), vel, life, colour]

	func _ready() -> void:
		z_index = 3
		add_to_group("glow")

	func chip(world: Vector2, col: Color, n: int) -> void:
		var at := world - terrain.position
		for k in n:
			_chips.append([at, Vector2(randf_range(-170, 170), randf_range(-280, -60)), randf_range(0.35, 0.7), col])

	func _process(delta: float) -> void:
		_t += delta
		for ch in _chips:
			ch[1] = (ch[1] as Vector2) + Vector2(0, 900) * delta
			ch[0] = (ch[0] as Vector2) + (ch[1] as Vector2) * delta
			ch[2] = float(ch[2]) - delta
		if not _chips.is_empty():
			_chips = _chips.filter(func(ch): return float(ch[2]) > 0.0)
		var cam := get_viewport().get_camera_2d()
		if cam != null and terrain.bounds().grow(400.0).has_point(cam.get_screen_center_position()):
			queue_redraw()

	func _view() -> Rect2:
		var cam := get_viewport().get_camera_2d()
		if cam == null:
			return Rect2()
		var half := LevelBase.view_half(self) + Vector2(80, 80)
		return Rect2(cam.get_screen_center_position() - half - terrain.position, half * 2.0)

	func _draw() -> void:
		var b := Batch.new()
		var view := _view()
		var w := terrain._w
		var charm := GameState.has_item("lucky_charm")
		for idx in terrain.loot:
			var s := Vector2(idx % w, idx / w) * Terrain.CELL
			if not view.has_point(s):
				continue
			var kind: String = terrain.loot[idx][0]
			if kind.begins_with("stone:"):
				# stones hide in the rock; the LUCKY CHARM shows them, a faint glint in their colour
				if charm and fmod(_t * 0.8 + float(idx % 89) * 0.41, 2.2) < 0.5:
					var sc := Bag.rarity_col(kind.substr(6))
					b.ellipse(s, 6.0, 4.0, Color(sc, 0.75))
					b.line(s + Vector2(-9, 0), s + Vector2(9, 0), Color(sc, 0.8), 1.5)
					b.line(s + Vector2(0, -9), s + Vector2(0, 9), Color(sc, 0.8), 1.5)
				continue
			var rare := kind.begins_with("relic:") or kind in ["conch", "tusk"]
			var col := Relics.colour(kind.substr(6)) if kind.begins_with("relic:") else (Color("ffd9a0") if rare else Color("e8dcc0"))
			# a little fossil in the stone: a dark socket, the find showing in it
			b.ellipse(s, 13.0, 10.0, Color(0.06, 0.04, 0.04, 0.7))
			b.ellipse(s + Vector2(0, -1), 10.0, 7.5, Color(col, 0.85 if rare else 0.7))
			b.ellipse(s + Vector2(-3, -4), 3.5, 2.2, Color(1, 1, 1, 0.5))
			for f in 3:
				b.line(s + Vector2(-4.0 + f * 4.0, 3), s + Vector2(-3.0 + f * 3.0, -4), Color(0.1, 0.07, 0.06, 0.45), 1.2)
			# and a glint, now and then
			var ph := fmod(_t * (1.4 if rare else 1.0) + float(idx % 97) * 0.37, 1.6)
			if ph < 0.4:
				var k := sin(ph / 0.4 * PI) * (22.0 if rare else 15.0)
				b.line(s + Vector2(-k, 0), s + Vector2(k, 0), Color(1, 1, 0.9, 0.9), 2.0)
				b.line(s + Vector2(0, -k), s + Vector2(0, k), Color(1, 1, 0.9, 0.9), 2.0)
		# cracks on rock that has taken a blow
		for i in terrain._damaged:
			var s2 := Vector2(i % w, i / w) * Terrain.CELL
			if not view.has_point(s2):
				continue
			var full: int = Terrain.HARD.get(char(terrain._g[i]), 1)
			var dmg := 1.0 - float(terrain._hits[i]) / full
			for q in 3:
				var a := q * 2.1 + float(i % w)
				b.line(s2, s2 + Vector2.from_angle(a) * 18.0 * dmg, Color(0.08, 0.05, 0.04, 0.85), 2.0)
		for ch in _chips:
			var q2: float = clampf(float(ch[2]) / 0.6, 0.0, 1.0)
			b.rect(Rect2(ch[0] - Vector2(3, 3), Vector2(6, 6)), Color(ch[3], q2))
		b.draw(self)

	func draw_glow(g) -> void:   # g: the glow layer's Batch
		var view := _view()
		var w := terrain._w
		for idx in terrain.loot:
			var s := Vector2(idx % w, idx / w) * Terrain.CELL
			if not view.has_point(s):
				continue
			var kind: String = terrain.loot[idx][0]
			if kind.begins_with("relic:"):
				g.draw_circle(terrain.position + s, 20.0, Color(Relics.colour(kind.substr(6)), 0.25))
			elif kind in ["conch", "tusk"]:
				g.draw_circle(terrain.position + s, 12.0, Color(1.0, 0.85, 0.6, 0.18))
