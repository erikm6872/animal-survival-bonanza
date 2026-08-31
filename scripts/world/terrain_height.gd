extends RefCounted
class_name TerrainHeight

## Single source of truth for ground height at any (x, z), so the terrain
## mesh/collision and anything placed on it (trees, props, spawn points)
## all agree without needing to query the generated mesh. Also the single
## source of truth for where the river/ponds are, so water_generator.gd's
## visible water always lines up with the basins carved in here.

const AMPLITUDE_LARGE: float = 3.5
const AMPLITUDE_DETAIL: float = 0.6
const FREQUENCY_LARGE: float = 0.015
const FREQUENCY_DETAIL: float = 0.08
const NOISE_SEED: int = 20260827

# Mountains: a ring of rising, ridged terrain surrounding the playable area
# (which stays untouched inside MOUNTAIN_START_RADIUS), so the map reads as
# a valley rather than terrain that just stops.
const MOUNTAIN_START_RADIUS: float = 65.0
const MOUNTAIN_END_RADIUS: float = 100.0
const MOUNTAIN_MAX_HEIGHT: float = 45.0
const MOUNTAIN_NOISE_FREQUENCY: float = 0.025

# River: a gentle meander across the full width of the map.
const RIVER_CENTER_Z: float = 35.0
const RIVER_MEANDER_AMPLITUDE: float = 15.0
const RIVER_MEANDER_FREQUENCY: float = 0.02
const RIVER_HALF_WIDTH: float = 5.0
const RIVER_BANK_WIDTH: float = 10.0
const RIVER_WATER_LEVEL: float = -1.2
const RIVER_BED_DEPTH: float = 1.0 ## how far below the water surface the carved bed sits

# Waterfall: past this x, the river is a higher, separate "source" stretch
# coming down out of the mountains — the step between the two water levels
# is the falls. water_generator.gd builds the two flat river ribbons plus a
# vertical drop mesh bridging them at WATERFALL_X.
const WATERFALL_X: float = 80.0
const WATERFALL_DROP_HEIGHT: float = 14.0
const RIVER_SOURCE_WATER_LEVEL: float = RIVER_WATER_LEVEL + WATERFALL_DROP_HEIGHT

# Ponds: center (x, z), radius, and water surface height.
const PONDS: Array[Dictionary] = [
	{"center": Vector2(-40, -30), "radius": 12.0, "water_level": -1.0},
	{"center": Vector2(55, -40), "radius": 9.0, "water_level": -0.8},
]
const POND_BED_DEPTH: float = 1.2 ## how far below the water surface the carved bed sits

static var _noise_large: FastNoiseLite
static var _noise_detail: FastNoiseLite
static var _noise_mountain: FastNoiseLite

static func get_height(x: float, z: float) -> float:
	if _noise_large == null:
		_noise_large = FastNoiseLite.new()
		_noise_large.seed = NOISE_SEED
		_noise_large.frequency = FREQUENCY_LARGE
		_noise_detail = FastNoiseLite.new()
		_noise_detail.seed = NOISE_SEED + 1
		_noise_detail.frequency = FREQUENCY_DETAIL
		_noise_mountain = FastNoiseLite.new()
		_noise_mountain.seed = NOISE_SEED + 2
		_noise_mountain.frequency = MOUNTAIN_NOISE_FREQUENCY
		_noise_mountain.fractal_octaves = 4
	var base := _noise_large.get_noise_2d(x, z) * AMPLITUDE_LARGE \
		+ _noise_detail.get_noise_2d(x, z) * AMPLITUDE_DETAIL
	base += _mountain_height(x, z)
	return _carve_water(x, z, base)

## Ridged noise (1 - abs(noise)) ramped in by radial distance from the map
## center, so the playable area stays untouched and only the outer ring
## rises into jagged peaks.
static func _mountain_height(x: float, z: float) -> float:
	var dist := Vector2(x, z).length()
	if dist < MOUNTAIN_START_RADIUS:
		return 0.0
	var t := clampf((dist - MOUNTAIN_START_RADIUS) / (MOUNTAIN_END_RADIUS - MOUNTAIN_START_RADIUS), 0.0, 1.0)
	var envelope := smoothstep(0.0, 1.0, t)
	var ridge := 1.0 - absf(_noise_mountain.get_noise_2d(x, z))
	return envelope * MOUNTAIN_MAX_HEIGHT * ridge

static func river_center_z(x: float) -> float:
	return RIVER_CENTER_Z + RIVER_MEANDER_AMPLITUDE * sin(x * RIVER_MEANDER_FREQUENCY)

## True inside the river channel or a pond (not counting their sloped banks) —
## used to keep trees/bushes from being scattered into the water.
static func is_water(x: float, z: float) -> bool:
	if absf(z - river_center_z(x)) < RIVER_HALF_WIDTH:
		return true
	for pond in PONDS:
		var center: Vector2 = pond["center"]
		var radius: float = pond["radius"]
		if Vector2(x, z).distance_to(center) < radius:
			return true
	return false

## Carves basins below `base` near the river/ponds, blending smoothly back up
## to the untouched height at the edge of each bank so there's a real shore
## instead of a cliff. Only ever lowers terrain, never raises it.
static func _carve_water(x: float, z: float, base: float) -> float:
	var height := base

	var river_dist := absf(z - river_center_z(x))
	if river_dist < RIVER_HALF_WIDTH + RIVER_BANK_WIDTH:
		var t := clampf((river_dist - RIVER_HALF_WIDTH) / RIVER_BANK_WIDTH, 0.0, 1.0)
		var water_lvl := RIVER_SOURCE_WATER_LEVEL if x >= WATERFALL_X else RIVER_WATER_LEVEL
		var bed := water_lvl - RIVER_BED_DEPTH
		height = minf(height, lerp(bed, base, smoothstep(0.0, 1.0, t)))

	for pond in PONDS:
		var center: Vector2 = pond["center"]
		var radius: float = pond["radius"]
		var water_level: float = pond["water_level"]
		var bank_width := radius * 0.5 + 4.0
		var d := Vector2(x, z).distance_to(center)
		if d < radius + bank_width:
			var t := clampf((d - radius) / bank_width, 0.0, 1.0)
			var bed := water_level - POND_BED_DEPTH
			height = minf(height, lerp(bed, base, smoothstep(0.0, 1.0, t)))

	return height
