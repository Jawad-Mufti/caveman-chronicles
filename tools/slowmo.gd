extends Node
## Test harness (not shipped): SLOW-MOTION REQUESTS that overlap. A hit-stop
## (0.05 s at 4%) and the death's slow-motion (1.3 s at 30%) together: 4% only
## for the hit-stop, then 30%, then full speed. (It used to be 1.3 s at 4%: a freeze.)
## One PASS/FAIL line each.

func check(name: String, ok: bool, info: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name, info])

func wait_ms(ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await get_tree().process_frame

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await get_tree().process_frame
	Critter.slow_time(get_tree(), 0.05, 0.04)
	Critter.slow_time(get_tree(), 1.3, 0.3)
	await get_tree().process_frame
	var a := Engine.time_scale
	await wait_ms(200)
	var b := Engine.time_scale
	await wait_ms(1300)
	var c := Engine.time_scale
	check("hit-stop, then the slow-motion, then normal", is_equal_approx(a, 0.04) and is_equal_approx(b, 0.3) and is_equal_approx(c, 1.0),
		"scale %.2f -> %.2f -> %.2f" % [a, b, c])
	# a hit-stop landing in the middle of a long slow-motion: back to it, not stuck at 4%
	Critter.slow_time(get_tree(), 1.0, 0.3)
	await wait_ms(300)
	Critter.slow_time(get_tree(), 0.05, 0.04)
	await get_tree().process_frame
	var d := Engine.time_scale
	await wait_ms(150)
	var e := Engine.time_scale
	await wait_ms(800)
	check("a hit-stop inside the slow-motion", is_equal_approx(d, 0.04) and is_equal_approx(e, 0.3) and is_equal_approx(Engine.time_scale, 1.0),
		"scale %.2f -> %.2f -> %.2f" % [d, e, Engine.time_scale])
	get_tree().quit()
