extends Node
## Test harness (not shipped): pictures of the new things.
var level: Node
var p: CaveMan
func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % n)
func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	p.talking = false
func wait(s: float, keep_quiet := true) -> void:
	var t := 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time() / maxf(Engine.time_scale, 0.01)
		if keep_quiet:
			quiet()
func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.give_torch()
	p.invuln = 999.0
	p.hp = 99
	level._snuffed = true
	level._panicked = true
	for m in level._mouths:
		m._noticed = true
	# a wolf's defeat: knocked out, then bolting
	var wolf: Critter = null
	for c in level.get_children():
		if c is NightBeasts.Wolf and (wolf == null or absf(c.position.x - 1330.0) < absf(wolf.position.x - 1330.0)):
			wolf = c
	p.global_position = Vector2(1150, 590)
	await wait(0.3)
	wolf.position = Vector2(1240, 600)
	wolf.take_hit(99, 1)
	await wait(0.95)
	await snap("n_wolf_ko")
	await wait(0.55)
	await snap("n_wolf_bolt")
	# the Toolmaker's home
	level._met_toolmaker = true
	level._near_toolmaker = true
	p.global_position = Vector2(30850, 590)
	await wait(0.8)
	await snap("n_camp")
	# the item card, with the hammer held up
	p.global_position = Vector2(30960, 590)
	await wait(0.3)
	level._hammer_reveal()
	await wait(1.2, false)
	await snap("n_card")
	for c in level.get_children():
		if c is ItemGet:
			c.queue_free()
	p.talking = false
	p.showing_off = 0.0
	await wait(0.3)
	# raising the hammer, then the slam's wave (by the trial's boulder and first bowl)
	p.global_position = Vector2(31600, 590)
	p.facing = 1
	await wait(0.4)
	p.slam_charge = 0.35
	p.set_physics_process(false)
	for i in 6:
		p.anim_t += 0.016
		p.queue_redraw()
		await get_tree().process_frame
	await snap("n_charge")
	p.set_physics_process(true)
	p.slam_charge = -1.0
	p._slam()
	await wait(0.28)
	await snap("n_slam")
	# the gate burning
	for b in level.get_children():
		if b is NightWoods.Brazier and b.global_position.x < 32200.0 and b.global_position.x > 31500.0:
			b.kindle()
	p.global_position = Vector2(32080, 590)
	await wait(0.6)
	await snap("n_gate")
	# Old Scar: the eye trick, and the meteor
	p.global_position = Vector2(32700, 590)
	await wait(6.0)
	var sc: OldScar = level.scar
	sc.phase = 2
	sc.cd = 0.0
	sc._hide_x = 33300.0
	sc.state = "vanish"
	await wait(1.6)
	await snap("n_eyes")
	sc.phase = 3
	sc._meteor_cd = 0.0
	sc.state = "prowl"
	sc.cd = 0.0
	sc._foiled = 0
	for i in 400:
		await get_tree().process_frame
		quiet()
		if sc.state == "perch":
			break
	await wait(1.0)
	await snap("n_meteor")
	get_tree().quit()
