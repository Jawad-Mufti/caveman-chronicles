extends "res://tools/harness.gd"
## Close-ups of the Steppe's MAMMOTHS (run with rendering): the herd framed
## whole, then one bull up close, walking each way. PNGs to C:/tmp/shots/mammoth_*.


func run() -> void:
	shot_prefix = "mammoth"
	p.invuln = 99999.0
	var ms: Array = []
	for c in level.get_children():
		if c is Steppe.Mammoth:
			ms.append(c)
	var bull: Steppe.Mammoth = ms[0]
	await put(Vector2(bull.global_position.x - 420.0, 590))
	await frames(30)
	await framed(bull, Vector2(140, -150), 1.0, "herd")
	await framed(bull, Vector2(0, -110), 1.9, "close_a")
	await frames(150)
	await framed(bull, Vector2(0, -110), 1.9, "close_b")


## A picture with the camera wherever we like: the level stops steering it
## (its own _process follows him), the beast holds still for it.
func framed(who: Node2D, off: Vector2, zoom: float, label: String) -> void:
	var cam: Camera2D = level.cam
	level.set_process(false)
	who.set_physics_process(false)
	cam.position_smoothing_enabled = false
	cam.global_position = who.global_position + off
	cam.offset = Vector2.ZERO
	cam.zoom = Vector2(zoom, zoom)
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/%s_%s.png" % [shot_prefix, label])
	who.set_physics_process(true)
	cam.position_smoothing_enabled = true
	level.set_process(true)
