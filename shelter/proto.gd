extends Node3D
## THE SHELTER, a PROTOTYPE (not wired into the game): Ugu's island as a little
## 3D "paper diorama". The island, the huts, the trees and the fire are
## low-poly 3D built from shapes in code; Ugu stays the 2D drawing he is in the
## levels (his real rig, drawn into a SubViewport) standing up in the world as a
## paper cut-out, like Paper Mario. The camera is fixed and tilted: kids never
## steer it.
##
## Play: arrows / WASD walk, E talks at a glowing spot. Run it on its own
## (F6 in the editor, or res://shelter/proto.tscn).
##   -- shot   pictures to C:/tmp/shots/shelter_*.png, then quit

const ISLAND_R := 15.0           ## metres, roughly
const UGU_H := 1.75              ## how tall the cut-out stands, metres
const SPEED := 4.2               ## m/s walking
const CAM_BACK := Vector3(0, 8.5, 11.0)

const SAND := Color("d8c08a")
const GRASS := Color("4f8f45")
const GRASS_DARK := Color("3a7438")
const ROCK := Color("8a7b6e")
const HIDE := Color("9a6a40")
const BONE := Color("efe4c8")
const WOOD := Color("6b4a2c")
const PINE := Color("2f5a3a")

var _noise := FastNoiseLite.new()
var _ugu: CaveMan
var _ugu_vp: SubViewport
var _cut: Sprite3D
var _pos := Vector3(0, 0, 4)
var _cam: Camera3D
var _fire_light: OmniLight3D
var _flames: Array = []
var _spots: Array = []            ## [position, name, line, Label3D]
var _hint: Label
var _t := 0.0


