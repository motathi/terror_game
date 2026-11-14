extends Control
## Tela de jogo: liga o StoryRunner (lógica), o Stage (3D) e o DialogueUI.
##
##   SubViewportContainer (baixa resolução + shader PSX de pós)
##     └ SubViewport └ Stage (cenário, elenco, câmera POV)
##   CanvasLayer └ DialogueUI (legenda, escolhas, finais) — sem filtro

const StoryRunner := preload("res://scripts/story/story_runner.gd")
const Stage := preload("res://scripts/stage/stage.gd")
const DialogueUI := preload("res://scripts/ui/dialogue_ui.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const POST_SHADER := preload("res://shaders/psx_post.gdshader")

## 1/4 da resolução da tela: 720x1280 -> 180x320 (bem PS1).
const PIXEL_SHRINK := 4

var runner := StoryRunner.new()
var stage: Stage
var ui: DialogueUI
var _current_choice_options: Array = []


func _ready() -> void:
	UI.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var svc := SubViewportContainer.new()
	UI.full_rect(svc)
	svc.stretch = true
	svc.stretch_shrink = PIXEL_SHRINK
	svc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var post := ShaderMaterial.new()
	post.shader = POST_SHADER
	svc.material = post
	add_child(svc)
	var sv := SubViewport.new()
	sv.msaa_3d = Viewport.MSAA_DISABLED
	sv.audio_listener_enable_3d = true
	svc.add_child(sv)

	stage = Stage.new()
	stage.title_font = UI.title_font()
	stage.body_font = UI.body_font()
	stage.post_material = post
	sv.add_child(stage)

	var layer := CanvasLayer.new()
	add_child(layer)
	ui = DialogueUI.new()
	layer.add_child(ui)
	ui.screen_tapped.connect(_on_screen_tapped)

	if not runner.load_file(GameState.current_campaign):
		push_error("Não foi possível carregar a campanha")
		return
	_run.call_deferred()


func _run() -> void:
	runner.reset()
	var current := runner.start_node()
	while true:
		var node := runner.enter_node(current)
		if node.is_empty():
			return
		await _setup_scene(node)
		for line in runner.visible_lines(node):
			await _play_line(line, node)
		var result: Dictionary
		if node.has("choice"):
			result = await _do_choice(node)
		else:
			result = runner.resolve_exit(node)
		if result.has("ending"):
			await _show_ending(result["ending"])
			return
		current = result.get("next", "")


func _setup_scene(node: Dictionary) -> void:
	var loc: String = node.get("location", stage.location_id)
	var changing: bool = loc != stage.location_id
	if changing:
		await ui.fade_out(0.45)
		stage.set_location(loc)
	stage.set_cast(node.get("cast", {}), runner.story.get("characters", {}))
	if node.has("ambience"):
		Audio.play_ambience(node["ambience"])
	if changing:
		await ui.fade_in(0.6)
	if node.has("title_card"):
		await ui.show_title_card(node["title_card"])


func _play_line(line: Dictionary, node: Dictionary) -> void:
	var who: String = line.get("who", "sistema")
	var ch := runner.character(who)
	var cast: Dictionary = node.get("cast", {})
	var phone: bool = line.get("phone", false) or cast.get("phone", {}).get("char", "") == who
	stage.on_line_start(line)
	if line.has("sfx"):
		Audio.play_sfx(line["sfx"])
	var spoke := false
	if ch.get("voiced", true):
		var bus: String = "Phone" if phone else ch.get("bus", "Voice")
		spoke = Audio.play_voice(line["id"], bus)
	await ui.present_line(ch.get("name", ""), line.get("text", ""), phone, GameState.settings.get("auto_advance", true))
	if spoke:
		Audio.stop_voice()
	stage.on_line_end(line, cast)


func _do_choice(node: Dictionary) -> Dictionary:
	var choice: Dictionary = node["choice"]
	_current_choice_options = runner.available_options(choice)
	var labels: PackedStringArray = []
	for o in _current_choice_options:
		labels.append(o["text"])
	stage.set_pleads(choice.get("plead", {}))
	stage.shake(0.02)
	var timer: float = choice.get("timer", 0.0)
	var idx: int = await ui.present_choice(choice.get("prompt", ""), labels, timer)
	stage.clear_pleads()
	if idx < 0:
		Audio.play_sfx("stinger_hit")
		return runner.timeout(choice)
	var opt: Dictionary = _current_choice_options[idx]
	if opt.has("who"):
		stage.reach_towards(opt["who"])
	await get_tree().create_timer(0.35).timeout
	return runner.choose(opt)


## Toque direto num personagem escolhe a opção ligada a ele ("who").
func _on_screen_tapped(pos: Vector2) -> void:
	var who: String = stage.actor_at_screen(pos, PIXEL_SHRINK)
	if who.is_empty():
		return
	for i in _current_choice_options.size():
		if _current_choice_options[i].get("who", "") == who:
			ui.force_choice(i)
			return


func _show_ending(ending_id: String) -> void:
	var data := runner.ending(ending_id)
	var is_new := GameState.discover_ending(runner.campaign_id, ending_id)
	var found := GameState.count_discovered(runner.campaign_id)
	var total := runner.ending_ids().size()
	stage.scare_flash()
	Audio.play_sfx("stinger_boom" if data.get("kind", "") == "morte" else "stinger_hit")
	Audio.play_ambience("tensao")
	var action: String = await ui.show_ending(data, is_new, found, total)
	match action:
		"replay":
			get_tree().reload_current_scene()
		"endings":
			get_tree().change_scene_to_file("res://scenes/endings_gallery.tscn")
		_:
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
