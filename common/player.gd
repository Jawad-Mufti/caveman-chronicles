class_name CaveMan
extends CharacterBody2D
## The caveman. He never changes across the game, only what he holds.
## Origin is at his feet. Drawn as a flat charcoal silhouette.
##
## Where things are (search for the "## ----" headers):
##   constants + state       movement, jumps, weapons, torch, fury, SUNFIRE, STOMP vars
##   _physics_process        one frame of him: death, timers, fire, hammer charge, walking,
##                           vines, wall-kick, jumps, attack, throw, _update_stomp, move
##   weapons                 swings, _apply_swing (every hit lands here), specials
##   vines                   swinging and letting go
##   hurt / hurt_toss / die   being hit (Sunfire absorbs, the stomp is untouchable)
##   torch                   fuel, light() for Night, wood and fire
##   drawing                 _paint(): the whole rig in design units, one draw call
##   costumes                skins and their extra pieces
##   SUNFIRE                 the 30-second power (effects: common/sunfire.gd)
##   STOMP                   the meteor stomp (effects: common/stomp.gd)

signal hp_changed(hp: int)
signal died
signal rock_picked
signal stick_picked
signal rocks_changed(count: int)
signal berries_changed(count: int)
signal poultice(ok: bool, note: String)
signal wood_changed(count: int)
signal torch_out
signal fire_released
signal said(note: String)

const SPEED := 330.0          ## running on the ground (315 before 2026-10-06; SUNFIRE: x1.55)
const AIR_SPEED := 320.0      ## in the air (335 broke the Glowcap Chasm and the chimney; 330 broke the chasm back across)
## Ramped instead of snapped, so direction changes read as weight rather than teleporting.
const ACCEL := 2600.0
const FRICTION := 2800.0
const AIR_ACCEL := 1700.0
const THROW_SPEED := 640.0
## Bare hands reach barely past his own shoulder. The club roughly doubles the
## area he can threaten, which is the real reason to go and fetch it.
const FIST_BOX := Vector2(34, 56)
const FIST_REACH := 20.0
const CLUB_BOX := Vector2(62, 70)
const CLUB_REACH := 36.0
const JUMP := -640.0
## Asymmetric gravity: rise gently, fall fast. Removes the floaty feel.
const GRAVITY_UP := 1540.0
const GRAVITY_DOWN := 2280.0
const JUMP_CUT := 0.45        ## velocity kept when the jump key is released early
const COYOTE_TIME := 0.10     ## can still jump this long after walking off a ledge
const JUMP_BUFFER := 0.12     ## a jump press is remembered this long before landing
const STOMP_BOUNCE := -430.0  ## pop up after crushing something underfoot
const MAX_JUMPS := 2
const AIR_JUMP := -520.0      ## weaker than the ground jump: a recovery, not a free second jump
## Hercules-style: the second jump is a quick somersault that opens into the
## SPEAR pose — club arm thrust forward like a spear, the lead leg reaching
## out, the back leg tucked — and he comes down a little softer than a plain
## fall, with a capped speed and time to steer. A LONG fall (any fall) turns
## into a cartoon TUMBLE: legs pedalling, arms windmilling, yelling.
const AIR_FLIP_TIME := 0.3    ## (quick and snappy: a whip of a somersault)
const GLIDE_GRAVITY := 1900.0
const GLIDE_FALL := 620.0
const LONG_FALL := 0.4        ## falling this long (s) and he starts to tumble
const LONG_FALL_HERC := 0.8   ## ...but out of a double jump he holds the spear pose this long
const YELLS := ["Whoa-oa-oa!", "Waaah!", "Yaaa-aa!", "Whoooa!", "Uh-oh!"]
var _air_glide := false
var _spear := 0.0             ## 0..1: the spear pose after the double jump
var _tumble := 0.0            ## 0..1: the cartoon fall
var _fall_t := 0.0
var _yelled := false
## The UNBOWED get-up: out of a long flailing fall he lands SPLAT, pops back up
## and flexes. Only the splat holds him; any key cuts the flex short.
const GETUP_SPLAT := 0.26
const GETUP_FLEX := 0.42
const GETUP_TIME := 1.05
const BOASTS := ["UNBOWED!", "HA!", "Still here!", "Is that all?", "Ugu strong!"]
var getup := -1.0             ## seconds into the get-up; -1 = not getting up
## Chimneys: between two close walls (bodies in group "kick_wall") he jumps
## from one to the other, Prince of Persia style. Holding into a wall slows
## his fall to a slide; jump kicks him up and across. Other walls don't count,
## so climbs elsewhere can't be skipped this way.
const WALL_SLIDE := 150.0
const CLIMB_SPEED := 170.0    ## scrambling up a steep rock face (diggable Terrain)
var climbing := false
const WALL_KICK := Vector2(340, -600)
const WALL_LOCK := 0.16       ## after a kick, steering is ignored this long
const WALL_GRACE := 0.10      ## a kick still works this long after leaving the wall
var wall_cling := false
var _wall_dir := 0            ## the side the wall is on: -1 left, 1 right
var _wall_t := 0.0
var _kick_lock := 0.0
var _slide_dust := 0.0
const SWING_TIME := 0.26
## Bare-handed he throws a one-two: a jab off the lead hand, then a cross off
## the rear. Two separate strikes inside a single press.
const PUNCH_TIME := 0.36
const LAND_TIME := 0.16
const STRIDE := 40.0      ## how far a foot swings either side of the hip, design units
## The torch (Level 2 on). Fuel runs 1 -> 0; the light's radius follows it down
## from TORCH_R_MAX to TORCH_R_MIN, then it is out. Half fuel is the line the
## wolves respect, so the meter's midpoint is the number that matters.
const TORCH_BURN := 50.0      ## seconds from full to out
const TORCH_R_MAX := 300.0
const TORCH_R_MIN := 120.0
## An ability is announced by ~1 s of visible anger. He is untouchable and
## rooted through all of it; the fire leaves at FURY_RELEASE, the rest is snarl.
const FURY_TIME := 1.0
const FURY_RELEASE := 0.6
const FIRE_COST := 2          ## bundles of wood burned by one fire
## Wind (the mountain). In the air it carries him; on the ground it only
## drifts him, and holding INTO it braces him to a slow walk.
const WIND_GROUND := 0.35
const BRACE_SPEED := 90.0

var hp := 5
var max_hp := 5
var has_stick := false
var rocks := 0
var max_rocks := 6
var throwing := 0.0
## GRAB & THROW (common/grab.gd): the dazed critter held overhead, if any
const Grab := preload("res://common/grab.gd")
var carrying: Critter = null
var _carry_t := 0.0
var _carry_hand := Vector2(0, -96)    ## where his lifting hand was drawn (local px)
var berries := 0
var max_berries := 3
var facing := 1
var attacking := 0.0
var attack_cd := 0.0
var invuln := 0.0
var knock := 0.0
var anim_t := 0.0
var dead := false
var has_torch := false
var torch_fuel := 0.0
var wood := 0
var max_wood := 4
var costume := 1          ## 1 = leaves (Level 1), 2 = first hide loincloth (Level 2)
var fury := -1.0          ## seconds into the fire's wind-up; -1 when calm
var wind := 0.0           ## world px/s the air is pushing him; set by the level's Wind
var talking := false      ## in a conversation: stands still, can't be hurt, torch waits
## From upgrades and the gem forge (GameState puts these on him at level start).
var torch_burn := TORCH_BURN
var club_bonus := 0
## The Firestone Hammer (Level 2's forged weapon). Tap attack: a heavy blow.
## Hold attack: he raises it overhead and the gem burns brighter; let go and
## he SLAMS the ground, and a wave of fire rolls out both ways along it.
var hammer := false
const SLAM_READY := 0.5         ## how long the charge takes to be full
const SLAM_COOLDOWN := 1.3
var slam_charge := -1.0         ## >= 0 while raising the hammer
var slam_t := 0.0               ## > 0 just after a slam: the hammer down on the ground
var slam_cd := 0.0
var showing_off := 0.0          ## > 0: holding a new treasure up high (set by the level)
var _attack_held := 0.0
var _special_prev := false
var _charge_by_hold := false     ## this charge was started by holding J (the axe throw), not L
const AXE_HOLD := 0.26           ## hold J this long with the axe: the throw
const ATK_BUFFER := 0.2          ## a tap this early is remembered until the swing is ready
var _atk_buffer := 0.0
## THE COMBO: hits landed in a row (each within COMBO_GAP of the last). It
## builds his damage (COMBO_DMG) and is shown big on the HUD; a hit taken, or
## a pause, ends it.
var combo_hits := 0
var _combo_gap := 0.0
const COMBO_GAP := 2.0
const COMBO_DMG := [[5, 1], [12, 2], [25, 3]]       ## [hits, + damage]
const COMBO_WORDS := {10: "SAVAGE!", 20: "BRUTAL!", 30: "UNSTOPPABLE!", 50: "CAVE LEGEND!!"}
## SUNFIRE (see Sunfire): seconds of it left, and how full the sun is (0..1).
var sun_t := 0.0
var sun_charge := 0.0
var _sun_prev := false
var _shot_cd := 0.0
var _shot_hand := 0
var _stream_t := 0.0
var _sun_sparks: Array = []    ## [world pos, vel, life]: embers shed as he moves
var _sun_spark_in := 0.0
var _sun_k := 0.0              ## 0..1: how far into his SUNFIRE form (bigger, stronger) he has grown
var _idle_t := 0.0             ## standing still this long (for the yawn)
var _hands: Array = []         ## where his hands were drawn this frame (his local space)
var _head_at := Vector2(0, -64)
## METEOR STOMP (see Stomp): "" / "charge" (the spin) / "dive"; level 1, or 2 after a double jump.
var stomp_state := ""
var stomp_dir := 0              ## 0: the meteor goes DOWN; -1 / +1: the METEOR DASH, sideways (T + left/right)
var _dash_hit: Array = []         ## critters the dash has already struck
var stomp_level := 1
var _stomp_t := 0.0
var _stomp_prev := false
## Digging (see Dig): this swing goes straight down into the ground under him.
var digging_down := false
## His costume. The fire-discovery set: wolf_hood, ember_paint, bear_cloak,
## firekeeper (and the older wolf_pelt, war_paint, bone_necklace, plain).
var skin := "plain"
var axe := false           ## the Flint Axe: a knapped flint blade, harder blows

## ------------------------------------------------------------------ weapons
## Every weapon fights its own way, and each has its own special (hold
## attack, then let go):
##   Wooden Club — a quick overhead BONK.
##     Special: HOME RUN — pulled back low, then a huge sweeping swing that
##     sends small things flying.
##   Flint Axe — fast slashes: tap three times for slash, back-slash, CHOP.
##     Special: AXE THROW — it spins out, cuts through everything in its way,
##     and flies back to his hand.
##   Firestone Hammer — heaved up high and SMASHED down in front of him: slow,
##     heavy, it shakes the ground.
##     Special: FIRE SLAM — a wave of fire rolls out along the ground.
## Each swing: [how long, time before the next, hits from, hits until (as parts
## of the swing), reach, height, damage]
const SWINGS := {
	"club": [0.22, 0.24, 0.20, 1.00, 38.0, -34.0, 3],         # (2026-10-06: faster, Terraria-quick; was 0.26 / 0.38)
	"axe0": [0.15, 0.17, 0.10, 0.90, 44.0, -48.0, 3],
	"axe1": [0.15, 0.17, 0.10, 0.90, 44.0, -30.0, 3],
	"axe2": [0.30, 0.36, 0.52, 1.00, 42.0, -30.0, 6],
	"axe3": [0.44, 0.40, 0.52, 1.00, 54.0, -26.0, 7],          # the 4th: the leaping CLEAVE
	"hammer": [0.44, 0.52, 0.58, 0.88, 50.0, -18.0, 6],
	"dig": [0.30, 0.34, 0.50, 0.95, 4.0, 14.0, 1],          # DOWN + HIT: the hammer's slam, quick, into the ground
	"spike": [0.24, 0.20, 0.15, 1.00, 4.0, 22.0, 3],         # DOWN + HIT in the air: the POGO, straight down
	"homerun": [0.38, 0.60, 0.30, 0.82, 64.0, -42.0, 7],
	# the club's combo: tap, tap, TAP — BONK, the uppercut back up, then the finisher
	"club1": [0.18, 0.20, 0.15, 1.00, 40.0, -40.0, 3],
	"club2": [0.34, 0.42, 0.52, 0.95, 50.0, -30.0, 5],
	# the combos (2026-10-06): the 4th of the chain, and HIT at a full run
	"cyclone": [0.46, 0.30, 0.0, 1.00, 42.0, -40.0, 3],      # spins round twice: it hits both sides, again and again
	"ram": [0.30, 0.28, 0.0, 0.85, 52.0, -36.0, 4],          # a charge: through everything in the way
	# UP + HIT in the air, no side held (2026-10-08): the AIR KICKS — a snap kick straight up, then the FLASH KICK
	"kick1": [0.20, 0.16, 0.20, 0.85, 30.0, -86.0, 3],
	"kick2": [0.40, 0.34, 0.18, 0.80, 20.0, -80.0, 5],
}
const CHARGE_READY := {"club": 0.45, "axe": 0.3, "hammer": 0.5}
var _swing_kind := "club"
var _swing_time := 0.26
var _combo := 0
var _combo_t := 9.0             ## time since the last axe swing ended
var axe_out := false            ## the axe is out, spinning (thrown)
var _struck := false            ## this swing has already struck something (for its effects)
var preview := false       ## a mannequin in the shop: stands, breathes, never moves
signal ate_fig
var _fig_prev := false
## Scorched by standing in a campfire: "YEOWCH!", a leap, his loincloth
## smoking with little flames, a panicked run — then a sooty face a while.
var scorch_t := 0.0
var soot_t := 0.0
var _panic_dir := 1.0
var _smoke_in := 0.0
## Vine swinging. While on one he is placed by the swing, not by physics.
const HANG := 80.0        ## px from the grip down to his feet
## Jumping off a vine he somersaults the way he's flying: curls into a ball,
## spins, then opens out — arms wide, legs reaching — to land in a crouch.
## A big fast release is a DOUBLE flip; letting go on the backswing is a BACK
## flip, arms flung out. Faded ghosts of the ball trace the arc behind him.
const FLIP_TIME := 0.62
var flip_t := 0.0
var flip_dir := 1.0
var flip_len := FLIP_TIME
var flip_turns := 1.0
var flip_back := false
var _ghosts: Array = []         ## [global centre, time left] of the ball, for the trail
var _ghost_in := 0.0
var _flipped := false           ## was flipping just before landing: a puff of dust
var vine: Node2D = null
var _vine_a := 0.0        ## angle from straight down
var _vine_w := 0.0        ## angular speed
var _vine_cd := 0.0       ## brief no-regrab of the vine he just let go of
var _last_vine: Node2D = null
var touch := {"left": false, "right": false, "jump": false, "attack": false, "heal": false, "throw": false, "fire": false, "talk": false, "special": false, "up": false}

var _jump_prev := false
var _attack_prev := false
var _heal_prev := false
var _throw_prev := false
var _fire_prev := false
var _torch_tip := Vector2(-22, -80)   ## where the flame is, in his local space; set by drawing
var _embers: CPUParticles2D           ## embers rising from the torch
var _coyote := 0.0
var _buffer := 0.0
var _jumps_left := 0
var _hitbox: Area2D
var _hit_box: RectangleShape2D
var _swing_hits: Array = []
var _punch_beat := 0
## --- animation state (visual only, never read by gameplay)
var _run_phase := 0.0     ## advances with distance travelled, so feet never slide
var _land := 0.0          ## landing squash timer
var _land_amt := 0.0      ## how hard that landing was, 0..1
var _was_floor := true
var _hit_shape: CollisionShape2D


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED     # the fur tiles
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if preview:
		# just for show: no body, no hit box, not "the player"
		set_physics_process(false)
		collision_layer = 0
		collision_mask = 0
		has_stick = true
		costume = 2
		return
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	_embers = FX.embers(3.0, 8, 0.7)
	_embers.emitting = false
	add_child(_embers)

	var body := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 13.0
	cap.height = 64.0
	body.shape = cap
	body.position = Vector2(0, -32)
	add_child(body)

	_hitbox = Area2D.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 4
	_hitbox.monitorable = false
	_hit_shape = CollisionShape2D.new()
	_hit_box = RectangleShape2D.new()
	_hit_box.size = FIST_BOX            ## starts bare-handed and short
	_hit_shape.shape = _hit_box
	_hit_shape.position = Vector2(FIST_REACH, -30)
	_hitbox.add_child(_hit_shape)
	add_child(_hitbox)


func scorched(fire_x: float) -> void:
	if dead or scorch_t > 0.0 or vine != null:
		return
	scorch_t = 1.5
	soot_t = 6.0
	_panic_dir = 1.0 if global_position.x >= fire_x else -1.0
	facing = int(_panic_dir)
	velocity = Vector2(_panic_dir * 260.0, -720.0)
	var word := WordPop.new()
	word.text = "YEOWCH!"
	word.position = global_position + Vector2(-50, -120)
	get_parent().add_child(word)
	FX.burst(get_parent(), global_position + Vector2(0, -40), "embers")


## A roast fig: two hearts back.
func eat_fig() -> bool:
	if GameState.figs <= 0 or hp >= max_hp or dead:
		return false
	GameState.figs -= 1
	hp = mini(hp + 2, max_hp)
	GameState.save()
	var pop := HeartPop.new()
	pop.position = global_position + Vector2(0, -120)
	get_parent().add_child(pop)
	ate_fig.emit()
	return true


## The Flint Axe, thrown: it spins out, slowing, cutting through everything in
## its path; at the end of its flight (or when it hits a wall) it turns and
## flies back to his hand, cutting again on the way.
class ThrownAxe extends Area2D:
	const SPEED := 820.0
	const OUT := 0.6                ## about 400 px out before it turns back
	const DAMAGE := 4
	var man: CaveMan
	var dir := 1
	var t := 0.0
	var back := false
	var spin := 0.0
	var _hit := {}

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 4
		monitorable = false
		z_index = 4
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 34.0
		cs.shape = c
		add_child(cs)

	func _exit_tree() -> void:
		# however it goes (caught, a level change, freed by anything), the axe is his again
		if man != null and is_instance_valid(man):
			man.axe_out = false

	func _physics_process(delta: float) -> void:
		t += delta
		spin += delta * 24.0 * dir
		if man == null or not is_instance_valid(man):
			queue_free()
			return
		var vel: Vector2
		if not back:
			vel = Vector2(dir * SPEED * (1.0 - 0.5 * t / OUT), 0.0)
			var q := PhysicsRayQueryParameters2D.create(global_position, global_position + vel * delta * 2.0, 1)
			if t > OUT or not get_world_2d().direct_space_state.intersect_ray(q).is_empty():
				back = true
				_hit.clear()
		else:
			var to := man.global_position + Vector2(0, -46) - global_position
			if to.length() < 44.0 or t > 3.0:
				man.axe_out = false
				queue_free()
				return
			vel = to.normalized() * SPEED * 1.1
		global_position += vel * delta
		for a in get_overlapping_areas():
			if a.has_method("take_hit") and not _hit.has(a.get_instance_id()):
				_hit[a.get_instance_id()] = true
				a.take_hit(DAMAGE, dir if not back else -dir)
		queue_redraw()

	func _draw() -> void:
		# a blur of the spin, then the axe itself, turning
		draw_arc(Vector2.ZERO, 34.0, spin - 1.6, spin, 12, Color("dfeaf2", 0.35), 6.0, true)
		draw_set_transform(Vector2.ZERO, spin, Vector2.ONE)
		draw_line(Vector2(-30, 0), Vector2(24, 0), Color("3a2a18"), 9.0, true)
		draw_line(Vector2(-30, 0), Vector2(24, 0), Color("c49a64"), 5.0, true)
		draw_colored_polygon(PackedVector2Array([Vector2(14, -4), Vector2(18, -26), Vector2(34, -24), Vector2(38, -4), Vector2(26, 4)]), Color("3d4650"))
		draw_colored_polygon(PackedVector2Array([Vector2(16, -5), Vector2(19, -23), Vector2(32, -22), Vector2(35, -5), Vector2(26, 2)]), Color("6f7f8f"))
		draw_line(Vector2(32, -22), Vector2(35, -5), Color("d9e4ee"), 2.0, true)


## Dust and sparks where the hammer hits the ground.
class SmashDust extends Node2D:
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		if t > 0.45:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := t / 0.45
		for i in 6:
			var dx := (i - 2.5) * 12.0 * (1.0 + k * 1.6)
			draw_circle(Vector2(dx, -6.0 - k * 14.0), 7.0 + k * 10.0, Color(0.72, 0.66, 0.56, 0.5 * (1.0 - k)))
		for i in 5:
			var p := Vector2.from_angle(-PI * 0.5 + (i - 2) * 0.45) * (10.0 + k * 60.0) + Vector2(0, -6)
			draw_circle(p, 3.0 * (1.0 - k) + 1.0, Color(1.0, 0.8, 0.4, 1.0 - k))


## A word bursting out of a big hit ("HOME RUN!").
class WordPop extends Node2D:
	## A comic word ("HOME RUN!", "SPLAT!"): pops in big with a bounce, a dark
	## outline so it reads on anything, rises and fades. `star` puts a spiky
	## comic burst behind it; `centered` centres it on its position.
	var text := ""
	var t := 0.0
	var size := 30
	var color := Color(1.0, 0.85, 0.35)
	var star := Color(0, 0, 0, 0)
	var centered := false
	var tilt := -0.08
	var life := 0.9

	func _ready() -> void:
		z_index = 20

	func _process(delta: float) -> void:
		t += delta
		if t > life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		# pop: overshoot to 1.35, settle back to 1
		var k := lerpf(0.3, 1.35, clampf(t / 0.09, 0.0, 1.0))
		if t > 0.09:
			k = lerpf(1.35, 1.0, clampf((t - 0.09) / 0.14, 0.0, 1.0))
		var a := clampf((life - t) / 0.3, 0.0, 1.0)
		var font := Pal.title_font()          # comic words in chunky cartoon capitals
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var o := Vector2(-w * 0.5, size * 0.35) if centered else Vector2.ZERO
		draw_set_transform(Vector2(0, -t * 40.0), tilt, Vector2(k, k))
		if star.a > 0.0:
			var c := o + Vector2(w * 0.5, -size * 0.35)
			var pts := PackedVector2Array()
			for i in 24:
				var r := minf(w * 0.62 + 10.0, 78.0) if i % 2 == 0 else minf(w * 0.42 + 4.0, 56.0)
				pts.append(c + Vector2.from_angle(i * TAU / 24.0) * Vector2(r, r * 0.62))
			draw_colored_polygon(pts, Color(star, star.a * a))
		draw_string_outline(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(size / 5, 4), Color(0.12, 0.07, 0.04, a))
		draw_string(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, a))


## Two little hearts rising and fading where he ate a fig.
class HeartPop extends Node2D:
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		if t > 0.9:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var a := 1.0 - t / 0.9
		for k in 2:
			var c := Vector2(-14.0 + k * 28.0, -t * 60.0 - k * 8.0)
			var r := 7.0
			draw_circle(c + Vector2(-r * 0.5, 0), r * 0.6, Color(0.95, 0.35, 0.4, a))
			draw_circle(c + Vector2(r * 0.5, 0), r * 0.6, Color(0.95, 0.35, 0.4, a))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.05, 2), c + Vector2(r * 1.05, 2), c + Vector2(0, r * 1.3)]), Color(0.95, 0.35, 0.4, a))
		draw_string(ThemeDB.fallback_font, Vector2(-14, -t * 60.0 + 26.0), "+2", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.9, 0.9, a))


