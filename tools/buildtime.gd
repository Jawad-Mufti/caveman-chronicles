extends Node
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	var t0 := Time.get_ticks_usec()
	var packed: PackedScene = load("res://level2/level2.tscn")
	var t1 := Time.get_ticks_usec()
	var level: Node = packed.instantiate()
	var t2 := Time.get_ticks_usec()
	add_child(level)
	var t3 := Time.get_ticks_usec()
	await get_tree().process_frame
	var t4 := Time.get_ticks_usec()
	await get_tree().process_frame
	var t5 := Time.get_ticks_usec()
	print("load %.0f ms, instance %.0f ms, build (_ready) %.0f ms, first frame %.0f ms, second frame %.0f ms" % [
		(t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0, (t4 - t3) / 1000.0, (t5 - t4) / 1000.0])
	# which parts of the build are slow?
	get_tree().quit()
