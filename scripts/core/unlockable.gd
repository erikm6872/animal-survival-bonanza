extends Resource
class_name Unlockable

## Data-driven shop item, mirroring how AnimalSpecies/EnemySpecies already
## work: a new item is a new .tres in resources/unlockables/, not a code
## change. shop.gd scans that folder at runtime rather than holding a
## hardcoded list, so dropping in a new .tres is enough on its own.
##
## No items exist yet (see docs/GDD.md's Currency & progression section) --
## this is deliberately just the data shape so the Shop UI has something
## real to scan for once content is chosen.

enum Kind { COSMETIC, STAT_UPGRADE, SPECIES }

@export var id: StringName = &""
@export var display_name: String = ""
@export var cost: int = 0
@export var kind: Kind = Kind.COSMETIC
@export var description: String = ""
