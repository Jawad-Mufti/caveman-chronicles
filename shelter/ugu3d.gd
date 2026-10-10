extends Node3D
## UGU IN 3D, for the home (shelter/home.gd): his 2D self (common/player.gd) made
## solid, and a bit taller (longer legs and trunk; the same big head).
## Built from the 2D rig's own numbers: every feature of the face is placed from
## the rig's design units onto the head (_face), so the big eyes, the V of the
## heavy brows, the broad nose, the moustache over the open smile, the short jaw
## beard, the fringe of locks and the swept-back mane of spikes sit where they
## sit in 2D. His clothes are the sheet's: the fur tunic over one shoulder with
## the light trim, the jagged light hem, the rope belt and the pouch, the fang
## necklace, the leather forearm wraps, the fur calf wraps, big bare feet (the
## leaf skirt in era 1). His costume (GameState.skin) recolours the hide and adds
## its pieces; he carries his weapon (GameState.weapon).
## DRAWN LIKE THE 2D ART: flat toon light in two bands, and every part rimmed in
## a darker tone of its own fill, never black (a hull pass: OUTLINE).
## THE AIR: hair, fur, hems, cords and capes drag behind his motion, lift in a
## fall and flutter faster as he speeds up; done in the vertex shader (each
## vertex knows how loose it is: UV2), so every part of him is a handful of meshes.
## FACES, as in 2D: the open smile at rest, the tongue flapping on a run, "ooh"
## falling, a grin in a flip, a yawn and a stretch when he stands about; he blinks.
## MOVES: a run that keeps pace with the ground, a lean into the run and a bank
## into turns, a stride that grows on a sprint, jump and fall poses, a somersault
## (jumped(true)), a squash on landing (landed()); his head turns to look at
## `look_at_point`.
## The game sets `speed`, `sprint`, `air` (and `look_at_point`) every frame (his
## velocity he works out from how he moved) and calls `refresh()` after his
## costume or weapon changes. Feet at the origin, facing +Z.

const SKIN := Color("c98d63")
const SKIN_DARK := Color("a46a46")
const HAIR := Color("45302a")
const HAIR_HI := Color("6e4c3a")
const FUR := Color("7a4b36")
const FUR_LIGHT := Color("d9b08e")
const LEATHER := Color("8a5a3a")
const CORD := Color("3b2a22")
const FANG := Color("efe6d2")
const ROPE := Color("b98a5e")
const EYE := Color("ece3cd")
const LASH := Color("2a211a")
const MOUTH := Color("33211a")
const TONGUE := Color("d9675e")
const DARK := Color("1a0f08")
const WOOD := Color("846141")
const WOOD_DARK := Color("5a4029")
const STONE := Color("8d9196")
const LEAF := Color("6a8447")

## How a part is drawn (UV): x the rim's width (1 full, 0 none), y its look
## (0 toon shaded, 1 lit by itself, 2 fur strokes, 3.. skin with its muscles
## painted on: the trunk, the upper arm, the forearm, the thigh, the shin).
const PLAIN := Vector2(1, 0)
const FURRY := Vector2(1, 2)
const M_TRUNK := Vector2(1, 3)
const M_ARM := Vector2(1, 4)
const M_FOREARM := Vector2(1, 5)
const M_THIGH := Vector2(1, 6)
const M_SHIN := Vector2(1, 7)
const FINE := Vector2(0.45, 0)
const BARE := Vector2(0, 0)
const SHINE := Vector2(0, 1)