func _physics_process(delta: float) -> void:
	var fig_now: bool = Input.is_physical_key_pressed(KEY_H) or touch.get("fig", false)
	if fig_now and not _fig_prev:
		eat_fig()
	_fig_prev = fig_now
	_carry_step(delta)
	_combo_step(delta)
	if dead:
		# the last pop into the air, the topple, and then flat on his back
		_die_t += delta
		anim_t += delta
		velocity.y += GRAVITY_DOWN * delta
		velocity.x = move_toward(velocity.x, 0.0, (FRICTION if is_on_floor() else AIR_ACCEL * 0.5) * delta)
		move_and_slide()
		if is_on_floor() and _die_t > DIE_TIME and not _starred:
			_starred = true
			var stars := Critter.Dizzy.new()
			stars.life = 3.0
			stars.radius = 22.0
			stars.position = Vector2(-float(facing) * 58.0, -22.0)   # round his head, now he's on his back
			add_child(stars)
			FX.burst(get_parent(), global_position, "dust", float(facing))
		queue_redraw()
		return

	anim_t += delta
	attack_cd = maxf(attack_cd - delta, 0.0)
	invuln = maxf(invuln - delta, 0.0)
	knock = maxf(knock - delta, 0.0)
	attacking = maxf(attacking - delta, 0.0)
	if flip_t > 0.0:
		flip_t = maxf(flip_t - delta, 0.0)
		_ghost_in -= delta
		if _ghost_in <= 0.0:
			_ghost_in = 0.02
			_ghosts.append([global_position + Vector2(0, -38), 0.22])
		if is_on_floor() or vine != null or knock > 0.0:
			flip_t = 0.0
	for g in _ghosts:
		g[1] = float(g[1]) - delta
	_ghosts = _ghosts.filter(func(g): return float(g[1]) > 0.0)
	if _flipped and is_on_floor():
		# landed out of a flip: a crouch and a puff of dust
		_flipped = false
		var dust := SmashDust.new()
		dust.position = global_position
		dust.scale = Vector2(0.6, 0.6)
		get_parent().add_child(dust)
	elif _flipped and (vine != null or knock > 0.0):
		_flipped = false
	if attacking <= 0.0:
		_combo_t += delta
	throwing = maxf(throwing - delta, 0.0)

	if getup >= 0.0 and _update_getup(delta):
		return

	if talking:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		if not is_on_floor():
			velocity.y += GRAVITY_DOWN * delta
		move_and_slide()
		return

	if has_torch and torch_fuel > 0.0:
		torch_fuel = maxf(torch_fuel - delta / torch_burn, 0.0)
		if hammer:
			# the Firestone in the hammer feeds the flame: it never sinks below half
			torch_fuel = maxf(torch_fuel, 0.5)
		if torch_fuel <= 0.0:
			torch_out.emit()

	_update_sun(delta)

	# The fire: a burst of visible anger, THEN the flame. He cannot be hurt
	# through it — it is the button you press when swarmed, so a wind-up that
	# could be punished would be a trap — and he cannot steer, jump or strike:
	# the rage roots him. Fire leaves at 0.6 s; the rest is the snarl.
	var fire_now: bool = Input.is_physical_key_pressed(KEY_F) or touch["fire"]
	if fury >= 0.0:
		var before := fury
		fury += delta
		if before < FURY_RELEASE and fury >= FURY_RELEASE:
			_release_fire()
		if fury >= FURY_TIME:
			fury = -1.0
		_fire_prev = fire_now
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		if not is_on_floor():
			velocity.y += GRAVITY_DOWN * delta
		move_and_slide()
		_was_floor = is_on_floor()
		return

	# raising the Firestone Hammer: rooted while the charge builds; letting go
	# of attack brings it down — a SLAM if the charge was full
	slam_t = maxf(slam_t - delta, 0.0)
	slam_cd = maxf(slam_cd - delta, 0.0)
	showing_off = maxf(showing_off - delta, 0.0)
	var held: bool = Input.is_physical_key_pressed(KEY_J) or (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Time.get_ticks_msec() > ui_click_until) or touch["attack"]
	# SPECIAL (L): hold to charge the weapon's special, let go to unleash it.
	# Holding HIT itself keeps swinging (like Terraria). Touch: the SPECIAL button.
	var special: bool = Input.is_physical_key_pressed(KEY_L) or touch.get("special", false)
	if slam_charge >= 0.0:
		slam_charge += delta
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		if not is_on_floor():
			velocity.y += GRAVITY_DOWN * delta
		move_and_slide()
		if not (held if _charge_by_hold else special):
			if slam_charge >= _charge_ready():
				match _weapon():
					"hammer":
						_slam()
					"axe":
						_throw_axe()
					_:
						_home_run()
			slam_charge = -1.0
		_attack_prev = held
		_special_prev = special
		return
	if held:
		_attack_held += delta
	else:
		_attack_held = 0.0
	if has_stick and not axe_out and is_on_floor() and slam_cd <= 0.0 and special and not _special_prev:
		attacking = 0.0
		slam_charge = 0.0
		_charge_by_hold = false
	# the AXE: taps chain its combo, but HOLDING J winds up the throw (let go: it
	# spins out and comes back). If he is still holding in the wind-up of a
	# swing, the swing is dropped for the throw. (The club: holding J keeps swinging.)
	elif _weapon() == "axe" and tool == "weapon" and has_stick and not axe_out and is_on_floor() \
			and slam_cd <= 0.0 and _attack_held > AXE_HOLD:
		var winding := attacking > 0.0 and (1.0 - attacking / _swing_time) < float(SWINGS[_swing_kind][2])
		if attacking <= 0.0 or winding:
			attacking = 0.0
			slam_charge = 0.0
			_charge_by_hold = true
	_special_prev = special

	# scorched: running off in a panic, smoke trailing behind
	scorch_t = maxf(scorch_t - delta, 0.0)
	soot_t = maxf(soot_t - delta, 0.0)
	if scorch_t > 0.0:
		_smoke_in -= delta
		if _smoke_in <= 0.0:
			_smoke_in = 0.08
			FX.burst(get_parent(), global_position + Vector2(-_panic_dir * 16.0, -44.0), "smoke", -_panic_dir)
	var dir := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT) or touch["left"]:
		dir -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT) or touch["right"]:
		dir += 1.0
	if scorch_t > 0.0:
		dir = _panic_dir
	if dir != 0.0:
		facing = int(signf(dir))
	_vine_cd = maxf(_vine_cd - delta, 0.0)
	if vine != null:
		_swing(delta, dir)
		return
	var armed := has_stick and not axe_out
	var _reach := CLUB_REACH if armed else FIST_REACH
	var _height := -34.0 if armed else -30.0
	if not armed and attacking > 0.0 and _punch_beat == 1:
		_reach = FIST_REACH + 9.0
	if armed and attacking > 0.0:
		var sw: Array = SWINGS[_swing_kind]
		_reach = sw[4]
		_height = sw[5]
	_hit_shape.position.x = _reach * facing
	_hit_shape.position.y = _height
	if digging_down:
		if attacking > 0.0:
			_hit_shape.position = Vector2(facing * 6.0, 14.0)     # the ground under his feet
		else:
			digging_down = false
	if armed:
		var big := (_swing_kind == "homerun" or _swing_kind == "spike") and attacking > 0.0
		_hit_box.size = CLUB_BOX * (1.4 if big else 1.0)
	else:
		_hit_box.size = FIST_BOX
	if armed and attacking > 0.0 and _swing_aim.y < -0.3 and not _swing_kind in ["dig", "spike", "homerun", "hammer", "cyclone", "ram"]:
		# aimed up, or up and across at 45 degrees: the uppercut sweeps from the
		# ground in front of him up over his head, so it LAUNCHES what stands
		# there and still hits what flies above
		_hit_shape.position = Vector2(facing * 26.0 + _swing_aim.x * 18.0, -62.0)
		_hit_box.size = Vector2(76.0, 136.0)
	if attacking > 0.0 and tool == "shovel" and _swing_kind == "dig" and not digging_down:
		# the shovel bites where he aims: up, ahead, the diagonals
		_hit_shape.position = Vector2(0, -40) + _dig_aim * 46.0
	if armed and attacking > 0.0 and _swing_kind == "cyclone":
		# the CYCLONE: the blow sweeps round him, front, back, front, back —
		# and every quarter turn it can hit the same beast again
		var cq := int((1.0 - attacking / _swing_time) * 4.0)
		_hit_shape.position.x = (_reach if cq % 2 == 0 else -_reach) * facing
		if cq != _cyc_q:
			_cyc_q = cq
			_swing_hits.clear()

	if _kicking():
		# the kicks reach up over his head: the snap straight up, the flash kick's whole crescent
		_hit_shape.position = Vector2(facing * 30.0, -90.0) if _swing_kind == "kick1" else Vector2(facing * 6.0, -84.0)
		_hit_box.size = Vector2(64, 76) if _swing_kind == "kick1" else Vector2(120, 120)

	_kick_lock = maxf(_kick_lock - delta, 0.0)
	if knock <= 0.0 and _kick_lock <= 0.0:
		var a := (ACCEL if is_on_floor() else AIR_ACCEL) * _sun_mul()
		if dir != 0.0:
			velocity.x = move_toward(velocity.x, dir * (SPEED if is_on_floor() else AIR_SPEED) * _sun_mul(), a * delta)
		else:
			var f := FRICTION if is_on_floor() else AIR_ACCEL * 0.5
			velocity.x = move_toward(velocity.x, 0.0, f * delta)
	# a launch stronger than the air jump (a Moonpuff, a Glowcap) ends the glide
	if knock > 0.0 or velocity.y < AIR_JUMP * _jump_mul() - 60.0:
		_air_glide = false
	if not is_on_floor():
		if _air_glide and velocity.y >= 0.0:
			velocity.y = minf(velocity.y + GLIDE_GRAVITY * delta, GLIDE_FALL)
		else:
			velocity.y += (GRAVITY_UP if velocity.y < 0.0 else GRAVITY_DOWN) * delta

	# the spear pose out of the double jump's somersault; the tumble on a long fall
	var aloft := not is_on_floor() and vine == null and knock <= 0.0 and not dead and not wall_cling
	if aloft and velocity.y > 0.0:
		_fall_t += delta
	else:
		_fall_t = 0.0
	var tumbling := aloft and flip_t <= 0.0 and _fall_t > (LONG_FALL_HERC if _air_glide else LONG_FALL)
	var spearing := aloft and _air_glide and flip_t < AIR_FLIP_TIME * 0.35 and not tumbling
	_tumble = move_toward(_tumble, 1.0 if tumbling else 0.0, delta * (7.0 if tumbling else 12.0))
	_spear = move_toward(_spear, 1.0 if spearing else 0.0, delta * 9.0)
	if tumbling and not _yelled:
		_yelled = true
		var yell := WordPop.new()
		yell.text = YELLS[randi() % YELLS.size()]
		yell.size = 22
		yell.color = Color("cfe8ff")
		yell.centered = true
		yell.tilt = randf_range(-0.15, 0.15)
		yell.life = 0.8
		yell.position = global_position + Vector2(0, -110)
		get_parent().add_child.call_deferred(yell)
	if not aloft:
		_yelled = false

	# chimney walls: cling and slide while holding into one
	_wall_t = maxf(_wall_t - delta, 0.0)
	wall_cling = false
	# ROCK CLIMBING: hold toward a steep face of the diggable rock (too steep to
	# walk up) and he scrambles up it; at the top he heaves himself over the lip.
	# SPACE kicks off it like a chimney wall.
	var was_climbing := climbing
	climbing = false
	var rn := _rock_wall_normal()
	var up_held: bool = Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W) or touch.get("up", false)
	# on the ground it takes UP + toward the wall (walking into rock just stops, so he can dig it);
	# in the air, or already on the wall, holding toward it is enough. Holding HIT digs instead.
	if rn != 0.0 and dir == -rn and attacking <= 0.0 and _attack_held <= 0.0 and (up_held or not is_on_floor() or was_climbing):
		climbing = true
		_wall_dir = -int(rn)
		_wall_t = WALL_GRACE
		wall_cling = true
		velocity.y = -CLIMB_SPEED
		_slide_dust -= delta
		if _slide_dust <= 0.0:
			_slide_dust = 0.16
			FX.burst(get_parent(), global_position + Vector2(_wall_dir * 13.0, -40.0), "dust", float(-_wall_dir))
	elif was_climbing and dir == float(_wall_dir) and not is_on_floor():
		# over the top: a heave up onto the ledge
		velocity = Vector2(dir * 180.0, -360.0)
	if not is_on_floor() and not climbing:
		var wn := _kick_wall_normal()
		if wn != 0.0:
			_wall_dir = -int(wn)
			_wall_t = WALL_GRACE
			if dir == float(_wall_dir) and velocity.y > 0.0:
				wall_cling = true
				velocity.y = minf(velocity.y, WALL_SLIDE)
				_slide_dust -= delta
				if _slide_dust <= 0.0:
					_slide_dust = 0.12
					FX.burst(get_parent(), global_position + Vector2(_wall_dir * 13.0, -20.0), "dust", float(-_wall_dir))

	# coyote time: full on the ground, draining in the air
	if is_on_floor():
		_coyote = COYOTE_TIME
		_jumps_left = MAX_JUMPS
		_air_kicks = 0
		_air_glide = false
	else:
		_coyote = maxf(_coyote - delta, 0.0)
		# walking off a ledge without jumping spends the ground jump
		if _coyote <= 0.0 and _jumps_left == MAX_JUMPS:
			_jumps_left = MAX_JUMPS - 1

	var jump_now: bool = Input.is_physical_key_pressed(KEY_SPACE) \
		or touch["jump"]

	# jump buffer: remember a press so an early tap still fires on landing
	if jump_now and not _jump_prev:
		_buffer = JUMP_BUFFER
	else:
		_buffer = maxf(_buffer - delta, 0.0)

	if _buffer > 0.0:
		if _wall_t > 0.0 and not is_on_floor():
			# kick off the wall: up, and across to the other one
			velocity = Vector2(-_wall_dir * WALL_KICK.x, WALL_KICK.y)
			facing = -_wall_dir
			_kick_lock = WALL_LOCK
			_jumps_left = MAX_JUMPS - 1
			_air_glide = false
			_wall_t = 0.0
			_buffer = 0.0
			FX.burst(get_parent(), global_position + Vector2(_wall_dir * 13.0, -30.0), "dust", float(-_wall_dir))
			if GameState.learn("wallkick"):
				said.emit("WALL KICK learned! (see Abilities in the camp menu)")
		elif _coyote > 0.0 and _jumps_left == MAX_JUMPS:
			velocity.y = JUMP * _jump_mul()
			FX.burst(get_parent(), global_position, "dust", -float(facing))
			_jumps_left -= 1
			_buffer = 0.0
			_coyote = 0.0
		elif _jumps_left > 0:
			velocity.y = AIR_JUMP * _jump_mul()
			FX.burst(get_parent(), global_position + Vector2(0, 4), "ring")
			_jumps_left -= 1
			_buffer = 0.0
			flip_dir = signf(velocity.x) if absf(velocity.x) > 40.0 else float(facing)
			flip_back = false
			flip_turns = 1.0
			flip_len = AIR_FLIP_TIME
			flip_t = flip_len
			_ghosts.clear()
			_flipped = true
			_air_glide = true

	# variable height: releasing early cuts the jump short
	if not jump_now and _jump_prev and velocity.y < 0.0:
		velocity.y *= JUMP_CUT
	_jump_prev = jump_now

	var attack_now: bool = Input.is_physical_key_pressed(KEY_J) \
		or (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Time.get_ticks_msec() > ui_click_until) \
		or touch["attack"]
	# a tap a little before the last swing is ready is remembered (BUFFERED) and
	# fires the moment it is: mashing J never loses a hit, so the combos land
	_atk_buffer = maxf(_atk_buffer - delta, 0.0)
	if attack_now and not _attack_prev and attack_cd > 0.0:
		_atk_buffer = ATK_BUFFER
	var buffered := _atk_buffer > 0.0 and attack_cd <= 0.0
	if buffered:
		_atk_buffer = 0.0
	if attack_now and not _attack_prev and carrying != null:
		_hurl()
	elif attack_now and not _attack_prev and tool == "rocks":
		throw_rock()                                  # the hotbar's ROCKS: HIT throws one, aimed
	elif attack_now and not _attack_prev and tool == "figs":
		eat_fig()                                     # the hotbar's FIGS: HIT eats one
	elif attack_now and not _attack_prev and Bag.HOTBAR.has(tool):
		Bag.use(self, tool)                           # made in the bag: tips, salve, wall, ladder, spark kit
	elif attack_now and attack_cd <= 0.0 and tool == "shovel" and carrying == null:
		# the SHOVEL: it digs wherever he aims (held, it keeps digging)
		_dig_aim = aim()
		if _dig_aim.y == 0.0:
			_dig_aim = Vector2(float(facing), 0.0)
		digging_down = _dig_aim.y > 0.9 and is_on_floor()     # straight down; DOWN + a side digs the diagonal
		_start_swing("dig")
		attack_cd *= 0.8                              # a proper tool digs quicker than a club
		_swing_hits.clear()
	# (only with the weapon in hand: held HIT with rocks, figs or a bag thing used to swing the club too)
	elif (attack_now or buffered) and attack_cd <= 0.0 and carrying == null and tool == "weapon" and (buffered or not _attack_prev or _weapon() != "axe" or not has_stick):
		# held, it keeps swinging (like Terraria): each swing chains on into the next
		var down_held: bool = Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN) or touch.get("down", false)
		# UP + HIT in the air with no side held: the AIR KICKS (a side held: the club, aimed, as ever)
		var kick := up_held and not down_held and dir == 0.0 and not is_on_floor() and vine == null and not wall_cling and not climbing
		# DOWN + HIT on the ground: an overhead blow straight down — digging
		digging_down = is_on_floor() and down_held
		if kick:
			_air_kick()
		elif digging_down and has_stick and not axe_out:
			_start_swing("dig")
		elif down_held and not is_on_floor() and has_stick and not axe_out and vine == null:
			# DOWN + HIT in the air: the POGO — a spike straight down; hit something and he bounces off it
			_start_swing("spike")
		elif has_stick and not axe_out:
			var kind := _weapon()
			_swing_aim = aim()
			var aimed_up := _swing_aim.y < -0.3
			if kind == "axe":
				# the axe's chain: slash, back-slash, CHOP... and the 4th, the leaping CLEAVE
				_combo = (_combo + 1) % 4 if _combo_t < 0.45 else 0
				kind = "axe%d" % _combo
				if aimed_up:
					kind = "axe0"                            # aimed up: the rising slash, a LAUNCHER
				elif _combo == 0 and is_on_floor() and absf(velocity.x) > SPEED * 0.85:
					# HIT at a full run: the RAM, axe-first
					kind = "ram"
					velocity.x = float(facing) * 680.0
					_kick_lock = 0.22
					_say_word("RAM!", Color("ffd36b"))
				elif kind == "axe3":
					# the CLEAVE: a hop forward, the axe up over his head... and DOWN
					if is_on_floor():
						velocity = Vector2(float(facing) * 260.0, -380.0)
					_say_word("CLEAVE!", Color("dfeaf2"))
			elif kind == "club":
				# the chain: BONK, uppercut, SMASH... and the 4th, the CYCLONE
				_combo = (_combo + 1) % 4 if _combo_t < 0.45 else 0
				kind = ["club", "club1", "club2", "cyclone"][_combo]
				if aimed_up:
					kind = "club1"                           # aimed up (or up and across): the uppercut, a LAUNCHER
				elif _combo == 0 and is_on_floor() and absf(velocity.x) > SPEED * 0.85:
					# HIT at a full run: the RAM, a charge right through them
					kind = "ram"
					velocity.x = float(facing) * 680.0
					_kick_lock = 0.22
					_say_word("RAM!", Color("ffd36b"))
				elif kind == "club2":
					velocity.x += float(facing) * 140.0      # a step into the finisher
				elif kind == "cyclone":
					_say_word("CYCLONE!", Color("bfe6ff"))
			_start_swing(kind)
		else:
			attack_cd = 0.3
			attacking = PUNCH_TIME
			_swing_kind = "club"           # a punch, not a kick left over
		if sun_t > 0.0:
			attack_cd *= 0.55          # burning fists are quick fists
		_punch_beat = 0
		_swing_hits.clear()
	_attack_prev = attack_now

	# The club connects across the WHOLE swing, not on one frame. Checking only
	# at the keypress meant anything that was not already touching him was a miss.
	if attacking > 0.0:
		if (not has_stick or axe_out) and not _kicking():
			# the cross is a fresh strike, so the same target can be hit by both
			var beat := 1 if (1.0 - attacking / PUNCH_TIME) >= 0.5 else 0
			if beat != _punch_beat:
				_punch_beat = beat
				_swing_hits.clear()
		_apply_swing()

	var throw_now: bool = Input.is_physical_key_pressed(KEY_K) \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) \
		or touch["throw"]
	if sun_t > 0.0:
		# SUNFIRE: fireballs as fast as he taps — or a stream while it is held
		if throw_now:
			_stream_t -= delta
			if (not _throw_prev or _stream_t <= 0.0) and shoot_fireball():
				_stream_t = Sunfire.STREAM_GAP
	elif throw_now and not _throw_prev:
		if carrying != null:
			_hurl()
		elif not _try_grab():
			throw_rock()
	_throw_prev = throw_now

	if fire_now and not _fire_prev:
		if Abilities.is_equipped("firering", self):
			start_fire()
		elif has_torch:
			said.emit("FIRE RING isn't one of his two abilities — pick it in the menu (Esc).")
	_fire_prev = fire_now

	# the wind: carried in the air, drifted on the ground, braced against by
	# walking into it (which slows him to a lean-forward crawl)
	var push := 0.0
	if wind != 0.0:
		var into := dir != 0.0 and signf(dir) != signf(wind)
		if is_on_floor():
			# bracing slows his walk to a lean, and the lean just about holds him
			if into:
				velocity.x = clampf(velocity.x, -BRACE_SPEED, BRACE_SPEED)
			push = wind * WIND_GROUND
		else:
			push = wind

	_update_stomp(delta)
	var pre_vy := velocity.y
	move_and_slide()
	if push != 0.0:
		move_and_collide(Vector2(push * delta, 0.0))
	var on_floor := is_on_floor()
	if stomp_state == "dive" and on_floor:
		_stomp_impact()
	if stomp_state == "dash" and is_on_wall():
		_dash_wall()
	if on_floor and not _was_floor and _tumble > 0.5 and stomp_state == "" and invuln <= 0.0:
		# (not straight after a hit: a splat then would hand the next blow a free target)
		getup = 0.0
		invuln = GETUP_SPLAT + 0.1
		velocity.x *= 0.2
		FX.burst(get_parent(), global_position, "dust", float(facing))
		FX.burst(get_parent(), global_position, "dust", -float(facing))
		var lvl := get_parent()
		if lvl.has_method("shake"):
			lvl.shake(7.0, 0.22)
		var ring := SmashDust.new()
		ring.position = global_position
		lvl.add_child(ring)
		var splat := WordPop.new()
		splat.text = "SPLAT!"
		splat.size = 34
		splat.color = Color("fff4d6")
		splat.star = Color("d9541e", 0.9)
		splat.centered = true
		splat.tilt = randf_range(-0.2, 0.2)
		splat.life = 0.6
		splat.position = global_position + Vector2(0, -40)
		lvl.add_child(splat)
	if on_floor and not _was_floor and pre_vy > 200.0:
		_land = LAND_TIME
		_land_amt = clampf(pre_vy / 1400.0, 0.3, 1.0)
		if pre_vy > 650.0:
			FX.burst(get_parent(), global_position, "dust", float(facing))
	_was_floor = on_floor


func _process(delta: float) -> void:
	if preview:
		# the shop's mannequin: just breathes
		anim_t += delta
		queue_redraw()
		return
	if _embers != null:
		_embers.position = _torch_tip
		_embers.emitting = has_torch and torch_fuel > 0.05 and not dead
	if invuln > 0.0 and not dead and fmod(invuln * 12.0, 1.0) < 0.5:
		modulate.a = 0.35
	else:
		modulate.a = 1.0
	# The stride is driven by distance covered, not by time. Tie it to time and
	# the feet skate whenever his speed changes; tie it to distance and every
	# footfall lands where the ground actually is.
	if is_on_floor():
		var k := clampf(absf(velocity.x) / SPEED, 0.0, 1.0)
		var step0 := floori(_run_phase / PI)
		_run_phase += absf(velocity.x) * delta / (_stride_amp(k) * ART)
		if floori(_run_phase / PI) != step0 and k > 0.8 and is_on_floor():
			FX.burst(get_parent(), global_position, "kick", signf(velocity.x))
	_land = maxf(_land - delta, 0.0)
	queue_redraw()


