extends Node
## Test (headless): FISHING with the FISHING STICK (shelter/fishing.gd).
## No stick: a splash, a nudge to the workshop. The workshop makes it (not
## without its bones, flint, clay). With it: he holds it (the stick in his
## fist, his weapon put away); the cast meter; a cast; striking at a nibble
## scares it off; too slow on the bite: the bait is gone; the fight, played by a
## careful fisher: a fish, its card, the log (NEW!), the drying rack, one to
## cook; reeling flat out on a strong one: SNAP; never reeling: it gets away;
## junk; OLD BONEJAW goes on the trophies; the log's rows; Esc: the stick down.
##   <godot> --headless --fixed-fps 60 --path . res://tools/fishing.tscn
##   With rendering and `-- pics`: pictures (C:/tmp/shots/fish_*.png).
var home: Node3D
var fs: Node
var fails := 0


func _ready() -> void:
	GameState.reset()
	GameState.bones = 3
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
			home._pos = Vector3(s[1].x, maxf(home.height(s[1].x, s[1].y), 0.66), s[1].y)
	await frames(3)
	home.use()
	await frames(2)


## Cast, wait for the bite (as it comes), and strike.
func to_bite(p: float) -> void:
	fs.cast(p)
	var n := 0
	while fs.state != "bite" and n < 900:
		await frames(1)
		n += 1


## Play the fight like a careful fisher: reel while it's slack, let go near the red.
func fight(careful := true, limit := 3000) -> void:
	var n := 0
	while fs.state == "fight" and n < limit:
		fs.reel_hold = (fs.tension < 0.55) if careful else true
		await frames(1)
		n += 1
	fs.reel_hold = false