## The air on loose parts: UV2.x how far a vertex moves (0 its root .. 1 a free
## tip), UV2.y its own beat. `drag` is the air in this mesh's space.
const FLEX := "
uniform vec3 drag = vec3(0.0);
uniform vec3 flut = vec3(0.0);
uniform float flut_amp = 0.0;
vec3 flexed(vec3 v, vec2 f) {
	vec3 wave = vec3(sin(flut.x + f.y * 1.7) + 0.45 * sin(flut.y + f.y * 2.9), 0.5 * cos(flut.z + f.y * 2.3), cos(flut.x * 0.8 + f.y * 1.3));
	return v + (drag + wave * flut_amp) * f.x;
}
// THE JAW (the head's mesh): what lies below the mouth and in front swings
// down round a hinge by the ears when he opens his mouth
uniform float jaw = 0.0;
uniform float jaw_y = 0.0;
vec3 jawed(vec3 v) {
	if (jaw == 0.0) {
		return v;
	}
	float w = smoothstep(jaw_y + 0.012, jaw_y - 0.03, v.y) * smoothstep(0.1, 0.19, v.z);
	float a = jaw * 0.2 * w;
	vec2 r = vec2(v.y - (jaw_y + 0.03), v.z + 0.03);
	r = vec2(r.x * cos(a) - r.y * sin(a), r.x * sin(a) + r.y * cos(a));
	return vec3(v.x, r.x + jaw_y + 0.03, r.y - 0.03);
}
// THE LIDS (their own materials): only what lies past the lid's edge is drawn,
// the edge an arch (lid_dir 1: the upper lid, kept above; -1: the lower)
uniform float lid_dir = 0.0;
uniform float lid_cut = 0.0;
uniform float lid_bend = 6.0;
float lid_edge(vec3 p) {
	return (p.y - (lid_cut - lid_bend * p.x * p.x)) * lid_dir;
}
"
const BODY_SHADER := "shader_type spatial;
render_mode cull_back, specular_disabled;
" + FLEX + "
varying vec3 mpos;
varying float look;
void vertex() {
	mpos = VERTEX;
	VERTEX = jawed(flexed(VERTEX, UV2));
	look = UV.y;
}
// a brush stroke from a to b, its width w0 -> w1: how much of it covers p
float brush(vec2 p, vec2 a, vec2 b, float w0, float w1) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	float d = length(pa - ba * h);
	float w = mix(w0, w1, h);
	float aa = fwidth(d) * 0.75 + 1e-5;
	return 1.0 - smoothstep(w - aa, w + aa, d);
}
// his MUSCLES, painted like the 2D art: tapering strokes in a darker tone of
// the skin, mirrored left and right. On the limbs: (round the limb, down it).
float muscles(vec3 p, float kind) {
	float m = 0.0;
	if (kind < 3.5) {
		vec2 q = vec2(abs(p.x), p.y);
		if (p.z > 0.0) {
			// the pecs: the lower edge, a shade under it, the breastbone
			m = max(m, brush(q, vec2(0.02, 0.372), vec2(0.08, 0.343), 0.003, 0.0065));
			m = max(m, brush(q, vec2(0.08, 0.343), vec2(0.16, 0.335), 0.0065, 0.006));
			m = max(m, brush(q, vec2(0.16, 0.335), vec2(0.225, 0.352), 0.006, 0.004));
			m = max(m, brush(q, vec2(0.225, 0.352), vec2(0.272, 0.392), 0.004, 0.0));
			float yb = 0.335 + 1.9 * (q.x - 0.15) * (q.x - 0.15);
			m = max(m, 0.4 * step(q.y, yb) * smoothstep(0.035, 0.0, yb - q.y) * smoothstep(0.03, 0.08, q.x) * smoothstep(0.26, 0.2, q.x));
			m = max(m, brush(q, vec2(0.0, 0.47), vec2(0.0, 0.372), 0.0, 0.0035));
			// the collarbones
			m = max(m, brush(q, vec2(0.1, 0.562), vec2(0.2, 0.578), 0.0045, 0.0));
			// the abs: the middle line, three rows, the outer edges
			m = max(m, brush(q, vec2(0.0, 0.33), vec2(0.0, 0.08), 0.004, 0.002));
			for (int i = 0; i < 3; i++) {
				float y = 0.278 - float(i) * 0.07;
				m = max(m, brush(q, vec2(0.0, y), vec2(0.082, y + 0.012), 0.004, 0.0));
			}
			m = max(m, brush(q, vec2(0.092, 0.315), vec2(0.103, 0.22), 0.0, 0.005));
			m = max(m, brush(q, vec2(0.103, 0.22), vec2(0.094, 0.13), 0.005, 0.004));
			m = max(m, brush(q, vec2(0.094, 0.13), vec2(0.068, 0.07), 0.004, 0.0));
			// the ribs' fingers under his arms
			for (int i = 0; i < 3; i++) {
				float y = 0.345 - float(i) * 0.033;
				m = max(m, brush(q, vec2(0.252, y + 0.012), vec2(0.205, y - 0.01), 0.0035, 0.0));
			}
		} else {
			// his back: the spine, the shoulder blades
			m = max(m, brush(q, vec2(0.0, 0.52), vec2(0.0, 0.1), 0.0, 0.004));
			m = max(m, brush(q, vec2(0.07, 0.5), vec2(0.06, 0.42), 0.0, 0.004));
			m = max(m, brush(q, vec2(0.06, 0.42), vec2(0.1, 0.35), 0.004, 0.005));
			m = max(m, brush(q, vec2(0.1, 0.35), vec2(0.2, 0.37), 0.005, 0.0));
		}
		return m;
	}
	vec2 q = vec2(abs(atan(p.x, p.z)) * 0.095, p.y);
	if (kind < 4.5) {
		// the upper arm: the deltoid's V, the bicep, the bicep/tricep split
		m = max(m, brush(q, vec2(0.02, -0.02), vec2(0.075, -0.1), 0.0, 0.005));
		m = max(m, brush(q, vec2(0.075, -0.1), vec2(0.149, -0.172), 0.005, 0.006));
		m = max(m, brush(q, vec2(0.149, -0.172), vec2(0.22, -0.1), 0.006, 0.004));
		m = max(m, brush(q, vec2(0.22, -0.1), vec2(0.28, -0.03), 0.004, 0.0));
		m = max(m, brush(q, vec2(0.068, -0.125), vec2(0.042, -0.208), 0.0, 0.005));
		m = max(m, brush(q, vec2(0.042, -0.208), vec2(0.0, -0.232), 0.005, 0.005));
		m = max(m, brush(q, vec2(0.149, -0.19), vec2(0.152, -0.28), 0.005, 0.0));
	} else if (kind < 5.5) {
		// the forearm, under the elbow
		m = max(m, brush(q, vec2(0.075, 0.0), vec2(0.03, -0.085), 0.005, 0.0));
	} else if (kind < 6.5) {
		// the thigh: the teardrops over the knee
		m = max(m, brush(q, vec2(0.088, -0.19), vec2(0.078, -0.29), 0.0, 0.005));
		m = max(m, brush(q, vec2(0.078, -0.29), vec2(0.045, -0.338), 0.005, 0.0));
	} else {
		// the kneecap
		float d = abs(length(vec2(q.x, (q.y + 0.022) * 0.9)) - 0.034);
		float aa = fwidth(d) * 0.75 + 1e-5;
		m = (1.0 - smoothstep(0.004 - aa, 0.004 + aa, d)) * smoothstep(-0.012, -0.034, q.y);
	}
	return m;
}
void fragment() {
	vec3 c = COLOR.rgb;
	if (lid_dir != 0.0) {
		float e = lid_edge(mpos);
		if (e < 0.0) {
			discard;
		}
		c = mix(c, c * 0.42, 1.0 - smoothstep(0.003, 0.0055, e));      // the lash line along its edge
	}
	if (look > 2.5) {
		c = mix(c, c * vec3(0.66, 0.56, 0.52), clamp(muscles(mpos, look), 0.0, 1.0) * 0.85);
	} else if (look > 1.5) {
		// fur: short strokes in a darker tone, running down
		vec3 q = mpos * vec3(30.0, 11.0, 30.0);
		vec3 cell = floor(q);
		float h = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
		vec3 fq = fract(q) - 0.5;
		float s = smoothstep(0.16, 0.04, abs(fq.x * 0.8 + fq.z * 0.8 + fq.y * 0.3)) * step(0.68, h);
		c = mix(c, c * 0.55, s);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	if (look > 0.5 && look < 1.5) {
		EMISSION = c;
	}
}
void light() {
	// two flat bands, like the 2D art: shade, light, and a brighter top
	float d = dot(NORMAL, LIGHT);
	float band = 0.82 * (0.3 + 0.7 * (smoothstep(-0.04, 0.04, d) * 0.72 + smoothstep(0.5, 0.56, d) * 0.28));
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * band / PI;
}
"
## THE MOUTH: one shape with dials (`m_*`), made in the vertex shader. Its mesh
## is unit balls (UV2.x: which part: 0 the mouth, 1 the upper teeth, 2 the lower,
## 3 the tongue); each is laid between the lips' two edges, so whatever the
## dials say, the teeth and the tongue stay inside the lips.
const MOUTH_MAP := "
uniform float m_open = 0.3;
uniform float m_smile = 0.6;
uniform float m_wide = 0.0;
uniform float m_teeth = 1.0;
uniform float m_span = 0.55;
uniform float m_teeth_lo = 0.0;
uniform float m_tongue = 0.5;
uniform float m_smirk = 0.0;
float m_hw() {
	return 0.082 * clamp(1.0 + 0.35 * m_wide + 0.1 * max(m_smile, 0.0), 0.38, 1.5);
}
float m_corner(float s) {
	return 0.03 * m_smile + 0.018 * m_smirk * s;
}
float m_top(float s) {
	float k = pow(max(1.0 - s * s, 0.0), 0.5);
	return mix(m_corner(s), 0.006 + 0.014 * m_open, k);
}
float m_bot(float s) {
	float k = pow(max(1.0 - s * s, 0.0), 0.62);
	return mix(m_corner(s), -0.006 - 0.076 * m_open - 0.014 * max(m_smile, 0.0) + 0.008 * max(-m_smile, 0.0) * (1.0 - m_open), k);
}
vec3 m_place(vec3 u, float part) {
	float hw = m_hw();
	float t = clamp(u.y / max(sqrt(max(1.0 - u.x * u.x, 0.0)), 0.001), -1.0, 1.0) * 0.5 + 0.5;
	float s = u.x;
	float z0 = 0.016;
	float zr = 0.011;
	float y;
	if (part < 0.5) {
		y = mix(m_bot(s), m_top(s), t);
	} else {
		s = u.x * (part < 2.5 ? 0.78 : 0.48);
		float top = m_top(s);
		float bot = m_bot(s);
		float gap = max(top - bot - 0.004, 0.0);
		if (part < 1.5) {
			y = top - 0.002 - (1.0 - t) * min(0.017, gap * 0.5) * m_teeth;
		} else if (part < 2.5) {
			y = bot + 0.002 + t * min(0.014, gap * 0.4) * m_teeth_lo;
		} else {
			y = bot + 0.003 + t * min(0.022, gap * 0.45) * m_tongue;
		}
		z0 = 0.024;
		zr = 0.004;
	}
	float x = s * hw;
	return vec3(x, y, z0 + u.z * zr - 2.5 * x * x);
}
vec3 m_normal(vec3 u, float pt) {
	vec3 a = abs(u.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 t1 = normalize(cross(u, a));
	vec3 t2 = cross(u, t1);
	vec3 p = m_place(u, pt);
	vec3 n = cross(m_place(normalize(u + t1 * 0.03), pt) - p, m_place(normalize(u + t2 * 0.03), pt) - p);
	n = length(n) < 1e-9 ? u : normalize(n);
	return dot(n, vec3(u.x, u.y, u.z + 0.3)) < 0.0 ? -n : n;
}
"
const MOUTH_SHADER := "shader_type spatial;
render_mode cull_back, specular_disabled;
" + MOUTH_MAP + "
varying vec3 mpos;
varying float part;
void vertex() {
	part = UV2.x;
	vec3 u = VERTEX;
	VERTEX = m_place(u, part);
	NORMAL = m_normal(u, part);
	mpos = VERTEX;
}
void fragment() {
	vec3 c = COLOR.rgb;
	if (part > 0.5 && part < 2.5) {
		// the teeth: a row with lines between, the gap in the middle of the
		// upper ones; in his smile only the front ones show (m_span)
		float ax = abs(mpos.x);
		if (part < 1.5 && (ax < 0.0032 || ax > m_span * m_hw() * 0.78)) {
			discard;
		}
		float k = ax / 0.021;
		if (round(k) >= 1.0 && abs(k - round(k)) * 0.021 < 0.0013) {
			c *= 0.35;
		}
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
void light() {
	float d = dot(NORMAL, LIGHT);
	float band = 0.82 * (0.3 + 0.7 * (smoothstep(-0.04, 0.04, d) * 0.72 + smoothstep(0.5, 0.56, d) * 0.28));
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * band / PI;
}
"
const MOUTH_OUTLINE := "shader_type spatial;
render_mode cull_front, specular_disabled;
" + MOUTH_MAP + "
uniform float width = 0.009;
void vertex() {
	VERTEX = m_place(VERTEX, UV2.x) + m_normal(VERTEX, UV2.x) * width * UV.x;
}
void fragment() {
	ALBEDO = COLOR.rgb * 0.45;
	ROUGHNESS = 1.0;
}
void light() {
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * 0.55 / PI;
}
"
const OUTLINE_SHADER := "shader_type spatial;
render_mode cull_front, specular_disabled;
" + FLEX + "
uniform float width = 0.009;
varying vec3 mpos;
void vertex() {
	mpos = VERTEX;
	VERTEX = jawed(flexed(VERTEX, UV2) + NORMAL * width * UV.x);
}
void fragment() {
	if (lid_dir != 0.0 && lid_edge(mpos) < 0.0) {
		discard;
	}
	ALBEDO = COLOR.rgb * 0.45;
	ROUGHNESS = 1.0;
}
void light() {
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * 0.55 / PI;
}
"

static var _shader: Shader
static var _outline: Shader
static var _mouth_shader: Shader
static var _mouth_outline: Shader

## HIS FACE is a set of dials, each eased toward what his feeling wants by a
## spring (a little overshoot: alive, never snapping). The mouth (MOUTH_MAP):
## open, smile (-1 a frown .. 1), wide (-1 an "o" .. 1 stretched), teeth (the
## upper ones; span: how far along they show), teeth_lo, tongue, smirk (one
## corner up); the jaw drops with `open`. The brows: brow (up), knit (1 the
## angry V .. -1 worried), brow_l / brow_r (one up: a cocked brow). The eyes: lid
## (the upper lids down), squint (the lower lids up: happy eyes), pupil (its
## size). tilt: his head on one side.
const FACE_REST := {"open": 0.0, "smile": 0.0, "wide": 0.0, "teeth": 0.0, "span": 0.55, "teeth_lo": 0.0, "tongue": 0.0,
	"smirk": 0.0, "brow": 0.0, "knit": 0.0, "brow_l": 0.0, "brow_r": 0.0, "lid": 0.1, "squint": 0.0, "pupil": 1.0, "tilt": 0.0}
## His feelings (what each sets; the rest from FACE_REST). "smile" is his face
## at rest: the 2D open smile with the gap in his teeth and a bit of tongue.
const EXPRESSIONS := {
	"smile": {"open": 0.42, "smile": 0.6, "teeth": 1.0, "tongue": 0.6, "squint": 0.15},
	"happy": {"open": 0.55, "smile": 1.0, "wide": 0.2, "teeth": 1.0, "span": 0.8, "tongue": 0.5, "brow": 0.3, "knit": -0.2, "squint": 0.55},
	"grin": {"open": 0.45, "smile": 1.0, "wide": 0.5, "teeth": 1.0, "span": 1.0, "teeth_lo": 1.0, "brow": 0.25, "squint": 0.6},
	"laugh": {"open": 0.75, "smile": 1.0, "wide": 0.35, "teeth": 1.0, "span": 1.0, "tongue": 0.7, "brow": 0.45, "knit": -0.3, "lid": 0.55, "squint": 0.75, "tilt": 0.1},
	"whee": {"open": 0.7, "smile": 1.0, "wide": 0.45, "teeth": 1.0, "span": 1.0, "teeth_lo": 0.6, "tongue": 0.4, "brow": 0.75, "knit": -0.3, "lid": 0.0, "squint": 0.3},
	"tongue": {"open": 0.45, "smile": 0.8, "teeth": 1.0, "brow": 0.15, "squint": 0.3},
	"effort": {"open": 0.22, "smile": 0.3, "wide": 0.65, "teeth": 1.0, "span": 1.0, "teeth_lo": 1.0, "brow": -0.2, "knit": 0.65, "squint": 0.4},
	"ooh": {"open": 0.6, "wide": -1.45, "brow": 0.95, "knit": -0.35, "lid": 0.0, "pupil": 0.85},
	"scared": {"open": 0.95, "smile": -0.55, "wide": 0.35, "teeth": 1.0, "span": 1.0, "teeth_lo": 1.0, "brow": 1.0, "knit": -1.0, "lid": 0.0, "pupil": 0.72},
	"wince": {"open": 0.12, "smile": -0.35, "wide": 0.75, "teeth": 1.0, "span": 1.0, "teeth_lo": 1.0, "brow": -0.3, "knit": 0.85, "lid": 0.75, "squint": 0.65, "tilt": -0.06},
	"yawn": {"open": 1.0, "wide": -0.35, "tongue": 1.0, "brow": 0.7, "knit": -0.45, "lid": 0.85},
	"curious": {"open": 0.1, "smile": 0.25, "wide": -0.45, "smirk": 0.45, "brow": 0.2, "brow_l": 0.7, "brow_r": -0.2, "knit": -0.25, "lid": 0.0, "pupil": 1.1, "tilt": 0.12},
	"bored": {"smile": -0.1, "smirk": -0.5, "brow": -0.15, "lid": 0.5},
	"sleepy": {"open": 0.04, "smile": 0.15, "brow": 0.2, "knit": -0.3, "lid": 0.62},
	"sad": {"open": 0.08, "smile": -0.9, "wide": -0.2, "brow": 0.35, "knit": -1.0, "lid": 0.35, "pupil": 1.12, "tilt": -0.08},
	"angry": {"open": 0.85, "smile": -0.4, "wide": 0.8, "teeth": 1.0, "span": 1.0, "teeth_lo": 1.0, "brow": -0.5, "knit": 1.0, "squint": 0.35, "pupil": 0.8},
	"proud": {"smile": 0.9, "smirk": 0.5, "brow": 0.1, "brow_r": 0.3, "lid": 0.38, "squint": 0.4, "tilt": -0.07},
}

var speed := 0.0                        ## 0 standing .. 1 running (set by the game)
var sprint := 0.0                       ## 0 .. 1 flat out (set by the game)
var air := false
var era := 2
var look_at_point := Vector3.INF        ## where he looks (world); INF: he looks about
var vel := Vector3.ZERO                 ## his velocity (world), worked out from how he moved
var _last := Vector3.INF
var _t := 0.0
var _phase := 0.0
var _drag := Vector3.ZERO               ## the air on him, model space: a spring toward -velocity
var _drag_v := Vector3.ZERO
var _flut := Vector3.ZERO               ## the flutter's clocks (faster the faster he goes)
var _amp := 0.0
var _yaw_last := INF
var _bank := 0.0
var _air_k := 0.0
var _fall_k := 0.0
var _sq := 0.0                          ## the squash on landing (a spring; < 0 stretches)
var _sq_v := 0.0
var _flip := -1.0                       ## 0..1 through a somersault, -1: none
var _cheer := 0.0
var _idle := 0.0
var _look := Vector2.ZERO               ## the head's yaw, pitch
var _mood := ""
var face_mood := ""                     ## the feeling on his face now (read only; emote() sets one)
var sleepy := 0.0                       ## 0 .. 1 drowsy (the game sets it: night)
var _dial := {}                         ## THE FACE: each dial now, and its speed (springs)
var _dial_v := {}
var _mood_t := 0.0
var _emote := ""
var _emote_t := 0.0
var _wince := 0.0
var _fall_t := 0.0
var _curious := 0.0
var _looked := false
var _blink := 1.0                       ## 0 .. 1 through a blink (1: none)
var _blink_in := 2.0
var _blinks := 0
var _gaze := Vector2.ZERO               ## where the eyes point (-1 .. 1 across, down .. up)
var _gaze_to := Vector2.ZERO
var _gaze_in := 1.0
var _quirk := ""                        ## a passing look on an idle face
var _quirk_t := 0.0
var _quirk_in := 4.0
var _rng := RandomNumberGenerator.new()

var _sqn: Node3D                        ## the squash (at his feet)
var _root: Node3D                       ## the lean, the bank, the somersault (at his middle)
var _hips: Node3D
var _body: Node3D
var _head: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D
var _foot_l: Node3D
var _foot_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _elbow_l: Node3D
var _elbow_r: Node3D
var _hand_r: Node3D
var _skirt: Array = []                  ## the skirt's panels: front, +X, back, -X (pivots at the belt)
var _brows: Array = []                  ## [node, rest position, face frame, side] each
var _lids: Array = []                   ## the lids' materials: -X upper, lower, +X upper, lower
var _irises: Array = []                 ## [node, rest position, eye frame] each
var _mouth: Node3D
var _m_mouth: ShaderMaterial
var _jaw_y := 0.0
var _tongue: Node3D
var _hair: MeshInstance3D
var _extras: Array = []                 ## era / costume / weapon meshes, rebuilt by refresh()
var _flexers: Array = []                ## [material, the node whose space it is in]
var _m_still: ShaderMaterial
var _m_head: ShaderMaterial
var _m_body: ShaderMaterial
var _m_hips: ShaderMaterial
var _m_knee_l: ShaderMaterial
var _m_knee_r: ShaderMaterial


## A mesh being modelled: vertices with a colour, how they are drawn (UV) and
## how loose they are (UV2).
class Lump:
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var cs := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var ix := PackedInt32Array()

	## A grid: `rows` of points (closed: each row a ring). Normals from the
	## neighbours, turned away from each row's centre. `flex[i]`: how far row i
	## moves in the air.
	func grid(rows: Array, centres: PackedVector3Array, closed: bool, col: Color, look: Vector2, flex: PackedFloat32Array, phase: float) -> void:
		var nr := rows.size()
		var nc := (rows[0] as PackedVector3Array).size()
		var base := vs.size()
		var lin := col                  # (vertex colours are taken as they are: the 2D palette)
		for i in nr:
			var row: PackedVector3Array = rows[i]
			var up: PackedVector3Array = rows[mini(i + 1, nr - 1)]
			var dn: PackedVector3Array = rows[maxi(i - 1, 0)]
			var f: float = flex[i] if i < flex.size() else 0.0
			for j in nc:
				var jm := posmod(j - 1, nc) if closed else maxi(j - 1, 0)
				var jp := (j + 1) % nc if closed else mini(j + 1, nc - 1)
				var p := row[j]
				var out := p - centres[i]
				var nm := (up[j] - dn[j]).cross(row[jp] - row[jm])
				if nm.length_squared() < 1e-14:
					nm = out
				if nm.dot(out) < 0.0:
					nm = -nm
				vs.append(p)
				ns.append(nm.normalized())
				cs.append(lin)
				uvs.append(look)
				uv2s.append(Vector2(f, phase))
		for i in nr - 1:
			for j in (nc if closed else nc - 1):
				var j1 := (j + 1) % nc
				var a := base + i * nc + j
				var b := base + i * nc + j1
				var c := base + (i + 1) * nc + j1
				var d := base + (i + 1) * nc + j
				_tri(a, b, c)
				_tri(a, c, d)

	## Front faces wind clockwise (Godot): turned to face along the normals.
	func _tri(a: int, b: int, c: int) -> void:
		var fn := (vs[b] - vs[a]).cross(vs[c] - vs[a])
		if fn.length_squared() < 1e-16:
			return
		if fn.dot(ns[a] + ns[b] + ns[c]) > 0.0:
			ix.append_array(PackedInt32Array([a, c, b]))
		else:
			ix.append_array(PackedInt32Array([a, b, c]))

	func commit() -> ArrayMesh:
		if ix.is_empty():
			return null
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = vs
		arr[Mesh.ARRAY_NORMAL] = ns
		arr[Mesh.ARRAY_COLOR] = cs
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_TEX_UV2] = uv2s
		arr[Mesh.ARRAY_INDEX] = ix
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m


func _ready() -> void:
	_m_still = _new_mat()
	_m_head = _new_mat()
	_m_body = _new_mat()
	_m_hips = _new_mat()
	_m_knee_l = _new_mat()
	_m_knee_r = _new_mat()
	_sqn = _node(Vector3.ZERO, self)
	_root = _node(Vector3(0, 0.95, 0), _sqn)
	_hips = _node(Vector3(0, -0.17, 0), _root)
	_body = _node(Vector3.ZERO, _hips)
	_build_legs()
	_build_torso()
	_build_arms()
	_build_head()
	_flexers = [[_m_head, _head], [_m_body, _body], [_m_hips, _hips], [_m_knee_l, _knee_l], [_m_knee_r, _knee_r]]
	refresh()


## ------------------------------------------------------------------ the body
func _build_legs() -> void:
	for side: float in [-1.0, 1.0]:
		var leg := _node(Vector3(side * 0.13, 0, 0), _hips)
		var l := Lump.new()
		_limb(l, Vector3(0, 0.02, 0), Vector3(0, -0.35, 0), 0.112, 0.086, SKIN, M_THIGH)         # thigh
		_mesh(l, leg, _m_still)
		var knee := _node(Vector3(0, -0.35, 0), leg)
		var k := Lump.new()
		_limb(k, Vector3.ZERO, Vector3(0, -0.31, 0), 0.084, 0.062, SKIN, M_SHIN)                # shin
		_ball(k, Vector3(0, -0.1, -0.03), Vector3(0.072, 0.1, 0.066), SKIN)                    # calf
		# the fur calf wrap, tied with cord, a ragged top that moves in the air
		_tube(k, _line(Vector3(0, -0.12, -0.004), Vector3(0, -0.29, 0.0), 4), PackedFloat32Array([0.088, 0.086, 0.078, 0.071]), FUR, FURRY, 0.0, 0.0, 12)
		for y: float in [-0.17, -0.25]:
			_ring(k, Vector3(0, y, -0.002), Vector2(0.088 - (-y - 0.12) * 0.1, 0.088 - (-y - 0.12) * 0.1), 0.009, CORD, FINE)
		for t in 7:
			var a := t * TAU / 7.0 + 0.3
			var root := Vector3(sin(a) * 0.084, -0.13, cos(a) * 0.084 - 0.004)
			_tube(k, PackedVector3Array([root, root + Vector3(sin(a) * 0.012, 0.035, cos(a) * 0.012), root + Vector3(sin(a) * 0.02, 0.06, cos(a) * 0.02)]),
				PackedFloat32Array([0.022, 0.014, 0.0]), FUR.darkened(0.15), FINE, 0.5, side * 3.0 + t, 5)
		_mesh(k, knee, _m_knee_l if side < 0.0 else _m_knee_r)
		# the big bare foot, toes forward
		var foot := _node(Vector3(0, -0.31, 0), knee)
		var f := Lump.new()
		_ball(f, Vector3(0, -0.055, 0.055), Vector3(0.085, 0.056, 0.15), SKIN)
		_ball(f, Vector3(0, -0.035, -0.04), Vector3(0.07, 0.06, 0.07), SKIN)                  # the heel
		for t2 in 5:
			var tx := side * (-0.05 + t2 * 0.025)
			_ball(f, Vector3(tx, -0.07, 0.19 - absf(t2 - 1.0) * 0.008), Vector3(0.017, 0.016, 0.02) * (1.25 if t2 == 0 else 1.0), SKIN, FINE)
		_mesh(f, foot, _m_still)
		if side < 0.0:
			_leg_l = leg
			_knee_l = knee
			_foot_l = foot
		else:
			_leg_r = leg
			_knee_r = knee
			_foot_r = foot


## His trunk, up from the hips (body space): [height, half width, half depth].
const TORSO := [[-0.1, 0.215, 0.16], [0.06, 0.235, 0.17], [0.18, 0.245, 0.17], [0.3, 0.285, 0.185],
	[0.4, 0.315, 0.2], [0.48, 0.325, 0.195], [0.55, 0.28, 0.17], [0.6, 0.17, 0.12], [0.635, 0.08, 0.07]]


func _torso_r(y: float) -> Vector2:
	for i in TORSO.size() - 1:
		var a: Array = TORSO[i]
		var b: Array = TORSO[i + 1]
		if y <= float(b[0]) or i == TORSO.size() - 2:
			var q := smoothstep(float(a[0]), float(b[0]), y)
			return Vector2(lerpf(a[1], b[1], q), lerpf(a[2], b[2], q))
	return Vector2(0.08, 0.07)


## A point of his trunk at height `y`, round at `ang` (0: the front, + toward +X).
func _torso_at(y: float, ang: float, inflate := 1.0) -> Vector3:
	var r := _torso_r(y) * inflate
	var front := maxf(cos(ang), 0.0)
	var pec := 0.04 * exp(-pow((y - 0.42) / 0.075, 2)) * front * front * (1.0 - 0.7 * exp(-pow(sin(ang) / 0.14, 2)))
	return Vector3(sin(ang) * r.x, y, cos(ang) * r.y + pec * inflate)


func _build_torso() -> void:
	var l := Lump.new()
	var rows := []
	var cen := PackedVector3Array()
	for i in 21:
		var y := lerpf(-0.1, 0.635, i / 20.0)
		var row := PackedVector3Array()
		for j in 32:
			row.append(_torso_at(y, TAU * j / 32.0))
		rows.append(row)
		cen.append(Vector3(0, y, 0))
	var top := PackedVector3Array()
	top.resize(32)
	top.fill(Vector3(0, 0.66, 0))
	rows.append(top)
	cen.append(Vector3(0, 0.6, 0))
	l.grid(rows, cen, true, SKIN, M_TRUNK, PackedFloat32Array(), 0.0)
	_mesh(l, _body, _m_body)


func _build_arms() -> void:
	for side: float in [-1.0, 1.0]:
		var arm := _node(Vector3(side * 0.37, 0.49, 0), _body)
		var l := Lump.new()
		_ball(l, Vector3(0, -0.02, 0), Vector3(0.12, 0.12, 0.115), SKIN, M_ARM)              # shoulder
		_limb(l, Vector3(0, -0.04, 0), Vector3(0, -0.3, 0), 0.095, 0.078, SKIN, M_ARM)       # upper arm
		_ball(l, Vector3(0, -0.14, 0.035), Vector3(0.076, 0.09, 0.064), SKIN, M_ARM)         # bicep
		_ball(l, Vector3(0, -0.16, -0.03), Vector3(0.074, 0.095, 0.06), SKIN, M_ARM)          # tricep
		_mesh(l, arm, _m_still)
		var elbow := _node(Vector3(0, -0.3, 0), arm)
		var e := Lump.new()
		_limb(e, Vector3.ZERO, Vector3(0, -0.25, 0.01), 0.082, 0.066, SKIN, M_FOREARM)        # forearm
		_ball(e, Vector3(0, -0.055, 0.008), Vector3(0.09, 0.075, 0.085), SKIN, M_FOREARM)   # its swell under the elbow
		# the leather wrap and the cords across it
		_tube(e, _line(Vector3(0, -0.09, 0.002), Vector3(0, -0.23, 0.008), 3), PackedFloat32Array([0.088, 0.083, 0.076]), LEATHER, PLAIN, 0.0, 0.0, 12)
		for t in 3:
			var y := -0.115 - t * 0.05
			_ring(e, Vector3(0, y, 0.004), Vector2(0.088, 0.088) - Vector2.ONE * t * 0.004, 0.007, LEATHER.darkened(0.4), BARE)
		# the big round fist
		var hand := _node(Vector3(0, -0.3, 0.012), elbow)
		_ball(e, Vector3(0, -0.3, 0.012), Vector3(0.078, 0.085, 0.082), SKIN)
		_ball(e, Vector3(-side * 0.045, -0.27, 0.05), Vector3(0.03, 0.04, 0.03), SKIN, FINE)  # the thumb
		_mesh(e, elbow, _m_still)
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
## same head a little bigger, cut along curves, so they hug him.
const HEAD_C := Vector3(0, 0.26, 0.03)
const HEAD_R := Vector3(0.208, 0.25, 0.212)
## The 2D head (design units): its middle, half its height, half its width, and
## its centre line (the face is drawn a little toward his facing).
const FACE_MID := -153.5
const FACE_HALF_H := 32.5
const FACE_HALF_W := 26.0
const FACE_X := 4.0


## The point of his head at latitude `lat` (up +) and longitude `lon` (0: the
## front, + toward +X), pushed out by `inflate`.
func _head_point(lat: float, lon: float, inflate := 1.0) -> Vector3:
	var d := Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))
	var p := d * HEAD_R
	var front := maxf(d.z, 0.0)
	if d.y < 0.0:
		p.x *= 1.0 + 0.17 * (-d.y)                           # the wide jaw
		p.y *= 1.0 - 0.07 * d.y * d.y                         # squared off underneath
		p.z += 0.05 * (-d.y) * front * front                  # the chin forward
		# the CHIN: a squared block under the mouth, out and down
		var chin := exp(-pow((d.y + 0.86) / 0.17, 2)) * smoothstep(0.15, 0.55, d.z) * exp(-pow(d.x / 0.42, 4))
		p += Vector3(0, -0.045, 0.072) * chin
	p.z += 0.022 * exp(-pow((d.y - 0.3) / 0.11, 2)) * front * front        # the brow ridge
	p += Vector3(signf(d.x) * 0.012, 0, 0.01) * exp(-pow(d.y / 0.13, 2) - pow((absf(d.x) - 0.6) / 0.2, 2))   # cheekbones
	return HEAD_C + p * inflate


## Where a point of the 2D face (design units, x from its centre line) lies on the head.
func _face_ll(x: float, y: float) -> Vector2:
	var lat := asin(clampf((FACE_MID - y) / FACE_HALF_H, -0.999, 0.999))
	var lon := asin(clampf(x / FACE_HALF_W / maxf(cos(lat), 0.3), -0.999, 0.999))
	return Vector2(lat, lon)


func _face(x: float, y: float, inflate := 1.0) -> Vector3:
	var ll := _face_ll(x, y)
	return _head_point(ll.x, ll.y, inflate)


## The head's surface at a 2D face point: x across (+X), y up it, z out of it.
func _face_frame(x: float, y: float) -> Basis:
	var ll := _face_ll(x, y)
	var p := _head_point(ll.x, ll.y)
	var ax := (_head_point(ll.x, ll.y + 0.01) - p).normalized()
	var ay := _head_point(ll.x + 0.01, ll.y) - p
	var az := ax.cross(ay).normalized()
	return Basis(ax, az.cross(ax), az)


## A shell of the head pushed out by `inflate`: for each longitude from lon0 to
## lon1, from latitude span(lon).x up to span(lon).y. The rows follow the span,
## so a cut edge (the jawline, the hairline) is a smooth curve.
func _shell(l: Lump, inflate: float, lon0: float, lon1: float, closed: bool, span: Callable, col: Color, look: Vector2, rings := 18, segs := 48) -> void:
	var rows := []
	var cen := PackedVector3Array()
	for i in rings + 1:
		var row := PackedVector3Array()
		for j in segs:
			var lon := lerpf(lon0, lon1, float(j) / (segs if closed else segs - 1))
			var s: Vector2 = span.call(lon)
			row.append(_head_point(lerpf(s.x, s.y, float(i) / rings), lon, inflate))
		rows.append(row)
		cen.append(HEAD_C)
	l.grid(rows, cen, closed, col, look, PackedFloat32Array(), 0.0)


## The beard's top edge: under the mouth at the front, up the jaw beside it, up
## the sides as sideburns to the ears; nothing round the back.
func _beard_top(lon: float) -> float:
	var s := absf(sin(lon))
	var top := lerpf(-0.72, -0.42, smoothstep(0.12, 0.7, s))
	top = lerpf(top, -0.04, smoothstep(0.9, 0.99, s))                 # the sideburns, up to the ears
	return lerpf(top, -1.5, smoothstep(0.0, 0.35, -cos(lon)))


## The hair's edge: the forehead (the fringe hangs from it), down the temples to
## above the ears, round the back to the nape.
func _hairline(lon: float) -> float:
	var c := cos(lon)
	if c > 0.25:
		return lerpf(0.0, 0.56, smoothstep(0.25, 0.8, c))
	return lerpf(-0.8, 0.0, smoothstep(-0.9, 0.25, c))


func _build_head() -> void:
	_head = _node(Vector3(0, 0.585, 0.01), _body)
	var l := Lump.new()
	_limb(l, Vector3(0, -0.06, -0.01), Vector3(0, 0.14, 0.0), 0.105, 0.1, SKIN, PLAIN, 14)    # the neck
	_shell(l, 1.0, -PI, PI, true, func(_lo): return Vector2(-PI * 0.5, PI * 0.5), SKIN, PLAIN, 22, 48)
	# ears, half in the hair
	for side: float in [-1.0, 1.0]:
		# a flat shell tipped back, a rolled rim, the hollow and the lobe
		var ear := _head_point(-0.06, side * 1.5, 0.985)
		var eb := Basis(Vector3.UP, side * 0.35) * Basis(Vector3.RIGHT, -0.2)
		_ball(l, ear, Vector3(0.026, 0.052, 0.038), SKIN, PLAIN, eb)
		_ball(l, ear + eb * Vector3(side * 0.012, 0.006, 0.0), Vector3(0.01, 0.03, 0.02), SKIN_DARK, BARE, eb)
		_ball(l, ear + eb * Vector3(side * 0.006, -0.042, 0.004), Vector3(0.016, 0.017, 0.016), SKIN, FINE, eb)
	# the BEARD: short and thick round the jaw and chin, up the sides as sideburns,
	# a ragged edge at the chin, lighter strands in it
	var beard := HAIR.lerp(FUR, 0.35)
	_shell(l, 1.085, -2.0, 2.0, false, func(lo): return Vector2(-PI * 0.5 + 0.02, _beard_top(lo)), beard, PLAIN, 14, 44)
	_ball(l, _head_point(-1.0, 0.0, 1.0), Vector3(0.085, 0.032, 0.05), beard)                # fuller on the chin
	for k in 4:
		var bx := -9.0 + k * 6.0
		var root := _face(bx, -122.0, 1.06)
		var fr := _face_frame(bx, -124.0)
		_tube(l, PackedVector3Array([root, root + fr * Vector3(0, -0.02, 0.008), root + fr * Vector3(0, -0.04, 0.0)]), PackedFloat32Array([0.022, 0.015, 0.0]), beard, PLAIN, 0.25, k * 1.3, 6)
	for k in 5:
		var sx := -10.0 + k * 5.0
		var s0 := _face(sx, -128.0 + absf(sx) * 0.2, 1.1)
		var s1 := _face(sx - 0.7, -122.0 + absf(sx) * 0.25, 1.1)
		_tube(l, PackedVector3Array([s0, s0.lerp(s1, 0.5), s1]), PackedFloat32Array([0.003, 0.0045, 0.002]), HAIR_HI, BARE, 0.0, 0.0, 4)
	# the MOUSTACHE over the lip, its ends running down into the beard
	var mo := PackedVector3Array()
	var mr := PackedFloat32Array()
	var mx := [-15.5, -14.0, -12.0, -5.0, 0.0, 5.0, 12.0, 14.0, 15.5]
	var my := [-130.0, -133.5, -138.5, -142.0, -140.5, -142.0, -138.5, -133.5, -130.0]
	var mrr := [0.0, 0.015, 0.023, 0.027, 0.022, 0.027, 0.023, 0.015, 0.0]
	for k in mx.size():
		mo.append(_face(mx[k], my[k], 1.1))
		mr.append(mrr[k])
	_tube(l, mo, mr, HAIR, PLAIN, 0.06, 2.0, 8, 0.7, _face_frame(0, -140).z)
	# the NOSE: a straight bridge, a broad rounded tip, the nostrils in shadow
	var nf := _face_frame(0, -146)
	var nose_col := SKIN.darkened(0.06)
	var tip := _face(0, -145.0, 1.0) + nf.z * 0.033
	_tube(l, PackedVector3Array([_face(0, -160.0, 0.98), _face(0, -154.0, 1.0) + nf.z * 0.012, tip + nf.y * 0.012]), PackedFloat32Array([0.02, 0.024, 0.03]), nose_col, PLAIN, 0.0, 0.0, 10)
	_ball(l, tip, Vector3(0.045, 0.036, 0.038), nose_col, PLAIN, nf)
	for side2: float in [-1.0, 1.0]:
		_ball(l, tip + nf * Vector3(side2 * 0.04, -0.008, -0.02), Vector3(0.027, 0.025, 0.026), nose_col, PLAIN, nf)
		_ball(l, tip + nf * Vector3(side2 * 0.02, -0.03, -0.002), Vector3(0.011, 0.006, 0.012), SKIN.darkened(0.5), BARE, nf)
	# the EYES: big and clear, white, a warm brown iris, a pupil, two glints, a
	# lash line along the top swept out at the outer corner. The iris (with its
	# pupil and glints) is a node of its own, so he can look about; the lids
	# (upper and lower) close as far as his face wants (_set_face)
	for side3: float in [-1.0, 1.0]:
		var ex: float = side3 * 11.0
		var fb := _face_frame(ex, -150.0)
		var ec := _face(ex, -150.0, 0.985)
		_ball(l, ec, Vector3(0.048, 0.041, 0.022), EYE, FINE, fb)
		var ic := ec + fb * Vector3(-side3 * 0.003, -0.002, 0.016)
		var iris := _node(ic, _head)
		iris.basis = fb
		var il := Lump.new()
		_ball(il, Vector3.ZERO, Vector3(0.028, 0.028, 0.009), Color("4a2a14"), BARE)
		_ball(il, Vector3(0, 0, 0.003), Vector3(0.022, 0.022, 0.008), Color("8a5426"), BARE)
		_ball(il, Vector3(0, 0, 0.006), Vector3(0.012, 0.012, 0.006), DARK, BARE)
		_ball(il, Vector3(-0.009, 0.01, 0.011), Vector3(0.0075, 0.0075, 0.004), Color.WHITE, SHINE)
		_ball(il, Vector3(0.011, -0.01, 0.01), Vector3(0.0035, 0.0035, 0.003), Color.WHITE, SHINE)
		_mesh(il, iris, _m_still).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_irises.append([iris, ic, fb])
		var lash := PackedVector3Array()
		var lr := PackedFloat32Array()
		for k2 in 7:
			var a := lerpf(PI * 0.95, PI * 0.08, k2 / 6.0)
			lash.append(ec + fb * Vector3(side3 * cos(a) * 0.05, sin(a) * 0.043, 0.012))
			lr.append(0.0055)
		lash.append(ec + fb * Vector3(side3 * 0.064, 0.03, 0.012))
		lr.append(0.0)
		_tube(l, lash, lr, LASH, BARE, 0.0, 0.0, 5)
		# the lids: a shell over the eye each, cut along an arch (the shader)
		for upper in [true, false]:
			var lid := _node(ec, _head)
			lid.basis = fb
			var ld := Lump.new()
			_ball(ld, Vector3(0, 0, 0.007), Vector3(0.053, 0.046, 0.026), SKIN if upper else SKIN.lightened(0.04), BARE)
			var lm := _new_mat()
			for p in [lm, lm.next_pass]:
				(p as ShaderMaterial).set_shader_parameter("lid_dir", 1.0 if upper else -1.0)
				(p as ShaderMaterial).set_shader_parameter("lid_bend", 6.0 if upper else 11.0)
				(p as ShaderMaterial).set_shader_parameter("lid_cut", 0.05 if upper else -0.05)
			_mesh(ld, lid, lm).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_lids.append(lm)
	_mesh(l, _head, _m_head)
	_jaw_y = _face(0, -135.0).y
	for p in [_m_head, _m_head.next_pass]:
		(p as ShaderMaterial).set_shader_parameter("jaw_y", _jaw_y)
	_build_brows()
	_build_mouth()


## The heavy brows (the sheet): thick by the nose, angled down to it (the scowl).
## One node each, at its middle, so each can lift and tilt on its own.
func _build_brows() -> void:
	for side: float in [-1.0, 1.0]:
		var pivot := _face(side * 14.0, -160.0, 1.035)
		var fr := _face_frame(side * 14.0, -160.0)
		var n := _node(pivot, _head)
		var l := Lump.new()
		var a := Vector2(side * 3.0, -156.0)
		var b := Vector2(side * 25.0, -163.0)
		var mid := (a + b) * 0.5 + Vector2(0, -3.0)
		var path := PackedVector3Array([_face(side * 1.2, -155.6, 1.035) - pivot])
		var radii := PackedFloat32Array([0.0])
		for i in 7:
			var q := i / 6.0
			var p := a.lerp(mid, q).lerp(mid.lerp(b, q), q)
			path.append(_face(p.x, p.y, 1.035) - pivot)
			radii.append(lerpf(0.036, 0.025, q) * (1.0 - 0.25 * pow(q, 4.0)))
		path.append(_face(side * 27.5, -163.5, 1.02) - pivot)
		radii.append(0.0)
		_tube(l, path, radii, HAIR, PLAIN, 0.0, 0.0, 8, 0.55, fr.z)
		_mesh(l, n, _m_still).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_brows.append([n, pivot, fr, side])


## His MOUTH: one shape the face's dials bend (MOUTH_SHADER): the mouth, the
## upper teeth (the gap in the middle), the lower, the tongue. The tongue out of
## the corner (on a run) is its own, flapping.
func _build_mouth() -> void:
	var fr := _face_frame(0, -133.5)
	var l := Lump.new()
	var parts := [[MOUTH, FINE, 10, 24], [EYE, BARE, 6, 18], [EYE, BARE, 6, 18], [TONGUE, BARE, 6, 14]]
	for i in parts.size():
		var from := l.vs.size()
		_ball(l, Vector3.ZERO, Vector3.ONE, parts[i][0], parts[i][1], Basis.IDENTITY, parts[i][2], parts[i][3])
		for v in range(from, l.vs.size()):
			l.uv2s[v] = Vector2(i, 0)
	if _mouth_shader == null:
		_mouth_shader = Shader.new()
		_mouth_shader.code = MOUTH_SHADER
		_mouth_outline = Shader.new()
		_mouth_outline.code = MOUTH_OUTLINE
	_m_mouth = ShaderMaterial.new()
	_m_mouth.shader = _mouth_shader
	var o := ShaderMaterial.new()
	o.shader = _mouth_outline
	_m_mouth.next_pass = o
	_mouth = _node(_face(0, -133.5, 1.0) + fr.z * 0.012, _head)
	_mouth.basis = fr
	_mesh(l, _mouth, _m_mouth).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tongue = _node(Vector3(0.045, -0.012, 0.03), _mouth)
	var tg := Lump.new()
	_tube(tg, PackedVector3Array([Vector3.ZERO, Vector3(0.022, -0.012, 0.014), Vector3(0.04, -0.035, 0.02), Vector3(0.046, -0.052, 0.018)]),
		PackedFloat32Array([0.016, 0.019, 0.016, 0.0]), Color("e0707a"), FINE, 0.0, 0.0, 8, 0.55, Vector3(0, 0, 1))
	_mesh(tg, _tongue, _m_still).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tongue.visible = false


## The hair: the cap (a shell of the head from the hairline up), the fringe of
## locks over the forehead, tufts off the crown, and the wild mane: two layers
## of swept-back spikes round the top and back. Everything but the cap moves in
## the air. Under a hood only the back of the mane shows.
func _build_hair(hooded: bool) -> void:
	if _hair != null:
		_hair.queue_free()
	var l := Lump.new()
	_shell(l, 1.075, -PI, PI, true, func(lo): return Vector2(_hairline(lo), PI * 0.5), HAIR, PLAIN, 14, 48)
	if not hooded:
		# the fringe: locks from the hairline over the forehead, tips flicking
		# aside (the 2D rig's FRINGE_LOCKS: root right x, root left x, tip, bend)
		var locks := [[32.0, 23.0, Vector2(31, -155), 4.0], [24.0, 15.0, Vector2(21, -163.5), -3.0],
			[16.0, 6.0, Vector2(9, -162), -4.0], [7.0, -3.0, Vector2(0, -164), -3.0], [-2.0, -12.0, Vector2(-11, -162), -4.0],
			[-11.0, -24.0, Vector2(-22, -154), -3.0]]
		var li := 0
		for lk in locks:
			var root := Vector2((float(lk[0]) + float(lk[1])) * 0.5 - FACE_X, -175.0)
			var tip: Vector2 = (lk[2] as Vector2) - Vector2(FACE_X, 0)
			var ctrl := root.lerp(tip, 0.5) + Vector2(float(lk[3]) * 0.5, 0)
			var w := absf(float(lk[0]) - float(lk[1])) * 0.5 * HEAD_R.y / FACE_HALF_H * 1.15
			var path := PackedVector3Array()
			var radii := PackedFloat32Array()
			for i in 5:
				var q := i / 4.0
				var p := root.lerp(ctrl, q).lerp(ctrl.lerp(tip, q), q)
				path.append(_face(p.x, p.y, 1.085 + 0.01 * q))
				radii.append(w * (1.0 - q * 0.92) if i < 4 else 0.0)
			_tube(l, path, radii, HAIR if li % 2 == 0 else HAIR.lightened(0.06), PLAIN, 0.5, li * 1.1, 8, 0.45, (path[1] - HEAD_C).normalized())
			li += 1
		# tufts curling up off the crown
		for k in 4:
			var lon := lerpf(-0.75, 0.75, k / 3.0)
			var base := _head_point(1.12, lon, 1.06)
			var side := Vector3(cos(lon), 0, -sin(lon))
			var curl := signf(lon) if absf(lon) > 0.1 else 1.0
			_tube(l, PackedVector3Array([base, base + Vector3(0, 0.055, -0.01) + side * 0.015 * curl, base + Vector3(0, 0.1, -0.05) + side * 0.045 * curl]),
				PackedFloat32Array([0.034, 0.024, 0.0]), HAIR, PLAIN, 0.65, 7.0 + k, 7, 0.5, side)
	# the MANE: spikes swept back off the head, darker longer ones behind, and
	# lighter ones over them
	var mc := HEAD_C + Vector3(0, 0.04, -0.05)
	var n := 0
	for layer in 2:
		var angs: Array = [50.0, 76.0, 101.0, 126.0, 151.0, 176.0, 200.0, 224.0, 247.0] if layer == 0 else [63.0, 89.0, 114.0, 139.0, 164.0, 188.0, 212.0, 236.0]
		for ai in angs.size():
			var ad: float = angs[ai]
			if hooded and ad < 150.0:
				continue
			var spreads: Array
			if layer == 0:
				spreads = [-60.0, -21.0, 21.0, 60.0] if ad > 80.0 else [-26.0, 26.0]
			else:
				spreads = [-41.0, 0.0, 41.0] if ad > 80.0 else [0.0]
			for si in spreads.size():
				var s := deg_to_rad(spreads[si])
				var a := deg_to_rad(ad)
				var dir := Vector3(sin(s) * 0.92, sin(a), cos(a) * cos(s)).normalized()
				var across := Vector3(cos(s), 0, -sin(s))
				var r := (0.4 if layer == 0 else 0.35) + 0.07 * float((ai * 7 + si * 3 + layer) % 5) / 4.0
				if ad < 80.0:
					r *= 0.8
				elif ad > 220.0:
					r *= 0.88
				var sweep := Vector3(0, 0.03, -0.08) * (r - 0.15) / 0.25
				var root := mc + dir * 0.15
				var path := PackedVector3Array([root, mc + dir * lerpf(0.15, r, 0.4), mc + dir * lerpf(0.15, r, 0.75) + sweep * 0.45, mc + dir * r + sweep])
				var k := 1.0 if layer == 0 else 0.85
				var col := HAIR.darkened(0.1) if layer == 0 else HAIR.lightened(0.05)
				if (n % 3) == 1 and layer == 1:
					col = HAIR_HI.lerp(HAIR, 0.3)
				_tube(l, path, PackedFloat32Array([0.07 * k, 0.06 * k, 0.036 * k, 0.0]), col, PLAIN, 0.75 + 0.3 * (r - 0.3) / 0.15, n * 0.37, 7, 0.5, dir.cross(across))
				n += 1
	_hair = _mesh(l, _head, _m_head)


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
	return [FUR, FUR.darkened(0.4)]


## The tunic's cut: high over his -X shoulder, down across the chest to the +X hip.
func _tunic_cut(x: float) -> float:
	return 0.7 - (x + 0.34) * 0.85


## His era's clothes, his costume, his weapon: rebuilt from GameState.
func refresh() -> void:
	for e in _extras:
		(e as Node).queue_free()
	_extras.clear()
	for p in _skirt:
		(p as Node).queue_free()
	_skirt.clear()
	var hooded: bool = GameState.skin in ["wolf_hood", "bear_cloak"]
	_build_hair(hooded)
	var cols := _hide()
	var fur: Color = cols[0]
	var b := Lump.new()                     # on his trunk
	var h := Lump.new()                     # on his hips
	if era >= 2:
		_tunic(b, fur)
		_build_skirt(fur)
	else:
		# era 1: the LEAF skirt, every leaf loose in the air
		for k in 13:
			var a := k * TAU / 13.0
			var rad := Vector3(sin(a), 0, cos(a))
			var top := Vector3(sin(a) * 0.255, 0.06, cos(a) * 0.19)
			var path := PackedVector3Array([top, top + rad * 0.03 + Vector3(0, -0.07, 0), top + rad * 0.05 + Vector3(0, -0.16, 0), top + rad * 0.055 + Vector3(0, -0.22, 0)])
			_tube(h, path, PackedFloat32Array([0.012, 0.045, 0.036, 0.0]), LEAF.lightened((k % 3) * 0.07), PLAIN, 0.9, 40.0 + k, 6, 0.25, rad)
	# the twisted ROPE BELT, the knot, its swinging ends, the pouch
	for strand in 2:
		var path2 := PackedVector3Array()
		var radii2 := PackedFloat32Array()
		for i in 64:
			var a2 := TAU * i / 64.0
			var rad2 := Vector3(sin(a2), 0, cos(a2))
			var tw := a2 * 14.0 + strand * PI
			path2.append(Vector3(sin(a2) * 0.262, 0.065, cos(a2) * 0.198) + rad2 * cos(tw) * 0.011 + Vector3(0, sin(tw) * 0.011, 0))
			radii2.append(0.016)
		_tube(h, path2, radii2, ROPE if strand == 0 else ROPE.darkened(0.3), FINE, 0.0, 0.0, 6, 1.0, Vector3.ZERO, true)
	var knot := Vector3(sin(0.35) * 0.27, 0.065, cos(0.35) * 0.205)
	_ball(h, knot, Vector3(0.034, 0.03, 0.026), ROPE)
	for k2 in 2:
		var end := knot + Vector3(-0.01 + k2 * 0.03, -0.13 + k2 * 0.02, 0.025)
		_tube(h, PackedVector3Array([knot, knot.lerp(end, 0.5) + Vector3(0, 0, 0.01), end]), PackedFloat32Array([0.012, 0.011, 0.009]), ROPE.darkened(0.12), FINE, 0.7, 50.0 + k2, 6)
	var pb := Basis(Vector3.UP, -0.75)
	var pouch := Vector3(sin(-0.75) * 0.285, -0.0, cos(-0.75) * 0.22)
	_ball(h, pouch, Vector3(0.072, 0.082, 0.042), LEATHER, PLAIN, pb)
	_ball(h, pouch + pb * Vector3(0, 0.035, 0.012), Vector3(0.076, 0.04, 0.042), LEATHER.darkened(0.15), PLAIN, pb)
	_ball(h, pouch + pb * Vector3(0, 0.012, 0.05), Vector3(0.01, 0.01, 0.008), FANG, BARE, pb)
	# the FANG NECKLACE: a dark cord, seven pale fangs (they swing)
	var cord := PackedVector3Array()
	var cr := PackedFloat32Array()
	for i in 13:
		var q := lerpf(-1.0, 1.0, i / 12.0)
		var y := 0.585 - (1.0 - q * q) * 0.1
		cord.append(_torso_at(y, q * 0.95, 1.035) + Vector3(0, 0, 0.004))
		cr.append(0.007)
	_tube(b, cord, cr, CORD, BARE, 0.0, 0.0, 5)
	for k3 in 7:
		var p: Vector3 = cord[3 + k3]
		var len := 0.06 if absf(k3 - 3.0) < 1.5 else 0.045
		var lean := (k3 - 3.0) * 0.012
		_tube(b, PackedVector3Array([p, p + Vector3(lean * 0.5, -len * 0.5, 0.012), p + Vector3(lean, -len, 0.016)]), PackedFloat32Array([0.013, 0.01, 0.0]), FANG, FINE, 0.35, 60.0 + k3, 6)
	_costume_pieces(b, h)
	var bm := _mesh(b, _body, _m_body)
	var hm := _mesh(h, _hips, _m_hips)
	for m in [bm, hm]:
		if m != null:
			_extras.append(m)
	_weapon()


## The fur TUNIC: a shell round his trunk, cut on the diagonal (_tunic_cut), a
## fur pad over the covered shoulder, a light fur trim along the cut, tufted.
func _tunic(b: Lump, fur: Color) -> void:
	var rows := []
	var cen := PackedVector3Array()
	var segs := 40
	for i in 15:
		var row := PackedVector3Array()
		for j in segs:
			var ang := TAU * j / segs
			var top := clampf(_tunic_cut(sin(ang) * 0.31), 0.1, 0.62)
			var y := lerpf(0.03, top, i / 14.0)
			row.append(_torso_at(y, ang, 1.06))
		rows.append(row)
		cen.append(Vector3(0, 0.3, 0))
	b.grid(rows, cen, true, fur, FURRY, PackedFloat32Array(), 0.0)
	_ball(b, Vector3(-0.345, 0.545, 0), Vector3(0.15, 0.075, 0.14), fur, FURRY)
	for side: float in [1.0, -1.0]:
		var trim := PackedVector3Array()
		var tr := PackedFloat32Array()
		for k in 12:
			var x := lerpf(-0.37, 0.31, k / 11.0)
			var y2 := minf(_tunic_cut(x), 0.6)
			var rr := _torso_r(y2)
			var ang2 := asin(clampf(x / (rr.x * 1.07), -1.0, 1.0))
			if side < 0.0:
				ang2 = PI - ang2
			trim.append(_torso_at(y2, ang2, 1.09))
			tr.append(0.032)
		_tube(b, trim, tr, FUR_LIGHT, PLAIN, 0.0, 0.0, 7)
		for k2 in 8:
			var p: Vector3 = trim[2 + k2]
			var out := Vector3(p.x, 0, p.z).normalized()
			_tube(b, PackedVector3Array([p, p + out * 0.02 + Vector3(0.012, -0.03, 0), p + out * 0.03 + Vector3(0.02, -0.055, 0)]),
				PackedFloat32Array([0.022, 0.015, 0.0]), FUR_LIGHT if k2 % 2 == 0 else FUR_LIGHT.darkened(0.08), FINE, 0.45, 20.0 + k2 + side, 5)


## The skirt below the belt, in four panels that swing with his legs (so a
## stride never pokes through it), the jagged light hem: every point loose.
func _build_skirt(fur: Color) -> void:
	for k in 4:
		var mid := k * PI * 0.5
		var pivot := _node(Vector3(sin(mid) * 0.25, 0.07, cos(mid) * 0.185), _hips)
		_skirt.append(pivot)
		var l := Lump.new()
		var rows := []
		var cen := PackedVector3Array()
		var fl := PackedFloat32Array()
		var cols := 9
		for i in 6:
			var q := i / 5.0
			var y := lerpf(0.07, -0.24, q)
			var rx := lerpf(0.25, 0.315, q)
			var rz := lerpf(0.185, 0.25, q)
			var row := PackedVector3Array()
			for j in cols:
				var a := mid + lerpf(-0.86, 0.86, float(j) / (cols - 1))
				row.append(Vector3(sin(a) * rx, y, cos(a) * rz) - pivot.position)
			rows.append(row)
			cen.append(Vector3(0, y, 0) - pivot.position)
			fl.append(0.45 * pow(q, 1.5))
		l.grid(rows, cen, false, fur, FURRY, fl, k * 2.0)
		# the hem: jagged light points
		for j2 in cols - 1:
			var a2 := mid + lerpf(-0.86, 0.86, (j2 + 0.5) / (cols - 1))
			var rad := Vector3(sin(a2), 0, cos(a2))
			var top := Vector3(sin(a2) * 0.312, -0.215, cos(a2) * 0.247) - pivot.position
			var tip := top + Vector3(0, -0.075 - 0.02 * float((j2 + k) % 2), 0) + rad * 0.012
			_tube(l, PackedVector3Array([top, top.lerp(tip, 0.5), tip]), PackedFloat32Array([0.034, 0.024, 0.0]), FUR_LIGHT if (j2 + k) % 2 == 0 else FUR_LIGHT.darkened(0.12),
				FINE, 0.85, 30.0 + k * 8.0 + j2, 6, 0.4, rad)
		_mesh(l, pivot, _m_hips)


func _costume_pieces(b: Lump, _h: Lump) -> void:
	var hd := Lump.new()
	match GameState.skin:
		"wolf_hood":
			_shell(hd, 1.15, -PI, PI, true, func(lo): return Vector2(lerpf(-0.6, 0.42, smoothstep(-0.6, 0.8, cos(lo))), PI * 0.5), Pal.WOLF, FURRY, 12, 40)
			var snout := _head_point(0.62, 0.0, 1.16)
			_ball(hd, snout + Vector3(0, -0.01, 0.06), Vector3(0.09, 0.07, 0.12), Pal.WOLF)
			_ball(hd, snout + Vector3(0, -0.02, 0.18), Vector3(0.03, 0.025, 0.025), DARK, FINE)
			for side: float in [-1.0, 1.0]:
				var ear := _head_point(1.0, side * 0.6, 1.12)
				_tube(hd, PackedVector3Array([ear, ear + Vector3(side * 0.02, 0.06, -0.01), ear + Vector3(side * 0.03, 0.12, -0.02)]), PackedFloat32Array([0.05, 0.035, 0.0]), Pal.WOLF_DARK, PLAIN, 0.2, side, 6, 0.6, Vector3(0, 0, 1))
				_ball(hd, snout + Vector3(side * 0.05, 0.035, 0.05), Vector3(0.014, 0.012, 0.01), Color("e8d36a"), SHINE)
			for t in 5:
				var tx := lerpf(-0.06, 0.06, t / 4.0)
				var tp := _head_point(0.42, tx * 3.0, 1.16)
				_tube(hd, PackedVector3Array([tp, tp + Vector3(0, -0.025, 0.006), tp + Vector3(0, -0.045, 0.004)]), PackedFloat32Array([0.01, 0.007, 0.0]), FANG, FINE, 0.0, 0.0, 5)
			_cape(b, Pal.WOLF, 0.42, 0.5)
		"bear_cloak":
			_shell(hd, 1.15, -PI, PI, true, func(lo): return Vector2(lerpf(-0.6, 0.45, smoothstep(-0.6, 0.8, cos(lo))), PI * 0.5), Color("6b4a2e"), FURRY, 12, 40)
			for side2: float in [-1.0, 1.0]:
				var ear2 := _head_point(0.95, side2 * 0.75, 1.15)
				_ball(hd, ear2, Vector3(0.05, 0.05, 0.03), Color("6b4a2e"))
				_ball(hd, ear2 + Vector3(0, 0, 0.02), Vector3(0.028, 0.028, 0.015), Color("45301c"), BARE)
			_cape(b, Color("6b4a2e"), 0.56, 0.62)
		"firekeeper":
			var band := PackedVector3Array()
			var br := PackedFloat32Array()
			for i in 40:
				band.append(_head_point(0.5 - 0.15 * maxf(-cos(TAU * i / 40.0), 0.0), TAU * i / 40.0, 1.1))
				br.append(0.018)
			_tube(hd, band, br, Color("a0703c"), PLAIN, 0.0, 0.0, 6, 0.6, Vector3.UP, true)
			_ball(hd, _head_point(0.5, 0.0, 1.17), Vector3(0.026, 0.026, 0.02), Color("ff8a2a"), SHINE)
			for k in 2:
				var fp := _head_point(0.55, -1.3, 1.1)
				_tube(hd, PackedVector3Array([fp, fp + Vector3(-0.03, 0.1, -0.04 - k * 0.03), fp + Vector3(-0.05 - k * 0.02, 0.22, -0.1 - k * 0.04)]), PackedFloat32Array([0.016, 0.022, 0.0]),
					[Color("e8e0cc"), Color("c0392b")][k], PLAIN, 0.6, 90.0 + k, 6, 0.3, Vector3(1, 0, 0))
		"ember_paint":
			for k2 in 3:
				var x := -0.09 + k2 * 0.09
				var st := PackedVector3Array()
				for i2 in 3:
					var y := 0.4 - i2 * 0.06 - absf(x) * 0.3
					st.append(_torso_at(y, asin(clampf(x / 0.3, -1, 1)), 1.075))
				_tube(b, st, PackedFloat32Array([0.012, 0.014, 0.0]), Color("e0602a"), BARE, 0.0, 0.0, 5)
			var stripe := PackedVector3Array()
			for i3 in 7:
				stripe.append(_face(lerpf(-22.0, 22.0, i3 / 6.0), -143.0, 1.02))
			_tube(hd, stripe, PackedFloat32Array([0.0, 0.012, 0.015, 0.015, 0.015, 0.012, 0.0]), Color("e0602a"), BARE, 0.0, 0.0, 5, 0.4, Vector3(0, 0, 1))
	var hm := _mesh(hd, _head, _m_head)
	if hm != null:
		_extras.append(hm)


## A cape (pelt, cloak) down his back: a sheet from the shoulders, looser lower down.
func _cape(b: Lump, col: Color, w0: float, w1: float) -> void:
	for face in 2:
		var rows := []
		var cen := PackedVector3Array()
		var fl := PackedFloat32Array()
		for i in 9:
			var q := i / 8.0
			var y := lerpf(0.6, -0.42, q)
			var w := lerpf(w0, w1, q) * 0.5
			var row := PackedVector3Array()
			for j in 9:
				var u := lerpf(-1.0, 1.0, j / 8.0)
				var rz := _torso_r(clampf(y, -0.1, 0.6)).y
				row.append(Vector3(u * w, y, -(rz + 0.035 + q * 0.08) + u * u * 0.06 + face * 0.012))
			rows.append(row)
			cen.append(Vector3(0, y, 0.3 if face == 0 else -0.6))
			fl.append(1.1 * pow(q, 1.3))
		b.grid(rows, cen, false, col if face == 0 else col.darkened(0.25), FURRY if face == 0 else PLAIN, fl, 70.0)


func _weapon() -> void:
	var w := Lump.new()
	match GameState.weapon:
		"axe":
			_limb(w, Vector3(0, -0.1, -0.03), Vector3(0, 0.6, 0.2), 0.024, 0.022, WOOD, PLAIN, 8)
			var hb := Basis(Vector3.RIGHT, -0.32)
			_ball(w, Vector3(0, 0.52, 0.27), Vector3(0.03, 0.1, 0.13), STONE, PLAIN, hb)
			for k in 3:
				_ring(w, Vector3(0, 0.48 + k * 0.035, 0.17 + k * 0.011), Vector2(0.03, 0.03), 0.007, ROPE.darkened(0.2), FINE)
		"hammer":
			_limb(w, Vector3(0, -0.1, -0.03), Vector3(0, 0.62, 0.21), 0.03, 0.026, WOOD_DARK, PLAIN, 8)
			_ball(w, Vector3(0, 0.6, 0.2), Vector3(0.15, 0.08, 0.08), STONE, PLAIN, Basis(Vector3.RIGHT, -0.32))
			_ball(w, Vector3(0, 0.6, 0.285), Vector3(0.03, 0.03, 0.012), Color("e04848"), SHINE, Basis(Vector3.RIGHT, -0.32))
		_:
			# the club: thick at the head, knobbly, a darker grip
			var path := PackedVector3Array()
			var radii := PackedFloat32Array([0.0, 0.03, 0.03, 0.04, 0.062, 0.076, 0.07, 0.04, 0.0])
			var ts := [-0.04, 0.0, 0.25, 0.42, 0.56, 0.68, 0.74, 0.79, 0.81]
			for t in ts:
				path.append(Vector3(0, -0.1, -0.03) + Vector3(0, 0.72, 0.235).normalized() * (float(t) + 0.04))
			_tube(w, path, radii, WOOD, PLAIN, 0.0, 0.0, 10)
			for k in 4:
				var at := Vector3(0, -0.1, -0.03) + Vector3(0, 0.72, 0.235).normalized() * (0.5 + k * 0.07)
				var a := k * 2.1
				_ball(w, at + Vector3(cos(a) * 0.06, 0, sin(a) * 0.06), Vector3(0.022, 0.022, 0.022), WOOD_DARK, FINE)
			_tube(w, _line(Vector3(0, -0.06, -0.017), Vector3(0, 0.06, 0.022), 3), PackedFloat32Array([0.035, 0.036, 0.035]), LEATHER.darkened(0.3), FINE, 0.0, 0.0, 8)
	# held out of the fist, up and forward (built leaning 0.31 forward; his
	# forearm hangs forward a little)
	var grip := _node(Vector3.ZERO, _hand_r)
	grip.rotation.x = 1.04
	_extras.append(grip)
	_mesh(w, grip, _m_still)


## ------------------------------------------------------------------ the game's calls
## He jumped: a stretch; `double`: a somersault and a grin.
func jumped(double := false) -> void:
	if double:
		_flip = 0.0
		_cheer = 0.6
	_sq_v -= 2.2


## He landed: squash, by how hard (0..1).
func landed(impact := 0.5) -> void:
	_flip = -1.0
	_sq_v += 1.2 + 3.6 * clampf(impact, 0.0, 1.0)
	if impact > 0.55:
		_wince = 0.25 + 0.35 * impact            # that one hurt


## A laugh, then a grin, for a while (he bought, made or caught something).
func cheer(t := 1.2) -> void:
	_cheer = maxf(_cheer, t)


## A feeling on his face for `t` seconds (a name in EXPRESSIONS: "sad" when he
## can't pay, "proud" in a new costume...). It wins over what he is doing.
func emote(feeling: String, t := 1.5) -> void:
	if EXPRESSIONS.has(feeling):
		_emote = feeling
		_emote_t = t


## ------------------------------------------------------------------ every frame
func _process(delta: float) -> void:
	_t += delta
	var dt := minf(delta, 1.0 / 30.0)
	if _last != Vector3.INF and delta > 0.0:
		var step := (global_position - _last) / delta
		if step.length() < 25.0:              # (more is a teleport, not a run)
			vel = vel.lerp(step, minf(1.0, delta * 20.0))
	_last = global_position
	var local := global_transform.basis.inverse() * vel                     # his velocity, model space
	var flat := Vector2(local.x, local.z).length()
	var run := clampf(maxf(speed, flat / 5.0), 0.0, 1.0)
	var fast := clampf(sprint, 0.0, 1.0)
	_idle = _idle + delta if run < 0.05 and not air else 0.0
	_cheer = maxf(_cheer - delta, 0.0)
	# turning: he banks into it
	var yaw := global_rotation.y
	var turn := 0.0
	if _yaw_last != INF and delta > 0.0:
		turn = wrapf(yaw - _yaw_last, -PI, PI) / delta
	_yaw_last = yaw
	_bank = lerpf(_bank, clampf(-turn * 0.045 * run, -0.28, 0.28), minf(1.0, dt * 8.0))
	_air_k = move_toward(_air_k, 1.0 if air else 0.0, dt * (7.0 if air else 10.0))
	_fall_k = move_toward(_fall_k, 1.0 if vel.y < -0.5 else 0.0, dt * 4.0)
	if not air:
		_phase += maxf(flat, speed * 5.0) * dt * TAU / (1.75 + 0.55 * fast)
		if _flip >= 0.0:
			_flip = -1.0
	if _flip >= 0.0:
		_flip += dt / 0.55
		if _flip >= 1.0:
			_flip = -1.0
	# the landing squash: a spring
	_sq_v += (-_sq * 240.0 - _sq_v * 13.0) * dt
	_sq = clampf(_sq + _sq_v * dt, -0.18, 0.32)
	# ---- the pose: on the ground (a run that keeps pace), a yawn and a stretch,
	# in the air (rising, falling), tucked in a somersault
	var s := sin(_phase)
	var c := cos(_phase)
	var amp := 0.62 + 0.28 * fast
	var breathe := sin(_t * 2.2)
	var pose := PackedFloat32Array([
		-s * amp * run, s * amp * run,
		run * (0.12 + 1.2 * maxf(0.0, c)) + 0.05, run * (0.12 + 1.2 * maxf(0.0, -c)) + 0.05,
		s * (0.8 + 0.35 * fast) * run, -0.2 + 0.06 * run - breathe * 0.02,
		-s * 0.45 * run - 0.18, 0.2 - 0.06 * run + breathe * 0.02,
		-0.45 - 0.75 * run - 0.4 * fast, -0.7 - 0.35 * run,
		0.1 * run + 0.12 * fast, 0.014 * run - 0.035 * run * absf(c)])
	var yawn := 0.0
	if _idle > 6.0 and fmod(_idle - 6.0, 9.0) < 2.0:
		yawn = sin(fmod(_idle - 6.0, 9.0) / 2.0 * PI)
		pose = _blend(pose, PackedFloat32Array([0.0, 0.0, 0.05, 0.05, -2.75, -0.45, -2.5, 0.45, -0.7, -0.8, -0.12, 0.02]), yawn)
	var flail := sin(_t * 13.0) * 0.22
	var rise := PackedFloat32Array([-1.15, 0.3, 1.5, 0.45, -2.2, -0.35, -0.75, 0.3, -0.5, -0.65, 0.06, 0.0])
	var fall := PackedFloat32Array([-0.45, -0.1, 0.75, 0.4, -2.6 + flail, -0.95, -2.3 - flail, 0.95, -0.35, -0.45, -0.04, 0.0])
	rise = _blend(rise, fall, _fall_k)
	pose = _blend(pose, rise, _air_k)
	var tuck := sin(clampf(_flip, 0.0, 1.0) * PI) if _flip >= 0.0 else 0.0
	pose = _blend(pose, PackedFloat32Array([-1.7, -1.7, 2.2, 2.2, -0.9, -0.25, -0.9, 0.25, -1.7, -1.6, 0.0, 0.0]), tuck)
	# the landing bends his knees
	var sq := maxf(_sq, 0.0)
	pose[0] -= sq * 0.9
	pose[1] -= sq * 0.9
	pose[2] += sq * 1.8
	pose[3] += sq * 1.8
	_leg_l.rotation.x = pose[0]
	_leg_r.rotation.x = pose[1]
	_knee_l.rotation.x = pose[2]
	_knee_r.rotation.x = pose[3]
	_foot_l.rotation.x = lerpf(-(pose[0] + pose[2]) * 0.85, 0.35, _air_k)
	_foot_r.rotation.x = lerpf(-(pose[1] + pose[3]) * 0.85, 0.35, _air_k)
	_arm_l.rotation = Vector3(pose[4], 0, pose[5])
	_arm_r.rotation = Vector3(pose[6], 0, pose[7])
	_elbow_l.rotation.x = pose[8]
	_elbow_r.rotation.x = pose[9]
	var spin := smoothstep(0.0, 1.0, _flip) * TAU if _flip >= 0.0 else 0.0
	_root.rotation = Vector3(pose[10] + spin, 0, _bank)
	_root.position = Vector3(0, 0.95 + pose[11] - sq * 0.13, 0)
	var twist := s * 0.16 * run * (1.0 - _air_k)
	_body.rotation = Vector3(0, twist, 0)
	_hips.rotation = Vector3(0, -twist * 0.6, sin(_t * 0.6) * 0.02 * (1.0 - run))
	_hips.position.x = sin(_t * 0.6) * 0.012 * (1.0 - run)
	_body.scale = Vector3(1.0 + breathe * 0.008, 1.0 + breathe * 0.012 * (1.0 - run), 1.0 + breathe * 0.016)
	_sqn.scale = Vector3(1.0 + _sq * 0.45, 1.0 - _sq, 1.0 + _sq * 0.45)
	# the skirt's panels follow his legs: the front one the leading thigh, the back one the trailing
	if _skirt.size() == 4:
		(_skirt[0] as Node3D).rotation.x = minf(0.0, minf(pose[0], pose[1])) * 0.75
		(_skirt[2] as Node3D).rotation.x = maxf(0.0, maxf(pose[0], pose[1])) * 0.75
		(_skirt[1] as Node3D).rotation.z = -_air_k * 0.15
		(_skirt[3] as Node3D).rotation.z = _air_k * 0.15
	# the head: toward what he looks at, else about him; steady on a run
	var want := Vector2(sin(_t * 0.45) * 0.4 * (1.0 - run) * (1.0 - yawn), 0.0)
	if look_at_point != Vector3.INF:
		var to := to_local(look_at_point)
		want = Vector2(clampf(atan2(to.x, to.z), -1.0, 1.0), clampf(atan2(1.55 - to.y, Vector2(to.x, to.z).length()) * 0.6, -0.3, 0.35))
		if to.z < -0.3:
			want.x *= 0.4                    # (behind him: no owl turns)
	_look = _look.lerp(want, minf(1.0, dt * 5.0))
	_head.rotation = Vector3(_look.y - pose[10] * 0.6 - yawn * 0.35, _look.x - twist, -_bank * 0.5)
	_face_step(dt, run, fast, yawn, breathe)
	# ---- THE AIR: a spring toward the opposite of his motion (falling: upward)
	var to_drag := Vector3(-local.x, -local.y * 0.7, -local.z) * 0.018
	_drag_v += ((to_drag - _drag) * 90.0 - _drag_v * 10.0) * dt
	_drag += _drag_v * dt
	_drag = _drag.limit_length(0.2)
	var spd := clampf(vel.length() / 5.0, 0.0, 1.8)
	_flut += Vector3(6.0 + 7.0 * spd, 11.0 + 9.0 * spd, 5.0 + 6.0 * spd) * delta
	_amp = 0.006 + 0.018 * spd
	var dw := global_transform.basis * _drag
	for f in _flexers:
		var node: Node3D = f[1]
		_air_on(f[0], node.global_transform.basis.orthonormalized().inverse() * dw)


## ------------------------------------------------------------------ his face
## What he feels, from what he is doing (an emote() wins): a somersault "whee",
## a laugh when he got something, a wince after a hard landing, "ooh" as he
## falls and fright if it goes on, a yawn, the tongue out on a run and gritted
## teeth flat out, a cocked brow at something new, bored, then sleepy, standing
## about; else his open smile.
func _pick_mood(run: float, fast: float, yawn: float) -> String:
	if _emote_t > 0.0:
		return _emote
	if _flip >= 0.0:
		return "whee"
	if _cheer > 0.0:
		return "laugh" if _cheer > 0.55 else "grin"
	if _wince > 0.0:
		return "wince"
	if air and vel.y < -1.5:
		return "scared" if _fall_t > 0.9 else "ooh"
	if air:
		return "happy"
	if yawn > 0.0:
		return "yawn"
	if fast > 0.6:
		return "effort"
	if run > 0.85:
		return "tongue"
	if run > 0.1:
		return "happy" if run > 0.4 else "smile"
	if _curious > 0.0:
		return "curious"
	if sleepy > 0.5 and _idle > 2.0:
		return "sleepy"
	if _idle > 3.5 and fmod(_idle - 3.5, 9.0) < 2.2:
		return "bored"
	return "smile"


func _face_step(dt: float, run: float, fast: float, yawn: float, breathe: float) -> void:
	_emote_t = maxf(_emote_t - dt, 0.0)
	_wince = maxf(_wince - dt, 0.0)
	_curious = maxf(_curious - dt, 0.0)
	_fall_t = _fall_t + dt if air and vel.y < -1.5 else 0.0
	var looking := look_at_point != Vector3.INF
	if looking and not _looked:
		_curious = 1.4                       # something new to look at: a cocked brow (and awake)
		_idle = 0.0
	_looked = looking
	var mood := _pick_mood(run, fast, yawn)
	if mood != _mood:
		if _mood != "" and _blink >= 1.0 and mood not in ["yawn", "wince", "laugh"]:
			_blink = 0.0                     # a change of feeling: a blink
		_mood = mood
		_mood_t = 0.0
		_tongue.visible = mood == "tongue"
	_mood_t += dt
	face_mood = mood
	var want: Dictionary = FACE_REST.duplicate()
	want.merge(EXPRESSIONS[mood], true)
	# ---- life on top of the feeling
	if mood == "yawn":
		want["open"] = 0.15 + 0.85 * yawn
		want["lid"] = 0.3 + 0.6 * yawn
	elif mood == "laugh":
		want["open"] = float(want["open"]) - 0.3 * absf(sin(_mood_t * 14.0))           # ha! ha! ha!
	elif mood == "tongue":
		_tongue.rotation = Vector3(0, 0, sin(_t * 26.0) * 0.35)
	elif mood == "smile" or mood == "sleepy":
		want["open"] = float(want["open"]) + breathe * 0.04
	want["lid"] = float(want["lid"]) + 0.35 * sleepy * (1.0 - float(want["lid"]))
	# a passing look on an idle face: a brow flick, a smirk, a hum, a puff
	_quirk_t = maxf(_quirk_t - dt, 0.0)
	if mood == "smile" and run < 0.05:
		_quirk_in -= dt
		if _quirk_in <= 0.0:
			_quirk = ["flick", "smirk", "hum", "puff", "flick"][_rng.randi() % 5]
			_quirk_t = _rng.randf_range(0.7, 1.4)
			_quirk_in = _rng.randf_range(3.5, 7.0)
	else:
		_quirk_t = 0.0
	if _quirk_t > 0.0:
		var q := sin(clampf(_quirk_t / 0.7, 0.0, 1.0) * PI * 0.5)
		match _quirk:
			"flick":
				want["brow_r"] = 0.7 * q
			"smirk":
				want["smirk"] = 0.7 * q
				want["open"] = float(want["open"]) * (1.0 - 0.7 * q)
			"hum":
				want["open"] = float(want["open"]) * (1.0 - q)
				want["smile"] = 0.75
				want["squint"] = 0.4 * q
			"puff":
				want["open"] = 0.1
				want["wide"] = -1.0 * q
	# ---- the springs
	for k in want:
		var x: float = _dial.get(k, FACE_REST[k])
		var v: float = _dial_v.get(k, 0.0)
		v += ((float(want[k]) - x) * 320.0 - v * 27.0) * dt
		_dial[k] = x + v * dt
		_dial_v[k] = v
	# ---- blinks: every few seconds, now and then two
	_blink_in -= dt
	if _blink_in <= 0.0:
		_blink = 0.0
		_blinks = 1 if _rng.randf() < 0.2 else 0
		_blink_in = _rng.randf_range(2.0, 5.5)
	var shut := 0.0
	if _blink < 1.0:
		_blink = minf(_blink + dt / 0.16, 1.0)
		shut = sin(_blink * PI)
		if _blink >= 1.0 and _blinks > 0:
			_blinks -= 1
			_blink = 0.0
	# ---- the eyes: at what he looks at, else a glance here and there (quick:
	# eyes jump, they never drift); falling, down; on a run, ahead
	_gaze_in -= dt
	if looking:
		var to := _head.global_transform.affine_inverse() * look_at_point
		_gaze_to = Vector2(clampf(to.x / maxf(to.z, 0.3) * 1.6, -1.0, 1.0), clampf(to.y / maxf(to.z, 0.3) * 1.6, -1.0, 1.0))
	elif air and vel.y < -1.5:
		_gaze_to = Vector2(0.0, -0.8)
	elif _mood in ["sad", "sleepy", "bored"]:
		_gaze_to = Vector2(0.15, -0.6)
	elif run > 0.3:
		_gaze_to = Vector2(0.0, -0.1)
	elif _gaze_in <= 0.0:
		_gaze_to = Vector2.ZERO if _rng.randf() < 0.4 else Vector2(_rng.randf_range(-0.85, 0.85), _rng.randf_range(-0.45, 0.4))
		_gaze_in = _rng.randf_range(0.7, 2.6)
	_gaze = _gaze.lerp(_gaze_to, minf(1.0, dt * 22.0))
	_set_face(shut)


## Puts the dials on him: the mouth's shader, the jaw, the brows, the lids, the eyes.
func _set_face(shut: float) -> void:
	var d := _dial
	for p in [_m_mouth, _m_mouth.next_pass]:
		var m := p as ShaderMaterial
		m.set_shader_parameter("m_open", maxf(float(d["open"]), 0.0))
		m.set_shader_parameter("m_smile", d["smile"])
		m.set_shader_parameter("m_wide", d["wide"])
		m.set_shader_parameter("m_teeth", clampf(d["teeth"], 0.0, 1.0))
		m.set_shader_parameter("m_span", d["span"])
		m.set_shader_parameter("m_teeth_lo", clampf(d["teeth_lo"], 0.0, 1.0))
		m.set_shader_parameter("m_tongue", clampf(d["tongue"], 0.0, 1.0))
		m.set_shader_parameter("m_smirk", d["smirk"])
	for p in [_m_head, _m_head.next_pass]:
		(p as ShaderMaterial).set_shader_parameter("jaw", maxf(float(d["open"]) - 0.25, 0.0))
	for b in _brows:
		var n: Node3D = b[0]
		var fr: Basis = b[2]
		var side: float = b[3]
		var up: float = float(d["brow"]) + float(d["brow_l"] if side < 0.0 else d["brow_r"])
		var knit: float = d["knit"]
		n.position = (b[1] as Vector3) + fr.y * 0.022 * up - fr.x * side * 0.006 * maxf(knit, 0.0) - fr.y * 0.006 * maxf(knit, 0.0)
		n.basis = Basis(fr.z, side * knit * (0.24 if knit > 0.0 else 0.42))
	var lid := clampf(maxf(float(d["lid"]), shut), 0.0, 1.0)
	var squint := clampf(d["squint"], 0.0, 1.0)
	for i in 4:
		var m := _lids[i] as ShaderMaterial
		var cut := lerpf(0.05, -0.05, lid) if i % 2 == 0 else lerpf(-0.05, 0.016, squint * (1.0 - lid * 0.5))
		m.set_shader_parameter("lid_cut", cut)
		(m.next_pass as ShaderMaterial).set_shader_parameter("lid_cut", cut)
	var pupil: float = d["pupil"]
	for e in _irises:
		var n2: Node3D = e[0]
		var fb: Basis = e[2]
		n2.position = (e[1] as Vector3) + fb.x * _gaze.x * 0.013 + fb.y * _gaze.y * 0.008
		n2.basis = fb * Basis.from_scale(Vector3(pupil, pupil, 1.0))
	# the tongue sticks out of the corner, wherever the corner is
	var hw := 0.082 * clampf(1.0 + 0.35 * float(d["wide"]) + 0.1 * maxf(float(d["smile"]), 0.0), 0.38, 1.5)
	_tongue.position = Vector3(hw * 0.62, 0.024 * float(d["smile"]) * 0.4 - 0.012, 0.03)
	_head.rotation.z += float(d["tilt"])


func _blend(a: PackedFloat32Array, b: PackedFloat32Array, k: float) -> PackedFloat32Array:
	if k <= 0.0:
		return a
	for i in a.size():
		a[i] = lerpf(a[i], b[i], k)
	return a


func _air_on(m: ShaderMaterial, d: Vector3) -> void:
	for mat in [m, m.next_pass]:
		var sm := mat as ShaderMaterial
		sm.set_shader_parameter("drag", d)
		sm.set_shader_parameter("flut", _flut)
		sm.set_shader_parameter("flut_amp", _amp)


## ------------------------------------------------------------------ building blocks
func _node(at: Vector3, parent: Node3D) -> Node3D:
	var n := Node3D.new()
	n.position = at
	parent.add_child(n)
	return n


func _new_mat() -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = BODY_SHADER
		_outline = Shader.new()
		_outline.code = OUTLINE_SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	var o := ShaderMaterial.new()
	o.shader = _outline
	m.next_pass = o
	return m


func _mesh(l: Lump, parent: Node3D, mat: ShaderMaterial) -> MeshInstance3D:
	var mesh := l.commit()
	if mesh == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.extra_cull_margin = 0.3                  # (the air moves vertices past the mesh's box)
	parent.add_child(mi)
	return mi


## `n` points from a to b.
func _line(a: Vector3, b: Vector3, n: int) -> PackedVector3Array:
	var p := PackedVector3Array()
	for i in n:
		p.append(a.lerp(b, float(i) / (n - 1)))
	return p


func _perp(t: Vector3) -> Vector3:
	return (Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT).cross(t).normalized()


## An ellipsoid: centre, radii, turned by `b`.
func _ball(l: Lump, at: Vector3, r: Vector3, col: Color, look := PLAIN, b := Basis.IDENTITY, rings := 8, segs := 14) -> void:
	var rows := []
	var cen := PackedVector3Array()
	for i in rings + 1:
		var lat := lerpf(-PI * 0.5, PI * 0.5, float(i) / rings)
		var row := PackedVector3Array()
		for j in segs:
			var lon := TAU * j / segs
			row.append(at + b * (Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon)) * r))
		rows.append(row)
		cen.append(at)
	l.grid(rows, cen, true, col, look, PackedFloat32Array(), 0.0)


