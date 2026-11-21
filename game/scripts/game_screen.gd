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
const DiceRoll := preload("res://scripts/ui/dice_roll.gd")

## 1/4 da resolução da tela: 720x1280 -> 180x320 (bem PS1).
const PIXEL_SHRINK := 4

var runner := StoryRunner.new()
var stage: Stage
var ui: DialogueUI
var _current_choice_options: Array = []
var _scene_gen := 0  # muda a cada nó: ações atrasadas de um nó antigo são ignoradas


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
		for k in GameState.debug_vars:
			runner.vars[k] = GameState.debug_vars[k]
		GameState.debug_vars = {}
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
		stage.clear_cinematic()
		Audio.set_location(loc)
	Audio.play_music(node.get("music", Audio.music_for_location(loc)))
	stage.apply_node_view(node.get("camera", {}))
	stage.set_cast(node.get("cast", {}), runner.story.get("characters", {}))
	# "maos_ocultas": {"esquerda": "sem_braco"} esconde a mão enquanto a condição valer
	# (ex.: o braço que você cortou não volta a aparecer nas cenas seguintes)
	var rules: Dictionary = runner.story.get("maos_ocultas", {})
	for side in ["esquerda", "direita"]:
		stage.set_hand_hidden(side, rules.has(side) and runner.eval_condition(rules[side]))
	_scene_gen += 1
	_start_timeline(node.get("acoes", []))  # direção de cena do nó (entradas etc.)
	if node.has("ambience"):
		Audio.play_ambience(node["ambience"])
	if changing:
		await ui.fade_in(0.6)
	if node.has("title_card"):
		await ui.show_title_card(node["title_card"])
	if node.has("aguardar"):
		await get_tree().create_timer(float(node["aguardar"])).timeout


## Ações com tempo ("t" em segundos): as de t <= 0 rodam já (antes de a cena
## aparecer); as outras rodam em paralelo com as falas.
func _start_timeline(steps: Array) -> void:
	if steps.is_empty():
		return
	var chars: Dictionary = runner.story.get("characters", {})
	var sorted := steps.duplicate()
	sorted.sort_custom(func(a, b): return float(a.get("t", 0.0)) < float(b.get("t", 0.0)))
	var rest: Array = []
	for st in sorted:
		if float(st.get("t", 0.0)) <= 0.0:
			_run_step(st, chars)
		else:
			rest.append(st)
	if not rest.is_empty():
		_timeline(rest, chars, _scene_gen)


func _timeline(steps: Array, chars: Dictionary, gen: int) -> void:
	var t := 0.0
	for st in steps:
		var at := float(st.get("t", 0.0))
		if at > t:
			await get_tree().create_timer(at - t).timeout
			t = at
		if gen != _scene_gen:
			return
		_run_step(st, chars)


func _play_line(line: Dictionary, node: Dictionary) -> void:
	var who: String = line.get("who", "sistema")
	var ch := runner.character(who)
	var cast: Dictionary = node.get("cast", {})
	var phone: bool = line.get("phone", false) or cast.get("phone", {}).get("char", "") == who
	stage.on_line_start(line)
	_start_timeline(line.get("acoes", []))
	if line.has("sfx"):
		Audio.play_sfx(line["sfx"])
	if line.has("espera"):
		await get_tree().create_timer(float(line["espera"])).timeout
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
	var gold: Array = []
	for o in _current_choice_options:
		if o.has("teste"):
			var info := runner.test_info(o["teste"])
			labels.append("[%s · CD %d]  %s" % [String(info["nome"]).to_upper(), info["cd"], o["text"]])
			gold.append(true)
		else:
			labels.append(o["text"])
			gold.append(false)
	stage.set_pleads(choice.get("plead", {}))
	stage.shake(0.02)
	var timer: float = choice.get("timer", 0.0)
	if timer > 0.0 and GameState.settings.get("timers", true):
		Audio.start_choice_tension()
	var idx: int = await ui.present_choice(choice.get("prompt", ""), labels, timer, gold)
	Audio.stop_choice_tension()
	stage.clear_pleads()
	if idx < 0:
		Audio.play_sfx("stinger_hit")
		return runner.timeout(choice)
	var opt: Dictionary = _current_choice_options[idx]
	if opt.has("who"):
		stage.reach_towards(opt["who"])
	await get_tree().create_timer(0.35).timeout
	if opt.has("teste"):
		# teste de dado: o resultado decide para onde a história vai
		var ok: bool = await DiceRoll.new().run(ui.get_parent(), runner.test_info(opt["teste"]))
		return runner.resolve_test(opt, ok)
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
				if s.get("fixo", false):
					a.base_anim = s.get("anim", "Idle")
		"entrar":
			stage.enter_actor(who, _v(s.get("de", [-3, 0, 0])), dur, s.get("anim", "Walk"), s.get("fim", "Idle"))
		"sair":
			stage.exit_actor(who, _v(s.get("para", [3, 0, 0])), dur, s.get("anim", "Walk"), s.get("esconder", true))
		"andar":
			stage.move_actor_rel(who, _v(s.get("por", [0, 0, 0])), dur, s.get("anim", "Walk"), s.get("fim", "Idle"), s.get("olhar_camera", true))
		"olhar_para":
			stage.face_actor(who, s.get("alvo", ""))
		"camera_andar":
			if s.has("pos"):
				stage.walk_camera(_v(s["pos"]), _v(s["olhar"]), dur)
			else:
				stage.camera_rel(_v(s.get("por", [0, 0, -1])), dur, true, _v(s["olhar"]) if s.has("olhar") else null)
		"camera_rel":
			stage.camera_rel(_v(s.get("por", [0, 0, 0])), dur, s.get("andar", false), _v(s["olhar"]) if s.has("olhar") else null)
		"camera_olhar":
			if not who.is_empty():
				stage.camera_look_actor(who, dur)
			else:
				stage.camera_look_point(_v(s["olhar"]), dur)
		"camera_voltar":
			stage.camera_back(dur)
		"luz_no":
			stage.tween_light(s.get("nome", ""), float(s.get("energia", 0.0)), dur)
		"esconder":
			stage.set_actor_visible(who, false)
		"mostrar":
			stage.set_actor_visible(who, true)
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
		"maos_ocultar":
			stage.set_hand_hidden(s.get("lado", "esquerda"), s.get("ocultar", true))
		"maos_cor":
			stage.tint_hands(Color.html(s.get("cor", "#ffffff")), dur)
		"susto":
			# jumpscare: com "who" alguém salta na tela; sem "who" é só o barulho e o tranco
			if who.is_empty():
				stage.scare_impact(s.get("flash", false))
			else:
				var def: Dictionary = chars.get(who, {}).duplicate()
				if s.has("modelo") or def.is_empty():
					def["model"] = s.get("modelo", "zombie_student")
				if s.has("tint"):
					def["tint"] = s["tint"]
				stage.jumpscare(who, def, s)
			Audio.play_sfx(s.get("som", "susto_grito"), float(s.get("volume", 3.0)))
		"silencio":
			Audio.hush(dur)
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
