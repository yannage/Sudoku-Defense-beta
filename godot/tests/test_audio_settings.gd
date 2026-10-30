extends SceneTree
## UI uses a unique settings file and never starts or saves a player run.
const Preferences = preload("res://scripts/preferences.gd")
const Sound = preload("res://scripts/sound.gd")
var checks := 0
var failures := 0
var settings_path := "user://audio-regression-%d.json" % Time.get_ticks_usec()
var scene

func _initialize() -> void:
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 3) -> void:
	for i in count: await process_frame

func press(index: int) -> void:
	for down in [true,false]:
		var event := InputEventJoypadButton.new()
		event.device = 42
		event.button_index = index
		event.pressed = down
		Input.parse_input_event(event)
		await frames()

func control(id: String) -> Button:
	for item in scene.overlay.find_children("*","Button",true,false):
		if item.get_meta("focus_id","") == id: return item
	return null

func launch():
	var instance = load("res://scenes/main.tscn").instantiate()
	instance.preferences.file_path = settings_path
	root.add_child(instance)
	return instance

func exercise() -> void:
	var store = Preferences.new()
	store.file_path = settings_path
	for size in [Vector2i(1280,800),Vector2i(600,1066)]:
		root.size = size
		check(store.write_settings(Preferences.DEFAULTS),"Prepare isolated audio settings")
		scene = launch()
		await frames(5)
		scene._show_audio_settings()
		await frames(5)
		check(root.gui_get_focus_owner() == control("audio:master:lower"),"Audio opens with controller focus on master volume")
		await press(JOY_BUTTON_A)
		check(is_equal_approx(scene.master_volume,0.80) and is_equal_approx(scene.sound.master_volume,0.80),"A lowers master volume once and applies it immediately")
		check(root.gui_get_focus_owner() == control("audio:master:lower"),"Repeated adjustment keeps focus on the same control")
		await press(JOY_BUTTON_DPAD_RIGHT)
		check(root.gui_get_focus_owner() == control("audio:master:higher"),"D-pad moves across the volume row")
		await press(JOY_BUTTON_A)
		check(is_equal_approx(scene.master_volume,0.85),"A raises volume without affecting another channel")
		await press(JOY_BUTTON_DPAD_DOWN)
		check(root.gui_get_focus_owner() == control("audio:music:higher"),"D-pad down reaches the next channel")
		await press(JOY_BUTTON_DPAD_LEFT)
		check(root.gui_get_focus_owner() == control("audio:music:lower"),"D-pad left reaches the next channel's lower control")
		await press(JOY_BUTTON_A)
		check(is_equal_approx(scene.music_volume,0.95) and is_equal_approx(scene.sound.music_volume,0.95),"Music adjustment reaches the mixer")
		await press(JOY_BUTTON_DPAD_DOWN)
		check(root.gui_get_focus_owner() == control("audio:effects:lower"),"D-pad down reaches effects without skipping a row")
		await press(JOY_BUTTON_A)
		check(is_equal_approx(scene.effects_volume,0.95) and is_equal_approx(scene.sound.effects_volume,0.95),"Effects adjustment reaches the mixer")
		scene._set_audio_level("effects",0.0)
		control("audio:effects:lower").grab_focus()
		await press(JOY_BUTTON_A)
		check(scene.effects_volume == 0.0 and root.gui_get_focus_owner() == control("audio:effects:lower"),"Lower bound clamps without losing focus")
		scene._set_audio_level("master",1.0)
		control("audio:master:higher").grab_focus()
		await press(JOY_BUTTON_A)
		check(scene.master_volume == 1.0,"Upper bound clamps to 100 percent")
		control("audio:mute").grab_focus()
		await press(JOY_BUTTON_A)
		check(scene.muted and control("audio:mute").text == "Sound: OFF","Mute feedback updates without rebuilding the menu")
		check(store.read_settings().muted and is_equal_approx(store.read_settings().music_volume,0.95) and store.read_settings().effects_volume == 0.0,"Volume and mute persist together immediately")
		for scroll in scene.overlay.find_children("*","ScrollContainer",true,false):
			var bounds: Rect2 = scroll.get_global_rect()
			for child in scroll.find_children("*","Control",true,false):
				if not child.is_visible_in_tree(): continue
				var rect: Rect2 = child.get_global_rect()
				check(rect.position.x >= bounds.position.x-2 and rect.end.x <= bounds.end.x+2,"Audio controls fit horizontally at " + str(size)+" "+str(child)+" "+str(rect)+" within "+str(bounds))
		control("audio:done").grab_focus()
		await frames(5)
		var done: Button = control("audio:done")
		check(root.get_visible_rect().encloses(done.get_global_rect()),"Controller focus scrolls Done into view")
		await press(JOY_BUTTON_B)
		check(scene.menu_open and not scene.overlay.get_meta("audio_settings",false),"B exits audio settings to setup when no run is active")
		check(not scene.has_active_run,"Settings never start or mutate a run")
		scene.queue_free()
		await frames()
		scene = launch()
		await frames()
		check(scene.muted and scene.sound.muted and scene.master_volume == 1.0 and is_equal_approx(scene.music_volume,0.95) and scene.effects_volume == 0.0,"Fresh scene restores all audio controls")
		check(scene.sound.master_volume == 1.0 and is_equal_approx(scene.sound.music_volume,0.95) and scene.sound.effects_volume == 0.0,"Fresh scene applies the stored mix before input")
		scene.queue_free()
		await frames()
	await exercise_mixer()
	DirAccess.remove_absolute(settings_path)
	DirAccess.remove_absolute(settings_path + ".tmp")
	print("AUDIO_SETTINGS_PASS %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)

func exercise_mixer() -> void:
	# Inject actual AudioStreamPlayers so headless checks still exercise live gain,
	# pause, stop, and zero-volume guards without playing through a real device.
	var sound = Sound.new()
	sound._initialized = true
	sound._headless = false
	root.add_child(sound)
	var clip := AudioStreamWAV.new()
	clip.mix_rate = 8000
	var silence := PackedByteArray()
	silence.resize(8000)
	clip.data = silence
	var voice := AudioStreamPlayer.new()
	sound.add_child(voice)
	sound._voices.append(voice)
	sound._clips["click"] = clip
	sound._music = AudioStreamPlayer.new()
	sound.add_child(sound._music)
	sound._music.stream = clip
	sound.set_volume(0.5)
	sound.set_effects_volume(0.5)
	sound.click()
	check(voice.playing and is_equal_approx(voice.volume_db,-9.0+linear_to_db(0.25)),"Effects combine master and channel gain")
	sound.set_effects_volume(0.25)
	check(is_equal_approx(voice.volume_db,-9.0+linear_to_db(0.125)),"Already playing effect updates to the new mix")
	sound.set_effects_volume(0.0)
	check(not voice.playing,"Zero effects level stops a currently playing voice")
	sound.click()
	check(not voice.playing,"Zero effects level prevents new effects")
	sound.set_music_volume(0.0)
	check(sound._music.stream_paused,"Zero music level pauses ambience")
	sound.set_music_volume(0.5)
	check(not sound._music.stream_paused and is_equal_approx(sound._music.volume_db,-18.0+linear_to_db(0.25)),"Music resumes at the combined saved levels")
	sound.set_volume(0.0)
	check(sound._music.stream_paused,"Zero master level silences music")
	sound.set_muted(true)
	sound.set_volume(0.7)
	check(sound._music.stream_paused and sound.effects_volume == 0.0 and sound.music_volume == 0.5,"Changing volume while muted preserves silence and channel choices")
	sound.set_muted(false)
	check(not sound._music.stream_paused,"Unmute restores music without changing channel levels")
	voice.stop()
	voice.stream = null
	sound._music.stop()
	sound._music.stream = null
	sound._clips.clear()
	# Let the dummy audio thread release its playback handles before quitting.
	await create_timer(0.1).timeout
	sound.queue_free()
	await frames()
