extends "res://shelter/system.gd"
## THE RELICS, AT HOME (common/relics.gd): every rare find he brings home does
## in his cave just what its own words say it's for:
## - MOONSTONE: a night-lamp on a bone post by his bed (pale blue at night).
## - STAR SHARD: in the hearth, turning over the fire: the fire burns gold.
## - GIANT FEATHER: laid over the cave mouth, "a roof that never leaks".
## - GLOW CRYSTAL: crystals on the cave walls, teal, glowing at night.
## - AMBER BUG: a charm swinging on a cord at the door.
## - MAMMOTH IVORY: carved into a little statue of Ugu, on a stone in the plaza.
## - CAVE BEAR FANG: hung by the door ("no wolf comes near").
## - RED OCHRE: new pictures on the back wall: a big red Ugu, his hand prints.
## - THUNDER EGG: cracked open by the store, purple crystal inside; it rumbles.
## - GOLDEN HORN: on Star Rock (shelter/nature.gd); E: blow it, and the whole
##   valley answers.
## THE RELIC SHELF, by his bed: a niche for each of the ten, found ones glowing,
## the rest dark with a "?"; E: what each is (and how many are still out there).
## Something new since his last visit sparkles, a "NEW!" over it, till he goes
## and looks (GameState.shelter["seen_relics"]).

const Nature := preload("res://shelter/nature.gd")
const SHELF := Vector3(-4.7, 0, -0.6)               ## (from the cave's middle) by the left wall, turned to face out
const AT := {                                       ## where each one goes (from the cave's middle, but the statue: the plaza)
	"moonstone": Vector3(-2.75, 0, -3.9), "star_shard": Vector3(0, 0, 0.5), "giant_feather": Vector3(0, 5.6, 4.4),
	"glow_crystal": Vector3(-5.9, 2.6, -2.2), "amber_bug": Vector3(1.4, 3.3, 4.6), "bear_fang": Vector3(-4.9, 2.4, 4.7),
	"red_ochre": Vector3(-0.2, 3.4, -4.6), "thunder_egg": Vector3(5.7, 0, -0.5), "ivory": Vector3(-5.8, 0, 13.6),
	"golden_horn": Vector3.ZERO,
}

var _new: Array = []                                ## [kind, its sparkles, its NEW label, where]
var _movers: Array = []
var _moon_light: OmniLight3D
var _moon_mat: StandardMaterial3D
var _crystal_mat: StandardMaterial3D
var _crystal_light: OmniLight3D
var _shard: Node3D
var _amber: Node3D
var _egg: Node3D
var _egg_in := 6.0
var _horn_t := 0.0


func reserved(p: Vector2, pad: float) -> bool:
	var stat := Vector2(home.CAVE.x + AT["ivory"].x, home.CAVE.z + AT["ivory"].z)
	return p.distance_to(stat) < 1.2 + pad


func movers() -> Array:
	return _movers


func has(kind: String) -> bool:
	return int(GameState.relics.get(kind, 0)) > 0


func build() -> void:
	var c: Vector3 = home.CAVE
	_shelf(c + SHELF)
	if has("moonstone"):
		_moonstone(c + AT["moonstone"])
	if has("star_shard"):
		_star_shard(c + AT["star_shard"])
	if has("giant_feather"):
		_feather(c + AT["giant_feather"])
	if has("glow_crystal"):
		_crystals(c)
	if has("amber_bug"):
		_amber_bug(c + AT["amber_bug"])
	if has("bear_fang"):
		_bear_fang(c + AT["bear_fang"])
	if has("red_ochre"):
		_paintings(c + AT["red_ochre"])
	if has("thunder_egg"):
		_thunder_egg(c + AT["thunder_egg"])
	if has("ivory"):
		_statue(c + AT["ivory"])
	if has("golden_horn"):
		_horn()
	# new since his last visit: sparkles and a NEW! till he goes and looks
	var seen: Array = saved("seen_relics", [])
	for k in Relics.KINDS:
		if has(k) and not seen.has(k):
			_mark_new(k)


func _where(kind: String) -> Vector3:
	if kind == "golden_horn":
		return at_ground(Nature.STAR_ROCK.x, Nature.STAR_ROCK.y, Nature.ROCK_TOP + 0.8)
	var p: Vector3 = home.CAVE + AT[kind]
	if kind == "ivory":
		p.y = ground(p.x, p.z)
	return p + Vector3(0, 1.0 if p.y < 3.0 else 0.0, 0)


