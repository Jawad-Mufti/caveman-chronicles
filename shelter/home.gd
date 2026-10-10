extends Node3D
## HOME: UGU'S CAVE (docs/shelter_plan.md), between the eras: an ISLAND, in 3D.
## The world is low-poly 3D made in code (shader water with waves and shore
## foam, wind in thousands of grass blades and the trees, a waterfall into a
## pool, a day and night that turn). Ugu is a 3D figure true to his drawing
## (shelter/ugu3d.gd); the Toolmaker is still his 2D drawing stood up as a
## paper cut-out. The camera is fixed and tilted and leans in when he does
## something; trees between it and him fade out, so he is never lost.
##
## It grows WITH the game: each finished level adds its era (GameState.home_era):
## 1 Raw Stone, 2 Fire (the bone frame at the mouth, furs, pots, the skull, gems,
## the Firestone forge, torches).
##
## Arrows / WASD walk, SPACE jumps, E (or J) uses what he is next to, Esc goes
## back to the level, where he left it. What E does:
##   CLOSET: the next costume he owns (saved)   WEAPON RACK: the next weapon (saved)
##   BED: sleep (night <-> day) and SAVE         FIRE: a log on, or cook a fish (+1 fig)
##   KEKKO: buy figs and stones, sell gems        THE TOOLMAKER: upgrades, the axe
##   THE WORKBENCH: make things from the bag     THE STORE: everything brought home
##   THE PUP: play fetch                         THE PIER: fish (E again on the bite)
##   THE PAINTED WALL: the mysteries, solved and open
## -- shot: pictures, then quit.

const Menu := preload("res://shelter/menu.gd")
const UguModel := preload("res://shelter/ugu3d.gd")
const UguPaper := preload("res://shelter/ugu_paper.gd")

const R := 58.0                  ## the island's radius, metres
const SPEED := 5.0
const GRAVITY := 22.0
const JUMP := 8.0
const CAM_FAR := Vector3(0, 7.0, 10.5)
const CAM_NEAR := Vector3(0, 3.6, 6.0)
const FLOOR_Y := 1.5             ## the cave and the plaza
const CAVE := Vector3(0, FLOOR_Y, -27)
const POOL := Vector3(17, 0, -17)
const BENCH := Vector3(-1.8, FLOOR_Y, -8.6)
var PIER := Vector2(6, 47)       ## where the pier starts: found at the real shore in _ready

const ROCK := Color("8f8076")
const ROCK_DARK := Color("5e534c")
const SAND := Color("e2cb94")
const SAND_WET := Color("b9a274")
const GRASS := Color("5a9a44")
const GRASS_2 := Color("3f7f3a")
const EARTH := Color("7a5a3c")
const HIDE := Color("9a6a40")
const FUR := Color("6e4a30")
const BONE := Color("efe4c8")
const WOOD := Color("6b4a2c")
const LEAF := Color("4f8a3a")
const CLAY := Color("b8643a")
const OCHRE := Color("c8553d")
const MEAT := Color("a8483a")

const LINES := {
	"fire": ["THE FIRE", "E: a log on (or cook a fish you caught)"],
	"bed": ["HIS BED", "E: sleep till morning (or night). The game is saved."],
	"paint": ["THE PAINTED WALL", "E: the mysteries, in ochre"],
	"weapons": ["THE WEAPON RACK", "E: carry the next one"],
	"closet": ["THE CLOSET", "E: try the next costume"],
	"store": ["THE STORE CORNER", "E: everything brought home"],
	"drying": ["THE DRYING RACK", "Meat drying in the smoke. Fish you catch hang here."],
	"piles": ["THE PILES", "Wood, stones and bones. Bones build the cave bigger, one day."],
	"tusk": ["TUSKAR'S TUSK", "The coat hook. Tuskar would hate that."],
	"skull": ["OLD SCAR'S SKULL", "The fire guard. One fang missing: that's a spear, one day."],
	"pup": ["THE PUP", "E: play fetch"],
	"kekko": ["KEKKO'S STALL", "E: trade (figs, stones, gems)"],
	"forge": ["THE TOOLMAKER", "E: upgrades and weapons"],
	"bench": ["THE WORKBENCH", "E: make things from the bag"],
	"pier": ["THE PIER", "E: fish"],
	"pool": ["THE WATERFALL POOL", "Cold! Lovely."],
}

var _noise := FastNoiseLite.new()
var _noise2 := FastNoiseLite.new()
var _era := 1
var _model: Node3D               ## Ugu, in 3D (shelter/ugu3d.gd)
var _paper := false              ## P swaps: the 3D figure / the paper cut-out of his 2D rig
var _rig: CaveMan                ## his 2D rig, never shown: what Bag asks about him (counts, crafting)
var _fish := 0                   ## fish caught this visit, to cook
var _glow_light: OmniLight3D     ## his own soft light
var _occluders: Array = []       ## [node, (x, z), radius, materials, alpha]: they fade when in front of him
var _pos := Vector3(0, 0, -8)
var _vy := 0.0
var _on_ground := true
var _cam: Camera3D
var _cam_k := 0.0               ## 0 far, 1 leaning in
var _focus := 0.0               ## > 0 while he is doing something
var _sun: DirectionalLight3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _night := 0.75              ## 0 noon .. 1 deep night (starts at dusk, like the levels)
var _night_to := 0.75
var _stars: MultiMeshInstance3D
var _star_mat: ShaderMaterial
var _fire_lights: Array = []    ## [light, base energy]
var _flames: Array = []
var _flare := 0.0
var _embers: CPUParticles3D
var _fireflies: CPUParticles3D
var _spits: Array = []
var _spots: Array = []          ## [id, position (x, z), Label3D]
var _blocks: Array = []         ## [centre (x, z), radius]
var _near := ""
var _hint: Label
var _say: Label
var _say_t := 0.0
var _fade: ColorRect
var _toolmaker: Node2D
var _pup: Node3D
var _pup_hop := 0.0
var _hearts: CPUParticles3D
var _fish_state := ""           ## "", "wait", "bite"
var _fish_t := 0.0
var _float: MeshInstance3D
var _line: MeshInstance3D
var _fish_caught := 0
var _drying_fish: Array = []
var _clouds: Array = []
var _birds: Array = []
var _splash: CPUParticles3D
var _t := 0.0


func _ready() -> void:
	Pal.install_fonts()
	_era = GameState.home_era()
	_noise.seed = 7
	_noise.frequency = 0.035
	_noise2.seed = 19
	_noise2.frequency = 0.12
	var z := 20.0                   # the pier: from where the land ends, south of the plaza, out over the sea
	while z < R + 20.0 and height(6.0, z) > 0.45:
		z += 0.25
	PIER = Vector2(6.0, z - 1.5)
	_build_sky()
	_build_island()
	_build_sea()
	_build_shore_foam()
	_build_waterfall()
	_build_grass()
	_build_trees()
	_build_cave()
	_build_plaza()
	_build_pier()
	_build_sky_life()
	_build_ugu()
	_build_ui()
	_bake_static()
	_apply_daylight(true)
	if OS.get_cmdline_user_args().has("shot"):
		_shots.call_deferred()


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	match (e as InputEventKey).physical_keycode:
		KEY_ESCAPE:
			leave()
		KEY_E, KEY_J, KEY_ENTER:
			use()
		KEY_SPACE:
			if _on_ground:
				_vy = JUMP
				_on_ground = false
		KEY_P:
			swap_ugu()


## P: Ugu as the 3D figure (ugu3d.gd) or as his own 2D self on paper (ugu_paper.gd),
## to compare (Jawad picks one; then this key goes).
func swap_ugu() -> void:
	var old := _model
	_paper = not _paper
	_model = (UguPaper if _paper else UguModel).new()
	_model.era = _era
	add_child(_model)
	_model.position = old.position
	_model.rotation = old.rotation
	old.queue_free()
	say("Ugu on PAPER (his 2D self)" if _paper else "Ugu in 3D")


## Back to the level, where he left it (GameState.away); run on its own: Level 2.
func leave() -> void:
	var to := str(GameState.away.get("level", "res://level2/level2.tscn"))
	GameState.resume = not GameState.away.is_empty()
	GameState.from_home = true
	get_tree().change_scene_to_file(to)


## ------------------------------------------------------------------ the ground
## Height of the island (metres) at x, z: a round island, a high rocky ridge in
## the north with the cave cut into its face, a flat plaza before it, a pool
## under the waterfall, a stream to the eastern shore, beaches all round.
func height(x: float, z: float) -> float:
	var warp := _noise.get_noise_2d(x * 0.6, z * 0.6) * 9.0
	var d := Vector2(x, z).length() + warp
	var land := 1.7 + _noise.get_noise_2d(x, z) * 0.9 + _noise2.get_noise_2d(x, z) * 0.2
	var h := lerpf(land, -2.4, smoothstep(R - 12.0, R + 2.0, d))
	# the ridge in the north: a cliff face around z -22, high behind
	var ridge := smoothstep(-20.0, -26.0, z) * (1.0 - smoothstep(26.0, 40.0, absf(x + 4.0)))
	h += ridge * (11.0 + _noise.get_noise_2d(x * 2.0, z * 2.0) * 3.0)
	# the cave: cut into the ridge
	var cave := (1.0 - smoothstep(6.5, 8.0, absf(x - CAVE.x))) * (1.0 - smoothstep(-31.0, -33.0, z)) * smoothstep(-19.0, -21.0, z)
	h = lerpf(h, FLOOR_Y, cave)
	# the plaza before it, flat
	var plaza := 1.0 - smoothstep(9.0, 13.0, Vector2(x, z + 13.0).length())
	h = lerpf(h, FLOOR_Y, plaza * (1.0 - ridge))
	# the pool under the waterfall, and the stream from it to the east shore
	h = lerpf(h, -0.6, 1.0 - smoothstep(3.0, 5.5, Vector2(x - POOL.x, z - POOL.z).length()))
	var seg := _seg_dist(Vector2(x, z), Vector2(POOL.x, POOL.z), Vector2(62, -2))
	h = lerpf(h, -0.3, (1.0 - smoothstep(1.2, 2.6, seg)) * (1.0 - ridge))
	return h


func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var k := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * k)


func _ground_col(x: float, z: float, h: float, slope: float) -> Color:
	var coast := Vector2(x, z).length() + _noise.get_noise_2d(x * 0.6, z * 0.6) * 9.0 > R - 14.0
	if slope > 0.55 and h > 1.2:
		return ROCK.lerp(ROCK_DARK, clampf(_noise2.get_noise_2d(x * 2.0, z * 2.0) + 0.4, 0.0, 1.0))
	if h < 0.25 and coast:
		return SAND_WET
	if h < 1.1 and coast:
		return SAND
	if h < FLOOR_Y + 0.3 and (Vector2(x, z + 13.0).length() < 9.0 or (absf(x - CAVE.x) < 6.5 and z < -19.0)):
		return EARTH.lerp(EARTH.darkened(0.15), _noise2.get_noise_2d(x * 3.0, z * 3.0) * 0.5 + 0.5)
	return GRASS.lerp(GRASS_2, clampf(_noise.get_noise_2d(x * 3.0, z * 3.0) * 1.5 + 0.5, 0.0, 1.0))


func _build_island() -> void:
	var step := 1.0
	var span := R + 8.0
	var n := int(span * 2.0 / step) + 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for j in n:
		for i in n:
			hs[j * n + i] = height(-span + i * step, -span + j * step)
	for j in n:
		for i in n:
			var x := -span + i * step
			var z := -span + j * step
			var h: float = hs[j * n + i]
			var hx: float = hs[j * n + mini(i + 1, n - 1)] - hs[j * n + maxi(i - 1, 0)]
			var hz: float = hs[mini(j + 1, n - 1) * n + i] - hs[maxi(j - 1, 0) * n + i]
			var nrm := Vector3(-hx, 2.0 * step, -hz).normalized()
			st.set_color(_ground_col(x, z, h, 1.0 - nrm.y))
			st.set_normal(nrm)
			st.add_vertex(Vector3(x, h, z))
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			if hs[a] < -2.2 and hs[a + 1] < -2.2 and hs[a + n] < -2.2 and hs[a + n + 1] < -2.2:
				continue
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + n)
			st.add_index(a + 1)
			st.add_index(a + n + 1)
			st.add_index(a + n)
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	m.material_override = mat
	add_child(m)
	# boulders about, and rock outcrops on the ridge
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 70:
		var a := rng.randf() * TAU
		var r := rng.randf_range(6.0, R - 6.0)
		var p := Vector2(cos(a), sin(a)) * r
		if _clear(p, 2.5):
			continue
		var s := rng.randf_range(0.3, 1.1) * (2.2 if p.y < -24.0 else 1.0)
		_rock(Vector3(p.x, height(p.x, p.y), p.y), s, rng)


