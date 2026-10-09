extends "res://tools/harness.gd"
## Screenshots of the METEOR DASH's effects (jump, then T + right), a paused
## frame every 2 through it; `gold` for the double-jump one. Run with
## rendering; PNGs to C:/tmp/shots/dash_*.


func run() -> void:
	shots = true
	shot_prefix = "dash"
	p.invuln = 99999.0
	p.give_torch()
	await put(Vector2(1150, 590))
	await frames(20)
	level.cam.zoom = Vector2(1.7, 1.7)
	var gold := args.has("gold")
	p.touch["jump"] = true
	await frames(8)
	if gold:
		p.touch["jump"] = false
		await frames(3)
		p.touch["jump"] = true
		await frames(6)
	p.touch["right"] = true
	p.stomp_state = ""
	Input.action_press("ui_accept")
	p.touch["stomp"] = true
	for i in 34:
		if i % 2 == 0 and p.stomp_state != "":
			await shot("%s%02d_%s" % ["g" if gold else "", i, p.stomp_state])
		await frames(1)
		if i == 2:
			p.touch["stomp"] = false
	release()
