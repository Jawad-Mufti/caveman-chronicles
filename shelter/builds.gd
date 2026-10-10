extends "res://shelter/system.gd"
## THE BONE BUILDS (docs/shelter_plan.md: "the cave GROWS with bones"): the
## bones he brings home build things round his cave, Ugu-style, eras 1-2 only
## (mammoth bones, hides, stone, fire). Until it is built, each one's place is
## marked: stakes, a rope, a hide sign with its price; E there (or the
## workshop's BUILD tab, shelter/workshop.gd) shows the plan, and BUILD pays
## the bones: it rises out of the ground in a cloud of dust. Built (saved in
## GameState.shelter["built"]):
## - THE HAMMOCK, on the beach by the pier: E: lie in it, swing, doze (and
##   watch the sun go down, or come up).
## - THE GATHERING FIRE, in the middle of the plaza: logs to sit on, hide drums:
##   E: BOOM! (every fire flares, the pup hops; four quick: he jumps for joy).
## - THE TUSK GATE, where the path leaves the plaza: two mammoth tusks arched
##   over it, a hide banner, and stone lamps all the way to the pier (they glow
##   at night).
## - THE BONE BRIDGE, over the stream: the way to the Moonpuff Grove
##   (shelter/nature.gd).
## - THE TROPHY TOTEM, by the pool: a carved head for every big beast beaten,
##   blank ones for the beasts to come.
## - THE LOOKOUT, in the west meadow: a tower of mammoth bones; E: climb the
##   ladder; on top the camera pulls back over the whole island.

## [id, name, bones, what it is, where it goes]. Cheap ones first: a quick win.
const BUILDS := [
	["hammock", "THE HAMMOCK", 20, "A hide slung between two palms by the sea. Lie back, swing, watch the sun go down.", "on the beach, by the pier"],
	["campfire", "THE GATHERING FIRE", 30, "A big fire in the middle of the plaza, logs round it to sit on, hide drums to bang. BOOM-BOOM!", "in the middle of the plaza"],
	["gate", "THE TUSK GATE", 40, "Two mammoth tusks arched over the path, and stone lamps that light the way to the pier at night.", "where the path leaves the plaza"],
	["bridge", "THE BONE BRIDGE", 50, "Bones lashed into a bridge over the stream. On the other side: the MOONPUFF GROVE!", "over the stream, past the pool"],
	["totem", "THE TROPHY TOTEM", 60, "A tall carved pole: a beast's head for every big beast he beats.", "by the pool"],
	["lookout", "THE LOOKOUT", 90, "A tower of mammoth bones. Climb to the top and see the whole island!", "in the meadow west of the plaza"],
]
const CAMPFIRE := Vector2(0.0, -13.4)
const GATE := Vector2(0.3, -1.4)
const TOTEM := Vector2(10.6, -13.6)
const LOOKOUT := Vector2(-19.0, -10.0)
const LOOK_H := 5.5                                ## the lookout's deck, over the ground
const HAMMOCK := Vector2(15.5, 41.5)               ## between its two palms
const BRIDGE_AT := 0.333                           ## where it crosses: along the stream, pool (0) to the sea (1)
const STREAM_END := Vector2(62, -2)
## A pool of lamplight on the ground: a disc, bright in the middle, added on.
const POOL_SHADER := "shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float glow = 0.0;
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float k = pow(clamp(1.0 - d, 0.0, 1.0), 2.2);
	ALBEDO = vec3(1.0, 0.62, 0.28) * k * glow;
}
"

var _sites := {}                                   ## id -> the marker node (stakes, rope, sign)
var _made := {}                                    ## id -> the build's node
var _movers: Array = []
var _lamp_mat: StandardMaterial3D
var _pool_mat: ShaderMaterial
var _drums: Array = []
var _booms: Array = []                             ## when the last drum beats were (for four quick ones)
var _sway: Node3D                                  ## the hammock (it swings)
var _flag: Node3D
var _hold := ""                                    ## "hammock", "up", "down": what he is doing (home._holder = self)
var _hold_t := 0.0
var _hold_from := Vector3.ZERO
var _hold_to := Vector3.ZERO
var _sun_to := 0.0


static func info(id: String) -> Array:
	for b in BUILDS:
		if b[0] == id:
			return b
	return []


static func is_built(id: String) -> bool:
	return (GameState.shelter.get("built", []) as Array).has(id)


## The bridge's two ends (x, z): the near bank (south), the far bank (the grove's).
func bridge_ends() -> Array:
	var pool := Vector2(home.POOL.x, home.POOL.z)
	var s := pool.lerp(STREAM_END, BRIDGE_AT)
	# straight north-south over it (the way he walks: a player holds W)
	return [s + Vector2(0, 5.0), s - Vector2(0, 5.0)]


func reserved(p: Vector2, pad: float) -> bool:
	if p.distance_to(CAMPFIRE) < 3.4 + pad or p.distance_to(TOTEM) < 1.6 + pad or p.distance_to(LOOKOUT) < 4.0 + pad:
		return true
	if p.distance_to(HAMMOCK) < 4.5 + pad or absf(p.x - GATE.x) < 3.4 + pad and absf(p.y - GATE.y) < 1.5 + pad:
		return true
	var e := bridge_ends()
	return home._seg_dist(p, e[0], e[1]) < 2.0 + pad


func movers() -> Array:
	return _movers


func build() -> void:
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = Color("ffb347")
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color("ff9a3c")
	_lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for b in BUILDS:
		var id: String = b[0]
		if is_built(id):
			_make(id)
			if id == "campfire":
				_campfire_lit()
		else:
			_site(id)


