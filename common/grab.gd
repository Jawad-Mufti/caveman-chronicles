extends RefCounted
## GRAB & THROW. A critter he has just hit is DAZED for a moment (stars round
## its head); THROW next to it and he hoists it overhead, upside down; THROW
## or HIT again and he hurls it, spinning, into whatever is ahead: it bowls
## over the critters and breakables it hits, and is out itself when it lands.
## The player drives it (CaveMan.carrying, _try_grab, _hurl), so it works the
## same on every critter, whatever its own _physics_process does.
## (Loaded with preload, not class_name: CaveMan.Grab.)

const DAZE_TIME := 1.8
const REACH := 130.0           ## how far in front he can grab (px): a hit knocks it ~100 px back
const THROW_V := Vector2(760.0, 60.0)   ## a short flat heave: it lands just ahead and rolls
const HIT_DAMAGE := 4          ## to what it bowls over
const LIFT_TIME := 0.18


## Small, beatable things only: no bosses, nothing rooted or running off with loot.
static func can_grab(c: Critter) -> bool:
	if c == null or c.dying > 0.0 or not c.is_physics_processing() or c.hp > 8:
		return false
	if c is Bestiary.Flytrap or c is Bestiary.Stone or c is Bestiary.Shockwave or c is Bestiary.Boar \
			or c is Treasure.GoldenHare:
		return false
	return is_dazed(c) or c.hp <= 1


static func daze(c: Critter) -> void:
	if c.dying > 0.0:
		return
	for ch in c.get_children():
		if ch is Stars:
			ch.t = DAZE_TIME
			return
	var s := Stars.new()
	s.lift = maxf(c._body_height() / 0.9, 22.0) + 12.0
	c.add_child(s)


static func is_dazed(c: Critter) -> bool:
	for ch in c.get_children():
		if ch is Stars:
			return ch.t > 0.0
	return false


static func undaze(c: Critter) -> void:
	for ch in c.get_children():
		if ch is Stars:
			ch.queue_free()


## Three little stars circling over a dazed critter's head.
class Stars extends Node2D:
	var t := DAZE_TIME
	var lift := 34.0

	func _process(delta: float) -> void:
		t -= delta
		var p := get_parent() as Critter
		if t <= 0.0 or p == null or p.dying > 0.0:
			queue_free()
			return
		position = Vector2(0, -lift)
		rotation = -p.rotation
		queue_redraw()

	func _draw() -> void:
		var a0 := Time.get_ticks_msec() * 0.008
		var fade := clampf(t / 0.3, 0.0, 1.0)
		var sc: Vector2 = (get_parent() as Node2D).scale
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(signf(sc.x), signf(sc.y)))
		for k in 3:
			var a := a0 + k * TAU / 3.0
			var c := Vector2(cos(a) * 16.0, sin(a) * 5.0)
			var r := 5.5 + 1.5 * sin(a)
			var pts := PackedVector2Array()
			for i in 8:
				var rr := r if i % 2 == 0 else r * 0.4
				pts.append(c + Vector2.from_angle(i * TAU / 8.0 - PI * 0.5) * rr)
			draw_colored_polygon(pts, Color(1.0, 0.86, 0.3, fade))


