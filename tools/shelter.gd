extends Node
## Test (headless): THE SHELTER'S NEW THINGS (shelter/nature.gd, builds.gd,
## relic_home.gd, visits.gd), played with keys the way a player would:
## the build sites and the workshop's BUILD tab (no bones: refused, nothing
## built; bones: paid, it stands, its sign gone), the hammock (lie, swing, up),
## the gathering fire's drums (BOOM, four quick: a jump), the stream before and
## after the Bone Bridge, a moonpuff's BOING, Star Rock's wish (a gift, then
## asleep), the lookout's ladder (up, the view, down), the totem, relics at home
## (NEW! till he looks), the golden horn, the pup's find, the welcome card.
##   <godot> --headless --fixed-fps 60 --path . res://tools/shelter.tscn
const Builds := preload("res://shelter/builds.gd")
const Nature := preload("res://shelter/nature.gd")

var home: Node3D
var fails := 0


func _ready() -> void:
	GameState.reset()
	GameState.trophies = ["sabre_fang"]
	GameState.relics = {"moonstone": 1, "golden_horn": 1}
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


func sys(kind: Script) -> Node:
	for s in home._systems:
		if s.get_script() == kind:
			return s
	return null


func has_spot(id: String) -> bool:
	return home._spots.any(func(s): return s[0] == id)


## Stand him at a spot (on its ground, or its pad), press E.
func use_at(id: String) -> void:
	for s in home._spots:
		if s[0] == id:
			var p: Vector2 = s[1]
			var top: float = home.pad_top(p)
			home._pos = Vector3(p.x, maxf(home.height(p.x, p.y), top), p.y)
			home._vy = 0.0
			home._on_ground = true
	await frames(3)
	home.use()
	await frames(2)


