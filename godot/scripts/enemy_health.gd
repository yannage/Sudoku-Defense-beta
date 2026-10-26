extends RefCounted
## One shared health-bar layout: a fixed track with an inset, left-anchored fill.
## Native draws it on one billboard quad; Canvas paints the same rectangle geometry.

const WIDTH := 0.48
const BOSS_WIDTH := 0.66
const HEIGHT := 0.08
const BORDER := 0.015
const TRACK := Color("122630")
const FULL := Color("ffc395")
const LOW := Color("ff7989")

static func ratio(enemy: Dictionary) -> float:
	return clampf(float(enemy.get("hp",1.0))/maxf(1.0,float(enemy.get("max_hp",1.0))),0.0,1.0)

static func size_for(kind: String) -> Vector2:
	return Vector2(BOSS_WIDTH if kind == "boss" else WIDTH,HEIGHT)

static func height_for(kind: String) -> float:
	return 1.06 if kind == "boss" else 0.66

static func color_for(amount: float) -> Color:
	return LOW.lerp(FULL,clampf(amount,0.0,1.0))

static func canvas_rects(center: Vector2, scale_value: float, kind: String, amount: float) -> Dictionary:
	# Snap the whole track once. Fill and border derive from that same rectangle,
	# avoiding independent rounding as the enemy moves or the camera rotates.
	var size := (size_for(kind)*scale_value).round().max(Vector2(8,4))
	var outer := Rect2((center-size*0.5).round(),size)
	var inset := maxf(1.0,roundf(BORDER*scale_value))
	var inner := outer.grow(-inset)
	var fill := Rect2(inner.position,Vector2(roundf(inner.size.x*clampf(amount,0.0,1.0)),inner.size.y))
	return {"track":outer,"inner":inner,"fill":fill}