## Runs every frame the swing is live. Each target can only be hit once per swing.
func _apply_swing() -> void:
	var dmg := 1
	var kicking := _kicking()
	if (has_stick and not axe_out) or kicking:
		var sw: Array = SWINGS[_swing_kind]
		var prog := 1.0 - attacking / _swing_time
		if prog < float(sw[2]) or prog > float(sw[3]):
			return
		dmg = int(sw[6]) + club_bonus
		if _swing_kind == "dig" and not _struck:
			# the blow goes in: dirt flies both ways, a thud
			_struck = true
			var lv := get_parent()
			FX.burst(lv, global_position + Vector2(facing * 8.0, 0), "kick", 1.0)
			FX.burst(lv, global_position + Vector2(facing * 8.0, 0), "kick", -1.0)
			FX.burst(lv, global_position, "dust", float(facing))
			if lv.has_method("shake"):
				lv.shake(2.5, 0.1)
		if _swing_kind == "axe3" and not _struck and is_on_floor():
			# the CLEAVE comes down: the ground cracks, chips fly
			_struck = true
			var lv2 := get_parent()
			if lv2.has_method("shake"):
				lv2.shake(5.0, 0.15)
			FX.shards(lv2, global_position + Vector2(facing * 60.0, 0), Vector2(facing * 0.3, -1.0), true)
		if _swing_kind == "hammer" and not _struck:
			# the hammer comes down on the ground: it shakes, and sparks fly
			_struck = true
			var level := get_parent()
			if level.has_method("shake"):
				level.shake(4.0, 0.15)
			var dust := SmashDust.new()
			dust.position = global_position + Vector2(facing * 86.0, 0)
			level.add_child(dust)
	if sun_t > 0.0:
		dmg += Sunfire.HIT_BONUS
	dmg += combo_bonus()
	for area in _hitbox.get_overlapping_areas():
		if not area.has_method("take_hit"):
			continue
		var id := area.get_instance_id()
		if _swing_hits.has(id) or area == carrying:
			continue
		_swing_hits.append(id)
		if area is Critter:
			Grab.daze(area as Critter)        # dazed: grab it (THROW) while the stars spin
		var flings := _swing_kind == "homerun" and has_stick and "fling" in area
		if flings:
			area.fling = 2.4
		var crit := area is Critter
		var at := (area as Node2D).global_position
		if sun_t > 0.0 and crit:
			(area as Critter).burned(dmg, global_position)     # a burning blow
		else:
			area.take_hit(dmg, facing)
		if crit:
			add_sun(Sunfire.GAIN_HIT)
			_hit_word(at)
			combo_hit()
			# every blow lands with a little freeze-frame: heavier swings, longer
			var heavy := _swing_kind in ["club2", "axe2", "axe3", "hammer", "homerun", "kick2"]
			Critter.slow_time(get_tree(), 0.05 if heavy else 0.03, 0.06 if heavy else 0.04)
		if crit and is_instance_valid(area) and (area as Critter).dying <= 0.0:
			var cr := area as Critter
			if _swing_kind == "kick2" and not cr.airborne and cr.can_launch():
				# the FLASH KICK sends it up: kick it again up there
				cr.launch(-560.0)
				_juggles = 0
			elif _swing_kind in ["club1", "axe0"] and _swing_aim.y < -0.3 and not cr.airborne and is_on_floor() and cr.can_launch():
				# the LAUNCHER: up it goes — jump after it!
				cr.launch(-580.0)                 # ~150 px up, a floaty arc: a jump (or two) to chase it
				_juggles = 0
				_say_word("LAUNCH!", Color("bfe6ff"))
			elif not is_on_floor() and cr.airborne and _swing_kind != "spike":
				# a JUGGLE: hit it again up there and it stays up; so does he, a little
				cr.launch(-430.0)
				velocity.y = minf(velocity.y, -260.0)
				_juggles += 1
				_say_word("JUGGLE x%d!" % _juggles, Color("ffe066"))
			elif _swing_kind == "spike" and cr.airborne:
				cr.slam()                         # SLAM DUNK: straight down into the ground
		if _swing_kind == "spike" and (crit or area is Treasure.Breakable):
			# the POGO: off its head and back up, the air jump given back
			velocity.y = -640.0
			_jumps_left = maxi(_jumps_left, 1)
			attacking = minf(attacking, 0.05)
			FX.burst(get_parent(), global_position + Vector2(0, 10), "ring")
		if sun_t > 0.0:
			var boom := Sunfire.Impact.new()
			boom.position = at + Vector2(-facing * 6.0, -30.0)
			boom.size = 1.4
			get_parent().add_child(boom)
		if not is_instance_valid(area):
			continue
		if kicking:
			# a kick lands: a white ring where the foot met it, and the flash kick jolts the world
			var foot := global_position + _hit_shape.position
			FX.burst(get_parent(), foot, "ring")
			FX.burst(get_parent(), foot, "sparks", float(facing))
			if _swing_kind == "kick2" and not _struck:
				_struck = true
				var lvk := get_parent()
				if lvk.has_method("shake"):
					lvk.shake(4.5, 0.14)
		elif has_stick:
			FX.burst(get_parent(), (area as Node2D).global_position + Vector2(-facing * 10.0, -34.0), "sparks", float(facing))
		if flings and is_instance_valid(area):
			area.fling = 1.0
		# the hammer's weight: what it hits and doesn't kill is knocked flat
		if _swing_kind == "hammer" and is_instance_valid(area) and area.has_method("stagger"):
			area.stagger(facing, 0.9)
		if _swing_kind in ["club2", "axe3"] and is_instance_valid(area):
			# the finisher: the world jolts, and what it hits reels back
			if area.has_method("stagger"):
				area.stagger(facing, 0.6)
			if not _struck:
				_struck = true
				var lvl := get_parent()
				if lvl.has_method("shake"):
					lvl.shake(6.0, 0.18)
		if _swing_kind == "homerun" and not _struck:
			_struck = true
			var word := WordPop.new()
			word.text = "HOME RUN!"
			word.position = area.global_position + Vector2(-50, -90)
			get_parent().add_child(word)


## Which weapon is in his hand.
func _weapon() -> String:
	if hammer:
		return "hammer"
	if axe:
		return "axe"
	return "club"


func _charge_ready() -> float:
	return CHARGE_READY[_weapon()]


func _start_swing(kind: String) -> void:
	var sw: Array = SWINGS[kind]
	_swing_kind = kind
	_cyc_q = -1
	_swing_time = sw[0]
	attacking = sw[0]
	attack_cd = sw[1]
	_struck = false
	if kind.begins_with("axe") or kind.begins_with("club") or kind.begins_with("kick"):
		_combo_t = 0.0


func _kicking() -> bool:
	return attacking > 0.0 and _swing_kind.begins_with("kick")


## UP + HIT in the air, no side held: the AIR KICKS, with or without a weapon.
## A snap kick straight up, then the FLASH KICK: a backflip, the foot drawing
## a blazing crescent overhead (it LAUNCHES what it catches; up there, both
## kicks JUGGLE). The first two of a jump lift him a little; later ones don't.
func _air_kick() -> void:
	var second := _swing_kind == "kick1" and _combo_t < 0.45
	_start_swing("kick2" if second else "kick1")
	_swing_aim = Vector2.UP
	if _air_kicks < 2:
		velocity.y = minf(velocity.y, -320.0 if second else -200.0)
	_air_kicks += 1
	if second:
		FX.burst(get_parent(), global_position + Vector2(0, -30), "ring")
		_say_word("FLASH KICK!", Color("ffd36b"))
	else:
		FX.burst(get_parent(), global_position, "kick", float(facing))


## The Wooden Club's special: a huge sweep from low behind him, round in front.
func _home_run() -> void:
	_start_swing("homerun")
	_swing_hits.clear()
	slam_cd = 0.7


## The Flint Axe's special: it spins out, and comes back.
func _throw_axe() -> void:
	axe_out = true
	slam_cd = 0.3
	var flying := ThrownAxe.new()
	flying.man = self
	flying.dir = facing
	flying.position = global_position + Vector2(facing * 40.0, -46.0)     # waist-high: low enough for wolves
	get_parent().add_child(flying)


## The hammer comes down: a wave of fire rolls out along the ground.
func _slam() -> void:
	slam_t = 0.3
	slam_cd = SLAM_COOLDOWN
	var wave := NightWoods.FireWave.new()
	wave.position = global_position
	wave.player = self
	get_parent().add_child(wave)
	var level := get_parent()
	if level.has_method("shake"):
		level.shake(7.0, 0.35)


## ------------------------------------------------------------------ vines
## A vine hands itself to him when he flies into its end. He keeps the speed he
## arrived with, can pump with left/right, and jumps to let go — carrying the
## swing's speed with him, plus a little hop.
## The side normal of a chimney wall he touched in the last move, or 0.
## A steep face of the diggable rock he is pressed against (too steep to walk up):
## which way it faces, or 0.
func _rock_wall_normal() -> float:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		var body := c.get_collider() as Node
		if absf(n.x) > 0.72 and body != null and _is_rock(body):
			return signf(n.x)
	return 0.0


## The diggable Terrain is a Node2D; what he touches is one of its chunk bodies, further down.
func _is_rock(n: Node) -> bool:
	for i in 3:
		if n == null:
			return false
		if n.is_in_group("diggable"):
			return true
		n = n.get_parent()
	return false


func _kick_wall_normal() -> float:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		var body := c.get_collider() as Node
		if absf(n.x) > 0.7 and body != null and body.is_in_group("kick_wall"):
			return signf(n.x)
	return 0.0


func grab_vine(v: Node2D) -> bool:
	if vine != null or dead or talking or fury >= 0.0 or is_on_floor():
		return false
	if v == _last_vine and _vine_cd > 0.0:
		return false
	vine = v
	_drop_carried()
	var rel: Vector2 = (global_position - Vector2(0, HANG)) - v.global_position
	_vine_a = atan2(rel.x, rel.y)
	var length: float = v.length
	_vine_w = clampf((velocity.x * cos(_vine_a) - velocity.y * sin(_vine_a)) / length, -3.0, 3.0)
	velocity = Vector2.ZERO
	_jumps_left = MAX_JUMPS
	return true


func _swing(delta: float, dir: float) -> void:
	var length: float = vine.length
	var acc := -(1800.0 / length) * sin(_vine_a) + dir * 2.6 * cos(_vine_a)
	_vine_w = clampf((_vine_w + acc * delta) * (1.0 - 0.12 * delta), -3.4, 3.4)
	_vine_a = clampf(_vine_a + _vine_w * delta, -1.3, 1.3)
	var grip: Vector2 = vine.global_position + Vector2(sin(_vine_a), cos(_vine_a)) * length
	global_position = grip + Vector2(0, HANG)
	vine.angle = _vine_a
	var jump_now: bool = Input.is_physical_key_pressed(KEY_SPACE) or touch["jump"]       # (UP / W aim now; SPACE jumps)
	if jump_now and not _jump_prev:
		var tangent := Vector2(cos(_vine_a), -sin(_vine_a)) * _vine_w * length
		# a vine on something that moves (a flying rock): he keeps its speed too,
		# and kicks off it the way he faces
		var carry = vine.get("carry")
		if carry is Vector2:
			tangent += carry + Vector2(float(facing) * 90.0, 0.0)
		_let_go(tangent + Vector2(0, -320))
		# off the vine with a somersault, turning the way he's flying
		flip_dir = signf(velocity.x) if absf(velocity.x) > 40.0 else float(facing)
		flip_back = flip_dir != float(facing) and absf(velocity.x) > 60.0
		flip_turns = 2.0 if absf(velocity.x) > 430.0 and not flip_back else 1.0
		flip_len = FLIP_TIME * (1.35 if flip_turns > 1.0 else 1.0)
		flip_t = flip_len
		_ghosts.clear()
		_flipped = true
	_jump_prev = jump_now


func _let_go(vel: Vector2) -> void:
	if vine != null and vine.has_method("let_go"):
		vine.let_go()
	_last_vine = vine
	vine = null
	_air_glide = false
	velocity = vel
	_vine_cd = 0.45
	_jumps_left = MAX_JUMPS - 1


## Called by a critter when he lands on top of it.
func stomp_bounce(push_x: float = 0.0) -> void:
	velocity.y = STOMP_BOUNCE
	if push_x != 0.0:
		velocity.x = push_x
		# brief loss of steering so the shove actually carries him off the back,
		# instead of being cancelled by his own input on the very next frame
		knock = 0.24
	_coyote = 0.0
	_buffer = 0.0
	_jumps_left = maxi(_jumps_left, 1)   # a crush refunds an air jump, so stomps chain
	invuln = maxf(invuln, 0.12)          # brief grace so a neighbour cannot punish a clean stomp


## Fired by a spring. Resets the air jumps so he can steer out of the launch.
func launch(vy: float) -> void:
	velocity.y = vy
	_coyote = 0.0
	_buffer = 0.0
	_jumps_left = MAX_JUMPS


func hurt(amount: int, from_x: float) -> void:
	if invuln > 0.0 or dead or fury >= 0.0 or talking:
		return
	getup = -1.0
	if stomp_state != "":
		return                          # nothing stops a meteor
	if sun_t > 0.0:
		# the fire takes it: a flare, a little shove, no harm
		invuln = 0.5
		var flare := Sunfire.Impact.new()
		flare.position = global_position + Vector2(0, -40)
		flare.size = 1.8
		get_parent().add_child(flare)
		velocity.x = signf(global_position.x - from_x + 0.01) * 220.0
		return
	hp -= amount
	invuln = 1.1
	_drop_carried()
	combo_hits = 0                       # a hit taken ends the run
	knock = 0.25
	slam_charge = -1.0
	if vine != null:
		_let_go(Vector2.ZERO)
	var away := signf(global_position.x - from_x)
	if away == 0.0:
		away = -float(facing)
	velocity = Vector2(away * 280.0, -340.0)
	hp_changed.emit(hp)
	if hp <= 0:
		_die()
	elif berries > 0 and is_inside_tree():
		get_tree().create_timer(0.45).timeout.connect(_auto_eat)


## Hurt, and — if the hit landed — thrown along `toss` instead of the usual
## knock-back (hazards that bowl him UP rather than sideways off a ledge:
## geysers, the snapper, swooping bats, guard flies). True if it landed.
func hurt_toss(amount: int, from_x: float, toss: Vector2) -> bool:
	var before := hp
	hurt(amount, from_x)
	if hp < before and not dead:
		velocity = toss
		return true
	return false


## Put back on solid ground after a fall. Costs one health point, but applies
## NO knockback: being flung again while standing at the lip of the same hole
## is how one fall turns into three.
func respawn_at(spot: Vector2) -> void:
	global_position = spot
	velocity = Vector2.ZERO
	knock = 0.0
	fury = -1.0
	if vine != null:
		_let_go(Vector2.ZERO)
	if dead:
		return
	hp -= 1
	invuln = 1.3
	hp_changed.emit(hp)
	if hp <= 0:
		_die()


func pick_up_stick() -> void:
	has_stick = true
	_hit_box.size = CLUB_BOX     ## longer and taller the moment he has it
	stick_picked.emit()


func add_rock(n: int = 1) -> bool:
	if rocks >= max_rocks:
		return false
	rocks = mini(rocks + n, max_rocks)
	rocks_changed.emit(rocks)
	rock_picked.emit()
	return true


## Throws a rock in the direction he faces. Ranged answer to things that bite back.
func throw_rock() -> bool:
	if dead or rocks <= 0 or throwing > 0.0:
		return false
	rocks -= 1
	rocks_changed.emit(rocks)
	throwing = 0.28
	var r := World.ThrownRock.new()
	_throw_aim = aim()
	r.position = global_position + Vector2(20.0 * facing, -44) + _throw_aim * 8.0
	r.thrower = self
	if _throw_aim.y == 0.0:
		r.vel = Vector2(THROW_SPEED * facing, -140.0)          # straight ahead: the usual little lob
	else:
		r.vel = _throw_aim * THROW_SPEED * 1.1                 # aimed: up, 45 degrees, or down
	get_parent().add_child(r)
	return true


## Health fruit (a bunch of grapes, or a banana) looks after itself: if he's
## hurt he eats it on the spot; if he isn't, it goes in his pouch, and he eats
## one by himself the moment he gets hurt. No key to press.
func add_berry() -> bool:
	if hp < max_hp and not dead:
		_eat_fruit()
		return true
	if berries >= max_berries:
		return false
	berries += 1
	berries_changed.emit(berries)
	return true


func _eat_fruit() -> void:
	hp = mini(hp + 2, max_hp)
	hp_changed.emit(hp)
	var pop := HeartPop.new()
	pop.position = global_position + Vector2(0, -120)
	get_parent().add_child(pop)


## Hurt, with fruit in the pouch: a moment later (so the hit is felt), he eats one.
func _auto_eat() -> void:
	if dead or berries <= 0 or hp >= max_hp:
		return
	berries -= 1
	berries_changed.emit(berries)
	_eat_fruit()


## Gather -> craft -> ability: berries become a poultice that heals.
## Always reports back, so pressing E never looks like nothing happened.
func use_poultice() -> bool:
	if dead:
		return false
	if berries <= 0:
		poultice.emit(false, "No berries to crush.")
		return false
	if hp >= max_hp:
		poultice.emit(false, "He is not hurt. Save them.")
		return false
	berries -= 1
	hp = mini(hp + 2, max_hp)
	berries_changed.emit(berries)
	hp_changed.emit(hp)
	poultice.emit(true, "He chews the poultice. Two wounds close.")
	return true


## ------------------------------------------------------------------ torch
## Level 2 on. The torch rides in his back hand, so the club stays in front.
func give_torch() -> void:
	has_torch = true
	torch_fuel = 1.0
	add_to_group("light")


func relight(amount: float = 1.0) -> void:
	if amount >= 1.0:
		add_sun(Sunfire.GAIN_FIRE * get_physics_process_delta_time())     # sitting by a fire fills the sun
	if has_torch:
		torch_fuel = maxf(torch_fuel, amount)


func light_radius() -> float:
	if not has_torch or torch_fuel <= 0.0 or dead:
		return 0.0
	return lerpf(TORCH_R_MIN, TORCH_R_MAX, torch_fuel)


## For Night: where the flame is (x, y), how far it reaches (z), how warm (w).
func light() -> Vector4:
	if sun_t > 0.0 and not dead:
		var sr := 430.0 * (1.0 + 0.04 * sin(anim_t * 9.0))
		return Vector4(global_position.x, global_position.y - 40.0, sr, 1.0)
	var r := light_radius()
	if r <= 0.0:
		return Vector4.ZERO
	var tip := to_global(_torch_tip)
	r *= 1.0 + sin(anim_t * 13.0) * 0.012 + sin(anim_t * 7.3 + 1.0) * 0.018
	# his anger feeds the flame: the pool of light swells as the fire builds,
	# which reads from across the screen and pushes the wolves back
	if fury >= 0.0:
		r *= 1.0 + 0.6 * clampf(fury / FURY_RELEASE, 0.0, 1.0)
	return Vector4(tip.x, tip.y, r, 0.9)


## How much the light protects him. The wolves read this, not the radius.
func light_strength() -> float:
	if sun_t > 0.0 and not dead:
		return 1.0
	return torch_fuel if has_torch and not dead else 0.0


func add_wood(n: int = 1) -> bool:
	if wood >= max_wood:
		return false
	wood = mini(wood + n, max_wood)
	wood_changed.emit(wood)
	return true


## Gather -> craft -> ability: dry wood becomes fire. Always reports back.
func start_fire() -> bool:
	if dead or fury >= 0.0:
		return false
	if wood < FIRE_COST:
		said.emit("A fire takes two bundles of wood. Dead trees give it up to the club.")
		return false
	wood -= FIRE_COST
	wood_changed.emit(wood)
	fury = 0.0
	attacking = 0.0
	throwing = 0.0
	return true


func _release_fire() -> void:
	var fb := NightWoods.FireBurst.new()
	fb.position = global_position + Vector2(0, -40)
	get_parent().add_child(fb)
	relight(0.5)
	fire_released.emit()


## Back on his feet at a checkpoint, whole, torch full.
## Down for good: the world slows right down, he's popped up into the air
## with a yelp, and comes down flat on his back — X eyes, tongue out, stars
## going round his head — until the level wakes him by the fire.
const DIE_TIME := 0.55           ## how long the topple takes
var _die_t := 0.0
var _starred := false


## ------------------------------------------------------------ GRAB & THROW
## THROW next to a dazed critter: up it goes, overhead and upside down.
func _try_grab() -> bool:
	if dead or carrying != null or vine != null or wall_cling or stomp_state != "" or talking:
		return false
	var best: Critter = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("critters"):
		var c := n as Critter
		if c == null or not Grab.can_grab(c):
			continue
		var d := c.global_position - global_position
		if d.x * facing < -16.0 or absf(d.x) > Grab.REACH or absf(d.y) > 70.0:
			continue
		if d.length() < best_d:
			best_d = d.length()
			best = c
	if best == null:
		return false
	carrying = best
	_carry_t = 0.0
	best.set_physics_process(false)        # it stops biting: he moves it now
	best.scale.y = -absf(best.scale.y)     # upside down, legs to the sky
	for ch in best.get_children():
		if ch is Grab.Stars:
			ch.queue_free()
	_say_word("HEAVE!", Color("fff4d6"))
	return true


## Holds it up where his hand is, wriggling, the body resting on his palm.
func _carry_step(delta: float) -> void:
	if carrying == null:
		return
	if not is_instance_valid(carrying) or carrying.dying > 0.0:
		carrying = null
		return
	_carry_t += delta
	var h := maxf(carrying._body_height() / 0.9, 22.0)
	carrying.global_position = to_global(_carry_hand) - Vector2(0, h - 4.0)
	carrying.rotation = sin(anim_t * 17.0) * 0.12
	carrying.queue_redraw()


## Away it goes, spinning, into whatever is ahead.
func _hurl() -> void:
	if carrying == null or _carry_t < 0.12:
		return
	var f := Grab.Flight.new()
	f.critter = carrying
	f.dir = facing
	f.thrower = self
	f.vel = Vector2(Grab.THROW_V.x * facing + velocity.x * 0.3, Grab.THROW_V.y + minf(velocity.y, 0.0) * 0.3)
	get_parent().add_child(f)
	carrying = null
	throwing = 0.28
	_say_word("HUP!", Color("ffd36b"))


## Lets go of it (hurt, a vine, death): it drops on its feet beside him.
func _drop_carried() -> void:
	if carrying == null:
		return
	if is_instance_valid(carrying):
		carrying.rotation = 0.0
		carrying.scale.y = absf(carrying.scale.y)
		carrying.global_position = global_position + Vector2(facing * 34.0, 0)
		carrying.set_physics_process(true)
	carrying = null


## ------------------------------------------------------------ THE HOTBAR
## Terraria-style: every tool he has, numbered 1-9, first in the bag's strip (Bag.View).
## Pick one (1-9, the mouse wheel, or tap it) and HIT uses it: a weapon
## swings, the SHOVEL digs wherever he aims, ROCKS are thrown, FIGS eaten.
var tool := "weapon"                 ## "weapon" (the weapon in hand), "shovel", "rocks", "figs"
var _dig_aim := Vector2.DOWN         ## where the shovel was aimed when the blow started
static var ui_click_until := 0       ## a tap on the HUD isn't also a swing (ms)


## The slots, in order: what he has.
func hotbar() -> Array:
	var out: Array = []
	if has_stick:
		for w in ["club", "axe", "hammer"]:
			if w == "club" or GameState.weapons.has(w):
				out.append(w)
	else:
		out.append("hands")
	if GameState.has_item("shovel"):
		out.append("shovel")
	out.append("rocks")
	out.append("figs")
	for id in Bag.HOTBAR:                 # what he has made (the bag's crafting), while he has some
		if Bag.count(self, id) > 0:
			out.append(id)
	return out


## Which slot is in use now.
func hotbar_selected() -> String:
	if tool != "weapon":
		return tool
	if not has_stick:
		return "hands"
	return _weapon()


