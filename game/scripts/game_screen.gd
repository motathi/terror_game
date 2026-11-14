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
	Audio.set_story_audio(runner.story.get("musica_cenarios", {}), runner.story.get("sons_cenarios", {}))
	_run.call_deferred()


func _run() -> void:
	runner.reset()
	if not GameState.debug_ending.is_empty() and runner.story.get("endings", {}).has(GameState.debug_ending):
		var e := GameState.debug_ending
		GameState.debug_ending = ""
		await _show_ending(e)
		return
	var current := runner.start_node()
	if not GameState.debug_start_node.is_empty() and runner.story["nodes"].has(GameState.debug_start_node):
		current = GameState.debug_start_node
		GameState.debug_start_node = ""
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
		Audio.set_location(loc)
	Audio.play_music(node.get("music", Audio.music_for_location(loc)))
	stage.apply_node_view(node.get("camera", {}))
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
		# efeitos (telefone/TV/porta) já vêm aplicados no arquivo de voz
		spoke = Audio.play_voice(line["id"], "Voice")
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
	if timer > 0.0 and GameState.settings.get("timers", true):
		Audio.start_choice_tension()
	var idx: int = await ui.present_choice(choice.get("prompt", ""), labels, timer)
	Audio.stop_choice_tension()
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
	var kind: String = data.get("kind", "")
	Audio.play_ambience("")
	Audio.set_location("")
	Audio.play_music({"morte": "final_morte", "sobreviveu": "final_vivo"}.get(kind, "final_triste"), 1.0)
	if data.has("cinematica"):
		await _play_cinematic(data["cinematica"], ending_id, data.get("text", ""))
	else:
		stage.scare_flash()
		Audio.play_sfx("stinger_boom" if kind == "morte" else "stinger_hit")
	var action: String = await ui.show_ending(data, is_new, found, total)
	match action:
		"replay":
			get_tree().reload_current_scene()
		"endings":
			get_tree().change_scene_to_file("res://scenes/endings_gallery.tscn")
		_:
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# --- cinemáticas dos finais ------------------------------------------------------------
# Cada final pode ter "cinematica": {location, camera, slots, cast, personagens,
# maos, dur, narrar, passos: [{t, acao, ...}]}. Ver docs/FORMATO_HISTORIA.md.

func _play_cinematic(c: Dictionary, ending_id: String, narration: String) -> void:
	var chars: Dictionary = runner.story.get("characters", {}).duplicate()
	chars.merge(c.get("personagens", {}), true)
	await ui.fade_out(0.5)
	ui.hide_subtitle()
	stage.clear_cinematic()
	stage.set_location(c.get("location", stage.location_id), true)
	stage.location_cfg["approach_center"] = false
	var slots := {}
	for k in c.get("slots", {}):
		slots[k] = _v(c["slots"][k])
	stage.location_cfg["slots"] = slots
	if c.has("camera"):
		stage.set_camera(_v(c["camera"]["pos"]), _v(c["camera"]["olhar"]))
	stage.hands.visible = c.get("maos", false)
	stage.set_cast(c.get("cast", {}), chars)
	stage.hide_names()
	await ui.fade_in(0.5)

	var steps: Array = c.get("passos", []).duplicate()
	steps.sort_custom(func(a, b): return float(a.get("t", 0.0)) < float(b.get("t", 0.0)))
	var dur: float = c.get("dur", 8.0)
	var narr_at: float = c.get("narrar", 0.8)
	var narrated := false
	var t := 0.0
	var i := 0
	ui.consume_tap()
	while true:
		while i < steps.size() and float(steps[i].get("t", 0.0)) <= t:
			_run_step(steps[i], chars)
			i += 1
		if not narrated and t >= narr_at and not narration.is_empty():
			narrated = true
			Audio.play_voice("fim_%s_%s" % [runner.campaign_id, ending_id], "Voice")
			ui.show_caption("", narration)
		await get_tree().process_frame
		t += get_process_delta_time()
		var voice_busy := narrated and Audio.is_voice_playing()
		if t >= dur and not voice_busy and i >= steps.size():
			break
		if t > dur + 12.0:
			break
		if ui.consume_tap() and t > 1.2:
			break  # toque pula a cena
	Audio.stop_voice()
	ui.hide_subtitle()


func _run_step(s: Dictionary, chars: Dictionary) -> void:
	var who: String = s.get("who", "")
	var dur: float = s.get("dur", 1.0)
	match s.get("acao", ""):
		"anim":
			var a = stage.actor_for(who)
			if a:
				a.play(s.get("anim", "Idle"))
		"mover":
			stage.move_actor(who, _v(s["para"]), dur)
		"olhar_camera":
			stage.face_camera_now(who)
		"trocar":
			stage.swap_actor(who, s["novo"], chars.get(s["novo"], {}), s.get("anim", "Idle"))
		"tremer":
			stage.shake_actor(who, dur)
		"camera":
			stage.tween_camera(_v(s["pos"]), _v(s["olhar"]), s.get("dur", 0.0))
		"sfx":
			Audio.play_sfx(s.get("som", ""), float(s.get("volume", 0.0)))
		"voz":
			Audio.play_voice(s.get("id", ""), "Voice")
			if s.has("texto"):
				ui.show_caption(s.get("quem", ""), s["texto"])
		"legenda":
			ui.show_caption(s.get("quem", ""), s.get("texto", ""))
		"texto3d":
			stage.world_text(s.get("id", "t"), s.get("texto", ""), _v(s["pos"]), int(s.get("tamanho", 48)), Color.html(s.get("cor", "#ffffff")))
		"luz":
			stage.tween_env(Color.html(s.get("ambiente", "#404050")), float(s.get("energia", 0.5)),
				Color.html(s.get("neblina", "#101010")), float(s.get("densidade", 0.03)), Color.html(s.get("fundo", "#000000")), dur)
		"luz_ponto":
			stage.point_light(_v(s["pos"]), Color.html(s.get("cor", "#ffffff")), float(s.get("energia", 1.0)), float(s.get("raio", 5.0)), s.get("piscar", false))
		"no":
			stage.move_location_node(s.get("nome", ""), _v(s["para"]), dur)
		"maos":
			stage.hands.visible = true
			stage.play_hands(s.get("anim", "guard_idle"))
		"maos_cor":
			stage.tint_hands(Color.html(s.get("cor", "#ffffff")), dur)
		"fx":
			match s.get("tipo", ""):
				"flash":
					stage.scare_flash()
				"tremor":
					stage.shake(float(s.get("forca", 0.08)))
				"piscar":
					stage.flicker_lights(dur)
				"luzes_off":
					stage.lights_off()
				"vermelho":
					stage.post_tween("flash", float(s.get("de", 0.0)), float(s.get("ate", 0.9)), dur)
				"apagar":
					stage.post_tween("blackout", 0.0, 1.0, dur)
				"acender":
					stage.post_tween("blackout", 1.0, 0.0, dur)
				"chuvisco":
					stage.post_tween("static_amount", float(s.get("de", 0.0)), float(s.get("ate", 0.8)), dur)


func _v(a) -> Vector3:
	if a is Vector3:
		return a
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
