extends RefCounted
## Pure previews: never check the hidden solution, spend resources, or advance RNG.

static func route_length(points: Array[Vector2]) -> float:
	var total := 0.0
	for i in range(1,points.size()): total += points[i-1].distance_to(points[i])
	return total

static func route_in_range(points: Array[Vector2], center: Vector2, radius: float) -> float:
	var total := 0.0
	for i in range(1,points.size()):
		var segment: Vector2 = points[i]-points[i-1]
		var length: float = segment.length()
		if length <= 0.0: continue
		var direction: Vector2 = segment/length
		var relative: Vector2 = center-points[i-1]
		var along: float = relative.dot(direction)
		var perpendicular_sq: float = maxf(0.0,relative.length_squared()-along*along)
		if perpendicular_sq >= radius*radius: continue
		var half_span: float = sqrt(radius*radius-perpendicular_sq)
		total += maxf(0.0,minf(length,along+half_span)-maxf(0.0,along-half_span))
	return total

static func placement(run: RefCounted, cell: int, number: int) -> Dictionary:
	if cell < 0 or cell >= 81 or number < 1 or number > 9 or int(run.board[cell]) != 0 or run.phase != "solve": return {}
	var moves: Array[int] = run.recent_moves.duplicate()
	moves.append(cell)
	if moves.size() > 12: moves.pop_front()
	var points: Array[Vector2] = run.route_for_moves(moves)
	var stats: Dictionary = run._stats_for_tower({"number":number,"level":1,"illegal":false,"attachments":[]})
	return {"route":points,"length":route_length(points),"delta":route_length(points)-run.route_length,"damage":float(stats.damage),"range":float(stats.range),"coverage":route_in_range(points,run.cell_position(cell),float(stats.range))}

static func upgrade(run: RefCounted, cell: int) -> Dictionary:
	if not run.towers.has(cell): return {}
	var number: int = int(run.towers[cell].number)
	var total_gain := 0.0
	var count := 0
	for other: int in run.towers:
		if int(run.towers[other].number) != number: continue
		count += 1
		total_gain += float(run.tower_stats(other,1).damage)-float(run.tower_stats(other).damage)
	return {"before":float(run.tower_stats(cell).damage),"after":float(run.tower_stats(cell,1).damage),"count":count,"total_gain":total_gain}

static func defense_summary(run: RefCounted) -> String:
	var uncovered := 0
	for cell: int in run.towers:
		if route_in_range(run.route,run.cell_position(cell),float(run.tower_stats(cell).range)) <= 0.001: uncovered += 1
	var text := "Route: %.1f tiles. %d active towers." % [run.route_length,run.towers.size()]
	if run.towers.is_empty(): text += " Plant some towers before launching."
	elif uncovered > 0: text += " %d cannot reach this route; range modules may help." % uncovered
	else: text += " Every tower can reach part of the route."
	return text

static func result_lines(run: RefCounted) -> Array[String]:
	var report: Dictionary = run.combat_report
	var lines: Array[String] = []
	if not bool(report.complete): lines.append("Partial report: combat tracked since this older save was resumed.")
	lines.append("%d enemies defeated in the run. %.0f damage dealt%s." % [run.kills,float(report.damage)," since resume" if not bool(report.complete) else ""])
	var leaks: Array[String] = []
	for kind: String in run.ENEMY_KINDS:
		var count: int = int(report.leaks.get(kind,0))
		if count > 0: leaks.append("%d %s (%d core)" % [count,kind,count*run._core_damage(kind)])
	lines.append("Core hits: " + ("none recorded." if leaks.is_empty() else ", ".join(leaks)+"."))
	var ranked: Array = report.towers.values().duplicate(true)
	ranked.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if float(a.damage) != float(b.damage): return float(a.damage) > float(b.damage)
		if int(a.round) != int(b.round): return int(a.round) < int(b.round)
		return int(a.cell) < int(b.cell))
	if not ranked.is_empty():
		var best: Dictionary = ranked[0]
		lines.append("Top damage: number %d at row %d, column %d (round %d): %.0f damage, %d kills." % [int(best.number),int(best.cell)/9+1,int(best.cell)%9+1,int(best.round),float(best.damage),int(best.kills)])
		lines.append("Damage measures attacks; slowing and pushing enemies also help your defense.")
	if run.phase == "lost":
		if int(report.leaks.get("runner",0)) > 0: lines.append("Try next: cover the exit with First targeting and frost to catch runners.")
		elif int(report.leaks.get("boss",0))+int(report.leaks.get("tank",0)) > 0: lines.append("Try next: concentrate upgrades and Strongest targeting against heavy enemies.")
		else: lines.append("Try next: check route coverage and fit your starter modules before launching.")
	return lines
