class_name GameState
extends RefCounted
## What carries from level to level and is kept on disk: shells, upgrades,
## skins, gems and trophies. Everything here is static, so it lives as long as
## the game runs — changing scene or restarting a level doesn't touch it — and
## it is written to user://caveman_save.json whenever something is earned.
##
## What he has picked up is remembered one by one while he is in a level (each
## piece has an id), so nothing is counted twice; each new visit to a level
## is a fresh treasure hunt. Weapons: the club always, plus whatever he has
## bought or forged; he carries one. Roast figs: eaten to heal.

const PATH := "user://caveman_save.json"
const UPGRADE_MAX := {"heart": 2, "torch": 1, "pouch": 1, "club": 1}

static var shells := 0
static var upgrades := {"heart": 0, "torch": 0, "pouch": 0, "club": 0}
static var skins: Array = ["plain"]
static var skin := "plain"
static var gems := {}          ## level id -> "found" | "forged"
static var taken := {}         ## level id -> { treasure id: true }
static var trophies: Array = []
static var weapons: Array = ["club"]   ## owned: club, axe, hammer
static var weapon := "club"            ## the one he carries
static var figs := 0                   ## roast figs in his pouch
## Bones: the building material. Plentiful — they come back on every visit —
## and kept for building his shelter in the home level. Shells are the rare
## currency: each is found only once per save.
static var bones := 0
## SPIRIT ORBS: streamed in from every beast he beats (common/spirit_orbs.gd). A currency
## apart from shells (beasts come back each visit), for upgrades.
static var orbs := 0
static var seen := {}                  ## guides already shown, by level
static var abilities: Array = []       ## learned once and kept: "wallkick", "sunfire"
static var equipped: Array = []        ## the two powers he carries (see Abilities.slots)
static var equip_picked := false      ## false: the slots fill themselves with what he unlocks
static var view := ""                  ## the camera: "close", "normal", "wide"; "" = suit the device
static var relics := {}                ## rare finds kept for the shelter: kind -> how many (see Relics)
static var items: Array = []           ## tools he owns for good: "shovel"
static var mysteries := {}             ## id -> "open" | "solved" (see CampMenu.MYSTERIES)
static var bag := {}                   ## stones and things he made: id -> how many (see Bag)
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	shells = int(d.get("shells", 0))
	var up: Dictionary = d.get("upgrades", {})
	for k in upgrades:
		upgrades[k] = int(up.get(k, 0))
	skins = d.get("skins", ["plain"])
	skin = str(d.get("skin", "plain"))
	gems = d.get("gems", {})
	taken = d.get("taken", {})
	trophies = d.get("trophies", [])
	weapons = d.get("weapons", ["club"])
	weapon = str(d.get("weapon", "club"))
	figs = int(d.get("figs", 0))
	bones = int(d.get("bones", 0))
	orbs = int(d.get("orbs", 0))
	seen = d.get("seen", {})
	abilities = d.get("abilities", [])
	equipped = d.get("equipped", [])
	equip_picked = bool(d.get("equip_picked", false))
	view = str(d.get("view", ""))
	relics = d.get("relics", {})
	items = d.get("items", [])
	mysteries = d.get("mysteries", {})
	bag = d.get("bag", {})
	# an older save that forged the Firestone before weapons were kept
	if str(gems.get("level2", "")) == "forged" and not weapons.has("hammer"):
		weapons.append("hammer")
		weapon = "hammer"


static func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"shells": shells, "upgrades": upgrades, "skins": skins, "skin": skin,
		"gems": gems, "taken": taken, "trophies": trophies, "weapons": weapons, "weapon": weapon, "figs": figs, "bones": bones, "orbs": orbs,
		"seen": seen, "abilities": abilities, "equipped": equipped, "equip_picked": equip_picked, "view": view, "relics": relics, "items": items, "mysteries": mysteries, "bag": bag}))


## A fresh start: everything back to nothing, on disk too.
static func reset() -> void:
	shells = 0
	upgrades = {"heart": 0, "torch": 0, "pouch": 0, "club": 0}
	skins = ["plain"]
	skin = "plain"
	gems = {}
	taken = {}
	trophies = []
	weapons = ["club"]
	weapon = "club"
	figs = 0
	bones = 0
	orbs = 0
	seen = {}
	abilities = []
	equipped = []
	equip_picked = false
	relics = {}
	items = []
	mysteries = {}
	bag = {}
	_loaded = true
	save()


## How many roast figs he can carry.
static func fig_max() -> int:
	return 3 + int(upgrades["pouch"])


static func is_taken(level: String, id: String) -> bool:
	return taken.has(level) and (taken[level] as Dictionary).has(id)


static func take(level: String, id: String, value: int) -> void:
	if not taken.has(level):
		taken[level] = {}
	(taken[level] as Dictionary)[id] = value     # its value, so finds can be totted up
	shells += value


## How many shells (by value) have ever been found in a level.
static func found_value(level: String) -> int:
	var total := 0
	for v in (taken.get(level, {}) as Dictionary).values():
		total += int(v)
	return total


static func taken_count(level: String) -> int:
	return (taken[level] as Dictionary).size() if taken.has(level) else 0


## His upgrades and skin, put on him at the start of a level.
static func apply_to(p: CaveMan) -> void:
	ensure_loaded()
	p.max_hp = 5 + int(upgrades["heart"])
	p.hp = p.max_hp
	p.torch_burn = CaveMan.TORCH_BURN * (1.0 + 0.4 * int(upgrades["torch"]))
	var pouch := int(upgrades["pouch"])
	p.max_wood = 4 + pouch
	p.max_rocks = 6 + 2 * pouch
	p.max_berries = 3 + pouch
	p.club_bonus = int(upgrades["club"]) + (1 if items.has("obsidian_edge") else 0)
	p.skin = skin
	p.axe = weapon == "axe"
	p.hammer = weapon == "hammer"


## Learn an ability for good (saved at once). True if it is new.
static func learn(id: String) -> bool:
	if abilities.has(id):
		return false
	abilities.append(id)
	save()
	return true


## He picked his powers in the menu (saved at once).
static func set_equipped(ids: Array) -> void:
	equipped = ids.duplicate()
	equip_picked = true
	save()


## How much of the world the camera shows. On a PC the default pulls back
## (more of the world, like PC players expect); on a touch screen it stays
## close, so he is big enough under a thumb.
const VIEWS := {"close": 1.0, "normal": 0.8, "wide": 0.67}


static func view_name() -> String:
	if VIEWS.has(view):
		return view
	return "close" if DisplayServer.is_touchscreen_available() else "normal"


static func view_zoom() -> float:
	return VIEWS[view_name()]


## Close -> Normal -> Wide -> Close (saved at once).
static func next_view() -> void:
	var order := ["close", "normal", "wide"]
	view = order[(order.find(view_name()) + 1) % order.size()]
	save()


## A rare find, kept for the shelter (saved at once).
static func add_relic(kind: String) -> void:
	relics[kind] = int(relics.get(kind, 0)) + 1
	save()


static func has_item(id: String) -> bool:
	return items.has(id)


## A tool for good (saved at once). True if it is new.
static func give_item(id: String) -> bool:
	if items.has(id):
		return false
	items.append(id)
	save()
	return true


## A mystery he has run into: open until solved (saved at once).
static func open_mystery(id: String) -> void:
	if not mysteries.has(id):
		mysteries[id] = "open"
		save()


static func solve_mystery(id: String) -> void:
	if mysteries.get(id, "") != "solved":
		mysteries[id] = "solved"
		save()


static func mystery(id: String) -> String:
	return str(mysteries.get(id, ""))
