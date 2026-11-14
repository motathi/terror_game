extends Node
## Áudio do jogo: vozes (geradas pelo ElevenLabs), efeitos e ambiente.
##
## Ordem de busca de cada som:
##   vozes:    res://audio/vo/<locale>/<id_da_fala>.(ogg|mp3|wav)
##   efeitos:  res://audio/sfx/<chave>.*   -> senão, fallback do pacote CC-BY
##   ambiente: res://audio/amb/<chave>.*   -> senão, fallback do pacote CC-BY
## Arquivos que não existem são ignorados em silêncio: o jogo roda sem áudio
## nenhum (útil antes de rodar tools/elevenlabs_gen.py).

signal voice_finished

const PACK := "res://assets/third_party/psx_horror_sfx/OGG/"
const SFX_FALLBACK := {
	"stinger_hit": PACK + "stingers/stinger_hit.ogg",
	"stinger_boom": PACK + "stingers/stinger_boom.ogg",
	"grito": PACK + "creatures/screech_01.ogg",
	"grito_zumbi": PACK + "creatures/screech_01.ogg",
	"gemido": PACK + "creatures/zombie_moan_02.ogg",
	"rosnado": PACK + "creatures/growl_01.ogg",
	"batidas_vidro": PACK + "doors/door_locked.ogg",
	"passos": PACK + "footsteps/step_concrete_01.ogg",
	"porta_abre": PACK + "doors/door_open_02.ogg",
	"elevador_ding": PACK + "menus/item_pickup.ogg",
	"celular": PACK + "menus/select.ogg",
	"linha_caiu": PACK + "menus/cursor_01.ogg",
	"ui_select": PACK + "menus/select.ogg",
	"ui_cursor": PACK + "menus/cursor_01.ogg",
	"coracao": PACK + "ambience/heartbeat_slow.ogg",
}
const AMB_FALLBACK := {
	"tensao": PACK + "ambience/drone_low.ogg",
	"garagem": PACK + "ambience/drone_low.ogg",
	"rua": PACK + "ambience/drone_low.ogg",
	"casa": PACK + "ambience/drone_low.ogg",
	"carro": PACK + "ambience/drone_low.ogg",
}

## Música padrão de cada cenário (o nó da história pode trocar com "music").
const LOCATION_MUSIC := {
	"escritorio": "inquietacao",
	"escritorio_escuro": "tensao",
	"escada": "tensao",
	"garagem": "suspense",
	"carro": "estrada",
	"rua": "perseguicao",
	"casa": "casa",
}
## Sons soltos que tocam de vez em quando, baixinho, em cada cenário.
const LOCATION_RANDOM := {
	"escritorio_escuro": ["longe_grito", "batida_porta", "vidro", "sirene"],
	"escada": ["longe_grito", "batida_porta", "rosnado_longe"],
	"garagem": ["rosnado_longe", "vidro", "longe_grito"],
	"carro": ["sirene", "helicoptero", "longe_grito"],
	"rua": ["sirene", "helicoptero", "longe_grito", "vidro", "rosnado_longe"],
	"casa": ["batida_porta", "rosnado_longe", "sirene"],
}
const MUSIC_DB := -9.0
const DUCK_DB := -9.0  # quanto a música abaixa enquanto alguém fala

var locale := "pt_BR"
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_key := ""
var _tension: AudioStreamPlayer
var _random_pool: Array = []
var _random_timer := 0.0
var _duck := 0.0
var _voice: AudioStreamPlayer
var _amb_a: AudioStreamPlayer
var _amb_b: AudioStreamPlayer
var _amb_key := ""
var _sfx_pool: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_voice = _make_player("Voice")
	_voice.finished.connect(func(): voice_finished.emit())
	_amb_a = _make_player("Ambience")
	_amb_b = _make_player("Ambience")
	for i in 6:
		_sfx_pool.append(_make_player("SFX"))
	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	_tension = _make_player("SFX")
	apply_volumes()


func _process(delta: float) -> void:
	# ducking: música abaixa enquanto uma voz toca
	var target := 1.0 if _voice.playing else 0.0
	_duck = move_toward(_duck, target, delta * (4.0 if target > _duck else 1.2))
	var idx := AudioServer.get_bus_index("Music")
	if idx >= 0:
		var base := linear_to_db(maxf(float(GameState.settings.get("music_volume", 0.8)), 0.0001))
		AudioServer.set_bus_volume_db(idx, base + DUCK_DB * _duck)
	# sons aleatórios do cenário
	if not _random_pool.is_empty():
		_random_timer -= delta
		if _random_timer <= 0.0:
			_random_timer = randf_range(9.0, 20.0)
			play_sfx(_random_pool.pick_random(), randf_range(-16.0, -9.0))


## Troca a trilha com crossfade. "" = silêncio.
func play_music(key: String, fade := 2.5) -> void:
	if key == _music_key:
		return
	_music_key = key
	var stream: AudioStream = null if key.is_empty() else _find("res://audio/music/" + key)
	var old := _music_a
	_music_a = _music_b
	_music_b = old
	var tw := create_tween()
	tw.tween_property(_music_b, "volume_db", -60.0, fade)
	tw.tween_callback(_music_b.stop)
	if stream == null:
		return
	if not key.begins_with("final_"):
		_set_loop(stream)
	_music_a.stream = stream
	_music_a.volume_db = -50.0
	_music_a.play()
	create_tween().tween_property(_music_a, "volume_db", MUSIC_DB, fade)


