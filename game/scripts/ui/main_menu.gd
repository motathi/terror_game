extends Control
## Menu principal: carrossel de campanhas com fundo 3D ao vivo (o monstro de
## cada campanha no seu cenário), estética de fita VHS e cards de campanha.
## As campanhas vêm de res://story/campanhas.json.

const UI := preload("res://scripts/ui/ui_kit.gd")
const Stage := preload("res://scripts/stage/stage.gd")
const StoryRunner := preload("res://scripts/story/story_runner.gd")
const POST_SHADER := preload("res://shaders/psx_post.gdshader")
const PIXEL_SHRINK := 4
const AssetLib := preload("res://scripts/stage/asset_lib.gd")
const Locations := preload("res://scripts/stage/locations.gd")

var stage: Stage
var post: ShaderMaterial
var index := 0
var _t := 0.0
var _touch_x := -1.0
var _drag_acc := 0.0
var _swiped := false
var _menu_light: OmniLight3D
var _back_light: OmniLight3D
var _extras: Node3D  # disco voador, figuras ao fundo etc. da campanha atual
var _beam: SpotLight3D

# widgets
var _title_red: Label
var _title_cyan: Label
var _rec_dot: ColorRect
var _clock: Label
var _counter: Label
var _badge: Label
var _camp_title: Label
var _camp_sub: Label
var _camp_text: Label
var _camp_meta: Label
var _play: Button
var _endings: Button
var _dots: HBoxContainer
var _card: Control


func _ready() -> void:
	UI.full_rect(self)
	_build_3d()
	_build_overlay()
	_build_card()
	Audio.play_ambience("")
	Audio.set_location("")
	Audio.play_music("tema")
	index = GameState.campaign_index()
	_select(index, false)
	_play.grab_focus()
	if not GameState.debug_start_node.is_empty() or not GameState.debug_ending.is_empty():
		_on_play.call_deferred()


# --- construção ------------------------------------------------------------------

func _build_3d() -> void:
	var svc := SubViewportContainer.new()
	UI.full_rect(svc)
	svc.stretch = true
	svc.stretch_shrink = PIXEL_SHRINK
	svc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post = ShaderMaterial.new()
	post.shader = POST_SHADER
	post.set_shader_parameter("scanlines", 0.7)
	post.set_shader_parameter("grain", 0.1)
	svc.material = post
	add_child(svc)
	var sv := SubViewport.new()
	svc.add_child(sv)
	stage = Stage.new()
	stage.title_font = UI.title_font()
	stage.body_font = UI.body_font()
	stage.post_material = post
	sv.add_child(stage)
	_menu_light = OmniLight3D.new()
	_menu_light.omni_range = 5.0
	_menu_light.light_energy = 1.6
	stage.add_child(_menu_light)
	_extras = Node3D.new()
	stage.add_child(_extras)
	_back_light = OmniLight3D.new()
	_back_light.omni_range = 7.0
	_back_light.light_energy = 5.0
	stage.add_child(_back_light)
	_beam = SpotLight3D.new()
	_beam.spot_range = 14.0
	_beam.spot_angle = 14.0
	_beam.light_energy = 6.0
	_beam.rotation_degrees = Vector3(-90, 0, 0)
	stage.add_child(_beam)

	# escurece a parte de baixo para o card ficar legível
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.95))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var shade := TextureRect.new()
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.anchor_right = 1.0
	shade.anchor_top = 0.42
	shade.anchor_bottom = 1.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _build_overlay() -> void:
	# OSD de câmera VHS
	var rec := HBoxContainer.new()
	rec.position = Vector2(28, 26)
	rec.add_theme_constant_override("separation", 10)
	rec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rec)
	_rec_dot = ColorRect.new()
	_rec_dot.color = Color(0.95, 0.1, 0.1)
	_rec_dot.custom_minimum_size = Vector2(16, 16)
	_rec_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rec.add_child(_rec_dot)
	var play_lbl := UI.label("PLAY", 34, UI.WHITE)
	play_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	rec.add_child(play_lbl)
	_clock = UI.label("", 30, UI.WHITE)
	_clock.autowrap_mode = TextServer.AUTOWRAP_OFF
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock.anchor_left = 1.0
	_clock.anchor_right = 1.0
	_clock.offset_left = -300
	_clock.offset_right = -28
	_clock.offset_top = 26
	add_child(_clock)

	# título com aberração cromática
	_title_cyan = UI.label("ESCOLHA-ME", 72, Color(0.2, 0.9, 1.0, 0.55), true)
	_title_red = UI.label("ESCOLHA-ME", 72, UI.RED, true)
	for l in [_title_cyan, _title_red]:
		l.anchor_right = 1.0
		l.offset_top = 78
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		add_child(l)
	var tag := UI.label("escolha. sobreviva. ou não.", 28, UI.DIM)
	tag.anchor_right = 1.0
	tag.offset_top = 168
	add_child(tag)


