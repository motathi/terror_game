extends Node3D
## Um personagem em cena: modelo + animação + nome flutuante (estilo trend)
## + palavra de súplica ("Por favor") que treme na hora da escolha.

const AssetLib := preload("res://scripts/stage/asset_lib.gd")
## Animações em loop: basta o nome conter uma destas palavras ("Dog1_Idle"...).
const LOOPING := ["idle", "walk", "run", "talk", "sit", "zombie", "loop", "wag", "bark"]

var char_id := ""
var display_name := ""
var model: Node3D
var anim_player: AnimationPlayer
var name_label: Label3D
var plead_label: Label3D
var key: OmniLight3D
var head_height := 1.85
var base_anim := "Idle"  # animação de repouso (volta para ela depois de falar)
var _current_anim := ""
var _t := randf() * 10.0
var _plead_active := false
var _base_y := 0.0
var _model_y0 := 0.0


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
		_apply_options(def.get("model", ""), def)
	_base_y = position.y

	# luz própria: o fundo pode ser escuro, o rosto não
	key = OmniLight3D.new()
	key.light_color = Color(1.0, 0.92, 0.82) if offscreen.is_empty() else Color(1.0, 0.75, 0.45)
	key.light_energy = 1.1
	key.omni_range = 2.6
	key.position = Vector3(0, head_height * 0.85, 0.9)  # à frente (+Z = lado da câmera)
	add_child(key)

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
	var low := found.to_lower()
	if a != null and not low.contains("start") and LOOPING.any(func(w): return low.contains(w)):
		a.loop_mode = Animation.LOOP_LINEAR
	anim_player.play(found, blend)
	_current_anim = found


## Opções do personagem além de model/tint (e ajustes do modelo em
## AssetLib.MODEL_META):
##   "altura": 1.3        altura em metros (medida pelos ossos)
##   "pelagem": "caramelo" recolore a textura (AssetLib.PELAGENS ou [escuro, claro])
##   "em_pe": true        bicho de quatro patas levantado nas patas de trás
##   "olhos": "#ffe070"   olhos que brilham (modelos com "olhos" no MODEL_META)
func _apply_options(key: String, def: Dictionary) -> void:
	var meta: Dictionary = AssetLib.meta(key)
	var pel = def.get("pelagem", "")
	_skin_materials(model, meta.get("tex", ""), AssetLib.PELAGENS.get(pel, null) if pel is String else pel)
	var em_pe: bool = def.get("em_pe", false)
	var rot := Vector3(deg_to_rad(80.0) if em_pe else 0.0, deg_to_rad(float(meta.get("rot_y", 0.0))), 0.0)
	var altura := float(def.get("altura", meta.get("altura", 0.0)))
	if altura > 0.0:
		var ext := _bone_extent_y(Basis.from_euler(rot))
		if ext.y - ext.x > 0.01:
			var s := altura / (ext.y - ext.x)
			var thin := float(meta.get("magro", 1.0))
			model.scale = Vector3(s * thin, s, s * thin)
			model.position.y = -ext.x * s
			head_height = altura + (0.12 if not em_pe and meta.has("olhos") else 0.0) + (0.35 if meta.has("anexos") else 0.0)
	model.rotation = rot
	_model_y0 = model.position.y
	if def.has("olhos") and meta.has("olhos"):
		_add_eyes_to_bone(meta, Color.html(def["olhos"]))
	for anexo in meta.get("anexos", []):
		_add_attachment(anexo, def)


