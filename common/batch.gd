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

var points := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()


## Any simple polygon, convex or not. One that crosses itself can't be
## triangulated and is skipped — the same polygons draw_colored_polygon rejects.
func poly(pts: PackedVector2Array, col: Color) -> void:
	var tri := Geometry2D.triangulate_polygon(pts)
	if tri.is_empty():
		return
	var base := points.size()
	for p in pts:
		points.append(p)
		colors.append(col)
	for i in tri:
		indices.append(base + i)


func tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var base := points.size()
	points.append_array(PackedVector2Array([a, b, c]))
	colors.append_array(PackedColorArray([col, col, col]))
	indices.append_array(PackedInt32Array([base, base + 1, base + 2]))


## Four corners in order; each corner may have its own colour (for gradients).
func quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color, cols: PackedColorArray = PackedColorArray()) -> void:
	var base := points.size()
	points.append_array(PackedVector2Array([a, b, c, d]))
	if cols.size() == 4:
		colors.append_array(cols)
	else:
		colors.append_array(PackedColorArray([col, col, col, col]))
	indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


func rect(r: Rect2, col: Color) -> void:
	quad(r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), col)


func line(a: Vector2, b: Vector2, col: Color, width: float = 1.0) -> void:
	var d := b - a
	if d.length_squared() < 0.0001:
		return
	var n := Vector2(-d.y, d.x).normalized() * width * 0.5
	quad(a + n, b + n, b - n, a - n, col)


func polyline(pts: PackedVector2Array, col: Color, width: float = 1.0) -> void:
	for i in pts.size() - 1:
		line(pts[i], pts[i + 1], col, width)


func circle(c: Vector2, r: float, col: Color, segments: int = 12) -> void:
	var base := points.size()
	points.append(c)
	colors.append(col)
	for i in segments:
		points.append(c + Vector2.from_angle(TAU * i / segments) * r)
		colors.append(col)
	for i in segments:
		indices.append_array(PackedInt32Array([base, base + 1 + i, base + 1 + (i + 1) % segments]))


## Everything recorded so far, as one draw call on this canvas item.
## Call it from inside the item's _draw().
func draw(ci: CanvasItem) -> void:
	if indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), indices, points, colors)
