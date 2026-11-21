extends Node
## Estado persistente: finais descobertos e configurações.
## Salva em user://save.json (no navegador vira IndexedDB automaticamente).

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

## Lista de campanhas do menu (inclusive as "em breve").
const CAMPAIGNS_PATH := "res://story/campanhas.json"

var campaigns: Array = []
var current_campaign: String = "res://story/cap1_surto.json"
var discovered_endings: Dictionary = {}  # "campanha/final" -> {"time": unix}
## Capítulos alcançados (liberam começar direto neles pelo menu): "campanha" -> [nó, ...]
var unlocked_chapters: Dictionary = {}
## Capítulo escolhido no menu: a partida começa neste nó (vazio = início da história).
var start_chapter_node := ""
var settings: Dictionary = {
	"auto_advance": true,
	"text_speed": 45.0,  # caracteres por segundo
	"voice_volume": 1.0,
	"sfx_volume": 1.0,
	"music_volume": 0.8,
	"timers": true,  # desligar = modo sem pressão de tempo (acessibilidade)
}


## Atalho de teste na web: ...?cena=<id_do_nó> abre o jogo direto nessa cena.
var debug_start_node := ""
## Atalho de teste: ...?final=<id_do_final> mostra direto a cinemática do final.
var debug_ending := ""
## Atalho de teste: ...?lento=0.25 roda o jogo em câmera lenta (conferir sustos quadro a quadro).
## Atalho de teste: ...?vars=viu_marina:true,culpa:2 define variáveis da história ao abrir com ?cena=.
var debug_vars := {}


func _ready() -> void:
	_load_campaigns()
	load_save()
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('cena') || ''", true)
		debug_start_node = str(q) if q != null else ""
		var fq = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('final') || ''", true)
		debug_ending = str(fq) if fq != null else ""
		var lq = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('lento') || ''", true)
		if lq != null and str(lq).is_valid_float():
			Engine.time_scale = clampf(str(lq).to_float(), 0.05, 1.0)  # câmera lenta para conferir sustos
		var vq = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('vars') || ''", true)
		for pair in str(vq if vq != null else "").split(",", false):
			var kv: PackedStringArray = str(pair).split(":")
			if kv.size() == 2:
				if kv[1] == "true" or kv[1] == "false":
					debug_vars[kv[0]] = kv[1] == "true"
				else:
					debug_vars[kv[0]] = kv[1].to_int()
		var camp = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('campanha') || ''", true)
		for i in campaigns.size():
			if str(camp) != "" and campaigns[i].get("id", "") == str(camp) and campaigns[i].has("path"):
				current_campaign = campaigns[i]["path"]
				settings["menu_campaign"] = i


func _load_campaigns() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(CAMPAIGNS_PATH)) if FileAccess.file_exists(CAMPAIGNS_PATH) else null
	if data == null:
		var res = load(CAMPAIGNS_PATH)
		data = res.data if res is JSON else {}
	campaigns = data.get("campanhas", []) if typeof(data) == TYPE_DICTIONARY else []


func campaign_index() -> int:
	return clampi(int(settings.get("menu_campaign", 0)), 0, maxi(campaigns.size() - 1, 0))


func discover_ending(campaign_id: String, ending_id: String) -> bool:
	var key := campaign_id + "/" + ending_id
	if discovered_endings.has(key):
		return false
	discovered_endings[key] = {"time": Time.get_unix_time_from_system()}
	save()
	return true


func is_discovered(campaign_id: String, ending_id: String) -> bool:
	return discovered_endings.has(campaign_id + "/" + ending_id)


## valid = finais que existem hoje na campanha (finais removidos não contam).
func count_discovered(campaign_id: String, valid: Array = []) -> int:
	var n := 0
	for key in discovered_endings:
		if String(key).begins_with(campaign_id + "/"):
			if valid.is_empty() or String(key).trim_prefix(campaign_id + "/") in valid:
				n += 1
	return n


func unlock_chapter(campaign_id: String, node_id: String) -> void:
	var list: Array = unlocked_chapters.get(campaign_id, [])
	if node_id in list:
		return
	list.append(node_id)
	unlocked_chapters[campaign_id] = list
	save()


func is_chapter_unlocked(campaign_id: String, node_id: String) -> bool:
	return node_id in unlocked_chapters.get(campaign_id, [])


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("GameState: não foi possível salvar (%s)" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"endings": discovered_endings,
		"chapters": unlocked_chapters,
		"settings": settings,
	}, "\t"))


func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	discovered_endings = data.get("endings", {})
	unlocked_chapters = data.get("chapters", {})
	var s: Dictionary = data.get("settings", {})
	for k in s:
		settings[k] = s[k]


func reset_progress() -> void:
	discovered_endings.clear()
	save()
