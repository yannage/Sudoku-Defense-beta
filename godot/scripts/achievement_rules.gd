extends RefCounted

const Facts = preload("res://scripts/achievement_facts.gd")

# Award conditions run at the successful gameplay action in DefenseRun. This
# evaluator only exposes durable evidence; it never infers feats from phase,
# recovered health, current equipment, or transient presentation events.
static func evaluate(run: RefCounted) -> Array[String]:
	var result: Array[String] = []
	var stats: Dictionary = run.achievement_stats
	if str(stats.get("run_id", "")).is_empty(): return result
	for key: String in Facts.IDS:
		if stats.earned.get(key,false) == true: result.append(key)
	return result