func music_for_location(location: String) -> String:
	return LOCATION_MUSIC.get(location, "tensao")


func set_location(location: String) -> void:
	_random_pool = LOCATION_RANDOM.get(location, [])
	_random_timer = randf_range(4.0, 10.0)


## Tique-taque + coração enquanto o jogador decide.
func start_choice_tension() -> void:
	var stream := _find("res://audio/amb/escolha")
	if stream == null:
		return
	_set_loop(stream)
	_tension.stream = stream
	_tension.volume_db = -30.0
	_tension.play()
	create_tween().tween_property(_tension, "volume_db", -6.0, 0.8)


func stop_choice_tension() -> void:
	if _tension.playing:
		var tw := create_tween()
		tw.tween_property(_tension, "volume_db", -50.0, 0.3)
		tw.tween_callback(_tension.stop)


## Toca a fala `line_id`. Retorna false se o arquivo de voz não existir.
func play_voice(line_id: String, bus: String = "Voice") -> bool:
	var stream := _find("res://audio/vo/%s/%s" % [locale, line_id])
	_voice.stop()
	print("[audio] voz ", line_id, " -> ", stream != null, " bus=", bus)
	if stream == null:
		return false
	_voice.stream = stream
	_voice.bus = bus if AudioServer.get_bus_index(bus) >= 0 else "Voice"
	_voice.play()
	return true


func is_voice_playing() -> bool:
	return _voice.playing


func stop_voice() -> void:
	_voice.stop()


func play_sfx(key: String, volume_db: float = 0.0) -> void:
	if key.is_empty():
		return
	var stream := _find("res://audio/sfx/" + key)
	if stream == null and SFX_FALLBACK.has(key):
		stream = _load(SFX_FALLBACK[key])
	if stream == null:
		print("[audio] sfx sem arquivo: ", key)
		return
	print("[audio] sfx ", key)
	for p in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.play()
			return


## Troca o som ambiente com crossfade. Chave vazia = silêncio.
func play_ambience(key: String, fade: float = 1.5) -> void:
	if key == _amb_key:
		return
	_amb_key = key
	var stream: AudioStream = null
	if not key.is_empty():
		stream = _find("res://audio/amb/" + key)
		if stream == null and AMB_FALLBACK.has(key):
			stream = _load(AMB_FALLBACK[key])
	var old := _amb_a
	_amb_a = _amb_b
	_amb_b = old
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_amb_b, "volume_db", -60.0, fade)
	tw.chain().tween_callback(_amb_b.stop)
	print("[audio] ambiente ", key, " -> ", stream != null)
	if stream != null:
		_set_loop(stream)
		_amb_a.stream = stream
		_amb_a.volume_db = -60.0
		_amb_a.play()
		create_tween().tween_property(_amb_a, "volume_db", -12.0, fade)


func apply_volumes() -> void:
	var s: Dictionary = GameState.settings
	_set_bus_volume("Voice", s.get("voice_volume", 1.0))
	_set_bus_volume("SFX", s.get("sfx_volume", 1.0))
	_set_bus_volume("Ambience", s.get("music_volume", 0.8))
	_set_bus_volume("Music", s.get("music_volume", 0.8))


# --- internos ---------------------------------------------------------------

func _setup_buses() -> void:
	# Os buses vêm de res://default_bus_layout.tres. Isto só garante que
	# existam caso o arquivo falte (não vale para o modo Sample da web).
	if AudioServer.get_bus_index("Muffled") >= 0:
		return
	_add_bus("Music", "Master")
	_add_bus("Ambience", "Master")
	_add_bus("SFX", "Master")
	_add_bus("Voice", "Master")
	# Voz no telefone: banda estreita + leve saturação.
	var phone := _add_bus("Phone", "Voice")
	if AudioServer.get_bus_effect_count(phone) == 0:
		var bp := AudioEffectBandPassFilter.new()
		bp.cutoff_hz = 1700.0
		AudioServer.add_bus_effect(phone, bp)
		var dist := AudioEffectDistortion.new()
		dist.drive = 0.25
		dist.post_gain = -4.0
		AudioServer.add_bus_effect(phone, dist)
	# TV / rádio: parecido com telefone, mais grave.
	var radio := _add_bus("Radio", "Voice")
	if AudioServer.get_bus_effect_count(radio) == 0:
		var bp2 := AudioEffectBandPassFilter.new()
		bp2.cutoff_hz = 1200.0
		AudioServer.add_bus_effect(radio, bp2)
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.3
		rv.wet = 0.15
		AudioServer.add_bus_effect(radio, rv)
	# Atrás de uma porta.
	var muffled := _add_bus("Muffled", "Voice")
	if AudioServer.get_bus_effect_count(muffled) == 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 900.0
		AudioServer.add_bus_effect(muffled, lp)


func _add_bus(bus_name: String, send: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send)
	return idx


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _find(base_path: String) -> AudioStream:
	for ext in [".ogg", ".mp3", ".wav"]:
		var s := _load(base_path + ext)
		if s != null:
			return s
	return null


func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path) as AudioStream
	_cache[path] = s
	return s


func _set_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