## ------------------------------------------------------------------ the plans' places
func _where(id: String) -> Vector3:
	match id:
		"campfire":
			return at_ground(CAMPFIRE.x, CAMPFIRE.y)
		"gate":
			return at_ground(GATE.x, GATE.y)
		"totem":
			return at_ground(TOTEM.x, TOTEM.y)
		"lookout":
			return at_ground(LOOKOUT.x, LOOKOUT.y)
		"hammock":
			return at_ground(HAMMOCK.x, HAMMOCK.y)
		"bridge":
			var e := bridge_ends()
			var near: Vector2 = e[0] + (e[0] - e[1]).normalized() * 1.2
			return at_ground(near.x, near.y)
	return Vector3.ZERO


## Stakes and a rope round the place, a hide sign on a post with the price.
func _site(id: String) -> void:
	var b := info(id)
	var c := _where(id)
	var n := pivot(c)
	_sites[id] = n
	_movers.append(n)
	var r := 1.3
	var corners: Array = []
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		p.y = ground(c.x + p.x, c.z + p.z) - c.y
		shape(cyl(0.05, 0.9, 5, 0.02), home.WOOD, p + Vector3(0, 0.4, 0), Vector3(0, 0, 4.0), Vector3.ONE, n)
		corners.append(p + Vector3(0, 0.72, 0))
	for k in 4:
		_rod(n, corners[k], corners[(k + 1) % 4], 0.018, Color("c9a46a"), 4)
	# the sign: a hide on a post, the price on it
	var sp := Vector3(1.6, ground(c.x + 1.6, c.z + 1.0) - c.y, 1.0)
	shape(cyl(0.06, 1.7, 6), home.WOOD, sp + Vector3(0, 0.85, 0), Vector3.ZERO, Vector3.ONE, n)
	shape(BoxMesh.new(), Color("e2c49a"), sp + Vector3(0, 1.45, 0.04), Vector3(0, 0, 3.0), Vector3(1.15, 0.62, 0.05), n)
	var l := Label3D.new()
	l.text = "%s\n%d BONES" % [str(b[1]).trim_prefix("THE "), int(b[2])]
	l.font = Pal.title_font()
	l.font_size = 40
	l.pixel_size = 0.004
	l.modulate = Color("5a2a14")
	l.outline_size = 0
	l.position = sp + Vector3(0, 1.45, 0.075)
	l.layers = MirrorKind.LAYER_LABELS
	n.add_child(l)
	for m in n.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF      # (a marker: no shadows, they cost)
	home._spot("site_" + id, c, "PLANS: %s" % b[1], "E: see the plan  (%d bones)" % int(b[2]))


func use(id: String) -> bool:
	if id.begins_with("site_"):
		home._open_workshop("build", id.substr(5))
		return true
	match id:
		"drums":
			_drum()
			return true
		"hammock":
			_lie_down()
			return true
		"lookout", "lookout_top":
			_climb()
			return true
		"totem":
			home.say(_totem_line())
			return true
	return false


