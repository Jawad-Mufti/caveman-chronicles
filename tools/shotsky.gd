extends Node
## Test harness (not shipped): the flying stones up close (canyon Sky Stones, Float
## Rocks, a sky-lane island). PNGs to C:/tmp/shots/sky_*. Run with rendering.
var level: Node
var p: CaveMan
var at := Vector2.ZERO

func _ready() -> void:
	process_priority = 100
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func _process(_d: float) -> void:
	if p != null:
		level.cam.zoom = Vector2(1.8, 1.8)
		level.cam.limit_top = -100000
		level.cam.position_smoothing_enabled = false
		level.cam.global_position = at

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		for c in level.get_children():
			if c is Dialogue:
				c.queue_free()
		p.talking = false
		p.torch_fuel = 1.0
		p.invuln = 0.5

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/sky_%s.png" % name)
	print("shot ", name)

func _run() -> void:
	p = level.player
	await frames(5)
	p.give_torch()
	level.hud.visible = false
	for spot in [["stones", Vector2(18900, 300)], ["rocks", Vector2(20900, 430)], ["island", Vector2(1150, 220)]]:
		at = spot[1]
		level._move_player(at + Vector2(0, 300), 1)
		await frames(30)
		await shot(spot[0])
	get_tree().quit()
