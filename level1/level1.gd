extends LevelBase
## Level 1: Raw stone age. Three stretches that step up in difficulty, then Tuskar.
##   Part 1 (0-3200)     ground work: gaps, ledges, biters, falling stone
##   Part 2 (3200-4750)  a chasm crossed on moving bamboo
##   Part 3 (5200-7600)  a sunken chamber, then springs and high ground
##   Finale (7700+)      the stampede, then the arena
## Everything is built in code so the project runs with no art assets.
## The shared machinery (player, camera, HUD, falls, restart) is in LevelBase.

const GROUND_Y := 600.0
const CHAMBER_Y := 900.0
const LEVEL_W := 9400.0
const ARENA_L := 8400.0
const ARENA_R := 9200.0
const FALL_Y := 1020.0

## floor runs: [x0, x1]. The holes between them are Part 2's chasm and Part 3's pit.
const FLOORS := [
	[0.0, 1350.0], [1520.0, 2650.0], [2820.0, 3200.0], [4750.0, 5200.0], [6450.0, LEVEL_W],
]

const TRAP_ZONES := [[2880.0, 300.0], [6550.0, 320.0]]

## Reachability budget: one jump climbs ~136 px and carries ~205 px.
## Nothing below asks for more than that, so the double jump stays a safety net.
const LEDGES := [
	[700.0, 480.0, 160.0],
	[1900.0, 480.0, 180.0],
	[2180.0, 400.0, 120.0],
	[3500.0, 480.0, 100.0],    # Part 2 resting stones between the bamboo
	[4030.0, 470.0, 100.0],
	[4560.0, 500.0, 100.0],
	[6850.0, 400.0, 120.0],    # Part 3 high ground, reached by spring
	[7060.0, 320.0, 110.0],
	[7270.0, 400.0, 120.0],
	[7040.0, 168.0, 110.0],    # the secret shelf: only the double jump reaches it
]

## [x, y, width, axis_x, axis_y, span, period, phase]
const BAMBOO := [
	[3330.0, 520.0, 110.0, 0.0, 1.0, 60.0, 2.6, 0.00],
	[3680.0, 500.0, 100.0, 1.0, 0.0, 80.0, 3.0, 0.25],
	[3860.0, 540.0, 110.0, 0.0, 1.0, 70.0, 2.2, 0.50],
	[4210.0, 510.0, 100.0, 0.0, 1.0, 60.0, 2.8, 0.15],
	[4390.0, 480.0, 110.0, 1.0, 0.0, 70.0, 2.4, 0.60],
]

## the sunken chamber: descend on these, cross the block, climb out on the spring
const CHAMBER_PLATFORMS := [
	[5240.0, 700.0, 120.0],
	[5420.0, 790.0, 110.0],
	[5760.0, 760.0, 120.0],
	[5980.0, 700.0, 120.0],
]
const CHAMBER_BLOCK := [5620.0, 780.0, 36.0, 120.0]

const SPRINGS := [[6250.0, CHAMBER_Y], [6620.0, GROUND_Y]]
## One hidden gem per level. This one waits late, in Part 3: on a shelf above
## the highest platform, reached only by double-jumping from it. The only place
## in the level that needs the double jump, which gives that move a purpose.
const GEM_AT := Vector2(7095.0, 168.0)
## throwable ammo, spread so he is never dry for long
const ROCK_PILES := [
	[860.0, GROUND_Y], [2200.0, GROUND_Y], [3050.0, GROUND_Y], [4820.0, GROUND_Y],
	[5760.0, 760.0], [6700.0, GROUND_Y], [7500.0, GROUND_Y], [8300.0, 480.0],
]

const STAMPEDE_X := 7700.0
const STAMPEDE_PLATFORMS := [
	[7820.0, 490.0, 120.0], [8000.0, 440.0, 110.0], [8180.0, 480.0, 120.0],
]

## [x, y]
const FLYTRAPS := [
	[1150.0, GROUND_Y], [2350.0, GROUND_Y], [3050.0, GROUND_Y], [4900.0, GROUND_Y],
	[5400.0, CHAMBER_Y], [6050.0, CHAMBER_Y], [6600.0, GROUND_Y], [7350.0, GROUND_Y],
]
const BERRIES := [[900.0, GROUND_Y], [5900.0, CHAMBER_Y], [7060.0, 320.0]]
## Every insect hovers exactly this far above its own ground, so they all sit
## at chest height wherever they are instead of drifting high or low.
const INSECT_HOVER := 54.0
## [x, the ground surface this insect belongs to]
const INSECTS := [
	[950.0, GROUND_Y], [2050.0, GROUND_Y], [3620.0, 560.0],
	[5600.0, CHAMBER_Y], [6700.0, GROUND_Y], [7450.0, GROUND_Y],
]
## [left, right, start_x, y]
const LIZARDS := [
	[400.0, 1300.0, 800.0, GROUND_Y],
	[1650.0, 2600.0, 1800.0, GROUND_Y],
	[2850.0, 3180.0, 2950.0, GROUND_Y],
	[4790.0, 5180.0, 4900.0, GROUND_Y],
	[5680.0, 6350.0, 5800.0, CHAMBER_Y],   # kept clear of the block at 5620
	[6500.0, 7600.0, 6700.0, GROUND_Y],
]