## ------------------------------------------------------------------ the shelf
func _shelf(at: Vector3) -> void:
	var n := pivot(at)
	n.rotation.y = PI * 0.25                               # (into the cave, and toward the camera)
	var stone: Color = home.ROCK.lightened(0.06)
	for y in [0.95, 1.85]:
		shape(BoxMesh.new(), stone, Vector3(0, y, 0), Vector3.ZERO, Vector3(2.9, 0.12, 0.5), n)
		for s: float in [-1.0, 1.0]:
			shape(cyl(0.05, 0.4, 5), home.BONE, Vector3(s * 1.2, y - 0.17, -0.1), Vector3(90, 0, 0), Vector3.ONE, n)
	for s2: float in [-1.0, 1.0]:
		shape(cyl(0.07, 2.4, 6), home.BONE, Vector3(s2 * 1.5, 1.2, -0.05), Vector3.ZERO, Vector3.ONE, n)
	shape(cone(0.1, 0.3, 5), home.BONE, Vector3(-1.5, 2.5, -0.05), Vector3.ZERO, Vector3.ONE, n)
	shape(cone(0.1, 0.3, 5), home.BONE, Vector3(1.5, 2.5, -0.05), Vector3.ZERO, Vector3.ONE, n)
	var kinds: Array = Relics.KINDS.keys()
	for i in kinds.size():
		var k: String = kinds[i]
		var p := Vector3(-1.12 + (i % 5) * 0.56, 1.04 if i < 5 else 1.94, 0.02)
		if has(k):
			_little(k, p, n)
		else:
			shape(ball(0.13, 6), Color("2a2420"), p + Vector3(0, 0.1, 0), Vector3.ZERO, Vector3(1, 0.8, 0.7), n)
			var q := Label3D.new()
			q.text = "?"
			q.font = Pal.title_font()
			q.font_size = 64
			q.pixel_size = 0.005
			q.modulate = Color("8a7a66")
			q.outline_size = 0
			q.position = p + Vector3(0, 0.12, 0.13)
			q.layers = MirrorKind.LAYER_LABELS
			n.add_child(q)
	for bz: float in [-1.1, 0.0, 1.1]:
		home._blocks.append([Vector2(at.x + bz * 0.707, at.z - bz * 0.707), 0.55])      # (along the turned shelf)
	home._spot("relics", at + Vector3(0.9, 0, 0.9), "THE RELIC SHELF", "E: his rare finds (%d of %d)" % [_found(), Relics.KINDS.size()])


func _found() -> int:
	var n := 0
	for k in Relics.KINDS:
		if has(k):
			n += 1
	return n


## A little one on the shelf: its shape, in its colour, glowing a little.
func _little(kind: String, p: Vector3, n: Node3D) -> void:
	var col: Color = Relics.KINDS[kind][2]
	var mesh: Mesh = ball(0.12, 8)
	var scl := Vector3.ONE
	var rot := Vector3.ZERO
	match kind:
		"star_shard", "glow_crystal":
			mesh = cone(0.09, 0.3, 5)
		"giant_feather":
			scl = Vector3(0.5, 1.9, 0.25)
			rot = Vector3(0, 0, 30)
		"bear_fang", "ivory":
			mesh = cone(0.07, 0.3, 6)
			rot = Vector3(0, 0, 20)
		"golden_horn":
			mesh = cone(0.08, 0.32, 7)
			rot = Vector3(0, 0, -70)
		"thunder_egg":
			scl = Vector3(1, 1.3, 1)
		"red_ochre":
			scl = Vector3(1.2, 0.6, 1.0)
	glowing(mesh, col, 0.6, p + Vector3(0, 0.15, 0), rot, scl, n)


func use(id: String) -> bool:
	match id:
		"relics":
			home._open_menu("THE RELIC SHELF", "%d of %d found. The rest are out at the edges of the world: off the paths, behind the hard rock." % [_found(), Relics.KINDS.size()], Color("6dffd8"), _shelf_rows)
			return true
		"horn":
			_blow()
			return true
	return false


