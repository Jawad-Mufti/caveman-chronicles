extends Node
## (loadflow's runner: it lives on the root, so it survives the scene changing
## under it.) The real path: the game's own scene, the Camp Menu's SAVE, LOAD
## pressed twice (the scene changes), where he wakes. With `second`: a new run
## of the game loads what the last run saved.
var fails := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_go.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func level() -> LevelBase:
	return get_tree().current_scene as LevelBase


func check(label: String, ok: bool, info: String = "") -> void:
	if not ok:
		fails += 1
	print("%s %s  %s" % ["PASS" if ok else "FAIL", label, info])


## The level, with its opening talk swept away; then the camp menu.
func open_level() -> CampMenu:
	get_tree().change_scene_to_file("res://level2/level2.tscn")
	await frames(30)
	var lv := level()
	for c in lv.get_children():
		if c is Dialogue:
			c.queue_free()
	lv.player.talking = false
	await frames(5)
	return null


func menu() -> CampMenu:
	level().open_menu()
	await frames(3)
	return get_tree().get_first_node_in_group("camp_menu")


func _go() -> void:
	check("tests save to their own file, never the player's", GameState.save_path() == GameState.TEST_PATH, GameState.save_path())
	if OS.get_cmdline_user_args().has("second"):
		GameState.ensure_loaded()
		var on_disk: Dictionary = GameState.spot.duplicate()
		await open_level()
		var m0: CampMenu = await menu()
		var off := m0._row_off(m0.row_of("load"))
		m0._select(m0.row_of("load"))
		m0._choose(m0.row_of("load"))
		m0._choose(m0.row_of("load"))
		await frames(40)
		var want := Vector2(float(on_disk.get("x", 0.0)), float(on_disk.get("y", 0.0)))
		check("a new run of the game LOADs the last run's save", not on_disk.is_empty() and not off and level().resumed and level().player.global_position.distance_to(want) < 60.0,
			"spot on disk %s, LOAD off %s, woke at %s" % [want, off, level().player.global_position])
		_end()
		return
	GameState.reset()
	GameState.seen["level2"] = true
	GameState.save()
	await open_level()
	var lv := level()
	lv._move_player(Vector2(3000, 590), 1)
	await frames(40)
	var at := lv.player.global_position
	var m: CampMenu = await menu()
	m._select(m.row_of("save"))
	m._choose(m.row_of("save"))
	await frames(3)
	var on_file := FileAccess.get_file_as_string(GameState.save_path()).contains("\"spot\":{\"")
	check("SAVE keeps his spot, on disk", not GameState.spot.is_empty() and on_file, "spot %s, in the file %s" % [GameState.spot, on_file])
	m._select(m.row_of("load"))
	m._choose(m.row_of("load"))
	var asks := m._confirm > 0.0 and level() == lv
	m._choose(m.row_of("load"))
	await frames(40)
	var lv2 := level()
	check("LOAD asks once, then wakes him where he saved", asks and lv2 != lv and lv2.resumed and lv2.player.global_position.distance_to(at) < 60.0 and not get_tree().paused,
		"asked %s, new scene %s, woke at %s (saved at %s)" % [asks, lv2 != lv, lv2.player.global_position, at])
	_end()


func _end() -> void:
	print("LoadFlow: %d failed" % fails)
	get_tree().quit()