var boar: Bestiary.Boar


func _ready() -> void:
	level_w = LEVEL_W
	fall_y = FALL_Y
	title = "LEVEL 1   RAW STONE AGE"
	_build_background()
	_build_world()
	_build_player(Vector2(140, GROUND_Y))
	_build_critters()
	_build_hud()
	hud.say("A and D to move. Space to jump. J to swing, K to throw. Drop on small things to crush them.", 6.0)


func _build_background() -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -120
	add_child(sky_layer)
	sky_layer.add_child(World.SkyFill.new())

	# A single authored panorama, not tiles: nothing repeats anywhere in the
	# level, and the scenery changes as he travels — tepuis and waterfalls,
	# then bamboo, then the painted caves, then Tuskar's stone circle.
	var pb := ParallaxBackground.new()
	pb.layer = -100
	add_child(pb)

	_band(pb, Vector2(0.05, 0.03), 3200.0, World.Clouds.new())

	var far := World.FarHighlands.new()
	far.seedn = 1
	var far_layer := _pano(pb, far, Vector2(0.10, 0.06))
	for wf in far.waterfalls():
		var fall := World.Waterfall.new()
		fall.position = wf[0]
		fall.height = wf[1]
		far_layer.add_child(fall)

	_band(pb, Vector2(0.08, 0.05), 2400.0, World.Birds.new())

	var canopy := World.CanopyBand.new()
	canopy.seedn = 2
	_pano(pb, canopy, Vector2(0.22, 0.12))

	_band(pb, Vector2(0.14, 0.08), 1800.0, World.LightShafts.new())

	var story := World.StoryBand.new()
	story.seedn = 3
	var story_layer := _pano(pb, story, Vector2(0.40, 0.20))

	# Tuskar, grazing at the edge of the trees long before the arena
	var far_boar := World.DistantBoar.new()
	var bx := story.at(1500.0)
	far_boar.position = Vector2(bx, story.line(bx, 532.0, 22.0))
	story_layer.add_child(far_boar)

	var under := World.Undergrowth.new()
	under.seedn = 4
	_pano(pb, under, Vector2(0.62, 0.34))

	_band(pb, Vector2(0.85, 0.5), 1400.0, World.Motes.new())


func _build_world() -> void:
	var ceiling := World.Ceiling.new()
	ceiling.width = LEVEL_W
	ceiling.trap_zones = TRAP_ZONES
	add_child(ceiling)

	for seg in FLOORS:
		add_child(World.Slab.new(Rect2(seg[0], GROUND_Y, seg[1] - seg[0], 240)))

	# Part 3: the floor of the sunken chamber
	add_child(World.Slab.new(Rect2(5150, CHAMBER_Y, 1250, 220)))

	for l in LEDGES:
		add_child(World.Slab.new(Rect2(l[0], l[1], l[2], 22)))
	for s in STAMPEDE_PLATFORMS:
		add_child(World.Slab.new(Rect2(s[0], s[1], s[2], 22)))
	for c in CHAMBER_PLATFORMS:
		add_child(World.Slab.new(Rect2(c[0], c[1], c[2], 22)))
	add_child(World.Slab.new(Rect2(CHAMBER_BLOCK[0], CHAMBER_BLOCK[1], CHAMBER_BLOCK[2], CHAMBER_BLOCK[3])))

	# cave walls at both ends
	add_child(World.Slab.new(Rect2(-80, -200, 80, 1400)))
	add_child(World.Slab.new(Rect2(ARENA_R + 20, -200, 300, 1400)))

	# Part 2: the bamboo
	for b in BAMBOO:
		var pole := World.Bamboo.new()
		pole.position = Vector2(b[0], b[1])
		pole.size = Vector2(b[2], 18)
		pole.axis = Vector2(b[3], b[4])
		pole.span = b[5]
		pole.period = b[6]
		pole.phase = b[7]
		add_child(pole)

	for sp in SPRINGS:
		var spring := World.SpringBush.new()
		spring.position = Vector2(sp[0], sp[1])
		add_child(spring)

	var stick := World.StickPickup.new()
	stick.position = Vector2(780, 480)
	stick.taken.connect(func() -> void:
		hud.say("A club. Three times the damage of a fist, and far more reach.", 4.5)
	)
	add_child(stick)

	for r in ROCK_PILES:
		var rock := World.RockPickup.new()
		rock.position = Vector2(r[0], r[1])
		rock.taken.connect(func() -> void:
			hud.say("Rocks. Press K to throw one.", 3.5)
		)
		add_child(rock)

	var gem := World.Gem.new()
	gem.position = GEM_AT
	gem.found.connect(func() -> void:
		gem_found = true
		hud.set_gem(true)
		hud.say("A red stone, hidden up here. Nobody was meant to find that.", 4.0)
	)
	add_child(gem)

	for b in BERRIES:
		var bush := World.BerryBush.new()
		bush.position = Vector2(b[0], b[1])
		bush.taken.connect(func() -> void:
			hud.say("Berries. Press E to crush them into a poultice.", 4.0)
		)
		add_child(bush)


