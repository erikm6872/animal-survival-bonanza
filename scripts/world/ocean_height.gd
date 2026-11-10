extends RefCounted
class_name OceanHeight

## Single source of truth for the ocean biome's seafloor height and water
## surface level, mirroring TerrainHeight's role for the land map. Kept as
## its own class (rather than extending TerrainHeight) since the ocean scene
## has no relationship to the land map's coordinate space or noise seed.

const WATER_LEVEL: float = 0.0
const AMPLITUDE: float = 4.0
const FREQUENCY: float = 0.02
const BASE_DEPTH: float = -18.0 ## average seafloor depth below the water surface
const NOISE_SEED: int = 20261109

## Shallows ringing the edge of the play area, so the floor rises up to meet
## the islands-to-come instead of staying a uniform abyss everywhere.
const SHALLOW_RADIUS_START: float = 60.0
const SHALLOW_RADIUS_END: float = 90.0
const SHALLOW_DEPTH: float = -4.0

static var _noise: FastNoiseLite

static func get_seafloor_height(x: float, z: float) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = NOISE_SEED
		_noise.frequency = FREQUENCY
		_noise.fractal_octaves = 3
	var depth := BASE_DEPTH + _noise.get_noise_2d(x, z) * AMPLITUDE

	var dist := Vector2(x, z).length()
	if dist > SHALLOW_RADIUS_START:
		var t := clampf((dist - SHALLOW_RADIUS_START) / (SHALLOW_RADIUS_END - SHALLOW_RADIUS_START), 0.0, 1.0)
		depth = lerp(depth, SHALLOW_DEPTH, smoothstep(0.0, 1.0, t))

	return depth
