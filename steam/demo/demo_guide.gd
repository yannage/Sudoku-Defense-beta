extends "res://scripts/first_round_guide.gd"

func start(game) -> void:
	super.start(game)
	host.run.max_rounds = 1
	host.run.mode = "freeplay"

func finish() -> void:
	if not active: return
	var finished := step in [7,8]
	var defended := step == 7
	var final_score: int = host.run.score
	restore()
	if finished:
		host._show_demo_end(defended,final_score)
	else:
		host._show_menu(true)
