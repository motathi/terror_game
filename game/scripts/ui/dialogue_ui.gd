extends Control
## Camada de UI do jogo: legendas (estilo TikTok), escolhas com timer,
## cartela de horário/lugar, fades e tela de final.

signal choice_made(index: int)
signal screen_tapped(position: Vector2)

const UI := preload("res://scripts/ui/ui_kit.gd")
const KIND_LABEL := {
	"morte": "VOCÊ MORREU",
	"sobreviveu": "VOCÊ SOBREVIVEU",
	"agridoce": "VOCÊ SOBREVIVEU... MAS",
	"secreto": "FINAL SECRETO",
}

var _subtitle_panel: PanelContainer
var _speaker: Label
var _text: Label
var _next_hint: Label
var _choice_box: VBoxContainer
var _prompt: Label
var _timer_bg: Control
var _timer_fg: ColorRect
var _buttons_box: VBoxContainer
var _title_card: Label
var _fade: ColorRect
var _ending_layer: Control
var _phone: PanelContainer
var _phone_head: Label
var _phone_body: Label
var _phone_tween: Tween

var _advance := false
var _choice_active := false
var _time_left := 0.0
var _time_total := 0.0
var _beat_played := false
var _hint_t := 0.0


func _ready() -> void:
	UI.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# --- legenda ---
	_subtitle_panel = PanelContainer.new()
	_subtitle_panel.add_theme_stylebox_override("panel", UI.panel_style())
	_subtitle_panel.anchor_left = 0.04
	_subtitle_panel.anchor_right = 0.96
	_subtitle_panel.anchor_top = 0.8
	_subtitle_panel.anchor_bottom = 0.8
	_subtitle_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_subtitle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_subtitle_panel)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_panel.add_child(v)
	_speaker = UI.label("", 26, UI.RED, true)
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(_speaker)
	_text = UI.label("", 40)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(_text)
	_next_hint = UI.label(">>", 26, UI.DIM)
	_next_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_next_hint)
	_subtitle_panel.visible = false

	# --- escolhas ---
	_choice_box = VBoxContainer.new()
	_choice_box.anchor_left = 0.04
	_choice_box.anchor_right = 0.96
	_choice_box.anchor_top = 1.0
	_choice_box.anchor_bottom = 1.0
	_choice_box.offset_bottom = -40
	_choice_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_choice_box.add_theme_constant_override("separation", 14)
	_choice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_choice_box)
	_prompt = UI.label("", 44, UI.WHITE, false)
	_choice_box.add_child(_prompt)
	_timer_bg = ColorRect.new()
	(_timer_bg as ColorRect).color = Color(1, 1, 1, 0.15)
	_timer_bg.custom_minimum_size = Vector2(0, 10)
	_timer_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_box.add_child(_timer_bg)
	_timer_fg = ColorRect.new()
	_timer_fg.color = UI.RED
	_timer_fg.anchor_bottom = 1.0
	_timer_fg.anchor_right = 1.0
	_timer_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_bg.add_child(_timer_fg)
	_buttons_box = VBoxContainer.new()
	_buttons_box.add_theme_constant_override("separation", 14)
	_choice_box.add_child(_buttons_box)
	_choice_box.visible = false

	# --- cartela ---
	_title_card = UI.label("", 52, UI.WHITE, true)
	_title_card.anchor_left = 0.0
	_title_card.anchor_right = 1.0
	_title_card.anchor_top = 0.12
	_title_card.anchor_bottom = 0.12
	_title_card.modulate.a = 0.0
	add_child(_title_card)

	_build_phone()

	# --- fade ---
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	UI.full_rect(_fade)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	_ending_layer = Control.new()
	UI.full_rect(_ending_layer)
	_ending_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ending_layer)


# --- tela do celular (nítida, na interface: na cena 3D o texto vira borrão) ----------

