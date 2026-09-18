extends Node2D
## Level 1: Raw stone age. A cave, a rock, some things that bite, and Tuskar.
## Everything is built in code so the project runs with no art assets.

const GROUND_Y := 600.0
const LEVEL_W := 5800.0
const ARENA_L := 4520.0
const ARENA_R := 5540.0

const TRAP_ZONES := [[2900.0, 320.0], [3800.0, 320.0]]

## Ledge heights are capped so every one is actually reachable.
## Max jump height at the current player values is ~136 px above the floor.
const LEDGES := [
	[700.0, 480.0, 160.0],
	[1900.0, 480.0, 180.0],
	[2180.0, 400.0, 120.0],   # only reachable from the ledge before it
	[3500.0, 480.0, 200.0],
]

const STAMPEDE_PLATFORMS := [[4020.0, 490.0, 120.0], [4200.0, 440.0, 110.0], [4380.0, 480.0, 120.0]]

const FLYTRAPS := [1150.0, 2350.0, 3060.0, 3760.0]
const BERRIES := [900.0, 2500.0, 3900.0]
const STAMPEDE_X := 3900.0

var player: CaveMan
var cam: Camera2D
var hud: Hud
var boar: Bestiary.Boar
var last_safe := Vector2(140, GROUND_Y)
var finished := false


func _ready() -> void:
	_build_background()
	_build_world()
	_build_player()
	_build_critters()
	_build_hud()
	hud.say("A and D to move. Space to jump. J to hit. Drop on small things to crush them.", 6.0)


func _build_background() -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -120
	add_child(sky_layer)
	sky_layer.add_child(World.SkyFill.new())

	var pb := ParallaxBackground.new()
	pb.layer = -100
	add_child(pb)
	for cfg in [[0.25, 0], [0.55, 1]]:
		var pl := ParallaxLayer.new()
		pl.motion_scale = Vector2(cfg[0], 1.0)
		pl.motion_mirroring = Vector2(2560, 0)
		pb.add_child(pl)
		var wall := World.CaveWall.new()
		wall.variant = cfg[1]
		pl.add_child(wall)


func _build_world() -> void:
	var ceiling := World.Ceiling.new()
	ceiling.width = LEVEL_W
	ceiling.trap_zones = TRAP_ZONES
	add_child(ceiling)

	# floor segments with two gaps to jump
	for seg in [[0.0, 1350.0], [1520.0, 2650.0], [2820.0, LEVEL_W]]:
		add_child(World.Slab.new(Rect2(seg[0], GROUND_Y, seg[1] - seg[0], 240)))

	# ledges
	for l in LEDGES:
		add_child(World.Slab.new(Rect2(l[0], l[1], l[2], 22)))

	for s in STAMPEDE_PLATFORMS:
		add_child(World.Slab.new(Rect2(s[0], s[1], s[2], 22)))

	# cave walls at both ends
	add_child(World.Slab.new(Rect2(-80, -200, 80, 1000)))
	add_child(World.Slab.new(Rect2(ARENA_R + 20, -200, 300, 1000)))

	var rock := World.RockPickup.new()
	rock.position = Vector2(520, GROUND_Y)
	rock.taken.connect(func() -> void:
		hud.say("A rock. It hits three times harder than a fist.", 4.0)
	)
	add_child(rock)

	# Tuskar, grazing far off. The boss exists long before the fight.
	var far_boar := World.DistantBoar.new()
	far_boar.position = Vector2(1320, GROUND_Y - 150)
	add_child(far_boar)

	for bx in BERRIES:
		var bush := World.BerryBush.new()
		bush.position = Vector2(bx, GROUND_Y)
		bush.taken.connect(func() -> void:
			hud.say("Berries. Press E to crush them into a poultice.", 4.0)
		)
		add_child(bush)


func _build_player() -> void:
	player = CaveMan.new()
	player.position = Vector2(140, GROUND_Y)
	add_child(player)
	player.hp_changed.connect(func(v: int) -> void: hud.set_hp(v))
	player.berries_changed.connect(func(v: int) -> void: hud.set_berries(v))
	player.poultice.connect(func(_ok: bool, note: String) -> void: hud.say(note, 2.0))
	player.died.connect(func() -> void: hud.say("He did not make it. Press R.", 999.0))

	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_right = int(LEVEL_W)
	cam.limit_top = 0
	cam.limit_bottom = 720
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	add_child(cam)
	cam.make_current()