## Kept clear of trees and rocks: the plaza, the cave, the path, the pool, the stream, the pier.
func _clear(p: Vector2, pad: float) -> bool:
	if p.distance_to(Vector2(0, -13)) < 13.0 + pad or (absf(p.x - CAVE.x) < 9.0 + pad and p.y < -16.0 and p.y > -36.0):
		return true
	if p.distance_to(Vector2(POOL.x, POOL.z)) < 6.5 + pad or _seg_dist(p, Vector2(POOL.x, POOL.z), Vector2(62, -2)) < 2.8 + pad:
		return true
	if _seg_dist(p, Vector2(0, -2), PIER) < 2.0 + pad or p.distance_to(PIER) < 5.0 + pad:
		return true
	return false


func _rock(at: Vector3, s: float, rng: RandomNumberGenerator) -> void:
	var m := _shape(_ball(1.0, 7), ROCK.lerp(ROCK_DARK, rng.randf() * 0.6), at + Vector3(0, s * 0.25, 0), Vector3(rng.randf() * 20.0, rng.randf() * 180.0, 0), Vector3(1.3, 0.75, 1.1) * s)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_blocks.append([Vector2(at.x, at.z), s * 1.1])


## ------------------------------------------------------------------ the sea and the water
const WATER_SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
uniform vec4 deep : source_color = vec4(0.05, 0.22, 0.36, 1.0);
uniform vec4 shallow : source_color = vec4(0.18, 0.62, 0.66, 1.0);
uniform vec4 night_tint : source_color = vec4(0.25, 0.3, 0.55, 1.0);
uniform float night = 0.0;
uniform float island_r = 58.0;
uniform float waves = 1.0;
varying float v_d;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_d = length(w.xz);
	float k = waves * smoothstep(island_r - 10.0, island_r + 30.0, v_d);
	float h = sin(w.x * 0.18 + TIME * 1.1) * 0.22 + sin(w.z * 0.23 - TIME * 0.9) * 0.18 + sin((w.x + w.z) * 0.5 + TIME * 2.1) * 0.06;
	VERTEX.y += h * k;
	float dx = cos(w.x * 0.18 + TIME * 1.1) * 0.04 * k;
	float dz = -sin(w.z * 0.23 - TIME * 0.9) * 0.04 * k;
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
}
void fragment() {
	float shore = 1.0 - smoothstep(island_r - 6.0, island_r + 22.0, v_d);
	vec3 c = mix(deep.rgb, shallow.rgb, shore);
	c = mix(c, c * night_tint.rgb, night);
	ALBEDO = c;
	ROUGHNESS = 0.08;
	METALLIC = 0.15;
	SPECULAR = 0.7;
	ALPHA = 0.9;
}
"""

const FOAM_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float night = 0.0;
void fragment() {
	float edge = UV.y;
	float n = sin(UV.x * 380.0 + TIME * 1.7) * 0.5 + 0.5;
	float n2 = sin(UV.x * 151.0 - TIME * 1.1 + edge * 7.0) * 0.5 + 0.5;
	float wave = sin(TIME * 1.3 + UV.x * 40.0) * 0.5 + 0.5;
	float a = smoothstep(0.0, 0.25, edge) * (1.0 - smoothstep(0.35 + 0.35 * wave, 1.0, edge));
	a *= 0.55 + 0.45 * n * n2;
	ALBEDO = mix(vec3(1.0), vec3(0.65, 0.7, 0.9), night);
	ALPHA = a * 0.85;
}
"""

const FALL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float night = 0.0;
void fragment() {
	float s = fract(UV.y * 3.0 - TIME * 1.6 + sin(UV.x * 30.0) * 0.08);
	float streak = smoothstep(0.0, 0.5, s) * (1.0 - smoothstep(0.5, 1.0, s));
	float st2 = sin(UV.x * 55.0 + sin(UV.y * 9.0 - TIME * 3.0)) * 0.5 + 0.5;
	vec3 c = mix(vec3(0.55, 0.82, 0.92), vec3(1.0), streak * st2);
	ALBEDO = mix(c, c * vec3(0.4, 0.45, 0.7), night);
	ALPHA = (0.55 + 0.4 * streak) * smoothstep(0.0, 0.12, UV.x) * (1.0 - smoothstep(0.88, 1.0, UV.x));
}
"""

var _water_mats: Array = []
var _foam_mat: ShaderMaterial
var _fall_mat: ShaderMaterial


func _build_sea() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(700, 700)
	pm.subdivide_width = 140
	pm.subdivide_depth = 140
	var sea := MeshInstance3D.new()
	sea.mesh = pm
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = WATER_SHADER
	m.shader = sh
	sea.material_override = m
	sea.position.y = 0.0
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
	_water_mats.append(m)
	# the pool and the stream: the same water, calm
	var pool := MeshInstance3D.new()
	var pp := PlaneMesh.new()
	pp.size = Vector2(12, 12)
	pool.mesh = pp
	var m2 := m.duplicate() as ShaderMaterial
	m2.set_shader_parameter("waves", 0.0)
	m2.set_shader_parameter("island_r", 999.0)
	pool.material_override = m2
	pool.position = Vector3(POOL.x, 0.15, POOL.z)
	add_child(pool)
	_water_mats.append(m2)
	var a := Vector2(POOL.x, POOL.z)
	var b := Vector2(62, -2)
	var stream := MeshInstance3D.new()
	var sp := PlaneMesh.new()
	sp.size = Vector2(a.distance_to(b), 3.6)
	stream.mesh = sp
	stream.material_override = m2
	stream.position = Vector3((a.x + b.x) * 0.5, 0.15, (a.y + b.y) * 0.5)
	stream.rotation.y = -(b - a).angle()
	add_child(stream)


## The surf: a band of foam that follows the coast all the way round.
func _build_shore_foam() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 360
	var pts: Array = []
	for i in n + 1:
		var a := TAU * i / n
		var dir := Vector2(cos(a), sin(a))
		var r := 20.0
		while r < R + 20.0 and height(dir.x * r, dir.y * r) > 0.02:
			r += 0.25
		pts.append([dir, r])
	for i in n:
		var p0: Array = pts[i]
		var p1: Array = pts[i + 1]
		var u0 := float(i) / n
		var u1 := float(i + 1) / n
		var in0: Vector2 = p0[0] * (p0[1] - 0.8)
		var out0: Vector2 = p0[0] * (p0[1] + 3.0)
		var in1: Vector2 = p1[0] * (p1[1] - 0.8)
		var out1: Vector2 = p1[0] * (p1[1] + 3.0)
		for v in [[in0, u0, 0.0], [out0, u0, 1.0], [in1, u1, 0.0], [out0, u0, 1.0], [out1, u1, 1.0], [in1, u1, 0.0]]:
			st.set_uv(Vector2(v[1], v[2]))
			var q: Vector2 = v[0]
			st.add_vertex(Vector3(q.x, 0.08, q.y))
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	_foam_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = FOAM_SHADER
	_foam_mat.shader = sh
	m.material_override = _foam_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)


## The waterfall: down the ridge's face into the pool, mist at its foot.
func _build_waterfall() -> void:
	# from the top of the ridge (where the ground stops rising) down its face to the pool,
	# hugging the rock a little out from it
	var z_top := POOL.z - 4.0
	while z_top > -44.0 and height(POOL.x, z_top - 0.5) > height(POOL.x, z_top) + 0.05:
		z_top -= 0.5
	var z_end := POOL.z - 2.6
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 24
	for i in steps:
		var k0 := float(i) / steps
		var k1 := float(i + 1) / steps
		var z0 := lerpf(z_top, z_end, k0)
		var z1 := lerpf(z_top, z_end, k1)
		var y0 := maxf(height(POOL.x, z0), 0.15) + 0.35
		var y1 := maxf(height(POOL.x, z1), 0.15) + 0.35
		var w0 := lerpf(1.3, 2.3, k0)
		var w1 := lerpf(1.3, 2.3, k1)
		for v in [[-w0, y0, z0, 0.0, k0], [w0, y0, z0, 1.0, k0], [-w1, y1, z1, 0.0, k1], [w0, y0, z0, 1.0, k0], [w1, y1, z1, 1.0, k1], [-w1, y1, z1, 0.0, k1]]:
			st.set_uv(Vector2(v[3], v[4]))
			st.add_vertex(Vector3(POOL.x + v[0], v[1], v[2]))
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	_fall_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = FALL_SHADER
	_fall_mat.shader = sh
	m.material_override = _fall_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	var mist := _particles(26, 1.8, Color(1, 1, 1, 0.35), 0.35, 0.8, false)
	mist.position = Vector3(POOL.x, 0.4, POOL.z - 3.0)
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	mist.emission_box_extents = Vector3(1.8, 0.2, 0.6)
	mist.direction = Vector3(0, 1, 0.6)
	mist.spread = 50.0
	mist.initial_velocity_min = 0.6
	mist.initial_velocity_max = 1.6
	mist.gravity = Vector3(0, -0.5, 0)
	add_child(mist)
	_spot("pool", Vector3(POOL.x - 3.5, 0, POOL.z + 3.0))
	_splash = _particles(30, 0.6, Color(0.85, 0.95, 1.0, 0.8), 0.06, 0.12, false)
	_splash.one_shot = true
	_splash.emitting = false
	_splash.explosiveness = 0.9
	_splash.direction = Vector3.UP
	_splash.spread = 50.0
	_splash.initial_velocity_min = 2.0
	_splash.initial_velocity_max = 4.0
	_splash.gravity = Vector3(0, -12, 0)
	add_child(_splash)


## ------------------------------------------------------------------ grass, flowers, trees
const WIND_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform float strength = 1.0;
uniform float night = 0.0;
varying vec3 v_col;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float sway = sin(TIME * 1.8 + w.x * 0.35 + w.z * 0.2) * 0.6 + sin(TIME * 3.3 + w.x * 0.9) * 0.25;
	float k = max(VERTEX.y, 0.0);
	VERTEX.x += sway * k * k * 0.35 * strength;
	VERTEX.z += sway * k * k * 0.15 * strength;
	v_col = COLOR.rgb;
}
void fragment() {
	ALBEDO = v_col;
	ROUGHNESS = 0.9;
	BACKLIGHT = vec3(0.25, 0.35, 0.1);
}
"""

var _wind_mat: ShaderMaterial


