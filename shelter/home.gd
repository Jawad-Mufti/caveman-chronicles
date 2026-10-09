extends Node3D
## HOME: UGU'S CAVE (docs/shelter_plan.md), between the eras. A 3D "paper
## diorama": the cave and its ledge are low-poly 3D built from shapes in code,
## cut away toward the camera like a dollhouse; Ugu stays the 2D drawing he is
## in the levels (his real rig, drawn into a SubViewport) standing up in it as a
## paper cut-out. The camera is fixed and tilted.
##
## It grows WITH the game: each finished level adds its era (the cave's upgrade,
## its costume, Kekko's and the forge's upgrades, its artifact): the ERA table
## below, and GameState.home_era(). Basic for now: everything a caveman uses.
## (Kekko, the Toolmaker and the pet are placeholders until their art.)
##
## Arrows / WASD walk; near a thing its name floats up and a line shows; Esc goes
## back to the level, where he left it. -- shot: pictures, then quit.

const UGU_H := 1.75              ## how tall the cut-out stands, metres
const SPEED := 4.5
const CAM_BACK := Vector3(0, 7.5, 10.5)
const CAVE := Vector3(0, 0, -3)  ## the middle of the cave floor
const WALK_R := 11.0             ## how far from the centre he may walk

const ROCK := Color("8a7b6e")
const ROCK_DARK := Color("5e534c")
const EARTH := Color("7a5a3c")
const GRASS := Color("4f8f45")
const HIDE := Color("9a6a40")
const FUR := Color("6e4a30")
const BONE := Color("efe4c8")
const WOOD := Color("6b4a2c")
const LEAF := Color("4f8a3a")
const CLAY := Color("b8643a")
const OCHRE := Color("c8553d")
const MEAT := Color("a8483a")

## What a thing is called and what Ugu thinks of it: [name, line], by id.
const SPOTS := {
	"fire": ["THE FIRE", "The heart of home. Meat on the spit, always."],
	"bed": ["HIS BED", "Leaves, then furs. Better than a rock. Just."],
	"paint": ["THE PAINTED WALL", "Every beast he's beaten, in ochre. Old Scar is the biggest."],
	"weapons": ["THE WEAPON RACK", "Every weapon he's earned. Pick one to carry."],
	"closet": ["THE CLOSET", "His costumes, one from every era. Try them on!"],
	"store": ["THE STORE CORNER", "Baskets, pots, a water skin. Everything brought home."],
	"drying": ["THE DRYING RACK", "Meat and fish, drying in the smoke."],
	"piles": ["THE PILES", "Wood, stones and bones: what he has gathered."],
	"tusk": ["TUSKAR'S TUSK", "The coat hook. Tuskar would hate that."],
	"skull": ["OLD SCAR'S SKULL", "The fire guard. One fang missing: that's the spear, one day."],
	"pup": ["THE PUP", "Asleep by the fire. One day it will sniff out shiny stones."],
	"kekko": ["KEKKO'S STALL", "\"Pebbles, gems, shiny things! Riddle me right for a discount...\""],
	"forge": ["THE FORGE", "The Toolmaker's anvil. Gems in, legends out."],
}

var _ugu: CaveMan
var _ugu_vp: SubViewport
var _cut: Sprite3D
var _pos := Vector3(0, 0, 4.5)
var _cam: Camera3D
var _spin: Array = []             ## [node, axis, speed]: the spit
var _flicker: Array = []          ## [light, base energy]
var _spots: Array = []            ## [position (x, z), name, line, Label3D]
var _blocks: Array = []           ## [centre (x, z), radius]: he walks round these
var _hint: Label
var _t := 0.0


func _ready() -> void:
	Pal.install_fonts()
	_build_world()
	_build_ground()
	_build_cave(GameState.home_era())
	_build_ugu()
	_build_ui()
	if OS.get_cmdline_user_args().has("shot"):
		_shots.call_deferred()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).physical_keycode == KEY_ESCAPE:
		leave()


## Back to the level, where he left it (GameState.away); no level to go back to
## (the scene run on its own): Level 2.
func leave() -> void:
	var to := str(GameState.away.get("level", "res://level2/level2.tscn"))
	GameState.resume = not GameState.away.is_empty()
	GameState.from_home = true
	get_tree().change_scene_to_file(to)


