## Level 1 critters: insect, lizard, falling stone, and the boar boss.
## Kept in one file so the whole bestiary for the stone age is in view.
class_name Bestiary
extends RefCounted


class Insect extends Critter:
	## Hovers at its own height and attacks in a STRAIGHT LINE from where it is.
	## It never climbs to sit on top of him: it winds up, commits to one direction,
	## and flies through. Committing is what makes it dodgeable and stompable.
	var anchor := Vector2.ZERO
	var t := 0.0
	var state := "hover"     ## hover -> wind -> dash -> rest
	var timer := 0.0
	var aim := Vector2.RIGHT
	var dash_speed := 440.0
	var vel := Vector2.ZERO  ## it carries momentum now, so nothing teleports
	var origin := Vector2.ZERO  ## where it was born. Its patch of the level, not its perch.
	const ROAM_X := 330.0    ## how far either side of home it may wander
	const ROAM_Y := 110.0    ## and how far above or below. Stops the long crawl home.
	var floor_y := 0.0       ## the one line it may not cross: the ground it lives above
	var ground_y := 0.0      ## set by the level. Without it the insect has to guess.

	func _setup() -> void:
		hp = 1
		damage = 1
		stomp_top = -14.0
		anchor = position
		origin = position
		# The level tells it which surface it belongs to. Deriving the floor from
		# the anchor was wrong wherever an insect sat higher or lower than usual,
		# which is why some hovered in the sky and others scraped the dirt.
		floor_y = (ground_y - 12.0) if ground_y > 0.0 else anchor.y + 40.0
		t = randf() * 10.0
		timer = randf() * 1.2
		add_circle_shape(12.0)

	## Adopts wherever the lunge left it as its new perch, kept inside its patch.
	func _settle() -> void:
		anchor = Vector2(
			clampf(global_position.x, origin.x - ROAM_X, origin.x + ROAM_X),
			clampf(global_position.y, origin.y - ROAM_Y, minf(origin.y + ROAM_Y, floor_y))
		)

	func _tick(delta: float) -> void:
		t += delta
		timer = maxf(timer - delta, 0.0)
		match state:
			"hover":
				vel = vel.move_toward(Vector2.ZERO, 500.0 * delta)
				var home := anchor + Vector2(sin(t * 1.3) * 60.0, sin(t * 2.7) * 12.0)
				if player != null:
					# drift sideways to line him up, never vertically
					var dx: float = player.global_position.x - global_position.x
					var dy: float = player.global_position.y - 30.0 - global_position.y
					home.x = clampf(
						global_position.x + clampf(dx, -70.0, 70.0),
						origin.x - ROAM_X, origin.x + ROAM_X
					)
					# Only commits when he is roughly level with it. Before this it
					# would wind up at a player standing far above, dash, fall short,
					# and then creep back up — which is what looked so wrong.
					if absf(dx) < 300.0 and absf(dy) < 120.0 and timer <= 0.0:
						state = "wind"
						timer = 0.45
				global_position = global_position.move_toward(home, 105.0 * delta)
			"wind":
				# hangs almost still for the beat before it commits
				vel = vel.move_toward(Vector2.ZERO, 900.0 * delta)
				global_position += vel * delta
				if timer <= 0.0:
					if player != null:
						aim = (player.global_position + Vector2(0, -26) - global_position).normalized()
						# never dive steeply: it strikes ACROSS him, not down at the floor
						aim.y = minf(aim.y, 0.35)
						if absf(aim.x) < 0.25:
							var side := signf(player.global_position.x - global_position.x)
							aim.x = 0.25 * (side if side != 0.0 else 1.0)
						aim = aim.normalized()
					vel = aim * dash_speed
					state = "dash"
					timer = 0.45
			"dash":
				# the lunge bleeds off speed instead of stopping dead
				vel = vel.move_toward(aim * dash_speed * 0.5, 430.0 * delta)
				global_position += vel * delta
				if timer <= 0.0:
					state = "rest"
					timer = 1.5
			"rest":
				# It STAYS where the lunge left it and settles there. Flying back
				# to the spawn point after every attack was the unnatural part:
				# a real insect does not reset, it drifts on from where it landed
				# and comes at you again from the new angle.
				vel = vel.move_toward(Vector2.ZERO, 380.0 * delta)
				global_position += vel * delta
				if timer <= 0.0:
					_settle()
					state = "hover"
					timer = 1.0

		# THE SNAP LIVED HERE. The sideways bound used to be applied to its
		# position, but only while hovering — so a lunge would carry it 200 px
		# past the edge unchecked, and the first hover frame yanked all of that
		# back in one step. A bound must never be enforced by moving something:
		# it is enforced by ENDING the lunge at the edge, and by capping where it
		# is allowed to aim. Then it stops at the line under its own power.
		global_position.y = clampf(global_position.y, origin.y - ROAM_Y, origin.y + ROAM_Y)
		if state == "dash" and absf(global_position.x - origin.x) > ROAM_X:
			state = "rest"
			timer = 1.2
		if global_position.y > floor_y:
			global_position.y = floor_y
			if state == "dash":
				state = "rest"      # it clips the dirt and pulls up
				timer = 1.1

	func _draw() -> void:
		# a fat prehistoric wasp: striped amber abdomen, blurred wings, one big eye
		var rate := 78.0 if state == "wind" else 42.0
		var flap := sin(t * rate)
		if state == "wind":
			draw_arc(Vector2.ZERO, 20.0 + sin(t * 30.0) * 3.0, 0.0, TAU, 18, Color(Pal.EMBER, 0.55), 2.0)
		# wings behind the body, squashed by the flap so they read as beating
		for sgn in [-1.0, 1.0]:
			_fill(_pts_oval(Vector2(-2, -9 + flap * 2.0), 10.0, 4.0 + absf(flap) * 3.0, sgn * 0.5),
				Color(Pal.WING, 0.72))
		# legs
		for i in 3:
			draw_line(Vector2(-4.0 + i * 5.0, 3), Vector2(-6.0 + i * 5.0, 9), Pal.OUTLINE, 1.6, true)
		# stinger
		_shape(PackedVector2Array([Vector2(-14, -2), Vector2(-22, 1), Vector2(-14, 3)]), Pal.WASP_DARK, 1.6)
		# abdomen with two dark bands
		_oval(Vector2(-7, 0), 10.0, 7.5, Pal.WASP, 2.2)
		for bx in [-10.0, -4.0]:
			_fill(_pts_oval(Vector2(bx, 0), 1.8, 7.0), Pal.WASP_DARK)
		# thorax and head
		_dot(Vector2(4, -1), 6.5, Pal.WASP_DARK, 2.2)
		_dot(Vector2(12, -2), 4.6, Pal.WASP_DARK, 2.2)
		_eye(Vector2(14, -3), 2.6, Vector2(0.6, 0), Pal.EYE_YELLOW)
		draw_line(Vector2(13, -6), Vector2(19, -11), Pal.OUTLINE, 1.5, true)
		if flash > 0.0:
			draw_circle(Vector2.ZERO, 15.0, Color(1, 1, 1, 0.5))