func _build_grass() -> void:
	_wind_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = WIND_SHADER
	_wind_mat.shader = sh
	# a blade: a thin bent triangle pair, dark at the root, light at the tip
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var root := Color("2f5f2a")
	var tip := Color("9ad46a")
	var verts := [[Vector3(-0.045, 0, 0), root], [Vector3(0.045, 0, 0), root], [Vector3(0.0, 0.32, 0.02), root.lerp(tip, 0.6)],
		[Vector3(0.045, 0, 0), root], [Vector3(0.025, 0.32, 0.02), root.lerp(tip, 0.6)], [Vector3(0.0, 0.32, 0.02), root.lerp(tip, 0.6)],
		[Vector3(0.0, 0.32, 0.02), root.lerp(tip, 0.6)], [Vector3(0.025, 0.32, 0.02), root.lerp(tip, 0.6)], [Vector3(0.03, 0.55, 0.08), tip]]
	for v in verts:
		st.set_color(v[1])
		st.set_normal(Vector3(0, 1, 0))
		st.add_vertex(v[0])
	var blade := st.commit()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = false
	mm.mesh = blade
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var xforms: Array = []
	var tries := 0
	while xforms.size() < 14000 and tries < 60000:
		tries += 1
		var p := Vector2(rng.randf_range(-R, R), rng.randf_range(-R, R))
		var h := height(p.x, p.y)
		if h < 0.8 or h > 3.5 or p.distance_to(Vector2(0, -13)) < 9.0 or (absf(p.x - CAVE.x) < 7.0 and p.y < -18.0):
			continue
		if _seg_dist(p, Vector2(0, -4), PIER) < 1.0:
			continue
		var s := rng.randf_range(0.7, 1.5)
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.4), s)), Vector3(p.x, h - 0.02, p.y))
		xforms.append(t)
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _wind_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# flowers in the grass
	var colours := [Color("ffd84a"), Color("b07cff"), Color("ff7a6b"), Color("ffffff"), Color("6ad8ff")]
	for i in 160:
		var p2 := Vector2(rng.randf_range(-R, R), rng.randf_range(-R, R))
		var h2 := height(p2.x, p2.y)
		if h2 < 0.9 or h2 > 3.0 or _clear(p2, 0.5):
			continue
		var f := _shape(_ball(0.08, 5), colours[i % colours.size()], Vector3(p2.x, h2 + 0.35, p2.y))
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shape(_cyl(0.012, 0.35, 4), Color("3f7f3a"), Vector3(p2.x, h2 + 0.17, p2.y))


func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var placed := 0
	var tries := 0
	while placed < 120 and tries < 2000:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(14.0, R - 4.0)
		var p := Vector2(cos(a), sin(a)) * r
		var h := height(p.x, p.y)
		if h < 0.5 or _clear(p, 2.5):
			continue
		var at := Vector3(p.x, h, p.y)
		if h < 1.0:
			_palm(at, rng.randf_range(0.9, 1.3), rng)
		elif rng.randf() < 0.55 or h > 3.0:
			_pine(at, rng.randf_range(0.9, 1.7))
		else:
			_broadleaf(at, rng.randf_range(0.9, 1.5), rng)
		_blocks.append([p, 0.6])
		placed += 1


func _pine(at: Vector3, s: float) -> void:
	var t := Node3D.new()
	t.position = at
	add_child(t)
	_shape(_cyl(0.16 * s, 1.2 * s, 7, 0.1 * s), WOOD, Vector3(0, 0.6 * s, 0), Vector3.ZERO, Vector3.ONE, t)
	for k in 4:
		var c := _shape(_cone((1.3 - k * 0.27) * s, 1.4 * s, 9), Color("2f5a3a").lightened(k * 0.05), Vector3(0, (1.3 + k * 0.75) * s, 0), Vector3(0, k * 20.0, 0), Vector3.ONE, t)
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_occluder(t, Vector2(at.x, at.z), 1.3 * s)


func _broadleaf(at: Vector3, s: float, rng: RandomNumberGenerator) -> void:
	var t := Node3D.new()
	t.position = at
	add_child(t)
	_shape(_cyl(0.2 * s, 2.2 * s, 7, 0.13 * s), WOOD.darkened(0.1), Vector3(0, 1.1 * s, 0), Vector3.ZERO, Vector3.ONE, t)
	for k in 5:
		var off := Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0.0, 0.8), rng.randf_range(-0.8, 0.8)) * s
		_shape(_ball(rng.randf_range(0.9, 1.3) * s, 8), LEAF.lightened(rng.randf_range(-0.1, 0.12)), Vector3(0, 2.6 * s, 0) + off, Vector3.ZERO, Vector3.ONE, t)
	_occluder(t, Vector2(at.x, at.z), 1.6 * s)


func _palm(at: Vector3, s: float, rng: RandomNumberGenerator) -> void:
	var t := Node3D.new()
	t.position = at
	t.rotation.y = rng.randf() * TAU
	add_child(t)
	var lean := rng.randf_range(8.0, 18.0)
	var top := Vector3.ZERO
	for k in 6:
		var seg := _shape(_cyl(0.13 * s, 0.7 * s, 6, 0.11 * s), Color("8a6a48").darkened(k * 0.03), top + Vector3(0, 0.35 * s, 0), Vector3(0, 0, -lean), Vector3.ONE, t)
		top += Vector3(sin(deg_to_rad(lean)) * 0.7 * s, cos(deg_to_rad(lean)) * 0.7 * s, 0)
		seg.position = top - Vector3(sin(deg_to_rad(lean)) * 0.35 * s, cos(deg_to_rad(lean)) * 0.35 * s, 0)
	for k in 7:
		var leaf := _box(Vector3(2.2 * s, 0.04, 0.45 * s), Color("4f9a3a").lightened(k * 0.02), top + Vector3(0, 0.1, 0), t)
		leaf.rotation = Vector3(0, k * TAU / 7.0, deg_to_rad(-28.0))
		leaf.position = top + Vector3(cos(k * TAU / 7.0), -0.15, -sin(k * TAU / 7.0)) * 0.9 * s
	for k in 3:
		_shape(_ball(0.13 * s, 6), Color("6a4a2a"), top + Vector3(cos(k * 2.1) * 0.2, -0.15, sin(k * 2.1) * 0.2), Vector3.ZERO, Vector3.ONE, t)
	_occluder(t, Vector2(at.x, at.z), 2.2 * s)          # (its crown leans out: a wider circle)


## ------------------------------------------------------------------ the cave
func _build_cave() -> void:
	var era := _era
	var c := CAVE
	# a roof over its back half (the front is open: a dollhouse cut), rock ribs at the sides
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 7:
		var x := lerpf(-6.5, 6.5, i / 6.0)
		var roof := _shape(_ball(1.0, 7), ROCK.darkened(0.1), Vector3(x, FLOOR_Y + 5.4 + rng.randf_range(-0.3, 0.3), c.z - 2.5 - rng.randf_range(0.0, 2.0)), Vector3(0, rng.randf() * 90.0, 0), Vector3(2.4, 1.1, 3.0))
		roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_occluder(roof, Vector2(roof.position.x, roof.position.z), 2.6)
	for side in [-1.0, 1.0]:
		for k in 3:
			var p := Vector3(side * (6.6 + rng.randf_range(-0.3, 0.3)), FLOOR_Y + 1.5 + k * 1.6, c.z + 4.5 - k * 1.2)
			_shape(_ball(1.0, 7), ROCK.lerp(ROCK_DARK, 0.3), p, Vector3(0, rng.randf() * 90.0, 0), Vector3(1.3, 1.4, 1.6))
		_blocks.append([Vector2(side * 6.8, c.z + 3.5), 1.5])
	# the painted wall at the back
	var wall := c + Vector3(0, 0, -4.6)
	_shape(BoxMesh.new(), ROCK.lightened(0.05), wall + Vector3(0, 2.5, -0.25), Vector3.ZERO, Vector3(11.0, 5.0, 0.4))
	_paint_beast(wall + Vector3(-2.2, 2.4, 0.0), 1.0)
	_paint_beast(wall + Vector3(1.6, 3.1, 0.0), 0.7)
	if era >= 2:
		_paint_cat(wall + Vector3(3.6, 2.0, 0.0))
	for hx in [-4.0, 4.1, 0.0, -0.8]:
		_shape(_cyl(0.18, 0.04, 8), OCHRE, wall + Vector3(hx, 1.2 + absf(hx) * 0.1, 0.0), Vector3(90, 0, 0))
	_spot("paint", wall + Vector3(0, 0, 1.6))
	# THE FIRE: stones, logs, a spit of meat turning, real fire light
	var fire := c + Vector3(0, 0, 0.5)
	for k in 10:
		var an := k * TAU / 10.0
		_shape(_ball(0.22, 6), ROCK, fire + Vector3(cos(an) * 0.75, 0.1, sin(an) * 0.75))
	for k in 3:
		_shape(_cyl(0.09, 1.1), WOOD, fire + Vector3(0, 0.15, 0), Vector3(0, k * 60.0, 80))
	_fire(fire, 1.0)
	for px in [-0.95, 0.95]:
		_shape(_cyl(0.05, 1.5), WOOD, fire + Vector3(px, 0.75, 0), Vector3(0, 0, px * 12.0))
	var spit := Node3D.new()
	spit.position = fire + Vector3(0, 1.38, 0)
	add_child(spit)
	_shape(_cyl(0.035, 2.1), WOOD, Vector3.ZERO, Vector3(0, 0, 90), Vector3.ONE, spit)
	_shape(_ball(0.3, 8), MEAT, Vector3.ZERO, Vector3.ZERO, Vector3(1.4, 0.9, 0.9), spit)
	_shape(_cyl(0.05, 0.55), BONE, Vector3(0.5, 0, 0), Vector3(0, 0, 90), Vector3.ONE, spit)
	_spits.append(spit)
	_blocks.append([Vector2(fire.x, fire.z), 1.05])
	_spot("fire", fire + Vector3(0, 0, 1.5))
	# his bed: leaves, then furs
	var bed := c + Vector3(-4.2, 0, -2.4)
	if era >= 2:
		_shape(_ball(1.0, 10), FUR, bed + Vector3(0, 0.16, 0), Vector3(0, 20, 0), Vector3(1.5, 0.2, 0.85))
		_shape(_ball(1.0, 10), FUR.lightened(0.15), bed + Vector3(-0.2, 0.33, 0.1), Vector3(0, 20, 0), Vector3(1.05, 0.13, 0.62))
		_shape(_ball(0.3, 7), HIDE.lightened(0.1), bed + Vector3(-1.05, 0.42, -0.3), Vector3.ZERO, Vector3(1.3, 0.6, 1.0))
	else:
		for k in 9:
			_shape(_ball(0.36, 6), LEAF.lightened(k * 0.02), bed + Vector3(-1.0 + (k % 3) * 0.9, 0.12, -0.5 + (k / 3) * 0.5), Vector3(0, k * 40.0, 0), Vector3(1.2, 0.35, 0.8))
	_blocks.append([Vector2(bed.x, bed.z), 1.25])
	_spot("bed", bed + Vector3(0.9, 0, 1.6))
	# THE WEAPON RACK
	var rack := c + Vector3(-5.5, 0, 1.8)
	for pz in [-0.75, 0.75]:
		_shape(_cyl(0.06, 1.9), BONE, rack + Vector3(0, 0.95, pz))
	_shape(_cyl(0.05, 1.7), BONE, rack + Vector3(0, 1.85, 0), Vector3(90, 0, 0))
	var held := 0
	for w in ["club", "axe", "hammer"]:
		if GameState.weapons.has(w):
			_weapon(w, rack + Vector3(0.06, 1.05, -0.45 + held * 0.45))
			held += 1
	_blocks.append([Vector2(rack.x, rack.z), 0.85])
	_spot("weapons", rack + Vector3(1.5, 0, 0.2))
	# THE CLOSET: a costume on a hook per era
	var closet := c + Vector3(5.4, 0, 1.6)
	for pz2 in [-0.85, 0.85]:
		_shape(_cyl(0.06, 2.0), BONE, closet + Vector3(0, 1.0, pz2))
	_shape(_cyl(0.05, 1.9), BONE, closet + Vector3(0, 1.95, 0), Vector3(90, 0, 0))
	_costume(closet + Vector3(-0.06, 1.4, -0.45), LEAF, false)
	if era >= 2:
		_costume(closet + Vector3(-0.06, 1.4, 0.4), Color("d9a64e"), true)
	_blocks.append([Vector2(closet.x, closet.z), 0.85])
	_spot("closet", closet + Vector3(-1.5, 0, 0.2))
	# THE STORE CORNER
	var store := c + Vector3(4.0, 0, -2.6)
	for k in 3:
		_shape(_cyl(0.33, 0.48, 10, 0.4), Color("a0784a"), store + Vector3(-0.8 + k * 0.72, 0.24, 0.2 * (k % 2)))
	for k in 7:
		_shape(_ball(0.08, 5), Color("8a2a5a"), store + Vector3(-0.85 + (k % 3) * 0.09, 0.52, 0.05 * (k / 3)))
	if era >= 2:
		for k in 2:
			_shape(_ball(0.36, 9), CLAY, store + Vector3(1.1, 0.38, -0.7 + k * 0.8), Vector3.ZERO, Vector3(1, 1.2, 1))
	_shape(_ball(0.26, 7), HIDE.darkened(0.2), store + Vector3(-1.5, 0.3, -0.6), Vector3.ZERO, Vector3(0.8, 1.2, 0.6))
	_blocks.append([Vector2(store.x, store.z), 1.4])
	_spot("store", store + Vector3(-0.8, 0, 1.6))
	# ARTIFACTS: Tuskar's tusk (era 1), Old Scar's skull (era 2)
	var tusk := c + Vector3(-2.4, 0, -4.0)
	_shape(_cyl(0.14, 1.8, 8, 0.04), BONE, tusk + Vector3(0, 2.1, 0), Vector3(0, 0, 70))
	_shape(BoxMesh.new(), FUR.lightened(0.1), tusk + Vector3(0.5, 1.65, 0.14), Vector3.ZERO, Vector3(0.55, 0.75, 0.05))
	_spot("tusk", tusk + Vector3(0, 0, 1.6))
	if era >= 2:
		var skull := c + Vector3(1.7, 0, 1.4)
		_shape(_ball(0.44, 9), BONE, skull + Vector3(0, 0.42, 0), Vector3.ZERO, Vector3(1.3, 0.9, 1.0))
		_shape(_ball(0.1, 6), Color("1a120c"), skull + Vector3(0.27, 0.52, 0.34))
		_shape(_ball(0.1, 6), Color("1a120c"), skull + Vector3(-0.1, 0.52, 0.4))
		_shape(_cone(0.07, 0.58, 6), BONE, skull + Vector3(0.36, 0.06, 0.32), Vector3(180, 0, 0))
		_blocks.append([Vector2(skull.x, skull.z), 0.65])
		_spot("skull", skull + Vector3(0.7, 0, 1.0))
		# the mouth's upgrade: a frame of mammoth bones, hide curtains, and two torches
		for side2 in [-1.0, 1.0]:
			var post := Vector3(side2 * 5.4, FLOOR_Y, c.z + 4.6)
			_shape(_cyl(0.17, 3.8, 8, 0.09), BONE, post + Vector3(0, 1.7, 0), Vector3(0, 0, -side2 * 12.0))
			_shape(BoxMesh.new(), HIDE, post + Vector3(-side2 * 0.65, 1.7, 0.1), Vector3(0, 0, side2 * 6.0), Vector3(0.95, 3.1, 0.06))
			_torch(post + Vector3(side2 * 1.2, 0, 1.0))
		_shape(_cyl(0.14, 11.4, 8), BONE, Vector3(0, FLOOR_Y + 3.6, c.z + 4.6), Vector3(0, 0, 90))
	# THE PUP, curled by the fire
	_pup = Node3D.new()
	_pup.position = c + Vector3(-1.7, 0, 2.0)
	add_child(_pup)
	var coat := Color("8a7a6a")
	_shape(_ball(0.33, 9), coat, Vector3(0, 0.22, 0), Vector3.ZERO, Vector3(1.3, 0.7, 1.0), _pup)
	_shape(_ball(0.18, 8), coat, Vector3(0.4, 0.32, 0.12), Vector3.ZERO, Vector3.ONE, _pup)
	_shape(_cone(0.06, 0.15, 4), coat.darkened(0.25), Vector3(0.44, 0.5, 0.05), Vector3.ZERO, Vector3.ONE, _pup)
	_shape(_cone(0.06, 0.15, 4), coat.darkened(0.25), Vector3(0.37, 0.5, 0.21), Vector3.ZERO, Vector3.ONE, _pup)
	_shape(_ball(0.04, 5), Color("1a120c"), Vector3(0.56, 0.32, 0.14), Vector3.ZERO, Vector3.ONE, _pup)
	_shape(_cyl(0.06, 0.42, 5, 0.02), coat, Vector3(-0.44, 0.22, 0.15), Vector3(0, 30, 70), Vector3.ONE, _pup)
	_blocks.append([Vector2(_pup.position.x, _pup.position.z), 0.5])
	_spot("pup", _pup.position + Vector3(0, 0, 1.0))
	_hearts = _particles(10, 1.0, Color("ff5a7a"), 0.08, 0.12, true)
	_hearts.one_shot = true
	_hearts.emitting = false
	_hearts.explosiveness = 0.6
	_hearts.direction = Vector3.UP
	_hearts.spread = 35.0
	_hearts.gravity = Vector3(0, 0.6, 0)
	_hearts.initial_velocity_min = 1.0
	_hearts.initial_velocity_max = 1.8
	_hearts.position = _pup.position + Vector3(0, 0.7, 0)
	add_child(_hearts)