## A critter thrown like a bowling ball: it slams down in front of him, then
## tumbles along the ground at speed, bowling over every critter and
## breakable in its lane (they are dazed too: grab the next one), until a
## wall or a stop. Then it's out. It drops off ledges and carries on below.
class Flight extends Node2D:
	var critter: Critter
	var vel := Vector2.ZERO
	var dir := 1
	var thrower: CaveMan
	var rolling := false
	var life := 2.4
	var _c := Vector2.ZERO        ## where the middle of its body is
	var _r := 16.0                ## its half height: how far the middle rides above the ground
	var _hit := {}
	var _strikes := 0

	func _ready() -> void:
		var h := maxf(critter._body_height() / 0.9, 22.0)
		_r = maxf(h * 0.5, 12.0)
		_c = critter.global_position + critter.transform.basis_xform(Vector2(0, -h * 0.5))

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(critter) or critter.dying > 0.0:
			queue_free()
			return
		life -= delta
		var space := critter.get_world_2d().direct_space_state
		var from := _c
		if not rolling:
			vel.y += 1800.0 * delta
			var to := _c + vel * delta
			var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(from, to + Vector2(0, _r), 1))
			if not hit.is_empty():
				var n: Vector2 = hit["normal"]
				if n.y < -0.6:
					# down on the ground: THUD, and off it rolls
					_c = Vector2(to.x, (hit["position"] as Vector2).y - _r)
					rolling = true
					vel.y = 0.0
					_shake(3.0)
				else:
					_out()
					return
			else:
				_c = to
		else:
			vel.x = move_toward(vel.x, 0.0, 380.0 * delta)
			var nx := _c.x + vel.x * delta
			# a wall ahead stops it dead
			var wall := space.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(_c.x, _c.y - 4), Vector2(nx + dir * _r, _c.y - 4), 1))
			if not wall.is_empty():
				_out()
				return
			# follow the ground; off a ledge, it falls
			var g := space.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(nx, _c.y - _r), Vector2(nx, _c.y + _r + 24.0), 1))
			if g.is_empty():
				rolling = false
				_c.x = nx
			else:
				_c = Vector2(nx, (g["position"] as Vector2).y - _r)
		critter.rotation += vel.x / maxf(_r, 10.0) * delta * 0.6
		critter.global_position = _c - critter.transform.basis_xform(Vector2(0, -_r))
		critter.queue_redraw()
		_bowl(space)
		if life <= 0.0 or (rolling and absf(vel.x) < 110.0):
			_out()

	## Everything it meets in its lane: knocked flying (and dazed).
	func _bowl(space: PhysicsDirectSpaceState2D) -> void:
		var q := PhysicsShapeQueryParameters2D.new()
		var shape := CircleShape2D.new()
		shape.radius = _r + 16.0
		q.shape = shape
		q.transform = Transform2D(0.0, _c)
		q.collide_with_areas = true
		q.collide_with_bodies = false
		q.collision_mask = 4
		for r in space.intersect_shape(q, 8):
			var o: Object = r["collider"]
			if o == critter or not o.has_method("take_hit") or _hit.has(o.get_instance_id()):
				continue
			if o is Critter and (o as Critter).dying > 0.0:
				continue
			_hit[o.get_instance_id()] = true
			o.take_hit(HIT_DAMAGE, dir)
			if o is Critter:
				_strikes += 1
				var cr := o as Critter
				if cr.dying <= 0.0:
					var st: Stars = null
					for ch in cr.get_children():
						if ch is Stars:
							st = ch
					if st == null:
						st = Stars.new()
						st.lift = maxf(cr._body_height() / 0.9, 22.0) + 12.0
						cr.add_child(st)
					st.t = DAZE_TIME
				if thrower != null:
					thrower.add_sun(Sunfire.GAIN_HIT)
					thrower.combo_hit()
				_word("STRIKE!" if _strikes == 1 else "STRIKE x%d!" % _strikes, Color("ffe066"), (o as Node2D).global_position)
				Critter.slow_time(get_tree(), 0.08, 0.1)
			vel.x *= 0.85

	## The end of the ride: it's out cold.
	func _out() -> void:
		critter.rotation = 0.0
		critter.scale.y = absf(critter.scale.y)
		critter.global_position = Vector2(_c.x, _c.y + _r)
		critter.set_physics_process(true)
		critter.take_hit(99, dir)
		_shake(2.0)
		queue_free()

	func _shake(amt: float) -> void:
		var lv := get_parent()
		if lv != null and lv.has_method("shake"):
			lv.shake(amt, 0.12)

	func _word(text: String, col: Color, at: Vector2) -> void:
		var w := CaveMan.WordPop.new()
		w.text = text
		w.size = 24
		w.color = col
		w.star = Color("e8823a", 0.85)
		w.centered = true
		w.tilt = randf_range(-0.2, 0.2)
		w.life = 0.7
		w.position = at + Vector2(0, -60)
		get_parent().add_child(w)
