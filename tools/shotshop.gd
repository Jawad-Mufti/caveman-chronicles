extends Node
## Test harness (not shipped): pictures of the shop and the costumes.
var level: Node
var p: CaveMan
func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % n)
func wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time()
func _run() -> void:
	await get_tree().process_frame
	p = level.player
	for c in level.get_children():
		if c is Dialogue: c.queue_free()
	p.talking = false
	GameState.shells = 290
	GameState.gems["level2"] = "found"
	level.gem_found = true
	p.global_position = Vector2(30960, 590)
	await wait(0.3)
	for c in level.get_children():
		if c is Dialogue: c.queue_free()
	var shop := Shop.new()
	shop.player = p
	shop.list_items = level._shop_items
	shop.buy = level._shop_buy
	level.add_child(shop)
	await wait(0.4)
	shop._sel = 1
	shop._show()
	await wait(0.3)
	await snap("shop_weapons")
	shop._tab = 1
	shop._sel = 3
	shop._rebuild()
	await wait(0.3)
	await snap("shop_costumes")
	shop._tab = 2
	shop._sel = 0
	shop._rebuild()
	await wait(0.3)
	await snap("shop_supplies")
	shop._tab = 1
	for i in [1, 2, 4]:
		shop._sel = i
		shop._rebuild()
		await wait(0.25)
		await snap("shop_c%d" % i)
	get_tree().quit()
