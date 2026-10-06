extends Node
## Test harness (not shipped): frame-time spikes around one-off events.
var level: Node
var p: CaveMan
var times: Array = []
var _last := 0
func _ready() -> void:
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func _process(_d: float) -> void:
	var now := Time.get_ticks_usec()
	if _last > 0:
		times.append((now - _last) / 1000.0)
	_last = now
func window(label: String, frames: int) -> void:
	times.clear()
	for i in frames:
		await get_tree().process_frame
	var s := times.duplicate()
	s.sort()
	print("%-34s median %5.1f ms   worst %6.1f ms" % [label, s[s.size() / 2], s[s.size() - 1]])
func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	p.talking = false
func _run() -> void:
	await get_tree().process_frame
	p = level.player
	await window("level start + opening narration", 60)
	quiet()
	p.give_torch()
	p.invuln = 999.0
	p.global_position = Vector2(1250, 590)
	await window("walking the woods", 60)
	p.wood = 2
	p.touch["fire"] = true
	await get_tree().process_frame
	p.touch["fire"] = false
	await window("first fire burst", 90)
	p.wood = 2
	p.touch["fire"] = true
	await get_tree().process_frame
	p.touch["fire"] = false
	await window("second fire burst", 90)
	p.global_position = Vector2(22930, 590)
	await window("cave door hint (first dialogue box)", 60)
	quiet()
	level._enter_cave(0)
	await window("going into the Weeping Cave", 60)
	p.global_position = Vector2(24010, 32)
	for m in level.get_children():
		if m is NightBeasts.Monkey:
			m.bother()
	await window("the troop shrieking and throwing", 180)
	get_tree().quit()
