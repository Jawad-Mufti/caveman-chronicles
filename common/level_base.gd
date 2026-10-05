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


static var _cam_frame := -1
static var _cam_vp: Viewport = null
static var _cam_ok := false
static var _cam_c := Vector2.ZERO


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
	if not _cam_ok:
		return true
	var c := _cam_c
	return absf(n.global_position.x - c.x) < margin + 640.0 and absf(n.global_position.y - c.y) < margin + 360.0


func _build_player(start: Vector2) -> void:
	player = CaveMan.new()
	player.position = start
	last_safe = start
	add_child(player)
	GameState.apply_to(player)

	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_right = int(level_w)
	cam.limit_top = cam_top
	cam.limit_bottom = 1200
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	add_child(cam)
	cam.make_current()


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
	hud.menu_tapped.connect(open_menu)
	if DisplayServer.is_touchscreen_available():
		hud.add_touch_controls(player)


func set_checkpoint(at: Vector2) -> void:
	has_checkpoint = true
	checkpoint = at


func _on_died() -> void:
	if not has_checkpoint:
		hud.say("He did not make it. Press R.", 999.0)
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
		if (event as InputEventKey).physical_keycode == KEY_R:
			get_tree().reload_current_scene()
		elif (event as InputEventKey).physical_keycode in [KEY_ESCAPE, KEY_TAB, KEY_M]:
			open_menu()


## The Camp Menu (Esc, Tab, M, or the tent at the top): save, shelter, abilities.
func open_menu() -> void:
	if player == null or player.dead or player.talking:
		return
	if get_tree().get_first_node_in_group("camp_menu") != null:
		return
	var m := CampMenu.new()
	m.player = player
	m.level_name = title
	add_child(m)


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
