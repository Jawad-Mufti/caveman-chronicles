extends Node
## Test harness (not shipped): SHIVERS' WINDBREAK (level2/windbreak.gd). He's
## there, cold; the talk opens the mixing slab; wrong mixes get a hint and
## cost nothing; the right one (2 wood, 3 rocks, 1 clay) is spent, Ugu builds
## for 2 s, the wall stands, the mystery is solved, obsidian comes to the bag;
## the mud bank gives clay. One PASS/FAIL line each.
##   shots - screenshots to C:/tmp/shots/windbreak/*
var level: Node
var p: CaveMan
var shots := false
const WB := preload("res://level2/windbreak.gd")

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		p.invuln = 1.0

func shot(name: String) -> void:
	if not shots:
		return
	DirAccess.make_dir_recursive_absolute("C:/tmp/shots/windbreak")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/windbreak/%s.png" % name)

func check(name: String, ok: bool, info: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name, info])

func dialogue() -> Dialogue:
	for c in level.get_children():
		if c is Dialogue and not c.is_queued_for_deletion():
			return c
	return null

## Talk through to the end (choices: the first answer).
func talk_through() -> void:
	for i in 40:
		var d := dialogue()
		if d == null:
			return
		d._next()
		await frames(2)

func _run() -> void:
	shots = OS.get_cmdline_user_args().has("shots")
	p = level.player
	await frames(5)
	p.pick_up_stick()
	for c in level.get_children():
		if c is Critter:
			c.free()
	var camp = level.shivers
	check("camp", camp != null and camp.position == level.WINDBREAK.AT and not camp.built)
	level._move_player(Vector2(level.WINDBREAK.AT.x + 20.0, 590), 1)
	await frames(30)
	for c in level.get_children():
		if c is Critter:
			c.free()
	await shot("cold")
	# 1. the talk opens the slab
	camp.meet()
	await frames(3)
	check("talks", dialogue() != null and GameState.mystery("windbreak") == "open")
	await talk_through()
	await frames(5)
	var m := Bag.mixer
	check("slab opens", m != null and p.talking and Bag.mode != 0, "mixer %s talking %s" % [m, p.talking])
	if m == null:
		get_tree().quit()
		return
	# 2. what he has
	p.wood = 3
	p.rocks = 4
	GameState.bag = {"clay": 1, "flint": 1}
	GameState.bones = 3
	Bag.version += 1
	# 3. a wrong mix: a hint, and nothing spent
	for id in ["wood", "wood", "rocks", "rocks", "rocks", "clay", "bones"]:
		m.put(id)
	m.put("club")
	check("weapon refused", not m.mix.has("club") and m.note.contains("BONK"), m.note)
	m.mixed.emit(m.mix.duplicate())
	check("bones hint", m.note.contains("skeleton") and p.wood == 3 and GameState.bones == 3, m.note)
	m.take("bones")
	m.put("wood")
	m.mixed.emit(m.mix.duplicate())
	check("too much wood", m.note.contains("Too much WOOD"), m.note)
	m.take("wood")
	m.take("rocks")
	m.mixed.emit(m.mix.duplicate())
	check("too few rocks", m.note.contains("Not enough ROCKS"), m.note)
	m.put("rocks")
	m.put("clay")
	check("only what he has", int(m.mix["clay"]) == 1 and m.note.contains("all the CLAY"), m.note)
	await frames(3)
	await shot("mixer")
	# 4. the right mix: spent, and he builds
	m.mixed.emit(m.mix.duplicate())
	await frames(3)
	check("spent", Bag.mixer == null and p.wood == 1 and p.rocks == 1 and Bag.count(p, "clay") == 0 and camp.build_t >= 0.0,
		"wood %d rocks %d clay %d" % [p.wood, p.rocks, Bag.count(p, "clay")])
	await frames(60)
	check("building", p.talking and not camp.built and absf(p.global_position.x - (camp.global_position.x + level.WINDBREAK.STAND_X)) < 4.0, "x %.0f" % p.global_position.x)
	await shot("building")
	await frames(70)
	check("built", camp.built and GameState.mystery("windbreak") == "solved")
	await talk_through()
	await frames(150)
	check("reward", Bag.count(p, "obsidian") == 2 and GameState.figs == 1, "obsidian %d figs %d" % [Bag.count(p, "obsidian"), GameState.figs])
	await shot("warm")
	# 5. the mud bank
	var mud: Node = null
	for c in level.get_children():
		if c is WB.MudBank:
			mud = c
	var before := Bag.count(p, "clay")
	for i in 12:
		mud.take_hit(1, 1)
		await frames(15)
	await frames(120)
	check("mud gives clay", Bag.count(p, "clay") >= before + 4, "%d -> %d" % [before, Bag.count(p, "clay")])
	# 6. again: a short line, no slab
	camp.meet()
	await frames(3)
	check("after: no slab", Bag.mixer == null and dialogue() == null)
	print("DONE")
	get_tree().quit()
