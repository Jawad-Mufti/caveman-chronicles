extends Node
## Test harness (not shipped): loads a level, teleports the player, saves screenshots.
var level: Node
var shots: Array = []
var out := "/tmp/shots"

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var path: String = args.get("level", "res://level1/level1.tscn")
	out = args.get("out", out)
	DirAccess.make_dir_recursive_absolute(out)
	level = load(path).instantiate()
	add_child(level)
	for s in String(args.get("xs", "300")).split(","):
		shots.append(s)
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	level.player.talking = false
	for m in (level._mouths if "_mouths" in level else []):
		m._noticed = true
	for s in shots:
		var parts: PackedStringArray = s.split(":")
		var x := float(parts[0])
		var y := float(parts[1]) if parts.size() > 1 else 590.0
		var wait := float(parts[2]) if parts.size() > 2 else 1.2
		var p: Node2D = level.get("player")
		if p.has_method("give_torch") and not p.get("has_torch"):
			p.give_torch()
		p.set("torch_fuel", 1.0)
		p.global_position = Vector2(x, y)
		for c in level.get_children():
			if c is Dialogue:
				c.queue_free()
		p.set("talking", false)
		p.set("velocity", Vector2.ZERO)
		await get_tree().create_timer(wait).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/shot_%s.png" % [out, parts[0]])
		print("saved ", parts[0])
	get_tree().quit()
