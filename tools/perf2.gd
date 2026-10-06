extends Node
## Test harness (not shipped): which parts of the scene cost the draw calls.
var level: Node
var p: CaveMan
func _ready() -> void:
	level = load("res://level2/level2.tscn").instantiate()
	add_child(level)
	_run.call_deferred()
func quiet() -> void:
	for c in level.get_children():
		if c is Dialogue:
			c.queue_free()
	p.talking = false
	for m in level._mouths:
		m._noticed = true
func calls() -> float:
	var t := 0.0
	for i in 12:
		await get_tree().process_frame
		t += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return t / 12.0
func set_vis(pred: Callable, on: bool) -> void:
	for c in level.get_children():
		if pred.call(c):
			if c is CanvasLayer or c is ParallaxBackground:
				c.visible = on
			elif c is CanvasItem:
				c.visible = on
func _run() -> void:
	await get_tree().process_frame
	p = level.player
	p.give_torch()
	quiet()
	p.global_position = Vector2(24000, 32)
	for i in 30:
		await get_tree().process_frame
	quiet()
	var base: float = await calls()
	var pb: ParallaxBackground = null
	var sky: CanvasLayer = null
	for c in level.get_children():
		if c is ParallaxBackground:
			pb = c
		if c is CanvasLayer and c.layer == -120:
			sky = c
	sky.visible = false
	print("night sky (stars, moon)      %5.0f" % (base - await calls()))
	sky.visible = true
	for layer in pb.get_children():
		var art: Node = layer.get_child(0)
		(layer as CanvasItem).visible = false
		print("%-28s %5.0f" % [art.get_script().get_global_name() if art.get_script().get_global_name() != "" else str(art.get_script()).get_file(), base - await calls()])
		(layer as CanvasItem).visible = true
	for layer in pb.get_children():
		print("  class: ", layer.get_child(0).get_class(), " ", layer.get_child(0))
	get_tree().quit()
