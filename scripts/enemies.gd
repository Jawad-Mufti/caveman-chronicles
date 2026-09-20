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
	const ROAM_X := 250.0    ## how far either side of home it may wander
	const ROAM_Y := 110.0    ## and how far above or below. Stops the long crawl home.
	var floor_y := 0.0       ## the one line it may not cross: the ground it lives above
	var ground_y := 0.0      ## set by the level. Without it the insect has to guess.

	func _setup() -> void:
		hp = 1
		damage = 1
		stomp_top = -14.0
		anchor = position
		# The level tells it which surface it belongs to. Deriving the floor from
		# the anchor was wrong wherever an insect sat higher or lower than usual,
		# which is why some hovered in the sky and others scraped the dirt.
		floor_y = (ground_y - 12.0) if ground_y > 0.0 else anchor.y + 40.0
		t = randf() * 10.0
		timer = randf() * 1.2
		add_circle_shape(12.0)

	func _tick(delta: float) -> void:
		t += delta
		timer = maxf(timer - delta, 0.0)
		match state:
			"hover":
				var home := anchor + Vector2(sin(t * 1.3) * 60.0, sin(t * 2.7) * 12.0)
				if player != null:
					# drift sideways to line him up, never vertically
					var dx: float = player.global_position.x - global_position.x
					var dy: float = player.global_position.y - 30.0 - global_position.y
					home.x = global_position.x + clampf(dx, -70.0, 70.0)
					# Only commits when he is roughly level with it. Before this it
					# would wind up at a player standing far above, dash, fall short,
					# and then creep back up — which is what looked so wrong.
					if absf(dx) < 300.0 and absf(dy) < 120.0 and timer <= 0.0:
						state = "wind"
						timer = 0.45
				global_position = global_position.move_toward(home, 165.0 * delta)
			"wind":
				if timer <= 0.0:
					if player != null:
						aim = (player.global_position + Vector2(0, -26) - global_position).normalized()
						# never dive steeply: it strikes ACROSS him, not down at the floor
						aim.y = minf(aim.y, 0.35)
						if absf(aim.x) < 0.25:
							var side := signf(player.global_position.x - global_position.x)
							aim.x = 0.25 * (side if side != 0.0 else 1.0)
						aim = aim.normalized()
					state = "dash"
					timer = 0.5
			"dash":
				global_position += aim * dash_speed * delta
				if timer <= 0.0:
					state = "rest"
					timer = 1.3
			"rest":
				# snaps back to station rather than trickling there
				global_position = global_position.move_toward(anchor, 260.0 * delta)
				if timer <= 0.0:
					state = "hover"
					timer = 0.8

		# It keeps a station and stays near it. Without this a dash could leave it
		# far below its post, crawling back up for seconds on end.
		global_position.y = clampf(global_position.y, anchor.y - ROAM_Y, anchor.y + ROAM_Y)
		if state != "dash":
			global_position.x = clampf(global_position.x, anchor.x - ROAM_X, anchor.x + ROAM_X)
		if global_position.y > floor_y:
			global_position.y = floor_y
			if state == "dash":
				state = "rest"      # it clips the dirt and pulls up
				timer = 1.1

	func _draw() -> void:
		var c := Pal.CHARCOAL
		var rate := 78.0 if state == "wind" else 42.0
		var w := sin(t * rate) * 6.0
		if state == "wind":
			# a clear tell before it commits
			draw_arc(Vector2.ZERO, 20.0 + sin(t * 30.0) * 3.0, 0.0, TAU, 18, Color(Pal.EMBER, 0.55), 2.0)
		draw_line(Vector2(0, -2), Vector2(-11, -9 - w), Pal.STONE, 2.0)
		draw_line(Vector2(0, -2), Vector2(11, -9 + w), Pal.STONE, 2.0)
		draw_circle(Vector2.ZERO, 7.0, c)
		draw_circle(Vector2(-7, 2), 5.0, c)
		draw_circle(Vector2(6, -1), 4.0, c)
		draw_circle(Vector2(8, -3), 1.2, Pal.EMBER)
		if flash > 0.0:
			draw_circle(Vector2.ZERO, 14.0, Color(1, 1, 1, 0.5))