## ------------------------------------------------------------------ building one
## The workshop paid for it: it rises out of the ground, dust everywhere.
func raise(id: String) -> void:
	var built: Array = GameState.shelter.get("built", [])
	if not built.has(id):
		built.append(id)
		save_key("built", built)
	if _sites.has(id):
		(_sites[id] as Node).queue_free()
		_sites.erase(id)
	home._unspot("site_" + id)
	var n := _make(id)
	var c := _where(id)
	if n != null:
		var y0 := n.position.y
		n.position.y = y0 - 3.5
		n.scale = Vector3(0.7, 0.7, 0.7)
		var tw := n.create_tween().set_parallel(true)
		tw.tween_property(n, "position:y", y0, 1.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "scale", Vector3.ONE, 1.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.chain().tween_callback(_after(id))
	for k in 5:
		puff(c + Vector3(randf_range(-2, 2), 0.2, randf_range(-2, 2)), Color(0.75, 0.66, 0.52, 0.7), 16, 3.0)
	pop_word("BUILT!", c + Vector3(0, 3.5, 0), Color("9be15d"), 110)
	if Vector2(ugu().x, ugu().z).distance_to(Vector2(c.x, c.z)) > 14.0:
		_beacon(c)


## What a build turns on once it stands (lights, the fire): after it rises.
func _after(id: String) -> Callable:
	return func() -> void:
		if id == "campfire" and _made.has(id):
			_campfire_lit()


## A pillar of light over a far build, for a while: "it's over there!"
func _beacon(at: Vector3) -> void:
	var b := glowing(cyl(0.5, 40.0, 10), Color(1.0, 0.9, 0.5), 1.5, at + Vector3(0, 20.0, 0))
	var m := b.material_override as StandardMaterial3D
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = 0.35
	var tw := b.create_tween()
	tw.tween_interval(25.0)
	tw.tween_property(m, "albedo_color:a", 0.0, 2.0)
	tw.tween_callback(b.queue_free)


func _make(id: String) -> Node3D:
	var c := _where(id)
	var n := pivot(c)
	_made[id] = n
	match id:
		"hammock":
			_make_hammock(n)
		"campfire":
			_make_campfire(n)
		"gate":
			_make_gate(n)
		"bridge":
			_make_bridge(n)
		"totem":
			_make_totem(n)
		"lookout":
			_make_lookout(n)
	return n


## ------------------------------------------------------------------ the hammock
func _palm_at(n: Node3D, base: Vector3, lean: Vector3) -> Vector3:
	var top := base
	for k in 7:
		var p := base + lean * (k / 6.0) * (k / 6.0) + Vector3(0, k * 0.55, 0)
		shape(cyl(0.2 - k * 0.012, 0.6, 7), home.WOOD.lightened(0.08 * (k % 2)), p + Vector3(0, 0.3, 0), Vector3.ZERO, Vector3.ONE, n)
		top = p + Vector3(0, 0.6, 0)
	for k in 7:
		var a := k * TAU / 7.0
		var fr := shape(BoxMesh.new(), home.LEAF.lightened(0.05 * (k % 3)), top + Vector3(cos(a) * 0.9, -0.25, sin(a) * 0.9), Vector3.ZERO, Vector3(1.9, 0.05, 0.42), n)
		fr.rotation = Vector3(0, -a, -0.45)
	for k in 3:
		shape(ball(0.13, 6), Color("6b4a2c"), top + Vector3(cos(k * 2.1) * 0.2, -0.2, sin(k * 2.1) * 0.2), Vector3.ZERO, Vector3.ONE, n)
	home._blocks.append([Vector2(base.x + n.position.x, base.z + n.position.z), 0.35])
	return top


func _make_hammock(n: Node3D) -> void:
	var a := Vector3(-2.1, ground(HAMMOCK.x - 2.1, HAMMOCK.y - 0.4) - n.position.y, -0.4)
	var b := Vector3(2.1, ground(HAMMOCK.x + 2.1, HAMMOCK.y + 0.4) - n.position.y, 0.4)
	_palm_at(n, a, Vector3(-0.6, 0, -0.3))
	_palm_at(n, b, Vector3(0.6, 0, 0.3))
	var ha := a + Vector3(0, 1.5, 0)
	var hb := b + Vector3(0, 1.5, 0)
	_sway = pivot((ha + hb) * 0.5, n)
	_movers.append(_sway)
	# the hide: a sagging strip, ropes to the trunks
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along := (hb - ha)
	var side := along.cross(Vector3.UP).normalized() * 0.55
	var rows := 12
	for i in rows:
		var q0 := float(i) / rows
		var q1 := float(i + 1) / rows
		var p0 := ha.lerp(hb, lerpf(0.12, 0.88, q0)) - _sway.position + Vector3(0, -sin(q0 * PI) * 0.75, 0)
		var p1 := ha.lerp(hb, lerpf(0.12, 0.88, q1)) - _sway.position + Vector3(0, -sin(q1 * PI) * 0.75, 0)
		for v in [[p0 - side, 0], [p1 - side, 0], [p1 + side, 1], [p0 - side, 0], [p1 + side, 1], [p0 + side, 1]]:
			st.set_color(Color("d9b08e") if i % 2 == 0 else Color("c99a72"))
			st.set_normal(Vector3.UP)
			st.add_vertex(v[0])
	var hide := MeshInstance3D.new()
	hide.mesh = st.commit()
	var hm := StandardMaterial3D.new()
	hm.vertex_color_use_as_albedo = true
	hm.cull_mode = BaseMaterial3D.CULL_DISABLED
	hide.material_override = hm
	_sway.add_child(hide)
	for end in [[ha, 0.12], [hb, 0.88]]:
		var tip: Vector3 = ha.lerp(hb, end[1]) - _sway.position + Vector3(0, -sin(float(end[1]) * PI) * 0.75, 0)
		var root: Vector3 = (end[0] as Vector3) - _sway.position
		_rod(_sway, root, tip, 0.02, Color("c9a46a"), 4)
	home._spot("hammock", n.position + Vector3(0, 0, 1.6), "THE HAMMOCK", "E: lie down for a swing")


## A basis whose Y runs along `d` (for a cylinder from one point to another).
func _basis_along(d: Vector3) -> Basis:
	var y := d.normalized()
	var x := (Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).cross(y).normalized()
	return Basis(x, y, x.cross(y)).orthonormalized()


## A cylinder from a to b (under n).
func _rod(n: Node3D, a: Vector3, b: Vector3, r: float, col: Color, segs := 6) -> MeshInstance3D:
	var m := shape(cyl(r, a.distance_to(b), segs), col, (a + b) * 0.5, Vector3.ZERO, Vector3.ONE, n)
	m.basis = _basis_along(b - a)
	return m


func _lie_down() -> void:
	if _sway == null:
		return
	_hold = "hammock"
	_hold_t = 0.0
	_sun_to = 1.0 if night() < 0.5 else 0.0          # lying here, the sun goes down (or comes up)
	home._holder = self
	home._model.emote("sleepy", 9999.0)
	home.say("Ahhh... (E or a step: up again)")


## ------------------------------------------------------------------ the gathering fire
func _make_campfire(n: Node3D) -> void:
	for k in 12:
		var a := k * TAU / 12.0
		shape(ball(0.26, 6), home.ROCK.lightened(0.04 * (k % 3)), Vector3(cos(a) * 1.0, 0.12, sin(a) * 1.0), Vector3(0, k * 30.0, 0), Vector3.ONE, n)
	for k in 4:
		shape(cyl(0.11, 1.3, 7), home.WOOD, Vector3(0, 0.18, 0), Vector3(0, k * 45.0, 82), Vector3.ONE, n)
	# log seats round it, and two hide drums
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		var p := Vector3(cos(a) * 2.5, 0.28, sin(a) * 2.5)
		var log := shape(cyl(0.28, 1.6, 9), home.WOOD.lightened(0.06), p, Vector3.ZERO, Vector3.ONE, n)
		log.basis = _basis_along(Vector3(-sin(a), 0, cos(a)))
		for end: float in [-1.0, 1.0]:
			shape(cyl(0.22, 0.02, 9), Color("c9a074"), p + Vector3(-sin(a), 0, cos(a)) * 0.81 * end, Vector3.ZERO, Vector3.ONE, n).basis = _basis_along(Vector3(-sin(a), 0, cos(a)))
		home._blocks.append([Vector2(n.position.x + p.x, n.position.z + p.z), 0.55])
	home._blocks.append([Vector2(n.position.x, n.position.z), 1.15])
	for k in 2:
		var dp := Vector3(-1.4 + k * 2.8, 0, 2.3)
		var drum := pivot(dp, n)
		shape(cyl(0.32, 0.6, 10, 0.26), home.WOOD.darkened(0.1), Vector3(0, 0.3, 0), Vector3.ZERO, Vector3.ONE, drum)
		shape(cyl(0.34, 0.04, 12), Color("ead2a8"), Vector3(0, 0.62, 0), Vector3.ZERO, Vector3.ONE, drum)
		for q in 6:
			var qa := q * TAU / 6.0
			shape(cyl(0.012, 0.5, 3), Color("5a3a22"), Vector3(cos(qa) * 0.31, 0.35, sin(qa) * 0.31), Vector3.ZERO, Vector3.ONE, drum)
		_drums.append(drum)
		_movers.append(drum)
	# bone stakes with skulls round the back
	for k in 5:
		var a2 := PI + k * PI / 4.0
		var p2 := Vector3(cos(a2) * 3.4, 0, sin(a2) * 3.4)
		shape(cyl(0.05, 1.3, 5), home.BONE, p2 + Vector3(0, 0.65, 0), Vector3.ZERO, Vector3.ONE, n)
		shape(ball(0.14, 6), home.BONE, p2 + Vector3(0, 1.35, 0), Vector3.ZERO, Vector3(1, 0.85, 1.1), n)
	home._spot("drums", n.position + Vector3(0, 0, 3.1), "THE GATHERING FIRE", "E: bang the drums!")


var _lit := false

func _campfire_lit() -> void:
	if _lit or not _made.has("campfire"):
		return
	_lit = true
	var n: Node3D = _made["campfire"]
	home._fire(n.global_position + Vector3(0, 0.05, 0), 0.95)


func _drum() -> void:
	var t: float = home._t
	_booms = _booms.filter(func(b: float) -> bool: return t - b < 2.4)
	_booms.append(t)
	var d: Node3D = _drums[_booms.size() % _drums.size()]
	var tw := d.create_tween()
	tw.tween_property(d, "scale", Vector3(1.12, 0.82, 1.12), 0.05)
	tw.tween_property(d, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	pop_word("BOOM!" if _booms.size() % 2 == 1 else "BOOM-BOOM!", d.global_position + Vector3(0, 1.3, 0), Color("ffb347"))
	home._flare = 1.2
	home._pup_hop = 0.9
	home._model.emote("grin", 0.6)
	if _booms.size() >= 4:
		_booms.clear()
		pop_word("DANCE!", ugu() + Vector3(0, 3.0, 0), Color("ff7ac0"), 100)
		puff(_made["campfire"].global_position + Vector3(0, 1.0, 0), Color("ffd84a"), 40, 5.0, true)
		if home._on_ground:
			home._vy = home.JUMP
			home._on_ground = false
			home._jumps = 1
			home._model.jumped(true)


## ------------------------------------------------------------------ the tusk gate and the path lamps
func _make_gate(n: Node3D) -> void:
	for side: float in [-1.0, 1.0]:
		var base := Vector3(side * 2.5, 0, 0)
		shape(ball(0.6, 7), home.ROCK_DARK, base + Vector3(0, 0.3, 0), Vector3(0, side * 30.0, 0), Vector3(1.2, 0.8, 1.1), n)
		# the tusk: a curve of ivory, thick at the root, up and in to meet the other
		var prev := base + Vector3(0, 0.5, 0)
		var ivory := Color("f1e6c8")
		for k in 16:
			var q := (k + 1) / 16.0
			var p := Vector3(side * (2.5 - 2.25 * q * q), 0.5 + 4.0 * sin(q * PI * 0.5), 0.3 * sin(q * PI))
			_rod(n, prev, p, lerpf(0.27, 0.07, q), ivory.darkened(0.1 * q), 9)
			shape(ball(lerpf(0.27, 0.07, q), 8), ivory.darkened(0.1 * q), p, Vector3.ZERO, Vector3.ONE, n)
			prev = p
		for r in 3:                                                # leather bands round the root
			shape(cyl(0.29 - r * 0.02, 0.08, 9), Color("8a5a3a"), base + Vector3(side * -0.03 * r, 0.75 + r * 0.32, 0), Vector3(0, 0, side * (8.0 + r * 6.0)), Vector3.ONE, n)
		home._blocks.append([Vector2(n.position.x + base.x, n.position.z), 0.7])
		_glow_torch(n, base + Vector3(side * 0.85, 0, 0.4))
	# the banner: a hide on a pole standing up where the tusks meet, Ugu's red
	# hand on it (above the arch: it never hides him from the camera)
	var top := Vector3(0, 4.4, 0.3)
	shape(cyl(0.22, 0.3, 8), Color("8a5a3a"), top, Vector3.ZERO, Vector3.ONE, n)
	_rod(n, top, top + Vector3(0, 1.9, 0), 0.04, home.WOOD)
	var bt := top + Vector3(0.55, 1.45, 0)
	shape(BoxMesh.new(), Color("e2c49a"), bt, Vector3.ZERO, Vector3(1.0, 0.75, 0.04), n)
	shape(ball(0.15, 8), home.OCHRE, bt + Vector3(0, -0.06, 0.04), Vector3.ZERO, Vector3(1.0, 1.15, 0.2), n)
	for f in 5:
		var fa := lerpf(-0.9, 0.9, f / 4.0)
		shape(cyl(0.032, 0.19, 5), home.OCHRE, bt + Vector3(sin(fa) * 0.19, 0.12 + cos(fa) * 0.05, 0.04), Vector3(0, 0, -rad_to_deg(fa)), Vector3.ONE, n)
	# stone lamps along the path to the pier, one batch of flames
	var a := Vector2(0, -4)
	var pier: Vector2 = home.PIER
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone(0.13, 0.32, 6)
	var xf: Array = []
	for k in 9:
		var q2 := (k + 1) / 10.0
		var p2 := a.lerp(pier, q2) + Vector2(1.7 if k % 2 == 0 else -1.7, 0)
		var g := ground(p2.x, p2.y)
		var lp := Vector3(p2.x, g, p2.y) - n.position
		shape(ball(0.3, 6), home.ROCK, lp + Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1, 0.7, 1), n)
		shape(ball(0.22, 6), home.ROCK.lightened(0.06), lp + Vector3(0, 0.5, 0), Vector3.ZERO, Vector3(1, 0.7, 1), n)
		shape(cyl(0.2, 0.14, 8, 0.12), home.ROCK_DARK, lp + Vector3(0, 0.74, 0), Vector3.ZERO, Vector3.ONE, n)
		xf.append(Transform3D(Basis.IDENTITY, Vector3(p2.x, g + 0.95, p2.y)))
	mm.instance_count = xf.size()
	for k2 in xf.size():
		mm.set_instance_transform(k2, xf[k2])
	var lamps := MultiMeshInstance3D.new()
	lamps.multimesh = mm
	lamps.material_override = _lamp_mat
	lamps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lamps)
	_movers.append(lamps)
	# a pool of warm light on the ground round each lamp and torch (no real
	# lights: a glowing disc, all of them one batch)
	var spots: Array = []
	for x in xf:
		spots.append((x as Transform3D).origin)
	for s3: float in [-1.0, 1.0]:
		spots.append(n.position + Vector3(s3 * 3.35, 2.0, 0.4))
	var pm := PlaneMesh.new()
	pm.size = Vector2(5.0, 5.0)
	var pmm := MultiMesh.new()
	pmm.transform_format = MultiMesh.TRANSFORM_3D
	pmm.mesh = pm
	pmm.instance_count = spots.size()
	for k3 in spots.size():
		var sp: Vector3 = spots[k3]
		pmm.set_instance_transform(k3, Transform3D(Basis.IDENTITY, Vector3(sp.x, ground(sp.x, sp.z) + 0.06, sp.z)))
	var pools := MultiMeshInstance3D.new()
	pools.multimesh = pmm
	_pool_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = POOL_SHADER
	_pool_mat.shader = sh
	pools.material_override = _pool_mat
	pools.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pools)
	_movers.append(pools)


