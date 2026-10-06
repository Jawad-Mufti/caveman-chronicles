extends Node2D
## SPIRIT ORBS, like God of War's: every beast he beats lets go of a burst of
## little blue-white orbs that hang for a beat, then stream into Ugu by
## themselves. Kept in the save (GameState.orbs), shown on the HUD, to be
## spent on upgrades. A new currency, apart from shells: beasts come back every
## visit, so these can be earned again and again without touching shop prices.
## One node per burst, all of its orbs drawn in one go. Loaded with preload
## (Critter.ORBS), no class_name.

const RIM := Color("5fb8ff")
const BODY := Color("cfeeff")
const DRAG := 0.03               ## how much of its burst speed an orb keeps after a second

var count := 5
var target: CaveMan
var origin := Vector2.INF        ## where the burst starts (world); else where the node is
var _orbs: Array = []            ## [pos (global), vel, delay before it homes in, alive]
var _t := 0.0


## How many a beast is worth: small things 3, a wolf ~8, a boss 30.
static func worth(hp0: int) -> int:
	return clampi(3 + int(hp0 * 0.8), 3, 30)


func _ready() -> void:
	z_index = 6
	add_to_group("glow")
	var from := origin if origin.x < INF else global_position
	top_level = true
	position = Vector2.ZERO        # orbs keep their own (world) positions
	for i in count:
		var a := randf_range(PI * 1.05, PI * 1.95)          # mostly up and out
		var v := Vector2.from_angle(a) * randf_range(180.0, 420.0)
		_orbs.append([from + Vector2(randf_range(-10, 10), randf_range(-14, 4)), v, 0.32 + i * 0.035, true])


func _process(delta: float) -> void:
	_t += delta
	var alive := 0
	var him_ok := is_instance_valid(target) and not target.dead
	for o in _orbs:
		if not o[3]:
			continue
		alive += 1
		var pos: Vector2 = o[0]
		var vel: Vector2 = o[1]
		var delay: float = o[2]
		if _t < delay or not him_ok:
			# the puff: thrown out, slowing, drifting up a little
			vel *= pow(DRAG, delta)
			vel.y -= 40.0 * delta
		else:
			# then in to him, faster and faster
			var to := target.global_position + Vector2(0, -40)
			var d := to - pos
			var sp := 520.0 + 1700.0 * (_t - delay)
			vel = vel.lerp(d.normalized() * sp, minf(1.0, delta * 9.0))
			if d.length() < 24.0 + sp * delta:
				o[3] = false
				GameState.orbs += 1
				continue
		o[0] = pos + vel * delta
		o[1] = vel
	if alive == 0 or (_t > 4.0 and not him_ok):
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var b := Batch.new()
	for o in _orbs:
		if not o[3]:
			continue
		var p: Vector2 = o[0]
		var v: Vector2 = o[1]
		var tw := 0.8 + 0.2 * sin(_t * 18.0 + p.x)
		# a streak behind it when it's moving fast
		if v.length() > 300.0:
			b.line(p - v * 0.045, p, Color(BODY, 0.5), 6.0)
		b.circle(p, 11.0 * tw, Color(RIM, 0.32), 12)
		b.circle(p, 6.2, BODY, 12)
		b.circle(p + Vector2(-1.6, -1.6), 2.6, Color.WHITE, 8)
	b.draw(self)


## They shine through the dark.
func draw_glow(g) -> void:   # g: the glow layer's Batch
	for o in _orbs:
		if o[3]:
			g.draw_circle(o[0], 22.0, Color(RIM, 0.32))