func _build_critters() -> void:
	for p in INSECTS:
		var bug := Bestiary.Insect.new()
		bug.ground_y = p[1]
		bug.position = Vector2(p[0], p[1] - INSECT_HOVER)
		add_child(bug)

	for l in LIZARDS:
		var liz := Bestiary.Lizard.new()
		liz.left_x = l[0]
		liz.right_x = l[1]
		liz.position = Vector2(l[2], l[3])
		add_child(liz)

	for f in FLYTRAPS:
		var trap := Bestiary.Flytrap.new()
		trap.position = Vector2(f[0], f[1])
		add_child(trap)

	for z in TRAP_ZONES:
		var trig := World.Trigger.new(Rect2(z[0], 100, z[1], 500))
		trig.tripped.connect(_drop_stones.bind(z[0], z[1]))
		add_child(trig)

	_note(300, "His fists barely reach. Something is up on that ledge.")
	_note(1180, "Something big is grazing out there.")
	_note(3140, "The floor runs out. The bamboo is the only way over.")
	_note(5140, "It goes down before it goes up.")
	_note(6560, "Spring off the sapling to reach the high ground.")

	var stamp := World.Trigger.new(Rect2(STAMPEDE_X, 100, 60, 520))
	stamp.tripped.connect(_stampede)
	add_child(stamp)

	boar = Bestiary.Boar.new()
	boar.position = Vector2(8900, GROUND_Y)
	boar.arena_l = ARENA_L
	boar.arena_r = ARENA_R
	boar.defeated.connect(_on_boar_down)
	boar.enraged_now.connect(func() -> void:
		hud.say("Tuskar is bleeding. He stops charging and starts slamming — jump the wave.", 4.5)
	)
	add_child(boar)

	var arena := World.Trigger.new(Rect2(ARENA_L + 120, 100, 200, 500))
	arena.tripped.connect(_on_arena_enter)
	add_child(arena)


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
	hud.say("The ground is shaking. Get off the floor.", 3.5)
	for i in 9:
		var r := Bestiary.Runner.new()
		r.dir = -1
		r.despawn_x = 7200.0
		r.speed = randf_range(390.0, 470.0)
		r.position = Vector2(9200.0 + i * randf_range(90.0, 190.0), GROUND_Y)
		add_child(r)
		await get_tree().create_timer(0.18).timeout


func _on_arena_enter() -> void:
	# the gate closes behind him, the boar opens its eyes
	add_child(World.Slab.new(Rect2(ARENA_L - 40, 60, 40, 540)))
	boar.wake()
	hud.say("Tuskar heard you. Two charges and he goes down — hit him then.", 4.0)


func _on_boar_down() -> void:
	hud.set_boss(-1.0)
	hud.say("Tuskar is down. Walk on.", 4.0)
	var exit := World.Exit.new()
	exit.position = Vector2(ARENA_R - 30, GROUND_Y)
	exit.reached.connect(_on_exit)
	add_child(exit)


func _on_exit() -> void:
	if finished:
		return
	finished = true
	player.set_physics_process(false)
	hud.say("Level 1 complete. Next: fire." if gem_found else "Level 1 complete — but you missed the hidden gem.", 999.0)
	await get_tree().create_timer(3.5).timeout
	get_tree().change_scene_to_file("res://level2/level2.tscn")


func _process(delta: float) -> void:
	super._process(delta)
	if boar != null and is_instance_valid(boar) and boar.state != "sleep" and boar.hp > 0:
		hud.set_boss(float(boar.hp) / float(boar.max_hp))