func select_slot(i: int) -> void:
	var slots := hotbar()
	if i >= 0 and i < slots.size():
		_select(slots[i])


func _select(id: String) -> void:
	if axe_out or slam_charge >= 0.0 or carrying != null:
		return
	match id:
		"club", "axe", "hammer":
			GameState.weapon = id
			axe = id == "axe"
			hammer = id == "hammer"
			tool = "weapon"
		"hands":
			tool = "weapon"
		_:
			tool = id
	attacking = 0.0
	_say_word(HOTBAR_NAMES.get(id, Bag.name_of(id)), Color("fff4d6"))

const HOTBAR_NAMES := {"club": "CLUB", "axe": "FLINT AXE", "hammer": "FIRESTONE HAMMER", "hands": "FISTS",
	"shovel": "SHOVEL", "rocks": "ROCKS", "figs": "ROAST FIGS"}


func _unhandled_input(event: InputEvent) -> void:
	if dead or preview or talking:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = (event as InputEventKey).physical_keycode
		if k >= KEY_1 and k <= KEY_9:
			select_slot(k - KEY_1)
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var slots := hotbar()
			var at := slots.find(hotbar_selected())
			var step := 1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
			select_slot(posmod(at + step, slots.size()))


## ------------------------------------------------------------ AIMING
## Where a swing or a throw goes: the arrows, 8 ways (UP + RIGHT = 45 degrees
## up and right), straight ahead if no up or down is held. (SPACE jumps.)
var _swing_aim := Vector2.RIGHT
var _cyc_q := -1             ## which quarter of the cyclone it is in
var _juggles := 0            ## hits on a beast held up in the air
var _air_kicks := 0          ## air kicks this jump (only the first two lift him)
var _throw_aim := Vector2.RIGHT


func aim() -> Vector2:
	var up: bool = Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W) or touch.get("up", false)
	var down: bool = Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S) or touch.get("down", false)
	var h := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT) or touch["left"]:
		h -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT) or touch["right"]:
		h += 1.0
	var v := -1.0 if up and not down else (1.0 if down and not up else 0.0)
	if v == 0.0:
		return Vector2(float(facing), 0.0)
	return Vector2(h, v).normalized()


## ------------------------------------------------------------ THE COMBO
## Extra damage for a long run of hits (COMBO_DMG).
func combo_bonus() -> int:
	var b := 0
	for s in COMBO_DMG:
		if combo_hits >= int(s[0]):
			b = int(s[1])
	return b


## A hit landed: the run goes on (and at the milestones, he gets told so).
func combo_hit() -> void:
	combo_hits += 1
	_combo_gap = COMBO_GAP
	if COMBO_WORDS.has(combo_hits):
		var w := WordPop.new()
		w.text = COMBO_WORDS[combo_hits]
		w.size = 30
		w.color = Color("ffe066") if combo_hits < 30 else Color("ff7a3a")
		w.star = Color("c0392b", 0.85)
		w.centered = true
		w.life = 1.0
		w.position = global_position + Vector2(0, -150)
		get_parent().add_child(w)


func _combo_step(delta: float) -> void:
	if combo_hits <= 0:
		return
	_combo_gap -= delta
	if _combo_gap <= 0.0:
		combo_hits = 0


func _say_word(text: String, col: Color) -> void:
	var w := WordPop.new()
	w.text = text
	w.size = 20
	w.color = col
	w.centered = true
	w.tilt = randf_range(-0.15, 0.15)
	w.life = 0.55
	w.position = global_position + Vector2(0, -120)
	get_parent().add_child(w)


## Whatever he was in the middle of ends: a death (or a revive) must not leave a
## swing running, a special charged (it would fire the moment he is back), a
## climb or a scorch hanging over him.
func _reset_actions() -> void:
	attacking = 0.0
	attack_cd = 0.0
	slam_charge = -1.0
	_charge_by_hold = false
	_atk_buffer = 0.0
	_attack_held = 0.0
	climbing = false
	digging_down = false
	throwing = 0.0
	scorch_t = 0.0
	combo_hits = 0
	_kick_lock = 0.0


func _die() -> void:
	_drop_carried()
	_reset_actions()
	dead = true
	stomp_state = ""
	if sun_t > 0.0:
		end_sunfire()
	_die_t = 0.0
	if vine != null:
		_let_go(Vector2.ZERO)
	velocity = Vector2(-float(facing) * 150.0, -380.0)
	flip_t = 0.0
	_tumble = 0.0
	_spear = 0.0
	if is_inside_tree():
		Critter.slow_time(get_tree(), 1.3, 0.3)
		var pop := Treasure.FloatText.new()
		pop.text = "OOF!"
		pop.position = global_position + Vector2(-16, -170)
		get_parent().add_child.call_deferred(pop)
	died.emit()


func revive(spot: Vector2) -> void:
	if vine != null:
		_let_go(Vector2.ZERO)
	dead = false
	_die_t = 0.0
	_starred = false
	for c in get_children():
		if c is Critter.Dizzy:
			c.queue_free()
	global_position = spot
	velocity = Vector2.ZERO
	knock = 0.0
	fury = -1.0
	hp = max_hp
	invuln = 1.6
	if has_torch:
		torch_fuel = 1.0
	hp_changed.emit(hp)
	_reset_actions()
	getup = 0.0                  # back from the dead: SPLAT, up, and a flex


## ------------------------------------------------------------------ drawing
## He is designed at about 2.6x game size and scaled down in one transform.
## Facing is folded into the same transform (a negative x scale), so none of
## the shapes below need to know which way he is looking.
const ART := 0.42        ## design units -> game pixels. ~186 tall -> ~78 px (the topknot on top)
const OLW := 5.0         ## rim width in design units (~2 px on screen)
## Shapes are drawn twice — a shadow tone, then the base tone pulled toward the
## light — so each form has a shaded edge instead of a flat colour and a black
## line. The sun in the sky sits high and right, so the light comes from there.
const LIGHT := Vector2(0.55, -0.83)

const C_OL := Color("2a211a")
const C_SKIN := Color("c89263")
const C_SK2 := Color("a67148")
const C_HAIR := Color("5a2c18")      ## a rich dark chestnut: natural, but warm enough to read on the night
const C_HAIR_HI := Color("94512a")   ## lighter streaks in it
## The head is drawn bigger than life (like most platformer heroes): the face is
## what reads from far away. Scaled about the neck, mane, face and topknot together.
const HEAD_K := 1.2
const NECK := Vector2(4, -126)
const C_LEOPARD := Color("d9a64e")   ## his leopard-skin loincloth
const C_LEOPARD_SPOT := Color("4a2a14")
const C_LEAF := Color("6a8447")
const C_LEAF2 := Color("55703a")
const C_VINE := Color("6a5535")
const C_WOOD := Color("846141")
const C_WOOD2 := Color("5a4029")
const C_EYE := Color("ece3cd")
const C_MOUTH := Color("33211a")
var _skin := C_SKIN      ## flushes toward ember while he is winding up the fire

## The mane: a wild shock of spikes swept back off his head, [angle deg, length]
## from MANE_C, going from the front of the crown round the back to the nape.
const MANE_C := Vector2(2, -158)
const MANE_SPIKES := [[-52.0, 36.0], [-76.0, 46.0], [-100.0, 50.0], [-124.0, 50.0], [-148.0, 47.0],
	[-171.0, 43.0], [-194.0, 38.0], [-216.0, 30.0]]
## The beard and the fringe (painted with fur); the face is the original, front on.
const BEARD := [
	Vector2(-19, -144), Vector2(-21, -138), Vector2(-17, -131), Vector2(-12, -124),
	Vector2(-7, -119), Vector2(-1, -123), Vector2(4, -116), Vector2(9, -122),
	Vector2(15, -118), Vector2(20, -125), Vector2(25, -130), Vector2(29, -139),
	Vector2(27, -144), Vector2(20, -142), Vector2(12, -144), Vector2(4, -142),
	Vector2(-4, -144), Vector2(-12, -142),
]
const FRINGE := [
	Vector2(-20, -164), Vector2(-22, -172), Vector2(-14, -180), Vector2(-8, -175),
	Vector2(-1, -184), Vector2(6, -177), Vector2(12, -186), Vector2(18, -178),
	Vector2(26, -176), Vector2(28, -166), Vector2(22, -167), Vector2(15, -171),
	Vector2(8, -168), Vector2(1, -172), Vector2(-6, -168), Vector2(-13, -170),
]
const FACE := Vector2.ZERO      ## (the features could sit toward his facing; front on now)
const FUR := preload("res://common/art/fur.png")
const FUR_GREY := preload("res://common/art/fur_grey.png")
var _hair_off := Vector2.ZERO   ## how far the hair tips trail his motion (a spring)
var _hair_vel := Vector2.ZERO



## ------------------------------------------------------------ one draw call
## Everything drawn here is collected into one Batch and handed to the GPU as
## a SINGLE draw call. Drawn shape by shape, a wolf was ~30 draw calls and the
## caveman ~200 — every frame — which is what made busy scenes stutter. The
## _ln / _pl / _cc / _pg / _rc / _ac / _st / _stm helpers stand in for
## draw_line / draw_polyline / draw_circle / draw_colored_polygon / draw_rect /
## draw_arc / draw_set_transform / draw_set_transform_matrix.
var _bb: Batch = null


func _draw() -> void:
	_bb = Batch.new()
	_furs.clear()
	_paint()
	# the furred shapes (mane, beard, loincloth), textured, each in its place
	# among the rest: the batch is drawn in pieces, cut where each was asked for
	var at := 0
	for f in _furs:
		_bb.draw_range(self, at, f[5])
		at = f[5]
		draw_set_transform_matrix(f[3])
		draw_colored_polygon(f[0], f[1], f[4], f[2])
		var ring: PackedVector2Array = f[0].duplicate()
		ring.append(f[0][0])
		draw_polyline(ring, f[1].darkened(0.62), OLW * 0.62)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	_bb.draw_range(self, at, _bb.points.size())
	_bb = null


## A shape covered in a fur texture (`tex`, tinted `col`), in its place in the
## painting order. The hair is laid on a slant, along the shape.
var _furs: Array = []
func _fur(pts: PackedVector2Array, tex: Texture2D, col: Color, tex_scale := 1.0) -> void:
	if _bb == null:
		_shape(pts, col)
		return
	var uv := PackedVector2Array()
	var ts := tex.get_size() * 0.5 * tex_scale
	for p in pts:
		uv.append(p.rotated(0.75) / ts)
	_furs.append([pts, col, tex, _bb.xf, uv, _bb.points.size()])


## A closed curve rounded through the control points (a quadratic B-spline).
func _smooth(ctrl: Array, n: int = 4) -> PackedVector2Array:
	var out := PackedVector2Array()
	var m := ctrl.size()
	for i in m:
		var a: Vector2 = (ctrl[(i - 1 + m) % m] + ctrl[i]) * 0.5
		var b: Vector2 = (ctrl[i] + ctrl[(i + 1) % m]) * 0.5
		out.append_array(_quad(a, ctrl[i], b, n))
	return out


func _segs(r: float) -> int:
	return clampi(int(r * 0.7) + 8, 8, 28)


func _ln(a: Vector2, b: Vector2, col: Color, w: float = -1.0, _aa: bool = false) -> void:
	if _bb == null:
		draw_line(a, b, col, w, _aa)
		return
	_bb.line(a, b, col, maxf(w, 1.0))


func _pl(pts: PackedVector2Array, col: Color, w: float = -1.0, _aa: bool = false) -> void:
	if _bb == null:
		draw_polyline(pts, col, w, _aa)
		return
	_bb.polyline(pts, col, maxf(w, 1.0))


func _cc(c: Vector2, r: float, col: Color, filled: bool = true, w: float = -1.0, _aa: bool = false) -> void:
	if _bb == null:
		draw_circle(c, r, col, filled, w, _aa)
		return
	if r <= 0.05:
		return
	if filled:
		_bb.circle(c, r, col, _segs(r))
	else:
		_bb.arc(c, r, 0.0, TAU, _segs(r), col, maxf(w, 1.0))


func _pg(pts: PackedVector2Array, col: Color) -> void:
	if _bb == null:
		draw_colored_polygon(pts, col)
		return
	_bb.poly(pts, col)


func _rc(r: Rect2, col: Color, filled: bool = true, w: float = -1.0, _aa: bool = false) -> void:
	if _bb == null:
		draw_rect(r, col, filled, w, _aa)
		return
	if filled:
		_bb.rect(r, col)
	else:
		_bb.polyline(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]), col, maxf(w, 1.0))


func _ac(c: Vector2, r: float, a0: float, a1: float, n: int, col: Color, w: float = -1.0, _aa: bool = false) -> void:
	if _bb == null:
		draw_arc(c, r, a0, a1, n, col, w, _aa)
		return
	_bb.arc(c, r, a0, a1, maxi(n, 2), col, maxf(w, 1.0))


func _st(pos: Vector2 = Vector2.ZERO, rot: float = 0.0, sc: Vector2 = Vector2.ONE) -> void:
	if _bb == null:
		draw_set_transform(pos, rot, sc)
		return
	_bb.set_xf(Transform2D(rot, sc, 0.0, pos))


func _stm(m: Transform2D) -> void:
	if _bb == null:
		draw_set_transform_matrix(m)
		return
	_bb.set_xf(m)


