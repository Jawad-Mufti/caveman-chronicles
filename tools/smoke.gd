extends Node
## Test harness (not shipped): loads each level, runs 5 s, reports nodes/player/errors-free.
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	for path in ["res://level1/level1.tscn", "res://level2/level2.tscn"]:
		GameState.reset()
		GameState.seen["level1"] = true
		GameState.seen["level2"] = true
		var lv: Node = load(path).instantiate()
		add_child(lv)
		for i in 300: await get_tree().physics_frame
		var p = lv.get("player")
		var n := 0
		for c in lv.get_children(): n += 1
		print("%-26s children %4d  player %s  hp %s" % [path, n, "ok" if p else "MISSING", str(p.hp) if p else "-"])
		lv.queue_free()
		await get_tree().process_frame
	get_tree().quit()