class Lizard extends Critter:
	var left_x := 0.0
	var right_x := 0.0
	var dir := 1
	var speed := 120.0
	var t := 0.0

	func _setup() -> void:
		# 6 health: the club and a thrown rock both do 3, so a reptile takes two
		# clean hits. A stomp still kills outright — that is the reward for the
		# harder move.
		hp = 6
		damage = 1
		# A flat 16 px box sat level with the floor, so he only ever touched it
		# at the instant he landed. Taller and wider gives a real landing target.
		stomp_top = -28.0
		add_rect_shape(Vector2(54, 28), Vector2(0, -14))

	## A point query just ahead, at body height. Patrol bounds alone were not
	## enough: anything solid standing inside a lizard's range was walked through.
	func _blocked(x: float) -> bool:
		var space := get_world_2d().direct_space_state
		if space == null:
			return false
		var q := PhysicsPointQueryParameters2D.new()
		q.position = Vector2(x, global_position.y - 14.0)
		q.collide_with_areas = false
		q.collide_with_bodies = true
		q.collision_mask = 1
		return space.intersect_point(q, 1).size() > 0

	func _tick(delta: float) -> void:
		t += delta
		if _blocked(position.x + dir * 30.0):
			dir = -dir
		position.x += dir * speed * delta
		if position.x > right_x:
			dir = -1
		elif position.x < left_x:
			dir = 1

	func _on_hit(from_dir: int) -> void:
		position.x += from_dir * 22.0

	func _draw() -> void:
		# a monitor lizard: olive back, pale belly, spined spine, slit eye
		var f := float(dir)
		var wig := sin(t * 14.0) * 4.0
		# tail, tapering away behind it
		_shape(PackedVector2Array([
			Vector2(-f * 16, -14), Vector2(-f * 30, -10 + wig * 0.5), Vector2(-f * 44, -5 + wig),
			Vector2(-f * 30, -5 + wig * 0.5), Vector2(-f * 16, -6)]), Pal.LIZ_DARK, 2.2)
		# far pair of legs, darker so they sit behind
		for i in [-1.0, 1.0]:
			_limb(Vector2(f * i * 13, -11), Vector2(f * i * 17 - wig, -1), 4.0, Pal.LIZ_DARK)
		# body and belly
		_shape(PackedVector2Array([
			Vector2(-f * 22, -13), Vector2(-f * 14, -20), Vector2(f * 6, -21),
			Vector2(f * 20, -17), Vector2(f * 23, -9), Vector2(f * 14, -3),
			Vector2(-f * 14, -3), Vector2(-f * 21, -7)]), Pal.LIZ)
		_fill(_pts_oval(Vector2(0, -6), 15.0, 3.5), Pal.LIZ_BELLY)
		for i in 3:
			_fill(_pts_oval(Vector2(-f * 10 + f * i * 10, -15), 3.6, 2.4), Pal.LIZ_DARK)
		# spines along the back
		for i in 5:
			var sx := -f * 16 + f * i * 8.0
			_fill(PackedVector2Array([Vector2(sx - f * 3, -19), Vector2(sx, -25), Vector2(sx + f * 3, -19)]), Pal.LIZ_DARK)
		# near pair of legs
		for i in [-1.0, 1.0]:
			_limb(Vector2(f * i * 11, -9), Vector2(f * i * 15 + wig, 0), 4.5, Pal.LIZ)
		# head
		_shape(PackedVector2Array([
			Vector2(f * 18, -20), Vector2(f * 31, -16), Vector2(f * 33, -10),
			Vector2(f * 20, -6), Vector2(f * 17, -12)]), Pal.LIZ, 2.2)
		draw_line(Vector2(f * 22, -11), Vector2(f * 32, -11), Pal.OUTLINE, 1.8, true)
		_eye(Vector2(f * 24, -15), 3.2, Vector2(f * 0.6, 0), Pal.EYE_YELLOW, true)
		# tongue, flicked now and then
		if fmod(t, 2.2) < 0.22:
			draw_line(Vector2(f * 32, -11), Vector2(f * 41, -13), Pal.MAW, 1.8, true)
		if flash > 0.0:
			draw_circle(Vector2(0, -10), 26.0, Color(1, 1, 1, 0.45))
