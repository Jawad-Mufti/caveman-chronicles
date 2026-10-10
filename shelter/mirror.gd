extends Node3D
## THE OBSIDIAN MIRROR (Bag "mirror": 2 obsidian, 2 bones, 1 clay; made once).
## It stands in his cave (shelter/home.gd), facing out: a tall oval of black
## glass in a frame of bones lashed with cord, on a clay foot. The glass shows
## his REFLECTION: a camera in it (a SubViewport of the same world), flipped,
## darkened like black glass; it only renders while he is near.
## E at it opens THE FACE STUDIO (open()): he stands at the glass, the camera
## looks over his shoulder, and a panel makes his face (Ugu3D.pose_face): one of
## his feelings (Ugu3D.EXPRESSIONS) to start from, then sliders to mix it (a
## smile or a frown, mouth open, wink, cross-eyed, tongue out...), or a SILLY one.
##   Left / Right: a feeling   Up / Down: a slider   A / D: move it
##   R: a silly face   Esc / E: done.     (The mouse works on all of it.)
## The home builds it with its own shapes (`home._shape` etc.); the frame is
## still, the glass is the only part that changes.

signal closed

const UguModel := preload("res://shelter/ugu3d.gd")
const GLASS := Vector2(0.95, 1.35)             ## the glass: width, height (metres)
const MID_Y := 1.55                            ## its middle, over the floor
const STAND := 1.55                            ## where he stands to look in: this far out from it
const LAYER_GLASS := 1 << 19                   ## (the camera in the glass doesn't see the glass)
const LAYER_LABELS := 1 << 18                  ## the home's floating labels: not in the glass either
const GLASS_SHADER := "shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D view : source_color, filter_linear;
uniform float shine = -1.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = dot(q, q);
	if (r > 1.0) {
		discard;
	}
	vec3 c = texture(view, vec2(1.0 - UV.x, UV.y)).rgb;
	c = c * vec3(0.9, 0.92, 1.0) * (1.0 - 0.3 * smoothstep(0.6, 1.0, r));       // black glass: darker at the rim
	float band = smoothstep(0.09, 0.0, abs(UV.x * 0.8 + UV.y * 0.55 - shine));        // a shine sweeping over it
	c += vec3(1.0, 0.95, 0.85) * band * 0.55;
	c += vec3(0.9, 0.9, 1.0) * 0.12 * smoothstep(0.22, 0.0, length(q - vec2(-0.45, -0.55)));   // a glint, up left
	ALBEDO = c;
}
"
## The feelings to start from: id (Ugu3D.EXPRESSIONS) -> its button
const FEELINGS := [["smile", "SMILE"], ["happy", "HAPPY"], ["grin", "GRIN"], ["laugh", "LAUGH"], ["whee", "WHEE!"],
	["tongue", "TONGUE"], ["effort", "GRRR"], ["ooh", "OOH!"], ["scared", "SCARED"], ["wince", "OUCH"], ["yawn", "YAWN"],
	["curious", "HMM?"], ["bored", "BORED"], ["sleepy", "SLEEPY"], ["sad", "SAD"], ["angry", "ANGRY"], ["proud", "PROUD"]]
## The sliders: [label, dial (Ugu3D.FACE_REST), low, high]. "teeth" moves the
## teeth's dials together.
const SLIDERS := [["Smile  /  frown", "smile", -1.0, 1.0], ["Mouth open", "open", 0.0, 1.0], ["Round  /  wide", "wide", -1.5, 1.0],
	["Teeth", "teeth", 0.0, 1.0], ["Tongue out", "tongue_out", 0.0, 1.0], ["Smirk", "smirk", -1.0, 1.0],
	["Brows up", "brow", -0.6, 1.0], ["Worried  /  angry", "knit", -1.0, 1.0], ["Wink (this eye)", "wink_l", 0.0, 1.0],
	["Wink (that eye)", "wink_r", 0.0, 1.0], ["Sleepy eyes", "lid", 0.0, 0.9], ["Happy eyes", "squint", 0.0, 1.0],
	["Cross-eyed", "cross", 0.0, 1.0], ["Head tilt", "tilt", -0.3, 0.3]]

var home: Node3D
var model: Node3D                              ## Ugu (the 3D one: pose_face)
var is_open := false
var face := {}                                 ## the face being made: dial -> value
var feeling := 0                               ## the feeling it started from (FEELINGS)
var _vp: SubViewport
var _rcam: Camera3D
var _glass: MeshInstance3D
var _gmat: ShaderMaterial
var _shine := -1.0
var _tick := 0
var _unseen := false                          ## just made, and he hasn't been to see it yet
var _sparkle: CPUParticles3D
var _ui: CanvasLayer
var _buttons: Array = []
var _rows: Array = []                          ## [label, slider] each
var _sel := 0
var _name: Label