class Lizard extends Critter:
	var left_x := 0.0
	var right_x := 0.0
	var dir := 1
	var speed := 120.0
	var t := 0.0

	func _setup() -> void:
		hp = 2
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
		var f := float(dir)
		var c := Pal.CHARCOAL
		var wig := sin(t * 14.0) * 4.0
		# tail
		draw_line(Vector2(-f * 20, -8), Vector2(-f * 40, -6 + wig), c, 4.0)
		# legs
		draw_line(Vector2(-f * 10, -8), Vector2(-f * 14 + wig, 0), c, 3.0)
		draw_line(Vector2(f * 10, -8), Vector2(f * 14 - wig, 0), c, 3.0)
		# body
		draw_polygon(PackedVector2Array([Vector2(-f * 22, -16), Vector2(f * 18, -19), Vector2(f * 23, -8), Vector2(f * 16, -2), Vector2(-f * 20, -3)]), PackedColorArray([c]))
		# a low ridge along the spine, so the top edge reads clearly
		draw_line(Vector2(-f * 16, -19), Vector2(f * 14, -22), Pal.STONE, 3.0)
		# head
		draw_circle(Vector2(f * 27, -13), 7.0, c)
		draw_circle(Vector2(f * 29, -15), 1.4, Pal.OCHRE)
		if flash > 0.0:
			draw_circle(Vector2(0, -8), 26.0, Color(1, 1, 1, 0.45))


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
		var pts := PackedVector2Array([
			Vector2(-r, -r * 0.3), Vector2(-r * 0.5, -r), Vector2(r * 0.4, -r * 0.9),
			Vector2(r, -r * 0.2), Vector2(r * 0.7, r * 0.8), Vector2(-r * 0.4, r)
		])
		draw_polygon(pts, PackedColorArray([Pal.STONE]))
		draw_polygon(PackedVector2Array([pts[0], pts[1], Vector2(0, 0)]), PackedColorArray([Pal.STONE_DARK]))


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
		var f := float(dir)
		draw_polygon(PackedVector2Array([
			Vector2(-f * 24, 0), Vector2(-f * 6, -30), Vector2(f * 10, -22), Vector2(f * 24, 0),
		]), PackedColorArray([Pal.STONE_DARK]))
		for i in 4:
			var x := -18.0 + i * 12.0
			var h := 22.0 - absf(x) * 0.4 + sin(t * 26.0 + i) * 3.0
			draw_line(Vector2(x, 0), Vector2(x, -h), Pal.STONE, 4.0)
		for i in 5:
			var a := t * 7.0 + i * 1.3
			draw_circle(Vector2(cos(a) * 18.0, -24.0 - sin(a) * 7.0), 2.4, Color(Pal.BONE, 0.7))


