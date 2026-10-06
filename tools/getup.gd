extends Node
## Test harness (not shipped): the UNBOWED get-up.
##   fall   - a long flailing fall lands SPLAT (held), then BOING and the flex, then free
##   cancel - a key during the flex ends it at once; a short hop never splats
##   shots  - with rendering: splat, boing, flex PNGs to C:/tmp/shots/getup_*
var level: Node
var p: CaveMan

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

func report(name: String, ok: bool, info: String) -> void:
	print("%-46s %s  %s" % [name, "PASS" if ok else "FAIL", info])

func release() -> void:
	for k in p.touch.keys():
		p.touch[k] = false

func drop(height: float) -> void:
	release()
	level._move_player(Vector2(1200, 600.0 - height), 1)
	p.velocity = Vector2.ZERO
	p.invuln = 0.0
	p.hp = 5
	for i in 300:
		await frames(1)
		if p.is_on_floor() and i > 3:
			break

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/getup_%s.png" % name)
	print("shot ", name)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	p = level.player
	await frames(5)
	p.give_torch()
	p.pick_up_stick()
	if args.has("shots"):
		level.cam.zoom = Vector2(1.7, 1.7)
		level.cam.offset = Vector2(0, 110)
		level.hud.visible = false
		await drop(700.0)
		level.cam.zoom = Vector2(1.7, 1.7)
		level.cam.offset = Vector2(0, 110)
		level.hud.visible = false
		await frames(4)
		await shot("splat")
		await frames(14)
		await shot("boing")
		await frames(24)
		await shot("flex")
		get_tree().quit()
		return
	if args.is_empty() or args.has("fall"):
		await drop(700.0)
		var splat := p.getup >= 0.0
		p.touch["right"] = true
		var x0 := p.global_position.x
		await frames(8)
		var held := absf(p.global_position.x - x0) < 2.0
		release()
		var flexed := false
		for i in 60:
			await frames(1)
			flexed = flexed or p.getup >= CaveMan.GETUP_FLEX
		await frames(30)
		report("fall: SPLAT holds him, then the flex, then free", splat and held and flexed and p.getup < 0.0,
			"splat %s, held %s, flexed %s, done %s" % [splat, held, flexed, p.getup < 0.0])
	if args.is_empty() or args.has("cancel"):
		await drop(700.0)
		var was_up := p.getup >= 0.0
		while p.getup >= 0.0 and p.getup < CaveMan.GETUP_FLEX + 0.05:
			await frames(1)
		p.touch["jump"] = true
		await frames(2)
		var cut := was_up and p.getup < 0.0
		release()
		await frames(40)
		await drop(80.0)
		var hop := p.getup < 0.0
		report("cancel: a key ends the flex; a short drop never splats", cut and hop, "cut %s, short drop calm %s" % [cut, hop])
	get_tree().quit()
