extends RefCounted
## Shared number-to-tower foundation assembly. Gameplay commits immediately.
## Retains the resource path for existing projects; there is no seed model.

const DURATION: float = 0.50
const SETTLE_AT: float = 0.36

static func corner_sign(index: int) -> Vector3:
	return Vector3(-1.0 if index % 2 == 0 else 1.0, 1.0, -1.0 if index < 2 else 1.0)

static func corner_offset(age: float, index: int) -> Vector3:
	var sign3: Vector3 = corner_sign(index)
	var progress: float = smoothstep(float(index) * 0.025, SETTLE_AT, age)
	var radius: float = lerpf(0.39, 0.31, progress)
	return Vector3(sign3.x * radius, lerpf(0.13, 0.045, progress), sign3.z * radius)

static func corner_scale(age: float, index: int) -> float:
	return lerpf(0.65, 1.0, smoothstep(float(index) * 0.025, SETTLE_AT, age))

static func corner_blocks(index: int, family: Color) -> Array[Dictionary]:
	# L-shaped mechanical brackets leave the numeral's center completely open.
	# Native meshes and Canvas voxels consume the exact same local geometry.
	var sign3: Vector3 = corner_sign(index)
	return [
		{"offset":Vector3(-0.045 * sign3.x,0,0),"size":Vector3(0.18,0.07,0.085),"color":Color("315056")},
		{"offset":Vector3(0,0,-0.045 * sign3.z),"size":Vector3(0.085,0.07,0.18),"color":Color("315056")},
		{"offset":Vector3(-0.045 * sign3.x,0.043,0),"size":Vector3(0.16,0.018,0.043),"color":family.darkened(0.18)},
		{"offset":Vector3(0,0.043,-0.045 * sign3.z),"size":Vector3(0.043,0.018,0.16),"color":family.darkened(0.18)}
	]

static func number_alpha(_age: float) -> float:
	# The answer is the player's action: never conceal it behind presentation.
	return 1.0

static func number_scale(age: float) -> float:
	return 1.0 + sin(smoothstep(0.0, 0.24, age) * PI) * 0.04

static func impact_scale(age: float) -> float:
	return lerpf(0.70, 0.88, smoothstep(0.0, DURATION, age))

static func impact_alpha(age: float) -> float:
	return 1.0 - smoothstep(0.10, DURATION, age)