class Boar extends Critter:
	signal defeated
	signal woke
	signal enraged_now

	## Down he takes double; upright he takes 1 whatever you hit him with.
	## That makes the fight about earning the window, and stops a couple of
	## thrown rocks from ending a boss that should take three knockdowns.
	func take_hit(dmg: int, from_dir: int) -> void:
		var scaled := dmg * 2 if (state == "down" or state == "pant") else 1
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
		stompable = false
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

	func _on_die() -> void:
		defeated.emit()

	func _draw() -> void:
		var f := float(dir)
		var c := Pal.CHARCOAL
		var running := state == "charge" or state == "head"
		var bob := sin(t * 18.0) * 3.0 if running else 0.0
		if state == "sleep":
			bob = sin(t * 2.0) * 2.0
		if state == "down":
			# slumped, and the head lifts as the strike gets close
			bob = 16.0 if not head_ready else 16.0 - sin(t * 9.0) * 7.0
		if state == "head":
			bob = -6.0
		if state == "rear":
			bob = -30.0 * (1.0 - stun / 0.7)
		if state == "slam":
			bob = 12.0
		if state == "pant":
			bob = 9.0 + sin(t * 11.0) * 2.5

		for i in 4:
			var lx := -34.0 + i * 22.0
			var sw := sin(t * 18.0 + i * 1.5) * 9.0 if running else 0.0
			draw_line(Vector2(lx, -22), Vector2(lx + sw, 0), c, 8.0)

		draw_set_transform(Vector2(0, -36 + bob), 0.0, Vector2(1.75, 1.0))
		draw_circle(Vector2.ZERO, 30.0, c)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		draw_circle(Vector2(f * 48, -32 + bob), 19.0, c)
		draw_circle(Vector2(f * 64, -25 + bob), 8.0, Pal.OCHRE_DARK)
		draw_line(Vector2(f * 58, -20 + bob), Vector2(f * 72, -36 + bob), Pal.BONE, 4.0)
		var eye := Pal.EMBER if running else Pal.OCHRE
		if state == "sleep":
			draw_line(Vector2(f * 46, -38 + bob), Vector2(f * 54, -38 + bob), Pal.OCHRE, 2.0)
		else:
			draw_circle(Vector2(f * 50, -38 + bob), 2.6, eye)
		draw_polygon(PackedVector2Array([
			Vector2(-22, -62 + bob), Vector2(-12, -76 + bob), Vector2(0, -62 + bob),
			Vector2(12, -74 + bob), Vector2(24, -62 + bob)
		]), PackedColorArray([c]))

		if state == "down":
			for i in 3:
				var a := t * 6.0 + i * 2.1
				draw_circle(Vector2(f * 48 + cos(a) * 22.0, -52 + sin(a) * 6.0), 3.0, Pal.BONE)
			if head_ready:
				draw_arc(Vector2(f * 52, -32 + bob), 26.0 + sin(t * 12.0) * 4.0, 0.0, TAU, 20, Color(Pal.EMBER, 0.6), 3.0)
		if state == "head":
			draw_line(Vector2(f * 66, -26), Vector2(f * 104, -26), Color(Pal.EMBER, 0.7), 5.0)
		if state == "rear":
			# the wind-up: he rises and his shadow gathers under him
			var lift := 1.0 - stun / 0.7
			draw_arc(Vector2(0, 4), 40.0 + lift * 30.0, 0.0, TAU, 24, Color(Pal.EMBER, 0.25 + lift * 0.4), 4.0)
		if state == "pant":
			for i in 3:
				var a3 := t * 5.0 + i * 2.1
				draw_circle(Vector2(f * 50 + cos(a3) * 18.0, -34 + sin(a3) * 5.0), 2.6, Color(Pal.BONE, 0.7))
		if enraged:
			# breath steaming out of him once he is bleeding
			for i in 4:
				var b := fmod(t * 1.6 + i * 0.25, 1.0)
				draw_circle(Vector2(f * (58.0 + b * 30.0), -40.0 - b * 16.0), 3.5 * (1.0 - b), Color(Pal.EMBER, 0.5 * (1.0 - b)))
		if flash > 0.0:
			draw_set_transform(Vector2(0, -36), 0.0, Vector2(1.75, 1.0))
			draw_circle(Vector2.ZERO, 34.0, Color(1, 1, 1, 0.4))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class Flytrap extends Critter:
	## A rooted snapping plant. It opens on a cycle and bites what is near it.
	## Deliberately NOT stompable: it snaps upward, so landing on it is a mistake.
	var t := 0.0
	var open := false
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
		# harmless while shut, so the open window is the telegraph
		damage = 1 if open else 0

	func _draw() -> void:
		var c := Pal.CHARCOAL
		var sway := sin(t * 1.7) * 3.0
		var head := Vector2(sway, -40)
		# stem
		draw_line(Vector2(0, 0), head, Pal.OCHRE_DEEP, 7.0)
		# base leaves
		draw_polygon(PackedVector2Array([Vector2(-18, 0), Vector2(-5, -12), Vector2(0, 0)]), PackedColorArray([Pal.OCHRE_DARK]))
		draw_polygon(PackedVector2Array([Vector2(18, 0), Vector2(5, -12), Vector2(0, 0)]), PackedColorArray([Pal.OCHRE_DARK]))
		if open:
			# upper and lower jaw, spread apart
			draw_polygon(PackedVector2Array([head + Vector2(-17, -2), head + Vector2(0, -6), head + Vector2(17, -2), head + Vector2(0, -24)]), PackedColorArray([c]))
			draw_polygon(PackedVector2Array([head + Vector2(-15, 6), head + Vector2(15, 6), head + Vector2(0, 22)]), PackedColorArray([c]))
			for i in 5:
				var x := -13.0 + i * 6.5
				draw_line(head + Vector2(x, 0), head + Vector2(x + 2, 8), Pal.BONE, 2.0)
		else:
			draw_polygon(PackedVector2Array([head + Vector2(-14, 10), head + Vector2(0, -18), head + Vector2(14, 10)]), PackedColorArray([c]))
		if flash > 0.0:
			draw_circle(head, 26.0, Color(1, 1, 1, 0.45))


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
		var f := float(dir)
		var c := Pal.CHARCOAL
		var run := sin(t * 22.0)
		for i in 4:
			var lx := -14.0 + i * 10.0
			draw_line(Vector2(lx, -16), Vector2(lx + sin(t * 22.0 + i * 1.6) * 7.0, 0), c, 4.0)
		draw_polygon(PackedVector2Array([
			Vector2(-f * 22, -20), Vector2(f * 16, -24), Vector2(f * 22, -14), Vector2(f * 14, -8), Vector2(-f * 20, -8)
		]), PackedColorArray([c]))
		draw_circle(Vector2(f * 26, -24 + run * 2.0), 8.0, c)
		draw_line(Vector2(f * 24, -30), Vector2(f * 32, -40), Pal.BONE, 3.0)
		draw_circle(Vector2(f * 29, -26), 1.6, Pal.EMBER)
		if flash > 0.0:
			draw_circle(Vector2(0, -18), 26.0, Color(1, 1, 1, 0.45))