## A torch that glows but lights nothing (no light: lights are dear here).
func _glow_torch(n: Node3D, at: Vector3) -> void:
	shape(cyl(0.06, 1.9, 6, 0.04), home.WOOD, at + Vector3(0, 0.95, 0), Vector3.ZERO, Vector3.ONE, n)
	shape(cyl(0.12, 0.26, 7), home.HIDE.darkened(0.3), at + Vector3(0, 1.9, 0), Vector3.ZERO, Vector3.ONE, n)
	for k in 3:
		var fl := shape(cone((0.13 - k * 0.03), (0.34 + k * 0.08), 7), Color.WHITE, at + Vector3(0, 2.15 + k * 0.02, 0), Vector3.ZERO, Vector3.ONE, n)
		fl.material_override = home._glow([Color("ff5a10"), Color("ffa020"), Color("fff0a0")][k], 3.0)
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		home._flames.append([fl, 0.45, k])


## ------------------------------------------------------------------ the bone bridge
func _make_bridge(n: Node3D) -> void:
	var e := bridge_ends()
	var a: Vector2 = e[0]
	var b: Vector2 = e[1]
	var ga := ground(a.x, a.y) + 0.08
	var gb := ground(b.x, b.y) + 0.08
	var arch := 0.55
	home.add_pad({"a": a, "b": b, "w": 1.25, "top_a": ga, "top_b": gb, "arch": arch})
	var along := Vector3(b.x - a.x, 0, b.y - a.y).normalized()
	var across := Vector3(-along.z, 0, along.x)
	var steps := 16
	var rails: Array = [[], []]
	for k in steps + 1:
		var q := float(k) / steps
		var p2 := a.lerp(b, q)
		var y := lerpf(ga, gb, q) + arch * sin(q * PI) - 0.07
		var p := Vector3(p2.x, y, p2.y) - n.position
		# a cross-bone, and a rope binding at each end
		_rod(n, p - across * 1.25, p + across * 1.25, 0.085, home.BONE.darkened(0.06 * (k % 2)), 7)
		if k % 4 == 0:
			for s: float in [-1.0, 1.0]:
				var post := p + across * s * 1.2
				_rod(n, post, post + Vector3(0, 1.0, 0), 0.06, home.BONE)
				shape(ball(0.09, 6), home.BONE, post + Vector3(0, 1.02, 0), Vector3.ZERO, Vector3.ONE, n)
				(rails[0 if s < 0.0 else 1] as Array).append(post + Vector3(0, 0.95, 0))
	for r in rails:
		for k in (r as Array).size() - 1:
			_rod(n, r[k], r[k + 1], 0.025, Color("c9a46a"), 4)
	# two long bones under it, and a skull on each end post
	_rod(n, Vector3(a.x, ga - 0.2, a.y) - n.position, Vector3(b.x, gb - 0.2, b.y) - n.position, 0.13, home.BONE.darkened(0.12), 8)


