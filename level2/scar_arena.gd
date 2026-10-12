extends Node2D
## OLD SCAR'S CLEARING, CHANGING AS THE FIGHT GOES ON (level2/old_scar.gd asks;
## level2.gd makes it): the arena is part of the fight.
## - CLOUDS OVER THE MOON (from phase 2): every so often they drift across it;
##   the clearing goes darker, his moonlit outline fades, and he favours the
##   eye trick while it lasts (is_dark()).
## - THE DEAD TREE (phase 3): his roar brings it crashing down across the
##   clearing: a LOG to stand on, and when he charges blind he slams into it
##   (log_stop()) and stands there dazed.
## - BURNING BRANCHES (phase 4, his rage): torn from the treetops, each with a
##   shadow first; it burns where it lands a while: it hurts to touch, but it
##   is FIRE, and his pounce won't go through its light.
## reset() takes it all away (he beat the man: back to the start).

var level: Node                        ## level2
var arena := Rect2()
var ground_y := 0.0
var dark := 0.0                        ## 0 .. 1: the moon behind the clouds
var _clouds_on := false
var _cloud_t := 0.0
var _cloud_k := 0.0                    ## the clouds' drift across the moon (0 clear .. 1 covered)
var _sky: CanvasLayer
var _cloud_node: Node2D
var _extra0 := 0.0
var _log: StaticBody2D = null
var _tree: Node2D = null
var _branches: Array = []
var _told := {}

const TREE_AT := 0.4                   ## where the dead tree stands (along the clearing)
const LOG_W := 300.0
const LOG_H := 38.0


func setup(lv: Node, area: Rect2, ground: float) -> void:
	level = lv
	arena = area
	ground_y = ground
	z_index = 2
	_sky = CanvasLayer.new()
	_sky.layer = -110                  # (over the moon, behind the forest)
	add_child(_sky)
	_cloud_node = Clouds.new()
	_cloud_node.arena = self
	_sky.add_child(_cloud_node)
	_extra0 = -999.0                   # (read from the dark once it exists)
	_tree = DeadTree.new()
	_tree.position = Vector2(arena.position.x + arena.size.x * TREE_AT, ground_y)
	add_child(_tree)


func _say(key: String, line: String, secs := 3.5) -> void:
	if _told.has(key):
		return
	_told[key] = true
	level.hud.say(line, secs)


## ------------------------------------------------------------------ the clouds
func clouds_on() -> void:
	_clouds_on = true
	_cloud_t = 6.0


func is_dark() -> bool:
	return dark > 0.6


func _process(delta: float) -> void:
	if _clouds_on:
		# a dark spell every 15 s: the clouds come over in 2, stay 5, go in 2
		_cloud_t += delta
		var c := fmod(_cloud_t, 15.0)
		var want := 0.0
		if c > 6.0 and c < 15.0:
			want = clampf(minf((c - 6.0) / 2.0, (15.0 - c) / 2.0), 0.0, 1.0)
		_cloud_k = want
		var was := dark
		dark = smoothstep(0.2, 0.9, _cloud_k)
		if dark > 0.6 and was <= 0.6:
			_say("clouds", "OLD BONGO:  \"Clouds over the moon! In the dark, watch for his EYES!\"", 3.5)
	else:
		dark = move_toward(dark, 0.0, delta)
		_cloud_k = move_toward(_cloud_k, 0.0, delta * 0.5)
	if level.night != null and _extra0 == -999.0:
		_extra0 = level.night.extra
	if level.night != null and level._fight:
		level.night.extra = _extra0 + 0.13 * dark
		level.night.moon_r = 70.0 * (1.0 - dark)
	_cloud_node.queue_redraw()


## ------------------------------------------------------------------ the dead tree, and the log
func fell_tree() -> void:
	if _tree == null or _log != null:
		return
	(_tree as DeadTree).fall(self)


## The tree is down: a log across the clearing (a one-way top to stand on).
func _make_log() -> void:
	_log = StaticBody2D.new()
	_log.position = _tree.position
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(LOG_W - 20.0, 16.0)
	cs.shape = sh
	cs.position = Vector2(LOG_W * 0.5, -LOG_H + 8.0)
	cs.one_way_collision = true
	_log.add_child(cs)
	add_child(_log)
	if level.has_method("shake"):
		level.shake(12.0, 0.6)
	var d := Critter.DeathPop.new()
	d.dust = true
	d.big = true
	d.position = _tree.position + Vector2(LOG_W * 0.5, 0)
	level.add_child(d)
	_say("log", "OLD BONGO:  \"The old tree fell! When he CHARGES, get behind it — he'll run right into it!\"", 4.0)


## His charge at `x` going `vx`: the x where the log stops him, or INF.
func log_stop(x: float, vx: float) -> float:
	if _log == null:
		return INF
	var a := _log.position.x
	var b := a + LOG_W
	if vx > 0.0 and x + 70.0 >= a and x < a + 20.0:
		return a - 70.0
	if vx < 0.0 and x - 70.0 <= b and x > b - 20.0:
		return b + 70.0
	return INF