func _paint_beast(at: Vector3, s: float) -> void:
	var col := OCHRE
	_shape(_ball(0.5 * s, 9), col, at, Vector3.ZERO, Vector3(1.4, 0.8, 0.05))
	_shape(_ball(0.28 * s, 9), col, at + Vector3(0.62 * s, 0.12 * s, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.05))
	for lx in [-0.35, -0.1, 0.2, 0.45]:
		_shape(BoxMesh.new(), col, at + Vector3(lx * s, -0.45 * s, 0), Vector3.ZERO, Vector3(0.08 * s, 0.4 * s, 0.03))
	_shape(BoxMesh.new(), col, at + Vector3(0.82 * s, -0.25 * s, 0), Vector3(0, 0, 20), Vector3(0.07 * s, 0.5 * s, 0.03))


func _paint_cat(at: Vector3) -> void:
	# Old Scar, in charcoal: a long low body, two huge fangs
	var col := Color("2a221e")
	_shape(_ball(0.5, 9), col, at, Vector3.ZERO, Vector3(1.6, 0.55, 0.05))
	_shape(_ball(0.27, 9), col, at + Vector3(0.8, 0.12, 0), Vector3.ZERO, Vector3(1.0, 0.9, 0.05))
	_shape(BoxMesh.new(), Color("efe4c8"), at + Vector3(0.9, -0.12, 0.02), Vector3(0, 0, 8), Vector3(0.05, 0.3, 0.03))
	for lx in [-0.5, -0.2, 0.25, 0.5]:
		_shape(BoxMesh.new(), col, at + Vector3(lx, -0.38, 0), Vector3.ZERO, Vector3(0.08, 0.36, 0.03))


func _weapon(id: String, at: Vector3) -> void:
	match id:
		"club":
			_shape(_cyl(0.06, 1.0, 7, 0.14), WOOD.lightened(0.1), at, Vector3(0, 0, 8))
		"axe":
			_shape(_cyl(0.04, 1.0, 6), WOOD, at, Vector3(0, 0, 4))
			_shape(BoxMesh.new(), Color("6f6a66"), at + Vector3(0.12, 0.38, 0), Vector3.ZERO, Vector3(0.3, 0.2, 0.06))
		"hammer":
			_shape(_cyl(0.05, 1.0, 6), WOOD.darkened(0.2), at, Vector3.ZERO)
			var head := _shape(BoxMesh.new(), Color.WHITE, at + Vector3(0, 0.45, 0), Vector3.ZERO, Vector3(0.45, 0.24, 0.24))
			head.material_override = _glow(Color("e05a2a"), 0.9)


func _costume(at: Vector3, col: Color, spots: bool) -> void:
	_shape(BoxMesh.new(), col, at, Vector3.ZERO, Vector3(0.06, 0.55, 0.52))
	if spots:
		for k in 5:
			_shape(_ball(0.04, 4), Color("4a2a14"), at + Vector3(0.04, -0.12 + (k % 2) * 0.22, -0.18 + k * 0.09))


func _torch(at: Vector3) -> void:
	_shape(_cyl(0.06, 1.8, 6, 0.04), WOOD, at + Vector3(0, 0.9, 0))
	_shape(_cyl(0.11, 0.25, 7), HIDE.darkened(0.3), at + Vector3(0, 1.8, 0))
	_fire(at + Vector3(0, 1.85, 0), 0.4)


## ------------------------------------------------------------------ the plaza: Kekko, the Toolmaker, the drying rack, the piles
func _build_plaza() -> void:
	# a path of flat stones from the plaza down to the pier
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var a := Vector2(0, -4)
	for i in 34:
		var p := a.lerp(PIER, i / 34.0) + Vector2(rng.randf_range(-0.6, 0.6), 0)
		_shape(_cyl(rng.randf_range(0.35, 0.55), 0.12, 7), Color("9a8f86"), Vector3(p.x, height(p.x, p.y) + 0.03, p.y), Vector3(0, rng.randf() * 90.0, 0))
	# KEKKO'S STALL: pebbles (era 1), gems on a leopard hide (era 2); Kekko under his pack
	var stall := Vector3(7.5, FLOOR_Y, -10.5)
	for px in [-1.1, 1.1]:
		_shape(_cyl(0.08, 2.0), WOOD, stall + Vector3(px, 1.0, -0.4))
		_shape(_cyl(0.08, 1.5), WOOD, stall + Vector3(px, 0.75, 0.5))
	var awning := _box(Vector3(2.7, 0.06, 1.5), Color("b0503a"), stall + Vector3(0, 1.85, 0), self)
	awning.rotation_degrees = Vector3(14, 0, 0)
	for k in 6:
		_box(Vector3(0.45, 0.07, 1.52), Color("e8dcc0") if k % 2 == 0 else Color("b0503a"), stall + Vector3(-1.12 + k * 0.45, 1.86, 0.0), self).rotation_degrees = Vector3(14, 0, 0)
	_shape(_cyl(0.27, 2.1, 9), WOOD, stall + Vector3(0, 0.45, 0.15), Vector3(0, 0, 90))
	var wares := [Color("8a8a8a"), Color("a0947e"), Color("6f6a66"), Color("b0a490")]
	if _era >= 2:
		wares = [Color("6cc4ff"), Color("d08bff"), Color("ffcf40"), Color("ff6b8a"), Color("8fe07a")]
		_box(Vector3(1.8, 0.03, 0.6), Color("d9a64e"), stall + Vector3(0, 0.73, 0.15), self)
	for k in wares.size():
		var g := _shape(_ball(0.11, 5), wares[k], stall + Vector3(-0.7 + k * 0.33, 0.82, 0.15), Vector3(0, k * 30.0, 0))
		if _era >= 2:
			g.material_override = _glow(wares[k], 1.4)
	_kekko(stall + Vector3(1.7, 0, -0.5))
	_blocks.append([Vector2(stall.x, stall.z), 1.5])
	_spot("kekko", stall + Vector3(-0.3, 0, 1.6))
	# THE FORGE and THE TOOLMAKER (his own 2D drawing, a cut-out)
	var forge := Vector3(-7.8, FLOOR_Y, -10.0)
	_shape(_ball(0.65, 7), ROCK_DARK, forge + Vector3(1.0, 0.38, 0), Vector3.ZERO, Vector3(1.2, 0.6, 0.8))
	if _era >= 2:
		for k in 8:
			var an := k * TAU / 8.0
			_shape(_ball(0.23, 6), ROCK, forge + Vector3(-0.7 + cos(an) * 0.65, 0.12, sin(an) * 0.65))
		var coals := _shape(_cyl(0.5, 0.12, 12), Color.WHITE, forge + Vector3(-0.7, 0.16, 0))
		coals.material_override = _glow(Color("ff5a1a"), 2.6)
		_shape(_ball(0.32, 7), HIDE.darkened(0.15), forge + Vector3(-1.75, 0.35, 0.2), Vector3.ZERO, Vector3(1.2, 0.7, 0.8))
		var l := OmniLight3D.new()
		l.light_color = Color("ff7a2a")
		l.light_energy = 1.5
		l.omni_range = 4.5
		l.position = forge + Vector3(-0.7, 0.7, 0)
		add_child(l)
		_fire_lights.append([l, 1.5])
	_weapon("club", forge + Vector3(1.0, 0.8, 0))
	_toolmaker = NightBeasts.Toolmaker.new()
	var tm_cut := _cutout(_toolmaker, 1.65)
	tm_cut.position = forge + Vector3(2.1, 0, 0.4)
	_blocks.append([Vector2(forge.x, forge.z), 1.5])
	_blocks.append([Vector2(tm_cut.position.x, tm_cut.position.z), 0.4])
	_spot("forge", forge + Vector3(1.4, 0, 1.6))
	# THE DRYING RACK, between the cave and the plaza
	var dry := Vector3(-4.2, FLOOR_Y, -17.6)
	for px2 in [-0.9, 0.9]:
		_shape(_cyl(0.05, 1.8), WOOD, dry + Vector3(px2, 0.9, 0))
	_shape(_cyl(0.04, 1.9), WOOD, dry + Vector3(0, 1.75, 0), Vector3(0, 0, 90))
	for k in 3:
		_shape(_ball(0.15, 6), MEAT.darkened(0.2), dry + Vector3(-0.6 + k * 0.6, 1.38, 0), Vector3.ZERO, Vector3(0.8, 1.6, 0.6))
	_blocks.append([Vector2(dry.x, dry.z), 1.0])
	_spot("drying", dry + Vector3(0, 0, 1.3))
	_drying_fish = [dry]
	# THE PILES: wood, stones, bones (the bones grow with what he has gathered)
	var piles := Vector3(4.6, FLOOR_Y, -17.4)
	var bones := clampi(GameState.bones / 5 + 2, 2, 14)
	for k in bones:
		_shape(_cyl(0.06, 0.95, 5), BONE, piles + Vector3(-1.0 + (k % 4) * 0.15, 0.1 + (k / 4) * 0.12, (k % 3) * 0.12), Vector3(0, k * 37.0, 85))
	for k in 6:
		_shape(_cyl(0.11, 1.1, 7), WOOD, piles + Vector3(0.35, 0.12 + (k / 3) * 0.2, -0.3 + (k % 3) * 0.24), Vector3(90, 0, 0))
	for k in 5:
		_shape(_ball(0.21, 6), ROCK, piles + Vector3(1.3 + (k % 2) * 0.3, 0.16 + (k / 2) * 0.18, -0.2 + (k % 3) * 0.2))
	_blocks.append([Vector2(piles.x + 0.3, piles.z), 1.4])
	_spot("piles", piles + Vector3(0, 0, 1.4))
	# THE WORKBENCH: a flat slab on two rocks, flint and a hammerstone on it, a spear half made
	var b := BENCH
	for px3 in [-0.7, 0.7]:
		_shape(_ball(0.35, 7), ROCK_DARK, b + Vector3(px3, 0.28, 0), Vector3.ZERO, Vector3(1.0, 0.9, 0.9))
	_box(Vector3(2.0, 0.16, 0.9), ROCK.lightened(0.08), b + Vector3(0, 0.62, 0), self)
	for k2 in 3:
		_shape(_ball(0.09, 5), Color("6f6a66"), b + Vector3(-0.6 + k2 * 0.22, 0.75, 0.1), Vector3(0, k2 * 50.0, 0), Vector3(1.3, 0.6, 1.0))
	_shape(_ball(0.12, 6), Color("8a8580"), b + Vector3(0.1, 0.77, -0.15))
	_shape(_cyl(0.025, 1.3, 5), WOOD, b + Vector3(0.45, 0.74, 0.15), Vector3(0, 30, 90))
	_shape(_cone(0.05, 0.16, 5), Color("4a4a50"), b + Vector3(1.05, 0.74, 0.5), Vector3(0, 30, -90))
	_blocks.append([Vector2(b.x, b.z), 1.1])
	_spot("bench", b + Vector3(0, 0, 1.4))