func _shelf_rows() -> Array:
	var rows: Array = []
	for k in Relics.KINDS:
		if has(k):
			rows.append(["%s: %s" % [Relics.KINDS[k][0], str(Relics.KINDS[k][1]).get_slice(".", 0)], "x%d" % int(GameState.relics[k]), false, null])
		else:
			rows.append(["???", "still out there", false, null])
	return rows


## ------------------------------------------------------------------ each one at home
func _moonstone(at: Vector3) -> void:
	shape(cyl(0.05, 1.3, 6), home.BONE, at + Vector3(0, 0.65, 0))
	for k in 3:
		var a := k * TAU / 3.0
		shape(cyl(0.025, 0.3, 4), home.BONE, at + Vector3(cos(a) * 0.12, 1.4, sin(a) * 0.12), Vector3(cos(a) * 25.0, 0, -sin(a) * 25.0))
	_moon_mat = home._glow(Color("bfe3ff"), 1.5)
	var m := shape(ball(0.17, 10), Color("bfe3ff"), at + Vector3(0, 1.5, 0))
	m.material_override = _moon_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_moon_light = OmniLight3D.new()
	_moon_light.light_color = Color("a8d0ff")
	_moon_light.omni_range = 5.0
	_moon_light.position = at + Vector3(0, 1.6, 0)
	add_child(_moon_light)
	home._blocks.append([Vector2(at.x, at.z), 0.3])


func _star_shard(at: Vector3) -> void:
	_shard = pivot(at + Vector3(0, 1.75, 0))
	_movers.append(_shard)
	for k in 2:
		glowing(cone(0.13, 0.42, 5), Color("ffd25a"), 3.0, Vector3(0, 0.12 - k * 0.24, 0), Vector3(180.0 * k, 0, 0), Vector3.ONE, _shard)
	# the fire it sits over burns gold
	for f in home._fire_lights:
		var l: OmniLight3D = f[0]
		if l.global_position.distance_to(at) < 2.0:
			l.light_color = Color("ffc24a")
			f[1] = float(f[1]) * 1.35


func _feather(at: Vector3) -> void:
	var n := pivot(at)
	n.rotation = Vector3(0.25, 0.15, 0.1)
	_rod_on(n, Vector3(-4.8, -0.15, 0), Vector3(4.9, 0.25, 0), 0.07, Color("f3ead2"))             # the quill
	# the vane: one flat curved shape each side of the quill, its edge ragged with
	# barbs, pink fading to a deep rose tip
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var steps := 40
	for s: float in [-1.0, 1.0]:
		for k in steps:
			var q0 := float(k) / steps
			var q1 := float(k + 1) / steps
			var pts: Array = []
			for q in [q0, q1]:
				var x := lerpf(-4.5, 4.8, q)
				var y := lerpf(-0.15, 0.25, q) + sin(q * PI) * 0.25
				var w := (sin(pow(q, 0.8) * PI) * 1.25 + 0.15) * (1.0 - 0.18 * float(int(q * 31.0) % 2))      # (barbs: a ragged edge)
				pts.append([Vector3(x, y, 0), Vector3(x + 0.3, y - w * 0.25, s * w), q])
			var c0 := Color("ffb0e4").lerp(Color("d0508f"), pow(q0, 2.5))
			var c1 := Color("ffb0e4").lerp(Color("d0508f"), pow(q1, 2.5))
			var tri := [[pts[0][0], c0], [pts[1][0], c1], [pts[1][1], c1.lightened(0.15)], [pts[0][0], c0], [pts[1][1], c1.lightened(0.15)], [pts[0][1], c0.lightened(0.15)]]
			for v in tri:
				st.set_color(v[1])
				st.add_vertex(v[0])
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	n.add_child(m)


func _rod_on(n: Node3D, a: Vector3, b: Vector3, r: float, col: Color) -> void:
	var m := shape(cyl(r, a.distance_to(b), 6), col, (a + b) * 0.5, Vector3.ZERO, Vector3.ONE, n)
	var y := (b - a).normalized()
	var x := (Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).cross(y).normalized()
	m.basis = Basis(x, y, x.cross(y)).orthonormalized()


