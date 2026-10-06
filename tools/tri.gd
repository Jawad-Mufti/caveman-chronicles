extends Node2D
## Test harness (not shipped): which costume or icon draws a bad shape?
var which := ""
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		which = a
	if which.begins_with("skin:"):
		var m := CaveMan.new()
		m.preview = true
		m.skin = which.substr(5)
		m.position = Vector2(400, 400)
		m.scale = Vector2(2, 2)
		add_child(m)
	else:
		queue_redraw()
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
func _draw() -> void:
	if which.begins_with("icon:"):
		Shop.draw_icon(self, which.substr(5), Vector2(300, 300), 1.0)
		Shop.draw_icon(self, which.substr(5), Vector2(300, 300), 0.55)
		Shop.draw_icon(self, which.substr(5), Vector2(300, 300), 0.7)