## ------------------------------------------------------------------ the trophy totem
## The heads carved on it: what he has beaten (the trophies, Old One-Eye), then
## blank ones for the beasts to come.
func _carvings() -> Array:
	var out: Array = []
	if GameState.trophies.has("sabre_fang"):
		out.append(["SABRE-FANG", Color("d9a64e"), "fangs"])
	if GameState.mystery("one_eye") == "solved":
		out.append(["OLD ONE-EYE", Color("7a8a9a"), "eye"])
	for t in GameState.trophies:
		if t != "sabre_fang":
			out.append([str(t).replace("_", " ").to_upper(), Color("a07850"), "horns"])
	return out


func _totem_line() -> String:
	var c := _carvings()
	if c.is_empty():
		return "No beast carved on it yet. Beat a big one, and its head goes up here!"
	return "Carved on the totem: %s. Beat more big beasts: there's room for more!" % ", ".join(c.map(func(x): return x[0]))


func _make_totem(n: Node3D) -> void:
	var carved := _carvings()
	var slots := maxi(4, carved.size() + 1)
	var wood: Color = home.WOOD.lightened(0.12)
	shape(cyl(0.6, 0.3, 10), home.ROCK, Vector3(0, 0.15, 0), Vector3.ZERO, Vector3.ONE, n)
	for k in slots:
		var y := 0.3 + k * 0.95
		var p := Vector3(0, y + 0.47, 0)
		if k < carved.size():
			var cv: Array = carved[k]
			var col: Color = cv[1]
			shape(cyl(0.44, 0.92, 10), col, p, Vector3.ZERO, Vector3.ONE, n)
			if cv[2] == "eye":                                   # one big eye, for One-Eye
				shape(ball(0.16, 8), Color("ffe066"), p + Vector3(0.0, 0.12, 0.38), Vector3.ZERO, Vector3(1, 1, 0.5), n)
			else:
				for s: float in [-1.0, 1.0]:
					shape(ball(0.09, 6), Color("1a120c"), p + Vector3(s * 0.17, 0.14, 0.4), Vector3.ZERO, Vector3(1, 1, 0.5), n)
			shape(ball(0.15, 7), col.darkened(0.25), p + Vector3(0, -0.06, 0.42), Vector3.ZERO, Vector3(1.4, 0.8, 0.7), n)   # the snout
			if cv[2] == "fangs":
				for s2: float in [-1.0, 1.0]:
					shape(cone(0.05, 0.36, 5), home.BONE, p + Vector3(s2 * 0.12, -0.32, 0.42), Vector3(180, 0, 0), Vector3.ONE, n)
			elif cv[2] == "horns":
				for s3: float in [-1.0, 1.0]:
					shape(cone(0.07, 0.4, 5), home.BONE, p + Vector3(s3 * 0.42, 0.42, 0), Vector3(0, 0, -s3 * 40.0), Vector3.ONE, n)
			for s4: float in [-1.0, 1.0]:                               # ears
				shape(cone(0.09, 0.22, 4), col.darkened(0.2), p + Vector3(s4 * 0.3, 0.5, 0.1), Vector3(0, 0, -s4 * 20.0), Vector3.ONE, n)
		else:
			# a blank: rough wood, a "?" scratched on it
			shape(cyl(0.42, 0.92, 10), wood.darkened(0.12), p, Vector3.ZERO, Vector3.ONE, n)
			var q := Label3D.new()
			q.text = "?"
			q.font = Pal.title_font()
			q.font_size = 96
			q.pixel_size = 0.005
			q.modulate = Color("3e2a18")
			q.outline_size = 0
			q.position = p + Vector3(0, 0, 0.43)
			q.layers = MirrorKind.LAYER_LABELS
			n.add_child(q)
		shape(cyl(0.47, 0.06, 10), Color("3e2a18"), Vector3(0, y + 0.94, 0), Vector3.ZERO, Vector3.ONE, n)
	# the top: a thunderbird spreading its wings
	var ty := 0.3 + slots * 0.95
	shape(cyl(0.38, 0.6, 10, 0.3), home.OCHRE, Vector3(0, ty + 0.3, 0), Vector3.ZERO, Vector3.ONE, n)
	for s5: float in [-1.0, 1.0]:
		shape(BoxMesh.new(), home.OCHRE.lightened(0.1), Vector3(s5 * 0.95, ty + 0.45, 0), Vector3(0, 0, s5 * 12.0), Vector3(1.5, 0.14, 0.4), n)
		shape(BoxMesh.new(), Color("e2c49a"), Vector3(s5 * 1.6, ty + 0.56, 0.02), Vector3(0, 0, s5 * 18.0), Vector3(0.5, 0.1, 0.42), n)
	shape(cone(0.12, 0.3, 5), Color("ffcf40"), Vector3(0, ty + 0.62, 0.36), Vector3(90, 0, 0), Vector3.ONE, n)
	home._blocks.append([Vector2(n.position.x, n.position.z), 0.7])
	home._spot("totem", n.position + Vector3(0, 0, 1.5), "THE TROPHY TOTEM", "E: whose heads are these?")