func _paint() -> void:
	var on_floor := is_on_floor() or preview
	var air := not on_floor and not dead
	var speed_k := clampf(absf(velocity.x) / SPEED, 0.0, 1.0) if on_floor else 0.0
	var running := speed_k > 0.08 and not dead
	var ph := _run_phase
	var boxing := attacking > 0.0 and not has_stick and throwing <= 0.0 and not _kicking()
	var wince := invuln > 0.8 and not dead
	var tumble := _tumble if air else 0.0
	var spear := _spear * (1.0 - _tumble) if air else 0.0
	# the anger: builds 0 -> 1 through the wind-up, then the snarl
	var rage := 0.0
	var roaring := false
	if fury >= 0.0:
		rage = clampf(fury / FURY_RELEASE, 0.0, 1.0)
		roaring = fury >= FURY_RELEASE
	_sun_k = move_toward(_sun_k, 1.0 if sun_t > 0.0 and not dead else 0.0, get_process_delta_time() * 3.5)
	_skin = C_SKIN.lerp(Pal.EMBER, 0.22 * rage) if rage > 0.0 else C_SKIN
	_hands.clear()
	if sun_t > 0.0:
		_skin = _skin.lerp(Sunfire.GOLD, 0.3 + 0.12 * sin(anim_t * 9.0))
		_paint_sun_aura()

	# ---- whole-body squash and stretch, pivoting on his feet so they stay planted
	var sx := 1.0
	var sy := 1.0
	var land_k := 0.0
	if _land > 0.0:
		land_k = sin(_land / LAND_TIME * PI) * _land_amt
		sx += 0.14 * land_k
		sy -= 0.16 * land_k
	elif air:
		var st := clampf(-velocity.y / 1600.0, -0.05, 0.09)
		sx -= st * 0.6
		sy += st
		# tumbling: stretched by the rushing air, with a jelly wobble
		sy += (0.07 + sin(anim_t * 19.0) * 0.03) * tumble
		sx -= (0.04 + sin(anim_t * 19.0) * 0.02) * tumble
	var gu := getup if on_floor and not dead else -1.0
	if gu >= 0.0:
		if gu < GETUP_SPLAT:
			# SPLAT: flattened like a pancake, wobbling
			var w := sin(gu * 40.0) * 0.05 * (1.0 - gu / GETUP_SPLAT)
			sx = 1.38 + w
			sy = 0.5 - w
		elif gu < GETUP_FLEX:
			# BOING: back up, stretched tall
			var q := (gu - GETUP_SPLAT) / (GETUP_FLEX - GETUP_SPLAT)
			sx = lerpf(1.38, 1.0, q) - 0.1 * sin(q * PI)
			sy = lerpf(0.5, 1.0, q) + 0.2 * sin(q * PI)
		else:
			# the flex: chest out, a proud little puff
			var q2 := clampf((gu - GETUP_FLEX) / 0.15, 0.0, 1.0)
			sx = 1.0 + 0.05 * q2
			sy = 1.0 + 0.04 * q2
	if _sun_k > 0.0:
		# SUNFIRE: he grows, a pop past full size and back
		var grow := 1.0 + 0.15 * _sun_k + 0.06 * sin(_sun_k * PI)
		sx *= grow
		sy *= grow
	if stomp_state == "dive" or stomp_state == "dash":
		# a meteor: stretched long and thin by the speed
		sx -= 0.12 + 0.04 * stomp_level
		sy += 0.16 + 0.06 * stomp_level
	if fury >= 0.0:
		if not roaring:
			# hunched and gathering
			sx += 0.05 * rage
			sy -= 0.06 * rage
		else:
			# and then he rears up as it leaves him
			var pop := 1.0 - clampf((fury - FURY_RELEASE) / 0.15, 0.0, 1.0)
			sy += 0.06 * pop
			sx -= 0.03 * pop
	# dead: he topples over backwards onto his back, with a little bounce at the end
	var rot := 0.0
	if dead:
		var dk := clampf(_die_t / DIE_TIME, 0.0, 1.0)
		var back_out := 1.0 + 2.2 * pow(dk - 1.0, 3.0) + 1.2 * pow(dk - 1.0, 2.0)
		rot = -float(facing) * PI * 0.5 * back_out
	var base := Transform2D(rot, Vector2(ART * facing * sx, ART * sy), 0.0, Vector2.ZERO)
	if wall_cling and not is_on_floor() and not dead:
		base.origin.x -= float(facing) * 12.0       # drawn just off the wall he clings to, not sunk into it
	if vine != null and not dead:
		# on a vine the body hangs along it, swinging from the grip
		var grip := Vector2(0, -HANG)
		base = Transform2D(-_vine_a * 0.9, grip) * Transform2D(0.0, -grip) * base
	if stomp_state == "dash" and not dead:
		# the dash: laid out flat, head first, like a thrown spear
		var mid := Vector2(0, -38)
		base = Transform2D(0.0, mid) * Transform2D(float(stomp_dir) * PI * 0.5, Vector2.ZERO) * Transform2D(0.0, -mid) * base
	var curl := 0.0                 ## 1 = curled into a ball; 0 = open
	var open_k := 0.0               ## 1 = opened out for the landing
	if flip_t > 0.0:
		var k := 1.0 - flip_t / flip_len
		# the spin: all of it in the curled part, finished as he opens out
		var spin_k := clampf(k / 0.78, 0.0, 1.0)
		var ang := flip_dir * TAU * flip_turns * (spin_k * spin_k * (3.0 - 2.0 * spin_k))
		curl = clampf(k / 0.12, 0.0, 1.0) * (1.0 - clampf((k - 0.72) / 0.12, 0.0, 1.0))
		open_k = clampf((k - 0.72) / 0.2, 0.0, 1.0)
		var pivot := Vector2(0, -38)
		# the ghosts of the ball, fading along the arc behind him
		_stm(Transform2D.IDENTITY)
		for g in _ghosts:
			var a := float(g[1]) / 0.22
			var at: Vector2 = (g[0] as Vector2) - global_position
			_cc(at, 17.0, Color(C_SKIN, 0.28 * a))
			_cc(at + Vector2(-flip_dir * 4.0, -6.0), 8.0, Color(C_HAIR, 0.3 * a))
		# the whoosh: bright arcs where his head just swept round
		if curl > 0.3:
			var hot := Color(1.0, 0.9, 0.55) if _air_glide else Color(0.85, 0.95, 1.0)
			var head_a := -PI * 0.5 + ang
			for w in 3:
				var a0 := head_a - flip_dir * (0.4 + 0.55 * w)
				var a1 := head_a - flip_dir * 0.1
				_ac(pivot, 52.0 + w * 10.0, minf(a0, a1), maxf(a0, a1), 12, Color(hot, (0.95 - w * 0.25) * curl), 10.0 - w * 2.5)
		# a ball is smaller than a man: squeeze him in while he's curled
		base = Transform2D(0.0, pivot) * Transform2D(ang, Vector2.ONE * (1.0 - 0.14 * curl)) * Transform2D(0.0, -pivot) * base

	var kick_k := -1.0              ## 0 -> 1 through an air kick; -1: not kicking
	if _kicking() and not dead:
		kick_k = 1.0 - attacking / _swing_time
		if _swing_kind == "kick2":
			# the FLASH KICK: a whole backflip, the lead leg held straight out
			var e := kick_k * kick_k * (3.0 - 2.0 * kick_k)
			var kp := Vector2(0, -38)
			base = Transform2D(0.0, kp) * Transform2D(-float(facing) * TAU * e, Vector2.ONE) * Transform2D(0.0, -kp) * base

	# ---- pelvis: rises through each stride, sinks on a landing, leans into a run
	var bob := land_k * 9.0
	var lean := 0.0
	if running:
		bob -= absf(sin(ph)) * 7.0 * speed_k
		lean = 0.14 * speed_k
	elif air:
		lean = 0.06
	if flip_t > 0.0:
		lean = 0.5 * curl - 0.1 * open_k      # curled forward into the ball
	lean = lerpf(lean, 0.16, spear)                                  # driving forward into the dive
	if attacking > 0.0 and _swing_kind == "ram":
		lean += 0.32                                                  # head down, charging
	if attacking > 0.0 and _swing_kind == "dig" and has_stick:
		# digging: stretched up for the lift, hunched over the blow
		var dp := 1.0 - attacking / _swing_time
		lean += -0.08 if dp < 0.45 else 0.32 * sin(clampf((dp - 0.45) / 0.5, 0.0, 1.0) * PI)
		bob += 0.0 if dp < 0.45 else 10.0 * sin(clampf((dp - 0.45) / 0.5, 0.0, 1.0) * PI)
	if attacking > 0.0 and _swing_kind == "club2" and has_stick:
		# the finisher: rearing back, then thrown forward into the blow
		var fp := 1.0 - attacking / _swing_time
		lean += -0.14 * sin(clampf(fp / 0.45, 0.0, 1.0) * PI * 0.5) if fp < 0.45 else 0.3 * sin(clampf((fp - 0.45) / 0.55, 0.0, 1.0) * PI)
	lean = lerpf(lean, -0.08 + sin(anim_t * 11.0) * 0.17, tumble)   # rocking as he flails
	if fury >= 0.0 and not roaring:
		bob += 7.0 * rage
	if wall_cling and not on_floor:
		bob += 4.0 * sin(anim_t * 22.0)          # heaving himself up with each pull
		lean = 0.12
	var shake := Vector2.ZERO
	if fury >= 0.0 and not roaring:
		shake = Vector2(sin(anim_t * 71.0) * 2.6, cos(anim_t * 89.0) * 1.8) * rage

	# ---- legs, solved with two-bone IK so the knees always bend the right way
	_stm(base)
	var hip_b := Vector2(-14, -62.0 + bob)
	var hip_f := Vector2(22, -62.0 + bob)
	# standing: feet planted straight under the hips
	var foot_b := Vector2(-16, -6)
	var foot_f := Vector2(24, -6)
	var bend := 0.0
	if air and flip_t > 0.0:
		bend = 1.0
		foot_f = Vector2(34, -28).lerp(Vector2(22, -62), curl).lerp(Vector2(34, -4), open_k)
		foot_b = Vector2(-26, -26).lerp(Vector2(-2, -60), curl).lerp(Vector2(-28, -8), open_k)
		if flip_back:
			foot_f = foot_f.lerp(Vector2(30, -40), curl * 0.6)
	elif air:
		bend = 1.0
		if vine != null:
			# legs trail the swing, and kick forward when he pumps it
			var swg := clampf(_vine_w / 3.0, -1.0, 1.0) * float(facing)
			foot_f = Vector2(18.0 - 26.0 * swg, -12.0 - 14.0 * absf(swg))
			foot_b = Vector2(-12.0 - 26.0 * swg, -6.0 - 10.0 * absf(swg))
		elif wall_cling:
			# scrambling up the wall: the feet take turns, pushing
			var cl := anim_t * 11.0
			foot_f = Vector2(40, -54.0 + 16.0 * sin(cl))
			foot_b = Vector2(34, -14.0 - 16.0 * sin(cl))
		elif velocity.y < -150.0:
			foot_f = Vector2(42, -36)      # lead knee drives up
			foot_b = Vector2(-32, -12)     # trail leg hangs back
		elif velocity.y < 180.0:
			foot_f = Vector2(34, -28)      # tucked at the top
			foot_b = Vector2(-26, -26)
		else:
			foot_f = Vector2(30, -6)       # reaching for the ground
			foot_b = Vector2(-24, -12)
		if tumble > 0.0:
			# running on thin air, like a cartoon who has just looked down
			var pp := anim_t * 22.0
			foot_f = foot_f.lerp(Vector2(28.0 + cos(pp) * 26.0, -22.0 + sin(pp) * 20.0), tumble)
			foot_b = foot_b.lerp(Vector2(-18.0 + cos(pp + PI) * 26.0, -22.0 + sin(pp + PI) * 20.0), tumble)
	elif not dead:
		# eases between standing and full stride, so stopping does not pop
		var w := clampf(speed_k * 4.0, 0.0, 1.0)
		foot_f = foot_f.lerp(_run_foot(hip_f.x, ph, speed_k), w)
		foot_b = foot_b.lerp(_run_foot(hip_b.x, ph + PI, speed_k), w)
		bend = maxf(w, land_k)
		if land_k > 0.0:
			foot_f.x += 6.0 * land_k
			foot_b.x -= 6.0 * land_k
		if fury >= 0.0:
			# a wide, braced stance while it builds
			bend = maxf(bend, 0.7 * rage)
			foot_f.x += 8.0 * rage
			foot_b.x -= 8.0 * rage
	if kick_k >= 0.0:
		bend = 1.0
		if _swing_kind == "kick1":
			# the SNAP KICK: knee chambered... then the foot whipped straight up over his head
			var up := sin(clampf(kick_k / 0.55, 0.0, 1.0) * PI * 0.5) * (1.0 - 0.45 * clampf((kick_k - 0.7) / 0.3, 0.0, 1.0))
			foot_f = Vector2(44, -40).lerp(Vector2(72, -108), up)
			foot_b = Vector2(-22, -14)
		else:
			foot_f = Vector2(62, -110)       # straight out: the flip carries it round
			foot_b = Vector2(-8, -32)        # the other tucked
	if spear > 0.0:
		# the lead leg reaching out in front, the back one tucked up behind
		foot_f = foot_f.lerp(Vector2(58, -30), spear)
		foot_b = foot_b.lerp(Vector2(-34, -46), spear)
		bend = 1.0
	_leg(hip_b, foot_b, bend)
	_leg(hip_f, foot_f, bend)
	if tumble > 0.0:
		# wind streaks rushing up past him
		for i in 5:
			var q := fmod(anim_t * 3.2 + i * 0.37, 1.0)
			var wx := -52.0 + i * 26.0 + sin(i * 2.3) * 6.0
			var wy := -20.0 - q * 260.0
			_ln(Vector2(wx, wy), Vector2(wx, wy - 46.0), Color(1, 1, 1, 0.75 * (1.0 - q) * tumble), 4.0)

	# ---- everything above the waist leans and bobs as one piece
	var upper := base * Transform2D(lean, Vector2(shake.x, -62.0 + bob + shake.y)) * Transform2D(0.0, Vector2(0, 62))
	_stm(upper)

	var head_xf := upper * Transform2D(0.0, Vector2(HEAD_K, HEAD_K), 0.0, NECK * (1.0 - HEAD_K))
	var face_xf := head_xf * Transform2D(0.0, FACE)
	# the hair trails his motion on a spring: streams back in a run, flies up
	# in a fall, flops down and bounces on a landing
	# (the step is capped: after one long frame (a hitch) a stiff spring stepped
	# raw blows up to INF/NaN, and NaN hair is hundreds of errors every frame after)
	var dt := minf(get_process_delta_time(), 1.0 / 30.0)
	var hair_to := Vector2(-clampf(velocity.x * facing / SPEED, -1.6, 1.6) * 11.0,
		clampf(-velocity.y / 900.0, -1.2, 1.2) * 10.0) if not dead and velocity.is_finite() else Vector2.ZERO
	_hair_vel += ((hair_to - _hair_off) * 140.0 - _hair_vel * 11.0) * dt
	_hair_off += _hair_vel * dt
	if not (_hair_off.is_finite() and _hair_vel.is_finite()):
		_hair_off = Vector2.ZERO
		_hair_vel = Vector2.ZERO
	_hair_off = _hair_off.limit_length(40.0)
	_stm(head_xf)
	_mane()
	_stm(upper)
	_costume_back()
	# spare wood rides tucked in the belt at his back, behind the body
	for i in wood:
		var wx := -20.0 - i * 6.0
		_ln(Vector2(wx, -60), Vector2(wx - 22, -104), Pal.DEADWOOD_DARK, 9.0, true)
		_ln(Vector2(wx, -60), Vector2(wx - 22, -104), Pal.DEADWOOD, 5.0, true)
	_oval(Vector2(4, -130), 17.0, 10.0, _skin)
	# a hero's chest: broad shoulders tapering to the waist
	var torso := PackedVector2Array([Vector2(-50, -124)])
	torso.append_array(_quad(Vector2(-50, -124), Vector2(4, -142), Vector2(58, -124)))
	torso.append_array(_quad(Vector2(58, -124), Vector2(50, -90), Vector2(30, -68)))
	torso.append(Vector2(-22, -68))
	torso.append_array(_quad(Vector2(-22, -68), Vector2(-40, -90), Vector2(-50, -124)))
	torso.remove_at(torso.size() - 1)
	_shape(torso, _skin)
	# pecs, lit on the top; soft abs
	_fan(_quad(Vector2(-32, -118), Vector2(-14, -98), Vector2(2, -110), 8, true), Color(1, 0.95, 0.85, 0.16))
	_fan(_quad(Vector2(6, -110), Vector2(24, -98), Vector2(44, -118), 8, true), Color(1, 0.95, 0.85, 0.16))
	_pl(_quad(Vector2(-32, -114), Vector2(-14, -98), Vector2(2, -108), 8, true), C_SK2, 3.5, true)
	_pl(_quad(Vector2(6, -108), Vector2(24, -98), Vector2(44, -114), 8, true), C_SK2, 3.5, true)
	var ab := Color(C_SK2, 0.55)
	_ln(Vector2(4, -98), Vector2(4, -76), ab, 2.5, true)
	for yy in [-92.0, -84.0]:
		_ln(Vector2(-6, yy), Vector2(2, yy + 1.0), ab, 2.5, true)
		_ln(Vector2(6, yy + 1.0), Vector2(14, yy), ab, 2.5, true)
	# a little tuft of chest hair
	for k in 3:
		_ln(Vector2(-1.0 + k * 5.0, -110), Vector2(-3.0 + k * 5.0 + (k - 1) * 2.0, -102), C_HAIR, 3.0, true)
	if _sun_k > 0.0:
		# the muscles lit from inside, gold
		var gl := Color(Sunfire.WHITE_HOT, 0.6 * _sun_k)
		_pl(_quad(Vector2(-32, -114), Vector2(-14, -100), Vector2(2, -108), 8, true), gl, 2.5, true)
		_pl(_quad(Vector2(6, -108), Vector2(22, -100), Vector2(40, -114), 8, true), gl, 2.5, true)
		_ln(Vector2(4, -100), Vector2(4, -74), gl, 2.0, true)
		for yy in [-94.0, -86.0, -78.0]:
			_ln(Vector2(-6, yy), Vector2(14, yy), gl, 2.0, true)
	_costume_chest()

	# far arm: pumps against the legs when running
	var back_sh := Vector2(-42, -118)
	if has_torch and not boxing:
		_torch_arm(back_sh, running, air, ph, speed_k, rage, upper)
	elif carrying != null:
		# the other hand up too, steadying it
		_arm(back_sh, back_sh + Vector2(16, -44), back_sh + Vector2(44, -96), 11.0, true)
	elif not boxing:
		var fa := _pose_arm(back_sh, -1.0, running, air, ph, speed_k)
		_arm(back_sh, fa[0], fa[1], 10.0, true)

	if costume >= 2:
		_hide_loincloth(speed_k)
		_seat_flames()
	else:
		for i in 6:
			var lx := -21.0 + i * 10.0
			var ang := (i - 2.5) * 0.11 + sin(anim_t * 2.2 + i) * 0.045 - speed_k * 0.18
			_leaf(Vector2(lx, -70), 29.0 + (3.0 if i % 2 == 1 else 0.0), 8.0, ang, C_LEAF2 if i % 2 == 1 else C_LEAF)
	var belt := _quad(Vector2(-25, -71), Vector2(4, -66), Vector2(33, -71), 10, true)
	_pl(belt, C_OL, 12.0, true)
	_pl(belt, C_VINE, 7.0, true)
	for i in 7:
		var bx := -20.0 + i * 8.0
		_ln(Vector2(bx - 2, -73), Vector2(bx + 2, -68), C_WOOD2, 2.0, true)
	for i in berries:
		_grapes(Vector2(-30.0 + i * 11.0, -80), 0.5)
	_costume_belt()
	for i in mini(rocks, 3):
		_dot(Vector2(36.0 + i * 10.0, -62), 6.5, Pal.STONE, 2.5)

	# ---- head: a warm, cheeky face (he scowls only in a fight or a rage)
	_stm(head_xf)
	# big ears that stick out
	_dot(Vector2(-23, -150), 9.0, _skin, 4.0)
	_dot(Vector2(31, -150), 9.0, _skin, 4.0)
	# a little curved fang hanging from that ear, swinging with him
	var ear_sw := clampf(_hair_off.x * 0.04, -0.6, 0.6) + sin(anim_t * 3.0) * 0.08
	var e0 := Vector2(33, -142)
	var dn := Vector2(sin(ear_sw), cos(ear_sw))
	var sd := Vector2(dn.y, -dn.x)
	_cc(e0, 2.2, C_OL)
	_shape(PackedVector2Array([e0 + dn * 2.0 - sd * 3.2, e0 + dn * 2.0 + sd * 3.2, e0 + dn * 9.0 + sd * 1.6, e0 + dn * 13.0 - sd * 1.5]), Pal.KEY_BONE, 2.0)
	_cc(Vector2(-26, -150), 3.5, C_SK2)
	_cc(Vector2(34, -150), 3.5, C_SK2)
	# his mood, for the funny faces
	_idle_t = _idle_t + get_process_delta_time() if on_floor and speed_k < 0.05 and attacking <= 0.0 and not talking and not dead and fury < 0.0 else 0.0
	var mood := ""
	if wall_cling and not on_floor:
		mood = "strain"
	elif on_floor and speed_k > 0.85 and attacking <= 0.0 and sun_t <= 0.0:
		mood = "run"
	elif air and velocity.y < -200.0 and flip_t <= 0.0 and tumble < 0.3 and vine == null:
		mood = "ooh"
	elif _idle_t > 5.0 and fmod(_idle_t - 5.0, 9.0) < 1.6:
		mood = "yawn"
	_oval(Vector2(4, -154), 24.0, 27.0, _skin)
	_fur(PackedVector2Array(BEARD), FUR, C_HAIR.lightened(0.18), 0.6)
	_costume_face()
	if skin == "war_paint":
		for k in 3:
			_ln(Vector2(-14 + k * 12, -104), Vector2(-4 + k * 12, -86), Pal.EMBER, 4.0, true)
	elif skin == "bone_necklace":
		var cord := PackedVector2Array()
		for k in 9:
			var x := -16.0 + k * 5.2
			cord.append(Vector2(x, -114.0 + sin(k / 8.0 * PI) * 12.0))
		_pl(cord, C_VINE, 2.5, true)
		for k in [1, 3, 5, 7]:
			var bp: Vector2 = cord[k]
			_oval(bp + Vector2(0, 4), 2.6, 5.5, Pal.KEY_BONE, 1.5)
	if roaring:
		_roar()
	elif dead:
		_dead_mouth()
	elif tumble > 0.5:
		_yell()
	elif gu >= 0.0 and gu < GETUP_SPLAT:
		_dead_mouth()
	elif gu >= GETUP_FLEX:
		_grin()
	elif sun_t > 0.0 and attacking <= 0.0:
		_grin()                                # SUNFIRE: a fierce, delighted grin
	elif vine != null and absf(_vine_w) > 1.6:
		_grin()                                # wheee!
	elif mood == "strain" and not wince:
		_tongue_out(false)                     # tongue poking out: concentrating hard
	elif mood == "run" and not wince:
		_tongue_out(true)                      # tongue flapping like a happy dog
	elif mood == "ooh":
		_oval(Vector2(4, -135), 4.5, 5.5, C_MOUTH, 2.2)
	elif mood == "yawn":
		_oval(Vector2(4, -134), 7.5, 9.0 * sin(clampf(fmod(_idle_t - 5.0, 9.0) / 1.6, 0.0, 1.0) * PI) + 2.0, C_MOUTH, 2.2)
	elif attacking > 0.0 or slam_charge >= 0.0 or wall_cling or wince or scorch_t > 0.0:
		_mouth()                               # teeth gritted: effort
	else:
		_smile()
	# rosy cheeks
	for ch in [Vector2(-15, -140), Vector2(24, -140)]:
		_cc(ch, 5.0, Color(0.93, 0.45, 0.42, 0.26))
	# a button nose
	_nose()
	var blink := fmod(anim_t, 3.7) < 0.12
	if dead:
		# X for eyes
		for ec in [Vector2(-7, -151), Vector2(15, -151)]:
			_ln(ec + Vector2(-5, -5), ec + Vector2(5, 5), C_OL, 3.0, true)
			_ln(ec + Vector2(-5, 5), ec + Vector2(5, -5), C_OL, 3.0, true)
	elif tumble > 0.5 and not wince:
		# eyes like saucers
		for ec in [Vector2(-7, -152), Vector2(15, -152)]:
			_oval(ec, 7.5, 7.0, C_EYE, 3.0)
			_cc(ec + Vector2(1.5 + sin(anim_t * 23.0), 1.0), 2.2, Color("1a0f08"))
	else:
		# one eye a bit bigger than the other: goofy, and his own
		var shut := blink or mood == "yawn"
		_eye(Vector2(-8, -149), wince, shut or mood == "strain", 0.96, -1.0)
		_eye(Vector2(16, -150), wince, shut, 1.08, 1.0)
		if mood == "strain":
			# sweat flying off his brow
			var q := fmod(anim_t * 1.8, 1.0)
			_cc(Vector2(-22.0 - q * 10.0, -166.0 + q * 18.0), 3.2 * (1.0 - q * 0.5), Color("bfe6ff", 0.9 * (1.0 - q)))
	# brows: soft and a little raised at rest (friendly); a V only when it's on
	var inner := 8.0 if wince else -1.5
	if attacking > 0.0 or slam_charge >= 0.0:
		inner = 6.0
	if fury >= 0.0:
		inner = 12.0
	if tumble > 0.5:
		inner = -7.0                          # shot up in alarm
	if dead:
		inner = 0.0                           # no more scowling
	if gu >= GETUP_FLEX:
		inner = -4.0                          # brows up: proud of himself
	if tumble > 0.0:
		# hair blown straight up, flapping
		for k in 4:
			var hx := -14.0 + k * 11.0
			var fl := sin(anim_t * 30.0 + k * 1.7) * 5.0
			_pg(PackedVector2Array([Vector2(hx - 6.0, -172), Vector2(hx + 6.0, -172), Vector2(hx + fl, -172.0 - 26.0 * tumble)]), C_HAIR)
		# sweat flying off him
		for k in 2:
			var q := fmod(anim_t * 2.6 + k * 0.5, 1.0)
			var side := -1.0 if k == 0 else 1.0
			var dp := Vector2(4.0 + side * (30.0 + q * 34.0), -166.0 - q * 30.0 + q * q * 40.0)
			_cc(dp, 4.0 * tumble * (1.0 - q * 0.5), Color("bfe6ff", 0.9 * (1.0 - q)))
	# THE UNIBROW: his trademark, sculpted (_brows)
	if mood == "strain":
		inner = 5.0
	elif mood == "ooh" or mood == "yawn":
		inner = -5.0
	_brows(inner)
	_fur(PackedVector2Array(FRINGE), FUR, C_HAIR, 0.6)
	_stm(face_xf)
	if not skin in ["wolf_hood", "bear_cloak"]:
		_topknot()
	if skin == "war_paint":
		_rc(Rect2(-12, -161, 36, 3.5), Pal.EMBER)
	_costume_head()
	if gu >= 0.0 and gu < GETUP_FLEX:
		# seeing stars
		for k in 3:
			var a := anim_t * 9.0 + k * TAU / 3.0
			var sp := Vector2(4.0 + cos(a) * 34.0, -182.0 + sin(a) * 9.0)
			_pg(PackedVector2Array([sp + Vector2(0, -7), sp + Vector2(2, -2), sp + Vector2(7, 0), sp + Vector2(2, 2), sp + Vector2(0, 7), sp + Vector2(-2, 2), sp + Vector2(-7, 0), sp + Vector2(-2, -2)]), Color("ffd84a"))
	if _bb != null:
		_head_at = _bb.xf * Vector2(4, -168)
	_soot_face()
	if fury >= 0.0:
		_rage_marks(rage, roaring)

	_stm(upper)
	# ---- the near arm: fists, throw, club swing, club carry, or pumping
	var sh := Vector2(50, -118)
	var charge_k := clampf(slam_charge / _charge_ready(), 0.0, 1.0) if slam_charge >= 0.0 else 0.0
	if gu >= GETUP_FLEX and attacking <= 0.0 and throwing <= 0.0:
		# the flex: bicep up, fist by his ear, the club held up like a trophy
		var hd := sh + Vector2(18, -64)
		_arm(sh, sh + Vector2(40, -8), hd, 17.0, true)
		if has_stick and not axe_out:
			_club(hd + Vector2(-4, 14), hd + Vector2(8, -96), 7.0, 26.0)
		# a glint off the bicep
		var gl := sh + Vector2(36, -22)
		var r := 7.0 + sin(anim_t * 18.0) * 2.5
		_pg(PackedVector2Array([gl + Vector2(0, -r), gl + Vector2(r * 0.25, 0), gl + Vector2(0, r), gl + Vector2(-r * 0.25, 0)]), Color(1, 1, 0.9, 0.9))
		_pg(PackedVector2Array([gl + Vector2(-r, 0), gl + Vector2(0, r * 0.25), gl + Vector2(r, 0), gl + Vector2(0, -r * 0.25)]), Color(1, 1, 0.9, 0.9))
	elif carrying != null:
		# hoisting a critter overhead: one mighty arm, straight up (it wobbles)
		var lk := clampf(_carry_t / Grab.LIFT_TIME, 0.0, 1.0)
		lk = 1.0 - pow(1.0 - lk, 3.0)
		var hd := Vector2(46, -120).lerp(Vector2(14, -232), lk) + Vector2(sin(anim_t * 17.0) * 3.0, 0)
		_arm(sh, sh.lerp(hd, 0.5) + Vector2(14, 4), hd, 15.0, false)
		_fist(hd, 13.0)
		if _bb != null:
			_carry_hand = _bb.xf * hd
	elif showing_off > 0.0 and has_stick:
		# holding the new treasure up high, both arms, for everyone to see
		var hd := Vector2(20, -232)
		_arm(sh, sh + Vector2(10, -60), hd, 13.0, false)
		_club(hd + Vector2(0, 30), hd + Vector2(0, -80), 7.0, 26.0)
		_fist(hd)
	elif slam_charge >= 0.0 and has_stick:
		var tremble := Vector2(sin(anim_t * 60.0), cos(anim_t * 71.0)) * 2.5 * charge_k
		var hd: Vector2
		var ca: float
		match _weapon():
			"hammer":
				# raised overhead and trembling as the gem burns brighter
				hd = Vector2(8, -196) + tremble
				ca = -1.9 - 0.35 * charge_k
				_arm(sh, sh + Vector2(20, -40), hd, 13.0, false)
			"axe":
				# drawn back behind his head, ready to throw
				hd = Vector2(-26, -186) + tremble
				ca = -2.5 - 0.4 * charge_k
				_arm(sh, sh + Vector2(-10, -46), hd, 13.0, false)
			_:
				# pulled back low behind him, like a batter
				hd = Vector2(-40, -104) + tremble
				ca = 2.5 + 0.25 * charge_k
				_arm(sh, sh + Vector2(-20, 6), hd, 13.0, false)
		_club(hd - Vector2.from_angle(ca) * 12.0, hd + Vector2.from_angle(ca) * 112.0, 7.0, 26.0)
		_fist(hd)
		if charge_k >= 1.0:
			# ready: a glint at the weapon's head
			var tip := hd + Vector2.from_angle(ca) * 104.0
			var r := 9.0 + sin(anim_t * 20.0) * 3.0
			_pg(PackedVector2Array([tip + Vector2(0, -r), tip + Vector2(r * 0.25, 0), tip + Vector2(0, r), tip + Vector2(-r * 0.25, 0)]), Color(1, 1, 0.9, 0.9))
			_pg(PackedVector2Array([tip + Vector2(-r, 0), tip + Vector2(0, r * 0.25), tip + Vector2(r, 0), tip + Vector2(0, -r * 0.25)]), Color(1, 1, 0.9, 0.9))
	elif slam_t > 0.0 and has_stick:
		# brought down onto the ground in front of him
		var hd := Vector2(96, -70)
		_arm(sh, sh + Vector2(40, 10), hd, 13.0, false)
		_club(hd, Vector2(190, -8), 7.0, 26.0)
		_fist(hd)
	elif scorch_t > 0.0 and has_stick:
		# arms up, waving wildly
		var hd := Vector2(24 + sin(anim_t * 26.0) * 14.0, -214)
		_arm(sh, sh + Vector2(12, -52), hd, 13.0, false)
		_club(hd, hd + Vector2(-50, -60), 7.0, 22.0)
		_fist(hd)
	elif spear > 0.3 and throwing <= 0.0 and attacking <= 0.0:
		# the spear: arm thrust straight out in front, club pointed ahead like a spear
		var hd := sh + Vector2(72, 12)
		_arm(sh, sh.lerp(hd, 0.5) + Vector2(0, -3), hd, 13.0, false)
		if has_stick and not axe_out:
			_club(hd + Vector2(-22, -3), hd + Vector2(96, 16), 7.0, 22.0)
		_fist(hd)
	elif flip_t > 0.0 and (curl > 0.0 or open_k > 0.0):
		var hd: Vector2
		if open_k > 0.0:
			hd = Vector2(70, -150).lerp(Vector2(88, -120), open_k)          # out wide for balance
		elif flip_back:
			hd = Vector2(20, -210)                                          # flung up and back
		else:
			hd = Vector2(34, -84)                                           # hugging the knees
		_arm(sh, sh.lerp(hd, 0.5) + Vector2(10, 14), hd, 13.0, false)
		_club(hd, hd + Vector2(-60, 40), 7.0, 22.0)
		_fist(hd)
	elif tumble > 0.0 and throwing <= 0.0 and attacking <= 0.0:
		# windmilling: the near arm whirls, the club whirling with it
		var a := anim_t * 19.0
		var hd := sh + Vector2(cos(a) * 54.0, sin(a) * 54.0 - 30.0)
		_arm(sh, sh.lerp(hd, 0.5) + Vector2(sin(a) * 10.0, -cos(a) * 10.0), hd, 13.0, false)
		if has_stick and not axe_out:
			_club(hd, hd + Vector2.from_angle(a + 0.9) * 92.0, 7.0, 22.0)
		_fist(hd)
	elif wall_cling and not is_on_floor() and throwing <= 0.0 and attacking <= 0.0:
		# climbing: the near hand reaching up the wall and pulling, in time with the feet
		var hd := Vector2(60, -184.0 + 18.0 * sin(anim_t * 11.0 + PI))
		_arm(sh, sh + Vector2(22, -30), hd, 13.0, false)
		if has_stick and not axe_out:
			_club(hd + Vector2(-14, 40), hd + Vector2(-34, -60), 7.0, 22.0)
		_fist(hd)
		# fingers spread on the rock
		for k in 3:
			_ln(hd, hd + Vector2(8.0, -10.0 + k * 8.0), _skin, 6.0, true)
	elif vine != null:
		# hanging on: the near hand up on the vine, the club tucked under the arm
		var hd := Vector2(0, -HANG / ART)
		_arm(sh, sh + Vector2(-8, -48), hd, 13.0, false)
		_fist(hd)
	elif fury >= 0.0 and has_stick:
		# the club goes up overhead for the whole rage and is shaken at the
		# world as the fire leaves: the pose reads from across the screen
		var ca := -1.85 if not roaring else -1.35
		var hd := sh + Vector2(8, -58)
		_arm(sh, sh + Vector2(26, -24), hd, 13.0, false)
		_club(hd - Vector2.from_angle(ca) * 12.0, hd + Vector2.from_angle(ca) * 112.0, 7.0, 26.0)
		_fist(hd)
	elif boxing:
		var prog := 1.0 - attacking / PUNCH_TIME
		var jab := 0.0
		var cross := 0.0
		if prog < 0.5:
			jab = pow(sin(prog / 0.5 * PI), 0.55)
		else:
			cross = pow(sin((prog - 0.5) / 0.5 * PI), 0.55)
		var bh := Vector2(-20.0 + cross * 112.0, -112.0 + cross * 4.0)
		_arm(back_sh, back_sh.lerp(bh, 0.5) + Vector2(0, 10), bh, 11.0, true)
		var fh := Vector2(64.0 + jab * 52.0, -110.0 + jab * 4.0)
		_arm(sh, sh.lerp(fh, 0.5) + Vector2(0, 10), fh, 11.0, true)
		if jab > 0.72:
			_cc(fh + Vector2(16, 0), 9.0, Color(Pal.BONE, 0.45))
		if cross > 0.72:
			_cc(bh + Vector2(16, 0), 11.0, Color(Pal.BONE, 0.5))
	elif throwing > 0.0:
		var q := 1.0 - throwing / 0.28
		# overhand, ending pointed the way he aimed (ahead, up, 45 degrees, down)
		var end_a := atan2(_throw_aim.y, absf(_throw_aim.x)) - 0.2
		var ta := lerpf(-2.6, end_a, 1.0 - pow(1.0 - q, 3.0))
		var reach := 48.0 + q * 14.0
		var hd := sh + Vector2.from_angle(ta) * reach
		var el := sh + Vector2.from_angle(ta) * reach * 0.5 + Vector2.from_angle(ta - PI * 0.5) * 9.0
		_arm(sh, el, hd, 11.0, false)
		_dot(hd, 15.0, Pal.STONE)
		_dot(hd + Vector2(-2, 4), 9.0, _skin, 4.0)
	elif has_stick and attacking > 0.0 and not axe_out and not _kicking():
		var sp := 1.0 - attacking / _swing_time
		var ang := 0.0
		var trail := 0.0
		var reach := 49.0
		var smear_col := Color(Pal.BONE, 0.32)
		match _swing_kind:
			"axe0", "axe1":
				# a fast slash: up across the front, then back down across it
				var q := 1.0 - pow(1.0 - sp, 2.0)
				ang = lerpf(1.0, -1.15, q) if _swing_kind == "axe0" else lerpf(-1.15, 1.0, q)
				trail = (1.0 - q) * 0.6 * (-1.0 if _swing_kind == "axe0" else 1.0)
				reach = 56.0
				smear_col = Color("dfeaf2", 0.4)
			"axe2", "axe3":
				# up over his head, a beat at the top... then the CHOP
				if sp < 0.45:
					ang = lerpf(-0.8, -2.35, sp / 0.45)
					trail = -0.3
				else:
					var q := (sp - 0.45) / 0.55
					ang = -2.35 + (1.0 - pow(1.0 - q, 3.0)) * 3.7
					trail = (1.0 - q) * 0.9
					reach = 49.0 + sin(q * PI) * 22.0
				smear_col = Color("dfeaf2", 0.45)
			"dig", "spike":
				# like a pickaxe: up over his head, then DRIVEN straight down at his feet
				if sp < 0.38:
					var q := sp / 0.38
					ang = lerpf(-0.6, -2.3, q * q * (3.0 - 2.0 * q))
					trail = -0.15
				else:
					var q := clampf((sp - 0.38) / 0.12, 0.0, 1.0)     # lands at 0.5, as the blow does
					# the club lands slanted, its head on the ground ahead of his feet: driven
					# straight down, planted in the dirt, it looked just like a shovel
					ang = -2.3 + q * q * (3.75 if tool == "shovel" else 3.2)
					trail = (1.0 - q) * 1.0
					reach = 44.0 - 6.0 * q
				smear_col = Color(0.85, 0.7, 0.5, 0.45)
			"hammer":
				# heaved up and back, slowly... then SMASHED down onto the ground
				if sp < 0.56:
					var q := sp / 0.56
					ang = lerpf(-0.9, -2.75, q * q * (3.0 - 2.0 * q))
					trail = -0.2
				else:
					var q := clampf((sp - 0.56) / 0.2, 0.0, 1.0)
					ang = -2.75 + q * q * 4.1
					trail = (1.0 - q) * 1.1
					reach = 52.0 + sin(q * PI) * 10.0
				smear_col = Color(Pal.EMBER_GLOW, 0.45)
			"club1":
				# the uppercut: from low in front, whipped back up over his head
				var q := 1.0 - pow(1.0 - sp, 2.4)
				ang = lerpf(1.25, -1.9, q)
				trail = -(1.0 - q) * 0.8
				reach = 50.0 + sin(q * PI) * 14.0
				smear_col = Color(Pal.BONE, 0.4)
			"club2":
				# the finisher: wound right up behind his head... then SMASHED down
				if sp < 0.45:
					var q := sp / 0.45
					ang = lerpf(-1.9, -3.05, q * q * (3.0 - 2.0 * q))
					trail = -0.2
				else:
					var q := clampf((sp - 0.45) / 0.22, 0.0, 1.0)
					ang = -3.05 + (1.0 - pow(1.0 - q, 3.0)) * 3.7       # lands slanted ahead (straight down, planted, it looked like a shovel)
					trail = (1.0 - q) * 1.2
					reach = 52.0 + sin(q * PI) * 22.0
				smear_col = Color(1.0, 0.9, 0.6, 0.55)
			"homerun":
				# from low behind him, a full sweep round to high in front
				var q := 1.0 - pow(1.0 - sp, 2.2)
				ang = lerpf(2.6, -1.1, q)
				trail = -(1.0 - q) * 0.9
				reach = 60.0
				smear_col = Color(Pal.BONE, 0.45)
			"cyclone":
				# round and round: the club whirls twice right round him, a blur
				ang = -PI * 0.5 + sp * TAU * 2.0
				trail = 0.9
				reach = 54.0
				smear_col = Color("bfe6ff", 0.55)
			"ram":
				# the charge: the club driven straight out in front like a battering ram
				ang = lerpf(-0.35, 0.12, minf(sp / 0.3, 1.0))
				trail = 0.15
				reach = 64.0
				smear_col = Color("ffd36b", 0.5)
			_:
				# the club: a quick overhead bonk
				if sp < 0.24:
					ang = -0.95 - (sp / 0.24) * 0.85
					trail = 0.55
				else:
					var q2 := (sp - 0.24) / 0.76
					ang = -1.80 + (1.0 - pow(1.0 - q2, 2.6)) * 3.05
					trail = (1.0 - q2) * 0.85
					reach = 49.0 + sin(q2 * PI) * 18.0
		var hd := sh + Vector2.from_angle(ang) * reach
		var el := sh + Vector2.from_angle(ang) * reach * 0.5 + Vector2.from_angle(ang - PI * 0.5) * 9.0
		var ca := ang - trail
		var smear := PackedVector2Array()
		var span := 0.75 * signf(trail if trail != 0.0 else 1.0)
		for i in 7:
			smear.append(sh + Vector2.from_angle(ca - span + i * (span / 6.0)) * (reach + 100.0))
		# the smear fades as the swing slows: a still arc left beside the landed club read as a shovel's handle
		smear_col.a *= clampf(absf(trail) / 0.45, 0.0, 1.0)
		if smear_col.a > 0.02:
			_pl(smear, smear_col, 9.0 if _swing_kind in ["hammer", "homerun", "axe2", "axe3", "cyclone", "ram"] else 7.0, true)
		_arm(sh, el, hd, 13.0, false)
		_club(hd - Vector2.from_angle(ca) * 12.0, hd + Vector2.from_angle(ca) * 112.0, 7.0, 26.0)
		_fist(hd)
	elif has_stick and kick_k >= 0.0:
		# kicking: the club flung up and back for balance, out of the leg's way
		var hd := Vector2(66, -184)
		_arm(sh, Vector2(70, -150), hd, 10.0, false)
		_club(hd + Vector2(10, 4), hd + Vector2(-92, -36), 7.0, 26.0)
		_fist(hd)
	elif has_stick:
		# carries the club on his shoulder; it rides the body's bob and lean
		var lift := -8.0 if air else 0.0
		var hd := Vector2(60, -76.0 + lift)
		_arm(sh, Vector2(68, -96.0 + lift), hd, 10.0, false)
		_club(Vector2(58, -64.0 + lift), Vector2(84, -184.0 + lift), 7.0, 26.0)
		_fist(hd)
	else:
		var na := _pose_arm(sh, 1.0, running, air, ph, speed_k)
		_arm(sh, na[0], na[1], 10.0, true)

	if kick_k >= 0.0:
		# kicking: the leg comes round in FRONT of everything, club and all
		_stm(base)
		_leg(hip_f, foot_f, 1.0)
	_st(Vector2.ZERO, 0.0, Vector2.ONE)
	if sun_t > 0.0:
		_paint_sun_flames()
	_paint_kick()


