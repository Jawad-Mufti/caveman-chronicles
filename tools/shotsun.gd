extends Node
## Test harness (not shipped): screenshots of SUNFIRE and the Camp Menu.
## PNGs to C:/tmp/shots/sun_*. Run with rendering (not headless).
var level: Node
var p: CaveMan

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.reset()
	GameState.seen["level2"] = true
	GameState.learn("sunfire")
	GameState.learn("wallkick")
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue or c is ItemGet:
			c.queue_free()
	p.talking = false

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/sun_%s.png" % name)
	print("shot ", name)

func wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame
		if not get_tree().paused:
			quiet()

func _run() -> void:
	p = level.player
	await wait(5)
	p.give_torch()
	p.invuln = 99999.0
	for m in level._mouths:
		m._noticed = true
	# out on the first stretch, near the wolves, sun full
	level._move_player(Vector2(2500, 590), 1)
	await wait(30)
	p.sun_charge = 1.0
	await wait(10)
	await shot("hud_full")
	p.start_sunfire()
	await wait(8)
	await shot("ignite")
	while Engine.time_scale < 1.0:
		await wait(1)
	# running and throwing fireballs
	p.touch["right"] = true
	for i in 40:
		p.touch["throw"] = i % 8 < 3
		await wait(1)
	await shot("blaze_run")
	p.touch["right"] = false
	p.touch["throw"] = false
	p.touch["jump"] = true
	await wait(14)
	await shot("blaze_jump")
	p.touch["jump"] = false
	await wait(30)
	# close up, standing, then mid-throw
	level._move_player(Vector2(1300, 590), 1)
	await wait(20)
	var cam := get_viewport().get_camera_2d()
	cam.zoom = Vector2(2.6, 2.6)
	cam.offset = Vector2(0, 110)
	await wait(20)
	await shot("closeup")
	p.touch["throw"] = true
	await wait(5)
	await shot("closeup_throw")
	p.touch["throw"] = false
	cam.zoom = Vector2.ONE
	cam.offset = Vector2.ZERO
	await wait(10)
	# the camp menu
	level.open_menu()
	await wait(40)
	await shot("menu_main")
	var m: CampMenu = get_tree().get_first_node_in_group("camp_menu")
	m._sel = m.row_of("abilities")
	await wait(20)
	await shot("menu_main_abilities")
	m._choose_id("abilities")
	m._pick = 0
	m._show_ability()
	await wait(40)
	await shot("menu_abilities")
	m._pick = 2
	m._show_ability()
	await wait(20)
	await shot("menu_locked")
	m._pick = 1
	m._show_ability()
	m._carry()
	await wait(10)
	await shot("menu_put_down")
	m._carry()
	m._go("main")
	m._choose_id("tutorial")
	m._pick = 2
	m._show_ability()
	await wait(30)
	await shot("menu_tutorial")
	m._go("main")
	m._choose_id("shelter")
	await wait(30)
	await shot("menu_shelter")
	m._go("main")
	m._sel = m.row_of("save")
	m._choose_id("save")
	await wait(8)
	await shot("menu_saved")
	get_tree().quit()
