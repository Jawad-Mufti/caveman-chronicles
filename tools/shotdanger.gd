extends Node
## Test harness (not shipped): screenshots of the new dangers at their big
## moment — a geyser blowing, the snapper's jaws up, a hoard with its guards
## taking aim, the bats screeching and swooping. PNGs to C:/tmp/shots/danger_*.
## args: optional "nodark"
var level: Node
var p: CaveMan

func _ready() -> void:
	GameState.reset()
	GameState.seen["level2"] = true
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()

func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	p.talking = false

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/tmp/shots/danger_%s.png" % name)
	print("shot ", name)

## Puts him at `at`, then waits (up to 12 s) until `ready` says so, and shoots.
func moment(name: String, at: Vector2, ready: Callable, hold := true) -> void:
	level._move_player(at, 1)
	for i in 720:
		await get_tree().physics_frame
		quiet()
		p.torch_fuel = 1.0
		p.hp = 5
		if hold and p.is_on_floor():
			p.global_position.x = at.x
		if i > 20 and ready.call():
			break
	await shot(name)

func first(cls) -> Node:
	for c in level.get_children():
		if is_instance_of(c, cls):
			return c
	return null

func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.give_torch()
	p.invuln = 99999.0
	if OS.get_cmdline_user_args().has("nodark"):
		level.night.table = [[0.0, 0.0]]
	for c in level.get_children():
		if c is Critter and not c is OldScar:
			c.queue_free()
	var geysers := level.get_children().filter(func(c): return c is TarPits.Geyser)
	var g1: TarPits.Geyser = geysers[1]
	await moment("rumble", Vector2(16900, 590), func(): return g1.state == "rumble" and fmod(g1._t, g1.cycle()) > g1.quiet + 0.6)
	await moment("geyser", Vector2(16900, 590), func(): return g1.state == "blast" and g1.jet_top() < 400.0)
	var sn: TarPits.Snapper = first(TarPits.Snapper)
	# hold him up on a log in its pool, so it comes for him
	await moment("snapper_eyes", Vector2(17060, 580), func(): return sn.state == "lurk" and absf(sn.position.x - 17060.0) < 80.0)
	await moment("snapper", Vector2(17180, 580), func(): return sn.state == "snap" and sn.jaw_up() >= 1.0)
	var hs := level.get_children().filter(func(c): return c is Hoards.Hoard)
	for h in hs:
		var hd: Hoards.Hoard = h
		var land: Vector2 = hd.box.land
		await moment("hoard_" + hd.box.id, land + Vector2(-140, -10), func():
			for f in hd.flies:
				if is_instance_valid(f) and f.state == "aim" and f._st > 0.35:
					return true
			return false)
	# the bats: onto the second floating rock, then wait for a screech and a swoop
	var rocks := level.get_children().filter(func(c): return c is Canyon.FloatRock)
	var r2: Canyon.FloatRock = rocks[2]
	var on := r2.global_position + Vector2(r2.w * 0.5, -10)
	await moment("bat_screech", on, func():
		for c in level.get_children():
			if c is Canyon.DiveBat and c.state == "warn" and c._st > 0.5:
				return true
		return false)
	await moment("bat_swoop", on, func():
		for c in level.get_children():
			if c is Canyon.DiveBat and c.state == "swoop" and c._st > 0.12:
				return true
		return false)
	get_tree().quit()
