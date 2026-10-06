extends Node
## Test harness (not shipped): after a fall into a hole he must be set down
## somewhere firm — one heart lost, standing, and not falling again.
##   lip       - slips off a pit's edge while facing away from it
##   mammoth   - was riding a mammoth's back just before he fell
##   crumble   - was standing on a crumbling stone when it gave way
var level: Node
var p: CaveMan
var runs := 0
var fails := 0

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	p.talking = false

func put(at: Vector2, facing: int) -> void:
	for k in ["left", "right", "jump"]:
		p.touch[k] = false
	p.global_position = at
	p.velocity = Vector2.ZERO
	p.facing = facing
	p.hp = 5
	p.invuln = 0.0
	await frames(8)

## Ground that stays put (the same rule as the level's).
func firm_body(b: Object) -> bool:
	return b is StaticBody2D and not (b as Node).is_in_group("unsafe_ground")

func floor_body() -> Object:
	for i in p.get_slide_collision_count():
		var c := p.get_slide_collision(i)
		if c.get_normal().y < -0.7:
			return c.get_collider()
	return null

## After the fall: wait, then check one heart, standing, on firm ground.
func judge(label: String) -> void:
	var t := 0
	while t < 240 and p.global_position.y <= level.fall_y:
		await get_tree().physics_frame
		t += 1
		quiet()
	await frames(150)
	quiet()
	var firm := p.is_on_floor()
	for i in p.get_slide_collision_count():
		var c := p.get_slide_collision(i)
		if c.get_normal().y < -0.7 and not firm_body(c.get_collider()):
			firm = false
	runs += 1
	var ok := p.hp == 4 and firm
	if not ok:
		fails += 1
	print("%-34s %s  set down at (%.0f, %.0f), hp %d/5, firm %s" % [label, "PASS" if ok else "FAIL", p.global_position.x, p.global_position.y, p.hp, firm])

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	await frames(5)
	p = level.player
	p.give_torch()
	for c in level.get_children():
		if c is Critter or c is NightBeasts.Monkey:
			c.queue_free()
	for m in level._mouths:
		m._noticed = true
	quiet()
	if args.is_empty() or args.has("lip"):
		# teetering at the pit's lip (1500), facing back the way he came, he slips in
		await put(Vector2(1440, 590), 1)
		p.touch["right"] = true
		while p.global_position.x < 1494.0:
			await get_tree().physics_frame
		p.touch["right"] = false
		# he turns to face back... and slips in anyway
		var tt := 0
		while tt < 120 and p.global_position.y < 640.0:
			p.facing = -1
			p.velocity.x = 160.0
			await get_tree().physics_frame
			tt += 1
		await judge("lip: slips off facing away")
	if args.is_empty() or args.has("mammoth"):
		var bull: Steppe.Mammoth = null
		for c in level.get_children():
			if c is Steppe.Mammoth and c.size >= 1.0 and c.global_position.y < 640.0:
				bull = c
		await put(Vector2(bull.x0 - 140.0, 590), 1)        # firm ground first, clear of its feet...
		await frames(10)
		p.global_position = bull.global_position + Vector2(0, -bull.BACK * bull.size - 20.0)
		p.velocity = Vector2.ZERO
		var riding := false
		for i in 90:                       # riding along...
			await get_tree().physics_frame
			if floor_body() is Steppe.Mammoth:
				riding = true
		print("   (was riding the mammoth: %s)" % riding)
		p.global_position.y = level.fall_y + 20.0   # ...and down a hole
		await judge("mammoth: fell after riding a back")
	if args.is_empty() or args.has("crumble"):
		var rock: Node2D = null
		for c in level.get_children():
			if c is NightWoods.CrumbleRock and not (c is CaveTrials.BoneSlab):
				rock = c
				break
		await put(Vector2(rock.global_position.x - 70.0, 590), 1)   # on the bank first
		await frames(10)
		await put(rock.global_position + Vector2(20, -12), 1)
		var t := 0
		while t < 400 and p.global_position.y < level.fall_y:
			await get_tree().physics_frame
			t += 1
			quiet()
		await judge("crumble: the stone gave way")
	if args.is_empty() or args.has("crumble2"):
		# along the stepping stones: from the bank onto the first, on to the
		# second... and both give way under him
		var rocks := []
		for c in level.get_children():
			if c is NightWoods.CrumbleRock and not (c is CaveTrials.BoneSlab):
				rocks.append(c)
		rocks.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
		var r1: Node2D = rocks[0]
		var r2: Node2D = rocks[1]
		await put(Vector2(r1.global_position.x - 70.0, 590), 1)
		await frames(10)
		p.global_position = r1.global_position + Vector2(30, -12)
		await frames(25)
		p.global_position = r2.global_position + Vector2(30, -12)
		p.velocity = Vector2.ZERO
		var t2 := 0
		while t2 < 400 and p.global_position.y < level.fall_y:
			await get_tree().physics_frame
			t2 += 1
			quiet()
		await judge("crumble2: two stones gave way")
	print("%d scenarios, %d failed" % [runs, fails])
	get_tree().quit()