func _build_card() -> void:
	_card = VBoxContainer.new()
	_card.anchor_left = 0.06
	_card.anchor_right = 0.94
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.offset_bottom = -34
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.add_theme_constant_override("separation", 12)
	add_child(_card)

	var head := HBoxContainer.new()
	_card.add_child(head)
	_counter = UI.label("", 26, UI.DIM, true)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_counter)
	_badge = UI.label("", 24, UI.WHITE, true)
	_badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(_badge)

	_camp_title = UI.label("", 62, UI.RED, true)
	_camp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_card.add_child(_camp_title)
	_camp_sub = UI.label("", 32, UI.DIM)
	_camp_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_card.add_child(_camp_sub)
	_camp_text = UI.label("", 36, UI.WHITE)
	_camp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_camp_text.custom_minimum_size.y = 110
	_card.add_child(_camp_text)
	_camp_meta = UI.label("", 28, UI.DIM, true)
	_camp_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_card.add_child(_camp_meta)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_card.add_child(row)
	var prev := UI.button("<", 48)
	prev.custom_minimum_size = Vector2(96, 112)
	prev.pressed.connect(func(): _select(index - 1))
	row.add_child(prev)
	_play = UI.button("JOGAR", 50)
	_play.custom_minimum_size.y = 112
	_play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play.pressed.connect(_on_play)
	row.add_child(_play)
	var nxt := UI.button(">", 48)
	nxt.custom_minimum_size = Vector2(96, 112)
	nxt.pressed.connect(func(): _select(index + 1))
	row.add_child(nxt)

	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 14)
	_card.add_child(_dots)
	for i in GameState.campaigns.size():
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(14, 14)
		_dots.add_child(d)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	_card.add_child(bottom)
	_endings = UI.button("FINAIS", 30, UI.DIM)
	_endings.custom_minimum_size.y = 76
	_endings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_endings.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/endings_gallery.tscn"))
	bottom.add_child(_endings)
	var timers := UI.button(_timers_text(), 30, UI.DIM)
	timers.custom_minimum_size.y = 76
	timers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timers.pressed.connect(func():
		GameState.settings["timers"] = not GameState.settings.get("timers", true)
		GameState.save()
		timers.text = _timers_text())
	bottom.add_child(timers)


# --- carrossel ---------------------------------------------------------------------

func _select(i: int, animate := true) -> void:
	var n := GameState.campaigns.size()
	if n == 0:
		return
	index = wrapi(i, 0, n)
	var c: Dictionary = GameState.campaigns[index]
	var available: bool = c.get("status", "") == "disponivel"
	var accent := Color.html(c.get("cor", "#d01818"))
	GameState.settings["menu_campaign"] = index
	if available:
		GameState.current_campaign = c["path"]

	if animate:
		Audio.play_sfx("ui_cursor")
		var tw := create_tween()
		tw.tween_method(func(v): post.set_shader_parameter("static_amount", v), 0.85, 0.0, 0.4)
		_card.modulate.a = 0.0
		create_tween().tween_property(_card, "modulate:a", 1.0, 0.3)

	# fundo 3D
	var cena: Dictionary = c.get("cena", {})
	stage.set_location(cena.get("location", "garagem"))
	stage.hands.visible = false
	stage.location_cfg["approach_center"] = false
	var dist: float = cena.get("dist", 2.8)
	var floor_y: float = stage.location_cfg.get("floor_y", 0.0)
	stage.location_cfg["slots"] = {"center": Vector3(0, floor_y, -dist)}
	stage.set_camera(Vector3(0, 1.2 + floor_y, 0), Vector3(0, -0.2 + floor_y, -dist))
	var def := {"name": "", "model": cena.get("model", "zombie_student")}
	for k in ["tint", "pelagem", "em_pe", "altura", "olhos", "anexos", "magro"]:
		if cena.has(k):
			def[k] = cena[k]
	var chars := {c["id"]: def}
	stage.set_cast({"center": {"char": c["id"], "anim": cena.get("anim", "")}}, chars)
	var luz := Color.html(cena.get("luz", "#ffffff"))
	# luz de frente fraca + contraluz forte: o monstro vira silhueta recortada
	_menu_light.light_color = luz
	_menu_light.light_energy = 1.6 if available else 0.5
	_menu_light.position = Vector3(0.6, 2.6 + floor_y, -dist + 1.4)
	_back_light.light_color = luz
	_back_light.position = Vector3(0, 1.6 + floor_y, -dist - 1.6)
	stage.env.fog_light_color = luz * 0.35
	stage.env.fog_density = 0.07
	stage.env.background_color = luz * 0.08
	_build_extras(cena, floor_y)
	_beam.visible = cena.get("feixe", false)
	_beam.light_color = luz
	_beam.position = Vector3(0, 9.0 + floor_y, -dist)

	# card
	_counter.text = "CAMPANHA %d/%d" % [index + 1, n]
	_camp_title.text = String(c.get("titulo", ""))
	_camp_title.add_theme_color_override("font_color", accent)
	_camp_sub.text = String(c.get("subtitulo", ""))
	_camp_text.text = String(c.get("chamada", ""))
	if available:
		_badge.text = "DISPONÍVEL"
		_badge.add_theme_color_override("font_color", accent)
		var total := _endings_total(c)
		var found := GameState.count_discovered(c["id"])
		_camp_meta.text = "%d FINAIS  ·  %d DESCOBERTOS" % [total, found]
		_play.text = "JOGAR"
		_play.disabled = false
		_endings.disabled = false
	else:
		_badge.text = "EM BREVE"
		_badge.add_theme_color_override("font_color", UI.DIM)
		_camp_meta.text = "[ BLOQUEADO ]  NOVA CAMPANHA EM BREVE"
		_play.text = "EM BREVE"
		_play.disabled = true
		_endings.disabled = true
	for k in _dots.get_child_count():
		var d := _dots.get_child(k) as ColorRect
		d.color = accent if k == index else Color(1, 1, 1, 0.25)
		d.custom_minimum_size = Vector2(28 if k == index else 14, 14)