func _build_critters() -> void:
	for p in [Vector2(950, 470), Vector2(2020, 450), Vector2(3320, 470), Vector2(4300, 430)]:
		var bug := Bestiary.Insect.new()
		bug.position = p
		add_child(bug)

	for l in [[1650.0, 2420.0, 1800.0], [3000.0, 3650.0, 3100.0], [3900.0, 4400.0, 4000.0]]:
		var liz := Bestiary.Lizard.new()
		liz.left_x = l[0]
		liz.right_x = l[1]
		liz.position = Vector2(l[2], GROUND_Y)
		add_child(liz)

	# deadly plants, rooted to the floor
	for fx in FLYTRAPS:
		var trap := Bestiary.Flytrap.new()
		trap.position = Vector2(fx, GROUND_Y)
		add_child(trap)

	for z in TRAP_ZONES:
		var trig := World.Trigger.new(Rect2(z[0], 100, z[1], 500))
		trig.tripped.connect(_drop_stones.bind(z[0], z[1]))
		add_child(trig)

	# Tuskar sighting line, as he passes the distant silhouette
	var sight := World.Trigger.new(Rect2(1180, 100, 60, 520))
	sight.tripped.connect(func() -> void:
		hud.say("Something big is grazing out there.", 3.0)
	)
	add_child(sight)

	# the stampede
	var stamp := World.Trigger.new(Rect2(STAMPEDE_X, 100, 60, 520))
	stamp.tripped.connect(_stampede)
	add_child(stamp)

	boar = Bestiary.Boar.new()
	boar.position = Vector2(5200, GROUND_Y)
	boar.arena_l = ARENA_L
	boar.arena_r = ARENA_R
	boar.defeated.connect(_on_boar_down)
	add_child(boar)

	var arena := World.Trigger.new(Rect2(ARENA_L + 120, 100, 200, 500))
	arena.tripped.connect(_on_arena_enter)
	add_child(arena)


func _build_hud() -> void:
	hud = Hud.new()
	add_child(hud)
	if DisplayServer.is_touchscreen_available():
		hud.add_touch_controls(player)


func _drop_stones(x0: float, width: float) -> void:
	hud.say("The ceiling is loose here.", 2.5)
	for i in 7:
		var s := Bestiary.Stone.new()
		s.position = Vector2(randf_range(x0 + 20.0, x0 + width - 20.0), 80.0)
		s.floor_y = GROUND_Y - 14.0
		add_child(s)
		await get_tree().create_timer(0.32).timeout


## The signature moment: a herd bolts through and the floor stops being safe.
func _stampede() -> void:
	hud.say("The ground is shaking. Get up high.", 3.5)
	for i in 9:
		var r := Bestiary.Runner.new()
		r.dir = -1
		r.despawn_x = 3400.0
		r.speed = randf_range(390.0, 470.0)
		r.position = Vector2(5400.0 + i * randf_range(90.0, 190.0), GROUND_Y)
		add_child(r)
		await get_tree().create_timer(0.18).timeout


func _on_arena_enter() -> void:
	# the gate closes behind him, the boar opens its eyes
	add_child(World.Slab.new(Rect2(ARENA_L - 40, 60, 40, 540)))
	boar.wake()
	hud.say("Tuskar heard you.", 2.5)


func _on_boar_down() -> void:
	hud.set_boss(-1.0)
	hud.say("Tuskar is down. Walk on.", 4.0)
	var exit := World.Exit.new()
	exit.position = Vector2(ARENA_R - 30, GROUND_Y)
	exit.reached.connect(func() -> void:
		if finished:
			return
		finished = true
		player.set_physics_process(false)
		hud.say("Level 1 complete. Next: fire.", 999.0)
	)
	add_child(exit)


func _process(_delta: float) -> void:
	cam.global_position = player.global_position + Vector2(0, -150)

	if player.is_on_floor() and not player.dead:
		last_safe = player.global_position
	if player.global_position.y > 960 and not player.dead:
		player.global_position = last_safe + Vector2(-30.0 * player.facing, -4.0)
		player.velocity = Vector2.ZERO
		player.hurt(1, last_safe.x + 60.0 * player.facing)

	if boar != null and is_instance_valid(boar) and boar.state != "sleep" and boar.hp > 0:
		hud.set_boss(float(boar.hp) / float(boar.max_hp))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_R:
			get_tree().reload_current_scene()