class Stone extends Critter:
	var vy := 0.0
	var floor_y := 0.0
	var landed := false
	var rest := 2.5
	var spin := 0.0
	var r := 14.0

	func _setup() -> void:
		hp = 9999
		damage = 1
		stompable = false
		add_circle_shape(r)
		spin = randf_range(-3.0, 3.0)

	func take_hit(_dmg: int, _from_dir: int) -> void:
		pass

	func _tick(delta: float) -> void:
		if landed:
			rest -= delta
			modulate.a = clampf(rest / 0.6, 0.0, 1.0)
			if rest <= 0.0:
				queue_free()
			return
		vy += 1300.0 * delta
		position.y += vy * delta
		rotation += spin * delta
		if position.y >= floor_y:
			position.y = floor_y
			landed = true
			set_deferred("monitoring", false)

	func _draw() -> void:
		# a chunky faceted boulder: lit top, shaded underside
		var pts := PackedVector2Array([
			Vector2(-r, -r * 0.3), Vector2(-r * 0.5, -r), Vector2(r * 0.4, -r * 0.9),
			Vector2(r, -r * 0.2), Vector2(r * 0.7, r * 0.8), Vector2(-r * 0.4, r)])
		_shape(pts, Pal.ROCK, 2.5)
		_fill(PackedVector2Array([pts[0], pts[1], pts[2], Vector2(0, -r * 0.1)]), Pal.ROCK_LIGHT)
		_fill(PackedVector2Array([pts[3], pts[4], pts[5], Vector2(0, -r * 0.1)]), Pal.ROCK_DARK)
		draw_line(pts[1], Vector2(0, -r * 0.1), Pal.OUTLINE, 1.6, true)
		draw_line(pts[4], Vector2(0, -r * 0.1), Pal.OUTLINE, 1.6, true)
