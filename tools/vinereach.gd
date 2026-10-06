extends Node
## Test harness (not shipped): how far does a vine fling him? Hangs him on the
## Gorge's first vine, pumps the swing up, lets go at a given point of the
## forward swing, and follows the flight. A second vine hanging at rest, at the
## same height and length, would catch him wherever his body passes within its
## grab circle (radius 50 round its end); the farthest such spot is the reach.
## Reports the reach for each release angle: just letting go (holding toward
## it), and letting go plus the air jump at the top of the flight.
var level: Node
var p: CaveMan
var vine: Node2D

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## One try: returns [reach x past the vine, release speed].
func fling(release_a: float, air_jump: bool) -> Array:
	p.hp = 50
	p.dead = false
	p.talking = false
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	p.touch["right"] = false
	p.touch["left"] = false
	p.touch["jump"] = false
	if p.vine != null:
		p._let_go(Vector2.ZERO)
	await frames(2)
	p.global_position = vine.global_position + Vector2(0, vine.length + CaveMan.HANG)
	p.velocity = Vector2.ZERO
	await get_tree().physics_frame          # in the air first, or he still counts as standing
	p.global_position = vine.global_position + Vector2(0, vine.length + CaveMan.HANG)
	p._vine_cd = 0.0
	p._last_vine = null
	var ok := p.grab_vine(vine)
	if not ok:
		print("   grab refused: talking %s, on floor %s, dead %s, fury %.1f, vine %s" % [p.talking, p.is_on_floor(), p.dead, p.fury, p.vine])
	# pump: push with the swing, up to full height
	for i in 360:
		p.touch["right"] = p._vine_w >= 0.0
		p.touch["left"] = p._vine_w < 0.0
		await get_tree().physics_frame
	# then wait for the release point on a forward swing, and let go
	var guard := 0
	while guard < 400 and p._vine_w >= 0.0:          # wait for a backswing...
		p.touch["right"] = p._vine_w >= 0.0
		p.touch["left"] = p._vine_w < 0.0
		await get_tree().physics_frame
		guard += 1
	while guard < 800 and p._vine_w <= 0.0:          # ...then the bottom of the next forward swing
		p.touch["right"] = p._vine_w >= 0.0
		p.touch["left"] = p._vine_w < 0.0
		await get_tree().physics_frame
		guard += 1
	while guard < 1200 and not (p._vine_w > 0.0 and p._vine_a >= release_a):
		p.touch["right"] = p._vine_w > 0.0
		p.touch["left"] = p._vine_w < 0.0
		await get_tree().physics_frame
		guard += 1
	var vl: float = vine.length
	var speed: Vector2 = Vector2(cos(p._vine_a), -sin(p._vine_a)) * p._vine_w * vl
	p.touch["left"] = false
	p.touch["right"] = true
	p.touch["jump"] = true
	await get_tree().physics_frame
	p.touch["jump"] = false
	var grip := vine.global_position + Vector2(0, vine.length)
	var reach := -INF
	var jumped := false
	for i in 240:
		await get_tree().physics_frame
		if air_jump and not jumped and p.velocity.y > -40.0:
			p.touch["jump"] = true
			jumped = true
		elif jumped:
			p.touch["jump"] = true
		# his body is a capsule from his feet up 64 px: does it pass within the grab circle of a vine
		# hanging at rest at this x? (the circle is 50 round the vine's end, at grip.y)
		var feet := p.global_position
		var top := feet.y - 51.0
		var bottom := feet.y - 13.0
		var dy := 0.0
		if grip.y < top:
			dy = top - grip.y
		elif grip.y > bottom:
			dy = grip.y - bottom
		if dy < 63.0:
			var dx := sqrt(63.0 * 63.0 - dy * dy)
			reach = maxf(reach, feet.x + dx - vine.global_position.x)
		if feet.y > grip.y + 200.0:
			break
	p.touch["right"] = false
	p.touch["jump"] = false
	return [reach, speed.length()]

func _run() -> void:
	await frames(5)
	p = level.player
	for c in level.get_children():
		if c is Critter or c is Dialogue:
			c.queue_free()
	for c in level.get_children():
		if c is World.Trigger:
			c.queue_free()      # no talks or notes in the way
	p.talking = false
	# a vine of the Gorge's length, hung in empty sky so nothing gets in the way
	var L := 255.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("length="):
			L = float(a.split("=")[1])
	vine = NightWoods.Vine.new()
	vine.length = L
	vine.position = Vector2(2000, -2600)
	level.add_child(vine)
	await frames(2)
	print("vine at x %.0f, length %.0f" % [vine.global_position.x, vine.length])
	for a in [0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 1.2]:
		var plain: Array = await fling(a, false)
		var boosted: Array = await fling(a, true)
		print("let go at %.1f rad: speed %4.0f  reach %4.0f px   with the air jump %4.0f px" % [a, plain[1], plain[0], boosted[0]])
	get_tree().quit()