## ------------------------------------------------------------------ the lookout
func _make_lookout(n: Node3D) -> void:
	var h := LOOK_H
	var bone: Color = home.BONE
	var legs: Array = []
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		var foot := Vector3(cos(a) * 1.75, ground(LOOKOUT.x + cos(a) * 1.75, LOOKOUT.y + sin(a) * 1.75) - n.position.y, sin(a) * 1.75)
		var top := Vector3(cos(a) * 1.25, h, sin(a) * 1.25)
		_rod(n, foot, top + Vector3(0, 0.15, 0), 0.17, bone.darkened(0.04 * k), 8)
		shape(ball(0.24, 7), bone, foot + Vector3(0, 0.1, 0), Vector3.ZERO, Vector3(1, 0.7, 1), n)
		legs.append([foot, top])
	for k in 4:                                                  # cross bracing
		var l0: Array = legs[k]
		var l1: Array = legs[(k + 1) % 4]
		for y0: float in [0.25, 0.55]:
			_rod(n, (l0[0] as Vector3).lerp(l0[1], y0), (l1[0] as Vector3).lerp(l1[1], y0 + 0.22), 0.06, bone.darkened(0.1))
			_rod(n, (l1[0] as Vector3).lerp(l1[1], y0), (l0[0] as Vector3).lerp(l0[1], y0 + 0.22), 0.06, bone.darkened(0.1))
	# the deck: planks, a bone rail, a hide roof, a flag
	shape(BoxMesh.new(), home.WOOD, Vector3(0, h, 0), Vector3.ZERO, Vector3(3.1, 0.24, 3.1), n)
	for k in 6:
		shape(BoxMesh.new(), home.WOOD.lightened(0.08 * (k % 2)), Vector3(-1.3 + k * 0.52, h + 0.13, 0), Vector3.ZERO, Vector3(0.48, 0.03, 3.05), n)
	var corners: Array = []
	for k in 4:
		var a2 := PI * 0.25 + k * PI * 0.5
		var cp := Vector3(cos(a2) * 1.95, h, sin(a2) * 1.95)
		_rod(n, cp, cp + Vector3(0, 2.3, 0), 0.07, bone)
		corners.append(cp)
	for k in 4:
		if k == 1:
			continue                                             # (the ladder side: open)
		_rod(n, (corners[k] as Vector3) + Vector3(0, 0.9, 0), (corners[(k + 1) % 4] as Vector3) + Vector3(0, 0.9, 0), 0.05, bone.darkened(0.08))
	var roof := shape(cone(2.5, 1.3, 4), home.HIDE, Vector3(0, h + 2.85, 0), Vector3(0, 45, 0), Vector3.ONE, n)
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_rod(n, Vector3(0, h + 3.4, 0), Vector3(0, h + 4.6, 0), 0.04, home.WOOD)
	_flag = pivot(Vector3(0, h + 4.4, 0), n)
	_movers.append(_flag)
	shape(BoxMesh.new(), home.OCHRE, Vector3(0.45, 0, 0), Vector3.ZERO, Vector3(0.85, 0.42, 0.03), _flag)
	# the ladder up the south side
	var lb := Vector3(0, 0, 2.3)
	lb.y = ground(LOOKOUT.x, LOOKOUT.y + 2.3) - n.position.y
	for s: float in [-0.4, 0.4]:
		_rod(n, lb + Vector3(s, 0, 0), Vector3(s, h + 0.1, 1.45), 0.05, home.WOOD)
	for k in 10:
		var q := (k + 0.5) / 10.0
		var rp := lb.lerp(Vector3(0, h + 0.1, 1.45), q)
		_rod(n, rp + Vector3(-0.4, 0, 0), rp + Vector3(0.4, 0, 0), 0.035, bone)
	home.add_pad({"c": LOOKOUT, "r": 1.55, "top": n.position.y + h + 0.13})
	home._spot("lookout", n.position + Vector3(0, 0, 2.9), "THE LOOKOUT", "E: climb up")
	home._spot("lookout_top", Vector3(LOOKOUT.x, n.position.y + h, LOOKOUT.y), "THE LOOKOUT", "E: climb down")


