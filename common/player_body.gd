class_name CaveManBody
extends CharacterBody2D
## The caveman: what he DOES. How he LOOKS is common/player.gd (CaveMan extends
## this, adding only the drawing); the game uses CaveMan everywhere. He never
## changes across the game, only what he holds. Origin is at his feet.
##
## Where things are (search for the "## ----" headers):
##   constants + state       movement, jumps, weapons, torch, fury, SUNFIRE, STOMP vars
##   _physics_process        one frame of him: death, timers, fire, hammer charge, walking,
##                           vines, wall-kick, jumps, attack, throw, _update_stomp, move
##   weapons                 swings, _apply_swing (every hit lands here), specials, AIR KICKS
##   vines                   swinging and letting go
##   hurt / hurt_toss / die   being hit (Sunfire absorbs, the stomp is untouchable)
##   torch                   fuel, light() for Night, wood and fire
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
## Design units -> game pixels: he is drawn ~2.6x game size and scaled down in one
## transform (common/player.gd). ~186 tall -> ~78 px (the topknot on top).
const ART := 0.42
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
	if held_left():
		dir -= 1.0
	if held_right():
		dir += 1.0
	if scorch_t > 0.0:
		dir = _panic_dir
	if dir != 0.0:
		facing = int(signf(dir))
	_vine_cd = maxf(_vine_cd - delta, 0.0)
	if vine != null:
		_swing(delta, dir)
		return
	_place_hitbox()

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
	var up_held := held_up()
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

	_input_hit(delta, dir, up_held)

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


## HIT (J, the mouse, the HIT button): what the slot in his hand does, or a
## swing with the weapon: DOWN digs, the air kicks, the pogo, the combos, the
## ram. A tap a little early is buffered. (A phase of _physics_process.)
func _input_hit(delta: float, dir: float, up_held: bool) -> void:
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
		var down_held := held_down()
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


## Where his blow lands this frame: the hitbox follows the swing (its reach
## and height), the aim (up: the uppercut's tall box), digging, the cyclone's
## turn, the kicks. (A phase of _physics_process.)
func _place_hitbox() -> void:
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


## Stride grows with speed up to a limit. Used by BOTH the foot placement and
## the phase rate, which is what keeps a planted foot exactly still on the
## ground: phase advances by distance / stride, so the foot sweeps backwards
## at precisely the speed the body moves forwards.
func _stride_amp(k: float) -> float:
	return STRIDE * clampf(k, 0.55, 1.0)


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


## The ONE place the direction keys are read: arrows, WASD, or the touch pad.
func held_left() -> bool:
	return Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT) or touch["left"]


func held_right() -> bool:
	return Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT) or touch["right"]


func held_up() -> bool:
	return Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) or touch.get("up", false)


func held_down() -> bool:
	return Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN) or touch.get("down", false)


func aim() -> Vector2:
	var up := held_up()
	var down := held_down()
	var h := 0.0
	if held_left():
		h -= 1.0
	if held_right():
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
		if held_right():
			lr += 1
		if held_left():
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
