extends RefCounted
## Shared cosmetic timing for a solved square. The run model never waits for it.

const DURATION: float = 0.72
const LAND_AT: float = 0.24
const REVEAL_AT: float = 0.34
const REVEAL_END: float = 0.48

static func seed_offset(age: float) -> Vector3:
	if age < LAND_AT:
		# Brief lift, then an accelerating diagonal plunge. Height alone disappears
		# in the overhead solve camera, so the approach also travels across the tile.
		var windup: float = smoothstep(0.0, 0.06, age)
		var fall: float = pow(clampf((age - 0.06) / (LAND_AT - 0.06), 0.0, 1.0), 2.0)
		return Vector3(-0.30 * (1.0 - fall), lerpf(0.70 + 0.14 * windup, 0.09, fall), -0.40 * (1.0 - fall))
	var bury: float = smoothstep(LAND_AT, REVEAL_AT, age)
	return Vector3(0.0, lerpf(0.09, -0.12, bury), 0.0)

static func seed_scale(age: float) -> float:
	if age >= REVEAL_AT: return 0.0
	if age >= LAND_AT: return lerpf(1.0, 0.0, smoothstep(LAND_AT, REVEAL_AT, age))
	return 0.92 + 0.08 * smoothstep(0.0, 0.06, age)

static func seed_rotation(age: float) -> Vector3:
	var fall: float = smoothstep(0.06, LAND_AT, age)
	# Tilt exposes the walnut's three voxel faces even when viewed straight down.
	return Vector3(lerpf(-0.48, 0.15, fall), lerpf(-0.65, 0.30, fall), lerpf(0.38, -0.12, fall))

static func seed_stretch(age: float) -> Vector3:
	var hit: float = 0.0
	if age >= LAND_AT: hit = 1.0 - smoothstep(LAND_AT, LAND_AT + 0.065, age)
	return Vector3(1.0 + hit * 0.30, 1.0 - hit * 0.42, 1.0 + hit * 0.20)

static func shadow_scale(age: float) -> float:
	return lerpf(0.70, 0.38, smoothstep(0.06, LAND_AT, age)) * (1.0 - smoothstep(LAND_AT, REVEAL_AT, age))

static func socket_scale(age: float) -> float:
	return smoothstep(0.04, 0.18, age) * (1.0 - smoothstep(REVEAL_AT, REVEAL_END, age))

static func soil_offset(age: float, index: int) -> Vector3:
	var flight: float = clampf((age - LAND_AT) / 0.25, 0.0, 1.0)
	var angle: float = float(index) * TAU / 6.0 + 0.35
	var radius: float = lerpf(0.13, 0.36, flight)
	return Vector3(cos(angle) * radius, 0.04 + sin(flight * PI) * (0.17 + float(index % 2) * 0.08), sin(angle) * radius)

static func sprout_scale(age: float) -> float:
	var growth: float = smoothstep(0.30, 0.54, age)
	return growth + sin(growth * PI) * 0.16

static func number_alpha(age: float) -> float:
	return smoothstep(REVEAL_AT, REVEAL_END, age)

static func number_scale(age: float) -> float:
	var reveal: float = smoothstep(REVEAL_AT, REVEAL_END, age)
	return lerpf(0.88, 1.0, reveal) + sin(reveal * PI) * 0.045

static func impact_scale(age: float) -> float:
	return lerpf(0.40, 0.82, smoothstep(LAND_AT, DURATION, age))

static func impact_alpha(age: float) -> float:
	if age < LAND_AT: return 0.0
	return 1.0 - smoothstep(LAND_AT, DURATION, age)

static func soil_scale(age: float) -> float:
	if age < LAND_AT: return 0.0
	return 1.0 - smoothstep(REVEAL_AT, 0.52, age)