## Elementos extras do fundo: "ovni" (disco voador com feixe) e "extras"
## (lista de modelos: model, pos [x,y,z], rot, escala, tint, anim).
func _build_extras(cena: Dictionary, floor_y: float) -> void:
	for ch in _extras.get_children():
		ch.queue_free()
	if cena.has("ovni"):
		var o: Dictionary = cena["ovni"]
		var p: Array = o.get("pos", [0, 7, -9])
		var u := Locations.ufo(_extras, Vector3(p[0], p[1] + floor_y, p[2]), Color.html(o.get("cor", "#66ff88")))
		u.scale = Vector3.ONE * float(o.get("escala", 1.0))
	for e in cena.get("extras", []):
		var n := AssetLib.spawn(AssetLib.model_path(e.get("model", "")), Vector3.ONE, "human")
		AssetLib.psxify(n, Color.html(e.get("tint", "#ffffff")))
		var p: Array = e.get("pos", [0, 0, -6])
		n.position = Vector3(p[0], p[1] + floor_y, p[2])
		n.rotation.y = deg_to_rad(float(e.get("rot", 0.0)))
		n.scale = Vector3.ONE * float(e.get("escala", 1.0))
		_extras.add_child(n)
		var ap := AssetLib.find_animation_player(n)
		var anim := AssetLib.find_animation(ap, e.get("anim", ""))
		if not anim.is_empty():
			ap.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
			ap.play(anim)
		if e.get("flutua", false):
			n.add_child(Locations.Hover.new())


func _endings_total(c: Dictionary) -> int:
	var runner := StoryRunner.new()
	if runner.load_file(c.get("path", "")):
		return runner.ending_ids().size()
	return 0


func _on_play() -> void:
	var c: Dictionary = GameState.campaigns[index] if index < GameState.campaigns.size() else {}
	if c.get("status", "") != "disponivel":
		return
	GameState.current_campaign = c["path"]
	GameState.save()
	Audio.play_sfx("stinger_hit")
	stage.scare_flash()
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _timers_text() -> String:
	return "TEMPO: " + ("LIGADO" if GameState.settings.get("timers", true) else "DESLIGADO")


# --- entrada e animação ----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# arrastar para os lados troca de campanha (lido em _input para funcionar
	# mesmo quando o gesto começa em cima de um texto/botão)
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_x = event.position.x
			_drag_acc = 0.0
			_swiped = false
		else:
			_touch_x = -1.0
	elif event is InputEventScreenDrag and _touch_x >= 0.0 and not _swiped:
		_drag_acc += event.relative.x
		if absf(_drag_acc) > 70.0:
			_swiped = true
			_select(index + (-1 if _drag_acc > 0 else 1))
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _touch_x >= 0.0 and not _swiped and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_drag_acc += event.relative.x
		if absf(_drag_acc) > 70.0:
			_swiped = true
			_select(index + (-1 if _drag_acc > 0 else 1))
	elif event.is_action_pressed("ui_left"):
		_select(index - 1)
	elif event.is_action_pressed("ui_right"):
		_select(index + 1)


func _process(delta: float) -> void:
	_t += delta
	_rec_dot.visible = fmod(_t, 1.2) < 0.7
	var secs := int(_t) + 17 * 3600 + 48 * 60
	_clock.text = "SEX %02d:%02d:%02d" % [(secs / 3600) % 24, (secs / 60) % 60, secs % 60]
	# glitch ocasional no título
	var glitch := randf() < 0.03
	_title_cyan.position.x = (randf_range(-10, 10) if glitch else 4.0)
	_title_red.position.x = (randf_range(-6, 6) if glitch else 0.0)
	_title_red.modulate.a = randf_range(0.6, 1.0) if glitch else 1.0
