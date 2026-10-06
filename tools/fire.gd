extends Node
## Test harness (not shipped): fire situations, one after another, marked in the log.
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
func phase(label: String, at: Vector2, frames: int) -> void:
	printerr("### PHASE ", label)
	p.global_position = at
	p.velocity = Vector2.ZERO
	p.invuln = 999.0
	for i in frames:
		await get_tree().process_frame
		quiet()
func _run() -> void:
	await get_tree().process_frame
	p = level.player
	quiet()
	await phase("walk into the camp fire", Vector2(470, 590), 120)
	await phase("standing in the camp fire", Vector2(520, 590), 120)
	await phase("lighting bonfire 2", Vector2(1720, 590), 120)
	p.wood = 4
	await phase("fire burst", Vector2(1250, 590), 5)
	p.touch["fire"] = true
	await get_tree().process_frame
	p.touch["fire"] = false
	await phase("fire burst (after)", p.global_position, 120)
	await phase("torch in the mountain wind", Vector2(6620, 55), 420)
	await phase("summit fire", Vector2(7410, -288), 120)
	await phase("cave hearth", Vector2(29470, 690), 120)
	printerr("### END")
	get_tree().quit()