func _run() -> void:
	await frames(20)
	for s in home._systems:
		if s.has_method("held_use"):
			fs = s
	# ---- no stick yet
	await use_at("pier")
	check("no stick: a splash, a nudge to the workshop", home._holder == null and str(home._say.text).contains("WORKSHOP"), home._say.text)
	home._open_workshop("make")
	await frames(2)
	var ws = home._menu
	if OS.get_cmdline_user_args().has("pics"):
		GameState.bones = 10
		GameState.bag = {"flint": 1, "clay": 1, "obsidian": 1}
		await frames(3)
		await shot("workshop")
		GameState.bones = 3
		GameState.bag = {}
	check("the workshop lists the fishing stick", ws.recipes().any(func(r): return r[0] == "fishing_stick"))
	check("not without its bones, flint and clay", not ws.make("fishing_stick") and not GameState.has_item("fishing_stick"))
	GameState.bones = 10
	GameState.bag = {"flint": 1, "clay": 1}
	check("with them: MADE (6 bones, 1 flint, 1 clay spent)", ws.make("fishing_stick") and GameState.has_item("fishing_stick") and GameState.bones == 4 and Bag.count(null, "flint") == 0,
		"bones %d" % GameState.bones)
	ws.close()
	await frames(5)
	check("the pier says so", str(home._title_of("pier")[1]).contains("FISHING STICK"))
	# ---- holding the stick
	await use_at("pier")
	await frames(10)
	var hand: Node3D = home._model.hand()
	check("E at the pier: the stick in his fist, his weapon away", home._holder == fs and fs.state == "aim" and fs._rod != null and fs._rod.get_parent() == hand and not home._model._grip.visible)
	var p0: float = fs.power
	await frames(20)
	home._night = 0.2
	home._night_to = 0.2
	home._apply_daylight(true)
	await frames(60)
	await shot("aim")
	check("the cast meter swings", absf(fs.power - p0) > 0.05, "%.2f -> %.2f" % [p0, fs.power])
	# ---- a nibble struck: it swims off
	fs.cast(0.3)
	await frames(50)
	await shot("wait")
	check("a cast: the bobber out on the water", fs.state == "wait" and fs._bobber.visible and fs._bobber.global_position.z > fs.where().z + 4.0)
	fs._nibbling = 0.3
	fs.held_use()
	check("striking at a NIBBLE: it swims off", fs.state == "lost" and str(fs.lost_word).contains("NIBBLE"))
	await frames(25)
	fs.held_use()
	# ---- too slow on the bite
	await to_bite(0.3)
	await frames(60)
	check("too slow on the bite: the bait is gone", fs.state == "lost" and str(fs.lost_word).contains("slow"))
	await frames(25)
	fs.held_use()
	# ---- a proper catch
	await to_bite(0.5)
	fs._junk = []
	fs._fish = fs.SPECIES[0]
	fs._size = 22.0
	fs.held_use()
	check("strike on the bite: HOOKED, the fight", fs.state == "fight")
	if OS.get_cmdline_user_args().has("pics"):
		fs.reel_hold = true
		await frames(70)
		await shot("fight")
		fs.reel_hold = false
	var bend := 0.0
	var n := 0
	while fs.state == "fight" and n < 3000:
		fs.reel_hold = fs.tension < 0.55
		await frames(1)
		bend = maxf(bend, (fs._segs[3] as Node3D).rotation.x)
		n += 1
	fs.reel_hold = false
	await frames(5)
	check("a careful fight: a fish!", fs.state == "catch" and fs.caught.has("fish"), fs.state)
	check("the stick bent with the pull", bend > 0.05, "%.2f" % bend)
	check("the card: NEW!, the log (and the fish in his hands, to land on the deck)", bool(fs.caught.get("new", false)) and (GameState.shelter.get("fish", {}) as Dictionary).has("perch") and not fs._caught_fish.is_empty())
	await frames(40)
	await shot("catch")
	check("he holds it up", fs._fishy != null and fs._fishy.global_position.y > fs.where().y + 2.0)
	fs.held_use()
	# ---- flat out on a strong one: SNAP
	await to_bite(1.0)
	fs._junk = []
	fs._fish = fs.SPECIES[3]
	fs._size = 78.0
	fs.held_use()
	await fight(false, 900)
	check("reeling flat out on a strong one: SNAP", fs.state == "lost" and str(fs.lost_word).begins_with("SNAP"), fs.lost_word)
	await frames(25)
	fs.held_use()
	# ---- never reeling: it gets away
	await to_bite(0.6)
	fs._junk = []
	fs._fish = fs.SPECIES[1]
	fs._size = 30.0
	fs.held_use()
	var m := 0
	while fs.state == "fight" and m < 1200:
		await frames(1)
		m += 1
	check("never reeling: it gets away", fs.state == "lost", "%s: %s" % [fs.state, fs.lost_word])
	await frames(25)
	fs.held_use()
	# ---- junk
	await to_bite(0.4)
	fs._junk = fs.JUNK[1]
	var sh := GameState.shells
	fs.held_use()
	await frames(5)
	check("not a fish: a giant clam, shells inside", fs.state == "catch" and fs.caught.has("junk") and GameState.shells == sh + 8)
	await frames(25)
	fs.held_use()
	# ---- the legend
	await to_bite(1.0)
	fs._junk = []
	fs._fish = fs.SPECIES[6]
	fs._size = 250.0
	fs.held_use()
	await fight(true, 6000)
	await frames(30)
	await shot("bonejaw")
	check("OLD BONEJAW, caught: on the trophies", fs.state == "catch" and GameState.trophies.has("bonejaw"), fs.state)
	await frames(30)
	fs.held_use()
	# ---- Esc: the stick down
	var e := InputEventKey.new()
	e.physical_keycode = KEY_ESCAPE
	e.keycode = KEY_ESCAPE
	e.pressed = true
	Input.parse_input_event(e)
	await frames(5)
	check("Esc: the stick down (he stays home), the weapon back", home._holder == null and fs._rod == null and home._model._grip.visible and is_instance_valid(home) and home.is_inside_tree())
	await use_at("fishlog")
	check("the fish log: a row for every kind", home._menu != null and home._menu._rows.size() == fs.SPECIES.size())
	print("fishing: %d failed" % fails)
	get_tree().quit()


func shot(label: String) -> void:
	if not OS.get_cmdline_user_args().has("pics"):
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("C:/tmp/shots")
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/fish_%s.png" % label)
