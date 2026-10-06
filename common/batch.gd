class_name Batch
extends RefCounted
## Collects many shapes into ONE list of coloured triangles and hands it to the
## GPU in a single draw call.
##
## Why: every draw_colored_polygon / draw_circle / draw_line in a _draw() is
## its own draw call, and a draw call costs about the same whether it is one
## triangle or a thousand. A band of a hundred pines drawn shape by shape was
## ~680 calls a frame; the same pines recorded here are 1.
##
## Use it for scenery that doesn't change shape: build it once in _draw(),
## then draw(self). The picture is identical, but lines lose antialiasing.
##
##   var b := Batch.new()
##   b.poly(pts, Pal.PINE)
##   b.line(a, c, Pal.MOONLIT, 1.5)
##   b.draw(self)

## Triangles are stored flat — every three points is one triangle — so circles
## and lines can be stamped out of ready-made templates with a few bulk
## operations instead of a loop per point. (Characters redraw every frame, so
## this matters: a circle went from ~5 us to ~1 us.)
var points := PackedVector2Array()
var colors := PackedColorArray()
## Everything recorded is moved through this, like draw_set_transform: so a
## character can draw its legs in one frame of reference and its upper body
## in another, and still end up as one draw call.
var xf := Transform2D.IDENTITY
var _plain := true              ## xf is the identity: skip the maths

static var _fans := {}          ## circle templates by segment count, made once
static var _fill := {}          ## colour runs, reused


func set_xf(t: Transform2D) -> void:
	xf = t
	_plain = t == Transform2D.IDENTITY


func _add(pts: PackedVector2Array, col: Color) -> void:
	points.append_array(pts if _plain else xf * pts)
	var n := pts.size()
	var run: PackedColorArray = _fill.get(n, PackedColorArray())
	if run.size() != n:
		run.resize(n)
	run.fill(col)
	_fill[n] = run
	colors.append_array(run)


## Any simple polygon, convex or not. One that crosses itself can't be
## triangulated and is skipped — the same polygons draw_colored_polygon rejects.
func poly(pts: PackedVector2Array, col: Color) -> void:
	var tri := Geometry2D.triangulate_polygon(pts)
	if tri.is_empty():
		return
	var flat := PackedVector2Array()
	flat.resize(tri.size())
	for k in tri.size():
		flat[k] = pts[tri[k]]
	_add(flat, col)


## The same shape twice — a shadow tone, then a lit copy over it (same
## points, pulled in toward the light) — cut into triangles only once.
func poly_pair(pts: PackedVector2Array, col: Color, lit: PackedVector2Array, lit_col: Color) -> void:
	var tri := Geometry2D.triangulate_polygon(pts)
	if tri.is_empty():
		return
	var flat := PackedVector2Array()
	flat.resize(tri.size())
	var flat2 := PackedVector2Array()
	flat2.resize(tri.size())
	for k in tri.size():
		flat[k] = pts[tri[k]]
		flat2[k] = lit[tri[k]]
	_add(flat, col)
	_add(flat2, lit_col)


func tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	_add(PackedVector2Array([a, b, c]), col)


## A triangle with a colour at each corner (soft shading).
func tri_cols(a: Vector2, b: Vector2, c: Vector2, ca: Color, cb: Color, cc: Color) -> void:
	var pts := PackedVector2Array([a, b, c])
	points.append_array(pts if _plain else xf * pts)
	colors.append_array(PackedColorArray([ca, cb, cc]))


## Four corners in order; each corner may have its own colour (for gradients).
func quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color, cols: PackedColorArray = PackedColorArray()) -> void:
	if cols.size() == 4:
		var pts := PackedVector2Array([a, b, c, a, c, d])
		points.append_array(pts if _plain else xf * pts)
		colors.append_array(PackedColorArray([cols[0], cols[1], cols[2], cols[0], cols[2], cols[3]]))
		return
	_add(PackedVector2Array([a, b, c, a, c, d]), col)


## An ellipse (optionally turned), as a fan of triangles round its centre.
func ellipse(c: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0, segments: int = 16) -> void:
	var pts := PackedVector2Array()
	var prev := c + Vector2(rx, 0).rotated(rot)
	for i in range(1, segments + 1):
		var a := i * TAU / segments
		var p := c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot)
		pts.append(c)
		pts.append(prev)
		pts.append(p)
		prev = p
	_add(pts, col)


func rect(r: Rect2, col: Color) -> void:
	quad(r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), col)


func line(a: Vector2, b: Vector2, col: Color, width: float = 1.0) -> void:
	var d := b - a
	if d.length_squared() < 0.0001:
		return
	var n := Vector2(-d.y, d.x).normalized() * width * 0.5
	_add(PackedVector2Array([a + n, b + n, b - n, a + n, b - n, a - n]), col)