## ------------------------------------------------------------------ the world
func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("1c2140")              # the levels' dusk
	sm.sky_horizon_color = Color("c9776a")
	sm.ground_horizon_color = Color("3a3550")
	sm.ground_bottom_color = Color("15182a")
	sm.sun_angle_max = 0.0
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("6d6a9a")
	e.ambient_light_energy = 0.5
	e.fog_enabled = true
	e.fog_light_color = Color("4a4468")
	e.fog_density = 0.012
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffb37a")
	sun.light_energy = 0.7
	sun.rotation_degrees = Vector3(-30, -30, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	var moon := _shape(_ball(3.0, 12), Color.WHITE, Vector3(-30, 26, -60))
	moon.material_override = _glow(Color("f6f0d8"), 1.6)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	add_child(_cam)


## The ledge he lives on: grass outside, packed earth inside the cave, rock all
## round; pines and far hills behind.
func _build_ground() -> void:
	_shape(_cyl(14.0, 1.0, 20), GRASS, Vector3(0, -0.5, 1.0))
	_shape(_cyl(7.5, 1.0, 16), EARTH, Vector3(CAVE.x, -0.48, CAVE.z))
	_shape(_cyl(14.6, 3.0, 20, 15.5), ROCK_DARK, Vector3(0, -2.5, 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 14:
		var a := rng.randf_range(-0.9, PI + 0.9)
		var at := Vector3(cos(a) * rng.randf_range(10.5, 13.0), 0, -sin(a) * 4.0 + rng.randf_range(4.0, 9.0))
		if absf(at.x) > 8.0 or at.z > 9.0:
			_pine(at, rng.randf_range(0.9, 1.4))
	for hill in [[Vector3(-22, -2, -30), 14.0], [Vector3(10, -3, -36), 18.0], [Vector3(30, -2, -24), 11.0]]:
		_shape(_ball(1.0, 7), Color("3a3a52"), hill[0], Vector3.ZERO, Vector3(hill[1], hill[1] * 0.6, hill[1]))


## ------------------------------------------------------------------ the cave, at an era
## (ERA 1, the Raw Stone age: a fire pit, a bed of leaves, the tusk. ERA 2, Fire:
## a hide curtain and a bone frame at the mouth, furs on the bed, clay pots, the
## skull, the Firestone forge, gems at Kekko's. A new level adds its era here.)
func _build_cave(era: int) -> void:
	# the shell: a horseshoe of rock round the floor, a roof over its back half
	# (cut away toward the camera, like a dollhouse)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 15:
		var a := lerpf(PI * 0.95, PI * 2.05, i / 14.0)
		var r := 7.2 + rng.randf_range(-0.3, 0.4)
		var p := Vector3(CAVE.x + cos(a) * r, 0, CAVE.z + sin(a) * r * 0.85)
		var s := rng.randf_range(1.6, 2.3)
		_shape(_ball(1.0, 6), ROCK, p + Vector3(0, s * 0.9, 0), Vector3(0, rng.randf() * 90.0, 0), Vector3(s * 1.1, s * 1.5, s))
		_shape(_ball(1.0, 6), ROCK.darkened(0.08), p + Vector3(0, s * 2.4, 0) - Vector3(cos(a), 0, sin(a)) * 0.6, Vector3(0, rng.randf() * 90.0, 0), Vector3(s, s * 0.9, s))
		_blocks.append([Vector2(p.x, p.z), s * 1.0])
	for i in 6:
		var x := lerpf(-5.5, 5.5, i / 5.0)
		_shape(_ball(1.0, 6), ROCK.darkened(0.12), Vector3(x, 5.0 + rng.randf_range(-0.3, 0.3), CAVE.z - 3.0 - rng.randf_range(0.0, 1.5)), Vector3(0, rng.randf() * 90.0, 0), Vector3(2.4, 1.0, 2.6))
	# the painted wall at the back: ochre beasts and handprints
	var wall := CAVE + Vector3(0, 0, -5.6)
	_paint_beast(wall + Vector3(-1.6, 2.2, 0), 1.0)
	_paint_beast(wall + Vector3(1.4, 2.6, 0), 0.7)
	for hx in [-3.2, 3.0, 0.2]:
		_shape(_cyl(0.18, 0.04, 8), OCHRE, wall + Vector3(hx, 1.4, 0.05), Vector3(90, 0, 0))
	_spot("paint", wall + Vector3(0, 0, 1.6))
	# THE FIRE, in the middle, meat roasting on a spit that turns
	var fire := CAVE + Vector3(0, 0, 1.0)
	for k in 9:
		var an := k * TAU / 9.0
		_shape(_ball(0.2, 5), ROCK, fire + Vector3(cos(an) * 0.7, 0.1, sin(an) * 0.7))
	for k in 3:
		_shape(_cyl(0.08, 1.0), WOOD, fire + Vector3(0, 0.14, 0), Vector3(0, k * 60.0, 80))
	_flame(fire, 1.0)
	for px in [-0.9, 0.9]:
		_shape(_cyl(0.05, 1.4), WOOD, fire + Vector3(px, 0.7, 0), Vector3(0, 0, px * 12.0))
	var spit := Node3D.new()
	spit.position = fire + Vector3(0, 1.3, 0)
	add_child(spit)
	_shape(_cyl(0.035, 2.0), WOOD, Vector3.ZERO, Vector3(0, 0, 90), Vector3.ONE, spit)
	_shape(_ball(0.28, 7), MEAT, Vector3.ZERO, Vector3.ZERO, Vector3(1.4, 0.9, 0.9), spit)
	_shape(_cyl(0.05, 0.5), BONE, Vector3(0.45, 0, 0), Vector3(0, 0, 90), Vector3.ONE, spit)
	_spin.append([spit, Vector3(1, 0, 0), 0.8])
	_blocks.append([Vector2(fire.x, fire.z), 1.0])
	_spot("fire", fire + Vector3(0, 0, 1.4))
	# his bed: leaves, then furs and a fur pillow
	var bed := CAVE + Vector3(-4.0, 0, -2.6)
	if era >= 2:
		_shape(_ball(1.0, 8), FUR, bed + Vector3(0, 0.15, 0), Vector3(0, 20, 0), Vector3(1.4, 0.18, 0.8))
		_shape(_ball(1.0, 8), FUR.lightened(0.15), bed + Vector3(-0.2, 0.32, 0.1), Vector3(0, 20, 0), Vector3(1.0, 0.12, 0.6))
		_shape(_ball(0.3, 6), HIDE.lightened(0.1), bed + Vector3(-1.0, 0.4, -0.3), Vector3.ZERO, Vector3(1.3, 0.6, 1.0))
	else:
		for k in 9:
			_shape(_ball(0.35, 5), LEAF.lightened(k * 0.02), bed + Vector3(-1.0 + (k % 3) * 0.9, 0.12, -0.5 + (k / 3) * 0.5), Vector3(0, k * 40.0, 0), Vector3(1.2, 0.35, 0.8))
	_blocks.append([Vector2(bed.x, bed.z), 1.2])
	_spot("bed", bed + Vector3(0.6, 0, 1.4))
	# THE WEAPON RACK: a bone frame, every weapon he owns hung on it
	var rack := CAVE + Vector3(-5.6, 0, 0.6)
	for pz in [-0.7, 0.7]:
		_shape(_cyl(0.06, 1.8), BONE, rack + Vector3(0, 0.9, pz))
	_shape(_cyl(0.05, 1.6), BONE, rack + Vector3(0, 1.75, 0), Vector3(90, 0, 0))
	var held := 0
	for w in ["club", "axe", "hammer"]:
		if GameState.weapons.has(w):
			_weapon(w, rack + Vector3(0.05, 1.0, -0.45 + held * 0.45))
			held += 1
	_blocks.append([Vector2(rack.x, rack.z), 0.8])
	_spot("weapons", rack + Vector3(1.4, 0, 0))
	# THE CLOSET: a bone rack, a costume on a hook per era
	var closet := CAVE + Vector3(5.5, 0, 0.4)
	for pz2 in [-0.8, 0.8]:
		_shape(_cyl(0.06, 1.9), BONE, closet + Vector3(0, 0.95, pz2))
	_shape(_cyl(0.05, 1.8), BONE, closet + Vector3(0, 1.85, 0), Vector3(90, 0, 0))
	_costume(closet + Vector3(-0.05, 1.35, -0.4), LEAF, "leaf")                  # era 1: the leaf loincloth
	if era >= 2:
		_costume(closet + Vector3(-0.05, 1.35, 0.35), Color("d9a64e"), "hide")    # era 2: the hide (leopard) loincloth
	_blocks.append([Vector2(closet.x, closet.z), 0.8])
	_spot("closet", closet + Vector3(-1.4, 0, 0))
	# THE STORE CORNER: baskets, (clay pots from the fire age), berries, a water skin
	var store := CAVE + Vector3(4.2, 0, -3.0)
	for k in 3:
		_shape(_cyl(0.32, 0.45, 9, 0.38), Color("a0784a"), store + Vector3(-0.8 + k * 0.7, 0.22, 0.2 * (k % 2)))
	for k in 6:
		_shape(_ball(0.08, 5), Color("8a2a5a"), store + Vector3(-0.85 + (k % 3) * 0.08, 0.5, 0.05 * (k / 3)))
	if era >= 2:
		for k in 2:
			_shape(_ball(0.35, 8), CLAY, store + Vector3(1.0, 0.35 + k * 0.0, -0.7 + k * 0.8), Vector3.ZERO, Vector3(1, 1.2, 1))
	_shape(_ball(0.25, 6), HIDE.darkened(0.2), store + Vector3(-1.4, 0.3, -0.6), Vector3.ZERO, Vector3(0.8, 1.2, 0.6))
	_blocks.append([Vector2(store.x, store.z), 1.3])
	_spot("store", store + Vector3(-0.6, 0, 1.6))
	# THE DRYING RACK by the mouth, in the smoke: meat and fish
	var dry := CAVE + Vector3(-3.6, 0, 3.4)
	for px2 in [-0.8, 0.8]:
		_shape(_cyl(0.05, 1.7), WOOD, dry + Vector3(px2, 0.85, 0))
	_shape(_cyl(0.04, 1.8), WOOD, dry + Vector3(0, 1.65, 0), Vector3(0, 0, 90))
	for k in 4:
		var hang := dry + Vector3(-0.6 + k * 0.4, 1.3, 0)
		if k % 2 == 0:
			_shape(_ball(0.14, 5), MEAT.darkened(0.2), hang, Vector3.ZERO, Vector3(0.8, 1.6, 0.6))
		else:
			_shape(_ball(0.13, 5), Color("9aa0a8"), hang, Vector3(0, 0, 0), Vector3(0.6, 1.8, 0.4))
	_blocks.append([Vector2(dry.x, dry.z), 0.9])
	_spot("drying", dry + Vector3(0, 0, 1.2))
	# THE PILES: wood, stones, bones; they grow with what he has gathered
	var piles := CAVE + Vector3(3.6, 0, 3.6)
	var bones := clampi(GameState.bones / 5 + 2, 2, 12)
	for k in bones:
		_shape(_cyl(0.06, 0.9, 5), BONE, piles + Vector3(-0.9 + (k % 4) * 0.15, 0.1 + (k / 4) * 0.12, (k % 3) * 0.12), Vector3(0, k * 37.0, 85))
	for k in 6:
		_shape(_cyl(0.11, 1.1, 6), WOOD, piles + Vector3(0.3, 0.12 + (k / 3) * 0.2, -0.3 + (k % 3) * 0.24), Vector3(90, 0, 0))
	for k in 5:
		_shape(_ball(0.2, 5), ROCK, piles + Vector3(1.2 + (k % 2) * 0.3, 0.15 + (k / 2) * 0.18, -0.2 + (k % 3) * 0.2))
	_blocks.append([Vector2(piles.x + 0.3, piles.z), 1.3])
	_spot("piles", piles + Vector3(0, 0, 1.3))
	# ARTIFACTS: Tuskar's tusk on the wall, a fur hung on it (era 1); Old Scar's skull by the fire (era 2)
	var tusk := CAVE + Vector3(2.2, 0, -5.2)
	_shape(_cyl(0.13, 1.6, 7, 0.04), BONE, tusk + Vector3(0, 1.9, 0), Vector3(0, 0, 70))
	_shape(BoxMesh.new(), FUR.lightened(0.1), tusk + Vector3(0.45, 1.5, 0.12), Vector3.ZERO, Vector3(0.5, 0.7, 0.05))
	_spot("tusk", tusk + Vector3(0, 0, 1.6))
	if era >= 2:
		var skull := CAVE + Vector3(1.4, 0, 1.6)
		_shape(_ball(0.42, 8), BONE, skull + Vector3(0, 0.4, 0), Vector3.ZERO, Vector3(1.3, 0.9, 1.0))
		_shape(_ball(0.1, 6), Color("1a120c"), skull + Vector3(0.25, 0.5, 0.33))
		_shape(_ball(0.1, 6), Color("1a120c"), skull + Vector3(-0.1, 0.5, 0.38))
		_shape(_cone(0.07, 0.55, 6), BONE, skull + Vector3(0.35, 0.05, 0.3), Vector3(180, 0, 0))          # ONE fang: the other is gone
		_blocks.append([Vector2(skull.x, skull.z), 0.6])
		_spot("skull", skull + Vector3(0.6, 0, 0.9))
		# the mouth: a frame of mammoth bones, hide curtains pulled aside
		for side in [-1.0, 1.0]:
			var post := Vector3(side * 5.6, 0, CAVE.z + 5.2)
			_shape(_cyl(0.16, 3.6, 7, 0.08), BONE, post + Vector3(0, 1.6, 0), Vector3(0, 0, -side * 14.0))
			_shape(BoxMesh.new(), HIDE, post + Vector3(-side * 0.6, 1.6, 0.1), Vector3(0, 0, side * 6.0), Vector3(0.9, 3.0, 0.06))
		_shape(_cyl(0.13, 11.0, 7), BONE, Vector3(0, 3.4, CAVE.z + 5.2), Vector3(0, 0, 90))
	# THE PUP, curled up by the fire
	var pup := CAVE + Vector3(-1.5, 0, 2.2)
	_shape(_ball(0.32, 7), Color("8a7a6a"), pup + Vector3(0, 0.22, 0), Vector3.ZERO, Vector3(1.3, 0.7, 1.0))
	_shape(_ball(0.17, 7), Color("8a7a6a"), pup + Vector3(0.38, 0.3, 0.12))
	_shape(_cone(0.06, 0.14, 4), Color("6a5a4a"), pup + Vector3(0.42, 0.48, 0.05))
	_shape(_cone(0.06, 0.14, 4), Color("6a5a4a"), pup + Vector3(0.36, 0.48, 0.2))
	_shape(_cyl(0.06, 0.4, 5, 0.02), Color("8a7a6a"), pup + Vector3(-0.42, 0.2, 0.15), Vector3(0, 30, 70))
	_blocks.append([Vector2(pup.x, pup.z), 0.5])
	_spot("pup", pup + Vector3(0, 0, 0.9))
	# outside: KEKKO'S STALL (pebbles on a log; era 2: gems on a hide) and THE FORGE
	var stall := Vector3(6.2, 0, 6.8)
	for px3 in [-1.0, 1.0]:
		_shape(_cyl(0.07, 1.8), WOOD, stall + Vector3(px3, 0.9, -0.4))
	_shape(BoxMesh.new(), HIDE.darkened(0.1), stall + Vector3(0, 1.8, 0), Vector3(14, 0, 0), Vector3(2.4, 0.06, 1.2))
	_shape(_cyl(0.25, 1.9, 8), WOOD, stall + Vector3(0, 0.45, 0.1), Vector3(0, 0, 90))
	var wares := [Color("8a8a8a"), Color("a0947e"), Color("6f6a66"), Color("b0a490")]
	if era >= 2:
		wares = [Color("6cc4ff"), Color("d08bff"), Color("ffcf40"), Color("ff6b8a"), Color("8fe07a")]
		_shape(BoxMesh.new(), Color("d9a64e"), stall + Vector3(0, 0.72, 0.1), Vector3.ZERO, Vector3(1.6, 0.03, 0.6))
	for k in wares.size():
		var g := _shape(_ball(0.1, 4), wares[k], stall + Vector3(-0.6 + k * 0.3, 0.8, 0.1), Vector3(0, k * 30.0, 0))
		if era >= 2:
			g.material_override = _glow(wares[k], 1.2)
	_kekko(stall + Vector3(1.4, 0, -0.6))
	_blocks.append([Vector2(stall.x, stall.z), 1.3])
	_spot("kekko", stall + Vector3(-0.4, 0, 1.4))
	var forge := Vector3(-6.2, 0, 6.6)
	_shape(_ball(0.6, 6), ROCK_DARK, forge + Vector3(0.9, 0.35, 0), Vector3.ZERO, Vector3(1.2, 0.6, 0.8))       # the anvil stone
	if era >= 2:
		for k in 7:
			var an2 := k * TAU / 7.0
			_shape(_ball(0.22, 5), ROCK, forge + Vector3(-0.6 + cos(an2) * 0.6, 0.12, sin(an2) * 0.6))
		var coals := _shape(_cyl(0.45, 0.12, 10), Color.WHITE, forge + Vector3(-0.6, 0.15, 0))
		coals.material_override = _glow(Color("ff5a1a"), 2.4)
		_shape(_ball(0.3, 6), HIDE.darkened(0.15), forge + Vector3(-1.6, 0.35, 0.2), Vector3.ZERO, Vector3(1.2, 0.7, 0.8))  # the bellows
		var l := OmniLight3D.new()
		l.light_color = Color("ff7a2a")
		l.light_energy = 1.4
		l.omni_range = 4.0
		l.position = forge + Vector3(-0.6, 0.6, 0)
		add_child(l)
		_flicker.append([l, 1.4])
	_weapon("club", forge + Vector3(0.9, 0.75, 0))
	_blocks.append([Vector2(forge.x, forge.z), 1.4])
	_spot("forge", forge + Vector3(0.3, 0, 1.5))


## ------------------------------------------------------------------ things
func _paint_beast(at: Vector3, s: float) -> void:
	# a cave painting: a mammoth in ochre, flat on the rock
	var col := Color(OCHRE, 0.95)
	_shape(_ball(0.5 * s, 8), col, at, Vector3.ZERO, Vector3(1.4, 0.8, 0.05))
	_shape(_ball(0.28 * s, 8), col, at + Vector3(0.62 * s, 0.12 * s, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.05))
	for lx in [-0.35, -0.1, 0.2, 0.45]:
		_shape(BoxMesh.new(), col, at + Vector3(lx * s, -0.45 * s, 0), Vector3.ZERO, Vector3(0.08 * s, 0.4 * s, 0.03))
	_shape(BoxMesh.new(), col, at + Vector3(0.82 * s, -0.25 * s, 0), Vector3(0, 0, 20), Vector3(0.07 * s, 0.5 * s, 0.03))


func _weapon(id: String, at: Vector3) -> void:
	match id:
		"club":
			_shape(_cyl(0.06, 1.0, 6, 0.14), WOOD.lightened(0.1), at, Vector3(0, 0, 8))
		"axe":
			_shape(_cyl(0.04, 1.0, 5), WOOD, at, Vector3(0, 0, 4))
			_shape(BoxMesh.new(), Color("6f6a66"), at + Vector3(0.12, 0.38, 0), Vector3.ZERO, Vector3(0.3, 0.2, 0.06))
		"hammer":
			_shape(_cyl(0.05, 1.0, 5), WOOD.darkened(0.2), at, Vector3.ZERO)
			var head := _shape(BoxMesh.new(), Color.WHITE, at + Vector3(0, 0.45, 0), Vector3.ZERO, Vector3(0.45, 0.24, 0.24))
			head.material_override = _glow(Color("e05a2a"), 0.9)


func _costume(at: Vector3, col: Color, kind: String) -> void:
	_shape(BoxMesh.new(), col, at, Vector3.ZERO, Vector3(0.06, 0.5, 0.5))
	if kind == "hide":
		for k in 4:
			_shape(_ball(0.04, 4), Color("4a2a14"), at + Vector3(0.04, -0.1 + (k % 2) * 0.2, -0.15 + k * 0.1))


func _kekko(at: Vector3) -> void:
	# (a placeholder until his cut-out): tiny, old, under a pack bigger than he is
	_shape(_ball(0.26, 6), Color("8a5a3a"), at + Vector3(0, 0.55, 0), Vector3.ZERO, Vector3(1, 1.4, 1))
	_shape(_ball(0.42, 6), HIDE.darkened(0.25), at + Vector3(0.1, 0.8, -0.3), Vector3.ZERO, Vector3(1, 1.3, 0.9))
	_shape(_ball(0.15, 6), Color("c89263"), at + Vector3(0, 0.98, 0.05))
	_shape(_ball(0.1, 6), Color("e6e0d4"), at + Vector3(0, 0.88, 0.14), Vector3.ZERO, Vector3(1, 1.2, 0.6))      # a white beard
	_shape(_ball(0.1, 5), Color("6a4a2a"), at + Vector3(0.25, 1.2, -0.25))                                       # the monkey on the pack
	_blocks.append([Vector2(at.x, at.z), 0.5])


func _flame(at: Vector3, s: float) -> void:
	for k in 3:
		var fl := _shape(_cone((0.24 - k * 0.05) * s, (0.65 + k * 0.15) * s, 6), Color.WHITE, at + Vector3(0, (0.32 + k * 0.05) * s, 0))
		fl.material_override = _glow([Color("ff6a1a"), Color("ffae2e"), Color("fff1a0")][k], 2.2)
		_spin.append([fl, Vector3(0, 1, 0), 1.5 + k])
	var l := OmniLight3D.new()
	l.light_color = Color("ff9a3c")
	l.light_energy = 2.6
	l.omni_range = 9.0 * s
	l.position = at + Vector3(0, 1.0, 0)
	add_child(l)
	_flicker.append([l, 2.6])
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
	embers.position = at + Vector3(0, 0.5, 0)
	add_child(embers)


func _pine(at: Vector3, s: float) -> void:
	_shape(_cyl(0.12 * s, 0.8 * s), WOOD, at + Vector3(0, 0.4 * s, 0))
	for k in 3:
		_shape(_cone((0.9 - k * 0.22) * s, 1.1 * s), Color("2f5a3a").lightened(k * 0.06), at + Vector3(0, (1.0 + k * 0.6) * s, 0))


func _spot(id: String, at: Vector3) -> void:
	var info: Array = SPOTS[id]
	var l := Label3D.new()
	l.text = info[0]
	l.font = Pal.title_font()
	l.font_size = 64
	l.pixel_size = 0.006
	l.outline_size = 14
	l.modulate = Color("ffe066")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.visible = false
	l.position = Vector3(at.x, 2.6, at.z)
	add_child(l)
	_spots.append([Vector2(at.x, at.z), info[0], info[1], l])


## ------------------------------------------------------------------ shapes
func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
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
	_ui_label(ui, Vector2(24, 14), Vector2(800, 40), 30, Color("ffcf40"), Pal.title_font()).text = "UGU'S CAVE"
	_ui_label(ui, Vector2(24, 54), Vector2(800, 30), 17, Color("d8c8b0"), Pal.text_font()).text = "Arrows: walk      Esc: back to the level"


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
	for s in _spin:
		(s[0] as Node3D).rotate_object_local(s[1], float(s[2]) * delta)
	for f in _flicker:
		(f[0] as OmniLight3D).light_energy = float(f[1]) * (1.0 + 0.15 * sin(_t * 11.0) + 0.08 * sin(_t * 23.0))
	var near_line := ""
	for s2 in _spots:
		var close: bool = Vector2(_pos.x, _pos.z).distance_to(s2[0]) < 1.6
		(s2[3] as Label3D).visible = close
		if close:
			near_line = "%s — %s" % [s2[1], s2[2]]
	_hint.text = near_line


## One step of walking: round the things in the way, on the ledge.
func walk(dir: Vector3, delta: float) -> void:
	var moving := dir.length() > 0.01
	if moving:
		dir = dir.normalized()
		var next := _pos + dir * SPEED * delta
		var p := Vector2(next.x, next.z)
		var ok := p.distance_to(Vector2(0, 1.0)) < WALK_R
		for b in _blocks:
			if p.distance_to(b[0]) < float(b[1]) + 0.25:
				ok = false
		if ok:
			_pos = next
		if absf(dir.x) > 0.1:
			_ugu.facing = 1 if dir.x > 0.0 else -1
	_ugu.velocity.x = float(_ugu.facing) * (CaveMan.SPEED if moving else 0.0)
	if moving:
		_ugu._run_phase += CaveMan.SPEED * delta / (_ugu._stride_amp(1.0) * CaveMan.ART)
	_cut.position = _pos
	var want := _pos + CAM_BACK
	_cam.position = _cam.position.lerp(want, minf(1.0, delta * 4.0)) if _t > 0.1 else want
	_cam.look_at(_pos + Vector3(0, 0.9, -1.6))


## ------------------------------------------------------------------ pictures
func _shots() -> void:
	DirAccess.make_dir_recursive_absolute("C:/tmp/shots")
	for f in 30:
		await get_tree().process_frame
	await _shot("mouth")
	for f in 70:
		walk(Vector3(0, 0, -1), 1.0 / 60.0)
		await get_tree().process_frame
	await _shot("inside")
	_cam.position = Vector3(0, 13, 17)
	_cam.look_at(Vector3(0, 0, -1))
	set_process(false)
	await _shot("whole")
	get_tree().quit()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/home_%s.png" % label)
	print("shot ", label)
