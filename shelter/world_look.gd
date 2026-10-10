extends RefCounted
## THE HOME'S LOOK (shelter/home.gd): the world drawn like Ugu is, not in
## default shading. One shader for every merged shape and the ground:
## - TOON LIGHT: the sun and the fires in flat bands (as on Ugu, ugu3d.gd), a
##   lit band, a shade band, a little light kept in the shade.
## - A RIM: every shape goes darker toward its edges (Ugu's rims are a darker
##   tone of each fill; here the same idea, without an extra pass).
## - PAINTED SURFACES, told apart by their colour: STONE gets strata and
##   speckles, WOOD a grain, LEAVES dappled light, the GROUND brush strokes (and
##   strata where it is rock).
## - FADE: a tree in front of him dissolves in a dither (it stays opaque: no
##   sorting, it still takes shadows).
## Cheap on purpose: the home is pixel-bound on a weak GPU (CLAUDE.md).

const SHADER := "shader_type spatial;
render_mode specular_disabled;
uniform float fade = 1.0;
uniform float rim_k = 1.0;
uniform float ground = 0.0;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	if (fade < 0.999) {
		// a 4x4 dither: the tree dissolves, still opaque
		ivec2 q = ivec2(FRAGCOORD.xy) % 4;
		int idx = q.x + q.y * 4;
		float th = float((idx * 7 + (idx / 4) * 3) % 16) / 16.0 + 0.03;
		if (fade < th) {
			discard;
		}
	}
	vec3 c = COLOR.rgb;
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / (mx + 0.001);
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	if (sat < 0.2 && lum < 0.72 && lum > 0.12) {
		// STONE: strata that wander, speckles, light and dark patches
		float n = vnoise(wpos.xz * 1.1 + vec2(wpos.y * 0.7));
		float band = abs(fract(wpos.y * 1.8 + n * 0.7) - 0.5);
		c *= 1.0 - 0.2 * smoothstep(0.4, 0.48, band);
		c *= 0.9 + 0.2 * n;
		float sp = step(0.94, hash2(floor(wpos.xz * 7.0 + vec2(wpos.y * 7.0))));
		c = mix(c, c * 1.3, sp * 0.6);
	} else if (ground > 0.5) {
		// the GROUND: big soft patches, and brush strokes across them
		float big = vnoise(wpos.xz * 0.28);
		float stroke = vnoise(vec2(wpos.x * 3.2 + wpos.z * 1.1, wpos.z * 0.9 - wpos.x * 0.4));
		c *= 0.9 + 0.18 * big + 0.08 * (stroke - 0.5);
		c = mix(c, c * vec3(1.06, 1.04, 0.86), smoothstep(0.55, 0.85, big) * 0.5);
	} else if (c.g > c.r * 1.05 && c.g > c.b * 1.1) {
		// LEAVES: dappled, warmer where it's lit
		float n = vnoise(wpos.xz * 2.4 + vec2(wpos.y * 1.9));
		c = mix(c * 0.84, c * 1.14 + vec3(0.04, 0.05, 0.0), n);
	} else if (sat > 0.2 && lum < 0.5 && c.r > c.b) {
		// WOOD: a grain, a little wavy
		float g = sin((wpos.x * 1.7 + wpos.z * 1.3) * 13.0 + vnoise(wpos.xz * 2.5 + vec2(wpos.y * 0.6)) * 7.0);
		c *= 0.94 + 0.08 * g;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	if (rim_k > 0.0) {
		float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		ALBEDO *= 1.0 - rim_k * 0.38 * smoothstep(0.55, 0.92, rim);
	}
}
void light() {
	// flat bands, like the 2D art (and Ugu): shade, light, and a brighter top
	float d = dot(NORMAL, LIGHT);
	float band = 0.74 * (0.3 + 0.7 * (smoothstep(-0.03, 0.05, d) * 0.66 + smoothstep(0.42, 0.5, d) * 0.34));
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * band / PI;
}
"

static var _shader: Shader
static var _shared: ShaderMaterial
static var _ground: ShaderMaterial


static func _make() -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	return m


## The merged shapes' material (shared).
static func world() -> ShaderMaterial:
	if _shared == null:
		_shared = _make()
	return _shared


## The ground's (no rim: it would darken the distance; brush strokes).
static func ground() -> ShaderMaterial:
	if _ground == null:
		_ground = _make()
		_ground.set_shader_parameter("rim_k", 0.0)
		_ground.set_shader_parameter("ground", 1.0)
	return _ground


## A material of its own (a tree that fades in front of him: "fade" 0..1).
static func own() -> ShaderMaterial:
	return _make()
