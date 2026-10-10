extends Node3D
## Test (headless): the 3D Ugu's FACE (shelter/ugu3d.gd): his feelings follow
## what he does, the dials get there, he blinks, his eyes move, his jaw drops.
##   <godot> --headless --fixed-fps 60 --path . res://tools/ugu3dface.tscn
const UguModel := preload("res://shelter/ugu3d.gd")

var u: Node3D
var fails := 0


func _ready() -> void:
	u = UguModel.new()
	add_child(u)
	_run.call_deferred()


func check(ok: bool, label: String, info := "") -> void:
	print("%s %s  %s" % ["PASS" if ok else "FAIL", label, info])
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func dial(k: String) -> float:
	return float(u.get("_dial")[k])


func _run() -> void:
	await frames(60)
	check(u.face_mood == "smile", "at rest: his open smile", u.face_mood)
	check(absf(dial("open") - 0.42) < 0.08 and absf(dial("smile") - 0.6) < 0.05, "the dials get there", "open %.2f smile %.2f" % [dial("open"), dial("smile")])
	u.emote("sad", 1.0)
	await frames(45)
	check(u.face_mood == "sad" and dial("smile") < -0.7 and dial("knit") < -0.8, "emote: sad (a frown, worried brows)", "smile %.2f knit %.2f" % [dial("smile"), dial("knit")])
	await frames(60)
	check(u.face_mood != "sad", "an emote passes", u.face_mood)
	u.landed(1.0)
	await frames(10)
	check(u.face_mood == "wince", "a hard landing: a wince", u.face_mood)
	await frames(60)
	u.cheer(1.5)
	var lo := 9.0
	var hi := 0.0
	for i in 40:
		await frames(1)
		lo = minf(lo, dial("open"))
		hi = maxf(hi, dial("open"))
	check(u.face_mood == "laugh" and hi - lo > 0.15, "cheer: he laughs (ha! ha!)", "open %.2f .. %.2f" % [lo, hi])
	await frames(90)
	# a fall: "ooh", then fright
	u.air = true
	var moods := {}
	for i in 90:
		u.position.y -= 6.0 / 60.0
		await frames(1)
		moods[u.face_mood] = true
	check(moods.has("ooh") and moods.has("scared"), "falling: ooh, then scared", str(moods.keys()))
	u.air = false
	u.position = Vector3.ZERO
	await frames(30)
	# blinks, glances
	var lid: ShaderMaterial = u.get("_lids")[0]
	var iris: Node3D = u.get("_irises")[0][0]
	var shut := false
	var p0 := iris.position
	var moved := 0.0
	for i in 400:
		await frames(1)
		shut = shut or float(lid.get_shader_parameter("lid_cut")) < -0.02
		moved = maxf(moved, iris.position.distance_to(p0))
	check(shut, "he blinks")
	check(moved > 0.004, "his eyes look about", "moved %.4f" % moved)
	# looking at something: a cocked brow, the eyes on it
	u.look_at_point = u.global_position + Vector3(2.0, 1.6, 1.0)
	await frames(30)
	check(u.face_mood == "curious" and dial("brow_l") > 0.4, "something to look at: curious", u.face_mood)
	var g: Vector2 = u.get("_gaze")
	check(g.x > 0.2, "his eyes on it", str(g))
	u.look_at_point = Vector3.INF
	# the yawn: the jaw drops
	u.set("_idle", 6.0)
	var jaw := 0.0
	var head: ShaderMaterial = u.get("_m_head")
	for i in 90:
		await frames(1)
		jaw = maxf(jaw, float(head.get_shader_parameter("jaw")))
	check(jaw > 0.4, "a yawn: the jaw drops", "jaw %.2f" % jaw)
	print("faces: %d failed" % fails)
	get_tree().quit()
