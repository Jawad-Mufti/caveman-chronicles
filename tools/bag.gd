extends Node
## Test harness (not shipped): UGU'S BAG. What he has is sorted into boxes;
## digging turns up stones; recipes make things; made things join the hotbar
## and HIT uses them (tips thrown, salve eaten, wall and ladder built, the torch
## sparked); the forever-ones stick; the bag is saved. One PASS/FAIL line each.
##   shots - screenshots to C:/tmp/shots/bag/*
var level: Node
var p: CaveMan
var shots := false

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		for c in level.get_children():
			if c is Dialogue:
				c.queue_free()
		p.talking = false
		p.invuln = 1.0

func shot(name: String) -> void:
	if not shots:
		return
	DirAccess.make_dir_recursive_absolute("C:/tmp/shots/bag")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/bag/%s.png" % name)

func check(name: String, ok: bool, info: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name, info])

func hit() -> void:
	p.touch["attack"] = true
	await frames(3)
	p.touch["attack"] = false
	await frames(20)

func hold(id: String) -> void:
	p.select_slot(p.hotbar().find(id))
	await frames(2)

func count_of(cls) -> int:
	var n := 0
	for c in level.get_children():
		if is_instance_of(c, cls):
			n += 1
	return n

func _run() -> void:
	shots = OS.get_cmdline_user_args().has("shots")
	p = level.player
	await frames(5)
	p.pick_up_stick()
	for c in level.get_children():
		if c is Critter:
			c.free()
	level._move_player(Vector2(1100, 590), 1)
	await frames(10)
	# 1. the boxes: what he has, sorted by kind
	GameState.give_item("shovel")
	p.add_rock(4)
	GameState.bones = 12
	GameState.shells = 40
	GameState.add_relic("moonstone")
	var l := Bag.listing(p)
	check("sorted", l.find("club") < l.find("shovel") and l.find("shovel") < l.find("rocks") and l.find("rocks") < l.find("bones") and l.find("bones") < l.find("shells") and l.has("relic:moonstone"), str(l))
	check("tooltip text", Bag.goes_into("flint").size() == 3 and Bag.name_of("relic:moonstone") == "MOONSTONE", str(Bag.goes_into("flint")))
	# 2. stones: a fixed number buried in the mountain, hidden; dug out once each
	var t: Terrain = level.mountain
	var stones: Array = []
	for idx in t.loot:
		if str(t.loot[idx][0]).begins_with("stone:"):
			stones.append(idx)
	var want := 0
	for k in level.MT_STONES:
		want += int(level.MT_STONES[k])
	check("stones buried", stones.size() == want, "%d of %d" % [stones.size(), want])
	var one: int = stones[0]
	var kind: String = str(t.loot[one][0]).substr(6)
	var sid: String = t.loot[one][1]
	var had_stone := Bag.count(p, kind)
	t._reveal(Vector2i(one % t._w, one / t._w))
	await frames(240)
	check("dug out", Bag.count(p, kind) == had_stone + 1 and GameState.is_taken("level2", sid), "%s %d -> %d" % [kind, had_stone, Bag.count(p, kind)])
	t.loot[one] = ["stone:" + kind, sid]
	t._reveal(Vector2i(one % t._w, one / t._w))
	await frames(150)
	check("only once", Bag.count(p, kind) == had_stone + 1)
	# 3. crafting: flint tips
	GameState.bag = {"flint": 3, "clay": 3, "pyrite": 1, "obsidian": 2, "quartz": 2}
	var m := Bag.missing(p, "spark")
	check("can craft", m == "", m)
	var ok := Bag.craft(p, "tips")
	check("craft tips", ok and Bag.count(p, "tips") == 3 and Bag.count(p, "flint") == 2 and GameState.bones == 11, str(GameState.bag))
	check("missing says what", Bag.missing(p, "ladder").begins_with("Need 1 more WOOD"), Bag.missing(p, "ladder"))
	check("hotbar has tips", p.hotbar().has("tips"), str(p.hotbar()))
	# 4. a tip, thrown
	await hold("tips")
	await hit()
	var tip := false
	for c in level.get_children():
		if c is World.ThrownRock and c.flint and c.dmg == 6:
			tip = true
	check("throw tip", tip and Bag.count(p, "tips") == 2, "left %d" % Bag.count(p, "tips"))
	# 5. salve
	p.berries = 1
	Bag.craft(p, "salve")
	p.hp = 1
	await hold("salve")
	await hit()
	check("salve heals 3", p.hp == 4 and Bag.count(p, "salve") == 0 and p.tool == "weapon", "hp %d tool %s" % [p.hp, p.tool])
	# 6. the wall: solid in front of him
	Bag.craft(p, "wall")
	await hold("wall")
	await hit()
	await frames(20)
	var wall: Node2D = null
	for c in level.get_children():
		if c is Bag.StoneWall:
			wall = c
	var solid := false
	if wall != null:
		var q := PhysicsRayQueryParameters2D.create(wall.global_position + Vector2(-80, -50), wall.global_position + Vector2(80, -50), 1)
		solid = not p.get_world_2d().direct_space_state.intersect_ray(q).is_empty()
	check("wall stands", wall != null and solid and p.rocks == 1, "rocks %d" % p.rocks)
	await shot("wall")
	# 7. the ladder: he stands on its top rung
	p.wood = 2
	level._move_player(Vector2(900, 590), 1)
	await frames(15)
	Bag.craft(p, "ladder")
	await hold("ladder")
	await hit()
	var lad: Node2D = null
	for c in level.get_children():
		if c is Bag.Ladder:
			lad = c
	check("ladder up", lad != null, "")
	if lad != null:
		var top := lad.global_position.y - Bag.Ladder.RUNG * Bag.Ladder.RUNGS
		p.global_position = Vector2(lad.global_position.x, top - 40)
		p.velocity = Vector2.ZERO
		await frames(40)
		check("stands on rung", absf(p.global_position.y - top) < 40.0 and p.is_on_floor(), "y %.0f top %.0f" % [p.global_position.y, top])
		await shot("ladder")
	# 8. the spark kit lights the torch
	p.give_torch()
	p.torch_fuel = 0.2
	Bag.craft(p, "spark")
	await hold("spark")
	await hit()
	check("spark relights", p.torch_fuel > 0.95, "%.2f" % p.torch_fuel)
	# 9. the forever ones
	var before := p.club_bonus
	Bag.craft(p, "edge")
	Bag.craft(p, "charm")
	check("edge +1", p.club_bonus == before + 1 and GameState.has_item("obsidian_edge") and Bag.missing(p, "edge") != "", "%d -> %d" % [before, p.club_bonus])
	check("charm", GameState.has_item("lucky_charm") and Bag.count(p, "quartz") == 0)
	# 10. kept on disk
	var was := GameState.bag.duplicate()
	GameState.save()
	GameState._loaded = false
	GameState.bag = {}
	GameState.ensure_loaded()
	var same := true
	for k in was:
		if int(GameState.bag.get(k, -1)) != int(was[k]):
			same = false
	check("saved", same, "%s vs %s" % [was, GameState.bag])
	# 11. the view: hidden -> strip -> big -> hidden
	var v := get_tree().get_first_node_in_group("hud").get("_bag") as Bag.View
	Bag.mode = 1
	GameState.bag["flint"] = 2
	GameState.bag["clay"] = 1
	Bag.version += 1
	await frames(4)
	check("strip input", v._has_point(Bag.View.STRIP + Vector2(10, 10)) and not v._has_point(Vector2(640, 400)))
	v._mouse = Bag.View.STRIP + Vector2(10, 10)
	v._hover = ["item", Bag.listing(p)[0]]
	await frames(3)
	await shot("strip")
	v.toggle()
	check("big view", Bag.mode == 2 and v._has_point(Vector2(640, 400)))
	v._hover = ["recipe", "tips"]
	v._mouse = Bag.View.PANEL.position + Bag.View.CRAFT.position + Vector2(40, 20)
	await frames(3)
	await shot("big")
	v.tab = "STONES"
	v._hover = ["item", "flint"]
	v._mouse = Bag.View.PANEL.position + Bag.View.GRID + Vector2(60, 20)
	await frames(3)
	await shot("stones")
	v.toggle()
	check("hidden", Bag.mode == 0 and not v._has_point(Bag.View.STRIP + Vector2(10, 10)) and v._has_point(Bag.View.BTN.get_center()))
	v.toggle()
	# the world waits while the big view (or a mixing slab) is open; a pause made by the camp menu is left alone
	Bag.mode = 2
	await frames(2)
	var big_paused := get_tree().paused and Bag.holding
	Bag.mode = 1
	await frames(2)
	var big_free := not get_tree().paused
	var mx := Bag.Mixer.new()
	mx.him = p
	level.hud.add_child(mx)
	await frames(2)
	var mix_paused := get_tree().paused
	mx.queue_free()
	await frames(3)
	var mix_free := not get_tree().paused
	level.open_menu()
	await frames(2)
	Bag.mode = 2
	await frames(2)
	Bag.mode = 1
	await frames(2)
	var menu_kept := get_tree().paused and not Bag.holding
	var menu: CampMenu = get_tree().get_first_node_in_group("camp_menu")
	if menu != null:
		menu._close()
	await frames(2)
	check("the world waits while the bag's big view or a mix is open", big_paused and big_free and mix_paused and mix_free and menu_kept and not get_tree().paused,
		"big %s/%s, mix %s/%s, menu's pause kept %s" % [big_paused, big_free, mix_paused, mix_free, menu_kept])
	print("DONE")
	get_tree().quit()