## The torch arm. Held up and behind his head so the light falls on both
## sides of him; it bobs with the stride but never swings wild. Records where
## the flame is, which is where Night centres his light.
func _torch_arm(sh: Vector2, running: bool, air: bool, ph: float, k: float, rage: float, xf: Transform2D) -> void:
	var hd := Vector2(-60, -150)
	if running:
		hd += Vector2(cos(ph) * 3.0 * k, -absf(sin(ph)) * 4.0 * k)
	elif air:
		hd += Vector2(2, -10)
		# the spear pose: the torch carried forward and high; tumbling: waved wildly
		hd += Vector2(34, -14) * _spear * (1.0 - _tumble)
		hd += Vector2(sin(anim_t * 14.0) * 16.0, -30.0 + cos(anim_t * 14.0) * 8.0) * _tumble
	else:
		hd.y += sin(anim_t * 1.8) * 1.5
	hd += Vector2(-4, -16) * rage          # thrust up as the anger builds
	var el := sh.lerp(hd, 0.5) + Vector2(-18, 10)
	var butt := hd + Vector2(7, 26)
	var top := hd + Vector2(-9, -60)
	var u := (top - butt).normalized()
	var n := Vector2(-u.y, u.x)
	_shape(PackedVector2Array([butt + n * 4.0, top + n * 6.0, top - n * 6.0, butt - n * 4.0]), C_WOOD, 3.5)
	_oval(top + u * 2.0, 8.5, 13.0, Pal.DEADWOOD_DARK, 3.0, u.angle() + PI * 0.5)
	for i in 3:
		var bp := top - u * (4.0 + i * 5.0)
		_ln(bp + n * 8.0, bp - n * 8.0, C_VINE, 2.5, true)
	_arm(sh, el, hd, 10.0, false)
	_dot(hd, 10.0, _skin)
	var base := top + u * 6.0
	if torch_fuel > 0.0:
		var h := (30.0 + 36.0 * torch_fuel) * (1.0 + 0.7 * rage)
		var sway := sin(anim_t * 9.0) * 5.0 + sin(anim_t * 15.0) * 2.5 - k * 14.0 + wind * facing / 10.0
		_flame(base, 17.0, h, sway, Color(Pal.EMBER_GLOW, 0.85))
		_flame(base + Vector2(0, 2), 12.0, h * 0.78, sway * 0.8, Pal.FLAME)
		_flame(base + Vector2(0, 4), 6.5, h * 0.45, sway * 0.5, Pal.FLAME_CORE)
		_torch_tip = xf * (base + Vector2(sway * 0.3, -h * 0.35))
	else:
		# out: a red ember and a thread of smoke
		var e := 0.5 + 0.5 * sin(anim_t * 3.0)
		_cc(base, 5.0, Color(Pal.EMBER_GLOW, 0.5 + 0.4 * e))
		for i in 3:
			var q := fmod(anim_t * 0.6 + i / 3.0, 1.0)
			_cc(base + Vector2(sin(q * 6.0 + i) * 6.0, -10.0 - q * 50.0), 4.0 + q * 7.0, Color(Pal.ASH, 0.35 * (1.0 - q)))
		_torch_tip = xf * base


