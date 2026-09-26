class_name GameState
extends RefCounted
## What carries from level to level and is kept on disk: shells, upgrades,
## skins, gems and trophies. Everything here is static, so it lives as long as
## the game runs — changing scene or restarting a level doesn't touch it — and
## it is written to user://caveman_save.json whenever something is earned.
##
## Shells are remembered one by one (each has an id in its level), so a shell
## picked up stays picked up: restarting a level can't be used to farm them.

const PATH := "user://caveman_save.json"
const UPGRADE_MAX := {"heart": 2, "torch": 1, "pouch": 1, "club": 1}

static var shells := 0
static var upgrades := {"heart": 0, "torch": 0, "pouch": 0, "club": 0}
static var skins: Array = ["plain"]
static var skin := "plain"
static var gems := {}          ## level id -> "found" | "forged"
static var taken := {}         ## level id -> { treasure id: true }
static var trophies: Array = []
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


static func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"shells": shells, "upgrades": upgrades, "skins": skins, "skin": skin,
		"gems": gems, "taken": taken, "trophies": trophies}))


## A fresh start: everything back to nothing, on disk too.
static func reset() -> void:
	shells = 0
	upgrades = {"heart": 0, "torch": 0, "pouch": 0, "club": 0}
	skins = ["plain"]
	skin = "plain"
	gems = {}
	taken = {}
	trophies = []
	_loaded = true
	save()


static func is_taken(level: String, id: String) -> bool:
	return taken.has(level) and (taken[level] as Dictionary).has(id)


static func take(level: String, id: String, value: int) -> void:
	if not taken.has(level):
		taken[level] = {}
	(taken[level] as Dictionary)[id] = true
	shells += value


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
