extends Node
## Test harness (not shipped): shrinks the downloaded CC0 textures into common/art.
## (The sources live in the scratchpad. See common/art/CREDITS.md.)
func _ready() -> void:
	var src := Image.load_from_file("C:/Users/wadah/AppData/Local/Temp/claude/C--Users-wadah-Downloads-caveman-chronicles-full/4934baf1-e2b9-40be-b7ad-8a6a7abdc964/scratchpad/assets/fur_tc/fabrics_0037_color_1k.jpg")
	src.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	src.save_png(ProjectSettings.globalize_path("res://common/art/fur.png"))
	# a grey wolf's coat: the same fur, the colour taken out, a touch lighter
	var grey := src.duplicate() as Image
	for y in grey.get_height():
		for x in grey.get_width():
			var c := grey.get_pixel(x, y)
			var l := c.get_luminance()
			grey.set_pixel(x, y, Color(l, l * 0.98, l * 0.96).lightened(0.18))
	grey.save_png(ProjectSettings.globalize_path("res://common/art/fur_grey.png"))
	print("fur done")
	get_tree().quit()
