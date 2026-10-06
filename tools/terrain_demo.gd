extends Node
## Test harness (not shipped): a sample Terrain far off in Level 2 — looks (with
## rendering, PNGs to C:/tmp/shots/terrain_*) and a walk over it (headless).
var level: Node
var p: CaveMan
var t: Terrain
const MAP := [
	"                                                            ",
	"                       ####                                 ",
	"                    ##########                              ",
	"                  ##############       ##                   ",
	"               ####################  ######                 ",
	"            ##########......###########d#####               ",
	"          ##########.........#####ddddddd######             ",
	"        ###########....##.....###dddddd##########           ",
	"      ############....####......#ddddd###############       ",
	"    #############....######.......dd####################    ",
	"  ##############....########.........#######......#######   ",
	"#################...##########...........ooo.........#######",
	"################...################.....oooo...ooo...#######",
	"===============...=================......o.......oo=========",
	"==============...===================..............==========",
	"=============....===========================================",
	"============================================================",
	"============================================================",
]

func _ready() -> void:
	process_priority = 100
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

var zoom := 0.6
func _process(_d: float) -> void:
	if p != null and OS.get_cmdline_user_args().has("shots"):
		level.cam.zoom = Vector2(zoom, zoom)
		level.cam.limit_bottom = 100000
		level.cam.limit_top = -100000
		level.cam.limit_right = 1000000
		level.cam.position_smoothing_enabled = false
		level.cam.global_position = cam_at

var cam_at := Vector2.ZERO

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		p.torch_fuel = 1.0
		for c in level.get_children():
			if c is Dialogue:
				c.queue_free()
		p.talking = false
		p.invuln = 0.5

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/terrain_%s.png" % name)
	print("shot ", name)

func _run() -> void:
	p = level.player
	await frames(3)
	p.give_torch()
	var t0 := Time.get_ticks_usec()
	t = Terrain.new()
	t.map = MAP
	t.position = Vector2(23800, -3000)
	level.add_child(t)
	print("built in %.1f ms, edges %d" % [(Time.get_ticks_usec() - t0) / 1000.0, t.edge_count()])
	var gy: float = t.ground_y(23800 + 4 * 40.0, -3200)
	print("ground at col 4: ", gy)
	level._move_player(Vector2(23800 + 1 * 40.0, gy - 4.0), 1)
	await frames(10)
	var y0 := p.global_position.y
	p.touch["right"] = true
	var max_x := 0.0
	var stuck := 0
	var last_x := p.global_position.x
	for i in 400:
		await frames(1)
		if p.is_on_floor() and absf(p.global_position.x - last_x) < 0.5:
			stuck += 1
			p.touch["jump"] = true
		else:
			p.touch["jump"] = false
		last_x = p.global_position.x
		max_x = maxf(max_x, p.global_position.x)
		if i % 40 == 0:
			print("  x %.0f y %.0f floor %s" % [p.global_position.x, p.global_position.y, p.is_on_floor()])
	print("walked to x %.0f (from %.0f), start y %.0f, frames stuck %d" % [max_x, 23840.0, y0, stuck])
	if OS.get_cmdline_user_args().has("shots"):
		p.touch["right"] = false
		cam_at = Vector2(23800 + 30 * 40.0, -3000 + 8 * 40.0)
		await frames(5)
		await shot("wide")
		zoom = 1.6
		cam_at = Vector2(23800 + 12 * 40.0, -3000 + 7 * 40.0)
		level._move_player(Vector2(23800 + 22 * 40.0, t.ground_y(23800 + 22 * 40.0, -3000 + 6 * 40.0) - 2.0), 1)
		await frames(20)
		await shot("tunnel")
	get_tree().quit()