func _crystals(c: Vector3) -> void:
	_crystal_mat = home._glow(Color("6dffd8"), 0.8)
	var spots := [Vector3(-5.9, 2.6, -2.2), Vector3(5.9, 3.2, -1.6), Vector3(-3.9, 4.9, -3.6), Vector3(3.3, 5.0, -4.0), Vector3(-6.2, 1.2, 0.8), Vector3(6.3, 1.6, 1.4)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for sp in spots:
		for k in 5:
			var m := shape(cone(rng.randf_range(0.07, 0.13), rng.randf_range(0.35, 0.7), 5), Color("6dffd8"), c + (sp as Vector3) + Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25)),
				Vector3(rng.randf_range(-35, 35), rng.randf() * 90.0, rng.randf_range(-35, 35)))
			m.material_override = _crystal_mat
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_crystal_light = OmniLight3D.new()
	_crystal_light.light_color = Color("6dffd8")
	_crystal_light.omni_range = 9.0
	_crystal_light.position = c + Vector3(0, 4.0, -2.0)
	add_child(_crystal_light)


func _amber_bug(at: Vector3) -> void:
	_amber = pivot(at + Vector3(0, 1.1, 0))
	_movers.append(_amber)
	_rod_on(_amber, Vector3.ZERO, Vector3(0, -1.0, 0), 0.012, Color("3b2a22"))
	glowing(ball(0.2, 10), Color("ffae42"), 0.9, Vector3(0, -1.2, 0), Vector3.ZERO, Vector3(0.85, 1.15, 0.85), _amber)
	shape(ball(0.07, 6), Color("2a1a10"), Vector3(0, -1.2, 0.12), Vector3.ZERO, Vector3(1.2, 1.5, 0.5), _amber)


func _bear_fang(at: Vector3) -> void:
	_rod_on(self, at + Vector3(0, 1.3, 0), at + Vector3(0, 0.5, 0), 0.015, Color("3b2a22"))
	shape(cone(0.17, 0.75, 8), Color("efe3c8"), at + Vector3(0, 0.15, 0), Vector3(180, 0, 8))
	shape(cyl(0.18, 0.08, 8), Color("8a5a3a"), at + Vector3(0, 0.52, 0))


func _paintings(at: Vector3) -> void:
	var red: Color = home.OCHRE
	# a big red Ugu with his club, arms up, his mane of spikes
	var n := pivot(at + Vector3(0, 0, 0.05))
	shape(cyl(0.09, 1.0, 6), red, Vector3(0, 0, 0), Vector3.ZERO, Vector3.ONE, n)
	shape(ball(0.22, 8), red, Vector3(0, 0.7, 0), Vector3.ZERO, Vector3(1, 1, 0.2), n)
	for k in 7:
		var a := lerpf(-1.2, 1.2, k / 6.0)
		shape(cone(0.06, 0.25, 4), red, Vector3(sin(a) * 0.28, 0.72 + cos(a) * 0.28, 0), Vector3(0, 0, -rad_to_deg(a)), Vector3(1, 1, 0.2), n)
	for s: float in [-1.0, 1.0]:
		shape(cyl(0.05, 0.7, 5), red, Vector3(s * 0.32, 0.3, 0), Vector3(0, 0, -s * 50.0), Vector3(1, 1, 0.3), n)
		shape(cyl(0.05, 0.75, 5), red, Vector3(s * 0.2, -0.8, 0), Vector3(0, 0, s * 15.0), Vector3(1, 1, 0.3), n)
	shape(cyl(0.07, 0.8, 6, 0.04), red, Vector3(0.7, 0.75, 0), Vector3(0, 0, -30), Vector3(1, 1, 0.3), n)
	# his hand prints, and a sun
	for k in 8:
		var hp := Vector3(-3.9 + k * 0.42, -2.2 + (k % 2) * 0.35, 0)
		shape(ball(0.12, 6), red.darkened(0.08 * (k % 3)), hp, Vector3.ZERO, Vector3(1, 1.2, 0.15), n)
		for f in 5:
			var fa := lerpf(-0.8, 0.8, f / 4.0)
			shape(cyl(0.025, 0.14, 4), red, hp + Vector3(sin(fa) * 0.14, 0.15 + cos(fa) * 0.04, 0), Vector3(0, 0, -rad_to_deg(fa)), Vector3(1, 1, 0.3), n)
	shape(cyl(0.3, 0.04, 12), Color("e0a020"), Vector3(-3.4, 0.6, 0), Vector3(90, 0, 0), Vector3.ONE, n)
	for r in 8:
		var ra := r * TAU / 8.0
		shape(cyl(0.025, 0.22, 4), Color("e0a020"), Vector3(-3.4 + cos(ra) * 0.45, 0.6 + sin(ra) * 0.45, 0), Vector3(0, 0, rad_to_deg(ra) - 90.0), Vector3(1, 1, 0.3), n)