class Shockwave extends Critter:
	## A ridge of broken ground thrown out by Tuskar's slam. It runs along the
	## floor, so the answer is to JUMP — the one skill the whole level taught.
	var dir := 1
	var speed := 360.0
	var left_x := 0.0
	var right_x := 0.0
	var t := 0.0
	var life := 4.0

	func _setup() -> void:
		hp = 9999
		damage = 1
		stompable = false
		add_rect_shape(Vector2(44, 32), Vector2(0, -16))

	func take_hit(_dmg: int, _from_dir: int) -> void:
		pass   ## you cannot club the ground into submission

	func _tick(delta: float) -> void:
		t += delta
		life -= delta
		position.x += dir * speed * delta
		if life <= 0.0 or position.x < left_x - 40.0 or position.x > right_x + 40.0:
			queue_free()

	func _draw() -> void:
		# a ridge of broken ground: dust, tumbling rock, grit in the air
		var f := float(dir)
		_shape(PackedVector2Array([
			Vector2(-f * 26, 0), Vector2(-f * 8, -32), Vector2(f * 6, -20), Vector2(f * 26, 0)]), Pal.DUST, 2.5)
		for i in 4:
			var x := -16.0 + i * 11.0
			var h := 20.0 - absf(x) * 0.4 + sin(t * 26.0 + i) * 3.0
			_fill(PackedVector2Array([Vector2(x - 4, 0), Vector2(x, -h), Vector2(x + 4, 0)]), Pal.ROCK_DARK)
		for i in 5:
			var a := t * 7.0 + i * 1.3
			draw_circle(Vector2(cos(a) * 18.0, -26.0 - sin(a) * 8.0), 2.6, Color(Pal.DUST, 0.8))
