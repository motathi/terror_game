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
			d.color = GREEN if success else UI.RED
			d.queue_redraw()
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
	box.anchor_top = 0.14
	box.anchor_bottom = 0.86
	box.offset_left = 0
	box.offset_right = 0
	box.offset_top = 0
	box.offset_bottom = 0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_title = UI.label("TESTE DE %s" % String(info.get("nome", "")).to_upper(), 40, GOLD, true)
	box.add_child(_title)
	_dc = UI.label("Classe de Dificuldade  %d" % int(info.get("cd", 10)), 34, UI.WHITE)
	box.add_child(_dc)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var two: bool = info.get("vantagem", false) or info.get("desvantagem", false)
	for i in (2 if two else 1):
		var d := _Die.new()
		d.custom_minimum_size = Vector2(300, 300) if not two else Vector2(250, 250)
		d.font = UI.title_font()
		row.add_child(d)
		_dice.append(d)
	if two:
		box.add_child(UI.label("VANTAGEM: vale o maior" if info.get("vantagem", false) else "DESVANTAGEM: vale o menor", 30, GOLD))
	var lines: PackedStringArray = []
	for m in info.get("mods", []):
		var v := int(m.get("valor", 0))
		lines.append("%s%d  %s" % ["+" if v >= 0 else "−", absi(v), m.get("texto", "")])
	_mods = UI.label("\n".join(lines), 32, UI.DIM)
	box.add_child(_mods)
	_total = UI.label("", 44, UI.WHITE, true)
	_total.visible = false
	box.add_child(_total)
	_result = UI.label("", 56, GREEN, true)
	_result.visible = false
	box.add_child(_result)
	_hint = UI.label("", 30, UI.DIM)
	box.add_child(_hint)


func _roll(n: int) -> Array:
	Audio.play_sfx("dado_rolando")
	var vals := []
	for i in n:
		vals.append(randi_range(1, 20))
	var t := 0.0
	var step := 0.04
	while t < 1.4:
		for i in n:
			var d: _Die = _dice[i]
			d.value = randi_range(1, 20)
			d.spin = randf_range(-0.6, 0.6)
			d.queue_redraw()
		await get_tree().create_timer(step).timeout
		t += step
		step = minf(step * 1.12, 0.16)
	for i in n:
		var d: _Die = _dice[i]
		d.value = vals[i]
		d.spin = 0.0
		d.pop = 1.25
		d.queue_redraw()
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


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed)
	if pressed and _waiting:
		accept_event()
		tapped.emit()


func _process(delta: float) -> void:
	_t += delta
	if _hint:
		_hint.modulate.a = 0.55 + 0.45 * sin(_t * 4.0)


## Um d20 visto de frente: hexágono com o triângulo central e as faces em volta.
class _Die extends Control:
	var value := 20
	var color := Color(0.86, 0.68, 0.32)
	var dim := false
	var spin := 0.0
	var pop := 1.0
	var font: Font

	func _process(delta: float) -> void:
		if pop > 1.0:
			pop = move_toward(pop, 1.0, delta * 1.5)
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.46 * pop
		var col: Color = color.darkened(0.55) if dim else color
		var hexa := PackedVector2Array()
		for k in 6:
			var a := deg_to_rad(-90 + 60 * k) + spin
			hexa.append(c + Vector2(cos(a), sin(a)) * r)
		var tri := PackedVector2Array()
		for k in 3:
			var a := deg_to_rad(-90 + 120 * k) + spin
			tri.append(c + Vector2(cos(a), sin(a)) * r * 0.58)
		draw_colored_polygon(hexa, Color(0.08, 0.05, 0.05, 0.95))
		draw_colored_polygon(tri, col.darkened(0.35))
		var outline := hexa.duplicate()
		outline.append(hexa[0])
		draw_polyline(outline, col, 5.0)
		var t2 := tri.duplicate()
		t2.append(tri[0])
		draw_polyline(t2, col, 4.0)
		for j in 3:  # arestas das faces em volta do triângulo central
			draw_line(hexa[2 * j], tri[j], col, 3.0)
			draw_line(hexa[2 * j + 1], tri[j], col, 3.0)
			draw_line(hexa[2 * j + 1], tri[(j + 1) % 3], col, 3.0)
		if font:
			var txt := str(value)
			var fs := int(r * 0.62)
			var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			draw_string(font, c + Vector2(-w * 0.5, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				Color(0.4, 0.4, 0.4) if dim else Color(1, 0.97, 0.9))
