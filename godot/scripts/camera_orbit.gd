extends RefCounted
## A manual yaw offset shared by the spatial and Canvas board cameras.
## Targets stay continuous while dragging, so crossing a full turn never snaps.

const FOLLOW_RATE: float = 18.0
const SETTLED_EPSILON: float = 0.00001
var yaw: float = 0.0
var _target: float = 0.0

func rotate(radians: float) -> void:
	if is_finite(radians): _target += radians

func reset() -> void:
	# Return by the shortest arc, even after several full revolutions.
	_target = yaw + angle_difference(yaw,0.0)

func clear() -> void:
	yaw = 0.0
	_target = 0.0

func advance(delta: float, reduced_motion: bool) -> void:
	if reduced_motion:
		yaw = _target
	elif delta > 0.0:
		yaw = lerpf(yaw,_target,1.0-exp(-FOLLOW_RATE*delta))
	if absf(_target-yaw) < SETTLED_EPSILON: yaw = _target
	# Rebase both values together; preserve pending movement and its direction.
	var turns: float = floor((yaw+PI)/TAU)*TAU
	yaw -= turns
	_target -= turns

func is_rotated() -> bool:
	return absf(angle_difference(0.0,yaw)) > 0.001 or absf(angle_difference(0.0,_target)) > 0.001