func _climb() -> void:
	var top := Vector3(LOOKOUT.x, home.pad_top(LOOKOUT), LOOKOUT.y)
	var foot := at_ground(LOOKOUT.x, LOOKOUT.y + 2.9)
	_hold_t = 0.0
	if ugu().y > top.y - 1.0:
		_hold = "down"
		_hold_from = ugu()
		_hold_to = foot
		home._zoom_to = 1.0
	else:
		_hold = "up"
		_hold_from = foot
		_hold_to = top + Vector3(0, 0, 0.6)
	home._holder = self


## ------------------------------------------------------------------ held: the hammock, the ladder
func hold_step(delta: float) -> void:
	_hold_t += delta
	var m: Node3D = home._model
	match _hold:
		"hammock":
			if _sway == null or _moving_keys():
				release()
				return
			var sw: float = sin(home._t * 1.2) * 0.12
			_sway.rotation.x = sw
			var c := _sway.global_position
			var along := (_made["hammock"] as Node3D).global_transform.basis.x
			var up := Vector3.UP.rotated(along, sw)
			home._pos = c + up * -0.62 - along * 0.95
			var y := along
			var z := up
			m.basis = Basis(y.cross(z), y, z).orthonormalized()
			m.look_at_point = Vector3.INF
			home._night_to = move_toward(home._night_to, _sun_to, delta * 0.04)
			if fmod(_hold_t, 2.6) < delta:
				pop_word("z", c + Vector3(0.4, 0.6, 0), Color("cfe8ff"), 56)
		"up", "down":
			var k := clampf(_hold_t / (1.8 if _hold == "up" else 1.0), 0.0, 1.0)
			home._pos = _hold_from.lerp(_hold_to, k) + Vector3(0, absf(sin(_hold_t * 9.0)) * 0.05, 0)
			m.rotation = Vector3(0, PI if _hold == "up" else 0.0, 0)
			if k >= 1.0:
				var was := _hold
				release()
				if was == "up":
					home._zoom_to = 1.6
					home.say("What a view! The whole island, and the sea all round.")
					puff(ugu() + Vector3(0, 1.5, 0), Color("fff2c0"), 20, 2.0, true)


