class_name LevelBase
extends Node2D
## What every level shares: the caveman, the camera, the HUD, fall recovery,
## on-screen notes, restart, and the helpers that build the parallax bands.
## A level extends this and is left holding only its own data tables and its
## own set-pieces — which is the whole point: a new level is new tables.

var level_w := 9400.0
var fall_y := 1020.0
var cam_top := 0          ## raise (negative) for levels that climb
var title := ""
var player: CaveMan
var cam: Camera2D
var hud: Hud
var last_safe := Vector2(140, 600)
var last_safe_facing := 1
var finished := false
var gem_found := false
## Set by bonfires and the like. While there is one, death puts him back
## there after a beat instead of asking for a full restart.
var has_checkpoint := false
var _shake_power := 0.0
var _shake_time := 0.0
var checkpoint := Vector2.ZERO
var resumed := false      ## LOAD put him at his saved spot (no opening story)
var sleeper: Sleeper      ## puts what is far from the camera to sleep (common/sleeper.gd)


static var _cam_frame := -1
static var _cam_vp: Viewport = null
static var _cam_ok := false
static var _cam_c := Vector2.ZERO
static var _cam_half := Vector2(640, 360)   ## half of what the camera shows, in world units


## Is this node near what the camera can see? Things that animate only need
## redrawing (or moving) then.
## Hundreds of things ask this every frame, so the camera centre is looked up
## once per frame (per viewport) and shared.
static func near_view(n: Node2D, margin: float = 800.0) -> bool:
	var vp := n.get_viewport()
	var f := Engine.get_process_frames()
	if f != _cam_frame or vp != _cam_vp:
		_cam_frame = f
		_cam_vp = vp
		var cam := vp.get_camera_2d()
		_cam_ok = cam != null
		if _cam_ok:
			_cam_c = cam.get_screen_center_position()
			_cam_half = vp.get_visible_rect().size * 0.5 / cam.zoom
	if not _cam_ok:
		return true
	var c := _cam_c
	return absf(n.global_position.x - c.x) < margin + _cam_half.x and absf(n.global_position.y - c.y) < margin + _cam_half.y


## Half the size of what the camera shows, in world units (wider when the
## view is pulled back). For anything that decides "is this on screen".
static func view_half(n: Node2D) -> Vector2:
	near_view(n)          # refreshes the per-frame camera numbers
	return _cam_half


func _build_player(start: Vector2) -> void:
	# LOAD: he wakes where he last saved
	var saved := GameState.take_resume(scene_file_path)
	resumed = not saved.is_empty()
	if resumed:
		start = Vector2(float(saved["x"]), float(saved["y"]))
	sleeper = Sleeper.new()
	add_child(sleeper)
	player = CaveMan.new()
	player.position = start
	last_safe = start
	add_child(player)
	GameState.apply_to(player)
	if resumed:
		if bool(saved.get("torch", false)):
			player.give_torch()
		set_checkpoint(start)
		_unstick.call_deferred()

	cam = Camera2D.new()
	cam.position = start + Vector2(0, -150)
	cam.limit_left = 0
	cam.limit_right = int(level_w)
	cam.limit_top = cam_top
	cam.limit_bottom = 1200
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	add_child(cam)
	cam.make_current()
	apply_view(Rect2(0, cam_top, level_w, 1200 - cam_top))


## Call after _build_player: the HUD listens to him.
func _build_hud() -> void:
	hud = Hud.new()
	hud.title = title
	add_child(hud)
	player.hp_changed.connect(func(v: int) -> void: hud.set_hp(v))
	player.berries_changed.connect(func(v: int) -> void: hud.set_berries(v))
	player.rocks_changed.connect(func(v: int) -> void: hud.set_rocks(v))
	player.wood_changed.connect(func(v: int) -> void: hud.set_wood(v))
	player.poultice.connect(func(_ok: bool, note: String) -> void:
		if note != "":
			hud.say(note, 2.0))
	player.said.connect(func(note: String) -> void: hud.say(note, 2.5))
	player.died.connect(_on_died)
	hud.max_hp = player.max_hp
	hud.set_hp(player.hp)
	hud.set_shells(GameState.shells)
	hud.set_figs(GameState.figs)
	hud.set_bones(GameState.bones)
	hud.fig_tapped.connect(func() -> void: player.eat_fig())
	player.ate_fig.connect(func() -> void: hud.set_figs(GameState.figs))
	hud.player = player
	hud.ability_tapped.connect(use_ability)
	hud.menu_tapped.connect(func() -> void: open_menu(not has_checkpoint))
	if DisplayServer.is_touchscreen_available():
		hud.add_touch_controls(player)
	if resumed:
		hud.say("Back from the cave. Off he goes again!" if GameState.from_home else "He wakes where he last saved.", 3.0)
		GameState.from_home = false
	FX.warm_up(self, player.global_position + Vector2(0, -40))      # shaders compile now, not mid-jump


