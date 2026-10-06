extends Node
## Test harness (not shipped): the talking animals and the answers he can pick.
## Walks into Moss and Nutmeg, answering with the given choice index, then
## brings Old Bongo his key and checks the beaver's stone comes up — and that
## the gem changes hands exactly once whichever answer he gives.
## args: pick=N (which answer to give every time, default 1), "shots" (screenshots
## of the boxes to C:/tmp/shots/talk_*.png; run with rendering)
var level: Node
var p: CaveMan
var pick := 1
var shots := false
var _shot := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("pick="):
			pick = int(a.split("=")[1])
		if a == "shots":
			shots = true
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func snap() -> void:
	if not shots:
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/talk_%02d.png" % _shot)
	_shot += 1

## Plays the dialogue that is up: every line in full, the chosen answer at choices.
func converse() -> Array:
	var said := []
	await frames(3)
	if not level.get_children().any(func(c): return is_instance_valid(c) and c is Dialogue):
		p.touch["talk"] = true
		await frames(2)
		p.touch["talk"] = false
		await frames(3)
	for c in level.get_children():
		if c is Dialogue:
			var d: Dialogue = c
			var guard := 0
			while is_instance_valid(d) and d._i < d.lines.size() and guard < 60:
				guard += 1
				if not d._choices.is_empty():
					var answers := []
					for ch in d._choices:
						answers.append(ch[0])
					said.append("  [choices: %s]" % " / ".join(answers))
					d._sel = mini(pick, d._choices.size() - 1)
					d._mark()
					if _shot < 14:
						await snap()
				else:
					d._shown = 999.0
					said.append("  %s: %s" % [d._name.text if d._tag.visible else "(narration)", d._text.text])
					if _shot < 14 and (d._name.text == "MOSS" or d._name.text == "NUTMEG"):
						await frames(1)
						await snap()
				d._next()
			await frames(2)
	return said

func _run() -> void:
	await frames(5)
	p = level.player
	for c in level.get_children():
		if c is Critter or c is NightBeasts.Monkey:
			c.queue_free()
	for m in level._mouths:
		m._noticed = true
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	p.talking = false
	p.give_torch()
	# Moss, over the gorge
	level._move_player(Vector2(3860, 590), 1)
	await frames(5)
	p.touch["right"] = true
	await frames(18)
	p.touch["right"] = false
	print("== Moss")
	for l in await converse():
		print(l)
	print("Moss asleep: %s" % level.moss.asleep)
	# Nutmeg, on the far bank
	level._move_player(Vector2(17590, 590), 1)
	await frames(5)
	p.touch["right"] = true
	await frames(18)
	p.touch["right"] = false
	print("== Nutmeg")
	for l in await converse():
		print(l)
	print("met Nutmeg: %s, calm %s" % [level._met_nutmeg, level.nutmeg.calm])
	# Old Bongo: first the ask, then the key
	level._move_player(Vector2(23500, -418), 1)
	await frames(20)
	print("== Old Bongo, asked")
	for l in await converse():
		print(l)
	level.has_key = true
	level._near_elder = false
	p.global_position = Vector2(23200, 590)
	await frames(10)
	level._move_player(Vector2(23500, -418), 1)
	await frames(20)
	print("== Old Bongo, the key")
	for l in await converse():
		print(l)
	await frames(30)
	var gems := 0
	for c in level.get_children():
		if c is World.Gem:
			gems += 1
	print("gem found %s, gems lying about %d, quest %s" % [level.gem_found, gems, level.quest])
	get_tree().quit()
