extends Node
## Test harness (not shipped): pictures of the home's sights (shelter/*.gd),
## run WITH rendering. PNGs to C:/tmp/shots/sights_<name>.png.
##   args: all (every build built, every relic owned, bones to spare), only=<a,b>
##   (names from SIGHTS), the rest as they are in a fresh save.
var home: Node3D

## [name, where Ugu stands (x, z), night 0..1, zoom, his facing (yaw)]
const SIGHTS := [
	["meadow", Vector2(-14, 6), 0.1, 1.0, PI],
	["rainbow", Vector2(13, -6), 0.05, 1.0, PI],
	["pool", Vector2(15, -11), 0.2, 0.55, PI],
	["plaza_day", Vector2(0, -6), 0.15, 1.0, PI],
	["plaza_night", Vector2(0, -6), 0.85, 1.0, PI],
	["cave_night", Vector2(0, -22.5), 0.85, 0.9, PI],
	["relics", Vector2(-3.0, -25.4), 0.8, 0.75, -PI * 0.75],
	["gate_night", Vector2(0.5, 3.5), 0.9, 1.0, PI],
	["bridge", Vector2(29.5, -6.5), 0.3, 1.0, PI * 0.8],
	["grove_night", Vector2(33.5, -13.5), 0.9, 1.2, PI * 0.8],
	["star_rock", Vector2(42.6, -25.2), 0.75, 1.3, PI],
	["lookout", Vector2(-18.5, -7.0), 0.3, 1.2, PI],
	["totem", Vector2(10.5, -11.0), 0.6, 0.7, PI],
	["hammock", Vector2(16.0, 41.0), 0.25, 0.9, PI],
	["island", Vector2(0, 6), 0.1, 1.6, PI],
]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	GameState.reset()
	if args.has("all"):
		GameState.bones = 999
		GameState.trophies = ["sabre_fang", "old_scar", "tuskar"]
		for k in Relics.KINDS:
			GameState.relics[k] = 1
		GameState.shelter["built"] = ["hammock", "campfire", "gate", "bridge", "totem", "lookout"]
		GameState.give_item("obsidian_mirror")
	home = load("res://shelter/home.tscn").instantiate()
	add_child(home)
	_run.call_deferred()


func _run() -> void:
	var only := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = Array(a.substr(5).split(","))
	for f in 30:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("C:/tmp/shots")
	for s in SIGHTS:
		if not only.is_empty() and not only.has(s[0]):
			continue
		var p: Vector2 = s[1]
		var top: float = home.pad_top(p)
		home._pos = Vector3(p.x, maxf(home.height(p.x, p.y), top if top > -INF else -99.0), p.y)
		home._vy = 0.0
		home._night = s[2]
		home._night_to = s[2]
		home._apply_daylight(true)
		home._zoom = s[3]
		home._zoom_to = s[3]
		home._model.rotation.y = s[4]
		home._cam.position = home._pos + home.CAM_FAR * float(s[3])
		for f in 50:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("C:/tmp/shots/sights_%s.png" % s[0])
		print("shot sights_", s[0])
	get_tree().quit()