class Boar extends Critter:
	signal defeated
	signal woke
	signal enraged_now

	## Down he takes double; upright he takes 1 whatever you hit him with.
	## That makes the fight about earning the window, and stops a couple of
	## thrown rocks from ending a boss that should take three knockdowns.
	func take_hit(dmg: int, from_dir: int) -> void:
		var scaled := dmg * 2 if (state == "down" or state == "pant") else maxi(1, dmg / 2)
		super.take_hit(scaled, from_dir)
		# Half health flips the fight: he stops running at you and starts
		# hammering the ground, so the threat moves from sideways to overhead.
		if not enraged and hp > 0 and hp <= max_hp / 2:
			enraged = true
			enraged_now.emit()
			charges = 0
			vx = 0.0
			state = "rear"
			stun = 0.7

	var arena_l := 0.0
	var arena_r := 0.0
	var state := "sleep"
	var dir := -1
	var vx := 0.0
	var stun := 0.0
	var t := 0.0
	var max_hp := 54
	var charges := 0          ## charges landed since he last went down
	var down_timer := 0.0     ## he lies there this long, then goes for the head
	var lunge_aim := 0.0
	var head_ready := false
	var enraged := false      ## below half health he abandons the charge entirely

	func _setup() -> void:
		hp = max_hp
		damage = 2
		# He can be ridden. Worth little while he is up — the club and the
		# knockdown are still the real damage — but landing on a charging boar
		# is a genuine option rather than a mistake.
		stompable = true
		stomp_top = -56.0     ## the line of his back
		stomp_damage = 4      ## becomes 2 upright, 8 while he is down
		stomp_push = 340.0    ## thrown clear of his flank, never straight back up
		add_rect_shape(Vector2(104, 56), Vector2(0, -28))

	## Two ground waves, one each way, plus rock shaken off the ceiling.
	## Jump the wave, then step out from under the falling stone.
	func _slam() -> void:
		var host := get_parent()
		if host == null:
			return
		for s in [-1, 1]:
			var w := Bestiary.Shockwave.new()
			w.position = position
			w.dir = s
			w.left_x = arena_l
			w.right_x = arena_r
			host.add_child(w)
		for i in 3:
			var st := Bestiary.Stone.new()
			st.position = Vector2(randf_range(arena_l + 90.0, arena_r - 90.0), 90.0)
			st.floor_y = position.y - 14.0
			host.add_child(st)


	func wake() -> void:
		if state == "sleep":
			state = "stalk"
			stun = 0.7
			woke.emit()

	## Fight loop: he charges from side to side. Two charges into the wall and he
	## goes DOWN — that is the window to hit him. Two seconds later he comes up
	## with a head strike aimed where the player stood, so the window has a price.
	func _tick(delta: float) -> void:
		t += delta
		# Winded means harmless. Standing on him to club him should not cost
		# health, or the reward window charges you for using it.
		damage = 0 if (state == "down" or state == "pant" or state == "sleep") else 2
		match state:
			"sleep":
				pass
			"stalk":
				stun -= delta
				# paces, sizing him up
				if player != null:
					dir = 1 if player.global_position.x > position.x else -1
				vx = move_toward(vx, dir * 90.0, 500.0 * delta)
				position.x = clampf(position.x + vx * delta, arena_l + 60.0, arena_r - 60.0)
				if stun <= 0.0:
					state = "charge"
					vx = 0.0
			"charge":
				vx = move_toward(vx, dir * 520.0, 1000.0 * delta)
				position.x += vx * delta
				var hit_wall := (dir > 0 and position.x >= arena_r - 60.0) or (dir < 0 and position.x <= arena_l + 60.0)
				if hit_wall:
					position.x = clampf(position.x, arena_l + 60.0, arena_r - 60.0)
					vx = 0.0
					if enraged:
						state = "rear"
						stun = 0.7
						return
					charges += 1
					if charges >= 2:
						# knocked down by his own momentum
						charges = 0
						state = "down"
						down_timer = 3.2
						head_ready = false
					else:
						# turn and come straight back the other way
						dir = -dir
						state = "stalk"
						stun = 0.45
			"down":
				down_timer -= delta
				if down_timer <= 1.4 and not head_ready:
					head_ready = true   # he starts to lift his head: the tell
				if down_timer <= 0.0 and player != null:
					lunge_aim = signf(player.global_position.x - position.x)
					if lunge_aim == 0.0:
						lunge_aim = float(dir)
					dir = int(lunge_aim)
					state = "head"
					stun = 0.7
			"head":
				# a short, fast head strike along the ground
				stun -= delta
				vx = move_toward(vx, lunge_aim * 680.0, 2200.0 * delta)
				position.x = clampf(position.x + vx * delta, arena_l + 60.0, arena_r - 60.0)
				if stun <= 0.0:
					vx = 0.0
					state = "stalk"
					stun = 0.8
			"rear":
				# up on his hind legs. Long, obvious, and the cue to move away
				stun -= delta
				vx = move_toward(vx, 0.0, 1600.0 * delta)
				position.x += vx * delta
				if stun <= 0.0:
					state = "slam"
					stun = 0.18
					_slam()
			"slam":
				stun -= delta
				if stun <= 0.0:
					state = "pant"
					stun = 1.2
			"pant":
				# winded from his own blow. Shorter than a knockdown, still double damage
				stun -= delta
				if stun <= 0.0:
					if player != null:
						dir = 1 if player.global_position.x > position.x else -1
					vx = 0.0
					state = "charge"

	func _on_hit(_from_dir: int) -> void:
		if state == "charge" or state == "head":
			vx *= 0.6

	## A boot on the spine takes some of the run out of him, so a well-timed
	## landing on a charge is rewarded even though the damage is small.
	func _on_stomped() -> void:
		if state == "charge" or state == "head":
			vx *= 0.7

	func _on_die() -> void:
		defeated.emit()

	func _draw() -> void:
		# Tuskar: heavy brown hide, pale belly, a black bristle ridge down the
		# spine, ivory tusks, and one small furious eye. Every state pose below
		# is the same animal, only shifted by bob.
		var f := float(dir)
		var running := state == "charge" or state == "head"
		var bob := sin(t * 18.0) * 3.0 if running else 0.0
		if state == "sleep":
			bob = sin(t * 2.0) * 2.0
		if state == "down":
			bob = 16.0 if not head_ready else 16.0 - sin(t * 9.0) * 7.0
		if state == "head":
			bob = -6.0
		if state == "rear":
			bob = -30.0 * (1.0 - stun / 0.7)
		if state == "slam":
			bob = 12.0
		if state == "pant":
			bob = 9.0 + sin(t * 11.0) * 2.5

		# legs, with hooves
		for i in 4:
			var lx := -34.0 + i * 22.0
			var sw := sin(t * 18.0 + i * 1.5) * 9.0 if running else 0.0
			var foot := Vector2(lx + sw, 0)
			_limb(Vector2(lx, -26 + bob * 0.6), foot, 9.0, Pal.BOAR_DARK)
			_fill(_pts_oval(foot + Vector2(f * 2, -2), 6.5, 4.5), Pal.HOOF)

		var body := Vector2(0, -36 + bob)
		# tail
		draw_line(body + Vector2(-f * 48, -4), body + Vector2(-f * 62, -16 + sin(t * 6.0) * 5.0), Pal.BOAR_DARK, 4.5, true)
		# barrel and belly
		_oval(body, 52.0, 30.0, Pal.BOAR_HIDE, 3.0)
		_fill(_pts_oval(body + Vector2(0, 11), 40.0, 16.0), Pal.BOAR_BELLY)
		# bristles down the spine
		for i in 7:
			var bx := -34.0 + i * 11.0
			var lift := 13.0 + sin(float(i) * 1.7) * 4.0 + (6.0 if enraged else 0.0)
			_fill(PackedVector2Array([
				body + Vector2(bx - 3, -26), body + Vector2(bx + f * 2, -26 - lift), body + Vector2(bx + 4, -26)]), Pal.BRISTLE)
		# head: a heavy wedge running into the snout
		var head := body + Vector2(f * 44, 4)
		_shape(PackedVector2Array([
			head + Vector2(-f * 8, -30), head + Vector2(f * 18, -26), head + Vector2(f * 30, -12),
			head + Vector2(f * 26, 4), head + Vector2(f * 6, 12), head + Vector2(-f * 10, 4)]), Pal.BOAR_HIDE, 3.0)
		# ear
		_shape(PackedVector2Array([
			head + Vector2(-f * 6, -28), head + Vector2(-f * 14, -44), head + Vector2(f * 6, -32)]), Pal.BOAR_DARK, 2.2)
		# snout disc and nostrils
		_dot(head + Vector2(f * 28, -6), 9.0, Pal.BOAR_DARK, 2.5)
		draw_circle(head + Vector2(f * 30, -9), 1.8, Pal.OUTLINE)
		draw_circle(head + Vector2(f * 30, -2), 1.8, Pal.OUTLINE)
		# tusks, curving up out of the jaw
		for sc in [1.0, 0.7]:
			_shape(PackedVector2Array([
				head + Vector2(f * 22, 4 * sc), head + Vector2(f * 34, -6 * sc),
				head + Vector2(f * 40, -22 * sc), head + Vector2(f * 33, -10 * sc),
				head + Vector2(f * 22, 0)]), Pal.TUSK, 2.0)
		# eye, and a heavy brow that drops as he wakes up
		if state == "sleep":
			draw_line(head + Vector2(f * 2, -14), head + Vector2(f * 14, -14), Pal.OUTLINE, 2.5, true)
		else:
			_eye(head + Vector2(f * 9, -15), 4.2, Vector2(f * 1.0, 0), Pal.EMBER if running else Pal.EYE_YELLOW)
			draw_line(head + Vector2(f * 1, -22), head + Vector2(f * 17, -17), Pal.BRISTLE, 4.0, true)

		if state == "down":
			for i in 3:
				var a := t * 6.0 + i * 2.1
				draw_circle(Vector2(f * 48 + cos(a) * 22.0, -52 + sin(a) * 6.0), 3.0, Pal.BONE)
			if head_ready:
				draw_arc(Vector2(f * 52, -32 + bob), 26.0 + sin(t * 12.0) * 4.0, 0.0, TAU, 20, Color(Pal.EMBER, 0.6), 3.0)
		if state == "head":
			draw_line(Vector2(f * 66, -26), Vector2(f * 104, -26), Color(Pal.EMBER, 0.7), 5.0)
		if state == "rear":
			var lift2 := 1.0 - stun / 0.7
			draw_arc(Vector2(0, 4), 40.0 + lift2 * 30.0, 0.0, TAU, 24, Color(Pal.EMBER, 0.25 + lift2 * 0.4), 4.0)
		if state == "pant":
			for i in 3:
				var a3 := t * 5.0 + i * 2.1
				draw_circle(Vector2(f * 50 + cos(a3) * 18.0, -34 + sin(a3) * 5.0), 2.6, Color(Pal.BONE, 0.7))
		if enraged:
			for i in 4:
				var b := fmod(t * 1.6 + i * 0.25, 1.0)
				draw_circle(Vector2(f * (74.0 + b * 30.0), -34.0 - b * 16.0), 4.0 * (1.0 - b), Color(Pal.EMBER, 0.5 * (1.0 - b)))
		if flash > 0.0:
			_fill(_pts_oval(body, 56.0, 34.0), Color(1, 1, 1, 0.4))

