extends Node
## Test harness (not shipped): the METEOR DASH (in the air, T + left/right) and the
## quicker double-jump flip.
##   open    - jump, T + right: spins, then shoots right, flat, and drops out of it
##   double  - after a double jump: farther (the gold one)
##   left    - T + left goes left
##   wall    - into a plain wall: BOOM, bounced back
##   drill   - into the mountain's rock: drills through it
##   flip    - the double jump's somersault is over in about 0.3 s
##   shots   - (with rendering) the flip and the dash, C:/tmp/shots/dash_*
var level: Node
var p: CaveMan

func _ready() -> void:
	process_priority = 100
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func _process(_d: float) -> void:
	if p != null and OS.get_cmdline_user_args().has("shots"):
		level.cam.zoom = Vector2(1.6, 1.6)
		level.cam.position_smoothing_enabled = false

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		for c in level.get_children():
			if c is Dialogue:
				c.queue_free()
		p.talking = false
		p.torch_fuel = 1.0

func release() -> void:
	for k in p.touch.keys():
		p.touch[k] = false

func put(at: Vector2, face := 1) -> void:
	release()
	level._move_player(at + Vector2(0, -4), face)
	p.velocity = Vector2.ZERO
	p.invuln = 0.5
	p.stomp_state = ""
	await frames(10)

func report(name: String, ok: bool, info: String) -> void:
	print("%-44s %s  %s" % [name, "PASS" if ok else "FAIL", info])

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/dash_%s.png" % name)
	print("shot ", name)

## Jump (twice if asked), then T with a direction held; follow it to its end.
func dash(dir: int, twice: bool) -> Dictionary:
	var x0 := p.global_position.x
	p.touch["jump"] = true
	await frames(8)
	p.touch["jump"] = false
	if twice:
		await frames(4)
		p.touch["jump"] = true
		await frames(6)
		p.touch["jump"] = false
	await frames(2)
	p.touch["right" if dir > 0 else "left"] = true
	p.touch["stomp"] = true
	await frames(2)
	p.touch["stomp"] = false
	var level_used := p.stomp_level
	var dashed := false
	var flat := true
	var y_dash := 0.0
	for i in 120:
		await frames(1)
		if p.stomp_state == "dash":
			if not dashed:
				y_dash = p.global_position.y
			dashed = true
			flat = flat and absf(p.global_position.y - y_dash) < 2.0
		elif dashed and p.stomp_state == "":
			break
	release()
	return {"went": p.global_position.x - x0, "dashed": dashed, "flat": flat, "level": level_used, "y": y_dash}

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	p = level.player
	await frames(5)
	p.give_torch()
	var all := args.is_empty() or (args.size() == 1 and args.has("shots"))
	if all or args.has("open"):
		await put(Vector2(500, 600))
		var r: Dictionary = await dash(1, false)
		report("open: T + right dashes right, flat", r["dashed"] and r["flat"] and r["went"] > 180.0 and r["went"] < 300.0 and r["level"] == 1, str(r))
	if all or args.has("double"):
		await put(Vector2(500, 600))
		var r2: Dictionary = await dash(1, true)
		report("double: the gold dash goes farther", r2["dashed"] and r2["level"] == 2 and r2["went"] > 330.0 and r2["went"] < 480.0, str(r2))
	if all or args.has("left"):
		await put(Vector2(1460, 600), -1)
		var r3: Dictionary = await dash(-1, false)
		report("left: T + left goes left", r3["dashed"] and r3["went"] < -180.0, str(r3))
	if all or args.has("wall"):
		var wall := World.Slab.new(Rect2(760, 300, 60, 300))
		level.add_child(wall)
		await put(Vector2(560, 600))
		var r4: Dictionary = await dash(1, false)
		var blast := false
		for c in level.get_children():
			if c is Stomp.Blast:
				blast = true
		report("wall: a plain wall stops it with a BOOM", r4["dashed"] and blast and p.global_position.x < 760.0, "%s at x %.0f, blast %s" % [str(r4), p.global_position.x, blast])
		wall.queue_free()
	if all or args.has("drill"):
		var t: Terrain = level.mountain
		await put(Vector2(8840, 160))
		var r5: Dictionary = await dash(1, true)
		var ty: float = r5["y"] - 38.0
		var tx := p.global_position.x + 40.0      # the tunnel he drilled, just ahead of where the dash ran out
		var tunnel := t.is_inside(Vector2(tx, ty)) and not t.is_solid(Vector2(tx, ty)) and tx > 9120.0
		report("drill: through the mountain's rock", r5["dashed"] and r5["went"] > 250.0 and tunnel, "%s, drilled tunnel at x %.0f %s" % [str(r5), tx, tunnel])
	if all or args.has("flip"):
		await put(Vector2(500, 600))
		p.touch["jump"] = true
		await frames(8)
		p.touch["jump"] = false
		await frames(3)
		p.touch["jump"] = true
		await frames(1)
		var n := 0
		while p.flip_t > 0.0 and n < 60:
			await frames(1)
			n += 1
		release()
		report("flip: the double-jump somersault is quick", n > 10 and n <= 20, "%d frames (%.2f s)" % [n, n / 60.0])
	if args.has("shots"):
		level.hud.visible = false
		await put(Vector2(500, 600))
		p.touch["jump"] = true
		await frames(8)
		p.touch["jump"] = false
		await frames(3)
		p.touch["jump"] = true
		await frames(7)
		await shot("flip")
		release()
		await frames(40)
		await put(Vector2(500, 600))
		p.touch["jump"] = true
		await frames(8)
		p.touch["jump"] = false
		await frames(4)
		p.touch["jump"] = true
		await frames(6)
		p.touch["jump"] = false
		p.touch["right"] = true
		p.touch["stomp"] = true
		await frames(2)
		p.touch["stomp"] = false
		while p.stomp_state != "dash":
			await frames(1)
		await frames(8)
		await shot("dash")
		release()
	get_tree().quit()