func _build_phone() -> void:
	_phone = PanelContainer.new()
	var frame := UI.panel_style(Color(0.06, 0.06, 0.07, 0.97), 34, Color(0.32, 0.32, 0.36))
	frame.content_margin_left = 16
	frame.content_margin_right = 16
	frame.content_margin_top = 30
	frame.content_margin_bottom = 30
	_phone.add_theme_stylebox_override("panel", frame)
	_phone.anchor_left = 0.18
	_phone.anchor_right = 0.82
	_phone.anchor_top = 0.16
	_phone.anchor_bottom = 0.16
	_phone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phone.pivot_offset = Vector2(230, 150)
	add_child(_phone)
	var screen := PanelContainer.new()
	var glow := UI.panel_style(Color(0.1, 0.16, 0.26), 18)
	glow.content_margin_top = 18
	glow.content_margin_bottom = 22
	screen.add_theme_stylebox_override("panel", glow)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phone.add_child(screen)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(v)
	_phone_head = UI.label("", 30, Color(0.55, 0.85, 1.0), true)
	v.add_child(_phone_head)
	_phone_body = UI.label("", 40, Color(0.93, 0.96, 1.0))
	v.add_child(_phone_body)
	_phone.visible = false


## Mostra a tela do celular. A primeira linha (se houver mais de uma) é o
## cabeçalho (contato/hora). Texto vazio guarda o celular.
func show_phone(text: String) -> void:
	if _phone_tween and _phone_tween.is_valid():
		_phone_tween.kill()
	if text.strip_edges().is_empty():
		if _phone.visible:
			_phone_tween = create_tween()
			_phone_tween.tween_property(_phone, "modulate:a", 0.0, 0.25)
			_phone_tween.tween_callback(_phone.hide)
		return
	var lines := text.split("\n")
	if lines.size() > 1:
		_phone_head.text = lines[0].strip_edges().trim_suffix(":")
		_phone_head.visible = true
		lines.remove_at(0)
		_phone_body.text = "\n".join(lines)
	else:
		_phone_head.visible = false
		_phone_body.text = text
	if not _phone.visible:
		_phone.modulate.a = 0.0
	_phone.visible = true
	_phone.pivot_offset = _phone.size * 0.5
	_phone_tween = create_tween()
	_phone_tween.tween_property(_phone, "modulate:a", 1.0, 0.2)
	for i in 4:  # vibra
		_phone_tween.tween_property(_phone, "rotation", 0.035 if i % 2 == 0 else -0.035, 0.05)
	_phone_tween.tween_property(_phone, "rotation", 0.0, 0.05)


func _process(delta: float) -> void:
	_hint_t += delta
	_next_hint.modulate.a = 0.4 + 0.6 * absf(sin(_hint_t * 3.0))
	if _choice_active and _time_total > 0.0:
		_time_left -= delta
		var r := clampf(_time_left / _time_total, 0.0, 1.0)
		_timer_fg.anchor_right = r
		if _time_left < 3.0 and not _beat_played:
			_beat_played = true
			Audio.play_sfx("coracao")
		if _time_left <= 0.0:
			_finish_choice(-1)


func _unhandled_input(event: InputEvent) -> void:
	var pressed := false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
		pos = event.position
	elif event.is_action_pressed("ui_accept"):
		pressed = true
	if not pressed:
		return
	if _choice_active:
		if _choice_box.get_global_rect().has_point(pos):
			return  # toque nos botões: deixa o Button tratar
		screen_tapped.emit(pos)
	else:
		_advance = true
	get_viewport().set_input_as_handled()


# --- legendas --------------------------------------------------------------------

## Mostra uma fala com efeito de máquina de escrever e espera o jogador
## (ou o fim da voz, se `auto`).
func present_line(speaker: String, text: String, phone: bool, auto: bool) -> void:
	_subtitle_panel.visible = true
	_speaker.visible = not speaker.is_empty()
	_speaker.text = speaker.to_upper() + ("  ·  CELULAR" if phone else "")
	_text.text = text
	_text.add_theme_color_override("font_color", UI.DIM if speaker.is_empty() else UI.WHITE)
	_text.visible_characters = 0
	_next_hint.visible = false
	_advance = false
	var speed: float = GameState.settings.get("text_speed", 45.0)
	var total := text.length()
	var t := 0.0
	while _text.visible_characters < total and not _advance:
		await get_tree().process_frame
		t += get_process_delta_time()
		_text.visible_characters = mini(int(t * speed), total)
	_text.visible_characters = -1
	_advance = false
	_next_hint.visible = true
	var read_time := 0.9 + total * 0.035
	var waited := 0.0
	while not _advance:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if auto and waited >= read_time and not Audio.is_voice_playing():
			break
	_advance = false


## Legenda que não espera o jogador (usada nas cinemáticas).
func show_caption(speaker: String, text: String) -> void:
	_subtitle_panel.visible = true
	_speaker.visible = not speaker.is_empty()
	_speaker.text = speaker.to_upper()
	_text.text = text
	_text.add_theme_color_override("font_color", UI.DIM if speaker.is_empty() else UI.WHITE)
	_text.visible_characters = -1
	_next_hint.visible = false