func _ready() -> void:
	Pal.install_fonts()
	_noise.seed = 7
	_noise.frequency = 0.09
	_build_world()
	_build_island()
	_build_village()
	_build_ugu()
	_build_ui()
	if OS.get_cmdline_user_args().has("shot"):
		_shots.call_deferred()


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
	e.ambient_light_energy = 0.55
	e.fog_enabled = true
	e.fog_light_color = Color("4a4468")
	e.fog_density = 0.012
	env.environment = e
	add_child(env)
	# the low sun, warm, from the side: long shadows
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffb37a")
	sun.light_energy = 0.9
	sun.rotation_degrees = Vector3(-28, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	# the moon, up there, and the sea all round
	var moon := MeshInstance3D.new()
	var ms := SphereMesh.new()
	ms.radius = 3.0
	ms.height = 6.0
	moon.mesh = ms
	moon.material_override = _glow(Color("f6f0d8"), 1.6)
	moon.position = Vector3(-30, 30, -70)
	add_child(moon)
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(240, 240)
	sea.mesh = pm
	var sw := StandardMaterial3D.new()
	sw.albedo_color = Color(0.16, 0.36, 0.48, 0.92)
	sw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sw.metallic = 0.2
	sw.roughness = 0.15
	sea.material_override = sw
	sea.position.y = -0.05
	add_child(sea)
	_cam = Camera3D.new()
	_cam.fov = 38.0
	add_child(_cam)


## A flat-shaded material that takes the mesh's vertex colours.
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


## ------------------------------------------------------------------ the island
## The ground's height (metres) at a point: a round island with a raised
## plateau for the village, bumpy at the edges, under the sea past its rim.
func height(x: float, z: float) -> float:
	var d := Vector2(x, z).length() + _noise.get_noise_2d(x, z) * 2.2
	var top := 0.55 + _noise.get_noise_2d(x * 1.7 + 40.0, z * 1.7) * 0.12
	return lerpf(top, -0.6, smoothstep(ISLAND_R - 4.0, ISLAND_R + 1.0, d))


func _build_island() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 0.9
	var n := int((ISLAND_R + 3.0) * 2.0 / step)
	var o := -(ISLAND_R + 3.0)
	for i in n:
		for j in n:
			var x0 := o + i * step
			var z0 := o + j * step
			var p := [Vector3(x0, 0, z0), Vector3(x0 + step, 0, z0), Vector3(x0 + step, 0, z0 + step), Vector3(x0, 0, z0 + step)]
			for k in 4:
				p[k].y = height(p[k].x, p[k].z)
			if p[0].y < -0.5 and p[1].y < -0.5 and p[2].y < -0.5 and p[3].y < -0.5:
				continue
			for tri in [[p[0], p[1], p[2]], [p[0], p[2], p[3]]]:
				var hy: float = (tri[0].y + tri[1].y + tri[2].y) / 3.0
				var nrm: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
				var steep := 1.0 - absf(nrm.y)
				var col := SAND
				if hy > 0.22:
					col = GRASS if _noise.get_noise_2d(tri[0].x * 3.0, tri[0].z * 3.0) > -0.1 else GRASS_DARK
				if steep > 0.35 and hy > 0.1:
					col = ROCK
				st.set_color(col)
				for v in tri:
					st.set_normal(-nrm if nrm.y < 0.0 else nrm)
					st.add_vertex(v)
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = _mat(Color.WHITE, true)
	add_child(mesh)
	# pines round the rim, rocks about
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 26:
		var a := rng.randf() * TAU
		var r := rng.randf_range(8.5, 12.5)
		var at := Vector3(cos(a) * r, 0, sin(a) * r)
		if at.z > 3.0 and absf(at.x) < 6.0:
			continue                                   # (keep the view to the village clear)
		_pine(at, rng.randf_range(0.8, 1.4))
	for i in 14:
		var a2 := rng.randf() * TAU
		var r2 := rng.randf_range(4.0, 12.0)
		_rock(Vector3(cos(a2) * r2, 0, sin(a2) * r2), rng.randf_range(0.25, 0.7))


func _put(node: Node3D, at: Vector3) -> Node3D:
	node.position = Vector3(at.x, height(at.x, at.z) + at.y, at.z)
	add_child(node)
	return node


func _shape(mesh: Mesh, col: Color, at: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = _mat(col)
	m.position = at
	m.rotation_degrees = rot
	m.scale = scl
	(parent if parent != null else self).add_child(m)
	return m


func _cone(r: float, h: float, segs := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


func _cyl(r: float, h: float, segs := 7) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
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
	s.rings = 4
	return s


func _pine(at: Vector3, s: float) -> void:
	var t := _put(Node3D.new(), at)
	_shape(_cyl(0.12 * s, 0.8 * s), WOOD, Vector3(0, 0.4 * s, 0), Vector3.ZERO, Vector3.ONE, t)
	for k in 3:
		_shape(_cone((0.9 - k * 0.22) * s, 1.1 * s), PINE.lightened(k * 0.06), Vector3(0, (1.0 + k * 0.6) * s, 0), Vector3.ZERO, Vector3.ONE, t)


func _rock(at: Vector3, s: float) -> void:
	_shape(_ball(s, 5), ROCK, Vector3(at.x, height(at.x, at.z) + s * 0.3, at.z), Vector3(0, at.x * 40.0, 0), Vector3(1.2, 0.7, 1.0))


## ------------------------------------------------------------------ the village (Stone Age)
func _build_village() -> void:
	# THE CAVE: his first home, a rocky mound with a dark mouth, at the back of the plaza
	var cave := _put(Node3D.new(), Vector3(0, 0, -6.5))
	for b in [[Vector3(0, 1.2, 0), Vector3(3.2, 2.2, 2.4)], [Vector3(-2.2, 0.8, 0.3), Vector3(2.0, 1.5, 1.8)],
			[Vector3(2.3, 0.7, 0.4), Vector3(1.8, 1.3, 1.6)], [Vector3(0.6, 2.4, -0.4), Vector3(1.8, 1.4, 1.5)]]:
		_shape(_ball(1.0, 6), ROCK.darkened(0.1), b[0], Vector3(0, b[0].x * 30.0, 0), b[1], cave)
	_shape(_ball(0.8, 8), Color("120c0a"), Vector3(0, 0.75, 1.65), Vector3.ZERO, Vector3(1.0, 1.05, 0.35), cave)
	_spot(Vector3(0, 0, -4.4), "THE CAVE", "Home. For now... every age, it grows.")
	# THE HEARTH: the campfire in the middle of the plaza, the heart of it all
	var fire := _put(Node3D.new(), Vector3(0, 0, -1.0))
	for k in 8:
		var a := k * TAU / 8.0
		_shape(_ball(0.16, 5), ROCK, Vector3(cos(a) * 0.55, 0.08, sin(a) * 0.55), Vector3.ZERO, Vector3.ONE, fire)
	for k in 3:
		_shape(_cyl(0.07, 0.9), WOOD, Vector3(0, 0.12, 0), Vector3(0, k * 60.0, 80), Vector3.ONE, fire)
	for k in 3:
		var fl := _shape(_cone(0.22 - k * 0.05, 0.6 + k * 0.15, 6), Color.WHITE, Vector3(0, 0.35 + k * 0.05, 0), Vector3.ZERO, Vector3.ONE, fire)
		fl.material_override = _glow([Color("ff6a1a"), Color("ffae2e"), Color("fff1a0")][k], 2.2)
		_flames.append(fl)
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color("ff9a3c")
	_fire_light.light_energy = 2.4
	_fire_light.omni_range = 7.0
	_fire_light.position = Vector3(0, 0.9, 0)
	fire.add_child(_fire_light)
	var embers := CPUParticles3D.new()
	embers.amount = 24
	embers.lifetime = 1.6
	embers.direction = Vector3.UP
	embers.spread = 20.0
	embers.gravity = Vector3(0, 0.6, 0)
	embers.initial_velocity_min = 0.6
	embers.initial_velocity_max = 1.4
	embers.scale_amount_min = 0.04
	embers.scale_amount_max = 0.07
	var em := SphereMesh.new()
	em.radius = 0.5
	em.height = 1.0
	embers.mesh = em
	embers.material_override = _glow(Color("ffb347"), 3.0)
	embers.position = Vector3(0, 0.5, 0)
	fire.add_child(embers)
	_spot(Vector3(0, 0, -1.0), "THE HEARTH", "Cook here. Every age it grows: a clay oven, a kiln, a forge.")
	# THE HIDE HUT, of mammoth bones and hides (the first thing he builds)
	var hut := _put(Node3D.new(), Vector3(-4.5, 0, -2.5))
	_shape(_cone(1.5, 2.6, 9), HIDE, Vector3(0, 1.3, 0), Vector3.ZERO, Vector3.ONE, hut)
	for k in 5:
		var a2 := k * TAU / 5.0 + 0.3
		_shape(_cyl(0.06, 2.9, 5), BONE, Vector3(cos(a2) * 0.9, 1.4, sin(a2) * 0.9), Vector3(sin(a2) * 28.0, 0, -cos(a2) * 28.0), Vector3.ONE, hut)
	_shape(_cone(0.5, 1.1, 3), Color("2a1a10"), Vector3(0.35, 0.55, 1.25), Vector3(0, 20, 0), Vector3(1, 1, 0.4), hut)
	_spot(Vector3(-4.5, 0, -1.0), "THE HIDE HUT", "Bones and hides. Later: a longhouse, a stone house...")
	# KEKKO'S STALL: a wandering trader's awning, gems glinting on a log
	var stall := _put(Node3D.new(), Vector3(4.6, 0, -2.2))
	for px in [-1.0, 1.0]:
		_shape(_cyl(0.07, 1.8), WOOD, Vector3(px, 0.9, 0.5), Vector3.ZERO, Vector3.ONE, stall)
		_shape(_cyl(0.07, 1.4), WOOD, Vector3(px, 0.7, -0.5), Vector3.ZERO, Vector3.ONE, stall)
	_shape(BoxMesh.new(), Color("b0503a"), Vector3(0, 1.75, 0), Vector3(-14, 0, 0), Vector3(2.4, 0.06, 1.4), stall)
	_shape(_cyl(0.25, 1.9, 8), WOOD, Vector3(0, 0.45, 0.2), Vector3(0, 0, 90), Vector3.ONE, stall)
	var gems := [Color("6cc4ff"), Color("d08bff"), Color("ffcf40"), Color("ff6b8a"), Color("8fe07a")]
	for k in gems.size():
		var g := _shape(_ball(0.1, 4), Color.WHITE, Vector3(-0.7 + k * 0.35, 0.78, 0.2), Vector3(0, k * 30.0, 0), Vector3.ONE, stall)
		g.material_override = _glow(gems[k], 1.2)
	# Kekko himself: a tiny old trader under a pack bigger than he is (a cut-out, like Ugu)
	_shape(_ball(0.28, 6), Color("8a5a3a"), Vector3(0.9, 0.95, 0.9), Vector3.ZERO, Vector3(1, 1.3, 1), stall)
	_shape(_ball(0.42, 6), HIDE.darkened(0.2), Vector3(1.05, 1.15, 1.25), Vector3.ZERO, Vector3(1, 1.25, 0.9), stall)
	_shape(_ball(0.16, 6), Color("c89263"), Vector3(0.88, 1.38, 0.86), Vector3.ZERO, Vector3.ONE, stall)
	_spot(Vector3(4.6, 0, -0.6), "KEKKO'S STALL", "\"Shiny stones! Diamonds! Answer my riddle and I'll knock off three shells...\"")
	# THE CLOSET: hides drying on a rack (his costumes, one day a tailor's room)
	var rack := _put(Node3D.new(), Vector3(-2.2, 0, 2.6))
	for px2 in [-0.8, 0.8]:
		_shape(_cyl(0.05, 1.6), WOOD, Vector3(px2, 0.8, 0), Vector3.ZERO, Vector3.ONE, rack)
	_shape(_cyl(0.05, 1.8), WOOD, Vector3(0, 1.55, 0), Vector3(0, 0, 90), Vector3.ONE, rack)
	for k in 3:
		_shape(BoxMesh.new(), [Color("d9a64e"), Color("8a6a4a"), Color("c8553d")][k], Vector3(-0.5 + k * 0.5, 1.1, 0), Vector3(0, 0, (k - 1) * 4.0), Vector3(0.4, 0.8, 0.04), rack)
	_spot(Vector3(-2.2, 0, 3.4), "THE CLOSET", "Every costume he finds hangs here. Try them on!")
	# empty plots, marked with a ring of stones: what the coming ages will build
	for plot in [[Vector3(7.5, 0, 2.5), "A PLOT: THE STABLE", "A mammoth calf could live here. Later: horses!"],
			[Vector3(-7.5, 0, 2.0), "A PLOT: THE FORGE", "The Toolmaker will move in. Stone now, then bronze, then iron."]]:
		var ring := _put(Node3D.new(), plot[0])
		for k in 10:
			var a3 := k * TAU / 10.0
			_shape(_ball(0.13, 4), BONE, Vector3(cos(a3) * 1.2, 0.05, sin(a3) * 1.2), Vector3.ZERO, Vector3.ONE, ring)
		_spot(plot[0], plot[1], plot[2])
	# fireflies over the grass
	var ff := CPUParticles3D.new()
	ff.amount = 40
	ff.lifetime = 4.0
	ff.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ff.emission_box_extents = Vector3(9, 0.6, 7)
	ff.gravity = Vector3.ZERO
	ff.initial_velocity_min = 0.05
	ff.initial_velocity_max = 0.25
	ff.direction = Vector3(0, 1, 0)
	ff.spread = 180.0
	ff.scale_amount_min = 0.03
	ff.scale_amount_max = 0.05
	var fm := SphereMesh.new()
	fm.radius = 0.5
	fm.height = 1.0
	ff.mesh = fm
	ff.material_override = _glow(Color("d8ff8a"), 3.0)
	ff.position = Vector3(0, 1.2, 0)
	add_child(ff)


## A place he can walk up to: a name floats over it when he is near.
func _spot(at: Vector3, title: String, line: String) -> void:
	var l := Label3D.new()
	l.text = title
	l.font = Pal.title_font()
	l.font_size = 64
	l.pixel_size = 0.006
	l.outline_size = 14
	l.modulate = Color("ffe066")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.visible = false
	l.position = Vector3(at.x, height(at.x, at.z) + 2.6, at.z)
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
	_ugu.has_torch = true
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
	_hint = Label.new()
	_hint.add_theme_font_override("font", Pal.text_font())
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_color", Color("f3e3c3"))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.position = Vector2(140, 640)
	_hint.size = Vector2(1000, 60)
	ui.add_child(_hint)
	var title := Label.new()
	title.text = "UGU'S ISLAND  ·  a prototype"
	title.add_theme_font_override("font", Pal.title_font())
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("ffcf40"))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 10)
	title.position = Vector2(24, 16)
	ui.add_child(title)


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
	# the fire breathes
	for i in _flames.size():
		var fl: MeshInstance3D = _flames[i]
		fl.scale = Vector3.ONE * (1.0 + 0.12 * sin(_t * (9.0 + i * 3.0) + i))
	_fire_light.light_energy = 2.2 + 0.4 * sin(_t * 11.0) + 0.2 * sin(_t * 23.0)
	# names float over what he is near
	var near_line := ""
	for s in _spots:
		var close: bool = Vector2(_pos.x - s[0].x, _pos.z - s[0].z).length() < 1.9
		(s[3] as Label3D).visible = close
		if close:
			near_line = "%s — %s" % [s[1], s[2]]
	_hint.text = near_line


## One step of walking (also used by the picture-taker).
func walk(dir: Vector3, delta: float) -> void:
	var moving := dir.length() > 0.01
	if moving:
		dir = dir.normalized()
		var next := _pos + dir * SPEED * delta
		if height(next.x, next.z) > 0.25 and Vector2(next.x, next.z).length() < ISLAND_R - 1.5:
			_pos = next
		if absf(dir.x) > 0.1:
			_ugu.facing = 1 if dir.x > 0.0 else -1
	# his own run cycle, driven from here (as a mannequin he only breathes by himself)
	_ugu.velocity.x = float(_ugu.facing) * (CaveMan.SPEED if moving else 0.0)
	if moving:
		_ugu._run_phase += CaveMan.SPEED * delta / (_ugu._stride_amp(1.0) * CaveMan.ART)
	_pos.y = height(_pos.x, _pos.z)
	_cut.position = _pos
	_cam.position = _cam.position.lerp(_pos + CAM_BACK, minf(1.0, delta * 4.0)) if _t > 0.1 else _pos + CAM_BACK
	_cam.look_at(_pos + Vector3(0, 0.8, -1.5))


## ------------------------------------------------------------------ pictures
func _shots() -> void:
	DirAccess.make_dir_recursive_absolute("C:/tmp/shots")
	for f in 30:
		await get_tree().process_frame
	await _shot("plaza")
	for f in 40:
		walk(Vector3(1, 0, -0.6), 1.0 / 60.0)
		await get_tree().process_frame
	await _shot("stall")
	for f in 70:
		walk(Vector3(-1, 0, 0.1), 1.0 / 60.0)
		await get_tree().process_frame
	await _shot("hut")
	_cam.position = Vector3(0, 22, 26)
	_cam.look_at(Vector3(0, 0, -1))
	set_process(false)
	await _shot("island")
	get_tree().quit()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/shelter_%s.png" % label)
	print("shot ", label)