## The frame, the glass, the camera in it. `fresh`: it was just made (a shine
## and sparkles: it's READY).
func build(fresh: bool) -> void:
	var bone := Color("efe4c8")
	var clay := Color("b8643a")
	var cord := Color("3b2a22")
	# the clay foot, and two bones standing in it, lashed to the frame
	home._shape(home._cyl(0.42, 0.22, 10, 0.5), clay, Vector3(0, 0.11, 0), Vector3.ZERO, Vector3(1, 1, 0.7), self)
	home._shape(home._ball(0.34, 8), clay.darkened(0.12), Vector3(0, 0.22, 0), Vector3.ZERO, Vector3(1.1, 0.35, 0.8), self)
	for side in [-1.0, 1.0]:
		home._shape(home._cyl(0.045, MID_Y + 0.25, 7), bone, Vector3(side * 0.5, (MID_Y + 0.25) * 0.5 + 0.15, -0.04), Vector3(0, 0, -side * 3.0), Vector3.ONE, self)
		home._shape(home._ball(0.075, 6), bone, Vector3(side * 0.53, MID_Y + 0.4, -0.04), Vector3.ZERO, Vector3.ONE, self)
		for y in [MID_Y - 0.25, MID_Y + 0.2]:
			home._shape(home._cyl(0.06, 0.05, 8), cord, Vector3(side * 0.49, y, -0.03), Vector3.ZERO, Vector3.ONE, self)
	# the frame: a ring of short bones round the oval, a cord binding each
	var n := 16
	for k in n:
		var a := TAU * (k + 0.5) / n
		var p := Vector3(cos(a) * (GLASS.x * 0.5 + 0.05), MID_Y + sin(a) * (GLASS.y * 0.5 + 0.05), -0.01)
		var tang := Vector3(-sin(a) * GLASS.x, cos(a) * GLASS.y, 0).normalized()
		var seg := home._shape(home._cyl(0.04, 0.3, 6), bone.darkened(0.04 * (k % 2)), p, Vector3.ZERO, Vector3.ONE, self) as MeshInstance3D
		seg.basis = Basis(tang.cross(Vector3.BACK), tang, Vector3.BACK).orthonormalized()
		var a2 := TAU * k / n
		home._shape(home._ball(0.05, 5), cord, Vector3(cos(a2) * (GLASS.x * 0.5 + 0.05), MID_Y + sin(a2) * (GLASS.y * 0.5 + 0.05), -0.01), Vector3.ZERO, Vector3(1, 1, 0.8), self)
	# the back: a hide stretched behind the glass
	home._shape(home._cyl(0.5, 0.03, 16), Color("9a6a40").darkened(0.2), Vector3(0, MID_Y, -0.06), Vector3(90, 0, 0), Vector3(GLASS.x, 1, GLASS.y * 0.98), self)
	# THE GLASS: what the camera in it sees, flipped
	_vp = SubViewport.new()
	_vp.size = Vector2i(380, 540)
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.positional_shadow_atlas_size = 512        # (with none, Compatibility drops the omni lights: no firelight)
	add_child(_vp)
	_rcam = Camera3D.new()
	_rcam.cull_mask = 0xFFFFF & ~LAYER_GLASS & ~LAYER_LABELS
	_rcam.fov = 46.0
	_rcam.near = 0.05
	_rcam.far = 12.0                              # (the cave and the plaza: all the glass needs)
	if home._env != null:
		var env: Environment = home._env.duplicate()
		env.glow_enabled = false
		_rcam.environment = env
	_vp.add_child(_rcam)
	_rcam.current = true
	var quad := QuadMesh.new()
	quad.size = GLASS
	_glass = MeshInstance3D.new()
	_glass.mesh = quad
	_glass.position = Vector3(0, MID_Y, 0.0)
	_glass.layers = LAYER_GLASS
	_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gmat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GLASS_SHADER
	_gmat.shader = sh
	_gmat.set_shader_parameter("view", _vp.get_texture())
	_glass.material_override = _gmat
	add_child(_glass)
	_sparkle = home._particles(30, 1.2, Color("fff2c0"), 0.03, 0.07, true)
	_sparkle.position = Vector3(0, MID_Y, 0.15)
	_sparkle.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_sparkle.emission_box_extents = Vector3(GLASS.x * 0.5, GLASS.y * 0.5, 0.05)
	_sparkle.gravity = Vector3(0, 0.3, 0)
	_sparkle.one_shot = true
	_sparkle.emitting = false
	add_child(_sparkle)
	_unseen = fresh
	if fresh:
		ready_shine()


## It's ready: a shine over the glass, sparkles.
func ready_shine() -> void:
	_shine = -0.4
	_sparkle.restart()


## Where he stands to look in (world).
func stand_point() -> Vector3:
	return global_transform * Vector3(0, 0, STAND)