func _moving_keys() -> bool:
	for k in [KEY_A, KEY_D, KEY_W, KEY_S, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_SPACE]:
		if Input.is_physical_key_pressed(k):
			return true
	return false


func release() -> void:
	var was := _hold
	_hold = ""
	home._holder = null
	var m: Node3D = home._model
	m.rotation = Vector3(0, m.rotation.y if was != "hammock" else 0.0, 0)
	if was == "hammock":
		home._pos = at_ground(HAMMOCK.x, HAMMOCK.y + 1.6)
		m.basis = Basis.IDENTITY
		home._model.emote("happy", 1.2)
		home._night_to = home._night


## ------------------------------------------------------------------ every frame
func _process(_delta: float) -> void:
	if home == null:
		return
	var n := night()
	_lamp_mat.emission_energy_multiplier = lerpf(0.4, 3.2, n) * (1.0 + 0.12 * sin(home._t * 9.0))
	if _pool_mat != null:
		_pool_mat.set_shader_parameter("glow", smoothstep(0.35, 0.85, n) * (0.6 + 0.05 * sin(home._t * 7.0)))
	if _flag != null:
		_flag.rotation.y = sin(home._t * 2.2) * 0.4
		_flag.rotation.z = sin(home._t * 5.0) * 0.08


## ------------------------------------------------------------------ the plans, drawn (the workshop's BUILD tab)
## A little picture of a build, centred at c, s = its scale (about 20 px).
static func draw_icon(ci: CanvasItem, id: String, c: Vector2, s: float, t := 0.0) -> void:
	ci.draw_set_transform(c, 0.0, Vector2(s, s))
	var bone := Color("efe4c8")
	var wood := Color("8a5a3a")
	match id:
		"hammock":
			ci.draw_line(Vector2(-13, 14), Vector2(-15, -12), wood, 4.0)
			ci.draw_line(Vector2(13, 14), Vector2(15, -12), wood, 4.0)
			for side: float in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(side * 15, -12), Vector2(side * 4, -18), Vector2(side * 9, -10)]), Color("6a9a4a"))
			var pts := PackedVector2Array()
			for k in 9:
				var q := k / 8.0
				pts.append(Vector2(lerpf(-12, 12, q), -2 + sin(q * PI) * 8.0 + sin(t * 2.0) * 1.0))
			ci.draw_polyline(pts, Color("d9b08e"), 5.0)
		"campfire":
			ci.draw_line(Vector2(-12, 12), Vector2(12, 4), wood, 5.0)
			ci.draw_line(Vector2(12, 12), Vector2(-12, 4), wood, 5.0)
			var f := 1.0 + sin(t * 9.0) * 0.08
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-9, 8), Vector2(0, -16 * f), Vector2(9, 8)]), Color("ff6a1a"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-5, 8), Vector2(0, -7 * f), Vector2(5, 8)]), Color("ffe066"))
		"gate":
			for side: float in [-1.0, 1.0]:
				ci.draw_arc(Vector2(0, 14), 14.0, PI if side < 0.0 else -PI * 0.5, -PI * 0.5 if side < 0.0 else 0.0, 10, bone, 4.0)
			ci.draw_rect(Rect2(-5, -4, 10, 9), Color("e2c49a"))
			ci.draw_circle(Vector2(0, 1), 2.5, Color("c8553d"))
		"bridge":
			ci.draw_arc(Vector2(0, 16), 15.0, PI * 1.15, PI * 1.85, 12, bone, 5.0)
			for k in 4:
				ci.draw_line(Vector2(-12 + k * 8, 6), Vector2(-12 + k * 8, 0), bone, 2.0)
			ci.draw_line(Vector2(-16, 13), Vector2(16, 13), Color("5ab0ff"), 3.0)
		"totem":
			for k in 3:
				var col: Color = [Color("d9a64e"), Color("7a8a9a"), Color("a07850")][k]
				ci.draw_rect(Rect2(-6, 6 - k * 10, 12, 9), col)
				ci.draw_circle(Vector2(-2.5, 9 - k * 10), 1.3, Color("1a120c"))
				ci.draw_circle(Vector2(2.5, 9 - k * 10), 1.3, Color("1a120c"))
			ci.draw_rect(Rect2(-14, -26, 28, 4), Color("c8553d"))
		"lookout":
			ci.draw_line(Vector2(-11, 16), Vector2(-7, -6), bone, 3.0)
			ci.draw_line(Vector2(11, 16), Vector2(7, -6), bone, 3.0)
			ci.draw_line(Vector2(-9, 6), Vector2(9, -2), bone, 2.0)
			ci.draw_rect(Rect2(-10, -8, 20, 3), wood)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-11, -9), Vector2(0, -18), Vector2(11, -9)]), Color("9a6a40"))
			ci.draw_line(Vector2(0, -18), Vector2(0, -25), wood, 1.5)
			ci.draw_rect(Rect2(0, -25, 7 + sin(t * 4.0), 4), Color("c8553d"))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