## Kekko (a 3D placeholder until his cut-out): tiny, old, a cloak, a staff,
## a pack bigger than he is, and his monkey on top.
func _kekko(at: Vector3) -> void:
	_shape(_cone(0.36, 1.0, 10), Color("6a4a6a"), at + Vector3(0, 0.5, 0))
	_shape(_ball(0.17, 8), Color("c89263"), at + Vector3(0, 1.08, 0.04))
	_shape(_ball(0.12, 7), Color("e6e0d4"), at + Vector3(0, 0.98, 0.14), Vector3.ZERO, Vector3(1.1, 1.3, 0.6))
	_shape(_cone(0.2, 0.32, 8), Color("4a3a5a"), at + Vector3(0, 1.32, 0))
	_shape(_ball(0.5, 8), HIDE.darkened(0.25), at + Vector3(0.05, 1.0, -0.45), Vector3.ZERO, Vector3(1.0, 1.4, 0.9))
	for k in 3:
		_shape(_cyl(0.05, 0.9, 5), WOOD, at + Vector3(-0.35 + k * 0.35, 1.6, -0.45), Vector3(0, 0, 0))
	_shape(_cyl(0.035, 1.6, 5), WOOD.lightened(0.1), at + Vector3(0.4, 0.8, 0.15), Vector3(0, 0, -6))
	var monkey := Color("6a4a2a")
	_shape(_ball(0.14, 7), monkey, at + Vector3(0.05, 1.92, -0.45))
	_shape(_ball(0.1, 7), monkey, at + Vector3(0.05, 2.12, -0.38))
	_shape(_ball(0.06, 6), Color("c8a27a"), at + Vector3(0.05, 2.1, -0.29))
	_blocks.append([Vector2(at.x, at.z), 0.55])


## ------------------------------------------------------------------ the pier and fishing
func _build_pier() -> void:
	var start := Vector3(PIER.x, height(PIER.x, PIER.y), PIER.y)
	for k in 12:
		var z := PIER.y + k * 1.0
		_box(Vector3(1.8, 0.12, 0.9), Color("8a6440").darkened((k % 3) * 0.06), Vector3(PIER.x, 0.6, z), self)
		if k % 2 == 0:
			for px in [-0.85, 0.85]:
				_shape(_cyl(0.1, 2.0, 6), WOOD, Vector3(PIER.x + px, -0.3, z))
	_shape(_cyl(0.13, 1.2, 6), WOOD, Vector3(PIER.x + 0.85, 1.1, PIER.y + 11.0))
	_spot("pier", Vector3(PIER.x, 0, PIER.y + 9.5))
	# a little raft tied to it
	for k in 5:
		_shape(_cyl(0.15, 2.2, 7), WOOD.lightened(0.05), Vector3(PIER.x + 2.4 + k * 0.3, 0.12, PIER.y + 7.0), Vector3(90, 0, 0))
	_float = _shape(_ball(0.1, 8), Color("e8dcc0"), Vector3(PIER.x, 0.1, PIER.y + 15.0))
	_float.visible = false
	_line = _shape(_cyl(0.008, 1.0, 4), Color(0.9, 0.9, 0.9), Vector3.ZERO)
	_line.visible = false


## ------------------------------------------------------------------ sky, sun, stars, clouds, birds
func _build_sky() -> void:
	var we := WorldEnvironment.new()
	_env = Environment.new()
	var sky := Sky.new()
	_sky = ProceduralSkyMaterial.new()
	_sky.sun_angle_max = 8.0
	sky.sky_material = _sky
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_sky_contribution = 0.6
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 0.95
	_env.glow_enabled = true
	_env.glow_intensity = 0.45
	_env.glow_bloom = 0.08
	_env.glow_hdr_threshold = 1.0
	_env.fog_enabled = true
	_env.fog_density = 0.0022
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 1.12
	_env.adjustment_contrast = 1.05
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 60.0
	_sun.shadow_blur = 1.5
	add_child(_sun)
	_cam = Camera3D.new()
	_cam.fov = 42.0
	_cam.far = 800.0
	add_child(_cam)
	# the moon, and stars on a dome (seen at night)
	var moon := _shape(_ball(6.0, 16), Color.WHITE, Vector3(-90, 80, -200))
	moon.material_override = _glow(Color("f6f0d8"), 2.2)
	var star_mesh := QuadMesh.new()
	star_mesh.size = Vector2(0.9, 0.9)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = star_mesh
	mm.instance_count = 700
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for i in mm.instance_count:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.12, 1.0), rng.randf_range(-1, 0.4)).normalized()
		var p := dir * 380.0
		var s := rng.randf_range(0.6, 1.8)
		mm.set_instance_transform(i, Transform3D(Basis.looking_at(-dir).scaled(Vector3(s, s, s)), p))
	_stars = MultiMeshInstance3D.new()
	_stars.multimesh = mm
	_star_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded, cull_disabled;\nuniform float night = 1.0;\nvoid fragment() {\n\tfloat d = length(UV - vec2(0.5));\n\tfloat tw = 0.7 + 0.3 * sin(TIME * 2.0 + FRAGCOORD.x * 0.05);\n\tALBEDO = vec3(1.0, 0.97, 0.9) * 2.0;\n\tALPHA = (1.0 - smoothstep(0.1, 0.5, d)) * night * tw;\n}\n"
	_star_mat.shader = sh
	_stars.material_override = _star_mat
	_stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_stars)


func _build_sky_life() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 9:
		var cl := Node3D.new()
		cl.position = Vector3(rng.randf_range(-120, 120), rng.randf_range(34, 48), rng.randf_range(-140, -20))
		add_child(cl)
		for k in 5:
			var puff := _shape(_ball(rng.randf_range(3.0, 5.5), 10), Color.WHITE, Vector3(k * 4.0 - 8.0, rng.randf_range(-1, 1.5), rng.randf_range(-2, 2)), Vector3.ZERO, Vector3(1.3, 0.6, 1.0), cl)
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(1, 1, 1, 0.85)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			puff.material_override = m
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_clouds.append([cl, rng.randf_range(0.6, 1.4)])
	# birds wheeling over the ridge
	for i in 5:
		var b := Node3D.new()
		add_child(b)
		for side in [-1.0, 1.0]:
			_box(Vector3(0.7, 0.03, 0.18), Color("2a2a32"), Vector3(side * 0.32, 0, 0), b).rotation_degrees = Vector3(0, 0, side * 18.0)
		_birds.append([b, rng.randf() * TAU, rng.randf_range(10.0, 22.0), rng.randf_range(16.0, 24.0), rng.randf_range(0.25, 0.45)])
	# fireflies over the grass at night
	_fireflies = _particles(90, 5.0, Color("d8ff8a"), 0.04, 0.07, true)
	_fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_fireflies.emission_box_extents = Vector3(30, 1.0, 22)
	_fireflies.position = Vector3(0, 2.0, 0)
	_fireflies.gravity = Vector3.ZERO
	_fireflies.spread = 180.0
	_fireflies.initial_velocity_min = 0.1
	_fireflies.initial_velocity_max = 0.4
	add_child(_fireflies)


## Day and night: everything follows `_night` (0 noon, 1 deep night).
func _apply_daylight(_force := false) -> void:
	var n := _night
	var day_top := Color("4f8fd6")
	var day_hz := Color("a8d0e8")
	var dusk_top := Color("2a2f5a")
	var dusk_hz := Color("e08a6a")
	var night_top := Color("0a0d22")
	var night_hz := Color("26284a")
	var top: Color
	var hz: Color
	if n < 0.5:
		top = day_top.lerp(dusk_top, n * 2.0)
		hz = day_hz.lerp(dusk_hz, n * 2.0)
	else:
		top = dusk_top.lerp(night_top, (n - 0.5) * 2.0)
		hz = dusk_hz.lerp(night_hz, (n - 0.5) * 2.0)
	_sky.sky_top_color = top
	_sky.sky_horizon_color = hz
	_sky.ground_horizon_color = hz.darkened(0.3)
	_sky.ground_bottom_color = top.darkened(0.5)
	_env.fog_light_color = top.lerp(hz, 0.3).darkened(0.1)
	_env.ambient_light_energy = lerpf(0.62, 0.35, n)
	var elev := lerpf(-62.0, -6.0, clampf(n * 1.25, 0.0, 1.0))
	_sun.rotation_degrees = Vector3(elev, -40.0, 0)
	_sun.light_color = Color("fff1d6").lerp(Color("ff9a5a"), clampf(n * 1.6, 0.0, 1.0)).lerp(Color("6a7ab8"), clampf((n - 0.6) * 2.5, 0.0, 1.0))
	_sun.light_energy = lerpf(1.15, 0.25, n)
	_star_mat.set_shader_parameter("night", clampf((n - 0.55) * 2.6, 0.0, 1.0))
	for m in _water_mats:
		(m as ShaderMaterial).set_shader_parameter("night", clampf(n, 0.0, 1.0))
	_foam_mat.set_shader_parameter("night", n)
	_fall_mat.set_shader_parameter("night", n)
	_fireflies.emitting = n > 0.6