## A teardrop of flame: round at the base, drawn to a swaying point.
func _flame(base: Vector2, w: float, h: float, sway: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var a := PI * (i / 8.0)
		pts.append(base + Vector2(cos(a) * w, sin(a) * w * 0.8))
	pts.append(base + Vector2(-w * 0.8 + sway * 0.3, -h * 0.35))
	pts.append(base + Vector2(sway, -h))
	pts.append(base + Vector2(w * 0.7 + sway * 0.4, -h * 0.4))
	_pg(pts, col)


## Level 2: his first hide. A rough wrap cut from a pelt, ragged at the hem.
func _hide_loincloth(k: float) -> void:
	var sw := -k * 6.0 + sin(anim_t * 2.0) * 1.2 + _hair_off.x * 0.5
	var hem := [Vector2(40, -40), Vector2(31, -34), Vector2(22, -38), Vector2(13, -31),
		Vector2(3, -36), Vector2(-7, -30), Vector2(-16, -35), Vector2(-24, -32), Vector2(-29, -40)]
	var pts := PackedVector2Array([Vector2(-27, -74), Vector2(35, -74)])
	for i in hem.size():
		var h: Vector2 = hem[i]
		pts.append(h + Vector2(sw + sin(anim_t * 2.6 + i) * 0.8, 0))
	var hide := C_LEOPARD
	var spots := C_LEOPARD_SPOT
	var leopard := true
	if skin in ["wolf_pelt", "wolf_hood"]:
		leopard = false
		hide = Pal.WOLF
		spots = Pal.WOLF_DARK
	elif skin == "ember_paint":
		leopard = false
		hide = Color("9a4a22")
		spots = Color("4a2414")
	elif skin == "bear_cloak":
		leopard = false
		hide = Color("6b4a2e")
		spots = Color("45301c")
	elif skin == "firekeeper":
		leopard = false
		hide = Color("c49a64")
		spots = Color("8a6a3c")
	_shape(pts, hide, 3.5)
	_fur(pts, FUR, Color(1.0, 0.9, 0.7, 0.32), 0.5)       # the hide is real fur
	if leopard:
		# leopard rosettes: broken dark rings round a warmer middle
		for r in [Vector2(-14, -62), Vector2(6, -66), Vector2(26, -60), Vector2(-4, -48), Vector2(18, -46), Vector2(-20, -44), Vector2(32, -46)]:
			var rp: Vector2 = r + Vector2(sw * 0.5, 0)
			_cc(rp, 4.2, Color("c07a2c"))
			for q in 3:
				var a: float = q * TAU / 3.0 + rp.x
				_cc(rp + Vector2.from_angle(a) * 4.6, 2.2, spots)
	else:
		_oval(Vector2(-8, -54), 7.0, 4.5, spots, 0.0, 0.3)
		_oval(Vector2(20, -48), 5.0, 3.5, spots, 0.0, -0.2)
	for i in 8:
		var fx := -24.0 + i * 8.0 + sw
		_ln(Vector2(fx, -37), Vector2(fx - 2, -29), Pal.WOLF_BELLY if skin in ["wolf_pelt", "wolf_hood"] else spots, 2.5, true)


## Ugu's topknot: a fiery tuft tied up on top with a little bone through it.
## It bounces a beat behind his head.
func _topknot() -> void:
	var sway := sin(anim_t * 3.0) * 2.0 - velocity.x / SPEED * 4.0 * float(facing)
	var base := Vector2(2, -184)
	var tip := base + Vector2(-6.0 + sway, -30.0)
	_shape(PackedVector2Array([base + Vector2(-11, 4), base + Vector2(-12, -10), tip + Vector2(-6, 2), tip, tip + Vector2(8, 4),
		base + Vector2(10, -10), base + Vector2(11, 4)]), C_HAIR, 4.0)
	_ln(base + Vector2(-2, -8), tip + Vector2(2, 6), C_HAIR_HI, 3.0, true)
	# the bone through the knot
	var b0 := base + Vector2(-20, -8)
	var b1 := base + Vector2(20, -12)
	_ln(b0, b1, C_OL, 9.0, true)
	_ln(b0, b1, Pal.KEY_BONE, 5.0, true)
	for e in [b0, b1]:
		_dot(e + Vector2(0, -2), 4.0, Pal.KEY_BONE, 2.5)
		_dot(e + Vector2(0, 3), 4.0, Pal.KEY_BONE, 2.5)

## A little bunch of grapes (the health fruit), at the given size.
func _grapes(at: Vector2, k: float) -> void:
	_ln(at + Vector2(0, -14) * k, at + Vector2(3, -22) * k, Color("6b4a2a"), 3.0 * k)
	for g in [Vector2(-6, -8), Vector2(0, -9), Vector2(6, -8), Vector2(-3, -2), Vector2(3, -2), Vector2(0, 4)]:
		_cc(at + g * k, 4.6 * k, Color("3e1a52"))
		_cc(at + g * k, 3.8 * k, Color("7b3aa0"))
		_cc(at + (g + Vector2(-1.3, -1.3)) * k, 1.3 * k, Color("d9b8ef"))


## The sooty face after a scorching: black with soot, just the whites of
## his eyes showing, fading over its last second.
func _soot_face() -> void:
	if soot_t <= 0.0:
		return
	var a := clampf(soot_t, 0.0, 1.0)
	_pg(_oval_pts(Vector2(4, -150), 23.0, 20.0), Color(0.12, 0.1, 0.09, 0.78 * a))
	for e in [Vector2(-7, -151), Vector2(15, -151)]:
		_cc(e, 5.0, Color(1, 1, 1, a))
		_cc(e + Vector2(1.5, 0.5), 2.2, Color(0.1, 0.08, 0.06, a))


## Little flames licking at the seat of his loincloth while he panics.
func _seat_flames() -> void:
	if scorch_t <= 0.0:
		return
	for i in 3:
		var x := -30.0 + i * 11.0
		var h := 26.0 + sin(anim_t * 30.0 + i * 2.0) * 7.0
		_pg(_seat_flame_pts(Vector2(x, -52), 9.0, h, 6.0), Color(1.0, 0.55, 0.15, 0.95))
		_pg(_seat_flame_pts(Vector2(x, -52), 5.0, h * 0.6, 4.0), Color(1.0, 0.9, 0.5))


## A small flame: a teardrop rising from `base`, `w` wide and `h` tall, its tip leaning by `lean`.
func _seat_flame_pts(base: Vector2, w: float, h: float, lean: float) -> PackedVector2Array:
	return PackedVector2Array([base + Vector2(-w, 0), base + Vector2(-w * 0.8, -h * 0.45), base + Vector2(lean, -h),
		base + Vector2(w * 0.8, -h * 0.45), base + Vector2(w, 0), base + Vector2(0, h * 0.12)])


## ------------------------------------------------------------------ costumes
## The fire-discovery costumes, drawn in layers: what hangs behind him, what
## is painted or worn on his chest and face, what sits on his head, and what
## hangs at his belt.
func _costume_back() -> void:
	match skin:
		"wolf_hood":
			# the wolf's pelt hanging down his back from the hood
			_shape(PackedVector2Array([Vector2(-20, -176), Vector2(-40, -150), Vector2(-54, -110), Vector2(-56, -74), Vector2(-40, -80),
				Vector2(-30, -120), Vector2(-8, -160)]), Pal.WOLF, 3.5)
			for k in 4:
				_ln(Vector2(-46 + k * 3, -120 + k * 10), Vector2(-52 + k * 2, -112 + k * 10), Pal.WOLF_DARK, 2.5, true)
		"bear_cloak":
			# a heavy bear-fur cloak over the shoulders, down to the knees
			# the cloak hangs down his back to the knees, swaying a little
			var fl := sin(anim_t * 2.0) * 2.0
			_shape(PackedVector2Array([Vector2(-46, -134), Vector2(-16, -138), Vector2(-14, -100), Vector2(-26, -64), Vector2(-36, -30 + fl),
				Vector2(-70, -26 + fl), Vector2(-64, -70 + fl), Vector2(-58, -112)]), Color("6b4a2e"), 3.5)
			for k in 6:
				var x := -66.0 + k * 5.0
				_ln(Vector2(x, -36 + fl), Vector2(x - 3.0, -24 + fl), Color("45301c"), 2.5, true)


func _costume_chest() -> void:
	match skin:
		"ember_paint":
			# charcoal-edged ochre flames rising from the belt up the chest
			for f in [[-24.0, 34.0], [4.0, 44.0], [30.0, 32.0]]:
				var x: float = f[0]
				var h: float = f[1]
				var flick := sin(anim_t * 3.0 + x) * 1.5
				var pts := PackedVector2Array([Vector2(x - 9, -72), Vector2(x - 6, -72 - h * 0.5), Vector2(x - 2 + flick, -72 - h),
					Vector2(x + 2, -72 - h * 0.6), Vector2(x + 5, -72 - h * 0.75), Vector2(x + 9, -72)])
				_shape(pts, Color("d9822b"), 2.5)
				_pg(PackedVector2Array([Vector2(x - 4, -72), Vector2(x - 1 + flick, -72 - h * 0.6), Vector2(x + 4, -72)]), Color("f3c14f"))
		"bear_cloak":
			# a fur mantle over both shoulders, scalloped where the fur ends,
			# fastened at the front with two bear claws
			var mantle := PackedVector2Array([Vector2(-50, -126), Vector2(-32, -142), Vector2(4, -146), Vector2(42, -142), Vector2(60, -126)])
			for k in 10:
				var x := 54.0 - k * 11.0
				mantle.append(Vector2(x, -114.0 if k % 2 == 0 else -120.0))
			_shape(mantle, Color("6b4a2e"), 3.5)
			for k in 7:
				var x := -36.0 + k * 13.0
				_ln(Vector2(x, -136), Vector2(x - 3.0, -126), Color("8a6440"), 2.5, true)
			for cx in [-2.0, 10.0]:
				_shape(PackedVector2Array([Vector2(cx - 3, -118), Vector2(cx + 3, -118), Vector2(cx + 1, -102)]), Color("efe6d2"), 2.0)
		"firekeeper":
			# ash smeared in two broad stripes across the chest
			_ln(Vector2(-30, -112), Vector2(30, -104), Color(0.8, 0.8, 0.78, 0.55), 6.0, true)
			_ln(Vector2(-26, -100), Vector2(28, -92), Color(0.8, 0.8, 0.78, 0.45), 5.0, true)


func _costume_face() -> void:
	match skin:
		"ember_paint":
			# a band of charcoal across the eyes, ochre dots below it
			_rc(Rect2(-20, -158, 48, 13), Color(0.12, 0.08, 0.06, 0.8))
			for k in 4:
				_cc(Vector2(-12 + k * 10, -141), 2.2, Color("d9822b"))
		"firekeeper":
			# ash stripes on the cheeks
			for sx in [-16.0, 20.0]:
				_ln(Vector2(sx - 4, -146), Vector2(sx + 4, -144), Color(0.85, 0.85, 0.82, 0.8), 2.5, true)
				_ln(Vector2(sx - 4, -140), Vector2(sx + 4, -138), Color(0.85, 0.85, 0.82, 0.8), 2.5, true)


func _costume_head() -> void:
	match skin:
		"wolf_hood":
			# a wolf's head worn over his own: skull cap, snout over the brow,
			# teeth at the fringe, pointed ears, and its eyes above his
			_shape(PackedVector2Array([Vector2(-24, -168), Vector2(-20, -184), Vector2(0, -192), Vector2(26, -188), Vector2(40, -176),
				Vector2(52, -170), Vector2(50, -162), Vector2(30, -164), Vector2(-10, -164)]), Pal.WOLF, 3.5)
			_shape(PackedVector2Array([Vector2(28, -172), Vector2(52, -170), Vector2(50, -162), Vector2(30, -164)]), Pal.WOLF_BELLY, 2.0)
			_cc(Vector2(52, -168), 3.0, Pal.OUTLINE)
			for k in 3:
				var tx := 34.0 + k * 5.0
				_pg(PackedVector2Array([Vector2(tx, -163), Vector2(tx + 3, -163), Vector2(tx + 1.5, -157)]), Color("f4efe2"))
			for e in [[-8.0, -186.0], [14.0, -190.0]]:
				_shape(PackedVector2Array([Vector2(e[0] - 7, e[1] + 2), Vector2(e[0] - 1, e[1] - 18), Vector2(e[0] + 6, e[1] + 1)]), Pal.WOLF_DARK, 2.5)
			_cc(Vector2(30, -178), 2.4, Pal.WOLF_EYE)
		"bear_cloak":
			# the bear's hood: a brown fur cap with round ears
			_shape(PackedVector2Array([Vector2(-26, -164), Vector2(-24, -182), Vector2(-6, -194), Vector2(18, -194), Vector2(34, -182),
				Vector2(34, -166), Vector2(18, -170), Vector2(-8, -170)]), Color("6b4a2e"), 3.5)
			for e in [Vector2(-14, -190), Vector2(24, -192)]:
				_dot(e, 7.5, Color("6b4a2e"), 3.0)
				_cc(e, 3.5, Color("45301c"))
		"firekeeper":
			# a leather headband with a glowing ember charm at the front
			_ln(Vector2(-24, -168), Vector2(32, -170), C_OL, 9.0, true)
			_ln(Vector2(-24, -168), Vector2(32, -170), Color("a0703c"), 6.0, true)
			var glow := 0.6 + 0.4 * sin(anim_t * 4.0)
			_cc(Vector2(28, -170), 11.0, Color(Pal.EMBER_GLOW, 0.3 * glow))
			_dot(Vector2(28, -170), 5.0, Color("f08a24").lerp(Color("ffd36b"), glow), 2.0)
			# two feathers tucked in at the back
			for k in 2:
				var fx := -20.0 - k * 6.0
				_shape(PackedVector2Array([Vector2(fx, -168), Vector2(fx - 8, -196 + k * 6), Vector2(fx - 2, -194 + k * 6), Vector2(fx + 3, -170)]),
					Color("e8e0cc") if k == 0 else Color("c0392b"), 2.0)


func _costume_belt() -> void:
	if skin == "firekeeper":
		# a little leather pouch of live embers, glowing through the seams
		var glow := 0.6 + 0.4 * sin(anim_t * 3.3 + 1.0)
		_shape(PackedVector2Array([Vector2(26, -70), Vector2(40, -70), Vector2(42, -54), Vector2(24, -54)]), Color("8a5a2c"), 2.5)
		_ln(Vector2(28, -62), Vector2(38, -62), Color("ffb347", glow), 2.5, true)
		_cc(Vector2(33, -58), 7.0, Color(Pal.EMBER_GLOW, 0.25 * glow))


## The snarl: jaw dropped, both rows of teeth bared.
func _roar() -> void:
	var pts := _oval_pts(Vector2(4, -134), 10.0, 7.5)
	_pg(pts, C_MOUTH)
	_rc(Rect2(-4, -141, 16, 3.5), C_EYE)
	_rc(Rect2(-3, -130.5, 14, 3.0), C_EYE)
	var ring := PackedVector2Array(pts)
	ring.append(pts[0])
	_pl(ring, C_OL, 2.5, true)


## Breath snorting from the nose while it builds, and sparks drawn in toward
## his chest; at the release they are gone into the burst.
func _rage_marks(rage: float, roaring: bool) -> void:
	if roaring:
		return
	for i in 3:
		var q := fmod(anim_t * 2.6 + i / 3.0, 1.0)
		_cc(Vector2(14.0 + q * 30.0, -144.0 - q * 14.0), 5.0 + q * 8.0, Color(Pal.BONE, 0.5 * (1.0 - q) * rage))
	for i in 10:
		var q := fmod(anim_t * 1.7 + i / 10.0, 1.0)
		var a := i * 0.63 + anim_t * 3.0
		var p := Vector2(4, -100) + Vector2.from_angle(a) * 200.0 * (1.0 - q)
		_cc(p, 5.0 + 4.0 * q, Color(Pal.FLAME, rage * q))
		_cc(p, 2.5 + 2.0 * q, Color(Pal.FLAME_CORE, rage * q))


## Where a foot is at a given point in the stride. It travels BACKWARDS while on
## the ground (pushing him forward) and swings forward while lifted. Get that
## the wrong way round and he looks like he is running on ice.
func _run_foot(hip_x: float, phase: float, k: float) -> Vector2:
	var lift := 24.0 * k
	return Vector2(hip_x + 4.0 - cos(phase) * _stride_amp(k), -6.0 - maxf(0.0, sin(phase)) * lift)


## Stride grows with speed up to a limit. Used by BOTH the foot placement and
## the phase rate, which is what keeps a planted foot exactly still on the
## ground: phase advances by distance / stride, so the foot sweeps backwards
## at precisely the speed the body moves forwards.
func _stride_amp(k: float) -> float:
	return STRIDE * clampf(k, 0.55, 1.0)


## Two-bone IK: given hip and foot, find the knee. Always bends forward.
func _knee(hip: Vector2, foot: Vector2, a: float, b: float) -> Vector2:
	var d := clampf(hip.distance_to(foot), absf(a - b) + 0.01, a + b - 0.01)
	var cos_h := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	return hip + Vector2.from_angle((foot - hip).angle() - acos(cos_h)) * a


## The IK bones are long so a full running stride can reach. Standing, that
## same length would have to fold into a much shorter hip-to-foot distance and
## bow the knees — so at rest the leg is simply straight, and the IK knee is
## blended in only as he moves, jumps or lands.
func _leg(hip: Vector2, foot: Vector2, bend: float) -> void:
	var straight := hip.lerp(foot, 0.5) + Vector2(1.5, 0)
	var knee := straight.lerp(_knee(hip, foot, 36.0, 36.0), bend)
	_limb([hip, knee, foot], [[25.0, 17.0], [18.0, 12.0]])     # a big thigh, a strong calf, a slim ankle
	# a big bare foot, three toes at the front
	_oval(foot + Vector2(6, 2), 19.0, 8.5, _skin)
	for tx in [15.0, 20.0]:
		_ln(foot + Vector2(tx, 0), foot + Vector2(tx + 1.0, 6), _skin.darkened(0.45), 2.0, true)


## Elbow and hand for an arm that is not doing anything else. side is -1 for
## the far arm and +1 for the near one; running, the two swing out of phase,
## each paired with the opposite leg the way a real runner's are.
func _pose_arm(sh: Vector2, side: float, running: bool, air: bool, phase: float, k: float) -> Array:
	if air and _tumble > 0.3:
		# windmilling, the other way round to the near arm
		var a := anim_t * 19.0 + PI
		var hd := sh + Vector2(cos(a) * 50.0, sin(a) * 50.0 - 28.0)
		return [sh.lerp(hd, 0.5) + Vector2(sin(a) * 9.0, -cos(a) * 9.0), hd]
	if air and _spear > 0.3:
		# reaching forward too, a little higher than the club arm
		return [sh + Vector2(36, -8), sh + Vector2(70, -14)]
	if air:
		if velocity.y < -150.0:
			return [sh + Vector2(20.0 * side, -18.0), sh + Vector2(24.0 * side, -44.0)]
		if velocity.y > 180.0:
			var fl := sin(anim_t * 22.0) * 5.0 * side
			return [sh + Vector2(26.0 * side, -12.0), sh + Vector2(34.0 * side, -36.0 + fl)]
		return [sh + Vector2(28.0 * side, 4.0), sh + Vector2(46.0 * side, 2.0)]
	if running:
		var sw := cos(phase) * k * side
		var ua := PI * 0.5 - sw * 0.95
		var el := sh + Vector2.from_angle(ua) * 28.0
		return [el, el + Vector2.from_angle(ua - 1.35) * 24.0]
	var br := sin(anim_t * 1.8) * 1.2
	return [sh + Vector2(15.0 * side, 24.0), sh + Vector2(9.0 * side, 48.0 + br)]


func _eye(c: Vector2, wince: bool, blink: bool, s := 1.0, side := 1.0) -> void:
	if wince:
		# squeezed shut: > <
		_pl(PackedVector2Array([c + Vector2(-5.0 * side, -4), c + Vector2(4.0 * side, 0), c + Vector2(-5.0 * side, 4)]), C_OL, 3.0, true)
		return
	# big and clear, so they read from across the screen
	var ry := 0.8 if blink else 5.6 * s
	_oval(c, 6.6 * s, ry, C_EYE, 2.0)
	if not blink:
		# warm amber eyes: his own
		_cc(c + Vector2(2.0, 0.6) * s, 3.9 * s, Color("8a4f12"))
		_cc(c + Vector2(2.0, 0.6) * s, 3.1 * s, Color("d18a2a"))
		_cc(c + Vector2(2.2, 0.8) * s, 1.8 * s, Color("1a0f08"))
		_cc(c + Vector2(0.9, -1.0) * s, 1.3 * s, Color.WHITE)
		_cc(c + Vector2(3.4, 2.0) * s, 0.6 * s, Color.WHITE)     # a second sparkle: lively eyes
		# a lash line along the top, swept out at the outer corner
		_ac(c, 6.8 * s, PI * 1.12, PI * 1.88, 8, C_OL, 2.2, true)
		var outer := c + Vector2(6.6 * s * side, -1.5 * s)
		_ln(outer, outer + Vector2(3.0 * side, -2.5) * s, C_OL, 2.0, true)


## A little round button of a nose, a shine on the tip.
func _nose() -> void:
	_oval(Vector2(5, -143), 6.5, 5.6, _skin.lerp(Color("d9705a"), 0.2), 2.2)
	_cc(Vector2(3, -145), 2.0, Color(1, 0.92, 0.82, 0.65))


## His unibrow, sculpted: thick at the ends, thinner where it meets over the
## nose. `inner` > 0 brings the middle down (a frown), < 0 lifts it.
func _brows(inner: float) -> void:
	_brow(Vector2(4, -160.0 + inner * 0.6), Vector2(-21, -161), 6.0, 9.0, 4.0)
	_brow(Vector2(4, -160.0 + inner * 0.6), Vector2(30, -161), 6.0, 10.0, 4.0)
	# his mark: an old scar nicked right through the brow over his big eye
	_ln(Vector2(18, -169.0 + inner * 0.4), Vector2(22, -155.0 + inner * 0.3), _skin, 3.4, true)
	_ln(Vector2(18.5, -167.0 + inner * 0.4), Vector2(21.5, -156.5 + inner * 0.3), Color("e6a98a"), 1.4, true)


## One brow: a furry band from `a` (by the nose) to `b`, `w_a` thick at a, `w_b`
## at b, arched up by `arch`, with a few hairs flicking up out of it.
func _brow(a: Vector2, b: Vector2, w_a: float, w_b: float, arch: float) -> void:
	var mid := (a + b) * 0.5 + Vector2(0, -arch * 2.0)
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 7:
		var q := i / 6.0
		var p := a.lerp(mid, q).lerp(mid.lerp(b, q), q)
		var w := lerpf(w_a, w_b, q) * (1.0 - 0.25 * pow(q, 4.0))
		top.append(p + Vector2(0, -w * 0.5))
		bot.append(p + Vector2(0, w * 0.5))
	var pts := PackedVector2Array(top)
	for i in range(bot.size() - 1, -1, -1):
		pts.append(bot[i])
	_shape(pts, C_HAIR, 3.0)
	for i in [1, 3, 5]:
		var t0: Vector2 = top[i]
		_ln(t0 + Vector2(0, 1), t0 + (b - a).normalized() * 3.5 + Vector2(0, -3.5), C_HAIR, 2.0, true)


## Out cold: mouth hanging open, tongue lolling out of the side.
func _dead_mouth() -> void:
	_oval(Vector2(4, -135), 8.0, 5.0, C_MOUTH, 3.0)
	_oval(Vector2(10, -128), 4.5, 7.0, Color("d9675e"), 2.0, 0.3)


## Mouth wide open in a yell, tongue waggling.
func _yell() -> void:
	var o := 1.0 + sin(anim_t * 17.0) * 0.12
	_oval(Vector2(4, -134), 9.0 * o, 9.0 * o, C_MOUTH, 3.0)
	_oval(Vector2(4 + sin(anim_t * 21.0) * 2.0, -129), 5.0, 3.5, Color("d9675e"), 2.0)
	_rc(Rect2(-2, -143, 12, 3), C_EYE, true)


## Clenched teeth with the corners pulled down.
## A big toothy grin (the flex).
func _grin() -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var a := PI * i / 8.0
		pts.append(Vector2(4.0 - cos(a) * 13.0, -140.0 + sin(a) * 8.0))
	_pg(pts, C_EYE)
	_pl(pts, C_OL, 2.5, true)
	_ln(Vector2(-9, -140), Vector2(17, -140), C_OL, 2.5, true)
	for i in range(1, 4):
		var tx := -9.0 + i * 6.5
		_ln(Vector2(tx, -140), Vector2(tx, -135), C_OL, 1.5, true)


## The smile with his tongue out of the corner: poking out (concentrating), or
## flapping about (running flat out).
func _tongue_out(flap: bool) -> void:
	_smile()
	var w := sin(anim_t * 26.0) * 3.0 if flap else 0.0
	var tip := Vector2(19.0 + (6.0 if flap else 0.0), -132.0 + w)
	_shape(PackedVector2Array([Vector2(10, -136), Vector2(14, -138), tip + Vector2(3, -2), tip + Vector2(2, 3), Vector2(11, -132)]), Color("e0707a"), 2.0)
	_ln(Vector2(12, -135), tip + Vector2(-1, 0), Color("b04a55"), 1.5, true)

## His resting face: a happy open smile, top teeth showing, a bit of tongue.
func _smile() -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var a := PI * i / 8.0
		pts.append(Vector2(4.0 - cos(a) * 10.0, -138.0 + sin(a) * 7.0))
	_pg(pts, C_MOUTH)
	_oval(Vector2(4, -133.5), 4.5, 2.4, Color("d9656a"), 0.0)
	# the gap in his front teeth
	_rc(Rect2(-3, -138, 6, 3.4), C_EYE)
	_rc(Rect2(5, -138, 6, 3.4), C_EYE)
	_pl(pts, C_OL, 2.2, true)
	_ln(Vector2(-6, -138), Vector2(14, -138), C_OL, 2.2, true)
	# smile lines lifting the cheeks
	_ln(Vector2(-9, -137), Vector2(-7, -140), C_OL, 2.0, true)
	_ln(Vector2(17, -137), Vector2(15, -140), C_OL, 2.0, true)



func _mouth() -> void:
	var w := 16.0
	var h := 5.0
	var x0 := 4.0 - w * 0.5
	_rc(Rect2(x0, -139, w, h), C_EYE, true)
	_rc(Rect2(x0, -139, w, h), C_OL, false, 2.5)
	for i in range(1, 4):
		var tx := x0 + i * w / 4.0
		_ln(Vector2(tx, -139), Vector2(tx, -139.0 + h), C_OL, 1.5, true)
	_ln(Vector2(x0 - 4, -133), Vector2(x0, -138), C_OL, 3.0, true)
	_ln(Vector2(x0 + w + 4, -133), Vector2(x0 + w, -138), C_OL, 3.0, true)


func _oval_pts(c: Vector2, rx: float, ry: float, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cr := cos(rot)
	var sr := sin(rot)
	for i in 22:
		var a := TAU * i / 22.0
		var v := Vector2(cos(a) * rx, sin(a) * ry)
		pts.append(c + Vector2(v.x * cr - v.y * sr, v.x * sr + v.y * cr))
	return pts


func _club(p0: Vector2, p1: Vector2, w0: float, w1: float) -> void:
	if axe_out:
		return
	if tool == "shovel":
		_shovel(p0, p1)
		return
	if hammer:
		_hammer(p0, p1)
		return
	if axe:
		_axe(p0, p1)
		return
	## Thin at the grip, thickening all the way up: cut from a branch with the
	## root end kept, so most of the weight sits in the head.
	var d := p1 - p0
	var u := d.normalized()
	var nrm := Vector2(-u.y, u.x)
	var n := 10
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n + 1:
		var sf := float(i) / n
		var w := (w0 + (w1 - w0) * pow(sf, 1.4)) * 0.5
		var bl := sin(i * 2.3) * 2.0 if sf > 0.5 else 0.0
		var br := cos(i * 1.9) * 2.0 if sf > 0.5 else 0.0
		left.append(p0 + d * sf + nrm * (w + bl))
		right.append(p0 + d * sf - nrm * (w + br))
	var pts := PackedVector2Array(left)
	pts.append_array(_quad(left[n], p1 + u * w1 * 0.9, right[n], 6))
	for i in range(n - 1, -1, -1):
		pts.append(right[i])
	_shape(pts, C_WOOD)
	var grain := PackedVector2Array()
	for i in range(2, n + 1):
		var sf := float(i) / n
		grain.append(p0 + d * sf + nrm * ((w0 + (w1 - w0) * pow(sf, 1.4)) * 0.5 * -0.3))
	_pl(grain, C_WOOD2, 3.0, true)
	for q in [[0.62, 1.0], [0.83, -1.0]]:
		var sf: float = q[0]
		var k: Vector2 = p0 + d * sf + nrm * ((w0 + (w1 - w0) * pow(sf, 1.4)) * 0.5 * float(q[1]) * 0.85)
		_dot(k, 4.5, C_WOOD2, 2.5)



## The shovel (the hotbar's digging tool): a straight haft, a cross-grip at
## the top, and a broad flat blade of shoulder-bone lashed on at the end.
func _shovel(p0: Vector2, p1: Vector2) -> void:
	var d := (p1 - p0).normalized()
	var n := Vector2(-d.y, d.x)
	var neck := p1 - d * 34.0
	_shape(PackedVector2Array([p0 + n * 4.0, neck + n * 4.0, neck - n * 4.0, p0 - n * 4.0]), C_WOOD, 3.0)
	_ln(p0 - n * 10.0, p0 + n * 10.0, C_WOOD2, 6.0, true)            # the grip
	var blade := PackedVector2Array([neck + n * 14.0, neck + d * 26.0 + n * 15.0, p1 + d * 10.0 + n * 6.0,
		p1 + d * 14.0, p1 + d * 10.0 - n * 6.0, neck + d * 26.0 - n * 15.0, neck - n * 14.0])
	_shape(blade, Pal.KEY_BONE.darkened(0.05), 3.0)
	_ln(neck + d * 6.0, p1 + d * 4.0, Pal.KEY_BONE.darkened(0.3), 2.0, true)
	for k in 2:
		var q := neck + d * (2.0 + k * 6.0)
		_ln(q + n * 9.0, q - n * 9.0, C_VINE, 3.0, true)              # lashed on


## The Flint Axe: a straight haft, and a blade of knapped flint — blue-grey,
## flaked to an edge — lashed into it with sinew.
func _axe(p0: Vector2, p1: Vector2) -> void:
	var d := (p1 - p0).normalized()
	var n := Vector2(-d.y, d.x)
	_shape(PackedVector2Array([p0 + n * 4.5, p1 + n * 5.0, p1 - n * 5.0, p0 - n * 4.5]), C_WOOD, 3.0)
	var hc := p1 - d * 14.0
	var blade := PackedVector2Array([hc + n * 4.0 - d * 12.0, hc + n * 30.0 - d * 20.0, hc + n * 40.0 - d * 2.0, hc + n * 34.0 + d * 18.0,
		hc + n * 4.0 + d * 12.0])
	_shape(blade, Color("6f7f8f"), 3.0)
	# the flake scars, and the pale fresh edge
	_pg(PackedVector2Array([hc + n * 10.0 - d * 8.0, hc + n * 26.0 - d * 14.0, hc + n * 22.0 + d * 2.0]), Color("8c9cab"))
	_pg(PackedVector2Array([hc + n * 12.0 + d * 8.0, hc + n * 24.0 + d * 4.0, hc + n * 28.0 + d * 14.0]), Color("5c6b7a"))
	_ln(hc + n * 30.0 - d * 20.0, hc + n * 40.0 - d * 2.0, Color("c9d6e2"), 2.5, true)
	_ln(hc + n * 40.0 - d * 2.0, hc + n * 34.0 + d * 18.0, Color("c9d6e2"), 2.5, true)
	# lashed on with sinew
	for k in 3:
		var q := hc + d * (-8.0 + k * 7.0)
		_ln(q + n * 7.0 - d * 3.0, q - n * 7.0 + d * 3.0, C_VINE, 3.0, true)


## The Firestone Hammer: a long haft bound with sinew, a heavy stone head,
## and the Firestone set in its face, glowing — brighter as the slam charges.
func _hammer(p0: Vector2, p1: Vector2) -> void:
	var d := (p1 - p0).normalized()
	var n := Vector2(-d.y, d.x)
	var charge_k := clampf(slam_charge / SLAM_READY, 0.0, 1.0) if slam_charge >= 0.0 else 0.0
	# the haft
	_shape(PackedVector2Array([p0 + n * 4.5, p1 - d * 20.0 + n * 5.5, p1 - d * 20.0 - n * 5.5, p0 - n * 4.5]), C_WOOD, 3.0)
	for k in 3:
		var q := p0 + d * (10.0 + k * 7.0)
		_ln(q + n * 6.0, q - n * 6.0, C_VINE, 3.0, true)
	# the head: a heavy block of stone across the end of the haft
	var hc := p1 - d * 6.0
	var head := PackedVector2Array([hc + n * 32.0 - d * 20.0, hc + n * 36.0 + d * 14.0, hc - n * 30.0 + d * 18.0, hc - n * 34.0 - d * 16.0])
	if charge_k > 0.0:
		_cc(hc, 40.0 + 30.0 * charge_k, Color(Pal.FLAME, 0.25 * charge_k))
	_shape(head, Color("7b7469"), 3.5)
	_shape(PackedVector2Array([hc + n * 30.0 - d * 16.0, hc + n * 32.0 + d * 4.0, hc - n * 26.0 + d * 8.0, hc - n * 28.0 - d * 12.0]), Color("948c80"), 0.0)
	_ln(hc + n * 10.0 - d * 12.0, hc - n * 4.0 + d * 10.0, Color("5b554c"), 2.5, true)
	# the Firestone, set in the head
	var g := hc + n * 2.0
	var pulse := 0.5 + 0.5 * sin(anim_t * 5.0)
	_cc(g, 14.0 + charge_k * 8.0, Color(Pal.EMBER_GLOW, 0.35 + 0.3 * pulse + 0.3 * charge_k))
	_shape(PackedVector2Array([g + n * 11.0, g + d * 9.0, g - n * 11.0, g - d * 9.0]), Pal.GEM, 2.5)
	_pg(PackedVector2Array([g + n * 6.0, g + d * 4.0, g - n * 2.0]), Pal.GEM_LIGHT)
	# embers drifting off it
	for i in 4:
		var q := fmod(anim_t * 0.9 + i * 0.25, 1.0)
		_cc(hc + Vector2(sin(i * 2.1 + anim_t * 2.0) * 16.0, -q * 70.0), 3.5 * (1.0 - q) + 0.8, Color(Pal.FLAME_CORE, 1.0 - q))
	if charge_k > 0.0:
		# sparks drawn in toward the gem as the charge builds
		for i in 8:
			var q := fmod(anim_t * 2.2 + i / 8.0, 1.0)
			var p := g + Vector2.from_angle(i * 0.79 + anim_t * 4.0) * 90.0 * (1.0 - q)
			_cc(p, 3.5 + 3.0 * q, Color(Pal.FLAME_CORE, q * charge_k))


func _leaf(a: Vector2, length: float, width: float, ang: float, col: Color) -> void:
	var dirv := Vector2(sin(ang), cos(ang))
	var tip := a + dirv * length
	var mid := a + dirv * length * 0.45
	var nrm := Vector2(-dirv.y, dirv.x)
	var pts := PackedVector2Array([a])
	pts.append_array(_quad(a, mid + nrm * width, tip, 6))
	pts.append_array(_quad(tip, mid - nrm * width, a, 6))
	pts.remove_at(pts.size() - 1)
	_shape(pts, col, 3.5)
	_ln(a, a + dirv * length * 0.85, Color(0.08, 0.2, 0.06, 0.55), 2.5, true)


func _arm(sh: Vector2, el: Vector2, hd: Vector2, bicep: float, fist: bool) -> void:
	if _bb != null:
		_hands.append(_bb.xf * hd)
	var buff := 1.0 + 0.22 * _sun_k          # SUNFIRE: thicker arms, a bigger bicep
	# a cartoon strongman's arm: a round shoulder, and forearms thicker than the upper arm
	_limb([sh, el, hd], [[17.0 * buff, 14.0 * buff], [15.0 * buff, 20.0 * buff]])
	_oval(sh.lerp(el, 0.55), sh.distance_to(el) * 0.4, bicep * 0.85 * (1.0 + 0.45 * _sun_k), _skin, 0.0, (el - sh).angle())
	if fist:
		_fist(hd, 10.5)


## A big fist: a round mitt with the knuckles marked.
func _fist(hd: Vector2, r: float = 12.0) -> void:
	_dot(hd, r, _skin, 3.5)
	var k := _skin.darkened(0.4)
	_ac(hd + Vector2(r * 0.15, 0), r * 0.6, -0.9, 0.9, 6, k, 2.0, true)
	_ln(hd + Vector2(-r * 0.2, -r * 0.55), hd + Vector2(r * 0.3, -r * 0.3), k, 2.0, true)


## Outline pass first, then fill, so segments merge cleanly. Each segment
## tapers from w[i][0] to w[i][1], the joints rounded.
func _limb(p: Array, w: Array) -> void:
	var dark := _skin.darkened(0.42)
	for i in p.size() - 1:
		var w0: float = w[i][0]
		var w1: float = w[i][1]
		_taper(p[i], p[i + 1], w0 + 5.0, w1 + 5.0, dark)
	for i in p.size() - 1:
		_taper(p[i], p[i + 1], w[i][0], w[i][1], _skin.darkened(0.16))
	for i in p.size() - 1:
		var w0: float = w[i][0]
		var w1: float = w[i][1]
		var off: Vector2 = LIGHT * w0 * 0.12
		_taper(p[i] + off, p[i + 1] + off, w0 * 0.72, w1 * 0.72, _skin)


## A limb segment that tapers from width w0 at a to w1 at b, ends rounded.
func _taper(a: Vector2, b: Vector2, w0: float, w1: float, col: Color) -> void:
	var d := b - a
	if d.length_squared() < 0.01:
		_cc(a, w0 * 0.5, col)
		return
	var n := Vector2(-d.y, d.x).normalized()
	var q := PackedVector2Array([a + n * w0 * 0.5, b + n * w1 * 0.5, b - n * w1 * 0.5, a - n * w0 * 0.5])
	if _bb != null:
		_bb.quad(q[0], q[1], q[2], q[3], col)
	else:
		_pg(q, col)
	_cc(a, w0 * 0.5, col)
	_cc(b, w1 * 0.5, col)


## A convex shape filled as a fan of triangles (no triangulating every frame).
func _fan(pts: PackedVector2Array, col: Color) -> void:
	if _bb == null:
		_pg(pts, col)
		return
	for i in range(1, pts.size() - 1):
		_bb.tri(pts[0], pts[i], pts[i + 1], col)


## The mane: spikes round the back of his head, painted with fur. The long
## ones swing most with the motion (_hair_off).
func _mane() -> void:
	var pts := PackedVector2Array()
	var sway := sin(anim_t * 2.4) * 1.5
	for i in MANE_SPIKES.size():
		var s: Array = MANE_SPIKES[i]
		var a := deg_to_rad(float(s[0]))
		var r: float = s[1]
		var swing := (r - 26.0) / 24.0
		pts.append(MANE_C + Vector2.from_angle(a + 0.2) * 23.0)
		pts.append(MANE_C + Vector2.from_angle(a) * r + (_hair_off + Vector2(sway, 0)) * swing)
	pts.append(MANE_C + Vector2.from_angle(deg_to_rad(-230.0)) * 18.0)
	pts.append(MANE_C + Vector2(4, 6))
	_fur(pts, FUR, C_HAIR, 0.6)
	# lighter streaks along the biggest spikes
	for i in [2, 3, 4]:
		var s: Array = MANE_SPIKES[i]
		var a := deg_to_rad(float(s[0]))
		var tip := MANE_C + Vector2.from_angle(a) * (float(s[1]) - 12.0) + _hair_off * 0.7
		_ln(MANE_C + Vector2.from_angle(a) * 24.0, tip, Color(C_HAIR_HI, 0.8), 3.0, true)


func _lit(pts: PackedVector2Array, amount: float = 0.87) -> PackedVector2Array:
	var mid := Vector2.ZERO
	for p in pts:
		mid += p
	mid /= float(pts.size())
	var span := 0.0
	for p in pts:
		span = maxf(span, p.distance_to(mid))
	var push := LIGHT * minf(5.0, span * 0.10)
	var out := PackedVector2Array()
	for p in pts:
		out.append(mid + (p - mid) * amount + push)
	return out


func _shape(pts: PackedVector2Array, fill: Color, w: float = OLW) -> void:
	if _bb != null:
		_bb.poly_pair(pts, fill.darkened(0.30), _lit(pts), fill)
	else:
		_pg(pts, fill.darkened(0.30))
		_pg(_lit(pts), fill)
	if w > 0.0:
		var ring := PackedVector2Array(pts)
		ring.append(pts[0])
		_pl(ring, fill.darkened(0.60), w * 0.62, true)


func _dot(c: Vector2, r: float, fill: Color, w: float = OLW) -> void:
	_cc(c, r, fill.darkened(0.30))
	_cc(c + LIGHT * r * 0.16, r * 0.86, fill)
	if w > 0.0:
		_ac(c, r, 0.0, TAU, 20, fill.darkened(0.60), w * 0.62, true)


func _oval(c: Vector2, rx: float, ry: float, fill: Color, w: float = OLW, rot: float = 0.0) -> void:
	_shape(_oval_pts(c, rx, ry, rot), fill, w)


## Samples a quadratic curve. Leaves out the start point unless asked, so
## consecutive curves can be chained without doubling up vertices.
func _quad(a: Vector2, c: Vector2, b: Vector2, n: int = 8, with_start: bool = false) -> PackedVector2Array:
	var out := PackedVector2Array()
	if with_start:
		out.append(a)
	for i in range(1, n + 1):
		var tq := float(i) / n
		out.append(a.lerp(c, tq).lerp(c.lerp(b, tq), tq))
	return out


## ------------------------------------------------------------------ SUNFIRE
## Learned once (GameState "sunfire"); the sun fills as he fights, finds
## shells and sits by fires; Q (or SUN) lets it out when it's full.
func sun_ready() -> bool:
	return GameState.abilities.has("sunfire") and sun_charge >= 1.0 and sun_t <= 0.0


func add_sun(amount: float) -> void:
	if sun_t > 0.0 or not GameState.abilities.has("sunfire") or sun_charge >= 1.0:
		return
	sun_charge = minf(sun_charge + amount, 1.0)
	if sun_charge >= 1.0:
		said.emit("The sun is FULL! Press Q (or SUN) for SUNFIRE!")


func start_sunfire() -> bool:
	if dead or talking or not sun_ready() or not Abilities.is_equipped("sunfire", self):
		return false
	sun_t = Sunfire.DURATION
	sun_charge = 0.0
	fury = -1.0
	slam_charge = -1.0
	invuln = maxf(invuln, 0.6)
	velocity.y = minf(velocity.y, -300.0)       # a hop as it bursts out of him
	add_to_group("light")
	add_to_group("glow")
	var level := get_parent()
	var ig := Sunfire.Ignite.new()
	ig.position = global_position + Vector2(0, -40)
	level.add_child(ig)
	var w := Sunfire.Word.new()
	w.position = global_position + Vector2(0, -150)
	level.add_child(w)
	if level.has_method("shake"):
		level.shake(9.0, 0.4)
	Critter.slow_time(get_tree(), 0.45, 0.35)
	relight(1.0)
	return true


func end_sunfire() -> void:
	sun_t = 0.0
	if not has_torch:
		remove_from_group("light")
	remove_from_group("glow")
	_sun_sparks.clear()
	FX.burst(get_parent(), global_position + Vector2(0, -40), "smoke")
	var pop := Treasure.FloatText.new()
	pop.text = "phew..."
	pop.position = global_position + Vector2(-24, -110)
	get_parent().add_child(pop)


## Every physics frame: the key, the clock, the embers he sheds.
func _update_sun(delta: float) -> void:
	var now: bool = Input.is_physical_key_pressed(KEY_Q) or touch.get("sun", false)
	if now and not _sun_prev and GameState.abilities.has("sunfire") and not Abilities.is_equipped("sunfire", self):
		said.emit("SUNFIRE isn't one of his two abilities — pick it in the menu (Esc).")
	elif now and not _sun_prev:
		if not start_sunfire() and GameState.abilities.has("sunfire") and sun_t <= 0.0:
			said.emit("The sun isn't full yet: hit beasts, grab shells, sit by a fire.")
	_sun_prev = now
	_shot_cd = maxf(_shot_cd - delta, 0.0)
	for s in _sun_sparks:
		s[2] = float(s[2]) - delta
		s[1] = (s[1] as Vector2) + Vector2(0, -60) * delta
		s[0] = (s[0] as Vector2) + (s[1] as Vector2) * delta
	_sun_sparks = _sun_sparks.filter(func(s): return float(s[2]) > 0.0)
	if sun_t <= 0.0:
		return
	sun_t = maxf(sun_t - delta, 0.0)
	if has_torch:
		torch_fuel = 1.0
	_sun_spark_in -= delta
	if _sun_spark_in <= 0.0:
		_sun_spark_in = 0.03 if absf(velocity.x) > 60.0 else 0.08
		var at := global_position + Vector2(randf_range(-14, 14), randf_range(-70, -10))
		_sun_sparks.append([at, Vector2(-velocity.x * 0.25 + randf_range(-30, 30), randf_range(-90, -20)), randf_range(0.35, 0.7)])
	if sun_t <= 0.0:
		end_sunfire()


func _sun_mul() -> float:
	return Sunfire.SPEED_MUL if sun_t > 0.0 else 1.0


func _jump_mul() -> float:
	return Sunfire.JUMP_MUL if sun_t > 0.0 else 1.0


## A fireball from alternating fists, straight out the way he faces.
func shoot_fireball() -> bool:
	if dead or _shot_cd > 0.0 or sun_t <= 0.0:
		return false
	_shot_cd = Sunfire.SHOT_GAP
	_shot_hand = 1 - _shot_hand
	throwing = 0.14
	var fb := Sunfire.Fireball.new()
	_throw_aim = aim()
	fb.position = global_position + Vector2(26.0 * facing, -48.0 + _shot_hand * 10.0)
	if _throw_aim.y == 0.0:
		fb.vel = Vector2(1000.0 * facing + velocity.x * 0.3, (_shot_hand * 2.0 - 1.0) * 18.0)
	else:
		fb.vel = _throw_aim * 1000.0                           # aimed, like a rock
	get_parent().add_child(fb)
	return true


## The aura, under everything: a gold halo breathing round him, and turning rays.
func _paint_sun_aura() -> void:
	var c := Vector2(0, -38)
	var warn := sun_t < Sunfire.WARN and fmod(sun_t * 6.0, 1.0) < 0.5
	var a := 0.35 if warn else 1.0
	var pulse := 1.0 + 0.06 * sin(anim_t * 8.0)
	for i in 3:
		_cc(c, (62.0 - i * 14.0) * pulse, Color(Sunfire.GOLD, (0.08 + i * 0.06) * a))
	for i in 10:
		var ang := i * TAU / 10.0 + anim_t * 1.6
		var p0 := c + Vector2.from_angle(ang) * 30.0
		var p1 := c + Vector2.from_angle(ang) * (66.0 + 10.0 * sin(anim_t * 7.0 + i)) * pulse
		_ln(p0, p1, Color(Sunfire.WHITE_HOT, 0.22 * a), 4.0)
	# behind him: fire blazing up off his shoulders and back, trailing as he moves
	var lean := clampf(-velocity.x / 520.0, -0.9, 0.9)
	var g := 1.0 + 0.15 * _sun_k
	var f := float(facing)
	for bf in [[Vector2(-f * 22.0, -52.0), 34.0], [Vector2(f * 20.0, -54.0), 28.0], [Vector2(-f * 24.0, -30.0), 26.0], [Vector2(-f * 6.0, -62.0), 30.0]]:
		var bp: Vector2 = bf[0]
		Sunfire.flame(_bb, bp * g, float(bf[1]) * _sun_k, anim_t * 1.2 + bp.x * 0.3, 0.85 * a, lean)


## Fire in both fists and in his hair; the embers he sheds.
## The air kicks' light, in his own upright frame (it doesn't flip with him):
## the snap kick's whoosh up to a star at the foot, and the flash kick's
## crescent, white-hot at the foot and fading to orange, chasing it round.
func _paint_kick() -> void:
	if not _kicking() or dead:
		return
	var k := 1.0 - attacking / _swing_time
	_stm(Transform2D(0.0, Vector2(ART * facing, ART), 0.0, Vector2.ZERO))
	if _swing_kind == "kick1":
		var hip := Vector2(22, -62)
		var up := sin(clampf(k / 0.55, 0.0, 1.0) * PI * 0.5)
		var fade := 1.0 - clampf((k - 0.45) / 0.55, 0.0, 1.0)
		var a1 := lerpf(0.785, -0.744, up)
		for w in 3:
			_ac(hip, 68.0 - w * 9.0, a1, 0.785, 12, Color(0.85, 0.95, 1.0, (0.85 - w * 0.25) * fade), 10.0 - w * 3.0)
		if up > 0.95 and fade > 0.2:
			var tip := Vector2(80, -114)
			var s := 26.0 * fade
			_ln(tip + Vector2(0, -s), tip + Vector2(0, s), Color(1, 1, 1, 0.9 * fade), 5.0)
			_ln(tip + Vector2(-s, 0), tip + Vector2(s, 0), Color(1, 1, 1, 0.9 * fade), 5.0)
	else:
		var e := k * k * (3.0 - 2.0 * k)
		var pivot := Vector2(0, -38)
		var now := -0.860 - TAU * e              # where the foot is: it started up and ahead
		var tail := minf(TAU * e, 2.6)
		var fade := 1.0 - clampf((k - 0.75) / 0.25, 0.0, 1.0)
		for l in [[110.0, 22.0, Color(1.0, 0.55, 0.12, 0.35)], [104.0, 13.0, Color(1.0, 0.82, 0.3, 0.7)], [100.0, 6.0, Color(1.0, 0.98, 0.85, 0.95)]]:
			var col: Color = l[2]
			_ac(pivot, l[0], now, now + tail, 24, Color(col, col.a * fade), l[1])
		for i in 5:                              # embers flung off the crescent
			var a := now + tail * (i / 5.0) + sin(anim_t * 20.0 + i) * 0.05
			_cc(pivot + Vector2.from_angle(a) * (120.0 + 10.0 * sin(anim_t * 13.0 + i * 2.0)), 4.0, Color(1.0, 0.8, 0.3, 0.8 * fade))
		_cc(pivot + Vector2.from_angle(now) * 95.0, 16.0, Color(1.0, 0.95, 0.7, 0.45 * fade))
	_st(Vector2.ZERO, 0.0, Vector2.ONE)


func _paint_sun_flames() -> void:
	var warn := sun_t < Sunfire.WARN and fmod(sun_t * 6.0, 1.0) < 0.5
	var a := 0.45 if warn else 1.0
	# the fire trails behind him as he moves
	var lean := clampf(-velocity.x / 520.0, -0.9, 0.9)
	for i in _hands.size():
		var h: Vector2 = _hands[i]
		_bb.circle(h, 9.0, Color(Sunfire.HOT, 0.8 * a), 12)
		Sunfire.flame(_bb, h + Vector2(0, 4), 28.0, anim_t * 1.3 + i * 2.1, a, lean * 0.6)
	for k in 3:
		var hx := (k - 1) * 7.0
		Sunfire.flame(_bb, _head_at + Vector2(hx, 4), 18.0 + 8.0 * float(k == 1), anim_t + k * 1.7, 0.85 * a, lean)
	for s in _sun_sparks:
		var q: float = clampf(float(s[2]) / 0.7, 0.0, 1.0)
		_bb.circle(to_local(s[0]), 3.0 * q + 0.8, Color(Sunfire.GOLD, q), 6)


## Through the dark: his halo, the fists' glow, the embers.
func draw_glow(g) -> void:   # g: the glow layer's Batch
	if sun_t <= 0.0 or dead:
		return
	var o := global_position + Vector2(0, -38)
	var warn := sun_t < Sunfire.WARN and fmod(sun_t * 6.0, 1.0) < 0.5
	var a := 0.4 if warn else 1.0
	g.draw_circle(o, 90.0 + 8.0 * sin(anim_t * 8.0), Color(1.0, 0.8, 0.3, 0.16 * a))
	g.draw_circle(o, 48.0, Color(1.0, 0.85, 0.45, 0.18 * a))
	for h in _hands:
		g.draw_circle(to_global(h), 15.0, Color(1.0, 0.55, 0.15, 0.3 * a))
		g.draw_circle(to_global(h), 5.0, Color(1.0, 0.95, 0.7, 0.7 * a))
	g.draw_circle(to_global(_head_at), 16.0, Color(1.0, 0.6, 0.2, 0.45 * a))
	for s in _sun_sparks:
		var q: float = clampf(float(s[2]) / 0.7, 0.0, 1.0)
		g.draw_circle(s[0], 2.5, Color(1.0, 0.85, 0.4, q))


## ------------------------------------------------------------------ STOMP
## In the air, T: curl up and spin (the somersault, once — twice after a
## double jump), hang a moment, then drop like a meteor. Landing makes the
## blast (Stomp.Blast) that knocks beasts flat and opens stomp spots.
func _update_stomp(delta: float) -> void:
	var now: bool = Input.is_physical_key_pressed(KEY_T) or touch.get("stomp", false)
	if now and not _stomp_prev and stomp_state == "" and not is_on_floor() and vine == null \
			and not wall_cling and fury < 0.0 and slam_charge < 0.0 and not dead:
		stomp_level = 2 if _jumps_left <= 0 else 1
		stomp_state = "charge"
		# T with left or right held: the METEOR DASH, that way
		var lr := 0
		if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D) or touch["right"]:
			lr += 1
		if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A) or touch["left"]:
			lr -= 1
		stomp_dir = lr
		if lr != 0:
			facing = lr
		_dash_hit.clear()
		_stomp_t = 0.0
		_air_glide = false
		# the spin: the somersault, once (twice for the mega stomp)
		flip_dir = float(facing)
		flip_back = false
		flip_turns = float(stomp_level)
		flip_len = Stomp.CHARGE[stomp_level]
		flip_t = flip_len
		_ghosts.clear()
		_flipped = true
		var tr := Stomp.Trail.new()
		tr.player = self
		tr.level = stomp_level
		tr.dir = stomp_dir
		get_parent().add_child(tr)
	_stomp_prev = now
	if stomp_state != "" and (vine != null or dead or talking):
		stomp_state = ""
		return
	match stomp_state:
		"charge":
			_stomp_t += delta
			# hanging in the air: a little lift, then still
			velocity = Vector2(0.0, -70.0 if _stomp_t < 0.08 else 0.0)
			if _stomp_t >= Stomp.CHARGE[stomp_level]:
				stomp_state = "dive" if stomp_dir == 0 else "dash"
				_stomp_t = 0.0
				flip_t = 0.0
		"dash":
			_stomp_t += delta
			velocity = Vector2(stomp_dir * Stomp.DASH_SPEED[stomp_level], 0.0)
			_fall_t = 0.0
			_air_glide = false
			# what it rams on the way: knocked, burned by the speed
			for c in get_tree().get_nodes_in_group("critters"):
				var cr := c as Critter
				if cr == null or cr.dying > 0.0 or _dash_hit.has(cr):
					continue
				var d := cr.global_position - global_position
				if absf(d.x) < 70.0 and absf(d.y + 30.0) < 70.0:
					_dash_hit.append(cr)
					cr.take_hit(Stomp.DAMAGE[stomp_level], stomp_dir)
					_hit_word(cr.global_position)
			if _stomp_t >= Stomp.DASH_TIME[stomp_level]:
				# spent: he drops out of it, still flying a little
				stomp_state = ""
				velocity = Vector2(stomp_dir * 260.0, -120.0)
		"dive":
			velocity = Vector2(0.0, Stomp.SPEED[stomp_level])
			_fall_t = 0.0
			_air_glide = false


