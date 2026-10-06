extends Node
## Test harness (not shipped): the economy, the shop, figs, and saving.
var level: Node
var p: CaveMan
var phase := 1
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("phase="):
			phase = int(a.split("=")[1])
	if phase == 1:
		GameState.reset()
		GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
func _run() -> void:
	await frames(5)
	p = level.player
	for c in level.get_children():
		if c is Dialogue: c.queue_free()
	p.talking = false
	if phase == 2:
		print("after restart: weapon %s (axe in hand %s), costume %s, figs %d, shells %d, max hearts %d" % [GameState.weapon, p.axe, p.skin, GameState.figs, GameState.shells, p.max_hp])
		get_tree().quit()
		return
	var total: int = level._treasure_total
	print("treasure in the level: %d shells' worth" % total)
	var prices := {}
	for id in ["axe", "wolf_hood", "ember_paint", "bear_cloak", "firekeeper", "fig", "heart", "torch", "pouch"]:
		prices[id] = level.price_of(id)
	print("prices: %s" % prices)
	var kit_lo: int = prices["axe"] + prices["wolf_hood"] + 3 * prices["fig"]
	var kit_hi: int = prices["axe"] + prices["bear_cloak"] + 3 * prices["fig"]
	print("the kit (axe + a costume + 3 figs): %d..%d = %d%%..%d%% of the level" % [kit_lo, kit_hi, 100 * kit_lo / total, 100 * kit_hi / total])
	var everything: int = kit_hi + prices["wolf_hood"] + prices["ember_paint"] + prices["firekeeper"] + prices["heart"] + int(prices["heart"] * 1.5) + prices["torch"] + prices["pouch"]
	print("buying everything costs %d = %d%% of one visit's treasure" % [everything, 100 * everything / total])
	# a player who found 60%: can they buy the kit?
	GameState.shells = int(total * 0.6)
	var shop := Shop.new()
	shop.player = p
	shop.list_items = level._shop_items
	shop.buy = level._shop_buy
	level.add_child(shop)
	await frames(3)
	shop._age = 1.0
	print("with 60%% (%d shells):" % GameState.shells)
	for id in ["axe", "ember_paint", "fig", "fig", "fig"]:
		print("  buy %-12s -> %s   (left %d)" % [id, level._shop_buy(id), GameState.shells])
	var tabs := {}
	for w in level._shop_items():
		tabs[w["tab"]] = tabs.get(w["tab"], 0) + 1
	print("shop tabs: %s" % tabs)
	print("switch back to the club: %s -> axe in hand %s" % [level._shop_buy("club"), p.axe])
	print("carry the axe again: %s -> axe in hand %s" % [level._shop_buy("axe"), p.axe])
	shop._close()
	await frames(3)
	# eat a fig
	p.hp = 2
	var ate := p.eat_fig()
	print("ate a fig: %s, hearts 2 -> %d, figs left %d, HUD shows %d" % [ate, p.hp, GameState.figs, level.hud.figs])
	get_tree().quit()