## A tube along `path`, `radii[i]` at each point (0: a tip). `flat` squashes it
## across `thin`; `reach`: how far its far end moves in the air (its root stays);
## `loop`: a closed ring.
func _tube(l: Lump, path: PackedVector3Array, radii: PackedFloat32Array, col: Color, look := PLAIN, reach := 0.0, phase := 0.0, segs := 8, flat := 1.0, thin := Vector3.ZERO, loop := false) -> void:
	var n := path.size()
	var total := 0.0
	for i in range(1, n):
		total += path[i].distance_to(path[i - 1])
	var rows := []
	var cen := PackedVector3Array()
	var fl := PackedFloat32Array()
	var run := 0.0
	var w := Vector3.ZERO
	for i in n:
		if i > 0:
			run += path[i].distance_to(path[i - 1])
		var t: Vector3
		if loop:
			t = (path[(i + 1) % n] - path[posmod(i - 1, n)]).normalized()
		else:
			t = (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		var hint := thin if thin != Vector3.ZERO else (w if w != Vector3.ZERO else _perp(t))
		w = hint - t * hint.dot(t)
		if w.length_squared() < 1e-8:
			w = _perp(t)
		w = w.normalized()
		var u := w.cross(t)
		var r: float = radii[i]
		var row := PackedVector3Array()
		for j in segs:
			var a := TAU * j / segs
			row.append(path[i] + u * cos(a) * r + w * sin(a) * r * flat)
		rows.append(row)
		var cp := path[i]
		if r < 0.0005 and not loop:
			cp -= t * (0.01 if i > 0 else -0.01)
		cen.append(cp)
		fl.append(reach * pow(run / maxf(total, 0.0001), 1.5))
	if loop:
		rows.append(rows[0])
		cen.append(cen[0])
		fl.append(fl[0])
	l.grid(rows, cen, true, col, look, fl, phase)


## A capsule from a to b, radius ra at a, rb at b, rounded ends.
func _limb(l: Lump, a: Vector3, b: Vector3, ra: float, rb: float, col: Color, look := PLAIN, segs := 12) -> void:
	var d := (b - a).normalized()
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	for k in 3:
		var ang := PI * 0.5 * (1.0 - k / 3.0)
		path.append(a - d * ra * sin(ang))
		radii.append(ra * cos(ang))
	path.append(a)
	radii.append(ra)
	path.append(b)
	radii.append(rb)
	for k2 in range(1, 4):
		var ang2 := PI * 0.5 * k2 / 3.0
		path.append(b + d * rb * sin(ang2))
		radii.append(rb * cos(ang2))
	_tube(l, path, radii, col, look, 0.0, 0.0, segs)


## A ring round the vertical (a wrap's cord), radii `r`, `thick`.
func _ring(l: Lump, at: Vector3, r: Vector2, thick: float, col: Color, look := PLAIN) -> void:
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in 20:
		var a := TAU * i / 20.0
		path.append(at + Vector3(sin(a) * r.x, 0, cos(a) * r.y))
		radii.append(thick)
	_tube(l, path, radii, col, look, 0.0, 0.0, 5, 1.0, Vector3.ZERO, true)