## ------------------------------------------------------------------ fire
func _fire(at: Vector3, s: float) -> void:
	for k in 3:
		var fl := _shape(_cone((0.26 - k * 0.06) * s, (0.7 + k * 0.16) * s, 7), Color.WHITE, at + Vector3(0, (0.34 + k * 0.05) * s, 0))
		fl.material_override = _glow([Color("ff5a10"), Color("ffa020"), Color("fff0a0")][k], 3.0)
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flames.append([fl, s, k])
	var l := OmniLight3D.new()
	l.light_color = Color("ff9a3c")
	l.light_energy = 2.6 * s
	l.omni_range = 10.0 * s
	l.shadow_enabled = s >= 1.0
	l.position = at + Vector3(0, 1.0 * s, 0)
	add_child(l)
	_fire_lights.append([l, 2.6 * s])
	var em := _particles(int(26 * s) + 4, 1.6, Color("ffb347"), 0.04 * s, 0.07 * s, true)
	em.direction = Vector3.UP
	em.spread = 20.0
	em.gravity = Vector3(0, 0.7, 0)
	em.initial_velocity_min = 0.6
	em.initial_velocity_max = 1.4
	em.position = at + Vector3(0, 0.5 * s, 0)
	add_child(em)
	if s >= 1.0:
		_embers = em
		var smoke := _particles(14, 3.5, Color(0.35, 0.33, 0.32, 0.25), 0.25, 0.6, false)
		smoke.direction = Vector3.UP
		smoke.spread = 10.0
		smoke.gravity = Vector3(0.1, 0.4, 0)
		smoke.initial_velocity_min = 0.6
		smoke.initial_velocity_max = 1.0
		smoke.position = at + Vector3(0, 1.5, 0)
		add_child(smoke)


