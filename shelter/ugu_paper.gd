extends Node3D
## UGU AT HOME AS HIS OWN 2D SELF: the real 2D rig (CaveMan, common/player.gd)
## drawn into a texture and stood up in the 3D home as a paper cut-out that
## always faces the camera, like the home's other paper figures. So he is
## EXACTLY the Ugu of the levels: the same face, expressions, run, jump pose,
## the air in his hair and clothes, costumes and weapon. Any change to his 2D
## art shows here too.
## Same interface as shelter/ugu3d.gd: the game sets `speed` and `air` every
## frame, calls `refresh()` after his costume or weapon changes; `era` picks
## the leaf skirt (1) or the tunic. Feet at the origin.

const TEX := Vector2i(512, 512)      ## the picture he is drawn into
const RIG_SCALE := 4.2               ## the 2D rig, scaled up in it
const FEET := Vector2(256, 478)      ## where his feet are in it
const HEIGHT_M := 1.85               ## how tall he stands at home (metres, with the mane)
const PX_PER_M := 160.0              ## his 3D speeds in the rig's pixels

var speed := 0.0                     ## 0 standing .. 1 running (set by the game)
var sprint := 0.0                    ## (the 3D figure's: unused on paper)
var look_at_point := Vector3.INF
var air := false
var era := 2
var vel := Vector3.ZERO              ## his velocity (world), worked out from how he moved
var _last := Vector3.INF
var _view: SubViewport
var _rig: CaveMan
var _card: Sprite3D


func _ready() -> void:
	_view = SubViewport.new()
	_view.size = TEX
	_view.transparent_bg = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_view)
	_rig = CaveMan.new()
	_rig.preview = true
	_rig.position = FEET
	_rig.scale = Vector2(RIG_SCALE, RIG_SCALE)
	_view.add_child(_rig)
	_card = Sprite3D.new()
	_card.texture = _view.get_texture()
	_card.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y        # faces the camera, stays upright
	_card.shaded = true                                       # the fires and the sun light him
	_card.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD          # a crisp edge, and a real shadow
	_card.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# his drawn height is ~ (mane to feet) 108 design px x RIG_SCALE: fit that to HEIGHT_M
	_card.pixel_size = HEIGHT_M / (108.0 * RIG_SCALE)
	_card.position.y = (TEX.y * 0.5 - FEET.y) * -_card.pixel_size    # feet on the ground
	add_child(_card)
	refresh()


## His costume and weapon (from GameState), and his era's clothes.
func refresh() -> void:
	if _rig == null:
		return
	GameState.apply_to(_rig)
	_rig.preview = true
	_rig.costume = 1 if era < 2 else 2


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	if _last != Vector3.INF:
		var step := (global_position - _last) / delta
		if step.length() < 20.0:              # (more is a teleport, not a run)
			vel = vel.lerp(step, minf(1.0, delta * 20.0))
	_last = global_position
	# which way he faces ON SCREEN: the camera's right
	var cam := get_viewport().get_camera_3d()
	var side := vel.dot(cam.global_basis.x) if cam != null else vel.x
	if absf(side) > 0.4:
		_rig.facing = 1 if side > 0.0 else -1
	# his motion, in the rig's terms: the stride from his speed, up / down from the jump
	var run := maxf(speed, clampf(Vector2(vel.x, vel.z).length() / 5.0, 0.0, 1.0))
	_rig.velocity = Vector2(_rig.facing * run * CaveMan.SPEED, -vel.y * PX_PER_M)
	_rig.puppet_air = air
	if not air and run > 0.02:
		_rig._run_phase += absf(_rig.velocity.x) * delta / (_rig._stride_amp(run) * CaveMan.ART)


## (the 3D figure's somersault, landing squash and grin: not on paper)
func jumped(_double := false) -> void:
	pass


func landed(_impact := 0.5) -> void:
	pass


func cheer(_t := 1.2) -> void:
	pass


func emote(_feeling: String, _t := 1.5) -> void:
	pass


func pose_face(_dials: Dictionary) -> void:
	pass
