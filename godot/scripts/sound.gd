class_name DefenseSound
extends Node
## Original, softly mixed garden-tech sounds. No external music or audio middleware.
## Add this node to the tree; play_event(), click() and set_muted() are the public API.

const AUDIO_ROOT: String = "res://assets/audio/"
const VOICE_COUNT: int = 14
const SHOT_INTERVAL: float = 0.075
const KILL_INTERVAL: float = 0.055
const CLIPS: Array[String] = ["click", "plant", "illegal", "shot", "electric", "frost", "blast", "kill", "leak", "phase", "loot", "equip", "upgrade", "chest", "chest_rare", "victory", "error", "garden_loop"]

var muted: bool = false
var music_enabled: bool = true
var master_volume: float = 0.85
var _clips: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _initialized: bool = false
var _headless: bool = false
var _has_interaction: bool = false
var _voice_cursor: int = 0
var _last_shot: float = -100.0
var _last_kill: float = -100.0
var _last_hit: float = -100.0

func _ready() -> void:
	setup()

func setup() -> void:
	if _initialized:
		return
	_initialized = true
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		return
	for clip_name: String in CLIPS:
		var path: String = AUDIO_ROOT + clip_name + ".wav"
		if ResourceLoader.exists(path):
			_clips[clip_name] = load(path)
	for i: int in VOICE_COUNT:
		var voice := AudioStreamPlayer.new()
		voice.name = "EffectVoice%02d" % i
		add_child(voice)
		_voices.append(voice)
	_music = AudioStreamPlayer.new()
	_music.name = "GardenAmbience"
	_music.volume_db = -18.0
	add_child(_music)
	if _clips.has("garden_loop"):
		var loop_stream: AudioStreamWAV = (_clips["garden_loop"] as AudioStreamWAV).duplicate() as AudioStreamWAV
		loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop_stream.loop_begin = 0
		loop_stream.loop_end = int(loop_stream.get_length() * float(loop_stream.mix_rate))
		_music.stream = loop_stream

func click() -> void:
	_begin_interaction()
	_play("click", -9.0)

func set_muted(value: bool) -> void:
	muted = value
	if not _initialized:
		setup()
	if _headless:
		return
	for voice: AudioStreamPlayer in _voices:
		if muted:
			voice.stop()
	if is_instance_valid(_music):
		_music.stream_paused = muted or not music_enabled
		if not muted and music_enabled and _has_interaction and not _music.playing:
			_music.play()

func set_music_enabled(value: bool) -> void:
	music_enabled = value
	if is_instance_valid(_music):
		_music.stream_paused = muted or not music_enabled
		if value and not muted and _has_interaction and not _music.playing:
			_music.play()

func set_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	if is_instance_valid(_music):
		_music.volume_db = -18.0 + linear_to_db(maxf(master_volume, 0.001))

func play_event(event: Dictionary) -> void:
	if not _initialized:
		setup()
	if muted or _headless:
		return
	var event_type: String = str(event.get("type", ""))
	var now: float = Time.get_ticks_msec() * 0.001
	match event_type:
		"plant", "seed":
			_begin_interaction()
			var number: int = int(event.get("number", 1))
			var pitch: float = pow(2.0, float([0, 2, 4, 7, 9][posmod(number - 1, 5)]) / 24.0)
			_play("illegal" if bool(event.get("illegal", false)) else "plant", -3.0, pitch)
		"shot":
			if now - _last_shot < SHOT_INTERVAL:
				return
			_last_shot = now
			var kind: String = str(event.get("kind", ""))
			var clip_name: String = kind if kind in ["electric", "frost", "blast"] else "shot"
			_play(clip_name, -10.0, 0.94 + float(posmod(int(event.get("cell", 0)), 5)) * 0.035, false)
		"kill":
			if now - _last_kill < KILL_INTERVAL:
				return
			_last_kill = now
			_play("kill", -7.5, 0.96 + float(posmod(int(event.get("cell", 0)), 4)) * 0.05, false)
		"hit":
			# Shot + crystal collect carry combat; hit spam deliberately stays quiet.
			if str(event.get("kind", "")) == "blast" and now - _last_hit > 0.22:
				_last_hit = now
				_play("blast", -12.0, 0.9, false)
		"leak":
			_play("leak", -4.0)
		"phase":
			var phase: String = str(event.get("phase", event.get("text", ""))).to_lower()
			_play("victory" if phase == "won" else "loot" if phase == "loot" else "phase", -4.5)
		"loot", "chest_drop", "chestDrop":
			_play("loot", -7.0)
		"chest_open", "chestOpen":
			_begin_interaction()
			var rarity: String = str(event.get("rarity", "common"))
			_play("chest_rare" if rarity in ["rare", "epic", "legendary"] else "chest", -2.0)
		"upgrade":
			_begin_interaction()
			_play("upgrade", -4.0)
		"equip", "unequip":
			_begin_interaction()
			_play("equip", -3.0)
		"item_used", "itemUsed", "consumable":
			_begin_interaction()
			_play("upgrade", -5.0, 1.12)
		"error", "invalid":
			_play("error", -6.0)
		"win", "won":
			_play("victory", -2.5)

func _begin_interaction() -> void:
	if not _initialized:
		setup()
	_has_interaction = true
	if _headless or muted or not music_enabled:
		return
	if is_instance_valid(_music) and _music.stream != null and not _music.playing:
		_music.volume_db = -18.0 + linear_to_db(maxf(master_volume, 0.001))
		_music.play()

func _play(clip_name: String, gain_db: float = -6.0, pitch: float = 1.0, important: bool = true) -> void:
	if muted or _headless or not _clips.has(clip_name) or _voices.is_empty():
		return
	var chosen: AudioStreamPlayer = null
	for offset: int in _voices.size():
		var candidate: AudioStreamPlayer = _voices[(_voice_cursor + offset) % _voices.size()]
		if not candidate.playing:
			chosen = candidate
			_voice_cursor = (_voice_cursor + offset + 1) % _voices.size()
			break
	if chosen == null:
		if not important:
			return
		chosen = _voices[_voice_cursor]
		_voice_cursor = (_voice_cursor + 1) % _voices.size()
	chosen.stop()
	chosen.stream = _clips[clip_name] as AudioStream
	chosen.volume_db = gain_db + linear_to_db(maxf(master_volume, 0.001))
	chosen.pitch_scale = pitch
	chosen.play()