## The middle of the glass (world).
func glass_mid() -> Vector3:
	return global_transform * Vector3(0, MID_Y, 0)


## The camera over his shoulder while the studio is open: [where, looking at].
func studio_camera() -> Array:
	return [global_transform * Vector3(1.9, 2.25, STAND + 2.0), global_transform * Vector3(-0.1, MID_Y - 0.1, 0)]


func _process(delta: float) -> void:
	model = home._model if home != null else null
	if _vp == null:
		return
	if _shine > -1.0:
		_shine += delta * 1.1
		if _shine > 1.8:
			_shine = -1.0
		_gmat.set_shader_parameter("shine", _shine)
	# the glass shows him only while he is near (a second view of the world costs)
	var near := model != null and is_instance_valid(model) and model.global_position.distance_to(global_position) < 7.0
	_tick += 1
	var live := is_open or (near and _tick % 3 == 0)    # walking by: every third frame is plenty
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE if live else SubViewport.UPDATE_DISABLED
	if near and _unseen and model.global_position.distance_to(global_position) < 5.0:
		_unseen = false                         # his first look at it: it shines, it sparkles
		ready_shine()
		home.say("His OBSIDIAN MIRROR! Go up to it and press E.")
	if near or is_open:
		# the camera in the glass looks out at him: his face fills it in the studio
		var head := model.global_position + Vector3(0, 1.58, 0)
		var at := glass_mid() + global_transform.basis.z * 0.02
		var d := maxf(at.distance_to(head), 0.5)
		_rcam.global_position = at
		var look := head if is_open else at + global_transform.basis.z * 2.0 + Vector3(0, -0.15, 0)
		_rcam.look_at(look, Vector3.UP)
		_rcam.fov = lerpf(_rcam.fov, rad_to_deg(2.0 * atan(0.42 / d)) if is_open else 52.0, minf(1.0, delta * 4.0))


## ------------------------------------------------------------------ THE FACE STUDIO
func open() -> void:
	if is_open:
		return
	is_open = true
	home.say("")
	feeling = 0
	_build_ui()
	pick_feeling(0)
	if model.has_method("emote"):
		model.emote("curious", 0.1)


func close() -> void:
	if not is_open:
		return
	is_open = false
	if model.has_method("pose_face"):
		model.pose_face({})
		model.cheer(0.9)                       # what a face!
	if _ui != null:
		_ui.queue_free()
		_ui = null
	_buttons.clear()
	_rows.clear()
	closed.emit()


## Start from one of his feelings: the sliders jump to it.
func pick_feeling(i: int) -> void:
	feeling = posmod(i, FEELINGS.size())
	var id: String = FEELINGS[feeling][0]
	face = UguModel.FACE_REST.duplicate()
	face.merge(UguModel.EXPRESSIONS[id], true)
	face["tongue_out"] = 1.0 if id == "tongue" else 0.0
	_apply()
	if _name != null:
		_name.text = FEELINGS[feeling][1]
	for k in _buttons.size():
		_style_button(_buttons[k], k == feeling)


## A slider moved (or set): that dial, and the face.
func set_dial(dial: String, v: float) -> void:
	face[dial] = v
	if dial == "teeth":
		face["teeth_lo"] = clampf(v * 2.0 - 1.0, 0.0, 1.0)
		face["span"] = lerpf(0.55, 1.0, v)
	_apply()
	if _name != null:
		_name.text = "YOUR FACE"


## R: a silly face (a big mouth or a tiny one, a wink, maybe the tongue, maybe cross-eyed...).
func silly() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for s in SLIDERS:
		face[s[1]] = rng.randf_range(float(s[2]), float(s[3]))
	for w in ["wink_l", "wink_r", "cross", "tongue_out"]:
		face[w] = 1.0 if rng.randf() < 0.35 else 0.0
	set_dial("teeth", face["teeth"])
	if _name != null:
		_name.text = "SILLY!"


func _apply() -> void:
	if model != null and model.has_method("pose_face"):
		model.pose_face(face)
	for r in _rows:
		var sl: HSlider = r[1]
		sl.set_value_no_signal(float(face.get(sl.get_meta("dial"), 0.0)))


func _input(e: InputEvent) -> void:
	if not is_open or not (e is InputEventKey and e.pressed):
		return
	var key := (e as InputEventKey).physical_keycode
	get_viewport().set_input_as_handled()      # every key is the studio's: no jumping, no leaving
	match key:
		KEY_LEFT:
			pick_feeling(feeling - 1)
		KEY_RIGHT:
			pick_feeling(feeling + 1)
		KEY_UP, KEY_W:
			_select(_sel - 1)
		KEY_DOWN, KEY_S:
			_select(_sel + 1)
		KEY_A, KEY_D:
			var s: Array = SLIDERS[_sel]
			var step := (float(s[3]) - float(s[2])) / 10.0 * (-1.0 if key == KEY_A else 1.0)
			set_dial(s[1], clampf(float(face.get(s[1], 0.0)) + step, float(s[2]), float(s[3])))
		KEY_R:
			silly()
		KEY_ESCAPE, KEY_E, KEY_Q, KEY_ENTER:
			if not e.is_echo():
				close()


