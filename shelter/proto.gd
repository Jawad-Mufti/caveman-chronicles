extends Node3D
## THE SHELTER, a PROTOTYPE (not wired into the game; the design is
## docs/shelter_plan.md): Ugu's island as a 3D "paper diorama" that GROWS WITH
## HISTORY. The island and its buildings are low-poly 3D built from shapes in
## code; Ugu stays the 2D drawing he is in the levels (his real rig, drawn into a
## SubViewport) standing up in the world as a paper cut-out. The camera is fixed
## and tilted: kids never steer it.
##
## "Same spot, new age": every building is one spot with a ladder of looks
## (BUILDINGS: a builder per age). Districts the age hasn't opened yet lie under
## MIST. Keys: arrows / WASD walk, 1 / 2 / 3 the age (Stone, Farming,
## Industrial), Tab the whole island from above.
##   -- shot   pictures of every age to C:/tmp/shots/shelter_*.png, then quit

const ISLAND_R := 36.0           ## metres, roughly
const UGU_H := 1.75              ## how tall the cut-out stands
const SPEED := 7.0               ## m/s walking (a big island)
const CAM_BACK := Vector3(0, 9.5, 12.5)
const AGES := ["THE STONE AGE", "FARMING & METAL", "THE INDUSTRIAL AGE"]

const SAND := Color("d8c08a")
const GRASS := Color("4f8f45")
const GRASS_DARK := Color("3a7438")
const ROCK := Color("8a7b6e")
const HIDE := Color("9a6a40")
const BONE := Color("efe4c8")
const WOOD := Color("6b4a2c")
const PLANK := Color("8a6440")
const THATCH := Color("c9a24e")
const CLAY := Color("b8643a")
const BRICK := Color("9a4632")
const SLATE := Color("4a4c58")
const IRON := Color("4b4f57")
const BRASS := Color("c9a03c")
const CREAM := Color("e8dcc0")
const PINE := Color("2f5a3a")

## The districts: [name, centre (x, z), radius, the age it opens in]. Before that: mist.
const DISTRICTS := [
	["THE FARM VALLEY", Vector2(19, 3), 8.0, 1],
	["THE QUARRY HILL", Vector2(-20, -15), 8.0, 1],
	["THE HARBOUR", Vector2(0, 25), 7.0, 1],
	["THE LIGHTHOUSE CAPE", Vector2(24, -20), 6.0, 2],
]
## Every building: [spot (x, z), [name, line] for each age]. Its looks: _build_<id>(age, root).
const BUILDINGS := {
	"home": [Vector2(0, -8), [["THE HIDE HUT", "Bones and hides. Every age, it grows."],
		["THE LONGHOUSE", "Wood and thatch, room for everyone."],
		["THE MANSION", "Brick and glass. Ugu the inventor. The old cave is its cellar."]]],
	"hearth": [Vector2(0, -1.5), [["THE HEARTH", "Cook here: a meal is a power for the next level."],
		["THE CLAY OVEN", "Bakes, roasts, fires pots."],
		["THE STEAM BOILER", "The fire grew up: it powers the whole town."]]],
	"kekko": [Vector2(7, -3), [["KEKKO'S STALL", "\"Shiny stones! Diamonds! Answer my riddle for a discount...\""],
		["KEKKO'S MARKET", "Stalls of everything. The monkey still bites every coin."],
		["KEKKO & CO.", "A department store! Kekko wears a top hat now."]]],
	"smith": [Vector2(-12, 1), [["THE ANVIL STONE", "The Toolmaker will move in here."],
		["THE SMITHY", "Bronze, then iron. Weapons reforged."],
		["THE FACTORY", "Makes goods by itself while Ugu is away."]]],
	"closet": [Vector2(-5, 8), [["THE CLOSET", "Every costume he finds hangs here."],
		["THE LOOM", "Wool and linen: new clothes."],
		["THE TAILOR'S", "Suits, goggles, explorer coats."]]],
	"travel": [Vector2(17, 17), [["THE STABLE PLOT", "A mammoth calf could live here."],
		["THE STABLE", "Horses! Ride to the far side."],
		["THE STATION", "The steam train goes all round the island."]]],
	"farm": [Vector2(19, 3), [["", ""], ["THE FIELDS", "Seeds from berries: crops, a windmill."],
		["THE GREENHOUSE", "Glass and steam: fruit all year."]]],
	"mine": [Vector2(-18, -12), [["", ""], ["THE MINE", "Copper, then iron."],
		["THE COAL MINE", "Rails and carts. Coal for the engines."]]],
	"harbour": [Vector2(0, 21), [["", ""], ["THE PIER", "A sailboat: little islands nearby."],
		["THE STEAMSHIP", "Sail to new islands: bonus places."]]],
	"lookout": [Vector2(23, -19), [["", ""], ["THE WATCHTOWER", "See far. Hints of mysteries."],
		["THE LIGHTHOUSE", "Its lamp turns all night. A telescope for the mysteries."]]],
	"tree": [Vector2(-10, -9), [["THE SPIRIT SAPLING", "Spirit orbs make it grow."],
		["THE SPIRIT TREE", "The one thing that never changes, only grows."],
		["THE SPIRIT TREE", "Still here, in the town park."]]],
}

var age := 0
var _noise := FastNoiseLite.new()
var _ugu: CaveMan
var _ugu_vp: SubViewport
var _cut: Sprite3D
var _pos := Vector3(0, 0, 3)
var _cam: Camera3D
var _overview := false
var _age_root: Node3D
var _spin: Array = []             ## [node, axis, speed]: windmill blades, the lighthouse lamp
var _flicker: Array = []          ## [light, base energy]
var _train: Array = []            ## the train's cars
var _train_t := 0.0
var _spots: Array = []            ## [position, name, line, Label3D]
var _hint: Label
var _age_label: Label
var _t := 0.0


func _ready() -> void:
	Pal.install_fonts()
	_noise.seed = 7
	_noise.frequency = 0.06
	_build_world()
	_build_island()
	_build_ugu()
	_build_ui()
	set_age(0)
	if OS.get_cmdline_user_args().has("shot"):
		_shots.call_deferred()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match (e as InputEventKey).physical_keycode:
			KEY_1:
				set_age(0)
			KEY_2:
				set_age(1)
			KEY_3:
				set_age(2)
			KEY_TAB:
				_overview = not _overview


