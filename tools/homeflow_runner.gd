extends Node
## (homeflow's runner: it lives on the root, so it survives the scenes changing
## under it.) The trip HOME: UGU'S CAVE locked before Level 2 is finished, open
## after; the Camp Menu takes him to the cave; Esc brings him back to the level
## where he stood, his SAVE spot untouched.  shots: pictures of the era-2 cave.
var fails := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_go.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(label: String, ok: bool, info: String = "") -> void:
	if not ok:
		fails += 1
	print("%s %s  %s" % ["PASS" if ok else "FAIL", label, info])


func level() -> LevelBase:
	return get_tree().current_scene as LevelBase


func menu() -> CampMenu:
	for c in level().get_children():
		if c is Dialogue:
			c.queue_free()
	level().player.talking = false
	await frames(3)
	level().open_menu()
	await frames(3)
	return get_tree().get_first_node_in_group("camp_menu")


func _go() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	GameState.save()
	get_tree().change_scene_to_file("res://level2/level2.tscn")
	await frames(30)
	var m: CampMenu = await menu()
	var row := m.row_of("shelter")
	var locked := m._row_off(row)
	m._choose(row)
	await frames(10)
	check("the cave is locked before Level 2 is finished", locked and get_tree().current_scene is LevelBase)
	m._close()
	# Level 2 done (Old Scar's fang): open
	GameState.trophies.append("sabre_fang")
	GameState.save_spot("res://level2/level2.tscn", Vector2(1150, 600), false, "x")
	var spot0: Dictionary = GameState.spot.duplicate()
	level()._move_player(Vector2(1150, 560), 1)        # flat ground (x 3000 is a slope: he slides)
	await frames(40)
	var at := level().player.global_position
	m = await menu()
	m._choose(row)
	await frames(30)
	var home := get_tree().current_scene
	check("open after: the Camp Menu takes him to the cave", home != null and home.scene_file_path == "res://shelter/home.tscn" and not get_tree().paused,
		"scene %s" % (home.scene_file_path if home else "?"))
	if OS.get_cmdline_user_args().has("shots"):
		await frames(20)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("C:/tmp/shots/home_era2.png")
	var away := Vector2(float(GameState.away.get("x", 0.0)), float(GameState.away.get("y", 0.0)))   # where he stood (or his last firm ground)
	home.leave()
	await frames(12)                 # (measured as he arrives: beasts near the start knock him about)
	var back := level()
	check("Esc: back in the level where he stood, SAVE spot untouched", back != null and back.resumed and back.player.global_position.distance_to(away) < 30.0 and GameState.spot == spot0,
		"him at %s (remembered %s), spot kept %s" % [back.player.global_position if back else Vector2.ZERO, away, GameState.spot == spot0])
	print("HomeFlow: %d failed" % fails)
	get_tree().quit()
