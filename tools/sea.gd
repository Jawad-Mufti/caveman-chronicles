extends Node
## Test (headless): THE SEA and THE GRILL (shelter/sea.gd, shelter/fishing.gd).
## The sea: walking into it he swims (head up at the surface); SPACE held: he
## dives to the floor, the camera goes under, the underwater world shows, the
## blue fog; his breath runs down; out of breath he floats up; let go: up; a
## shell picked up; the pier ladder out, and jumping in from it.
## The catch: a fish caught lands on the deck; walking over it he carries it
## on a cord; at the cave fire: on a stick over the flames, the cook meter;
## E when golden: PERFECT, he eats it (bites), a fig, the bones by the fire;
## left on too long: BURNT.
##   <godot> --headless --fixed-fps 60 --path . res://tools/sea.tscn
##   With rendering and `-- pics`: pictures (C:/tmp/shots/sea_*.png).
var home: Node3D
var sea: Node
var fs: Node
var fails := 0


func _ready() -> void:
	GameState.reset()
	GameState.give_item("fishing_stick")
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


func shot(label: String) -> void:
	if not OS.get_cmdline_user_args().has("pics"):
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("C:/tmp/shots")
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/sea_%s.png" % label)


func key(k: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = down
	Input.parse_input_event(e)


func use_at(id: String) -> void:
	for s in home._spots:
		if s[0] == id:
			home._pos = Vector3(s[1].x, maxf(home.height(s[1].x, s[1].y), 0.66 if id == "pier" else -99.0), s[1].y)
			home._vy = 0.0
	await frames(3)
	home.use()
	await frames(2)


func _run() -> void:
	await frames(20)
	sea = home._sea
	fs = home._fishing
	home._night = 0.15
	home._night_to = 0.15
	home._apply_daylight(true)
	# ---- into the sea from the beach, walking (east coast)
	# a lane down the east beach with nothing in the way
	var lz := 6.0
	var x := 40.0
	for z in [6.0, 10.0, 14.0, 18.0, 2.0, 22.0]:
		x = 40.0
		while home.height(x, z) > 0.0 and x < 80.0:
			x += 0.5
		var clear := true
		for xx in range(int(x) - 4, int(x) + 4):
			for b in home._blocks:
				if Vector2(xx, z).distance_to(b[0]) < float(b[1]) + 0.6:
					clear = false
		if clear:
			lz = z
			break
	home._pos = Vector3(x - 3.0, home.height(x - 3.0, lz), lz)
	await frames(5)
	key(KEY_D, true)
	var n := 0
	while not sea.swimming and n < 400:
		await frames(1)
		n += 1
	await frames(40)
	key(KEY_D, false)
	await frames(30)
	check("walking into the sea: he swims", sea.swimming and absf(home._pos.y - sea.SURF_Y) < 0.2, "y %.2f" % home._pos.y)
	check("swimming: the paddle pose, the underwater world awake", float(home._model.swim) > 0.9 and sea._world.visible)
	await shot("swim")
	# ---- dive
	var y0: float = home._pos.y
	sea.dive_hold = true
	key(KEY_D, true)
	await frames(120)
	key(KEY_D, false)
	await frames(60)
	var g: float = home.height(home._pos.x, home._pos.z)
	check("SPACE held: he dives down", home._pos.y < y0 - 2.0, "%.1f m down (floor at %.1f)" % [y0 - home._pos.y, g])
	check("the camera goes under, blue fog, the tint", sea.under and sea._overlay.visible and home._env.fog_density > 0.05)
	check("diving: head first, holding his breath", float(home._model.dive) > 0.7 and home._model.face_mood == "breath", home._model.face_mood)
	check("his breath runs down", sea.air < sea.AIR - 2.0, "%.1f s left" % sea.air)
	await shot("dive")
	# swim on along the floor, to the mammoth, for a picture
	home._pos = Vector3(sea.MAMMOTH.x + 6.0, home.height(sea.MAMMOTH.x + 6.0, sea.MAMMOTH.y) + 1.5, sea.MAMMOTH.y + 2.0)
	home._model.rotation.y = -PI * 0.6
	await frames(90)
	await shot("mammoth")
	home._pos = Vector3(sea.CLAM.x - 3.0, home.height(sea.CLAM.x - 3.0, sea.CLAM.y) + 1.2, sea.CLAM.y + 2.5)
	home._model.rotation.y = PI * 0.75
	await frames(90)
	await shot("clam")
	# a shell
	var sh := GameState.shells
	if not sea._shells.is_empty():
		var at: Vector3 = sea._shells[0][1]
		home._pos = at + Vector3(0, 0.4, 0)
		await frames(5)
	check("a glinting shell, picked up: +2 shells", GameState.shells == sh + 2, "%d -> %d" % [sh, GameState.shells])
	# out of breath: up he goes
	sea.air = 0.05
	await frames(10)
	var low: float = home._pos.y
	var top := low
	var breathed := 0.0
	for i in 300:
		await frames(1)
		top = maxf(top, home._pos.y)
		breathed = maxf(breathed, sea.air)
	check("out of breath: he floats up, whatever (SPACE still held)", top >= sea.SURF_Y - 0.3 and breathed > 5.0, "%.1f -> %.1f swimming %s gasp %s air %.1f floor %.1f at %s" % [low, home._pos.y, sea.swimming, sea._gasp, sea.air, home.height(home._pos.x, home._pos.z), home._pos])
	sea.dive_hold = false
	await frames(240)
	check("let go: up to the top, the camera above again", absf(home._pos.y - sea.SURF_Y) < 0.3 and not sea.under)
	# ---- the pier ladder: out, and back in
	var pier: Vector2 = home.PIER
	home._pos = Vector3(pier.x + 1.6, sea.SURF_Y, pier.y + 7.5)
	await frames(5)
	check("swimming at the pier ladder", sea.swimming)
	await use_at("ladder")
	await frames(5)
	check("E at the ladder: out on the deck", not sea.swimming and absf(home._pos.y - 0.66) < 0.1, "y %.2f" % home._pos.y)
	home.use()
	n = 0
	while not sea.swimming and n < 200:
		await frames(1)
		n += 1
	check("E on the deck there: CANNONBALL, he's in", sea.swimming)
	await use_at("ladder")
	await frames(5)
	# ---- the catch, onto the deck, carried, grilled
	await use_at("pier")
	fs.cast(0.3)
	n = 0
	while fs.state != "bite" and n < 900:
		await frames(1)
		n += 1
	fs._junk = []
	fs._fish = fs.SPECIES[1]
	fs._size = 30.0
	home.use()
	while fs.state == "fight" and n < 5000:
		fs.reel_hold = fs.tension < 0.55
		await frames(1)
		n += 1
	fs.reel_hold = false
	await frames(30)
	check("a fish caught", fs.state == "catch")
	fs.release()
	await frames(50)
	check("put the stick down: the fish lands on the deck, flopping", fs.drops.size() == 1 and fs.carried.is_empty())
	await shot("flop")
	var d: Array = fs.drops[0]
	var at2: Vector3 = d[4]
	home._pos = Vector3(at2.x, 0.66, at2.z)
	await frames(10)
	check("walking over it: on his cord", fs.carried.size() == 1 and fs.drops.is_empty() and home._fish == 1)
	await frames(20)
	await shot("carry")
	var figs := GameState.figs
	var shells := GameState.shells
	await use_at("fire")
	check("E at the cave fire: on a stick over the flames", fs.state == "grill" and home._holder == fs)
	n = 0
	while fs.cook < 0.65 and n < 600:
		await frames(1)
		n += 1
	await shot("grill")
	home.use()
	check("E when golden: PERFECT, he eats it", fs.state == "eat" and int(fs.grills["perfect"]) == 1)
	await frames(30)
	await shot("eat")
	await frames(120)
	check("eaten: +1 fig, +3 shells, no fish left, free again", GameState.figs == figs + 1 and GameState.shells == shells + 3 and fs.carried.is_empty() and home._holder == null,
		"figs %d -> %d, shells %d -> %d" % [figs, GameState.figs, shells, GameState.shells])
	# burnt: one more fish, left on
	fs._take_up([fs._fishy_for_test(), fs.SPECIES[0], 20.0, 0.0, home._pos, 0.0])
	await frames(5)
	home.use()
	n = 0
	while fs.state == "grill" and n < 600:
		await frames(1)
		n += 1
	check("left on too long: BURNT (and he eats it anyway)", int(fs.grills["burnt"]) == 1)
	await frames(200)
	print("sea: %d failed" % fails)
	get_tree().quit()