func log_hit() -> void:
	if _tree != null:
		(_tree as DeadTree).shudder = 0.5


## ------------------------------------------------------------------ burning branches
## A branch torn from the treetops comes down at x: a shadow first, then fire.
func drop_branch(x: float) -> void:
	var br := BurningBranch.new()
	br.arena = self
	br.position = Vector2(clampf(x, arena.position.x + 80.0, arena.end.x - 80.0), ground_y)
	add_child(br)
	_branches.append(br)


## A red pulse and embers: his last stand begins.
func rage() -> void:
	var f := RageFlash.new()
	level.add_child(f)
	_say("rage", "OLD BONGO:  \"He's ENRAGED! Watch the branches — and the FIRE where they fall!\"", 4.0)


## He's beaten: the clouds clear off the moon (the log stays where it fell).
func calm() -> void:
	_clouds_on = false
	for b in _branches:
		if is_instance_valid(b):
			b.queue_free()
	_branches.clear()


## He beat the man: back to how the clearing was.
func reset() -> void:
	_clouds_on = false
	dark = 0.0
	_cloud_k = 0.0
	for b in _branches:
		if is_instance_valid(b):
			b.queue_free()
	_branches.clear()
	if _log != null:
		_log.queue_free()
		_log = null
	if _tree != null:
		(_tree as DeadTree).stand_up()
	if level.night != null:
		if _extra0 != -999.0:
			level.night.extra = _extra0
		level.night.moon_r = 70.0


## ================================================================== the parts
## The clouds: three dark puffs that drift across the moon (screen space).
class Clouds extends Node2D:
	var arena: Node

	func _draw() -> void:
		var k: float = arena._cloud_k
		if k <= 0.01:
			return
		var moon: Vector2 = arena.level.night.moon
		for i in 3:
			var x := moon.x + lerpf(-420.0 - i * 120.0, 0.0 + i * 50.0 - 60.0, k)
			var y: float = moon.y + [-20.0, 25.0, 0.0][i]
			var c := Color(0.07, 0.08, 0.14, 0.92)
			for j in 5:
				draw_circle(Vector2(x + j * 34.0 - 68.0, y - absf(j - 2.0) * -8.0 + sin(i * 2.0 + j) * 6.0), 38.0 - absf(j - 2.0) * 6.0, c)
			# the moon catches their edges
			draw_arc(Vector2(x, y - 6.0), 92.0, -2.6, -0.5, 18, Color(0.75, 0.82, 1.0, 0.35 * (1.0 - absf(k - 0.5))), 3.0)


## The dead tree at the clearing's side: grey, bare, cracked. In phase 3 it
## creaks, tips, and comes down across the clearing; a log ever after.
class DeadTree extends Node2D:
	var ang := 0.0                     ## 0 upright .. PI/2 down (it falls to the right)
	var shudder := 0.0
	var _arena: Node
	var _falling := false
	var _t := 0.0

	func _ready() -> void:
		z_index = -1

	func fall(a: Node) -> void:
		_arena = a
		_falling = true
		_t = 0.0

	func stand_up() -> void:
		_falling = false
		ang = 0.0
		queue_redraw()

	func _process(delta: float) -> void:
		if shudder > 0.0:
			shudder = maxf(shudder - delta, 0.0)
			queue_redraw()
		if not _falling:
			return
		_t += delta
		if _t < 0.6:
			ang = sin(_t * 40.0) * 0.03                  # the creak
		else:
			var k := clampf((_t - 0.6) / 0.75, 0.0, 1.0)
			ang = PI * 0.5 * k * k
			if k >= 1.0:
				_falling = false
				_arena._make_log()
		queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		var bark := Color("6e6a64")
		var dark := Color("4a4640")
		var rot := ang + sin(shudder * 60.0) * 0.02 * shudder
		draw_set_transform(Vector2.ZERO, rot, Vector2.ONE)
		var w := 46.0
		var h := 300.0
		# the trunk, lying along its fall: bottom at the origin, top at -h
		b.quad(Vector2(-w * 0.5 - 4, 0), Vector2(-w * 0.35, -h), Vector2(w * 0.35, -h), Vector2(w * 0.5 + 4, 0), dark)
		b.quad(Vector2(-w * 0.5, -2), Vector2(-w * 0.3, -h + 4), Vector2(w * 0.3, -h + 4), Vector2(w * 0.5, -2), bark)
		for k in 6:                                         # the cracks in the bark
			var y := -30.0 - k * 45.0
			b.line(Vector2(-10 + k % 2 * 8, y), Vector2(-4 + k % 2 * 8, y - 30), dark, 2.4)
		# two broken limbs and the snapped top
		b.quad(Vector2(10, -170), Vector2(70, -230), Vector2(76, -224), Vector2(16, -158), bark)
		b.quad(Vector2(-12, -220), Vector2(-60, -262), Vector2(-64, -256), Vector2(-16, -208), bark)
		b.tri(Vector2(-16, -h + 2), Vector2(16, -h + 2), Vector2(4, -h - 34), bark)
		b.tri(Vector2(-8, -h + 2), Vector2(4, -h - 34), Vector2(-14, -h - 16), dark)
		# moss low down, the moon on its right edge
		b.circle(Vector2(-14, -12), 12.0, Color("4a6a3a"), 8)
		b.line(Vector2(w * 0.5, -4), Vector2(w * 0.32, -h + 6), Color(0.78, 0.86, 1.0, 0.45), 2.4)
		b.draw(self)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A burning branch: its shadow grows where it will land, then down it comes