class Flytrap extends Critter:
	## A rooted snapping plant. It opens on a cycle and bites what is near it.
	## Deliberately NOT stompable: it snaps upward, so landing on it is a mistake.
	var t := 0.0
	var open := false
	var open_amt := 0.0    ## 0 shut, 1 gaping. Eased, not switched.
	var cycle := 2.2
	var phase := 0.0

	func _setup() -> void:
		hp = 3
		damage = 0
		stompable = false
		phase = randf() * cycle
		add_rect_shape(Vector2(40, 46), Vector2(0, -30))

	func _tick(delta: float) -> void:
		t += delta
		open = fmod(t + phase, cycle) < cycle * 0.45
		# a real trap takes a moment to gape and shuts in a blink
		open_amt = move_toward(open_amt, 1.0 if open else 0.0, (7.0 if open else 24.0) * delta)
		# harmless while shut, so the open window is the telegraph
		damage = 1 if open else 0

	func _draw() -> void:
		# A Venus flytrap. The giveaway is the rim: long spines along the margin
		# of each lobe that interlock when it shuts, over a red inner surface.
		# Mirrored so it faces left, toward the player walking in from that side.
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
		var sway := sin(t * 1.7) * 3.0
		var head := Vector2(sway * 0.5 - 4.0, -40)

		# rosette of flat paddle leaves at the base
		for i in 4:
			var a := -2.75 + i * 0.5
			var tip := Vector2(cos(a), sin(a) * 0.55) * 22.0
			_shape(_pts_oval(tip * 0.55, 12.0, 5.0, a * 0.35), Pal.TRAP_GREEN, 2.0)
			draw_line(Vector2.ZERO, tip * 0.95, Pal.TRAP_DARK, 1.6, true)

		# stalk, bending with the sway
		var stalk := PackedVector2Array()
		for i in 9:
			var u := i / 8.0
			stalk.append(Vector2(0, 0).lerp(Vector2(sway * 0.4, -22), u).lerp(Vector2(sway * 0.4, -22).lerp(head, u), u))
		draw_polyline(stalk, Pal.OUTLINE, 10.0, true)
		draw_polyline(stalk, Pal.TRAP_DARK, 6.5, true)

		# the throat, seen between the lobes
		_fill(_pts_oval(head + Vector2(9, 0), 12.0, 3.0 + open_amt * 11.0), Pal.MAW)
		_jaw(head, -1.0)
		_jaw(head, 1.0)
		if flash > 0.0:
			draw_circle(head + Vector2(8, 0), 26.0, Color(1, 1, 1, 0.45))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## One lobe, hinged at the back and swinging open. sgn -1 is the upper lobe.
	func _jaw(hinge: Vector2, sgn: float) -> void:
		var ang := sgn * (0.06 + open_amt * 0.62)
		var rx := 24.0
		var ry := 10.5
		var pts := PackedVector2Array()
		for i in 9:
			var a := PI - PI * i / 8.0
			pts.append(hinge + Vector2(rx * 0.5 + cos(a) * rx * 0.5, sgn * sin(a) * ry).rotated(ang))
		_shape(pts, Pal.TRAP_GREEN, 2.2)
		# red inner face along the margin, and the trigger hairs on it
		var inner := PackedVector2Array()
		for i in 6:
			var u := i / 5.0
			inner.append(hinge + Vector2(4.0 + u * (rx - 7.0), sgn * (1.0 + sin(u * PI) * 3.4)).rotated(ang))
		for i in range(5, -1, -1):
			var u2 := i / 5.0
			inner.append(hinge + Vector2(4.0 + u2 * (rx - 7.0), sgn * 0.5).rotated(ang))
		_fill(inner, Pal.MAW)
		for i in 3:
			var hx := 9.0 + i * 5.0
			draw_line(hinge + Vector2(hx, sgn * 2.0).rotated(ang),
				hinge + Vector2(hx, sgn * 5.5).rotated(ang), Pal.OUTLINE, 1.2, true)
		# The spines grow off the margin and reach ACROSS the gap, so the two
		# rows mesh when it shuts. Pointing them the other way (into their own
		# lobe) is what made them burst out through the back of the head.
		for i in 6:
			var bx := 7.0 + i * (rx - 11.0) / 5.0
			var reach := 5.0 + sin(float(i) / 5.0 * PI) * 4.5   # longest mid-row
			draw_line(hinge + Vector2(bx, sgn * 1.0).rotated(ang),
				hinge + Vector2(bx + 1.5, -sgn * reach).rotated(ang), Pal.TOOTH, 2.2, false)
		# midrib along the lobe
		draw_line(hinge + Vector2(3, sgn * 4.0).rotated(ang),
			hinge + Vector2(rx - 3.0, sgn * 3.0).rotated(ang), Pal.TRAP_DARK, 1.8, true)

