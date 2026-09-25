class_name Night
extends Node
## Darkness and light. Every light source reports one circle — where it is and
## how far it reaches — and that single circle is used twice: the shader cuts
## it out of the dark, and the creatures refuse to enter it. What the player
## sees IS the rule, so there is never a question of why a wolf stopped.
##
## Light sources join the "light" group and implement:
##   light() -> Vector4            world x, world y, radius, warmth (0..1)
##   light_strength() -> float     how much it protects: 1 for a bonfire,
##                                 the fuel left for his torch
## Anything that should shine THROUGH the dark (eyes, embers) joins the "glow"
## group and implements draw_glow(canvas), drawing in world coordinates.

## A point counts as lit inside this fraction of a light's radius — where the
## light is still mostly light, not where its fade finally reaches the dark.
const EDGE := 0.85
const MAX_LIGHTS := 12
## The dark is soft gradients all the way through, so it is worked out on a
## small image and smoothed up to the screen: the shader runs for 57,600
## pixels instead of one per screen pixel (0.9 million at 720p, 3.7 million at
## 1440p), and its cost no longer grows with the window.
const DARK_RES := Vector2i(320, 180)

const SHADER := """
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

uniform vec2 view_size = vec2(1280.0, 720.0);
uniform float ambient = 0.7;
uniform float sky_lift = 1.0;
uniform vec4 dark_col : source_color = vec4(0.043, 0.067, 0.133, 1.0);
uniform vec4 warm_col : source_color = vec4(0.95, 0.56, 0.24, 1.0);
uniform int count = 0;
uniform vec4 lights[12];

void fragment() {
	vec2 p = UV * view_size;
	float lit = 0.0;
	float warm = 0.0;
	for (int i = 0; i < 12; i++) {
		if (i >= count) {
			break;
		}
		vec4 l = lights[i];
		if (l.z < 1.0) {
			continue;
		}
		float d = distance(p, l.xy);
		lit = max(lit, 1.0 - smoothstep(l.z * 0.6, l.z, d));
		warm += l.w * (1.0 - smoothstep(0.0, l.z, d));
	}
	// moonlight from above: the top of the screen is never quite as dark
	float sky = mix(1.0 - 0.28 * sky_lift, 1.0, smoothstep(0.0, 0.62, UV.y));
	float a = ambient * sky * (1.0 - lit);
	float w = min(warm, 1.0) * 0.16;
	COLOR = vec4(dark_col.rgb * a + warm_col.rgb * w, a);
}
"""

## [x, darkness] pairs, sorted by x. Darkness between them is interpolated, so
## night falls as he walks and the "dark zones" are just rows in a table.
var table: Array = []
## Extra darkness laid over the table for scripted moments (the Long Dark).
var extra := 0.0
var ambient := 0.7
var player: CaveMan
## The moon is a light too: a small hole in the dark at a fixed spot on screen.
var moon := Vector2(1010, 104)
var moon_r := 70.0
## Moonlight from above: 1 outdoors, 0 underground.
var sky_lift := 1.0

var _mat: ShaderMaterial
var _rect: ColorRect
## Cached once per physics frame, before any creature asks.
var _l: Array[Vector4] = []
var _str: Array[float] = []


func _ready() -> void:
	add_to_group("night")
	process_physics_priority = -100

	# the dark is drawn small, off screen...
	var small := SubViewport.new()
	small.size = DARK_RES
	small.transparent_bg = true
	small.disable_3d = true
	small.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(small)
	_rect = ColorRect.new()
	_rect.size = Vector2(DARK_RES)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect.material = _mat
	small.add_child(_rect)
	# ...and laid over the whole screen, smoothed. It holds premultiplied
	# colour, so it is blended that way.
	var dark := CanvasLayer.new()
	dark.layer = 3
	add_child(dark)
	var shown := TextureRect.new()
	shown.texture = small.get_texture()
	shown.set_anchors_preset(Control.PRESET_FULL_RECT)
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.stretch_mode = TextureRect.STRETCH_SCALE
	shown.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	shown.material = blend
	dark.add_child(shown)

	# Above the dark, but moving with the world: eyes, embers, fireflies.
	var glow := CanvasLayer.new()
	glow.layer = 4
	glow.follow_viewport_enabled = true
	add_child(glow)
	glow.add_child(Glow.new())


func darkness_at(x: float) -> float:
	if table.is_empty():
		return 0.7
	var first: Array = table[0]
	if x <= float(first[0]):
		return float(first[1])
	for i in range(1, table.size()):
		var b: Array = table[i]
		if x <= float(b[0]):
			var a: Array = table[i - 1]
			var k := (x - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1.0)
			return lerpf(float(a[1]), float(b[1]), k)
	var last: Array = table[table.size() - 1]
	return float(last[1])


func _physics_process(_delta: float) -> void:
	_l.clear()
	_str.clear()
	for n in get_tree().get_nodes_in_group("light"):
		var l: Vector4 = n.light()
		if l.z <= 0.0:
			continue
		_l.append(l)
		_str.append(float(n.light_strength()))


## Is this point inside any light?
func is_lit(p: Vector2) -> bool:
	for l in _l:
		if p.distance_squared_to(Vector2(l.x, l.y)) < (l.z * EDGE) * (l.z * EDGE):
			return true
	return false


## How strongly this point is protected: 0 in the dark, 1 beside a bonfire,
## and inside his torchlight however much fuel the torch has left.
func shelter_at(p: Vector2) -> float:
	var best := 0.0
	for i in _l.size():
		var l := _l[i]
		if p.distance_squared_to(Vector2(l.x, l.y)) < (l.z * EDGE) * (l.z * EDGE):
			best = maxf(best, _str[i])
	return best


func _process(_delta: float) -> void:
	if player != null:
		ambient = clampf(darkness_at(player.global_position.x) + extra, 0.0, 0.97)
	var xf := get_viewport().get_canvas_transform()
	var zoom := xf.get_scale().x
	var view := get_viewport().get_visible_rect().size
	var packed: Array[Vector4] = []
	packed.append(Vector4(moon.x, moon.y, moon_r, 0.0))
	for l in _l:
		if packed.size() >= MAX_LIGHTS:
			break
		var sp := xf * Vector2(l.x, l.y)
		var r := l.z * zoom
		if sp.x < -r or sp.x > view.x + r or sp.y < -r or sp.y > view.y + r:
			continue
		packed.append(Vector4(sp.x, sp.y, r, l.w))
	var used := packed.size()
	while packed.size() < MAX_LIGHTS:
		packed.append(Vector4.ZERO)
	_mat.set_shader_parameter("view_size", view)
	_mat.set_shader_parameter("ambient", ambient)
	_mat.set_shader_parameter("sky_lift", sky_lift)
	_mat.set_shader_parameter("count", used)
	_mat.set_shader_parameter("lights", packed)


## Draws everything in the "glow" group on the layer above the dark.
class Glow extends Node2D:
	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var cam := get_viewport().get_camera_2d()
		var cx := cam.get_screen_center_position() if cam != null else Vector2.ZERO
		for n in get_tree().get_nodes_in_group("glow"):
			var n2 := n as Node2D
			if n2 == null or absf(n2.global_position.x - cx.x) > 900.0:
				continue
			n2.draw_glow(self)