## SAVE (Camp Menu): everything, and where he stands — on firm ground, or
## the last firm ground he stood on.
func save_spot() -> void:
	var at := player.global_position if _standing_safe() else last_safe
	GameState.save_spot(scene_file_path, at, player.has_torch, title)


## LOAD (Camp Menu): the level again, and him at his saved spot.
func load_spot() -> void:
	var path := str(GameState.spot.get("level", ""))
	if path == "":
		return
	GameState.resume = true
	get_tree().paused = false
	get_tree().change_scene_to_file(path)



## HOME (the Camp Menu's UGU'S CAVE): off to the cave; leaving it brings him
## back here, where he stood (not his SAVE spot: that is untouched).
const HOME := "res://shelter/home.tscn"


func go_home() -> void:
	var at := player.global_position if _standing_safe() else last_safe
	GameState.away = {"level": scene_file_path, "x": at.x, "y": at.y, "torch": player.has_torch}
	GameState.save()
	get_tree().paused = false
	get_tree().change_scene_to_file(HOME)

## LOAD: a tunnel he dug is rock again on a new visit. Buried? Lift him
## (his capsule) until he is clear.
func _unstick() -> void:
	await get_tree().physics_frame
	var cap := CapsuleShape2D.new()
	cap.radius = 13.0
	cap.height = 64.0
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = cap
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	var space := get_world_2d().direct_space_state
	for i in 60:
		var at := player.global_position + Vector2(0, -20.0 * i)
		q.transform = Transform2D(0.0, at + Vector2(0, -32))
		if space.intersect_shape(q, 1).is_empty():
			if i > 0:
				player.global_position = at
				player.velocity = Vector2.ZERO
				set_checkpoint(at)
			return


func set_checkpoint(at: Vector2) -> void:
	has_checkpoint = true
	checkpoint = at


func _on_died() -> void:
	if not has_checkpoint:
		hud.say("He did not make it.", 2.0)
		await get_tree().create_timer(1.6).timeout
		if is_instance_valid(player) and player.dead:
			open_menu(true)                # RESTART LEVEL waits there
		return
	hud.say("He did not make it.", 2.0)
	await get_tree().create_timer(2.2).timeout
	if not is_instance_valid(player) or not player.dead:
		return
	player.revive(checkpoint)
	last_safe = checkpoint
	hud.say("He wakes by the fire.", 2.5)


## ---------------------------------------------------------------- panorama
## A panorama band: no mirroring, and long enough to cover the whole level at
## this band's speed — a slower band needs less, because it moves less.
func _pano(pb: ParallaxBackground, art: World.Panorama, motion: Vector2) -> ParallaxLayer:
	art.s = motion.x
	art.length = (level_w - 1280.0) * motion.x + 1500.0
	var pl := ParallaxLayer.new()
	pl.motion_scale = motion
	pb.add_child(pl)
	pl.add_child(art)
	return pl


func _band(pb: ParallaxBackground, motion: Vector2, tile: float, art: Node2D) -> void:
	var pl := ParallaxLayer.new()
	pl.motion_scale = motion
	pl.motion_mirroring = Vector2(tile, 0)
	pb.add_child(pl)
	pl.add_child(art)


## Shake the view: a boss hitting the ground, a big blow landing.
func shake(power: float, secs: float) -> void:
	_shake_power = power
	_shake_time = secs


## A line of text the first time he walks past x.
func _note(x: float, text: String, seconds: float = 3.0) -> void:
	var t := World.Trigger.new(Rect2(x, 100, 60, 900))
	t.tripped.connect(func() -> void: hud.say(text, seconds))
	add_child(t)