## A line through all the points, built in one pass (outlines are mostly this).
func polyline(pts: PackedVector2Array, col: Color, width: float = 1.0) -> void:
	var n := pts.size()
	if n < 2:
		return
	var out := PackedVector2Array()
	out.resize((n - 1) * 6)
	var h := width * 0.5
	var k := 0
	for i in n - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var d := b - a
		var l := d.length()
		if l < 0.001:
			d = Vector2(1, 0)
			l = 1.0
		var nn := Vector2(-d.y, d.x) * (h / l)
		out[k] = a + nn
		out[k + 1] = b + nn
		out[k + 2] = b - nn
		out[k + 3] = a + nn
		out[k + 4] = b - nn
		out[k + 5] = a - nn
		k += 6
	_add(out, col)


func circle(c: Vector2, r: float, col: Color, segments: int = 12) -> void:
	var fan: PackedVector2Array = _fans.get(segments, PackedVector2Array())
	if fan.is_empty():
		# a fan of triangles around (0, 0) on a circle of radius 1
		for i in segments:
			fan.append(Vector2.ZERO)
			fan.append(Vector2.from_angle(TAU * i / segments))
			fan.append(Vector2.from_angle(TAU * (i + 1) / segments))
		_fans[segments] = fan
	# scaled and moved into place in one step
	_add(Transform2D(0.0, Vector2(r, r), 0.0, c) * fan, col)


## An outline of part of a circle, as a line.
func arc(c: Vector2, r: float, a0: float, a1: float, segments: int, col: Color, width: float = 1.0) -> void:
	var pts := PackedVector2Array()
	for i in segments + 1:
		pts.append(c + Vector2.from_angle(lerpf(a0, a1, float(i) / segments)) * r)
	polyline(pts, col, width)


## ---- a Batch can stand in for a CanvasItem: drawing code written against
## draw_line / draw_circle / draw_colored_polygon / ... can draw into a Batch
## unchanged, and the whole picture becomes one draw call. (Text can't be
## triangles; it is kept aside and drawn over the top at the end.)
var _texts: Array = []


func draw_set_transform(pos: Vector2 = Vector2.ZERO, rot: float = 0.0, sc: Vector2 = Vector2.ONE) -> void:
	set_xf(Transform2D(rot, sc, 0.0, pos))


func draw_set_transform_matrix(m: Transform2D) -> void:
	set_xf(m)


func draw_line(a: Vector2, b: Vector2, col: Color, w: float = -1.0, _aa: bool = false) -> void:
	line(a, b, col, maxf(w, 1.0))


func draw_polyline(pts: PackedVector2Array, col: Color, w: float = -1.0, _aa: bool = false) -> void:
	polyline(pts, col, maxf(w, 1.0))


func draw_circle(c: Vector2, r: float, col: Color, filled: bool = true, w: float = -1.0, _aa: bool = false) -> void:
	if r <= 0.05:
		return
	var segs := clampi(int(r * 0.7) + 8, 8, 28)
	if filled:
		circle(c, r, col, segs)
	else:
		arc(c, r, 0.0, TAU, segs, col, maxf(w, 1.0))


func draw_colored_polygon(pts: PackedVector2Array, col: Color, _uvs: PackedVector2Array = PackedVector2Array(), _tex: Texture2D = null) -> void:
	poly(pts, col)


## A polygon with one colour, or one colour per corner (a gradient).
func draw_polygon(pts: PackedVector2Array, cols: PackedColorArray, _uvs: PackedVector2Array = PackedVector2Array(), _tex: Texture2D = null) -> void:
	if cols.size() <= 1:
		poly(pts, cols[0] if cols.size() == 1 else Color.WHITE)
		return
	var tri := Geometry2D.triangulate_polygon(pts)
	if tri.is_empty():
		return
	var flat := PackedVector2Array()
	flat.resize(tri.size())
	var fc := PackedColorArray()
	fc.resize(tri.size())
	for k in tri.size():
		flat[k] = pts[tri[k]]
		fc[k] = cols[tri[k]]
	points.append_array(flat if _plain else xf * flat)
	colors.append_array(fc)


func draw_rect(r: Rect2, col: Color, filled: bool = true, w: float = -1.0, _aa: bool = false) -> void:
	if filled:
		rect(r, col)
	else:
		polyline(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]), col, maxf(w, 1.0))


func draw_arc(c: Vector2, r: float, a0: float, a1: float, n: int, col: Color, w: float = -1.0, _aa: bool = false) -> void:
	arc(c, r, a0, a1, maxi(n, 2), col, maxf(w, 1.0))


func draw_string(font: Font, pos: Vector2, text: String, align: int = 0, width: float = -1.0, size: int = 16, col: Color = Color.WHITE) -> void:
	_texts.append([xf, font, pos, text, align, width, size, col])


## Only the triangles recorded between two marks (`points.size()` at the time):
## to draw other things (textured shapes) in between, in order.
func draw_range(ci: CanvasItem, from: int, to: int) -> void:
	if to > from:
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), PackedInt32Array(), points.slice(from, to), colors.slice(from, to))


## Everything recorded so far, as one draw call on this canvas item.
## Call it from inside the item's _draw().
func draw(ci: CanvasItem) -> void:
	if not points.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), PackedInt32Array(), points, colors)
	for t in _texts:
		ci.draw_set_transform_matrix(t[0])
		ci.draw_string(t[1], t[2], t[3], t[4], t[5], t[6], t[7])
	if not _texts.is_empty():
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