func _stomp_impact() -> void:
	var blast := Stomp.Blast.new()
	blast.level = stomp_level
	blast.position = global_position
	stomp_state = ""
	_land = LAND_TIME
	_land_amt = 1.0
	invuln = maxf(invuln, 0.3)
	get_parent().add_child(blast)


## The get-up, each frame while it runs. True while the splat still holds him
## (the caller skips the rest of the frame); the flex lets everything through,
## and any move, jump or swing ends it.
func _update_getup(delta: float) -> bool:
	var before := getup
	getup += delta
	if getup < GETUP_SPLAT:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		if not is_on_floor():
			velocity.y += GRAVITY_DOWN * delta
		move_and_slide()
		_was_floor = is_on_floor()
		return true
	if before < GETUP_FLEX and getup >= GETUP_FLEX:
		var boast := WordPop.new()
		boast.text = BOASTS[randi() % BOASTS.size()]
		boast.size = 30
		boast.centered = true
		boast.tilt = 0.06 * float(facing)
		boast.life = 1.1
		boast.position = global_position + Vector2(0, -110)
		get_parent().add_child.call_deferred(boast)
	var busy: bool = Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_D) \
		or Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_RIGHT) \
		or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_W) \
		or Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_J) \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
		or touch["left"] or touch["right"] or touch["jump"] or touch["attack"]
	if getup >= GETUP_TIME or (busy and getup >= GETUP_SPLAT) or not is_on_floor():
		getup = -1.0
	return false


## A comic word where a blow lands on a creature, by weapon.
func _hit_word(at: Vector2) -> void:
	var word := WordPop.new()
	var words := ["POW!", "BAM!"]
	if has_stick and not axe_out:
		match _swing_kind:
			"hammer", "dig":
				words = ["WHAM!", "KRAK!"]
			"axe0", "axe1", "axe2", "axe3":
				words = ["SHNK!", "CHOP!"]
			"homerun":
				return                       # it has its own: HOME RUN!
			"club1":
				words = ["WHACK!", "SMACK!"]
			"club2":
				words = ["KA-BONK!", "KRAKOOM!"]
				word.size = 27
				word.life = 0.7
			_:
				words = ["BONK!", "THWAK!"]
	word.text = words[randi() % words.size()]
	if word.size == 30:
		word.size = 22                       # (the finisher set its own)
	word.color = Color("fff4d6")
	word.star = Color("e8823a", 0.85)
	word.centered = true
	word.tilt = randf_range(-0.25, 0.25)
	if word.life > 0.8:
		word.life = 0.45
	word.position = at + Vector2(-facing * 4.0, -60.0)
	get_parent().add_child(word)


## The dash meets a wall. Diggable rock (a Terrain): he DRILLS through it, a
## blow strong enough to break any rock, and flies on. Anything else: BOOM.
func _dash_wall() -> void:
	var front := global_position + Vector2(stomp_dir * 30.0, -38.0)
	var drilled := false
	for t in get_tree().get_nodes_in_group("diggable"):
		for i in 3:
			if t.dig_at(front, 64.0, 6):
				drilled = true
	if drilled:
		var lvl := get_parent()
		if lvl.has_method("shake"):
			lvl.shake(3.0, 0.08)
		return
	var blast := Stomp.Blast.new()
	blast.level = stomp_level
	blast.position = global_position + Vector2(stomp_dir * 20.0, 0)
	stomp_state = ""
	velocity = Vector2(-stomp_dir * 220.0, -260.0)      # bounced back off it
	invuln = maxf(invuln, 0.3)
	get_parent().add_child(blast)
