extends Node
## Test harness (not shipped): the REAL frame time at chosen spots, surface and
## underground (run with rendering and --disable-vsync; add --resolution
## 1920x1080 to see what a big window costs). For each spot: average and worst
## frame, the scripts' share (process + physics), draw calls, lights and glows
## on screen.  args: names from SPOTS (default all), dig (hold DOWN + HIT there)
const SPOTS := {
	"start": Vector2(400, 590), "woods": Vector2(3000, 590), "mountain": Vector2(6200, 280),
	"mtdeep": Vector2(7000, 640), "steppe": Vector2(12150, 600), "herd": Vector2(13300, 590), "dig": Vector2(15020, 640),
	"hollows": Vector2(15550, 2100), "graveyard": Vector2(15400, 590), "canyon": Vector2(21000, 590),
	"cave": Vector2(36240, 700), "end": Vector2(33000, 590),
}
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
		await get_tree().process_frame
		for c in level.get_children():
			if c is Dialogue or c is ItemGet:
				c.queue_free()
		p.talking = false
		p.invuln = 1.0
		p.hp = p.max_hp

func _run() -> void:
	var args := OS.get_cmdline_user_args()   # (spotcost predates harness.gd)
	var digging := args.has("dig")
	var names: Array = []
	for a in args:
		if SPOTS.has(a):
			names.append(a)
	if names.is_empty():
		names = SPOTS.keys()
	p = level.player
	await frames(5)
	p.give_torch()
	if args.has("viewport"):           # A/B: draw at 1280x720 and scale up, instead of at the window size
		get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	print("window %s, mode %d" % [get_window().size, get_tree().root.content_scale_mode])
	for n in names:
		level._move_player(SPOTS[n], 1)
		await frames(90)
		if args.has("nohaze"):          # A/B: the fires' heat shimmer (a screen-texture read) off
			for b in get_tree().get_nodes_in_group("light"):
				if "_haze" in b and b._haze != null:
					b._haze.material = null
					b._haze.color = Color(0, 0, 0, 0)
		if digging:
			p.touch["down"] = true
			p.touch["attack"] = true
		var sum := 0.0
		var worst := 0.0
		var scripts := 0.0
		var calls := 0.0
		var count := 180
		for i in count:
			var t0 := Time.get_ticks_usec()
			await frames(1)
			var dt := (Time.get_ticks_usec() - t0) / 1000.0
			sum += dt
			worst = maxf(worst, dt)
			scripts += (Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
			calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		p.touch["down"] = false
		p.touch["attack"] = false
		var lights := 0
		for l in get_tree().get_nodes_in_group("light"):
			if l is Node2D and LevelBase.near_view(l as Node2D, 0.0):
				lights += 1
		var glows := 0
		for g in get_tree().get_nodes_in_group("glow"):
			if g is Node2D and LevelBase.near_view(g as Node2D, 0.0):
				glows += 1
		print("%-10s avg %5.1f ms  worst %5.1f  scripts %5.1f  draw calls %4d  lights %2d  glows %3d  nodes %d" % [n, sum / count, worst, scripts / count, int(calls / count), lights, glows, level.get_child_count()])
	get_tree().quit()
