extends Node
## Test harness (not shipped): how long does building each picture take?
var level: Node
func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func cost(n: Node, runs: int) -> float:
	var t0 := Time.get_ticks_usec()
	for i in runs:
		n._bb = Batch.new()
		n._paint()
		n._bb = null
	return float(Time.get_ticks_usec() - t0) / runs
func _run() -> void:
	for i in 10: await get_tree().process_frame
	var p: CaveMan = level.player
	p.give_torch()
	var wolf: Node = level.get_children().filter(func(c): return c is NightBeasts.Wolf)[0]
	var bat: Node = level.get_children().filter(func(c): return c is NightBeasts.Bat)[0]
	print("caveman: %.0f us per picture" % cost(p, 200))
	print("wolf:    %.0f us per picture" % cost(wolf, 200))
	print("bat:     %.0f us per picture" % cost(bat, 200))
	var b := Batch.new()
	var t0 := Time.get_ticks_usec()
	for i in 2000:
		b.circle(Vector2(10, 10), 8.0, Color.RED, 14)
	print("one circle: %.1f us" % (float(Time.get_ticks_usec() - t0) / 2000.0))
	t0 = Time.get_ticks_usec()
	for i in 2000:
		b.line(Vector2(10, 10), Vector2(40, 30), Color.RED, 3.0)
	print("one line:   %.1f us" % (float(Time.get_ticks_usec() - t0) / 2000.0))
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(20, -4), Vector2(30, 10), Vector2(18, 24), Vector2(2, 20)])
	t0 = Time.get_ticks_usec()
	for i in 2000:
		b.poly(pts, Color.RED)
	print("one poly:   %.1f us" % (float(Time.get_ticks_usec() - t0) / 2000.0))
	get_tree().quit()
