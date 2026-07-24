extends Node

# 全局音效管理器。
# 一次性音效使用播放器池；环境音、脚步、打字机使用专用循环播放器。
# 静音状态跟随 OpeningMusic 的音频设置。

const STREAMS := {
	"ui_click": preload("res://assets/audio/sfx/ui_click.wav"),
	"ui_hover": preload("res://assets/audio/sfx/ui_hover.wav"),
	"ui_switch": preload("res://assets/audio/sfx/ui_switch.wav"),
	"stamp": preload("res://assets/audio/sfx/item_stamp.wav"),
	"door": preload("res://assets/audio/sfx/item_door.wav"),
	"bling": preload("res://assets/audio/sfx/special_bling.wav"),
	"start": preload("res://assets/audio/sfx/special_start.wav"),
	"call_bell": preload("res://assets/audio/sfx/external/call_bell_cc0.wav"),
	"call_intercom": preload("res://assets/audio/sfx/external/call_intercom_noise.wav"),
}

# 各音效的默认音量（分贝），未列出的按 0 dB 播放。
const DEFAULT_VOLUME_DB := {
	"ui_click": -8.0,
	"ui_hover": -20.0,
	"ui_switch": -8.0,
	"stamp": -4.0,
	"door": -8.0,
	"bling": -6.0,
	"start": -6.0,
	"call_bell": -7.0,
	"call_intercom": -12.0,
}

const VOICE_STREAMS := {
	"PERSON-LIN": preload("res://assets/audio/sfx/people_male_young.wav"),
	"PERSON-ZHOU": preload("res://assets/audio/sfx/people_male_old.wav"),
	"PERSON-XU": preload("res://assets/audio/sfx/people_female_young.wav"),
}
const VOICE_FALLBACKS := [
	preload("res://assets/audio/sfx/people_male_average.wav"),
	preload("res://assets/audio/sfx/people_female_old.wav"),
]

const AMBIENCE_STREAM := preload("res://assets/audio/sfx/background_whitenoise_talk.mp3")
const WALK_STREAM := preload("res://assets/audio/sfx/people_walkonfloor.mp3")
const CONVEYOR_STREAM := preload("res://assets/audio/sfx/item_conveyor_belt.wav")
const TYPEWRITER_STREAM := preload("res://assets/audio/sfx/item_typewriter.wav")

const ONE_SHOT_POOL_SIZE := 8
const TYPEWRITER_LINGER_SECONDS := 0.3

var one_shot_players: Array[AudioStreamPlayer] = []
var ambience_player: AudioStreamPlayer
var walk_player: AudioStreamPlayer
var conveyor_player: AudioStreamPlayer
var typewriter_player: AudioStreamPlayer
var voice_player: AudioStreamPlayer
var typewriter_deadline := 0.0
var voice_fallback_index := 0
var last_voice_person_id := ""


# 创建一次性音效池与各专用播放器；暂停时仍可播放 UI 音效。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in ONE_SHOT_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "OneShot%d" % i
		add_child(player)
		one_shot_players.append(player)

	ambience_player = _make_looping_player("Ambience", AMBIENCE_STREAM, -16.0)
	walk_player = _make_looping_player("Walk", WALK_STREAM, -10.0)

	# 传送带素材长达 10 秒，远超吞入动画，播放一次即可，无需循环。
	conveyor_player = AudioStreamPlayer.new()
	conveyor_player.name = "Conveyor"
	conveyor_player.stream = CONVEYOR_STREAM
	conveyor_player.volume_db = -10.0
	add_child(conveyor_player)

	typewriter_player = AudioStreamPlayer.new()
	typewriter_player.name = "Typewriter"
	typewriter_player.stream = TYPEWRITER_STREAM
	typewriter_player.volume_db = -10.0
	add_child(typewriter_player)

	voice_player = AudioStreamPlayer.new()
	voice_player.name = "NpcVoice"
	voice_player.volume_db = -9.0
	add_child(voice_player)


func _make_looping_player(player_name: String, stream: AudioStreamMP3, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	var looping_stream := stream.duplicate() as AudioStreamMP3
	looping_stream.loop = true
	player.stream = looping_stream
	player.volume_db = volume_db
	add_child(player)
	return player


func _is_muted() -> bool:
	var music = get_node_or_null("/root/OpeningMusic")
	return music != null and bool(music.muted)


# 播放一次性音效；name 为 STREAMS 中的键。
func play(sound_name: String, volume_offset_db := 0.0, pitch := 1.0) -> void:
	if _is_muted() or not STREAMS.has(sound_name):
		return
	for player in one_shot_players:
		if player.playing:
			continue
		player.stream = STREAMS[sound_name]
		player.volume_db = float(DEFAULT_VOLUME_DB.get(sound_name, 0.0)) + volume_offset_db
		player.pitch_scale = pitch
		player.play()
		return


# 播放一次短促人物拟声；配置路径无效时按人物 ID 或备用声线降级。
func play_voice(person_id: String, configured_path := "") -> void:
	if _is_muted():
		return
	var stream: AudioStream
	if not configured_path.is_empty() and ResourceLoader.exists(configured_path):
		stream = load(configured_path)
	if stream == null:
		stream = VOICE_STREAMS.get(person_id)
	if stream == null:
		stream = VOICE_FALLBACKS[voice_fallback_index % VOICE_FALLBACKS.size()]
		voice_fallback_index += 1
	voice_player.stop()
	voice_player.stream = stream
	voice_player.pitch_scale = 1.0
	last_voice_person_id = person_id
	voice_player.play()


func stop_voice() -> void:
	if is_instance_valid(voice_player):
		voice_player.stop()


# 开始播放办公室环境底噪（人声嘈杂声）循环。
func start_ambience() -> void:
	if not ambience_player.playing:
		ambience_player.play()


func stop_ambience() -> void:
	ambience_player.stop()


# 开始/停止脚步声循环（傍晚地图移动）。
func start_walking() -> void:
	if not walk_player.playing:
		walk_player.play()


func stop_walking() -> void:
	walk_player.stop()


# 开始/停止验收机器传送带声（素材足够长，单次播放）。
func start_conveyor() -> void:
	if not conveyor_player.playing:
		conveyor_player.play()


func stop_conveyor() -> void:
	conveyor_player.stop()


# 输入框每次击键调用：从素材随机位置起播打字声，停止输入后自动收束。
func typewriter_tick() -> void:
	typewriter_deadline = Time.get_ticks_msec() / 1000.0 + TYPEWRITER_LINGER_SECONDS
	if _is_muted():
		return
	if not typewriter_player.playing:
		var length: float = typewriter_player.stream.get_length()
		typewriter_player.play(randf_range(0.0, maxf(length - 1.0, 0.0)))


func _process(_delta: float) -> void:
	if typewriter_player.playing and Time.get_ticks_msec() / 1000.0 > typewriter_deadline:
		typewriter_player.stop()
