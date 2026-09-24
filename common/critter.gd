class_name Critter
extends Area2D
## Base for everything that can hurt the caveman or be hit by him.
## Subclasses set up their shape in _setup, move in _tick, and draw themselves.

var hp := 1
var damage := 1
var flash := 0.0
var dying := 0.0
var player: CaveMan

## Stomping. Landing on a critter from above crushes it.
## Big or spiked things set stompable = false so the player learns the exception.
var stompable := true
var stomp_top := -14.0    ## y offset of this critter's top, relative to its origin
var stomp_damage := 99    ## a clean landing kills almost anything small
var stomp_push := 0.0     ## sideways shove handed to the player, so big things throw him clear
var _prev_feet := -1000000.0   ## where his feet were last frame, so fast falls still register
var _prev_vy := 0.0            ## and how fast he was going, so the landing frame still counts


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	monitorable = true
	add_to_group("critters")
	_setup()


func _setup() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func _on_hit(_from_dir: int) -> void:
	pass


func _on_die() -> void:
	pass


func _on_stomped() -> void:
	pass


## Caught in a fire burst. Most things simply take the damage; a few react.
func burned(dmg: int, from: Vector2) -> void:
	var d := int(signf(global_position.x - from.x))
	take_hit(dmg, d if d != 0 else 1)


func take_hit(dmg: int, from_dir: int) -> void:
	if dying > 0.0:
		return
	hp -= dmg
	flash = 0.15
	_on_hit(from_dir)
	if hp <= 0:
		dying = 0.35
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		_on_die()


## True when he is coming down and his feet are above this critter's back.
## Checks last frame as well as this one: at full fall speed he covers ~10 px
## per physics step, so a single-frame test misses the landing entirely.
func _is_stomp() -> bool:
	if not stompable or dying > 0.0 or player == null:
		return false
	# Landing on the floor zeroes his fall speed in the SAME frame he touches a
	# ground-level critter, so testing only the current velocity makes anything
	# standing on the floor impossible to stomp. Last frame's speed counts too.
	if player.velocity.y <= 40.0 and _prev_vy <= 40.0:
		return false
	# The faster he is falling, the further past the ideal point he will be by
	# the time this runs, so the allowance grows with fall speed.
	var slack := 18.0 + maxf(player.velocity.y, 0.0) * 0.035
	var line := global_position.y + stomp_top + slack
	return player.global_position.y <= line or _prev_feet <= line


func _physics_process(delta: float) -> void:
	flash = maxf(flash - delta, 0.0)
	if dying > 0.0:
		dying -= delta
		modulate.a = clampf(dying / 0.35, 0.0, 1.0)
		if dying <= 0.0:
			queue_free()
			return
		queue_redraw()
		return

	if player == null:
		var p := get_tree().get_first_node_in_group("player")
		if p != null:
			player = p as CaveMan

	_tick(delta)

	if player != null and not player.dead and overlaps_body(player):
		if _is_stomp():
			_on_stomped()
			take_hit(stomp_damage, 0)
			# bounce him off to whichever side he landed on, so he cannot keep
			# dropping onto the same back over and over
			var away := signf(player.global_position.x - global_position.x)
			if away == 0.0:
				away = float(player.facing)
			player.stomp_bounce(stomp_push * away)
		elif damage > 0:
			player.hurt(damage, global_position.x)

	if player != null:
		_prev_feet = player.global_position.y
		_prev_vy = player.velocity.y

	# Redrawing is only needed for ANIMATION. A creature far off screen still
	# moves (its transform updates without re-running _draw), so re-running the
	# drawing for it is pure waste — and most of a 9,400 px level is off screen.
	if player == null or absf(player.global_position.x - global_position.x) < 820.0:
		queue_redraw()


## ---------------------------------------------------------------- drawing
## Shared by every creature, so one change restyles the whole bestiary.
## Every filled shape is drawn TWICE: once in a shadow tone, then again pulled
## in toward the light in the base tone. That leaves a shaded rim around each
## form, which is what makes a shape read as rounded rather than as a sticker.
## Outlines are kept, but thin and tinted from the fill — never black.
const OLW := 2.5
const LIGHT := Vector2(0.55, -0.83)   ## the sun sits high and to the right


func _pts_oval(c: Vector2, rx: float, ry: float, rot: float = 0.0, n: int = 10) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cr := cos(rot)
	var sr := sin(rot)
	for i in n:
		var a := TAU * i / float(n)
		var v := Vector2(cos(a) * rx, sin(a) * ry)
		pts.append(c + Vector2(v.x * cr - v.y * sr, v.x * sr + v.y * cr))
	return pts


func _fill(pts: PackedVector2Array, col: Color) -> void:
	draw_colored_polygon(pts, col)


## The same outline, shrunk toward its own centre and nudged into the light.
func _lit(pts: PackedVector2Array, amount: float = 0.86) -> PackedVector2Array:
	var mid := Vector2.ZERO
	for p in pts:
		mid += p
	mid /= float(pts.size())
	var span := 0.0
	for p in pts:
		span = maxf(span, p.distance_to(mid))
	var push := LIGHT * minf(2.6, span * 0.10)
	var out := PackedVector2Array()
	for p in pts:
		out.append(mid + (p - mid) * amount + push)
	return out


func _shape(pts: PackedVector2Array, col: Color, w: float = OLW) -> void:
	draw_colored_polygon(pts, col.darkened(0.30))
	draw_colored_polygon(_lit(pts), col)
	if w > 0.0:
		var ring := PackedVector2Array(pts)
		ring.append(pts[0])
		draw_polyline(ring, col.darkened(0.62), w * 0.7, false)


func _oval(c: Vector2, rx: float, ry: float, col: Color, w: float = OLW, rot: float = 0.0) -> void:
	_shape(_pts_oval(c, rx, ry, rot), col, w)


func _dot(c: Vector2, r: float, col: Color, w: float = OLW) -> void:
	draw_circle(c, r, col.darkened(0.30))
	draw_circle(c + LIGHT * r * 0.16, r * 0.86, col)
	if w > 0.0:
		draw_arc(c, r, 0.0, TAU, 12, col.darkened(0.62), w * 0.7, false)


## A thick outlined limb: outline pass, then fill, with round joints.
func _limb(a: Vector2, b: Vector2, width: float, col: Color) -> void:
	draw_line(a, b, Pal.OUTLINE, width + 4.0, false)
	draw_circle(a, (width + 4.0) * 0.5, Pal.OUTLINE)
	draw_circle(b, (width + 4.0) * 0.5, Pal.OUTLINE)
	draw_line(a, b, col, width, false)
	draw_circle(a, width * 0.5, col)
	draw_circle(b, width * 0.5, col)


## An eye with a pupil. slit = a reptile's vertical pupil.
func _eye(c: Vector2, r: float, look: Vector2, white: Color, slit: bool = false) -> void:
	_dot(c, r, white, 1.4)
	if slit:
		_fill(_pts_oval(c + look, r * 0.34, r * 0.82), Pal.OUTLINE)
	else:
		draw_circle(c + look, r * 0.46, Pal.OUTLINE)
	draw_circle(c + look - Vector2(r * 0.3, r * 0.35), r * 0.2, Color(1, 1, 1, 0.9))


func add_circle_shape(radius: float, offset: Vector2 = Vector2.ZERO) -> void:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	cs.shape = c
	cs.position = offset
	add_child(cs)


func add_rect_shape(size: Vector2, offset: Vector2 = Vector2.ZERO) -> void:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = offset
	add_child(cs)
