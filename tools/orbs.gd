extends Node
## Test harness (not shipped): SPIRIT ORBS. A wolf beaten next to him: its
## orbs burst out and stream into him by themselves; the count is right and
## saved; nothing is left lying about. One PASS/FAIL line each.
##   shots - also save screenshots (run with rendering) to C:/tmp/shots/orbs_*
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
		p.invuln = 0.5

func check(name: String, ok: bool, info: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name, info])

func _run() -> void:
	var shots := OS.get_cmdline_user_args().has("shots")
	p = level.player
	await frames(5)
	p.pick_up_stick()
	for c in level.get_children():
		if c is NightBeasts.Wolf or c is NightBeasts.Bat:
			c.free()
	var w := NightBeasts.Wolf.new()
	w.left_x = 1000.0
	w.right_x = 1490.0
	w.position = Vector2(1300, 600)
	level.add_child(w)
	level._move_player(Vector2(1120, 590), 1)
	await frames(20)
	var expect: int = Critter.ORBS.worth(w.hp)
	w.set_physics_process(false)
	w.take_hit(99, 1)
	var t := 0
	while GameState.orbs < expect and t < 240:
		await frames(1)
		t += 1
		if shots and t in [12, 28, 44]:
			level.cam.zoom = Vector2(1.8, 1.8)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("C:/tmp/shots/orbs_%02d.png" % t)
	check("wolf orbs", GameState.orbs == expect, "%d of %d in %.2f s" % [GameState.orbs, expect, t / 60.0])
	await frames(10)
	var left := 0
	for c in level.get_children():
		if c.get_script() == Critter.ORBS:
			left += 1
	check("burst gone", left == 0)
	GameState.save()
	var saved := GameState.orbs
	GameState.orbs = 0
	GameState._loaded = false
	GameState.ensure_loaded()
	check("saved", GameState.orbs == saved, "%d after reloading the save" % GameState.orbs)
	check("hud shows", level.hud._orbs_shown == saved)
	get_tree().quit()
