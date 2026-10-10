extends Node
## Test (headless): THE OBSIDIAN MIRROR (shelter/mirror.gd) from the bag to
## the faces. No mirror in the cave before it is made; the workbench makes it
## from 2 obsidian, 2 bones, 1 clay (kept for good, the stones spent); it stands
## in the cave; E at it opens the face studio: he steps up and faces the glass,
## a feeling sets his face, a slider changes it, a silly face, the keys; Esc
## closes it (his own face back), and the home's Esc is not taken for leaving.
##   <godot> --headless --fixed-fps 60 --path . res://tools/mirror.tscn
##   With rendering and `-- pics`: pictures too (C:/tmp/shots/mirror_*.png).
var home: Node3D
var fails := 0


func _ready() -> void:
	GameState.reset()
	GameState.bag = {"obsidian": 2, "clay": 1}
	GameState.bones = 5
	home = load("res://shelter/home.tscn").instantiate()
	add_child(home)
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(label: String, ok: bool, info: String = "") -> void:
	if not ok:
		fails += 1
	print("%s %s  %s" % ["PASS" if ok else "FAIL", label, info])


func use_at(id: String) -> void:
	for s in home._spots:
		if s[0] == id:
			home._pos = Vector3(s[1].x, home.height(s[1].x, s[1].y), s[1].y)
	await frames(3)
	home.use()
	await frames(2)


func key(k: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = true
	Input.parse_input_event(e)
	await frames(2)
	var up := e.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await frames(2)


func dial(k: String) -> float:
	return float(home._model.get("_dial")[k])


func _run() -> void:
	await frames(30)
	check("no mirror before it is made", home._mirror == null and not home._spots.any(func(s): return s[0] == "mirror"))
	await use_at("bench")
	var m = home._menu
	await frames(5)
	await shot("workshop")
	check("the workshop lists the mirror, and he can make it", m != null and m.recipes().any(func(r): return r[0] == "mirror") and Bag.missing(home._rig, "mirror") == "")
	check("the bag's own CRAFT doesn't (it's made at home)", not Bag.known_recipes().any(func(r): return r[0] == "mirror"))
	m.make("mirror")
	await frames(20)
	await shot("workshop_made")
	check("made: kept for good, the stones and bones spent", GameState.has_item("obsidian_mirror") and Bag.count(null, "obsidian") == 0 and Bag.count(null, "clay") == 0 and GameState.bones == 3,
		"obsidian %d clay %d bones %d" % [Bag.count(null, "obsidian"), Bag.count(null, "clay"), GameState.bones])
	check("it stands in the cave", home._mirror != null and home._spots.any(func(s): return s[0] == "mirror"))
	m.close()
	await frames(5)
	# up to it
	home._pos = home._mirror.stand_point() + Vector3(0.5, 0, 2.5)
	await frames(60)
	await shot("cave")
	await use_at("mirror")
	var mi = home._mirror
	check("E at it: the face studio opens", mi.is_open and mi._ui != null)
	await frames(60)
	var gm: Vector3 = mi.glass_mid()
	var facing: Vector3 = home._model.global_transform.basis.z
	var to := Vector3(gm.x - home._pos.x, 0, gm.z - home._pos.z).normalized()
	check("he steps up and faces the glass", home._pos.distance_to(mi.stand_point()) < 0.3 and facing.dot(to) > 0.9, "facing %.2f" % facing.dot(to))
	check("the glass shows him (it renders)", mi._vp.render_target_update_mode == SubViewport.UPDATE_ONCE)
	mi.pick_feeling(14)                       # SAD
	await frames(40)
	await shot("sad")
	check("a feeling: his face (sad)", home._model.face_mood == "pose" and dial("smile") < -0.7, "smile %.2f" % dial("smile"))
	mi.set_dial("wink_r", 1.0)
	mi.set_dial("tongue_out", 1.0)
	await frames(30)
	await shot("wink")
	check("sliders: a wink, the tongue out", dial("wink_r") > 0.8 and home._model.get("_tongue").visible)
	await key(KEY_RIGHT)
	check("Right: the next feeling", mi.feeling == 15, str(mi.feeling))
	var before: float = mi.face["smile"]
	await key(KEY_DOWN)
	await key(KEY_UP)
	await key(KEY_D)
	check("A / D move the chosen slider", float(mi.face["smile"]) > before, "%.2f -> %.2f" % [before, float(mi.face["smile"])])
	mi.silly()
	await frames(5)
	await frames(30)
	await shot("silly")
	check("a silly face", mi._name.text == "SILLY!")
	var x0: float = home._pos.x
	await key(KEY_LEFT)
	await frames(20)
	check("no walking in the studio", absf(home._pos.x - x0) < 0.05)
	await key(KEY_ESCAPE)
	await frames(10)
	check("Esc: the studio closes, he stays home", not mi.is_open and mi._ui == null and is_instance_valid(home) and home.is_inside_tree())
	await frames(90)
	check("his own face back", home._model.face_mood != "pose", home._model.face_mood)
	print("mirror: %d failed" % fails)
	get_tree().quit()


func shot(label: String) -> void:
	if not OS.get_cmdline_user_args().has("pics"):
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("C:/tmp/shots")
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/mirror_%s.png" % label)
	if home._mirror != null:
		home._mirror._vp.get_texture().get_image().save_png("C:/tmp/shots/mirror_%s_glass.png" % label)
