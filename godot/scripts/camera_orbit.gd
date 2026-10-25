extends RefCounted
## A manual yaw offset shared by the spatial and Canvas board cameras.
## Targets stay continuous while dragging, so crossing a full turn never snaps.

const BoardTransition = preload("res://scripts/board_transition.gd")
const FOLLOW_RATE: float = 18.0
const RESET_DURATION: float = 0.60
const SETTLED_EPSILON: float = 0.00001
var yaw: float = 0.0
var _target: float = 0.0
var _reset_active: bool = false
var _reset_from: float = 0.0
var _reset_progress: float = 0.0

func rotate(radians: float) -> void:
	if not is_finite(radians) or is_zero_approx(radians): return
	if _reset_active:
		# A new drag takes over exactly where the reset is currently visible.
		_reset_active = false
		_target = yaw
	_target += radians

func reset() -> void:
	# Return by the shortest arc, even after several full revolutions.
	_reset_from = yaw
	_target = yaw + angle_difference(yaw,0.0)
	_reset_progress = 0.0
	_reset_active = true

func clear() -> void:
	yaw = 0.0
	_target = 0.0
	_reset_active = false
	_reset_from = 0.0
	_reset_progress = 0.0

func advance(delta: float, reduced_motion: bool) -> void:
	if reduced_motion:
		yaw = _target
		_reset_active = false
	elif _reset_active:
		# Reset is an automatic camera move: give it a gentle start and stop,
		# rather than the fast response used to follow a player's drag.
		_reset_progress = minf(1.0,_reset_progress+maxf(0.0,delta)/RESET_DURATION)
		yaw = lerpf(_reset_from,_target,BoardTransition.eased(_reset_progress))
		if _reset_progress >= 1.0: _reset_active = false
	elif delta > 0.0:
		yaw = lerpf(yaw,_target,1.0-exp(-FOLLOW_RATE*delta))
	if absf(_target-yaw) < SETTLED_EPSILON: yaw = _target
	# Rebase both values together; preserve pending movement and its direction.
	var turns: float = floor((yaw+PI)/TAU)*TAU
	yaw -= turns
	_target -= turns
	_reset_from -= turns

func is_rotated() -> bool:
	return absf(angle_difference(0.0,yaw)) > 0.001 or absf(angle_difference(0.0,_target)) > 0.001
