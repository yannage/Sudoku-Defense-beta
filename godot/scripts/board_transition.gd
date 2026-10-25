extends RefCounted
## Shared timing for native and compatible board transitions.

const DURATION: float = 1.05
const REDUCED_DURATION: float = 0.25

static func advance(progress: float, target: float, dt: float, reduced: bool) -> float:
	return move_toward(progress, target, maxf(0.0, dt) / (REDUCED_DURATION if reduced else DURATION))

static func eased(progress: float) -> float:
	# Quintic easing keeps velocity and acceleration at zero at both ends.
	# The same curve drives orientation, zoom, and palette changes.
	var t: float = clampf(progress, 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
