extends Node3D
## Um personagem em cena: modelo + animação + nome flutuante (estilo trend)
## + palavra de súplica ("Por favor") que treme na hora da escolha.

const AssetLib := preload("res://scripts/stage/asset_lib.gd")
const LOOPING := ["idle", "walk", "run", "talk", "sit", "zombieidle", "zombiewalk"]

var char_id := ""
var display_name := ""
var model: Node3D
var anim_player: AnimationPlayer
var name_label: Label3D
var plead_label: Label3D
var head_height := 1.85
var _current_anim := ""
var _t := randf() * 10.0
var _plead_active := false
var _base_y := 0.0


func setup(id: String, def: Dictionary, slot_def: Dictionary, title_font: Font, body_font: Font) -> void:
	char_id = id
	display_name = def.get("name", "")
	var offscreen: String = slot_def.get("offscreen", "")
	if offscreen == "porta":
		# Personagem escondido atrás de uma porta: só a porta e o nome.
		model = _build_door()
		add_child(model)
		head_height = 2.3
	else:
		var path := AssetLib.model_path(def.get("model", ""))
		model = AssetLib.spawn(path, Vector3.ONE, "human")
		var tint := Color.WHITE
		if def.has("tint"):
			tint = Color.html(def["tint"])
		AssetLib.psxify(model, tint)
		add_child(model)
		anim_player = AssetLib.find_animation_player(model)
	_base_y = position.y

	name_label = _make_label(title_font, 44, Color.WHITE)
	name_label.text = display_name
	name_label.position.y = head_height + 0.22
	add_child(name_label)

	plead_label = _make_label(body_font, 64, Color(1, 1, 1))
	plead_label.position.y = head_height * 0.62
	plead_label.visible = false
	add_child(plead_label)

	play(slot_def.get("anim", "Idle"))


func play(anim: String, blend := 0.25) -> void:
	if anim_player == null or anim.is_empty():
		return
	var found := AssetLib.find_animation(anim_player, anim)
	if found.is_empty() or found == _current_anim:
		return
	var a := anim_player.get_animation(found)
	if a != null and anim.to_lower() in LOOPING:
		a.loop_mode = Animation.LOOP_LINEAR
	anim_player.play(found, blend)
	_current_anim = found


func set_plead(text: String) -> void:
	_plead_active = not text.is_empty()
	plead_label.text = text
	plead_label.visible = _plead_active


func set_name_visible(v: bool) -> void:
	name_label.visible = v and not display_name.is_empty()


func chest_position() -> Vector3:
	return global_position + Vector3(0, head_height * 0.6, 0)


func _process(delta: float) -> void:
	_t += delta
	if anim_player == null and model != null:
		# Sem animação: respiração/balanço procedural.
		model.position.y = sin(_t * 1.7) * 0.012
		model.rotation.z = sin(_t * 0.9) * 0.02
	if _plead_active:
		# Tremor de súplica, como nos vídeos.
		plead_label.position.x = sin(_t * 31.0) * 0.012
		plead_label.position.y = head_height * 0.62 + sin(_t * 23.0) * 0.01


func _build_door() -> Node3D:
	var door := Node3D.new()
	var parts := [
		[Vector3(0.95, 2.05, 0.06), Vector3(0, 1.025, 0), Color(0.36, 0.24, 0.16), 0.0],  # folha
		[Vector3(0.08, 2.15, 0.12), Vector3(-0.51, 1.075, 0), Color(0.85, 0.82, 0.75), 0.0],  # batente
		[Vector3(0.08, 2.15, 0.12), Vector3(0.51, 1.075, 0), Color(0.85, 0.82, 0.75), 0.0],
		[Vector3(1.1, 0.08, 0.12), Vector3(0, 2.15, 0), Color(0.85, 0.82, 0.75), 0.0],
		[Vector3(0.06, 0.06, 0.08), Vector3(0.36, 1.0, 0.05), Color(0.8, 0.7, 0.3), 0.0],  # maçaneta
		[Vector3(0.9, 0.02, 0.3), Vector3(0, 0.01, 0.15), Color(1.0, 0.75, 0.4), 2.5],  # luz por baixo da porta
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = p[0]
		mi.mesh = m
		mi.position = p[1]
		mi.material_override = AssetLib.make_material(p[2], p[3])
		door.add_child(mi)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.7, 0.4)
	glow.light_energy = 0.6
	glow.omni_range = 1.5
	glow.position = Vector3(0, 0.1, 0.4)
	door.add_child(glow)
	return door


func _make_label(font: Font, size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.font = font
	l.font_size = size
	l.outline_size = 14
	l.outline_modulate = Color(0, 0, 0, 1)
	l.modulate = color
	l.pixel_size = 0.0035
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return l