## ------------------------------------------------------------------ the world
func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("1c2140")              # the levels' dusk: deep blue over a warm horizon
	sm.sky_horizon_color = Color("c9776a")
	sm.ground_horizon_color = Color("3a3550")
	sm.ground_bottom_color = Color("15182a")
	sm.sun_angle_max = 0.0
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("6d6a9a")
	e.ambient_light_energy = 0.6
	e.fog_enabled = true
	e.fog_light_color = Color("4a4468")
	e.fog_density = 0.006
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffb37a")
	sun.light_energy = 0.9
	sun.rotation_degrees = Vector3(-30, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
	var moon := _shape(_ball(5.0, 12), Color.WHITE, Vector3(-60, 45, -120))
	moon.material_override = _glow(Color("f6f0d8"), 1.6)
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	sea.mesh = pm
	var sw := StandardMaterial3D.new()
	sw.albedo_color = Color(0.13, 0.42, 0.5, 0.94)
	sw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sw.metallic = 0.3
	sw.roughness = 0.1
	sea.material_override = sw
	sea.position.y = -0.05
	add_child(sea)
	_cam = Camera3D.new()
	_cam.fov = 38.0
	_cam.far = 400.0
	add_child(_cam)


func _mat(col: Color = Color.WHITE, vertex := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.vertex_color_use_as_albedo = vertex
	m.roughness = 0.9
	return m


func _glow(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _see_through(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## ------------------------------------------------------------------ the island
## The ground's height (metres): a big round island with a plateau, a hill in
## the north-west (the quarry), a cape in the north-east (the lighthouse), a
## bay cut into the south (the harbour).
func height(x: float, z: float) -> float:
	var d := Vector2(x, z).length() + _noise.get_noise_2d(x, z) * 3.0
	var top := 0.55 + _noise.get_noise_2d(x * 1.7 + 40.0, z * 1.7) * 0.15
	var h := lerpf(top, -0.7, smoothstep(ISLAND_R - 6.0, ISLAND_R + 1.0, d))
	h += 3.2 * exp(-Vector2(x + 21.0, z + 17.0).length_squared() / 60.0)        # the quarry hill
	h += 1.8 * exp(-Vector2(x - 25.0, z + 21.0).length_squared() / 30.0)        # the cape
	var bay := Vector2(x, (z - 30.0) * 0.8).length()
	h = lerpf(-0.7, h, smoothstep(7.0, 10.0, bay))                               # the bay
	return h


func _build_island() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 1.25
	var span := ISLAND_R + 4.0
	var n := int(span * 2.0 / step)
	for i in n:
		for j in n:
			var x0 := -span + i * step
			var z0 := -span + j * step
			var p := [Vector3(x0, 0, z0), Vector3(x0 + step, 0, z0), Vector3(x0 + step, 0, z0 + step), Vector3(x0, 0, z0 + step)]
			var under := 0
			for k in 4:
				p[k].y = height(p[k].x, p[k].z)
				if p[k].y < -0.6:
					under += 1
			if under == 4:
				continue
			for tri in [[p[0], p[1], p[2]], [p[0], p[2], p[3]]]:
				var hy: float = (tri[0].y + tri[1].y + tri[2].y) / 3.0
				var nrm: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
				if nrm.y < 0.0:
					nrm = -nrm
				var col := SAND
				if hy > 0.25:
					col = GRASS if _noise.get_noise_2d(tri[0].x * 3.0, tri[0].z * 3.0) > -0.1 else GRASS_DARK
				if (1.0 - nrm.y) > 0.3 and hy > 0.1:
					col = ROCK
				st.set_color(col)
				for v in tri:
					st.set_normal(nrm)
					st.add_vertex(v)
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = _mat(Color.WHITE, true)
	add_child(mesh)
	# a forest round the rim (the levels' pines), rocks about
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 90:
		var a := rng.randf() * TAU
		var r := rng.randf_range(12.0, ISLAND_R - 4.0)
		var at := Vector3(cos(a) * r, 0, sin(a) * r)
		if height(at.x, at.z) < 0.35 or _taken(Vector2(at.x, at.z)):
			continue
		_pine(at, rng.randf_range(0.8, 1.5), self)
	for i in 30:
		var a2 := rng.randf() * TAU
		var r2 := rng.randf_range(5.0, ISLAND_R - 5.0)
		var at2 := Vector3(cos(a2) * r2, 0, sin(a2) * r2)
		if not _taken(Vector2(at2.x, at2.z)) and height(at2.x, at2.z) > 0.3:
			_rock(at2, rng.randf_range(0.3, 0.9), self)


## Is this point kept clear (the village, a district, a road)?
func _taken(p: Vector2) -> bool:
	if p.length() < 12.0:
		return true
	for d in DISTRICTS:
		if p.distance_to(d[1]) < float(d[2]) + 1.0:
			return true
	for b in BUILDINGS:
		if p.distance_to(BUILDINGS[b][0]) < 4.0:
			return true
	return absf(p.length() - 27.0) < 2.0                  # the rail loop's ring


## ------------------------------------------------------------------ shapes
func _shape(mesh: Mesh, col: Color, at: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = _mat(col)
	m.position = at
	m.rotation_degrees = rot
	m.scale = scl
	(parent if parent != null else self).add_child(m)
	return m


func _box(size: Vector3, col: Color, at: Vector3, parent: Node3D, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _shape(b, col, at, rot, Vector3.ONE, parent)


func _cone(r: float, h: float, segs := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


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


## A roof: a triangular prism `w` wide, `d` deep, `h` high, its ridge along x.
func _roof(w: float, d: float, h: float, col: Color, at: Vector3, parent: Node3D) -> void:
	var p := PrismMesh.new()
	p.size = Vector3(d, h, w)
	_shape(p, col, at, Vector3(0, 90, 0), Vector3.ONE, parent)


func _pine(at: Vector3, s: float, parent: Node3D) -> void:
	var t := Node3D.new()
	t.position = Vector3(at.x, height(at.x, at.z), at.z)
	parent.add_child(t)
	_shape(_cyl(0.12 * s, 0.8 * s), WOOD, Vector3(0, 0.4 * s, 0), Vector3.ZERO, Vector3.ONE, t)
	for k in 3:
		_shape(_cone((0.9 - k * 0.22) * s, 1.1 * s), PINE.lightened(k * 0.06), Vector3(0, (1.0 + k * 0.6) * s, 0), Vector3.ZERO, Vector3.ONE, t)


func _rock(at: Vector3, s: float, parent: Node3D) -> void:
	_shape(_ball(s, 5), ROCK, Vector3(at.x, height(at.x, at.z) + s * 0.3, at.z), Vector3(0, at.x * 40.0, 0), Vector3(1.2, 0.7, 1.0), parent)


func _smoke(at: Vector3, parent: Node3D, amount := 14, col := Color(0.8, 0.8, 0.85, 0.5)) -> void:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 3.0
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0.4, 0.5, 0)
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.4
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.6
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 6
	m.rings = 3
	p.mesh = m
	p.material_override = _see_through(col)
	p.position = at
	parent.add_child(p)


func _fire(at: Vector3, parent: Node3D, s := 1.0, light := true) -> void:
	for k in 3:
		var fl := _shape(_cone((0.22 - k * 0.05) * s, (0.6 + k * 0.15) * s, 6), Color.WHITE, at + Vector3(0, (0.3 + k * 0.05) * s, 0), Vector3.ZERO, Vector3.ONE, parent)
		fl.material_override = _glow([Color("ff6a1a"), Color("ffae2e"), Color("fff1a0")][k], 2.2)
	if light:
		var l := OmniLight3D.new()
		l.light_color = Color("ff9a3c")
		l.light_energy = 2.2
		l.omni_range = 7.0 * s
		l.position = at + Vector3(0, 0.9, 0)
		parent.add_child(l)
		_flicker.append([l, 2.2])


func _window(at: Vector3, size: Vector2, parent: Node3D, rot := Vector3.ZERO) -> void:
	var w := _box(Vector3(size.x, size.y, 0.05), Color.WHITE, at, parent, rot)
	w.material_override = _glow(Color("ffcf7a"), 1.4)


func _lamp_post(at: Vector3, parent: Node3D) -> void:
	_shape(_cyl(0.06, 2.4, 6), IRON, at + Vector3(0, 1.2, 0), Vector3.ZERO, Vector3.ONE, parent)
	var g := _shape(_ball(0.18, 8), Color.WHITE, at + Vector3(0, 2.5, 0), Vector3.ZERO, Vector3.ONE, parent)
	g.material_override = _glow(Color("ffd98a"), 2.5)


## ------------------------------------------------------------------ the age
## Switch the island to an age: the buildings are rebuilt in its style, the
## districts it has opened come out of the mist.
func set_age(a: int) -> void:
	age = clampi(a, 0, AGES.size() - 1)
	if _age_root != null:
		_age_root.queue_free()
	_spin.clear()
	_flicker.clear()
	_train.clear()
	for s in _spots:
		(s[3] as Node).queue_free()
	_spots.clear()
	_age_root = Node3D.new()
	add_child(_age_root)
	for id in BUILDINGS:
		var spot: Vector2 = BUILDINGS[id][0]
		var info: Array = BUILDINGS[id][1][age]
		if info[0] == "":
			continue
		var root := Node3D.new()
		root.position = Vector3(spot.x, height(spot.x, spot.y), spot.y)
		_age_root.add_child(root)
		call("_build_" + id, age, root)
		_spot(Vector3(spot.x, 0, spot.y + 2.4), info[0], info[1])
	_build_roads()
	for d in DISTRICTS:
		if age < int(d[3]):
			_mist(d[1], d[2])
	if _age_label != null:
		_age_label.text = "%s     1 / 2 / 3: the age     Tab: the whole island" % AGES[age]


func _mist(c: Vector2, r: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(c.x * 7.0 + c.y)
	for i in 9:
		var p := c + Vector2(rng.randf_range(-r, r), rng.randf_range(-r, r)) * 0.7
		var s := rng.randf_range(r * 0.45, r * 0.75)
		var m := _shape(_ball(1.0, 10), Color.WHITE, Vector3(p.x, height(p.x, p.y) + 1.4, p.y), Vector3.ZERO, Vector3(s, s * 0.45, s), _age_root)
		m.material_override = _see_through(Color(0.85, 0.85, 0.95, 0.55))


## The roads from the plaza to every open district: earth in the old ages,
## cobbles and street lamps in the industrial one; and the rail loop.
func _build_roads() -> void:
	if age == 0:
		return
	var targets: Array = []
	for d in DISTRICTS:
		if age >= int(d[3]):
			targets.append(d[1])
	for tgt in targets:
		var to: Vector2 = tgt
		var steps := int(to.length() / 1.6)
		for i in range(4, steps):
			var p := to * (float(i) / steps)
			var col := Color("8a6a4a") if age == 1 else Color("7d7a80")
			_box(Vector3(1.8, 0.05, 1.7), col, Vector3(p.x, height(p.x, p.y) + 0.03, p.y), _age_root, Vector3(0, rad_to_deg(atan2(to.x, to.y)), 0))
			if age == 2 and i % 4 == 0:
				var side := Vector2(to.y, -to.x).normalized() * 1.4
				_lamp_post(Vector3(p.x + side.x, height(p.x + side.x, p.y + side.y), p.y + side.y), _age_root)
	if age == 2:
		_build_rails()


## The rail loop round the island (on a bridge over the bay) and the train on it.
func _build_rails() -> void:
	var ring := 27.0
	for i in 120:
		var a := TAU * i / 120.0
		var p := Vector2(cos(a), sin(a)) * ring
		var y := maxf(height(p.x, p.y), 0.9)
		_box(Vector3(0.25, 0.08, 1.5), WOOD, Vector3(p.x, y + 0.05, p.y), _age_root, Vector3(0, -rad_to_deg(a), 0))
		if height(p.x, p.y) < 0.6 and i % 2 == 0:
			_shape(_cyl(0.12, y + 0.8), WOOD, Vector3(p.x, (y - 0.8) * 0.5, p.y), Vector3.ZERO, Vector3.ONE, _age_root)
	for k in 4:
		var car := Node3D.new()
		_age_root.add_child(car)
		if k == 0:
			_shape(_cyl(0.45, 1.6, 10), IRON, Vector3(0, 0.75, 0), Vector3(0, 0, 90), Vector3.ONE, car)
			_box(Vector3(0.8, 1.1, 1.0), Color("7a2a24"), Vector3(-0.7, 0.85, 0), car)
			_shape(_cyl(0.14, 0.7, 8), IRON, Vector3(0.55, 1.4, 0), Vector3.ZERO, Vector3.ONE, car)
			_smoke(Vector3(0.55, 1.8, 0), car, 10)
		else:
			_box(Vector3(1.5, 0.9, 1.0), [Color("2f5a6a"), Color("6a2f3a"), Color("4a5a2f")][k - 1], Vector3(0, 0.7, 0), car)
			_box(Vector3(1.6, 0.08, 1.1), SLATE, Vector3(0, 1.18, 0), car)
		for wx in [-0.5, 0.5]:
			for wz in [-0.5, 0.5]:
				_shape(_cyl(0.22, 0.1, 8), Color("1a1a1e"), Vector3(wx, 0.25, wz), Vector3(90, 0, 0), Vector3.ONE, car)
		_train.append(car)


## ------------------------------------------------------------------ the buildings, age by age
func _build_home(a: int, r: Node3D) -> void:
	if a == 0:
		# the cave mound, and the first hut of bones and hides
		for b in [[Vector3(0, 1.2, -2.5), Vector3(3.2, 2.2, 2.4)], [Vector3(-2.2, 0.8, -2.2), Vector3(2.0, 1.5, 1.8)], [Vector3(2.3, 0.7, -2.1), Vector3(1.8, 1.3, 1.6)]]:
			_shape(_ball(1.0, 6), ROCK.darkened(0.1), b[0], Vector3(0, b[0].x * 30.0, 0), b[1], r)
		_shape(_ball(0.8, 8), Color("120c0a"), Vector3(0, 0.75, -0.85), Vector3.ZERO, Vector3(1.0, 1.05, 0.35), r)
		var hut := Node3D.new()
		hut.position = Vector3(-4.0, 0, 1.5)
		r.add_child(hut)
		_shape(_cone(1.5, 2.6, 9), HIDE, Vector3(0, 1.3, 0), Vector3.ZERO, Vector3.ONE, hut)
		for k in 5:
			var a2 := k * TAU / 5.0 + 0.3
			_shape(_cyl(0.06, 2.9, 5), BONE, Vector3(cos(a2) * 0.9, 1.4, sin(a2) * 0.9), Vector3(sin(a2) * 28.0, 0, -cos(a2) * 28.0), Vector3.ONE, hut)
	elif a == 1:
		# the longhouse: timber walls, a thatched roof, smoke from the roof hole
		_box(Vector3(7.0, 1.8, 3.4), PLANK, Vector3(0, 0.9, 0), r)
		_roof(7.6, 4.0, 2.0, THATCH, Vector3(0, 2.8, 0), r)
		_box(Vector3(1.0, 1.4, 0.1), Color("2a1a10"), Vector3(0, 0.7, 1.72), r)
		for wx in [-2.4, 2.4]:
			_window(Vector3(wx, 1.1, 1.72), Vector2(0.6, 0.5), r)
		_smoke(Vector3(0, 3.6, 0), r)
	else:
		# the mansion: two storeys of brick, a slate roof, chimneys, lit windows
		_box(Vector3(8.0, 3.0, 4.6), BRICK, Vector3(0, 1.5, 0), r)
		_box(Vector3(6.0, 2.2, 4.2), BRICK.lightened(0.05), Vector3(0, 4.1, 0), r)
		_roof(6.6, 4.8, 1.8, SLATE, Vector3(0, 6.1, 0), r)
		for cx in [-2.3, 2.3]:
			_box(Vector3(0.6, 1.6, 0.6), BRICK.darkened(0.2), Vector3(cx, 6.6, 0), r)
			_smoke(Vector3(cx, 7.5, 0), r, 8)
		for wx2 in [-3.0, -1.5, 1.5, 3.0]:
			_window(Vector3(wx2, 1.6, 2.32), Vector2(0.7, 1.0), r)
		for wx3 in [-2.0, 0.0, 2.0]:
			_window(Vector3(wx3, 4.2, 2.12), Vector2(0.7, 0.9), r)
		_box(Vector3(1.2, 2.0, 0.1), Color("3a2418"), Vector3(0, 1.0, 2.32), r)
		_box(Vector3(2.4, 0.2, 1.0), CREAM, Vector3(0, 0.1, 2.8), r)
		var gear := _shape(_cyl(0.7, 0.15, 12), BRASS, Vector3(3.2, 4.4, 2.15), Vector3(90, 0, 0), Vector3.ONE, r)
		_spin.append([gear, Vector3(0, 1, 0), 1.2])


func _build_hearth(a: int, r: Node3D) -> void:
	if a == 0:
		for k in 8:
			var an := k * TAU / 8.0
			_shape(_ball(0.16, 5), ROCK, Vector3(cos(an) * 0.55, 0.08, sin(an) * 0.55), Vector3.ZERO, Vector3.ONE, r)
		for k in 3:
			_shape(_cyl(0.07, 0.9), WOOD, Vector3(0, 0.12, 0), Vector3(0, k * 60.0, 80), Vector3.ONE, r)
		_fire(Vector3.ZERO, r)
	elif a == 1:
		# a clay dome oven, the fire glowing in its mouth
		_shape(_ball(1.2, 10), CLAY, Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1, 0.9, 1), r)
		_box(Vector3(0.7, 0.6, 0.2), Color("1a0c06"), Vector3(0, 0.45, 1.05), r)
		_fire(Vector3(0, 0.15, 1.0), r, 0.6)
		_shape(_cyl(0.18, 0.8, 8), CLAY.darkened(0.1), Vector3(0, 1.3, -0.3), Vector3.ZERO, Vector3.ONE, r)
		_smoke(Vector3(0, 1.8, -0.3), r, 8)
	else:
		# the steam boiler: an iron drum on its firebox, a tall stack, a brass gauge
		_box(Vector3(2.6, 0.8, 1.4), BRICK.darkened(0.2), Vector3(0, 0.4, 0), r)
		_shape(_cyl(0.75, 2.6, 14), IRON, Vector3(0, 1.4, 0), Vector3(0, 0, 90), Vector3.ONE, r)
		var fb := _box(Vector3(0.6, 0.4, 0.05), Color.WHITE, Vector3(0.6, 0.4, 0.72), r)
		fb.material_override = _glow(Color("ff7a2a"), 2.5)
		_shape(_cyl(0.22, 3.0, 10), IRON.darkened(0.2), Vector3(-1.0, 3.0, 0), Vector3.ZERO, Vector3.ONE, r)
		_smoke(Vector3(-1.0, 4.6, 0), r, 18, Color(0.9, 0.9, 0.95, 0.55))
		_shape(_cyl(0.25, 0.1, 12), BRASS, Vector3(0.9, 1.6, 0.76), Vector3(90, 0, 0), Vector3.ONE, r)
		var l := OmniLight3D.new()
		l.light_color = Color("ff8a3c")
		l.light_energy = 1.6
		l.omni_range = 5.0
		l.position = Vector3(0.6, 0.6, 1.2)
		r.add_child(l)
		_flicker.append([l, 1.6])


func _build_kekko(a: int, r: Node3D) -> void:
	var gems := [Color("6cc4ff"), Color("d08bff"), Color("ffcf40"), Color("ff6b8a"), Color("8fe07a")]
	if a == 0:
		for px in [-1.0, 1.0]:
			_shape(_cyl(0.07, 1.8), WOOD, Vector3(px, 0.9, 0.5), Vector3.ZERO, Vector3.ONE, r)
			_shape(_cyl(0.07, 1.4), WOOD, Vector3(px, 0.7, -0.5), Vector3.ZERO, Vector3.ONE, r)
		_box(Vector3(2.4, 0.06, 1.4), Color("b0503a"), Vector3(0, 1.75, 0), r, Vector3(-14, 0, 0))
		_shape(_cyl(0.25, 1.9, 8), WOOD, Vector3(0, 0.45, 0.2), Vector3(0, 0, 90), Vector3.ONE, r)
		for k in gems.size():
			var g := _shape(_ball(0.1, 4), Color.WHITE, Vector3(-0.7 + k * 0.35, 0.78, 0.2), Vector3(0, k * 30.0, 0), Vector3.ONE, r)
			g.material_override = _glow(gems[k], 1.2)
	elif a == 1:
		# a market: three stalls under striped awnings
		for s in 3:
			var x := -2.6 + s * 2.6
			for px in [-0.9, 0.9]:
				_shape(_cyl(0.06, 1.9), WOOD, Vector3(x + px, 0.95, 0.4), Vector3.ZERO, Vector3.ONE, r)
			_box(Vector3(2.2, 0.06, 1.4), [Color("c0392b"), Color("2e6fa8"), Color("d8a020")][s], Vector3(x, 1.85, 0), r, Vector3(-14, 0, 0))
			_box(Vector3(1.9, 0.6, 0.8), PLANK, Vector3(x, 0.3, 0.1), r)
			for k in 3:
				var g2 := _shape(_ball(0.12, 4), Color.WHITE, Vector3(x - 0.5 + k * 0.5, 0.7, 0.1), Vector3.ZERO, Vector3.ONE, r)
				g2.material_override = _glow(gems[(s + k) % gems.size()], 1.2)
	else:
		# KEKKO & CO.: a department store with big shop windows and an awning
		_box(Vector3(6.0, 4.2, 4.0), CREAM, Vector3(0, 2.1, 0), r)
		_box(Vector3(6.4, 0.4, 4.4), SLATE, Vector3(0, 4.4, 0), r)
		for wx in [-1.9, 1.9]:
			_window(Vector3(wx, 1.4, 2.02), Vector2(1.8, 1.6), r)
		_box(Vector3(1.0, 2.2, 0.1), Color("3a2418"), Vector3(0, 1.1, 2.02), r)
		for k in 6:
			_box(Vector3(1.0, 0.06, 1.0), Color("c0392b") if k % 2 == 0 else CREAM, Vector3(-2.5 + k * 1.0, 2.6, 2.4), r, Vector3(-20, 0, 0))
		var sign := Label3D.new()
		sign.text = "KEKKO & CO."
		sign.font = Pal.title_font()
		sign.font_size = 96
		sign.pixel_size = 0.008
		sign.outline_size = 16
		sign.modulate = BRASS.lightened(0.3)
		sign.position = Vector3(0, 3.5, 2.06)
		r.add_child(sign)


func _build_smith(a: int, r: Node3D) -> void:
	if a == 0:
		_shape(_ball(0.6, 5), ROCK.darkened(0.2), Vector3(0, 0.35, 0), Vector3.ZERO, Vector3(1.3, 0.6, 0.8), r)
		for k in 10:
			var an := k * TAU / 10.0
			_shape(_ball(0.13, 4), BONE, Vector3(cos(an) * 1.6, 0.05, sin(an) * 1.6), Vector3.ZERO, Vector3.ONE, r)
	elif a == 1:
		# a smithy: an open shed, the anvil, the forge glowing
		for px in [-1.5, 1.5]:
			for pz in [-1.2, 1.2]:
				_shape(_cyl(0.1, 2.4), WOOD, Vector3(px, 1.2, pz), Vector3.ZERO, Vector3.ONE, r)
		_roof(3.6, 3.0, 1.0, THATCH.darkened(0.2), Vector3(0, 2.9, 0), r)
		_box(Vector3(0.8, 0.5, 0.4), IRON, Vector3(0.6, 0.55, 0.2), r)
		_box(Vector3(1.2, 0.8, 1.0), ROCK, Vector3(-0.8, 0.4, -0.4), r)
		var gl := _box(Vector3(0.7, 0.1, 0.6), Color.WHITE, Vector3(-0.8, 0.85, -0.4), r)
		gl.material_override = _glow(Color("ff6a1a"), 2.5)
		_smoke(Vector3(-0.8, 1.2, -0.4), r, 8)
	else:
		# a factory: brick halls, a saw-tooth roof, two tall smoking stacks
		_box(Vector3(8.0, 3.4, 5.0), BRICK.darkened(0.05), Vector3(0, 1.7, 0), r)
		for k in 3:
			var pr := PrismMesh.new()
			pr.left_to_right = 0.0
			pr.size = Vector3(2.6, 1.2, 5.0)
			_shape(pr, SLATE, Vector3(-2.6 + k * 2.6, 4.0, 0), Vector3.ZERO, Vector3.ONE, r)
		for sx in [-3.0, 2.8]:
			_shape(_cyl(0.4, 6.5, 10, 0.32), BRICK.darkened(0.25), Vector3(sx, 3.25, -1.6), Vector3.ZERO, Vector3.ONE, r)
			_smoke(Vector3(sx, 6.8, -1.6), r, 20, Color(0.55, 0.55, 0.6, 0.55))
		for wx in [-3.0, -1.5, 0.0, 1.5, 3.0]:
			_window(Vector3(wx, 1.8, 2.52), Vector2(0.9, 1.2), r)
		var wheel := _shape(_cyl(1.0, 0.2, 12), IRON, Vector3(4.1, 2.0, 0), Vector3(0, 0, 90), Vector3.ONE, r)
		_spin.append([wheel, Vector3(1, 0, 0), 1.5])


func _build_closet(a: int, r: Node3D) -> void:
	var cloth := [Color("d9a64e"), Color("8a6a4a"), Color("c8553d")]
	if a == 0:
		for px in [-0.8, 0.8]:
			_shape(_cyl(0.05, 1.6), WOOD, Vector3(px, 0.8, 0), Vector3.ZERO, Vector3.ONE, r)
		_shape(_cyl(0.05, 1.8), WOOD, Vector3(0, 1.55, 0), Vector3(0, 0, 90), Vector3.ONE, r)
		for k in 3:
			_box(Vector3(0.4, 0.8, 0.04), cloth[k], Vector3(-0.5 + k * 0.5, 1.1, 0), r, Vector3(0, 0, (k - 1) * 4.0))
	elif a == 1:
		_shape(_cyl(1.3, 1.8, 10), PLANK, Vector3(0, 0.9, -0.5), Vector3.ZERO, Vector3.ONE, r)
		_shape(_cone(1.6, 1.2, 10), THATCH, Vector3(0, 2.4, -0.5), Vector3.ZERO, Vector3.ONE, r)
		for px in [-0.7, 0.7]:
			_shape(_cyl(0.05, 1.4), WOOD, Vector3(px, 0.7, 1.2), Vector3.ZERO, Vector3.ONE, r)
		for k in 7:
			_box(Vector3(0.04, 1.2, 0.02), [Color("c0392b"), Color("2e6fa8"), Color("d8a020")][k % 3], Vector3(-0.6 + k * 0.2, 0.75, 1.2), r)
	else:
		_box(Vector3(3.6, 3.0, 3.0), Color("5a6a7a"), Vector3(0, 1.5, 0), r)
		_roof(4.0, 3.4, 1.0, SLATE, Vector3(0, 3.5, 0), r)
		_window(Vector3(-0.6, 1.3, 1.52), Vector2(1.6, 1.4), r)
		_shape(_cone(0.35, 1.2, 8), Color("2a2a3a"), Vector3(-0.6, 1.0, 1.25), Vector3.ZERO, Vector3.ONE, r)
		_box(Vector3(0.8, 1.9, 0.1), Color("3a2418"), Vector3(1.1, 0.95, 1.52), r)


func _build_travel(a: int, r: Node3D) -> void:
	if a == 0:
		for k in 10:
			var an := k * TAU / 10.0
			_shape(_ball(0.13, 4), BONE, Vector3(cos(an) * 1.6, 0.05, sin(an) * 1.6), Vector3.ZERO, Vector3.ONE, r)
	elif a == 1:
		# a stable, its fence, and a horse
		_box(Vector3(3.4, 1.8, 2.2), PLANK, Vector3(0, 0.9, -1.0), r)
		_roof(3.8, 2.6, 0.9, THATCH, Vector3(0, 2.25, -1.0), r)
		for k in 6:
			_shape(_cyl(0.06, 0.9), WOOD, Vector3(-2.2 + k * 0.9, 0.45, 1.6), Vector3.ZERO, Vector3.ONE, r)
		_box(Vector3(4.6, 0.08, 0.08), WOOD, Vector3(0.05, 0.75, 1.6), r)
		_horse(Vector3(0.6, 0, 0.6), r)
	else:
		# the station: a platform under an iron-and-glass roof, by the rail loop
		_box(Vector3(6.0, 0.4, 2.4), Color("8a8580"), Vector3(0, 0.2, 0), r)
		for px in [-2.6, 0.0, 2.6]:
			_shape(_cyl(0.08, 2.6, 6), IRON, Vector3(px, 1.5, -0.8), Vector3.ZERO, Vector3.ONE, r)
		var glass := _box(Vector3(6.4, 0.08, 2.8), Color.WHITE, Vector3(0, 2.85, 0), r, Vector3(8, 0, 0))
		glass.material_override = _see_through(Color(0.7, 0.85, 0.95, 0.35))
		var clock := _shape(_cyl(0.35, 0.08, 14), CREAM, Vector3(0, 2.3, -0.75), Vector3(90, 0, 0), Vector3.ONE, r)
		clock.material_override = _glow(CREAM, 0.8)


func _horse(at: Vector3, parent: Node3D) -> void:
	var h := Node3D.new()
	h.position = at
	parent.add_child(h)
	var coat := Color("7a4a2a")
	_box(Vector3(1.4, 0.6, 0.5), coat, Vector3(0, 1.0, 0), h)
	_box(Vector3(0.35, 0.8, 0.32), coat, Vector3(0.75, 1.4, 0), h, Vector3(0, 0, -30))
	_box(Vector3(0.55, 0.28, 0.28), coat, Vector3(1.05, 1.75, 0), h, Vector3(0, 0, 15))
	_box(Vector3(0.6, 0.1, 0.1), Color("2a1a10"), Vector3(0.65, 1.7, 0), h, Vector3(0, 0, -30))
	for lx in [-0.5, 0.5]:
		for lz in [-0.15, 0.15]:
			_shape(_cyl(0.07, 0.75, 5), coat.darkened(0.2), Vector3(lx, 0.38, lz), Vector3.ZERO, Vector3.ONE, h)
	_shape(_cyl(0.05, 0.6, 5), Color("2a1a10"), Vector3(-0.8, 0.9, 0), Vector3(0, 0, -30), Vector3.ONE, h)


func _build_farm(a: int, r: Node3D) -> void:
	var crops := [Color("d8b44a"), Color("6aa84f"), Color("c97a3a"), Color("9ac455")]
	for row in 8:
		for col in 2:
			_box(Vector3(5.0, 0.25, 0.7), crops[(row + col) % crops.size()], Vector3(-3.5 + col * 6.0, 0.12, -4.0 + row * 1.0), r)
	if a == 1:
		# the windmill, its sails turning
		_shape(_cyl(0.9, 4.0, 8, 0.6), CREAM.darkened(0.15), Vector3(4.5, 2.0, 4.0), Vector3.ZERO, Vector3.ONE, r)
		_shape(_cone(0.9, 1.0, 8), THATCH.darkened(0.2), Vector3(4.5, 4.5, 4.0), Vector3.ZERO, Vector3.ONE, r)
		var hub := Node3D.new()
		hub.position = Vector3(4.5, 3.6, 4.95)
		r.add_child(hub)
		for k in 4:
			_box(Vector3(0.35, 3.0, 0.04), CREAM, Vector3(0, 1.5, 0).rotated(Vector3(0, 0, 1), k * PI * 0.5), hub, Vector3(0, 0, k * 90.0))
		_spin.append([hub, Vector3(0, 0, 1), 0.8])
	else:
		# a greenhouse of glass and iron, glowing, and a steam tractor
		var gh := _box(Vector3(5.0, 2.2, 3.0), Color.WHITE, Vector3(4.0, 1.1, 4.0), r)
		gh.material_override = _see_through(Color(0.75, 0.95, 0.85, 0.35))
		_roof(5.2, 3.2, 1.0, Color.WHITE, Vector3(4.0, 2.7, 4.0), r)
		for k in 4:
			var plant := _shape(_ball(0.4, 6), Color.WHITE, Vector3(2.6 + k * 0.95, 0.5, 4.0), Vector3.ZERO, Vector3.ONE, r)
			plant.material_override = _glow(Color("7ad86a"), 0.6)
		_box(Vector3(1.6, 0.8, 1.0), Color("2e6f4a"), Vector3(-4.0, 0.8, 4.2), r)
		_shape(_cyl(0.6, 0.3, 12), Color("1a1a1e"), Vector3(-4.6, 0.6, 4.75), Vector3(90, 0, 0), Vector3.ONE, r)
		_shape(_cyl(0.12, 1.0, 8), IRON, Vector3(-3.6, 1.6, 4.2), Vector3.ZERO, Vector3.ONE, r)
		_smoke(Vector3(-3.6, 2.2, 4.2), r, 8)


func _build_mine(a: int, r: Node3D) -> void:
	# the mine's mouth in the hillside, timbered
	_box(Vector3(2.0, 2.2, 0.3), Color("120c0a"), Vector3(0, 1.1, -0.6), r)
	for px in [-1.1, 1.1]:
		_box(Vector3(0.25, 2.4, 0.3), WOOD, Vector3(px, 1.2, -0.4), r)
	_box(Vector3(2.6, 0.3, 0.3), WOOD, Vector3(0, 2.45, -0.4), r)
	_box(Vector3(1.1, 0.6, 0.7), WOOD.darkened(0.2), Vector3(0.4, 0.4, 1.0), r)
	var ore := Color("c27a4a") if a == 1 else Color("1a1a1e")
	for k in 4:
		_shape(_ball(0.22, 4), ore, Vector3(0.2 + (k % 2) * 0.35, 0.8, 0.9 + (k / 2) * 0.3), Vector3.ZERO, Vector3.ONE, r)
	if a == 2:
		# the headframe and its wheel, rails out of the mouth
		for px2 in [-1.4, 1.4]:
			_shape(_cyl(0.12, 6.0, 6), IRON, Vector3(px2 * 0.6, 3.0, -1.6), Vector3(0, 0, px2 * 6.0), Vector3.ONE, r)
		var wheel := _shape(_cyl(1.0, 0.15, 14), IRON.lightened(0.1), Vector3(0, 6.0, -1.6), Vector3(90, 0, 0), Vector3.ONE, r)
		_spin.append([wheel, Vector3(0, 1, 0), 1.0])
		for k in 8:
			_box(Vector3(1.4, 0.06, 0.18), WOOD, Vector3(0, 0.05, 0.2 + k * 0.5), r)
		for k in 6:
			_shape(_ball(0.6, 5), Color("1a1a1e"), Vector3(2.5 + (k % 3) * 0.6, 0.3 + (k / 3) * 0.4, 1.0), Vector3.ZERO, Vector3(1, 0.6, 1), r)


func _build_harbour(a: int, r: Node3D) -> void:
	# the pier
	var long := 6.0 if a == 1 else 10.0
	for k in int(long):
		_box(Vector3(1.6, 0.12, 1.0), PLANK, Vector3(0, 0.45, 1.0 + k * 1.0), r)
		if k % 2 == 0:
			for px in [-0.75, 0.75]:
				_shape(_cyl(0.1, 1.4), WOOD, Vector3(px, -0.2, 1.0 + k * 1.0), Vector3.ZERO, Vector3.ONE, r)
	var boat := Node3D.new()
	boat.position = Vector3(2.8, 0, long * 0.8)
	r.add_child(boat)
	if a == 1:
		# a sailboat
		var hull := PrismMesh.new()
		hull.size = Vector3(1.4, 0.8, 4.0)
		_shape(hull, PLANK.darkened(0.2), Vector3(0, 0.25, 0), Vector3(180, 0, 0), Vector3.ONE, boat)
		_shape(_cyl(0.07, 3.6, 6), WOOD, Vector3(0, 2.2, 0), Vector3.ZERO, Vector3.ONE, boat)
		var sail := PrismMesh.new()
		sail.size = Vector3(0.05, 2.8, 2.2)
		_shape(sail, CREAM, Vector3(0.05, 2.3, 0.6), Vector3.ZERO, Vector3.ONE, boat)
	else:
		# the steamship: an iron hull, a white cabin, a red funnel smoking
		_box(Vector3(2.4, 1.2, 7.0), Color("2a2a32"), Vector3(0, 0.4, 0), boat)
		_box(Vector3(2.4, 0.3, 7.0), Color("8a2a24"), Vector3(0, -0.1, 0), boat)
		_box(Vector3(1.8, 1.2, 3.0), CREAM, Vector3(0, 1.6, -0.5), boat)
		for wz in [-1.5, -0.5, 0.5]:
			_window(Vector3(0.92, 1.6, wz), Vector2(0.35, 0.35), boat, Vector3(0, 90, 0))
		_shape(_cyl(0.4, 1.6, 10), Color("c0392b"), Vector3(0, 2.9, 0.4), Vector3.ZERO, Vector3.ONE, boat)
		_smoke(Vector3(0, 3.9, 0.4), boat, 16)


func _build_lookout(a: int, r: Node3D) -> void:
	if a == 1:
		# a wooden watchtower
		for px in [-0.8, 0.8]:
			for pz in [-0.8, 0.8]:
				_shape(_cyl(0.1, 5.0), WOOD, Vector3(px, 2.5, pz), Vector3.ZERO, Vector3.ONE, r)
		_box(Vector3(2.2, 0.15, 2.2), PLANK, Vector3(0, 5.0, 0), r)
		_shape(_cone(1.6, 1.2, 4), THATCH, Vector3(0, 6.3, 0), Vector3(0, 45, 0), Vector3.ONE, r)
		_fire(Vector3(0, 5.1, 0), r, 0.5, false)
	else:
		# the lighthouse: white and red rings, a lamp that turns all night
		for k in 6:
			var rr := 1.3 - k * 0.12
			_shape(_cyl(rr, 1.2, 12, rr - 0.12), CREAM if k % 2 == 0 else Color("c0392b"), Vector3(0, 0.6 + k * 1.2, 0), Vector3.ZERO, Vector3.ONE, r)
		_box(Vector3(1.4, 0.15, 1.4), IRON, Vector3(0, 7.3, 0), r)
		var lamp := _shape(_ball(0.45, 10), Color.WHITE, Vector3(0, 7.8, 0), Vector3.ZERO, Vector3.ONE, r)
		lamp.material_override = _glow(Color("fff1b0"), 3.0)
		_shape(_cone(0.8, 0.7, 10), Color("8a2a24"), Vector3(0, 8.5, 0), Vector3.ZERO, Vector3.ONE, r)
		var beam := Node3D.new()
		beam.position = Vector3(0, 7.8, 0)
		r.add_child(beam)
		var ray := _shape(_cyl(0.15, 14.0, 8, 1.6), Color.WHITE, Vector3(0, 0, 7.0), Vector3(90, 0, 0), Vector3.ONE, beam)
		ray.material_override = _see_through(Color(1.0, 0.95, 0.7, 0.18))
		_spin.append([beam, Vector3(0, 1, 0), 0.9])


func _build_tree(a: int, r: Node3D) -> void:
	var s: float = [0.35, 0.8, 1.0][a]
	_shape(_cyl(0.35 * s, 3.0 * s, 8, 0.2 * s), WOOD.darkened(0.2), Vector3(0, 1.5 * s, 0), Vector3.ZERO, Vector3.ONE, r)
	for k in 5:
		var an := k * TAU / 5.0
		var leaf := _shape(_ball(1.3 * s, 8), Color.WHITE, Vector3(cos(an) * 1.0 * s, 3.4 * s + (k % 2) * 0.5 * s, sin(an) * 1.0 * s), Vector3.ZERO, Vector3.ONE, r)
		leaf.material_override = _glow(Color("7ad8ff").lerp(Color("b48cff"), k / 5.0), 0.7)
	if a == 2:
		for k in 3:
			_box(Vector3(1.4, 0.1, 0.4), PLANK, Vector3(cos(k * 2.1) * 2.8, 0.45, sin(k * 2.1) * 2.8), r, Vector3(0, -rad_to_deg(k * 2.1), 0))
			_lamp_post(Vector3(cos(k * 2.1 + 1.0) * 3.2, 0, sin(k * 2.1 + 1.0) * 3.2), r)


## A place he can walk up to: a name floats over it when he is near.
func _spot(at: Vector3, title: String, line: String) -> void:
	var l := Label3D.new()
	l.text = title
	l.font = Pal.title_font()
	l.font_size = 64
	l.pixel_size = 0.007
	l.outline_size = 14
	l.modulate = Color("ffe066")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.visible = false
	l.position = Vector3(at.x, height(at.x, at.z) + 3.2, at.z)
	add_child(l)
	_spots.append([Vector3(at.x, 0, at.z), title, line, l])


## ------------------------------------------------------------------ Ugu, a paper cut-out
func _build_ugu() -> void:
	_ugu_vp = SubViewport.new()
	_ugu_vp.size = Vector2i(320, 320)
	_ugu_vp.transparent_bg = true
	_ugu_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_ugu_vp)
	_ugu = CaveMan.new()
	_ugu.preview = true                      # his real rig, drawn: no physics, no input of its own
	_ugu.position = Vector2(160, 300)
	_ugu.scale = Vector2(2.6, 2.6)
	_ugu_vp.add_child(_ugu)
	GameState.apply_to(_ugu)
	_cut = Sprite3D.new()
	_cut.texture = _ugu_vp.get_texture()
	_cut.pixel_size = UGU_H / (78.0 * 2.6)
	_cut.offset = Vector2(0, 160 - 20)       # his feet on the ground
	_cut.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_cut.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_cut.shaded = true
	_cut.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_cut)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	_hint = _ui_label(ui, Vector2(140, 640), Vector2(1000, 60), 22, Color("f3e3c3"), Pal.text_font())
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ui_label(ui, Vector2(24, 14), Vector2(800, 40), 28, Color("ffcf40"), Pal.title_font()).text = "UGU'S ISLAND  ·  a prototype"
	_age_label = _ui_label(ui, Vector2(24, 52), Vector2(1000, 30), 18, Color("f3e3c3"), Pal.text_font())


func _ui_label(ui: Node, at: Vector2, size: Vector2, fs: int, col: Color, font: Font) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 8)
	l.position = at
	l.size = size
	ui.add_child(l)
	return l


## ------------------------------------------------------------------ every frame
func _process(delta: float) -> void:
	_t += delta
	var dir := Vector3.ZERO
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
	var near_line := ""
	for s in _spots:
		var close: bool = Vector2(_pos.x - s[0].x, _pos.z - s[0].z).length() < 2.6
		(s[3] as Label3D).visible = close
		if close:
			near_line = "%s — %s" % [s[1], s[2]]
	_hint.text = near_line


func _animate(delta: float) -> void:
	for s in _spin:
		if is_instance_valid(s[0]):
			(s[0] as Node3D).rotate_object_local(s[1], float(s[2]) * delta)
	for f in _flicker:
		if is_instance_valid(f[0]):
			(f[0] as OmniLight3D).light_energy = float(f[1]) * (1.0 + 0.15 * sin(_t * 11.0) + 0.08 * sin(_t * 23.0))
	_train_t += delta * 0.07
	for i in _train.size():
		var car: Node3D = _train[i]
		if not is_instance_valid(car):
			continue
		var a := _train_t - i * 0.07
		var p := Vector2(cos(a), sin(a)) * 27.0
		car.position = Vector3(p.x, maxf(height(p.x, p.y), 0.9) + 0.1, p.y)
		car.rotation.y = -a - PI * 0.5


## One step of walking (also used by the picture-taker).
func walk(dir: Vector3, delta: float) -> void:
	var moving := dir.length() > 0.01
	if moving:
		dir = dir.normalized()
		var next := _pos + dir * SPEED * delta
		if height(next.x, next.z) > 0.25 and Vector2(next.x, next.z).length() < ISLAND_R - 2.0:
			_pos = next
		if absf(dir.x) > 0.1:
			_ugu.facing = 1 if dir.x > 0.0 else -1
	_ugu.velocity.x = float(_ugu.facing) * (CaveMan.SPEED if moving else 0.0)
	if moving:
		_ugu._run_phase += CaveMan.SPEED * delta / (_ugu._stride_amp(1.0) * CaveMan.ART)
	_pos.y = height(_pos.x, _pos.z)
	_cut.position = _pos
	var want := _pos + CAM_BACK
	var look := _pos + Vector3(0, 0.8, -1.5)
	if _overview:
		want = Vector3(0, 62, 72)
		look = Vector3(0, 0, 6)
	_cam.position = _cam.position.lerp(want, minf(1.0, delta * 3.0)) if _t > 0.1 else want
	_cam.look_at(look)


## ------------------------------------------------------------------ pictures
func _shots() -> void:
	DirAccess.make_dir_recursive_absolute("C:/tmp/shots")
	for a in 3:
		set_age(a)
		_pos = Vector3(0, 0, 3)
		_overview = false
		for f in 40:
			walk(Vector3.ZERO, 1.0 / 60.0)
			_animate(1.0 / 60.0)
			await get_tree().process_frame
		await _shot("a%d_plaza" % a)
		_overview = true
		_t = 0.0
		for f in 3:
			walk(Vector3.ZERO, 1.0 / 60.0)
			await get_tree().process_frame
		await _shot("a%d_island" % a)
		_overview = false
		_pos = Vector3(14, 0, 8)
		_t = 0.0
		for f in 6:
			walk(Vector3.ZERO, 1.0 / 60.0)
			await get_tree().process_frame
		_cam.position = Vector3(14, 14, 24)
		_cam.look_at(Vector3(10, 1, 0))
		await _shot("a%d_east" % a)
	get_tree().quit()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/shelter_%s.png" % label)
	print("shot ", label)
