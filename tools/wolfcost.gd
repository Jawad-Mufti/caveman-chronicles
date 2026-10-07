extends Node
## Test harness (not shipped): what does a wolf cost, drawing or thinking?
## A pack of N wolves round him; the average frame with everything on, with
## the wolves hidden (no drawing, still thinking), and with their AI off
## (drawn, frozen). Run with rendering and --disable-vsync.   args: n=<wolves>
var level: Node
var p: CaveMan
var n := 14

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("n="): n = int(a.substr(2))
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func avg(frames: int) -> float:
	var t0 := Time.get_ticks_usec()
	for i in frames:
		await get_tree().process_frame
		p.invuln = 1.0
		p.hp = p.max_hp
	return (Time.get_ticks_usec() - t0) / 1000.0 / frames

func _run() -> void:
	p = level.player
	await get_tree().process_frame
	for c in level.get_children():
		if c is Critter:
			c.free()
	level._move_player(Vector2(1500, 590), 1)
	for i in 30:
		await get_tree().process_frame
	var none := await avg(240)
	var wolves: Array = []
	for i in n:
		var w := NightBeasts.Wolf.new()
		w.left_x = 1100.0
		w.right_x = 1900.0
		w.position = Vector2(1150.0 + i * 50.0, 600)
		level.add_child(w)
		wolves.append(w)
	for i in 30:
		await get_tree().process_frame
	var all := await avg(240)
	for w in wolves: w.visible = false
	var hidden := await avg(240)
	for w in wolves:
		w.visible = true
		w.set_physics_process(false)
	var frozen := await avg(240)
	print("WOLFCOST n=%d  no wolves %.2f ms | all %.2f | drawing %.2f ms (%.3f each) | thinking %.2f ms (%.3f each)" % [
		n, none, all, all - hidden, (all - hidden) / n, all - frozen, (all - frozen) / n])
	get_tree().quit()