func _select(i: int) -> void:
	_sel = posmod(i, SLIDERS.size())
	for k in _rows.size():
		(_rows[k][0] as Label).add_theme_color_override("font_color", Color("ffe066") if k == _sel else Color("e8dcc4"))


## ---- the panels: the feelings on the left, the sliders on the right, the
## name of the face over the glass, the keys at the foot
func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	var left := _panel(Vector2(16, 96), Vector2(300, 560))
	_text(left, "MAKE A FACE!", Vector2(18, 10), Vector2(270, 40), 30, Color("ffcf40"), Pal.title_font())
	_text(left, "Start from a feeling:", Vector2(18, 50), Vector2(270, 24), 15, Color("d8c8b0"), Pal.text_font())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(14, 80)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	left.add_child(grid)
	for i in FEELINGS.size():
		var b := Button.new()
		b.text = FEELINGS[i][1]
		b.custom_minimum_size = Vector2(132, 44)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", Pal.title_font())
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(pick_feeling.bind(i))
		grid.add_child(b)
		_buttons.append(b)
	var right := _panel(Vector2(944, 96), Vector2(320, 560))
	_text(right, "MIX YOUR OWN", Vector2(18, 10), Vector2(290, 40), 30, Color("9be15d"), Pal.title_font())
	var box := VBoxContainer.new()
	box.position = Vector2(18, 54)
	box.size = Vector2(284, 490)
	box.add_theme_constant_override("separation", 1)
	right.add_child(box)
	for s in SLIDERS:
		var l := Label.new()
		l.text = s[0]
		l.add_theme_font_override("font", Pal.text_font())
		l.add_theme_font_size_override("font_size", 14)
		box.add_child(l)
		var sl := HSlider.new()
		sl.min_value = s[2]
		sl.max_value = s[3]
		sl.step = 0.01
		sl.focus_mode = Control.FOCUS_NONE
		sl.custom_minimum_size = Vector2(284, 16)
		sl.set_meta("dial", s[1])
		sl.value_changed.connect(func(v: float) -> void: set_dial(s[1], v))
		box.add_child(sl)
		_rows.append([l, sl])
	_name = _text(_ui, "", Vector2(340, 92), Vector2(600, 60), 44, Color("ffe066"), Pal.title_font())
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_color_override("font_outline_color", Color("2a1a10"))
	_name.add_theme_constant_override("outline_size", 10)
	var silly_b := Button.new()
	silly_b.text = "SILLY FACE!  (R)"
	silly_b.position = Vector2(470, 600)
	silly_b.custom_minimum_size = Vector2(170, 44)
	silly_b.focus_mode = Control.FOCUS_NONE
	silly_b.add_theme_font_override("font", Pal.title_font())
	silly_b.add_theme_font_size_override("font_size", 19)
	silly_b.pressed.connect(silly)
	_ui.add_child(silly_b)
	var done := Button.new()
	done.text = "DONE  (Esc)"
	done.position = Vector2(650, 600)
	done.custom_minimum_size = Vector2(170, 44)
	done.focus_mode = Control.FOCUS_NONE
	done.add_theme_font_override("font", Pal.title_font())
	done.add_theme_font_size_override("font_size", 19)
	done.pressed.connect(close)
	_ui.add_child(done)
	_style_button(silly_b, true)
	_style_button(done, true)
	var foot := _text(_ui, "Left / Right: a feeling      Up / Down: a slider      A / D: move it", Vector2(340, 662), Vector2(600, 24), 15, Color("e8dcc4"), Pal.text_font())
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_color_override("font_outline_color", Color("1a0f08"))
	foot.add_theme_constant_override("outline_size", 6)
	_select(0)


func _panel(at: Vector2, size: Vector2) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.07, 0.05, 0.86)
	sb.border_color = Color("ffcf40", 0.85)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	p.add_theme_stylebox_override("panel", sb)
	p.position = at
	p.size = size
	_ui.add_child(p)
	return p


func _text(parent: Node, s: String, at: Vector2, size: Vector2, fs: int, col: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = s
	l.position = at
	l.size = size
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _style_button(b: Button, on: bool) -> void:
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("ffcf40", 0.9 if st == "pressed" else (0.75 if on else 0.16)) if st != "hover" or on else Color("ffcf40", 0.32)
		sb.set_corner_radius_all(10)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color("2a1a10") if on else Color("f3e3c3"))
	b.add_theme_color_override("font_hover_color", Color("2a1a10") if on else Color("fff2c0"))
