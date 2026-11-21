extends Control
## Teste de dado estilo Baldur's Gate: d20 + modificadores contra a Classe de
## Dificuldade (CD). O jogador toca para rolar; o dado gira, para, e a tela
## mostra o total, SUCESSO/FALHA (20 natural sempre passa, 1 natural sempre
## falha). Com vantagem rolam dois dados e vale o maior; com desvantagem, o menor.
##
## Uso: var ok: bool = await DiceRoll.new().run(parent, info)
## info = {"nome": "Agilidade", "cd": 12, "mods": [{"texto", "valor"}], "vantagem", "desvantagem"}

signal tapped

const UI := preload("res://scripts/ui/ui_kit.gd")
const GOLD := Color(0.86, 0.68, 0.32)
const GREEN := Color(0.45, 0.9, 0.45)
const ROLL_TIME := 1.35


var _dice: Array = []
var _title: Label
var _dc: Label
var _mods: Label
var _total: Label
var _result: Label
var _hint: Label
var _t := 0.0
var _waiting := false
var _wait_id := 0


func run(parent: Node, info: Dictionary) -> bool:
	parent.add_child(self)
	_build(info)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
	Audio.play_sfx("ui_select")
	_hint.text = "toque para rolar"
	await _wait_tap(7.0)
	_hint.text = ""
	var rolls: Array = await _roll(_dice.size())
	var used: int = rolls[0]
	if _dice.size() == 2:
		used = maxi(rolls[0], rolls[1]) if info.get("vantagem", false) else mini(rolls[0], rolls[1])
		for i in 2:
			if rolls[i] != used or (i == 1 and rolls[0] == rolls[1]):
				_dice[i].dim = true
	var bonus := 0
	for m in info.get("mods", []):
		bonus += int(m.get("valor", 0))
	var total := used + bonus
	var cd := int(info.get("cd", 10))
	var success := total >= cd
	var label := "SUCESSO" if success else "FALHA"
	if used == 20:
		success = true
		label = "SUCESSO CRÍTICO"
	elif used == 1:
		success = false
		label = "FALHA CRÍTICA"
	print("[dado] %s CD %d: d20=%d %+d = %d -> %s" % [info.get("nome", ""), cd, used, bonus, total, label])
	_total.text = "%d %s %d = %d" % [used, "+" if bonus >= 0 else "−", absi(bonus), total]
	_total.visible = true
	_result.text = label
	_result.add_theme_color_override("font_color", GREEN if success else UI.RED)
	_result.visible = true
	_result.scale = Vector2(1.6, 1.6)
	_result.pivot_offset = _result.size * 0.5
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(_result, "scale", Vector2.ONE, 0.35)
	for d in _dice:
		if not d.dim:
			d.show_result(success)
	Audio.play_sfx("dado_sucesso" if success else "dado_falha")
	_hint.text = "toque para continuar"
	await _wait_tap(5.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	await tw.finished
	queue_free()
	return success


func _build(info: Dictionary) -> void:
	UI.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	UI.full_rect(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.anchor_left = 0.06
	box.anchor_right = 0.94
	box.anchor_top = 0.08
	box.anchor_bottom = 0.92
	box.offset_left = 0
	box.offset_right = 0
	box.offset_top = 0
	box.offset_bottom = 0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_title = UI.label("TESTE DE %s" % String(info.get("nome", "")).to_upper(), 48, GOLD, true)
	box.add_child(_title)
	_dc = UI.label("Classe de Dificuldade  %d" % int(info.get("cd", 10)), 46, UI.WHITE)
	box.add_child(_dc)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var two: bool = info.get("vantagem", false) or info.get("desvantagem", false)
	for i in (2 if two else 1):
		var d := _Die3D.new(300 if two else 420)
		row.add_child(d)
		_dice.append(d)
	if two:
		box.add_child(UI.label("VANTAGEM: vale o maior" if info.get("vantagem", false) else "DESVANTAGEM: vale o menor", 40, GOLD))
	var lines: PackedStringArray = []
	for m in info.get("mods", []):
		var v := int(m.get("valor", 0))
		lines.append("%s%d  %s" % ["+" if v >= 0 else "−", absi(v), m.get("texto", "")])
	_mods = UI.label("\n".join(lines), 42, Color(0.78, 0.78, 0.74))
	box.add_child(_mods)
	_total = UI.label("", 64, UI.WHITE, true)
	_total.visible = false
	box.add_child(_total)
	_result = UI.label("", 80, GREEN, true)
	_result.visible = false
	box.add_child(_result)
	_hint = UI.label("", 40, UI.DIM)
	box.add_child(_hint)


func _roll(n: int) -> Array:
	Audio.play_sfx("dado_rolando")
	var vals := []
	for i in n:
		vals.append(randi_range(1, 20))
	for i in n:  # os dois dados rolam juntos, o segundo para um pouco depois
		_dice[i].roll(vals[i], ROLL_TIME + 0.2 * i)
	await get_tree().create_timer(ROLL_TIME + 0.2 * (n - 1) + _Die3D.SETTLE + 0.1).timeout
	return vals


func _wait_tap(max_wait: float) -> void:
	_waiting = true
	_wait_id += 1
	var id := _wait_id
	get_tree().create_timer(max_wait).timeout.connect(_wait_timeout.bind(id))
	await tapped
	_waiting = false


## Segue sozinho depois de um tempo (só vale para a espera atual).
func _wait_timeout(id: int) -> void:
	if _waiting and id == _wait_id:
		tapped.emit()


## O overlay cobre a tela toda: qualquer toque (ou clique/tecla) conta, mesmo que
## a GUI ainda esteja presa ao botão da escolha que acabou de sumir.
func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed) \
		or event.is_action_pressed("ui_accept")
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _waiting:
		tapped.emit()


func _process(delta: float) -> void:
	_t += delta
	if _hint:
		_hint.modulate.a = 0.55 + 0.45 * sin(_t * 4.0)


## O d20 modelado no Blender (tools/blender/make_d20.py), renderizado num
## SubViewport próprio em baixa resolução, com o mesmo visual PSX do jogo.
## Gira devagar esperando o toque, rola, quica e para com o número sorteado de frente.
class _Die3D extends SubViewportContainer:
	const D20 := preload("res://assets/models/d20.glb")
	const Faces := preload("res://scripts/ui/d20_faces.gd")
	const SETTLE := 0.45

	var dim := false:
		set(v):
			dim = v
			modulate = Color(0.38, 0.38, 0.38) if v else Color.WHITE
	var model: Node3D
	var _rim: OmniLight3D
	var _spin := Vector3.ZERO  # eixo * velocidade (rad/s)
	var _idle := true

	func _init(px: int) -> void:
		custom_minimum_size = Vector2(px, px)
		stretch = true
		stretch_shrink = 2  # pixels grandes, como o resto do jogo
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_DISABLED
		add_child(vp)
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.42, 0.36, 0.4)
		env.ambient_light_energy = 0.7
		var we := WorldEnvironment.new()
		we.environment = env
		vp.add_child(we)
		var cam := Camera3D.new()
		cam.position = Vector3(0, 0, 4.4)
		cam.fov = 34.0
		vp.add_child(cam)
		var key := DirectionalLight3D.new()
		key.rotation_degrees = Vector3(-38, 28, 0)
		key.light_energy = 1.25
		key.light_color = Color(1.0, 0.94, 0.86)
		vp.add_child(key)
		var fill := OmniLight3D.new()  # vela de baixo, quente
		fill.position = Vector3(-1.4, -1.6, 2.2)
		fill.light_color = Color(1.0, 0.55, 0.25)
		fill.light_energy = 1.2
		fill.omni_range = 5.0
		vp.add_child(fill)
		_rim = OmniLight3D.new()  # acende verde/vermelho no resultado
		_rim.position = Vector3(1.5, 1.3, 1.8)
		_rim.light_energy = 0.0
		_rim.omni_range = 5.0
		vp.add_child(_rim)
		model = D20.instantiate()
		model.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		vp.add_child(model)

	func _process(delta: float) -> void:
		if model == null:
			return
		if _idle:
			model.rotate(Vector3(0.3, 1.0, 0.15).normalized(), delta * 0.7)
		elif _spin.length() > 0.001:
			model.rotate(_spin.normalized(), _spin.length() * delta)
		model.transform.basis = model.transform.basis.orthonormalized()

	## Rola por `dur` segundos e para com `value` virado para a câmera.
	func roll(value: int, dur: float) -> void:
		_idle = false
		var axis := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var speed := randf_range(17.0, 23.0)
		_spin = axis * speed
		var tw := create_tween()
		tw.tween_method(func(k: float) -> void: _spin = axis * k, speed, 2.5, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var hop := create_tween()  # quica duas vezes
		for h in [0.42, 0.16]:
			hop.tween_property(model, "position:y", h, dur * 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			hop.tween_property(model, "position:y", 0.0, dur * 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		_spin = Vector3.ZERO
		var q0 := model.quaternion
		var q1 := _face_quat(value)
		var settle := create_tween()
		settle.tween_method(func(k: float) -> void: model.quaternion = q0.slerp(q1, k), 0.0, 1.0, SETTLE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	## Rotação que deixa a face `value` de frente, com o número em pé
	## (e uma leve inclinação para o dado não parecer chapado).
	func _face_quat(value: int) -> Quaternion:
		var f: Array = Faces.FACES[value]
		var n: Vector3 = f[0]
		var up: Vector3 = f[1]
		var local := Basis(up.cross(n), up, n)  # colunas: direita, cima, normal
		var r := Basis(Vector3.RIGHT, deg_to_rad(-9.0)) * Basis(Vector3.UP, deg_to_rad(6.0)) * local.transposed()
		return r.get_rotation_quaternion()

	func show_result(ok: bool) -> void:
		_rim.light_color = Color(0.35, 1.0, 0.45) if ok else Color(1.0, 0.12, 0.08)
		create_tween().tween_property(_rim, "light_energy", 4.5, 0.25)
		model.scale = Vector3.ONE * 1.16
		create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(model, "scale", Vector3.ONE, 0.35)
