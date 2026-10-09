extends Node
## The cave's interactions (shelter/home.gd), each one used: the closet changes
## his costume and the rack his weapon (saved, and the 3D Ugu wears them),
## Kekko's menu sells a fig and a stone and buys a gem, the Toolmaker's menu
## sells an upgrade, the workbench makes a spark kit, the bed turns night to
## day and saves, a fish is caught at the pier and cooked at the fire (+1
## fig), the pup fetches. Headless is fine.
var home: Node3D
var fails := 0


func _ready() -> void:
	GameState.reset()
	GameState.trophies.append("sabre_fang")
	GameState.skins = ["plain", "wolf_hood"]
	GameState.weapons = ["club", "axe"]
	GameState.shells = 400
	GameState.figs = 0
	GameState.bag = {"flint": 1, "pyrite": 1, "quartz": 1}
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


## In the open menu: the row whose label starts with `text`, done.
func menu_do(text: String) -> bool:
	var m = home._menu
	if m == null:
		return false
	for i in m._rows.size():
		if str(m._rows[i][0]).begins_with(text):
			m.pick(i)
			m.act()
			return true
	return false


func close_menu() -> void:
	if home._menu != null:
		home._menu.close()
	await frames(2)


func _run() -> void:
	await frames(5)
	await use_at("closet")
	check("the closet: the next costume, saved, worn", GameState.skin == "wolf_hood", GameState.skin)
	await use_at("weapons")
	check("the rack: the next weapon, saved", GameState.weapon == "axe", GameState.weapon)
	# Kekko
	await use_at("kekko")
	var opened: bool = home._menu != null
	var s0 := GameState.shells
	var fig := menu_do("Roast fig")
	var clay := menu_do("Buy CLAY")
	var sold := menu_do("Sell QUARTZ")
	check("Kekko: a fig, a stone, a gem sold", opened and fig and clay and sold and GameState.figs == 1 and Bag.count(null, "clay") == 1 and Bag.count(null, "quartz") == 0,
		"figs %d clay %d quartz %d shells %d -> %d" % [GameState.figs, Bag.count(null, "clay"), Bag.count(null, "quartz"), s0, GameState.shells])
	await close_menu()
	# the Toolmaker
	await use_at("forge")
	var h0: int = GameState.upgrades["heart"]
	menu_do("An extra heart")
	check("the Toolmaker: an upgrade for shells", int(GameState.upgrades["heart"]) == h0 + 1, "heart %d -> %d" % [h0, GameState.upgrades["heart"]])
	await close_menu()
	# the workbench
	await use_at("bench")
	menu_do("SPARK KIT")
	check("the workbench: a spark kit from flint and fire-gold", Bag.count(null, "spark") == 1 and Bag.count(null, "flint") == 0, str(GameState.bag))
	await close_menu()
	# the store shows what's kept
	await use_at("store")
	var rows: int = home._menu._rows.size() if home._menu != null else 0
	check("the store corner lists what's kept", rows >= 3, "%d rows" % rows)
	await close_menu()
	# bed
	var n0: float = home._night
	await use_at("bed")
	await frames(120)
	check("the bed: sleep turns night to day", n0 > 0.5 and home._night < 0.5, "night %.2f -> %.2f" % [n0, home._night])
	# fishing, then cooking
	await use_at("pier")
	var waited := 0
	while home._fish_state != "bite" and waited < 400:
		await frames(1)
		waited += 1
	home.use()
	await frames(2)
	check("the pier: cast, a bite, E: a fish", home._fish_caught == 1 and home._fish == 1, "caught %d" % home._fish_caught)
	var f0 := GameState.figs
	await use_at("fire")
	check("the fire: the fish cooked, +1 fig", GameState.figs == f0 + 1 and home._fish == 0, "figs %d -> %d" % [f0, GameState.figs])
	# fetch
	await use_at("pup")
	var t := 0
	while home._fetch_state != "" and t < 600:
		await frames(1)
		t += 1
	check("the pup: fetch, and back", home._fetches == 1, "fetches %d after %d frames" % [home._fetches, t])
	print("HomeUse: %d failed" % fails)
	get_tree().quit()
