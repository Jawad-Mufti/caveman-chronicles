extends Node
var level: Node
func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func _run() -> void:
	for i in 5: await get_tree().physics_frame
	var p: CaveMan = level.player
	var popped := [0]
	var old: Callable = level._on_treasure_popped
	for kind in ["pot", "log", "mound", "stash"]:
		var box: Node2D = level.get_children().filter(func(c): return c is Treasure.Breakable and c.kind == kind)[0]
		p.global_position = box.global_position + Vector2(-600, -10)
		for i in 5: await get_tree().physics_frame
		var holds: int = box.contents.size()
		var per := []
		for k in {"pot": 1, "log": 2, "mound": 3, "stash": 2}[kind]:
			var n0 := level.get_children().filter(func(c): return c is Treasure.Pickup).size()
			if is_instance_valid(box):
				box.take_hit(3, 1)
			for i in 3: await get_tree().physics_frame
			per.append(level.get_children().filter(func(c): return c is Treasure.Pickup).size() - n0)
		print("%-6s out per hit: %s  (holds %d)" % [kind, per, holds])
	get_tree().quit()
