extends Node
## Test harness (not shipped): draw calls added by fire.
var level: Node
var p: CaveMan
func _ready() -> void:
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	p.talking = false
func calls(n: int) -> float:
	var t := 0.0
	for i in n:
		await get_tree().process_frame
		quiet()
		t += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return t / n
func _run() -> void:
	await get_tree().process_frame
	p = level.player
	quiet()
	p.give_torch()
	p.invuln = 999.0
	p.global_position = Vector2(250, 590)
	for i in 20: await get_tree().process_frame
	var fire_on := await calls(15)
	for c in level.get_children():
		if c is NightWoods.Bonfire:
			c.visible = false
	var fire_off := await calls(15)
	for c in level.get_children():
		if c is NightWoods.Bonfire:
			c.visible = true
	print("the camp bonfire on screen adds %.0f draw calls" % (fire_on - fire_off))
	p.visible = false
	var no_player := await calls(15)
	p.visible = true
	print("the caveman (with his torch) costs %.0f" % (fire_on - no_player))
	p.wood = 2
	p.touch["fire"] = true
	await get_tree().process_frame
	p.touch["fire"] = false
	for i in 38: await get_tree().process_frame
	var burst := await calls(6)
	var fb: Node = null
	for c in level.get_children():
		if c is NightWoods.FireBurst:
			fb = c
	if fb:
		fb.visible = false
	var no_fb := await calls(6)
	if fb and is_instance_valid(fb):
		fb.visible = true
	p.visible = false
	var no_p := await calls(6)
	p.visible = true
	print("during the burst: +%.0f total;  the burst node itself %.0f;  the caveman now %.0f (fury %.2f)" % [burst - fire_on, burst - no_fb, burst - no_p, p.fury])
	get_tree().quit()