func key(k: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = down
	Input.parse_input_event(e)


func hold(k: Key, n: int) -> void:
	key(k, true)
	await frames(n)
	key(k, false)
	await frames(2)


func _run() -> void:
	await frames(20)
	var visits := sys(preload("res://shelter/visits.gd"))
	var relics := sys(preload("res://shelter/relic_home.gd"))
	# ---- the welcome card, the build sites
	check("the welcome card has news", home.get_children().any(func(c): return c is CanvasLayer and c.get_child_count() > 0 and c.get_child(0).get("lines") != null and not (c.get_child(0).lines as Array).is_empty()))
	var sites := Builds.BUILDS.filter(func(b): return has_spot("site_" + b[0]))
	check("every build has its marked site", sites.size() == Builds.BUILDS.size(), "%d of %d" % [sites.size(), Builds.BUILDS.size()])
	await use_at("site_hammock")
	var ws = home._menu
	check("E at a site: the workshop, on BUILD, at that build", ws != null and ws.tab == "build" and ws.rows()[ws.sel][0] == "hammock")
	check("no bones: refused, nothing built", not ws.build_it("hammock") and not Builds.is_built("hammock") and GameState.bones == 0)
	GameState.bones = 400
	check("bones: BUILT, paid", ws.build_it("hammock") and Builds.is_built("hammock") and GameState.bones == 380, "bones %d" % GameState.bones)
	ws.close()
	await frames(90)
	check("its sign is gone, it stands", not has_spot("site_hammock") and has_spot("hammock"))
	# ---- the hammock
	await use_at("hammock")
	await frames(30)
	var tilt: float = (home._model.global_transform.basis.y as Vector3).dot(Vector3.UP)
	check("the hammock: he lies in it", home._holder != null and tilt < 0.3, "upright %.2f" % tilt)
	await hold(KEY_W, 3)
	await frames(5)
	check("a step: up again", home._holder == null and (home._model.global_transform.basis.y as Vector3).dot(Vector3.UP) > 0.95)
	# ---- the gathering fire
	home._open_workshop("build", "campfire")
	await frames(2)
	home._menu.build_it("campfire")
	home._menu.close()
	await frames(90)
	var jumped := false
	for i in 4:
		await use_at("drums")
		jumped = jumped or not home._on_ground
	await frames(4)
	check("the drums: BOOM (the fires flare), four quick: a jump", home._flare > 0.0 and (jumped or not home._on_ground), "flare %.2f" % home._flare)
	await frames(60)
	# ---- the stream: no way over, then the bridge
	var b := sys(Builds)
	var ends: Array = b.bridge_ends()
	var a: Vector2 = ends[0]
	var far: Vector2 = ends[1]
	home._pos = Vector3(a.x, home.height(a.x, a.y), a.y)
	await frames(5)
	var dir := (far - a).normalized()
	await _walk_toward(dir, 120)
	check("no bridge: the stream stops him", Vector2(home._pos.x, home._pos.z).distance_to(a) < 4.0, "got %.1f m" % Vector2(home._pos.x, home._pos.z).distance_to(a))
	home._open_workshop("build", "bridge")
	await frames(2)
	home._menu.build_it("bridge")
	home._menu.close()
	await frames(90)
	home._pos = Vector3(a.x, home.height(a.x, a.y), a.y)
	await frames(5)
	var low := 99.0
	for i in 150:
		_steer(dir)
		await frames(1)
		low = minf(low, home._pos.y)
	_steer(Vector2.ZERO)
	check("the bridge: over the stream, dry feet", Vector2(home._pos.x, home._pos.z).distance_to(far) < 2.5 and low > 0.2, "%.1f m from the far end, lowest %.2f" % [Vector2(home._pos.x, home._pos.z).distance_to(far), low])
	# ---- a moonpuff
	var m: Array = Nature.MOONPUFFS[0]
	var mp: Vector2 = m[0]
	home._pos = Vector3(mp.x, home.pad_top(mp) + 2.5, mp.y)
	home._on_ground = false
	home._vy = 0.0
	var fastest := 0.0
	for i in 60:
		await frames(1)
		fastest = maxf(fastest, home._vy)
	check("a moonpuff: BOING, up he goes", fastest > 10.0, "up at %.1f m/s" % fastest)
	await frames(120)
	# ---- Star Rock: a wish, then the stone sleeps
	var before := GameState.shells + GameState.orbs + GameState.figs + Bag.count(null, "pyrite") + Bag.count(null, "quartz")
	await use_at("wish")
	await frames(90)
	var after := GameState.shells + GameState.orbs + GameState.figs + Bag.count(null, "pyrite") + Bag.count(null, "quartz")
	check("the wishing stone: a gift", after > before, "%d -> %d" % [before, after])
	var again := after
	await use_at("wish")
	await frames(90)
	check("again: the stone is asleep (nothing)", GameState.shells + GameState.orbs + GameState.figs + Bag.count(null, "pyrite") + Bag.count(null, "quartz") == again)
	# ---- the golden horn (it is on Star Rock)
	home._flare = 0.0
	await use_at("horn")
	check("the golden horn: HOOOO, the fires flare", home._flare > 1.5, "flare %.2f" % home._flare)
	# ---- the lookout
	home._open_workshop("build", "lookout")
	await frames(2)
	home._menu.build_it("lookout")
	home._menu.close()
	await frames(90)
	await use_at("lookout")
	await frames(150)
	var g: float = home.height(Builds.LOOKOUT.x, Builds.LOOKOUT.y)
	check("the lookout: up the ladder, on the top", home._holder == null and home._pos.y > g + 4.5, "%.1f m up" % (home._pos.y - g))
	await use_at("lookout_top")
	await frames(120)
	check("and down again", home._pos.y < g + 1.0, "%.1f m up" % (home._pos.y - home.height(home._pos.x, home._pos.z)))
	# ---- the totem
	home._open_workshop("build", "totem")
	await frames(2)
	home._menu.build_it("totem")
	home._menu.close()
	await frames(90)
	await use_at("totem")
	check("the totem: his beasts carved on it", str(home._say.text).contains("SABRE-FANG"), home._say.text)
	# ---- relics at home: NEW till he looks
	check("relics brought home are NEW", relics.new_ones().has("moonstone"))
	var mo: Vector3 = relics._where("moonstone")
	home._pos = Vector3(mo.x, home.height(mo.x, mo.z), mo.z + 1.5)
	await frames(10)
	check("he went and looked: no longer new (saved)", not relics.new_ones().has("moonstone") and (GameState.shelter.get("seen_relics", []) as Array).has("moonstone"))
	await use_at("relics")
	check("the relic shelf: a row for each", home._menu != null and home._menu._rows.size() == Relics.KINDS.size())
	home._menu.close()
	await frames(5)
	# ---- the pup's find
	check("the pup has dug something up", has_spot("dig"))
	var s0 := GameState.shells + GameState.bones + Bag.count(null, "clay") + Bag.count(null, "flint") + Bag.count(null, "pyrite") + Bag.count(null, "quartz")
	await use_at("dig")
	var s1 := GameState.shells + GameState.bones + Bag.count(null, "clay") + Bag.count(null, "flint") + Bag.count(null, "pyrite") + Bag.count(null, "quartz")
	check("dug up: something for him, the mound gone, the time saved", s1 > s0 and not has_spot("dig") and float(GameState.shelter.get("pup", 0.0)) > 0.0, "%d -> %d" % [s0, s1])
	print("shelter: %d failed" % fails)
	get_tree().quit()


## Walk him (as if a key were held) along `dir` for n frames.
func _walk_toward(dir: Vector2, n: int) -> void:
	for i in n:
		_steer(dir)
		await frames(1)
	_steer(Vector2.ZERO)


## The keys for a direction (x: A / D, z: W / S).
func _steer(dir: Vector2) -> void:
	key(KEY_D, dir.x > 0.3)
	key(KEY_A, dir.x < -0.3)
	key(KEY_S, dir.y > 0.3)
	key(KEY_W, dir.y < -0.3)
