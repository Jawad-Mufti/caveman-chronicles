extends Node
## Test harness (not shipped): physics time second by second from level start.
var level: Node
var drop := ""
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("drop="):
			drop = a.split("=")[1]
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func _run() -> void:
	await get_tree().process_frame
	if drop != "":
		for c in level.get_children():
			if (drop == "wolves" and c is NightBeasts.Wolf) or (drop == "critters" and c is Critter) \
					or (drop == "monkeys" and (c is NightBeasts.Monkey or c is NightBeasts.Elder)) \
					or (drop == "bonfires" and c is NightWoods.Bonfire) or (drop == "caves" and (c is Caves.CaveMouth or c is Caves.CaveExit or c is Caves.Web)):
				c.queue_free()
	var line := "drop %-9s" % (drop if drop != "" else "nothing")
	for sec in 6:
		var t := 0.0
		for i in 60:
			await get_tree().physics_frame
			t += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		line += "  s%d %5.2f" % [sec + 1, t / 60.0]
	print(line)
	get_tree().quit()