func _process(_delta: float) -> void:
	cam.global_position = player.global_position + Vector2(0, -150)
	# the fire's wind-up trembles the view, and the release jolts it
	var shake := 0.0
	if _shake_time > 0.0:
		_shake_time -= get_process_delta_time() / maxf(Engine.time_scale, 0.05)
		shake = _shake_power
	if player.fury >= 0.0:
		if player.fury < CaveMan.FURY_RELEASE:
			shake = 3.0 * player.fury / CaveMan.FURY_RELEASE
		else:
			shake = 8.0 * (1.0 - clampf((player.fury - CaveMan.FURY_RELEASE) / 0.25, 0.0, 1.0))
	cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake

	if not player.dead and _standing_safe():
		last_safe = player.global_position
		last_safe_facing = player.facing
	if player.global_position.y > fall_y and not player.dead:
		# Set down well back from the lip he walked off, facing the way he came,
		# so he is not dropped straight back into the same hole.
		player.respawn_at(_safe_spot())
		player.facing = -last_safe_facing
		hud.say("He drags himself back up. That cost him.", 2.0)


## Back from the lip he fell off, facing the way he came — unless that would
## put him in the air (a narrow ledge), in which case right where he stood.
func _safe_spot() -> Vector2:
	var spot := last_safe + Vector2(-58.0 * last_safe_facing, -10.0)
	if not (_solid_below(spot + Vector2(-16, 0)) and _solid_below(spot + Vector2(16, 0))):
		spot = last_safe + Vector2(0, -10)
	return spot


## Ground that stays put: a static body that can't break, burn or fall away
## (those join "unsafe_ground"). Moving things — a mammoth's back, a log on
## the tar — are never static.
static func _firm(body: Object) -> bool:
	return body is StaticBody2D and not (body as Node).is_in_group("unsafe_ground")


## Firm ground just under this point?
func _solid_below(at: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(at + Vector2(0, -8), at + Vector2(0, 26), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and _firm(hit["collider"])


## Is he standing somewhere worth remembering as safe? On firm ground, and
## with firm ground under both sides of him — not teetering on a lip (set
## down there, he would slide straight back into the hole).
func _standing_safe() -> bool:
	if not player.is_on_floor():
		return false
	for i in player.get_slide_collision_count():
		var c := player.get_slide_collision(i)
		if c.get_normal().y < -0.7 and not _firm(c.get_collider()):
			return false
	var p := player.global_position
	return _solid_below(p + Vector2(-16, 0)) and _solid_below(p + Vector2(16, 0))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		if key in [KEY_EQUAL, KEY_KP_ADD]:
			_look_zoom(1.25)
		elif key in [KEY_MINUS, KEY_KP_SUBTRACT]:
			_look_zoom(1.0 / 1.25)
		elif key in [KEY_0, KEY_KP_0]:
			_look_zoom(0.0)
		elif key in [KEY_ESCAPE, KEY_TAB, KEY_M]:
			open_menu(not has_checkpoint)     # dead for good: the menu has RESTART


## The Camp Menu (Esc, Tab, M, or the tent at the top): save, shelter, abilities.
func open_menu(dead_ok: bool = false) -> void:
	if player == null or (player.dead and not dead_ok) or player.talking:
		return
	if get_tree().get_first_node_in_group("camp_menu") != null:
		return
	var m := CampMenu.new()
	m.player = player
	m.level_name = title
	add_child(m)
	if player.dead:
		m._select(m.row_of("restart"))


## A tap on one of the two ability circles.
func use_ability(id: String) -> void:
	if player == null or player.dead or player.talking:
		return
	match id:
		"sunfire":
			if not player.start_sunfire() and player.sun_t <= 0.0:
				hud.say("The sun isn't full yet: hit beasts, grab shells, sit by a fire.", 2.5)
		"firering":
			player.start_fire()


## The camera's zoom: the player's View setting (GameState.view_zoom) — but
## never so far out that the view is bigger than the place it is showing
## (a cave is only so tall), or it would show what is outside it.
var _view_rect := Rect2()


func apply_view(rect: Rect2 = Rect2()) -> void:
	if rect.size != Vector2.ZERO:
		_view_rect = rect
	if cam == null:
		return
	var screen := get_viewport().get_visible_rect().size
	var z := GameState.view_zoom() * look_zoom
	if _view_rect.size != Vector2.ZERO:
		z = maxf(z, maxf(screen.x / _view_rect.size.x, screen.y / _view_rect.size.y))
	cam.zoom = Vector2(z, z)


## LOOK CLOSER: + / - zoom the camera in and out over the chosen VIEW, to see him
## (and the world) up close; 0 puts it back. Not saved.
var look_zoom := 1.0


func _look_zoom(k: float) -> void:
	look_zoom = 1.0 if k == 0.0 else clampf(look_zoom * k, 0.6, 5.0)
	apply_view()
	if hud != null:
		hud.say("Zoom x%.1f   (+ / -, 0 resets)" % look_zoom, 1.2)
