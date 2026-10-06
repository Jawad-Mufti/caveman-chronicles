extends Node
## Test harness (not shipped): what does the glow layer cost at a spot? Times
## each glowing thing's draw_glow into a Batch and counts its triangles.
## args: x (default 32900)
var level: Node

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func _run() -> void:
	var x := 32900.0
	for a in OS.get_cmdline_user_args():
		if a.is_valid_float():
			x = float(a)
	for i in 5:
		await get_tree().process_frame
	var p: CaveMan = level.player
	p.global_position = Vector2(x, 590)
	for i in 20:
		await get_tree().process_frame
	var rows := []
	var total := 0.0
	var tris := 0
	var n_all := 0
	for n in get_tree().get_nodes_in_group("glow"):
		var n2 := n as Node2D
		if n2 == null or absf(n2.global_position.x - x) > 900.0:
			continue
		n_all += 1
		var b := Batch.new()
		var t0 := Time.get_ticks_usec()
		for k in 20:
			b = Batch.new()
			n2.draw_glow(b)
		var us := (Time.get_ticks_usec() - t0) / 20.0
		total += us
		tris += b.points.size() / 3
		var s: Script = n2.get_script()
		rows.append([us, b.points.size() / 3, "%s %s" % [s.resource_path.get_file(), n2.name]])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	print("x %.0f: %d glowing things, %.0f us to record, %d triangles" % [x, n_all, total, tris])
	for r in rows.slice(0, 12):
		print("   %7.0f us  %6d tris  %s" % [r[0], r[1], r[2]])
	get_tree().quit()
