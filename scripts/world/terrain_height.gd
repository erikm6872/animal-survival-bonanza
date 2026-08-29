extends RefCounted
class_name TerrainHeight

## Single source of truth for ground height at any (x, z), so the terrain
## mesh/collision and anything placed on it (trees, props, spawn points)
## all agree without needing to query the generated mesh.

const AMPLITUDE_LARGE: float = 3.5
const AMPLITUDE_DETAIL: float = 0.6
const FREQUENCY_LARGE: float = 0.015
const FREQUENCY_DETAIL: float = 0.08
const NOISE_SEED: int = 20260827

static var _noise_large: FastNoiseLite
static var _noise_detail: FastNoiseLite

static func get_height(x: float, z: float) -> float:
	if _noise_large == null:
		_noise_large = FastNoiseLite.new()
		_noise_large.seed = NOISE_SEED
		_noise_large.frequency = FREQUENCY_LARGE
		_noise_detail = FastNoiseLite.new()
		_noise_detail.seed = NOISE_SEED + 1
		_noise_detail.frequency = FREQUENCY_DETAIL
	return _noise_large.get_noise_2d(x, z) * AMPLITUDE_LARGE \
		+ _noise_detail.get_noise_2d(x, z) * AMPLITUDE_DETAIL
