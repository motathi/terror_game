extends Node
## Estado persistente: finais descobertos e configurações.
## Salva em user://save.json (no navegador vira IndexedDB automaticamente).

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

## Campanhas disponíveis (ordem do menu). Adicione novos capítulos aqui.
const CAMPAIGNS := [
	{"id": "cap1_surto", "path": "res://story/cap1_surto.json"},
]

var current_campaign: String = CAMPAIGNS[0]["path"]
var discovered_endings: Dictionary = {}  # "campanha/final" -> {"time": unix}
var settings: Dictionary = {
	"auto_advance": true,
	"text_speed": 45.0,  # caracteres por segundo
	"voice_volume": 1.0,
	"sfx_volume": 1.0,
	"music_volume": 0.8,
	"timers": true,  # desligar = modo sem pressão de tempo (acessibilidade)
}


func _ready() -> void:
	load_save()


func discover_ending(campaign_id: String, ending_id: String) -> bool:
	var key := campaign_id + "/" + ending_id
	if discovered_endings.has(key):
		return false
	discovered_endings[key] = {"time": Time.get_unix_time_from_system()}
	save()
	return true


func is_discovered(campaign_id: String, ending_id: String) -> bool:
	return discovered_endings.has(campaign_id + "/" + ending_id)


func count_discovered(campaign_id: String) -> int:
	var n := 0
	for key in discovered_endings:
		if String(key).begins_with(campaign_id + "/"):
			n += 1
	return n


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("GameState: não foi possível salvar (%s)" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"endings": discovered_endings,
		"settings": settings,
	}, "\t"))


func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	discovered_endings = data.get("endings", {})
	var s: Dictionary = data.get("settings", {})
	for k in s:
		settings[k] = s[k]


func reset_progress() -> void:
	discovered_endings.clear()
	save()