## and burns there a while. A light (his pounce won't go through it); it hurts
## the man who touches it.
class BurningBranch extends Node2D:
	var arena: Node
	var t := 0.0
	var _hurt_cd := 0.0
	const WARN := 1.0
	const BURN := 5.0

	func _ready() -> void:
		z_index = 3
		add_to_group("light")
		add_to_group("glow")

	func light() -> Vector4:
		if t < WARN:
			return Vector4.ZERO
		var k := clampf((WARN + BURN - t) / 1.0, 0.0, 1.0)
		return Vector4(global_position.x, global_position.y - 30.0, 170.0 * k * (1.0 + sin(t * 11.0) * 0.04), 1.0)

	func light_strength() -> float:
		return 1.0

	func _process(delta: float) -> void:
		t += delta
		_hurt_cd = maxf(_hurt_cd - delta, 0.0)
		if t >= WARN and t - delta < WARN:
			var lv: Node = arena.level
			if lv.has_method("shake"):
				lv.shake(6.0, 0.25)
			FX.burst(lv, global_position + Vector2(0, -20), "sparks", 0.0)
		if t > WARN and t < WARN + BURN:
			var man: CaveMan = arena.level.player
			if man != null and _hurt_cd <= 0.0 and absf(man.global_position.x - global_position.x) < 70.0 and absf(man.global_position.y - global_position.y) < 60.0:
				man.hurt(1, global_position.x)
				_hurt_cd = 1.0
		if t > WARN + BURN:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var b := Batch.new()
		if t < WARN:
			# the shadow, growing; the branch high up, falling into view at the end
			var k := t / WARN
			b.ellipse(Vector2(0, -3), 40.0 + 40.0 * k, 8.0 + 6.0 * k, Color(0, 0, 0, 0.25 + 0.35 * k))
			var y := -720.0 * (1.0 - k * k)
			if k > 0.5:
				_branch(b, Vector2(0, y - 20.0), k * 3.0)
			b.draw(self)
			return
		_branch(b, Vector2(0, -14), 0.35)
		b.draw(self)

	func _branch(b: Batch, at: Vector2, spin: float) -> void:
		var d := Vector2.from_angle(spin)
		var n := Vector2(-d.y, d.x)
		b.quad(at - d * 70.0 + n * 9.0, at + d * 70.0 + n * 6.0, at + d * 70.0 - n * 6.0, at - d * 70.0 - n * 9.0, Color("4a3020"))
		b.quad(at + d * 10.0, at + d * 40.0 + n * 34.0, at + d * 46.0 + n * 30.0, at + d * 18.0, Color("4a3020"))

	func draw_glow(g) -> void:
		if t < WARN * 0.5:
			return
		var p := global_position + Vector2(0, -14)
		var fade := clampf((WARN + BURN - t) / 1.0, 0.0, 1.0)
		for i in 5:
			var x := -56.0 + i * 28.0
			var h := 30.0 + 18.0 * sin(t * 9.0 + i * 1.7)
			var base := p + Vector2(x, 0)
			g.draw_colored_polygon(PackedVector2Array([base + Vector2(-12, 0), base + Vector2(0, -h), base + Vector2(12, 0)]), Color(Pal.EMBER_GLOW, 0.85 * fade))
			g.draw_colored_polygon(PackedVector2Array([base + Vector2(-6, 0), base + Vector2(0, -h * 0.55), base + Vector2(6, 0)]), Color(Pal.FLAME_CORE, 0.9 * fade))


## His last stand: a red pulse over everything, fading.
class RageFlash extends CanvasLayer:
	var t := 0.0
	var _r: ColorRect

	func _ready() -> void:
		layer = 5
		_r = ColorRect.new()
		_r.set_anchors_preset(Control.PRESET_FULL_RECT)
		_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_r.color = Color(1.0, 0.25, 0.1, 0.45)
		add_child(_r)

	func _process(delta: float) -> void:
		t += delta
		_r.color.a = 0.45 * maxf(0.0, 1.0 - t / 0.9)
		if t > 0.9:
			queue_free()