## true se o jogador tocou na tela desde a última chamada.
func consume_tap() -> bool:
	var t := _advance
	_advance = false
	return t


func hide_subtitle() -> void:
	_subtitle_panel.visible = false


# --- escolhas --------------------------------------------------------------------

## Retorna o índice escolhido ou -1 se o tempo acabou.
func present_choice(prompt: String, options: PackedStringArray, timer: float, gold: Array = []) -> int:
	hide_subtitle()
	for c in _buttons_box.get_children():
		c.queue_free()
	_prompt.text = prompt
	for i in options.size():
		# opções com teste de dado ficam douradas (estilo Baldur's Gate)
		var is_test: bool = i < gold.size() and gold[i]
		var col: Color = Color(0.92, 0.74, 0.36) if is_test else UI.WHITE
		var b := UI.button(options[i], 40, col)
		b.pressed.connect(_finish_choice.bind(i))
		_buttons_box.add_child(b)
	_time_total = timer if GameState.settings.get("timers", true) else 0.0
	_time_left = _time_total
	_timer_bg.visible = _time_total > 0.0
	_timer_fg.anchor_right = 1.0
	_beat_played = false
	_choice_box.visible = true
	_choice_box.modulate.a = 0.0
	create_tween().tween_property(_choice_box, "modulate:a", 1.0, 0.25)
	_choice_active = true
	var idx: int = await choice_made
	return idx


func force_choice(index: int) -> void:
	if _choice_active:
		_finish_choice(index)


func _finish_choice(index: int) -> void:
	if not _choice_active:
		return
	_choice_active = false
	_choice_box.visible = false
	Audio.play_sfx("ui_select")
	choice_made.emit(index)


# --- cartela / fade ----------------------------------------------------------------

func show_title_card(text: String) -> void:
	_title_card.text = text
	var tw := create_tween()
	tw.tween_property(_title_card, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.6)
	tw.tween_property(_title_card, "modulate:a", 0.0, 0.6)
	await get_tree().create_timer(0.9).timeout


func fade_out(duration := 0.5) -> void:
	await create_tween().tween_property(_fade, "color:a", 1.0, duration).finished


func fade_in(duration := 0.6) -> void:
	await create_tween().tween_property(_fade, "color:a", 0.0, duration).finished


# --- final --------------------------------------------------------------------------

## Mostra o final e devolve a ação escolhida: "replay", "endings" ou "menu".
func show_ending(data: Dictionary, is_new: bool, found: int, total: int) -> String:
	hide_subtitle()
	for c in _ending_layer.get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.88)
	UI.full_rect(bg)
	_ending_layer.add_child(bg)
	var box := VBoxContainer.new()
	box.anchor_left = 0.07
	box.anchor_right = 0.93
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 22)
	_ending_layer.add_child(box)

	var kind: String = data.get("kind", "morte")
	box.add_child(UI.label(KIND_LABEL.get(kind, "FIM"), 30, UI.DIM, true))
	box.add_child(UI.label(String(data.get("title", "")).to_upper(), 60, UI.RED, true))
	box.add_child(UI.label(data.get("text", ""), 42))
	var extra: String = data.get("extra_text", "")
	if not extra.is_empty():
		box.add_child(UI.label(extra, 38, UI.DIM))
	if is_new:
		box.add_child(UI.label("* NOVO FINAL DESBLOQUEADO *", 28, Color(1, 0.85, 0.3), true))
	box.add_child(UI.label("%d / %d FINAIS" % [found, total], 36, UI.WHITE, true))
	box.add_child(UI.label("Qual final você pegou? Comenta aí.", 32, UI.DIM))

	var actions := ["replay", "endings", "menu"]
	var labels := ["JOGAR DE NOVO", "VER FINAIS", "MENU"]
	var result := [""]
	for i in actions.size():
		var b := UI.button(labels[i], 38)
		b.custom_minimum_size.y = 88
		b.pressed.connect(func(): result[0] = actions[i])
		box.add_child(b)
	_ending_layer.modulate.a = 0.0
	await create_tween().tween_property(_ending_layer, "modulate:a", 1.0, 1.2).finished
	while result[0] == "":
		await get_tree().process_frame
	return result[0]
