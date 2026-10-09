extends Node
## The cave's interactions (shelter/home.gd), each one used: the closet changes
## his costume, the rack his weapon (saved), Kekko sells a fig for shells, the
## bed turns night to day, a fish is caught at the pier. Headless is fine.
var home: Node3D
var fails := 0


func _ready() -> void:
	GameState.reset()
	GameState.trophies.append("sabre_fang")
	GameState.skins = ["plain", "wolf_hood"]
	GameState.weapons = ["club", "axe"]
	GameState.shells = 10
	GameState.figs = 0
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


## Stand him at a spot (its id), and press E.
func use_at(id: String) -> void:
	for s in home._spots:
		if s[0] == id:
			home._pos = Vector3(s[1].x, home.height(s[1].x, s[1].y), s[1].y)
	await frames(3)
	home.use()
	await frames(2)


func _run() -> void:
	await frames(5)
	await use_at("closet")
	check("the closet: the next costume, saved", GameState.skin == "wolf_hood" and home._ugu.skin == "wolf_hood", GameState.skin)
	await use_at("weapons")
	check("the rack: the next weapon, saved", GameState.weapon == "axe" and home._ugu.axe, GameState.weapon)
	await use_at("kekko")
	check("Kekko: a roast fig for 4 shells", GameState.figs == 1 and GameState.shells == 6, "figs %d shells %d" % [GameState.figs, GameState.shells])
	var n0: float = home._night
	await use_at("bed")
	await frames(120)
	check("the bed: sleep turns night to day", n0 > 0.5 and home._night < 0.5, "night %.2f -> %.2f" % [n0, home._night])
	await use_at("pier")
	var waited := 0
	while home._fish_state != "bite" and waited < 400:
		await frames(1)
		waited += 1
	home.use()
	await frames(2)
	check("the pier: cast, a bite, E: a fish", home._fish_caught == 1 and home._fish_state == "", "caught %d" % home._fish_caught)
	await use_at("fire")
	check("the fire: a log flares it", home._flare > 1.5)
	await use_at("pup")
	check("the pup: a pat, hearts", home._pup_hop > 0.0)
	print("HomeUse: %d failed" % fails)
	get_tree().quit()
