extends RefCounted
class_name TerrainHeight

## Single source of truth for ground height at any (x, z), so the terrain
## mesh/collision and anything placed on it (trees, props, spawn points)
## all agree without needing to query the generated mesh. Also the single
## source of truth for where the river/ponds are, so water_generator.gd's
## visible water always lines up with the basins carved in here.

const AMPLITUDE_LARGE: float = 5.5
const AMPLITUDE_DETAIL: float = 0.6
const FREQUENCY_LARGE: float = 0.015
const FREQUENCY_DETAIL: float = 0.08
const NOISE_SEED: int = 20260827

# Mountains: a ring of rising, ridged terrain surrounding the playable area
# (which stays untouched inside MOUNTAIN_START_RADIUS), so the map reads as
# a valley rather than terrain that just stops.
const MOUNTAIN_START_RADIUS: float = 130.0
const MOUNTAIN_END_RADIUS: float = 200.0
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
const WATERFALL_X: float = 160.0
const WATERFALL_DROP_HEIGHT: float = 14.0
const RIVER_SOURCE_WATER_LEVEL: float = RIVER_WATER_LEVEL + WATERFALL_DROP_HEIGHT

# Ponds: center (x, z), radius, and water surface height.
const PONDS: Array[Dictionary] = [
	{"center": Vector2(-40, -30), "radius": 12.0, "water_level": -1.0},
	{"center": Vector2(55, -40), "radius": 9.0, "water_level": -0.8},
]
const POND_BED_DEPTH: float = 1.2 ## how far below the water surface the carved bed sits

# Clearings: a low-frequency noise field thresholded into open-field blobs,
# sprinkled through the forest so biome_populator.gd's scatter has somewhere
# to leave bare -- otherwise a denser forest reads as wall-to-wall trees
# with nowhere to see or move freely.
const CLEARING_FREQUENCY: float = 0.012
const CLEARING_THRESHOLD: float = 0.35 ## higher = less of the map counts as a clearing

# Spawn cave: a ring-shaped mound around the origin (where the player
# spawns/respawns -- see scenes/world/spawn_cave.tscn) that reads as a
# hillside behind/around the cave's stone facade, rising up from flat,
# unbumped ground at CAVE_HOLLOW_RADIUS (where spawn_cave.gd's room sits) and
# tapering back down to ordinary terrain by CAVE_MOUND_RADIUS. The ring must
# stay wide relative to terrain_generator.gd's 2m mesh grid -- too narrow
# (originally 3.3m, under 2 grid cells) and the *mesh*, which only samples
# this smooth function every 2m and triangulates a straight line between
# samples, renders it as a visibly steep ramp right outside the entrance
# rather than the gentle slope the underlying math describes.
const CAVE_MOUND_RADIUS: float = 16.0
const CAVE_HOLLOW_RADIUS: float = 7.2
const CAVE_MOUND_HEIGHT: float = 4.5

static var _noise_large: FastNoiseLite
static var _noise_detail: FastNoiseLite
static var _noise_mountain: FastNoiseLite
static var _noise_clearing: FastNoiseLite

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
	base = _apply_cave(x, z, base)
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

## Flattens `natural` (the rolling-hills noise + mountain height computed so
## far) to a single constant height everywhere inside CAVE_HOLLOW_RADIUS --
## spawn_cave.gd's room is built flat, at a fixed height, and the natural
## noise is not otherwise zero there, so without this the floor/walls
## would sit at the wrong height (gaps or clipping) everywhere except the
## one point (the origin) the room was measured from. Blends smoothly back
## to the untouched natural terrain by CAVE_MOUND_RADIUS, with an added rise
## in between so it reads as a hill around the cave rather than a flat disc
## with a ring of bare dirt.
static func _apply_cave(x: float, z: float, natural: float) -> float:
	var dist := Vector2(x, z).length()
	if dist >= CAVE_MOUND_RADIUS:
		return natural
	var flat := _cave_flat_height()
	if dist <= CAVE_HOLLOW_RADIUS:
		return flat
	var t := clampf((dist - CAVE_HOLLOW_RADIUS) / (CAVE_MOUND_RADIUS - CAVE_HOLLOW_RADIUS), 0.0, 1.0)
	var blended := lerpf(flat, natural, smoothstep(0.0, 1.0, t))
	return blended + CAVE_MOUND_HEIGHT * sin(t * PI)

static var _cave_flat_height_cached: bool = false
static var _cave_flat_height_cache: float = 0.0

## The natural (noise + mountain) height at the world origin -- computed
## directly rather than through get_height()/​_apply_cave() itself, to avoid
## recursing into this same flattening logic.
static func _cave_flat_height() -> float:
	if not _cave_flat_height_cached:
		var h := _noise_large.get_noise_2d(0.0, 0.0) * AMPLITUDE_LARGE \
			+ _noise_detail.get_noise_2d(0.0, 0.0) * AMPLITUDE_DETAIL
		h += _mountain_height(0.0, 0.0)
		_cave_flat_height_cache = h
		_cave_flat_height_cached = true
	return _cave_flat_height_cache

## True inside a sprinkled-open-field blob -- used by biome_populator.gd to
## leave clearings bare rather than scattering vegetation uniformly
## everywhere. Called independently of get_height() (e.g. before any height
## has been sampled yet), so it lazily inits its own noise field too.
static func is_clearing(x: float, z: float) -> bool:
	if _noise_clearing == null:
		_noise_clearing = FastNoiseLite.new()
		_noise_clearing.seed = NOISE_SEED + 3
		_noise_clearing.frequency = CLEARING_FREQUENCY
	return _noise_clearing.get_noise_2d(x, z) > CLEARING_THRESHOLD

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