## ------------------------------------------------------------------ helpers
func _particles(amount: int, life: float, col: Color, s0: float, s1: float, glow: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 6
	m.rings = 3
	p.mesh = m
	if glow:
		p.material_override = _glow(col, 3.0)
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		p.material_override = mat
	p.scale_amount_min = s0 * 2.0
	p.scale_amount_max = s1 * 2.0
	return p


## PERFORMANCE: every shape is built with its own material (_mat), so each would
## be its own draw call (~1400). Once the home is built, every plain shape that
## never moves (rock, bone, wood, the props) is merged into ONE mesh with its
## colour in the vertices (two: shadow-casting or not). What moves, fades, glows
## or uses a shader keeps its own node: Ugu, the pup, the fishing float and line,
## the trees that fade (occluders), flames, spits, clouds, birds. The merged
## originals keep their nodes (children, references) and just lose their mesh.
var _baked := 0                  ## how many shapes were merged (homecost prints it)

func _bake_static() -> void:
	var skip := {}
	for n in [_model, _pup, _float, _line]:
		if n != null:
			skip[(n as Node).get_instance_id()] = true
	for group in [_flames, _clouds, _birds]:
		for e in group:
			skip[(e[0] as Node).get_instance_id()] = true
	for s in _spits:
		skip[(s as Node).get_instance_id()] = true
	for o in _occluders:
		skip[(o[0] as Node).get_instance_id()] = true
	var arrs := [_new_bake_arrays(), _new_bake_arrays()]       # [casts shadows, does not]
	_bake_walk(self, skip, arrs, global_transform.affine_inverse())
	for k in 2:
		_add_baked(self, arrs[k], k == 0)
	# each tree that fades in front of him: merged into one mesh of its own; its
	# fade (_fade_occluders) then sets the alpha of that one material
	for o in _occluders:
		var tree: Node3D = o[0]
		var ta := _new_bake_arrays()
		var tskip := {}
		_bake_walk(tree, tskip, [ta, ta], tree.global_transform.affine_inverse())
		var mats: Array = []
		var mi := _add_baked(tree, ta, true)
		if mi != null:
			mats.append(mi.material_override)
		for rest in tree.find_children("*", "MeshInstance3D", true, false):
			var r := rest as MeshInstance3D
			if r != mi and r.mesh != null and r.material_override is StandardMaterial3D:
				mats.append(r.material_override)
		o[3] = mats


## One merged mesh (vertex colours) under `parent`, or null if there was nothing.
func _add_baked(parent: Node3D, a: Array, shadows: bool) -> MeshInstance3D:
	if (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
		return null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true          # (albedo x vertex colour: white, its alpha fades it)
	mat.roughness = 0.85
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _new_bake_arrays() -> Array:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	a[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	a[Mesh.ARRAY_COLOR] = PackedColorArray()
	a[Mesh.ARRAY_INDEX] = PackedInt32Array()
	return a


func _bake_walk(node: Node, skip: Dictionary, arrs: Array, inv: Transform3D) -> void:
	for c in node.get_children():
		if skip.has(c.get_instance_id()):
			continue
		var mi := c as MeshInstance3D
		if mi != null and _bakeable(mi):
			var xf := inv * mi.global_transform
			var col: Color = (mi.material_override as StandardMaterial3D).albedo_color
			var off := mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var a: Array = arrs[1 if off else 0]
			var nb := xf.basis.inverse().transposed()
			for s in mi.mesh.get_surface_count():
				var src := mi.mesh.surface_get_arrays(s)
				var verts: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
				var norms: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
				var idx: PackedInt32Array = src[Mesh.ARRAY_INDEX]
				# (take each array out and empty its slot, so appending does not copy it)
				var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
				var cl: PackedColorArray = a[Mesh.ARRAY_COLOR]
				var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
				a[Mesh.ARRAY_VERTEX] = null
				a[Mesh.ARRAY_NORMAL] = null
				a[Mesh.ARRAY_COLOR] = null
				a[Mesh.ARRAY_INDEX] = null
				var base := v.size()
				for i in verts.size():
					v.append(xf * verts[i])
				for i in norms.size():
					n.append((nb * norms[i]).normalized())
				for i in verts.size():
					cl.append(col)
				if idx.is_empty():
					for i in verts.size():
						ix.append(base + i)
				else:
					for i in idx.size():
						ix.append(base + idx[i])
				a[Mesh.ARRAY_VERTEX] = v
				a[Mesh.ARRAY_NORMAL] = n
				a[Mesh.ARRAY_COLOR] = cl
				a[Mesh.ARRAY_INDEX] = ix
			mi.mesh = null
			_baked += 1
		_bake_walk(c, skip, arrs, inv)


## A plain, still, opaque, solid-coloured shape (what _mat makes), seen, with normals.
func _bakeable(mi: MeshInstance3D) -> bool:
	if mi.mesh == null or not mi.is_visible_in_tree() or mi.mesh is ArrayMesh and mi.mesh.get_surface_count() == 0:
		return false
	var m := mi.material_override as StandardMaterial3D
	if m == null or m.emission_enabled or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or m.albedo_texture != null \
			or m.vertex_color_use_as_albedo or m.cull_mode != BaseMaterial3D.CULL_BACK or m.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL:
		return false
	for s in mi.mesh.get_surface_count():
		if mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return false                            # (the built-in shapes are always triangles)
		if (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_NORMAL] as PackedVector3Array).is_empty():
			return false
	return true


func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	return m


func _glow(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _shape(mesh: Mesh, col: Color, at: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = _mat(col)
	m.position = at
	m.rotation_degrees = rot
	m.scale = scl
	(parent if parent != null else self).add_child(m)
	return m


func _box(size: Vector3, col: Color, at: Vector3, parent: Node3D) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _shape(b, col, at, Vector3.ZERO, Vector3.ONE, parent)


func _cone(r: float, h: float, segs := 8) -> CylinderMesh:
	return _cyl(r, h, segs, 0.0)


func _cyl(r: float, h: float, segs := 7, top := -1.0) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r if top < 0.0 else top
	c.bottom_radius = r
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


func _ball(r: float, segs := 6) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = maxi(3, segs / 2)
	return s


func _spot(id: String, at: Vector3) -> void:
	var l := Label3D.new()
	l.text = LINES[id][0]
	l.font = Pal.title_font()
	l.font_size = 64
	l.pixel_size = 0.006
	l.outline_size = 14
	l.modulate = Color("ffe066")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.visible = false
	l.position = Vector3(at.x, maxf(height(at.x, at.z), 0.6) + 2.7, at.z)
	add_child(l)
	_spots.append([id, Vector2(at.x, at.z), l])


## A 2D drawing (feet at its origin) stood up in the world as a paper cut-out, `h` metres tall.
func _cutout(drawing: Node2D, h: float) -> Sprite3D:
	var vp := SubViewport.new()
	vp.size = Vector2i(320, 320)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	drawing.position = Vector2(160, 300)
	drawing.scale = Vector2(2.6, 2.6)
	vp.add_child(drawing)
	var s := Sprite3D.new()
	s.texture = vp.get_texture()
	s.pixel_size = h / (78.0 * 2.6)
	s.offset = Vector2(0, 160 - 20)
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(s)
	return s


## ------------------------------------------------------------------ Ugu
func _build_ugu() -> void:
	_model = UguModel.new()
	_model.era = _era
	add_child(_model)
	_rig = CaveMan.new()
	_rig.preview = true                      # never shown: Bag counts and crafts through it
	GameState.apply_to(_rig)
	_pos.y = height(_pos.x, _pos.z)
	_model.position = _pos
	_model.rotation.y = PI                   # facing the camera to start
	# a soft warm light that walks with him (stronger at night): he is never lost in a shadow
	_glow_light = OmniLight3D.new()
	_glow_light.light_color = Color("ffd9a8")
	_glow_light.omni_range = 4.0
	_glow_light.position = Vector3(0, 1.7, 1.2)
	add_child(_glow_light)


func _exit_tree() -> void:
	if _rig != null:
		_rig.free()


## Trees (and the cave's roof) fade out while they stand between the camera and
## him, and come back when he has passed: he is never hidden.
func _occluder(node: Node3D, at: Vector2, radius: float) -> void:
	var mats: Array = []
	var meshes: Array = [node] if node is MeshInstance3D else []
	for c in node.get_children():
		if c is MeshInstance3D:
			meshes.append(c)
	for m in meshes:
		var mat := (m as MeshInstance3D).material_override as StandardMaterial3D
		if mat != null:
			mats.append(mat)
	_occluders.append([node, at, radius, mats, 1.0])


func _fade_occluders(delta: float) -> void:
	var cam := Vector2(_cam.position.x, _cam.position.z)
	var me := Vector2(_pos.x, _pos.z)
	for o in _occluders:
		var at: Vector2 = o[1]
		var want := 1.0
		if at.distance_to(me) < 16.0:
			var to_me := me - cam
			var k := clampf((at - cam).dot(to_me) / to_me.length_squared(), 0.0, 1.0)
			var close := at.distance_to(cam + to_me * k)
			if k > 0.05 and k < 0.98 and close < float(o[2]) + 0.7:
				want = 0.22
		var a: float = move_toward(float(o[4]), want, delta * 3.0)
		if a == float(o[4]):
			continue
		o[4] = a
		for mat in o[3]:
			var m := mat as StandardMaterial3D
			m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if a >= 0.999 else BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = a


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	_ui_label(ui, Vector2(24, 14), Vector2(800, 40), 30, Color("ffcf40"), Pal.title_font()).text = "UGU'S CAVE"
	_ui_label(ui, Vector2(24, 54), Vector2(900, 30), 16, Color("d8c8b0"), Pal.text_font()).text = "Arrows: walk     Space: jump     E: use     P: 3D / paper Ugu     Esc: back to the level"
	_hint = _ui_label(ui, Vector2(140, 646), Vector2(1000, 50), 21, Color("f3e3c3"), Pal.text_font())
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_say = _ui_label(ui, Vector2(190, 560), Vector2(900, 70), 24, Color("ffe066"), Pal.title_font())
	_say.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_fade)
	var stats := _ui_label(ui, Vector2(940, 18), Vector2(320, 30), 18, Color("f3e3c3"), Pal.text_font())
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats.set_meta("stats", true)
	_stats = stats


var _stats: Label


func _ui_label(ui: Node, at: Vector2, size: Vector2, fs: int, col: Color, font: Font) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 9)
	l.position = at
	l.size = size
	ui.add_child(l)
	return l


func say(text: String) -> void:
	_say.text = text
	_say_t = 3.2


## ------------------------------------------------------------------ E: what he does
func use() -> void:
	if _menu != null:
		return
	if _fish_state == "bite":
		_reel()
		return
	if _fish_state == "wait":
		return
	match _near:
		"closet":
			var owned: Array = GameState.skins.duplicate()
			if not owned.has("plain"):
				owned.insert(0, "plain")
			var i := (owned.find(GameState.skin) + 1) % owned.size()
			GameState.skin = owned[i]
			GameState.save()
			_model.refresh()
			say(("Today: %s!" % _skin_name(GameState.skin)) if owned.size() > 1 else "Only one costume so far. Trade for more in the levels!")
			_focus = 1.5
		"weapons":
			var ws: Array = GameState.weapons
			var j := (ws.find(GameState.weapon) + 1) % ws.size()
			GameState.weapon = ws[j]
			GameState.save()
			_model.refresh()
			say(("He'll carry the %s." % Bag.name_of(GameState.weapon)) if ws.size() > 1 else "Just the club so far. The Toolmaker sells an axe!")
			_focus = 1.5
		"bed":
			_sleep()
		"fire":
			if _fish > 0:
				_fish -= 1
				_flare = 1.2
				if GameState.figs < GameState.fig_max():
					GameState.figs += 1
					GameState.save()
					say("Fish on the fire... sizzle... a hot meal for the road!  (+1 fig)")
				else:
					say("Fish on the fire... he eats it right here. Yum. (Your fig pouch is full.)")
			else:
				_flare = 2.5
				say("WHOOMPH!  (Catch a fish at the pier: cook it here for the road.)")
			_focus = 1.2
		"pup":
			_fetch()
		"kekko":
			_open_menu("KEKKO'S STALL", "\"Pebbles, gems, shiny things! I buy, I sell. Fair prices... mostly.\"", Color("ffcf40"), _kekko_rows)
		"forge":
			_toolmaker.forging = 2.0
			_open_menu("THE TOOLMAKER", _toolmaker_line(), Color("ff8a4a"), _toolmaker_rows)
		"bench":
			_open_menu("THE WORKBENCH", "Make things from what's in the bag. (Rocks, wood and berries are gathered in the levels.)", Color("9be15d"), _bench_rows)
		"store":
			_open_menu("THE STORE CORNER", "Everything brought home, in baskets and pots.", Color("6cc4ff"), _store_rows)
		"paint":
			_open_menu("THE PAINTED WALL", "Every mystery he has met, in ochre.", Color("e0663a"), _paint_rows)
		"pier":
			_cast()
		_:
			pass


func _skin_name(id: String) -> String:
	return {"plain": "PLAIN HIDE", "wolf_hood": "WOLF HOOD", "ember_paint": "EMBER PAINT", "bear_cloak": "BEAR CLOAK",
		"firekeeper": "FIREKEEPER", "war_paint": "WAR PAINT", "bone_necklace": "BONE NECKLACE"}.get(id, id.to_upper())


## ------------------------------------------------------------------ the menus
## What something costs: the same rule as Level 2's shop (a fraction of the
## level's treasure, ECONOMY), so home and the level agree.
const TREASURE := 832
const PRICE := {"fig": 0.04, "heart": 0.20, "torch": 0.12, "pouch": 0.12, "axe": 0.34}
const STONE_BUY := {"clay": 5, "flint": 8, "pyrite": 30, "quartz": 40}
const STONE_SELL := {"pyrite": 15, "quartz": 20, "obsidian": 30}

var _menu: CanvasLayer


func price(id: String) -> int:
	var f: float = PRICE.get(id, 0.0)
	if id == "heart" and int(GameState.upgrades["heart"]) >= 1:
		f *= 1.5
	return int(round(TREASURE * f / 5.0)) * 5


func _open_menu(title: String, line: String, accent: Color, rows: Callable) -> void:
	_menu = Menu.new()
	_menu.title = title
	_menu.line = line
	_menu.accent = accent
	_menu.rows_fn = rows
	_menu.closed.connect(func() -> void:
		_menu = null
		_focus = 0.6
		if _toolmaker != null:
			_toolmaker.speaking = false)
	add_child(_menu)
	_focus = 999.0
	if _toolmaker != null and title == "THE TOOLMAKER":
		_toolmaker.speaking = true


func _spend(n: int) -> bool:
	if GameState.shells < n:
		return false
	GameState.shells -= n
	return true


func _kekko_rows() -> Array:
	var rows: Array = []
	var fp := price("fig")
	var full := GameState.figs >= GameState.fig_max()
	rows.append(["Roast fig  (%d / %d)" % [GameState.figs, GameState.fig_max()], "pouch full" if full else "%d shells" % fp, not full and GameState.shells >= fp, func():
		_spend(fp)
		GameState.figs += 1
		GameState.save()
		return "A roast fig! Eat it with H in the levels."])
	for id in STONE_BUY:
		var p: int = STONE_BUY[id]
		rows.append(["Buy %s  (have %d)" % [Bag.name_of(id), Bag.count(null, id)], "%d shells" % p, GameState.shells >= p, func():
			_spend(p)
			Bag.add(id)
			return "+1 %s" % Bag.name_of(id)])
	for id2 in STONE_SELL:
		var have := Bag.count(null, id2)
		var p2: int = STONE_SELL[id2]
		rows.append(["Sell %s  (have %d)" % [Bag.name_of(id2), have], "+%d shells" % p2, have > 0, func():
			GameState.bag[id2] = have - 1
			GameState.shells += p2
			Bag.version += 1
			GameState.save()
			return "+%d shells" % p2])
	return rows


func _toolmaker_line() -> String:
	var g := str(GameState.gems.get("level2", ""))
	if g == "found" and not GameState.weapons.has("hammer"):
		return "\"You have the Firestone! Bring it to my forge in the Long Dark, and I'll make a hammer of it.\""
	if GameState.weapons.has("hammer"):
		return "\"The hammer still burns? Good. Every land hides a gem: find me the next one.\""
	return "\"Every land hides a gem. Find it, and I'll make a legend of it. Meanwhile: upgrades.\""


func _toolmaker_rows() -> Array:
	var rows: Array = []
	var names := {"heart": "An extra heart", "torch": "A long-burning torch", "pouch": "A bigger pouch"}
	for id in names:
		var lvl: int = GameState.upgrades[id]
		var mx: int = GameState.UPGRADE_MAX[id]
		var p := price(id)
		var maxed := lvl >= mx
		rows.append(["%s  (%d / %d)" % [names[id], lvl, mx], "done" if maxed else "%d shells" % p, not maxed and GameState.shells >= p, func():
			_spend(p)
			GameState.upgrades[id] = lvl + 1
			GameState.save()
			_toolmaker.forging = 1.5
			return "Clang, clang... done! It's his for good."])
	var has_axe := GameState.weapons.has("axe")
	var pa := price("axe")
	rows.append(["The Flint Axe", "owned" if has_axe else "%d shells" % pa, not has_axe and GameState.shells >= pa, func():
		_spend(pa)
		GameState.weapons.append("axe")
		GameState.save()
		_toolmaker.forging = 1.5
		return "A Flint Axe! Carry it from the weapon rack."])
	return rows


## The workbench: the bag's recipes that need only what's kept at home
## (stones, bones): rocks, wood and berries are carried in the levels only.
func _bench_rows() -> Array:
	var rows: Array = []
	for r in Bag.RECIPES:
		var id: String = r[0]
		var needs: Dictionary = r[2]
		if needs.has("rocks") or needs.has("wood") or needs.has("berries"):
			continue
		var made_for_good := Bag.FOREVER.has(id) and GameState.has_item(Bag.FOREVER[id])
		var parts: Array = []
		for k in needs:
			parts.append("%d %s" % [needs[k], Bag.name_of(k).to_lower()])
		var miss := "" if made_for_good else Bag.missing(_rig, id)
		rows.append(["%s  (%s)" % [Bag.name_of(id), ", ".join(parts)], "made" if made_for_good else ("make" if miss == "" else miss), not made_for_good and miss == "", func():
			Bag.craft(_rig, id)
			return "Made: %s!" % Bag.name_of(id)])
	return rows


func _store_rows() -> Array:
	var rows: Array = []
	for id in GameState.bag:
		if int(GameState.bag[id]) > 0:
			rows.append([Bag.name_of(id), "x%d" % int(GameState.bag[id]), false, null])
	for k in GameState.relics:
		rows.append(["%s (a rare find)" % Relics.name_of(k), "x%d" % int(GameState.relics[k]), false, null])
	rows.append(["Bones", "x%d" % GameState.bones, false, null])
	rows.append(["Spirit orbs", "x%d" % GameState.orbs, false, null])
	for t in GameState.trophies:
		rows.append(["Trophy: %s" % str(t).replace("_", " "), "", false, null])
	return rows


func _paint_rows() -> Array:
	var rows: Array = []
	for id in GameState.mysteries:
		var solved: bool = GameState.mysteries[id] == "solved"
		var words: Array = CampMenu.MYSTERIES.get(id, [id, id])
		rows.append([str(words[1] if solved else words[0]).left(46), "SOLVED" if solved else "open", false, null])
	if rows.is_empty():
		rows.append(["No mysteries yet. Go and find some!", "", false, null])
	return rows


## ------------------------------------------------------------------ the pup fetches
var _stick: MeshInstance3D
var _fetch_state := ""          ## "", "fly", "run", "back"
var _fetch_to := Vector3.ZERO
var _fetch_t := 0.0
var _fetches := 0


func _fetch() -> void:
	if _fetch_state != "":
		return
	if _stick == null:
		_stick = _shape(_cyl(0.035, 0.6, 5), WOOD, Vector3.ZERO)
	var ahead := Vector3(sin(_model.rotation.y), 0, cos(_model.rotation.y))
	_fetch_to = _pos + ahead * randf_range(5.0, 8.0)
	_fetch_to.y = height(_fetch_to.x, _fetch_to.z) + 0.05
	_stick.position = _pos + Vector3(0, 1.4, 0)
	_stick.visible = true
	_fetch_t = 0.0
	_fetch_state = "fly"
	_pup_hop = 0.5
	say("Fetch!")


func _fetch_step(delta: float) -> void:
	match _fetch_state:
		"fly":
			_fetch_t += delta / 0.7
			var from := _pos + Vector3(0, 1.4, 0)
			var p := from.lerp(_fetch_to, minf(_fetch_t, 1.0))
			p.y += sin(minf(_fetch_t, 1.0) * PI) * 2.0
			_stick.position = p
			_stick.rotation.z += delta * 14.0
			if _fetch_t >= 1.0:
				_stick.position = _fetch_to
				_stick.rotation = Vector3(0, 0, PI * 0.5)
				_fetch_state = "run"
		"run", "back":
			var target := _fetch_to if _fetch_state == "run" else _pos + Vector3(0.7, 0, 0.7)
			var flat := Vector3(target.x - _pup.position.x, 0, target.z - _pup.position.z)
			if flat.length() < 0.5:
				if _fetch_state == "run":
					_fetch_state = "back"
				else:
					_fetch_state = ""
					_stick.visible = false
					_fetches += 1
					_hearts.position = _pup.position + Vector3(0, 0.7, 0)
					_hearts.restart()
					say(["Good pup!", "He brought it back!", "Again? Again!", "Best pup on the island!"][_fetches % 4])
				return
			var step := flat.normalized() * 7.0 * delta
			_pup.position += step
			_pup.position.y = height(_pup.position.x, _pup.position.z) + absf(sin(_t * 18.0)) * 0.12
			_pup.rotation.y = atan2(step.x, step.z) - PI * 0.5
			if _fetch_state == "back":
				_stick.position = _pup.position + Vector3(0, 0.35, 0)


func _sleep() -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.7)
	tw.tween_callback(func() -> void:
		_night_to = 0.12 if _night > 0.5 else 0.82
		_night = _night_to
		GameState.save()
		_apply_daylight()
		say("Good morning!" if _night < 0.5 else "The sun's down. Fire's lit."))
	tw.tween_interval(0.5)
	tw.tween_property(_fade, "color:a", 0.0, 0.9)


func _cast() -> void:
	_fish_state = "wait"
	_fish_t = randf_range(1.5, 3.5)
	_float.position = Vector3(PIER.x + randf_range(-1.0, 1.0), 0.12, PIER.y + 15.0)
	_float.visible = true
	_line.visible = true
	say("Cast...")
	_focus = 6.0


func _reel() -> void:
	_fish_state = ""
	_float.visible = false
	_line.visible = false
	_fish_caught += 1
	_fish += 1
	var dry: Vector3 = _drying_fish[0]
	var k := _fish_caught
	_shape(_ball(0.14, 6), Color("9aa8b8"), dry + Vector3(-0.85 + (k % 6) * 0.3, 1.25, 0.08), Vector3.ZERO, Vector3(0.6, 1.8, 0.4))
	_splash.position = _float.position
	_splash.restart()
	say(["A FISH! Off to the drying rack.", "Another one! Ugu, master fisher.", "A BIG one! Well... medium."][k % 3])
	_focus = 1.5


## ------------------------------------------------------------------ every frame
func _process(delta: float) -> void:
	_t += delta
	var dir := Vector3.ZERO
	if _fish_state == "" and _menu == null:
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			dir.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			dir.x += 1.0
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			dir.z -= 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			dir.z += 1.0
	walk(dir, delta)
	_animate(delta)


func _animate(delta: float) -> void:
	_focus = maxf(_focus - delta, 0.0)
	_say_t = maxf(_say_t - delta, 0.0)
	_say.modulate.a = clampf(_say_t / 0.4, 0.0, 1.0)
	if _say_t <= 0.0 and _toolmaker != null:
		_toolmaker.speaking = false
	_flare = maxf(_flare - delta, 0.0)
	var night_boost := lerpf(0.7, 1.35, _night)
	for f in _fire_lights:
		(f[0] as OmniLight3D).light_energy = float(f[1]) * night_boost * (1.0 + 0.15 * sin(_t * 11.0) + 0.08 * sin(_t * 23.0)) * (1.0 + _flare * 0.6)
	for fl in _flames:
		var m: MeshInstance3D = fl[0]
		var k: int = fl[2]
		var big := 1.0 + _flare * 0.5 * float(fl[1])
		m.scale = Vector3(1, 1.0 + 0.18 * sin(_t * (9.0 + k * 3.0) + k), 1) * big
		m.rotation.y += delta * (1.5 + k)
	if _embers != null:
		_embers.speed_scale = 1.0 + _flare * 0.8          # the flare: embers fly faster and higher
	for s in _spits:
		(s as Node3D).rotate_object_local(Vector3(1, 0, 0), delta * 0.8)
	for c in _clouds:
		var cl: Node3D = c[0]
		cl.position.x += delta * float(c[1]) * 1.2
		if cl.position.x > 160.0:
			cl.position.x = -160.0
	for b in _birds:
		b[1] = float(b[1]) + delta * float(b[4])
		var a: float = b[1]
		var bird: Node3D = b[0]
		bird.position = Vector3(cos(a) * float(b[2]), float(b[3]) + sin(a * 2.0) * 1.5, -32.0 + sin(a) * float(b[2]) * 0.6)
		bird.rotation.y = -a
		bird.rotation.z = sin(_t * 8.0 + a) * 0.35
	if _pup != null:
		_pup_hop = maxf(_pup_hop - delta, 0.0)
		if _fetch_state == "":
			_pup.position.y = height(_pup.position.x, _pup.position.z) + absf(sin(_pup_hop * 12.0)) * 0.3 * minf(_pup_hop * 2.0, 1.0)
		else:
			_fetch_step(delta)
	_fade_occluders(delta)
	if _night != _night_to:
		_night = move_toward(_night, _night_to, delta * 0.2)
		_apply_daylight()
	# fishing: a bite after a while; too slow and it gets away
	if _fish_state == "wait":
		_fish_t -= delta
		_float.position.y = 0.12 + sin(_t * 3.0) * 0.03
		if _fish_t <= 0.0:
			_fish_state = "bite"
			_fish_t = 1.4
			say("A BITE!  E!")
	elif _fish_state == "bite":
		_fish_t -= delta
		_float.position.y = 0.05 + sin(_t * 30.0) * 0.08
		if _fish_t <= 0.0:
			_fish_state = ""
			_float.visible = false
			_line.visible = false
			say("It got away! Try again.")
	if _line.visible:
		var hand := _pos + Vector3(0, 1.3, 0.2)
		var to := _float.position
		_line.position = (hand + to) * 0.5
		_line.scale = Vector3(1, hand.distance_to(to), 1)
		_line.look_at_from_position(_line.position, to, Vector3.UP)
		_line.rotate_object_local(Vector3(1, 0, 0), PI * 0.5)
	# what he is next to
	var was := _near
	_near = ""
	var best := 2.0
	for sp in _spots:
		var d: float = Vector2(_pos.x, _pos.z).distance_to(sp[1])
		if d < best:
			best = d
			_near = sp[0]
	# the labels and texts change only when what they show changes (a Label re-lays
	# itself out on every text set)
	if _near != was or _hint.text == "" and _near != "":
		for sp2 in _spots:
			(sp2[2] as Label3D).visible = sp2[0] == _near
		_hint.text = ("%s  —  %s" % [LINES[_near][0], LINES[_near][1]]) if _near != "" else ""
	var stats := "Shells %d    Figs %d/%d    Bones %d" % [GameState.shells, GameState.figs, GameState.fig_max(), GameState.bones]
	if stats != _stats.text:
		_stats.text = stats


## One step: walking round things, jumping, on the ground's height.
func walk(dir: Vector3, delta: float) -> void:
	var moving := dir.length() > 0.01
	if moving:
		dir = dir.normalized()
		var next := _pos + dir * SPEED * delta
		var p := Vector2(next.x, next.z)
		var gh := height(p.x, p.y)
		var ok := gh > 0.0 and gh < _pos.y + 1.2 and p.length() < R
		if _on_pier(p):
			ok = true
			gh = 0.66
		for b in _blocks:
			if p.distance_to(b[0]) < float(b[1]) + 0.3:
				ok = false
		if ok:
			_pos.x = next.x
			_pos.z = next.z
		# he turns to face where he is going (smoothly, the short way round)
		var aim := atan2(dir.x, dir.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, aim, minf(1.0, delta * 12.0))
	var ground := 0.66 if _on_pier(Vector2(_pos.x, _pos.z)) else height(_pos.x, _pos.z)
	_vy -= GRAVITY * delta
	_pos.y += _vy * delta
	if _pos.y <= ground:
		if not _on_ground and _vy < -6.0:
			_dust()
		_pos.y = ground
		_vy = 0.0
		_on_ground = true
	else:
		_on_ground = _pos.y - ground < 0.05
	if ground < 0.25 and Vector2(_pos.x, _pos.z).distance_to(Vector2(POOL.x, POOL.z)) < 5.0 and moving and fmod(_t, 0.35) < delta:
		_splash.position = _pos
		_splash.restart()
	_model.speed = move_toward(_model.speed, 1.0 if moving else 0.0, delta * 6.0)
	_model.air = not _on_ground
	_model.position = _pos
	_glow_light.position = _pos + Vector3(0, 1.7, 1.2)
	_glow_light.light_energy = lerpf(0.25, 0.9, _night)
	_cam_k = move_toward(_cam_k, 1.0 if _focus > 0.0 else 0.0, delta * 1.6)
	var k := _cam_k * _cam_k * (3.0 - 2.0 * _cam_k)
	var want := _pos + CAM_FAR.lerp(CAM_NEAR, k)
	_cam.position = _cam.position.lerp(want, minf(1.0, delta * 3.5)) if _t > 0.1 else want
	_cam.look_at(_pos + Vector3(0, 1.0, -1.6))


func _on_pier(p: Vector2) -> bool:
	return absf(p.x - PIER.x) < 0.9 and p.y > PIER.y - 1.0 and p.y < PIER.y + 11.5


func _dust() -> void:
	var d := _particles(10, 0.5, Color(0.8, 0.72, 0.6, 0.6), 0.08, 0.18, false)
	d.one_shot = true
	d.explosiveness = 1.0
	d.direction = Vector3.UP
	d.spread = 80.0
	d.initial_velocity_min = 1.0
	d.initial_velocity_max = 2.0
	d.gravity = Vector3(0, -3, 0)
	d.position = _pos + Vector3(0, 0.05, 0)
	add_child(d)
	d.emitting = true
	get_tree().create_timer(1.0).timeout.connect(d.queue_free)


## ------------------------------------------------------------------ pictures
func _shots() -> void:
	DirAccess.make_dir_recursive_absolute("C:/tmp/shots")
	if OS.get_cmdline_user_args().has("paper"):
		swap_ugu()                          # the shots of the paper Ugu: home_paper_*
	for f in 40:
		await get_tree().process_frame
	await _shot("plaza")
	_pos = CAVE + Vector3(0, 0, 3.4)
	_t = 0.0
	_cam.position = _pos + CAM_FAR          # (snap: the shot is taken before a glide would arrive)
	for f in 30:
		await get_tree().process_frame
	await _shot("cave")
	_pos = Vector3(PIER.x, 0.66, PIER.y + 6.0)
	_t = 0.0
	_cam.position = _pos + CAM_FAR          # (snap: the shot is taken before a glide would arrive)
	for f in 20:
		await get_tree().process_frame
	await _shot("pier")
	set_process(false)
	_cam.position = Vector3(0, 70, 95)
	_cam.look_at(Vector3(0, 0, -6))
	await _shot("island_dusk")
	_night = 0.15
	_night_to = 0.15
	_apply_daylight()
	await _shot("island_day")
	_cam.position = Vector3(26, 9, 4)
	_cam.look_at(Vector3(POOL.x, 3, POOL.z - 4))
	await _shot("waterfall_day")
	# Ugu in 3D, close up (in daylight): front, three-quarter, side, running
	var at := Vector3(0, FLOOR_Y, -12)
	_model.position = at
	_model.speed = 0.0
	_model.air = false
	for v in [["ugu_front", 0.0, Vector3(0, 1.6, 3.1)], ["ugu_three_quarter", -0.6, Vector3(2.0, 1.6, 2.5)], ["ugu_side", -PI * 0.5, Vector3(3.2, 1.4, 0.3)]]:
		_model.rotation.y = v[1]
		_cam.position = at + (v[2] as Vector3)
		_cam.look_at(at + Vector3(0, 1.15, 0))
		for f in 4:
			await get_tree().process_frame
		await _shot(v[0])
	_model.speed = 1.0
	_model.rotation.y = -PI * 0.5
	for f in 9:
		await get_tree().process_frame
	await _shot("ugu_running")
	# behind a tree, from the game's camera: the tree fades
	set_process(true)
	_model.speed = 0.0
	var tree: Array = _occluders[0]
	for o in _occluders:
		if (o[0] as Node3D).get_parent() == self and o[2] < 2.0 and Vector2(o[1]).length() < 30.0:
			tree = o
			break
	var tp: Vector2 = tree[1]
	_pos = Vector3(tp.x, height(tp.x, tp.y - 1.6), tp.y - 1.6)
	_t = 0.0
	_cam.position = _pos + CAM_FAR
	for f in 60:
		await get_tree().process_frame
	await _shot("behind_tree")
	get_tree().quit()


func _shot(label: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/home_%s%s.png" % ["paper_" if _paper else "", label])
	print("shot ", label)
