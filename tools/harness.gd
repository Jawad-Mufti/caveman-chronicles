extends Node
## The base of a test harness (not shipped). A test starts with
##   extends "res://tools/harness.gd"
## and overrides run(): Level 2 is built fresh (a clean save, the guide seen),
## he is `p`, and the usual helpers are here. One PASS/FAIL line per check(),
## and a summary line at the end. Args after `--` are in `args`; `shots` turns
## shot() on (run with rendering): PNGs to C:/tmp/shots/<shot_prefix>_<name>.png.
var level: Node
var p: CaveMan
var args := PackedStringArray()
var shots := false
var shot_prefix := "test"
var checks := 0
var fails := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS       # (shot() pauses the game)
	args = OS.get_cmdline_user_args()
	shots = args.has("shots")
	GameState.reset()
	GameState.seen["level2"] = true
	level = load(level_path()).instantiate()
	add_child(level)
	_go.call_deferred()


## Override for another level.
func level_path() -> String:
	return "res://level2/level2.tscn"


## Override: the test itself.
func run() -> void:
	pass


func _go() -> void:
	p = level.player
	await frames(5)
	await run()
	print("%s: %d checks, %d failed" % [name, checks, fails])
	get_tree().quit()


## Physics frames, with any dialogue or item card swept away so he can move.
func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		quiet()


func quiet() -> void:
	for c in level.get_children():
		if is_instance_valid(c) and (c is Dialogue or c is ItemGet):
			c.queue_free()
	if p != null:
		p.talking = false


## Every touch control let go.
func release() -> void:
	for k in p.touch.keys():
		p.touch[k] = false


## Him, set down at a spot, still and well.
func put(at: Vector2, facing: int = 1) -> void:
	release()
	level._move_player(at, facing)
	p.velocity = Vector2.ZERO
	p.hp = p.max_hp
	await frames(6)


## A scenario runs if no names were given, or it was named.
func wants(scenario: String) -> bool:
	var named := false
	for a in args:
		if a != "shots" and not a.contains("="):
			named = true
	return not named or args.has(scenario)


func check(label: String, ok: bool, info: String = "") -> void:
	checks += 1
	if not ok:
		fails += 1
	print("%s %s  %s" % ["PASS" if ok else "FAIL", label, info])


## A screenshot of this very frame (the game held still while it is taken).
func shot(label: String) -> void:
	if not shots:
		return
	get_tree().paused = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/%s_%s.png" % [shot_prefix, label])
	get_tree().paused = false
