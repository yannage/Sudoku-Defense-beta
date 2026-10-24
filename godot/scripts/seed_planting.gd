extends RefCounted
## Shared cosmetic timing for a solved square. The run model never waits for it.

const DURATION: float = 0.64
const LAND_AT: float = 0.24
const REVEAL_AT: float = 0.32
const REVEAL_END: float = 0.48

static func seed_offset(age: float) -> Vector3:
	var fall: float = clampf(age / LAND_AT, 0.0, 1.0)
	if age < LAND_AT:
		# The small lateral approach remains visible from the solve camera above.
		return Vector3(-0.25 * (1.0 - fall), lerpf(0.70, 0.045, fall) + sin(fall * PI) * 0.18, -0.34 * (1.0 - fall))
	var bury: float = smoothstep(LAND_AT, REVEAL_AT, age)
	return Vector3(0.0, lerpf(0.045, -0.12, bury), 0.0)

static func seed_scale(age: float) -> float:
	if age >= REVEAL_AT: return 0.0
	if age >= LAND_AT: return lerpf(1.0, 0.0, smoothstep(LAND_AT, REVEAL_AT, age))
	return 0.90 + 0.10 * smoothstep(0.0, LAND_AT, age)

static func number_alpha(age: float) -> float:
	return smoothstep(REVEAL_AT, REVEAL_END, age)

static func number_scale(age: float) -> float:
	var reveal: float = smoothstep(REVEAL_AT, REVEAL_END, age)
	return lerpf(0.88, 1.0, reveal) + sin(reveal * PI) * 0.045

static func impact_scale(age: float) -> float:
	return lerpf(0.28, 0.74, smoothstep(LAND_AT, DURATION, age))

static func impact_alpha(age: float) -> float:
	if age < LAND_AT: return 0.0
	return 1.0 - smoothstep(LAND_AT, DURATION, age)

static func soil_scale(age: float) -> float:
	if age < LAND_AT: return 0.0
	return 1.0 - smoothstep(REVEAL_AT, REVEAL_END, age)