class Runner extends Critter:
	## One beast in the stampede. Stompable like any small thing, but they come
	## packed, so crushing one only drops you into the next. High ground is the answer.
	var speed := 430.0
	var dir := -1
	var despawn_x := -500.0
	var t := 0.0

	func _setup() -> void:
		hp = 1
		damage = 1
		stomp_top = -34.0
		t = randf() * 4.0
		add_rect_shape(Vector2(44, 36), Vector2(0, -18))

	func _tick(delta: float) -> void:
		t += delta
		position.x += dir * speed * delta
		if dir < 0 and position.x < despawn_x:
			queue_free()
		elif dir > 0 and position.x > despawn_x:
			queue_free()

	func _draw() -> void:
		# a shaggy little boar, one of the herd
		var f := float(dir)
		var run := sin(t * 22.0)
		for i in 4:
			var lx := -12.0 + i * 9.0
			var sw := sin(t * 22.0 + i * 1.6) * 7.0
			_limb(Vector2(lx, -16), Vector2(lx + sw, -1), 4.5, Pal.RUNNER_DARK)
			_fill(_pts_oval(Vector2(lx + sw, -1), 3.4, 2.4), Pal.HOOF)
		draw_line(Vector2(-f * 20, -20), Vector2(-f * 27, -26 + run * 3.0), Pal.RUNNER_DARK, 3.0, true)
		_oval(Vector2(0, -19), 22.0, 12.0, Pal.RUNNER_HIDE)
		_fill(_pts_oval(Vector2(0, -13), 16.0, 5.0), Pal.BOAR_BELLY)
		for i in 5:
			var bx := -14.0 + i * 7.0
			_fill(PackedVector2Array([Vector2(bx - 2, -29), Vector2(bx + 1, -37), Vector2(bx + 3, -29)]), Pal.BRISTLE)
		# head and snout
		_shape(PackedVector2Array([
			Vector2(f * 12, -29), Vector2(f * 26, -26), Vector2(f * 33, -18),
			Vector2(f * 26, -11), Vector2(f * 12, -12)]), Pal.RUNNER_HIDE, 2.2)
		_dot(Vector2(f * 32, -18), 3.6, Pal.RUNNER_DARK, 2.0)
		_fill(PackedVector2Array([Vector2(f * 14, -28), Vector2(f * 12, -36), Vector2(f * 20, -30)]), Pal.RUNNER_DARK)
		_shape(PackedVector2Array([Vector2(f * 27, -14), Vector2(f * 34, -22), Vector2(f * 30, -12)]), Pal.TUSK, 1.6)
		_eye(Vector2(f * 22, -23), 2.8, Vector2(f * 0.6, 0), Pal.EMBER)
		if flash > 0.0:
			draw_circle(Vector2(0, -18), 26.0, Color(1, 1, 1, 0.45))