func _thunder_egg(at: Vector3) -> void:
	_egg = pivot(at)
	_movers.append(_egg)
	var grey := Color("8a8580")
	for s: float in [-1.0, 1.0]:                                  # the two halves, cracked apart
		var half := pivot(Vector3(s * 0.18, 0.42, 0), _egg)
		half.rotation.z = -s * 0.35
		shape(ball(0.42, 10), grey, Vector3.ZERO, Vector3.ZERO, Vector3(0.55, 1.2, 0.9), half)
		for k in 5:
			var a := lerpf(-1.0, 1.0, k / 4.0)
			var m := shape(cone(0.06, 0.24, 4), Color("a77bff"), Vector3(-s * 0.15, a * 0.3, sin(a * 2.0) * 0.2), Vector3(0, 0, s * 90.0), Vector3.ONE, half)
			m.material_override = home._glow(Color("a77bff"), 1.4)
	home._blocks.append([Vector2(at.x, at.z), 0.5])


func _statue(at: Vector3) -> void:
	var g := ground(at.x, at.z)
	var p := Vector3(at.x, g, at.z)
	var iv := Color("f3ead2")
	shape(cyl(0.55, 0.7, 10), home.ROCK, p + Vector3(0, 0.35, 0))
	shape(cyl(0.22, 0.75, 8, 0.18), iv, p + Vector3(0, 1.1, 0))                  # body
	shape(ball(0.24, 8), iv, p + Vector3(0, 1.62, 0))                           # head
	for k in 8:
		var a := lerpf(-1.4, 1.4, k / 7.0)
		shape(cone(0.06, 0.28, 4), iv.darkened(0.06), p + Vector3(sin(a) * 0.2, 1.75 + cos(a) * 0.12, -0.08), Vector3(-25, 0, -rad_to_deg(a)))
	for s: float in [-1.0, 1.0]:
		shape(cyl(0.07, 0.42, 6), iv, p + Vector3(s * 0.26, 1.15, 0.05), Vector3(0, 0, -s * 20.0))
		shape(cyl(0.08, 0.4, 6), iv, p + Vector3(s * 0.1, 0.55 + 0.2, 0))
	shape(cyl(0.06, 0.6, 6, 0.04), iv.darkened(0.08), p + Vector3(0.42, 1.35, 0.05), Vector3(0, 0, -35))
	home._blocks.append([Vector2(p.x, p.z), 0.6])
	home._spot("statue", p + Vector3(0, 0, 1.3), "THE IVORY UGU", "Carved from mammoth ivory. He looks very brave.")


func _horn() -> void:
	var p := at_ground(Nature.STAR_ROCK.x + 1.0, Nature.STAR_ROCK.y + 0.7, Nature.ROCK_TOP)
	shape(cyl(0.07, 1.6, 6), home.BONE, p + Vector3(0, 0.8, 0))
	shape(cyl(0.06, 0.8, 6), home.BONE, p + Vector3(0, 1.55, 0), Vector3(0, 0, 90))
	var horn := pivot(p + Vector3(-0.3, 1.5, 0))
	for k in 6:
		var q := k / 5.0
		glowing(cyl(lerpf(0.09, 0.3, q), 0.32, 9), Color("ffcf40"), 0.8, Vector3(0.4 * q, -0.15 - q * 0.75 + q * q * 0.35, 0), Vector3(0, 0, -20.0 - q * 50.0), Vector3.ONE, horn)
	home._spot("horn", Vector3(p.x, p.y, p.z), "THE GOLDEN HORN", "E: blow it!")


