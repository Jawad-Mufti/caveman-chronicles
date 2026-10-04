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
static var seen := {}                  ## guides already shown, by level
static var abilities: Array = []       ## learned once and kept: "wallkick", "sunfire"
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
	seen = d.get("seen", {})
	abilities = d.get("abilities", [])
	# an older save that forged the Firestone before weapons were kept
	if str(gems.get("level2", "")) == "forged" and not weapons.has("hammer"):
		weapons.append("hammer")
		weapon = "hammer"


static func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"shells": shells, "upgrades": upgrades, "skins": skins, "skin": skin,
		"gems": gems, "taken": taken, "trophies": trophies, "weapons": weapons, "weapon": weapon, "figs": figs, "bones": bones,
		"seen": seen, "abilities": abilities}))


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
	seen = {}
	abilities = []
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
	p.club_bonus = int(upgrades["club"])
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
