extends Node
## Test harness (not shipped): the combat feel. Holding HIT keeps swinging;
## the hits build a COMBO (and its damage bonus); every hit pops a damage
## number and knocks the beast back; DOWN + HIT in the air is the POGO (he
## bounces off); SPECIAL (L) charges the home run. One PASS/FAIL line each.
##   shots - also save screenshots (run with rendering) to C:/tmp/shots/combat_*
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
	level.cam.zoom = Vector2(1.8, 1.8)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/combat_%s.png" % name)

func check(name: String, ok: bool, info: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name, info])

func release() -> void:
	for k in p.touch.keys():
		p.touch[k] = false

## A tough practice wolf that stays put (well, nearly), so the blows keep landing.
func dummy(x: float) -> Critter:
	var w := NightBeasts.Wolf.new()
	w.left_x = x - 40.0
	w.right_x = x + 40.0
	w.position = Vector2(x, 600)
	level.add_child(w)
	w.hp = 300
	return w

func _run() -> void:
	shots = OS.get_cmdline_user_args().has("shots")
	p = level.player
	await frames(5)
	p.pick_up_stick()
	for c in level.get_children():
		if c is NightBeasts.Wolf or c is NightBeasts.Bat:
			c.free()
	level._move_player(Vector2(1100, 590), 1)
	p.facing = 1
	await frames(20)
	# 1. hold HIT: it keeps swinging
	var swings := 0
	var was := false
	p.touch["attack"] = true
	for i in 90:
		await frames(1)
		var now := p.attacking > 0.0
		if now and not was:
			swings += 1
		was = now
	release()
	check("hold to keep swinging", swings >= 5, "%d swings in 1.5 s" % swings)
	await frames(30)
	# 2. the combo, the numbers, the knock-back, against a tough wolf
	var w := dummy(1160.0)
	await frames(5)
	var x0 := w.global_position.x
	var nums := 0
	var max_kb := 0.0
	p.touch["attack"] = true
	for i in 150:
		await frames(1)
		max_kb = maxf(max_kb, absf(w.kb))
		for c in level.get_children():
			if c is Critter.DamageNumber and not c.has_meta("seen"):
				c.set_meta("seen", true)
				nums += 1
		if i == 100:
			await shot("combo")
	release()
	check("combo builds", p.combo_hits >= 6 and p.combo_bonus() >= 1, "%d hits, +%d damage" % [p.combo_hits, p.combo_bonus()])
	check("damage numbers", nums >= 6, "%d numbers" % nums)
	check("knock-back", max_kb > 200.0, "kb %.0f px/s" % max_kb)
	await frames(150)
	check("combo ends after a pause", p.combo_hits == 0)
	# 3. the POGO: from above, DOWN + HIT, and off he bounces
	w.global_position = Vector2(1300, 600)
	w.left_x = 1299.0
	w.right_x = 1301.0
	w.set_physics_process(false)
	level._move_player(Vector2(1300, 470), 1)
	await frames(2)
	p.velocity = Vector2(0, 200)
	p.touch["down"] = true
	p.touch["attack"] = true
	var bounced := false
	for i in 40:
		await frames(1)
		if p.velocity.y < -400.0:
			bounced = true
			await shot("pogo")
			break
	release()
	check("pogo bounce", bounced, "vy %.0f" % p.velocity.y)
	await frames(60)
	# 4. SPECIAL: hold, let go — the home run
	level._move_player(Vector2(1100, 590), 1)
	await frames(30)
	p.touch["special"] = true
	await frames(40)
	p.touch["special"] = false
	var hr := false
	for i in 20:
		await frames(1)
		hr = hr or p._swing_kind == "homerun"
	check("special: home run", hr)
	get_tree().quit()
