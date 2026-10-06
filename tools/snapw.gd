extends Node
## Test harness (not shipped): teleports him to spots and takes screenshots.
## args: spots as  name:x:y  (several allowed), plus optional  torch  nodark  key=0|1
var level: Node
var p: CaveMan
func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("key="):
			level.key_cave = int(a.split("=")[1])
	add_child(level)
	_run.call_deferred()
func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue: c.queue_free()
	p.talking = false
func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.give_torch()
	p.invuln = 99999.0
	var args := OS.get_cmdline_user_args()
	if args.has("nodark"):
		level.night.table = [[0.0, 0.0]]
	if args.has("freeze"):
		for c in level.get_children():
			if c is Critter: c.set_physics_process(false)
	for a in args:
		var parts := a.split(":")
		if parts.size() < 3: continue
		var at := Vector2(float(parts[1]), float(parts[2]))
		level._move_player(at, 1)
		for i in 40:
			await get_tree().physics_frame
			quiet()
			p.torch_fuel = 0.0 if args.has("notorch") else 1.0
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("C:/tmp/shots/%s.png" % parts[0])
	get_tree().quit()