## The horn: HOOOO across the island; the valley answers; the birds go up, the
## pup howls, every fire flares.
func _blow() -> void:
	if home._t - _horn_t < 4.0:
		return
	_horn_t = home._t
	var at := ugu() + Vector3(0, 2.0, 0)
	pop_word("HOOOOOOO!", at + Vector3(0, 1.5, 0), Color("ffcf40"), 130)
	var ring := glowing(cyl(1.0, 0.08, 40), Color("ffe680"), 2.0, ugu() + Vector3(0, 0.6, 0))
	var m := ring.material_override as StandardMaterial3D
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(70, 1, 70), 2.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 2.6)
	tw.chain().tween_callback(ring.queue_free)
	home._flare = 2.5
	home._pup_hop = 1.5
	if home._pup != null:
		pop_word("AWOOO!", home._pup.global_position + Vector3(0, 1.2, 0), Color("cfe8ff"), 80)
	for b in home._birds:
		b[4] = float(b[4]) * 3.0                             # the birds wheel up, fast
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		for b in home._birds:
			b[4] = float(b[4]) / 3.0)
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		pop_word("...hooooo...", at + Vector3(-6, 3, -8), Color(1, 0.9, 0.6, 0.8), 70)
		pop_word("...hoooo...", at + Vector3(7, 2.5, -10), Color(1, 0.9, 0.6, 0.6), 60))
	home._model.cheer(1.5)


## ------------------------------------------------------------------ NEW!
func _mark_new(kind: String) -> void:
	var at := _where(kind)
	var sp: CPUParticles3D = home._particles(16, 1.2, Color("fff2a0"), 0.04, 0.08, true)
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sp.emission_sphere_radius = 0.5
	sp.gravity = Vector3(0, 0.6, 0)
	sp.spread = 180.0
	sp.initial_velocity_min = 0.2
	sp.initial_velocity_max = 0.6
	sp.position = at
	add_child(sp)
	var l := Label3D.new()
	l.text = "NEW!"
	l.font = Pal.title_font()
	l.font_size = 64
	l.pixel_size = 0.005
	l.outline_size = 14
	l.modulate = Color("ffe066")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = at + Vector3(0, 0.9, 0)
	l.layers = MirrorKind.LAYER_LABELS
	add_child(l)
	_new.append([kind, sp, l, at])


## Which relics are new this visit (the welcome card tells them).
func new_ones() -> Array:
	return _new.map(func(e: Array) -> String: return e[0])


## ------------------------------------------------------------------ every frame
func _process(delta: float) -> void:
	if home == null:
		return
	var t: float = home._t
	var n := night()
	if _moon_mat != null:
		_moon_mat.emission_energy_multiplier = lerpf(0.6, 2.6, n)
		_moon_light.visible = n > 0.45
		_moon_light.light_energy = lerpf(0.0, 1.1, smoothstep(0.45, 0.8, n))
	if _crystal_mat != null:
		_crystal_mat.emission_energy_multiplier = lerpf(0.3, 2.2, n) * (1.0 + 0.1 * sin(t * 1.3))
		_crystal_light.visible = n > 0.45
		_crystal_light.light_energy = lerpf(0.0, 0.8, smoothstep(0.45, 0.8, n))
	if _shard != null:
		_shard.rotation.y += delta * 0.9
		_shard.position.y += sin(t * 2.0) * 0.002
	if _amber != null:
		_amber.rotation.z = sin(t * 1.4) * 0.12
		_amber.rotation.x = sin(t * 0.9) * 0.06
	if _egg != null:
		_egg_in -= delta
		if _egg_in < 0.0:
			_egg.rotation.z = sin(t * 60.0) * 0.05             # it rumbles...
			if _egg_in < -0.6:
				_egg_in = randf_range(6.0, 11.0)
				_egg.rotation.z = 0.0
				puff(_egg.global_position + Vector3(0, 0.6, 0), Color("c9a0ff"), 10, 1.5, true)
	# he went and looked: no longer new
	for i in range(_new.size() - 1, -1, -1):
		var e: Array = _new[i]
		var at: Vector3 = e[3]
		if Vector2(ugu().x, ugu().z).distance_to(Vector2(at.x, at.z)) < 3.2:
			(e[1] as Node).queue_free()
			(e[2] as Node).queue_free()
			var seen: Array = saved("seen_relics", [])
			if not seen.has(e[0]):
				seen.append(e[0])
				save_key("seen_relics", seen)
			pop_word(Relics.name_of(e[0]), at + Vector3(0, 0.8, 0), Color("6dffd8"), 60)
			_new.remove_at(i)
