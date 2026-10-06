extends Node
## Test harness (not shipped): a running double jump, with screenshots of the
## somersault and the tumble after it (to C:/tmp/shots/tumble_*.png).
## args: frame numbers to snap (default 20 30 40 48 56), "nodark", "drop" (a plain long fall)
var level: Node
var p: CaveMan

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.give_torch()
	p.invuln = 0.0
	var args := OS.get_cmdline_user_args()
	if args.has("nodark"):
		level.night.table = [[0.0, 0.0]]
	var snaps := []
	for a in args:
		if a.is_valid_int():
			snaps.append(int(a))
	if snaps.is_empty():
		snaps = [20, 30, 40, 48, 56]
	for c in level.get_children():
		if c is Critter or c is Dialogue:
			c.queue_free()
	level._move_player(Vector2(14800, 590), 1)
	for i in 40:
		await get_tree().physics_frame
		p.talking = false
	var drop := args.has("drop")       # a plain long fall from high up, no jumps
	if drop:
		p.global_position = Vector2(14800, -500)
		p.velocity = Vector2.ZERO
	else:
		p.touch["right"] = true
		for i in 15:
			await get_tree().physics_frame
		p.touch["jump"] = true
	for f in 90:
		if f == 22 and not drop:
			p.touch["jump"] = false
		if f == 24 and not drop:
			p.touch["jump"] = true
		await get_tree().physics_frame
		if snaps.has(f):
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png("C:/tmp/shots/tumble_%02d.png" % f)
			# and a close-up of him, twice the size
			var sp := get_viewport().get_canvas_transform() * p.global_position
			var crop := img.get_region(Rect2i(int(sp.x) - 100, int(sp.y) - 190, 200, 210))
			crop.resize(600, 630, Image.INTERPOLATE_NEAREST)
			crop.save_png("C:/tmp/shots/tumble_%02d_zoom.png" % f)
		if f > 30 and p.is_on_floor():
			break
	get_tree().quit()
