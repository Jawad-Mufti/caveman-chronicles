extends Node
## Test harness (not shipped): the key frames of every weapon's swing and special.
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
	var img := get_viewport().get_texture().get_image()
	img.crop(1280, 720)
	img.get_region(Rect2i(380, 250, 520, 400)).save_png("/tmp/shots/w_%s.png" % n)
func pose(kind: String, sp: float, weapon: String) -> void:
	p.axe = weapon == "axe"
	p.hammer = weapon == "hammer"
	p._swing_kind = kind
	p._swing_time = CaveMan.SWINGS[kind][0]
	p.attacking = p._swing_time * (1.0 - sp)
	p.slam_charge = -1.0
	p.queue_redraw()
	await get_tree().process_frame
func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.invuln = 11699.0
	for c in level.get_children():
		if c is Dialogue: c.queue_free()
	p.talking = false
	level.night.table = [[0.0, 0.3]]
	p.global_position = Vector2(700, 590)
	p.facing = 1
	for i in 20: await get_tree().process_frame
	p.set_physics_process(false)
	await pose("club", 0.15, "club"); await snap("club_a")
	await pose("club", 0.6, "club"); await snap("club_b")
	await pose("axe0", 0.5, "axe"); await snap("axe0")
	await pose("axe1", 0.5, "axe"); await snap("axe1")
	await pose("axe2", 0.4, "axe"); await snap("axe2_top")
	await pose("axe2", 0.75, "axe"); await snap("axe2_chop")
	await pose("hammer", 0.5, "hammer"); await snap("hammer_top")
	await pose("hammer", 0.75, "hammer"); await snap("hammer_smash")
	await pose("homerun", 0.45, "club"); await snap("homerun")
	# the charge poses, fully charged
	for w in ["club", "axe", "hammer"]:
		p.axe = w == "axe"
		p.hammer = w == "hammer"
		p.attacking = 0.0
		p.slam_charge = 0.8
		for i in 3:
			p.anim_t += 0.02
			p.queue_redraw()
			await get_tree().process_frame
		await snap("charge_" + w)
	p.slam_charge = -1.0
	# the axe in flight
	p.axe = true
	p.hammer = false
	p.set_physics_process(true)
	p._throw_axe()
	for i in 12: await get_tree().physics_frame
	await snap("axe_flying")
	get_tree().quit()