## Textura (para GLBs que vêm sem ela) e rampa de cor ("pelagem") num modelo.
func _skin_materials(root: Node, tex_path: String, ramp) -> void:
	var tex: Texture2D = null
	if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
		tex = load(tex_path) as Texture2D
	if tex == null and ramp == null:
		return
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var mat := m.get_active_material(i) as ShaderMaterial
			if mat == null:
				continue
			mat = mat.duplicate()
			if tex != null:
				mat.set_shader_parameter("albedo_tex", tex)
				mat.set_shader_parameter("use_texture", true)
			if ramp != null:
				mat.set_shader_parameter("use_ramp", true)
				mat.set_shader_parameter("ramp_dark", Color.html(ramp[0]))
				mat.set_shader_parameter("ramp_light", Color.html(ramp[1]))
			m.set_surface_override_material(i, mat)


func _find_bone(bone_name: String) -> Array:
	for sk in model.find_children("*", "Skeleton3D", true, false):
		var skel := sk as Skeleton3D
		var idx := skel.find_bone(bone_name)
		if idx < 0:
			idx = skel.find_bone(bone_name.replace(".", "_"))
		if idx >= 0:
			return [skel, idx]
	return []


## Modelo extra preso num osso (ex.: máscara de cabeça de cachorro).
func _add_attachment(anexo: Dictionary, def: Dictionary) -> void:
	var found := _find_bone(anexo.get("osso", ""))
	if found.is_empty():
		return
	var skel: Skeleton3D = found[0]
	var att := BoneAttachment3D.new()
	att.bone_name = skel.get_bone_name(found[1])
	skel.add_child(att)
	var inst := AssetLib.spawn(AssetLib.model_path(anexo.get("model", "")), Vector3(0.2, 0.2, 0.2))
	AssetLib.psxify(inst)
	var pel = anexo.get("pelagem", "")
	_skin_materials(inst, anexo.get("tex", ""), AssetLib.PELAGENS.get(pel, null) if pel is String else pel)
	var holder := Node3D.new()
	holder.position = anexo.get("pos", Vector3.ZERO)
	var r: Vector3 = anexo.get("rot", Vector3.ZERO)
	holder.rotation = Vector3(deg_to_rad(r.x), deg_to_rad(r.y), deg_to_rad(r.z))
	holder.scale = Vector3.ONE * float(anexo.get("escala", 1.0))
	holder.add_child(inst)
	att.add_child(holder)
	if def.has("olhos"):
		_add_eye_meshes(holder, anexo.get("olhos", []), float(anexo.get("raio_olho", 0.02)), Color.html(def["olhos"]))


## Menor e maior altura dos ossos (pose de descanso) depois de girar o modelo.
func _bone_extent_y(rot: Basis) -> Vector2:
	var out := Vector2(INF, -INF)
	for sk in model.find_children("*", "Skeleton3D", true, false):
		var skel := sk as Skeleton3D
		var rel := Transform3D.IDENTITY
		var n: Node = skel
		while n != null and n != model:
			if n is Node3D:
				rel = (n as Node3D).transform * rel
			n = n.get_parent()
		for i in skel.get_bone_count():
			var y := (rot * (rel * skel.get_bone_global_rest(i).origin)).y
			out.x = minf(out.x, y)
			out.y = maxf(out.y, y)
	return out if out.x < out.y else Vector2(0, 0)


func _add_eyes_to_bone(meta: Dictionary, color: Color) -> void:
	var found := _find_bone(meta.get("osso_cabeca", ""))
	if found.is_empty():
		return
	var skel: Skeleton3D = found[0]
	var att := BoneAttachment3D.new()
	att.bone_name = skel.get_bone_name(found[1])
	skel.add_child(att)
	_add_eye_meshes(att, meta.get("olhos", []), float(meta.get("raio_olho", 0.02)), color)


func _add_eye_meshes(parent: Node3D, points: Array, r: float, color: Color) -> void:
	for p in points:
		var eye := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = r
		sph.height = r * 2.0
		sph.radial_segments = 6
		sph.rings = 3
		eye.mesh = sph
		eye.position = p
		eye.material_override = AssetLib.make_material(color, 4.0)
		parent.add_child(eye)


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
		model.position.y = _model_y0 + sin(_t * 1.7) * 0.012
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
